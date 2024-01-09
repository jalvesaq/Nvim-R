" Functions to start nvimrserver or that are called only after the
" nvimrserver is running

" Check if it's necessary to build and install nvimcom before attempting to load it
function CheckNvimcomVersion()
    if filereadable(g:rplugin.home . '/R/nvimcom/DESCRIPTION')
        let ndesc = readfile(g:rplugin.home . '/R/nvimcom/DESCRIPTION')
        let current = substitute(matchstr(ndesc, '^Version: '), 'Version: ', '', '')
        let flines = ['needed_nvc_version <- "' . current . '"']
    else
        let flines = ['needed_nvc_version <- NULL']
    endif

    let libs = ListRLibsFromBuffer()
    let flines += ['nvim_r_home <- "' . g:rplugin.home . '"',
                \ 'libs <- c(' . libs . ')']
    let flines += readfile(g:rplugin.home . "/R/before_nrs.R")
    let scrptnm = g:rplugin.tmpdir . "/before_nrs.R"
    call writefile(flines, scrptnm)
    call AddForDeletion(g:rplugin.tmpdir . "/before_nrs.R")

    " Run the script as a job, setting callback functions to receive its
    " stdout, stderr and exit code.
    if has('nvim')
        let jobh = {'on_stdout': function('RInitStdout'),
                    \ 'on_stderr': function('RInitStderr'),
                    \ 'on_exit': function('RInitExit')}
    else
        let jobh = {'out_cb':  'RInitStdout',
                    \ 'err_cb':  'RInitStderr',
                    \ 'exit_cb': 'RInitExit'}
    endif

    let s:RBout = []
    let s:RBerr = []
    let s:RWarn = []
    if exists("g:R_remote_compldir")
        let scrptnm = g:R_remote_compldir . "/tmp/before_nrs.R"
    endif
    let g:rplugin.debug_info['Time']['before_nrs.R'] = reltime()
    let g:rplugin.jobs["Init R"] = StartJob([g:rplugin.Rcmd, "--quiet", "--no-save", "--no-restore", "--slave", "-f", scrptnm], jobh)
    call AddForDeletion(g:rplugin.tmpdir . "/libPaths")
endfunction

function MkRdir()
    redraw
    let success = v:false
    let resp = input('"' . s:libd . '" is not writable. Create it now? [y/n] ')
    if resp[0] ==? "y"
        let dw = mkdir(s:libd, "p")
        if dw
            " Try again
            call CheckNvimcomVersion()
        else
            call RWarningMsg('Failed creating "' . s:libd . '"')
        endif
    else
        echo ""
        redraw
    endif
    unlet s:libd
endfunction

" Get the output of R CMD build and INSTALL
let s:RoutLine = ''
function RInitStdout(...)
    if has('nvim')
        let rcmd = substitute(join(a:2), '\r', '', 'g')
    else
        let rcmd = substitute(a:2, '\r', '', 'g')
    endif
    if s:RoutLine != ''
        let rcmd = s:RoutLine . rcmd
        if rcmd !~ "\x14"
            let s:RoutLine = rcmd
            return
        endif
    endif
    if rcmd =~ '^RWarn: ' || rcmd =~ '^let ' || rcmd =~ '^echo '
        if rcmd !~ "\x14"
            " R has sent an incomplete line
            let s:RoutLine .= rcmd
            return
        endif
        let s:RoutLine = ''

        " In spite of flush(stdout()), rcmd might be concatenating two commands
        " (https://github.com/jalvesaq/Nvim-R/issues/713)
        let rcmdl = split(rcmd, "\x14", 0)
        for rcmd in rcmdl
            if rcmd =~ '^RWarn: '
                let s:RWarn += [substitute(rcmd, '^RWarn: ', '', '')]
            else
                exe rcmd
            endif
            if rcmd =~ '^echo'
                redraw
            endif
        endfor
    else
        let s:RBout += [rcmd]
    endif
endfunction

function RInitStderr(...)
    if has('nvim')
        let s:RBerr += [substitute(join(a:2), '\r', '', 'g')]
    else
        let s:RBerr += [substitute(a:2, '\r', '', 'g')]
    endif
endfunction

" Check if the exit code of the script that built nvimcom was zero and if the
" file nvimcom_info seems to be OK (has three lines).
function RInitExit(...)
    let cnv_again = 0
    if a:2 == 0 || a:2 == 512 " ssh success seems to be 512
        call StartNServer()
    elseif a:2 == 71
        " No writable directory to update nvimcom
        " Avoid redraw of status line while waiting user input in MkRdir()
        let s:RBerr += s:RWarn
        let s:RWarn =[]
        call MkRdir()
    elseif a:2 == 72 && !has('win32') && !exists('s:pkgbuild_attempt')
        " Nvim-R/R/nvimcom directory not found. Perhaps R running in remote machine...
        " Try to use local R to build the nvimcom package.
        let s:pkgbuild_attempt = 1
        if executable("R")
            let shf = ['cd ' . g:rplugin.tmpdir,
                        \ 'R CMD build ' . g:rplugin.home . '/R/nvimcom']
            call writefile(shf, g:rplugin.tmpdir . '/buildpkg.sh')
            let rout = system('sh ' . g:rplugin.tmpdir . '/buildpkg.sh')
            if v:shell_error == 0
                call CheckNvimcomVersion()
                let cnv_again = 1
            endif
            call delete(g:rplugin.tmpdir . '/buildpkg.sh')
        endif
    else
        if filereadable(expand("~/.R/Makevars"))
            call RWarningMsg("ERROR! Please, run :RDebugInfo for details, and check your '~/.R/Makevars'.")
        else
            call RWarningMsg("ERROR: R exit code = " . a:2 . "! Please, run :RDebugInfo for details.")
        endif
    endif
    let g:rplugin.debug_info["before_nrs.R stderr"] = join(s:RBerr, "\n")
    let g:rplugin.debug_info["before_nrs.R stdout"] = join(s:RBout, "\n")
    unlet s:RBerr
    unlet s:RBout
    call AddForDeletion(g:rplugin.tmpdir . "/bo_code.R")
    call AddForDeletion(g:rplugin.localtmpdir . "/libs_in_nrs_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/libnames_" . $NVIMR_ID)
    if len(s:RWarn) > 0
        let g:rplugin.debug_info['RInit Warning'] = ''
        for wrn in s:RWarn
            let g:rplugin.debug_info['RInit Warning'] .= wrn . "\n"
            call RWarningMsg(wrn)
        endfor
    endif
    if cnv_again == 0
        let g:rplugin.debug_info['Time']['before_nrs.R'] = reltimefloat(reltime(g:rplugin.debug_info['Time']['before_nrs.R'], reltime()))
    endif
endfunction

function FindNCSpath(libdir)
    if has('win32')
        let ncs = 'nvimrserver.exe'
    else
        let ncs = 'nvimrserver'
    endif
    if filereadable(a:libdir . '/bin/' . ncs)
        return a:libdir . '/bin/' . ncs
    elseif filereadable(a:libdir . '/bin/x64/' . ncs)
        return a:libdir . '/bin/x64/' . ncs
    elseif filereadable(a:libdir . '/bin/i386/' . ncs)
        return a:libdir . '/bin/i386/' . ncs
    endif

    call RWarningMsg('Application "' . ncs . '" not found at "' . a:libdir . '"')
    return ''
endfunction

" Check and set some variables and, finally, start the nvimrserver
function StartNServer()
    if IsJobRunning("Server")
        return
    endif

    if exists("g:R_local_R_library_dir")
        let nrs_path = FindNCSpath(g:R_local_R_library_dir . '/nvimcom')
    else
        if filereadable(g:rplugin.compldir . '/nvimcom_info')
            let info = readfile(g:rplugin.compldir . '/nvimcom_info')
            if len(info) == 3
                " Update nvimcom information
                let g:rplugin.nvimcom_info = {'version': info[0], 'home': info[1], 'Rversion': info[2]}
                let g:rplugin.debug_info['nvimcom_info'] = g:rplugin.nvimcom_info
                let nrs_path = FindNCSpath(info[1])
            else
                call delete(g:rplugin.compldir . '/nvimcom_info')
                call RWarningMsg("ERROR in nvimcom_info! Please, do :RDebugInfo for details.")
                return
            endif
        else
            call RWarningMsg("ERROR: nvimcom_info not found. Please, run :RDebugInfo for details.")
            return
        endif
    endif

    let ncspath = substitute(nrs_path, '/nvimrserver.*', '', '')
    let ncs = substitute(nrs_path, '.*/nvimrserver', 'nvimrserver', '')

    " Some pdf viewers run nvimrserver to send SyncTeX messages back to Vim
    if $PATH !~ ncspath
        if has('win32')
            let $PATH = ncspath . ';' . $PATH
        else
            let $PATH = ncspath . ':' . $PATH
        endif
    endif

    " Options in the nvimrserver application are set through environment variables
    if g:R_objbr_opendf
        let $NVIMR_OPENDF = "TRUE"
    endif
    if g:R_objbr_openlist
        let $NVIMR_OPENLS = "TRUE"
    endif
    if g:R_objbr_allnames
        let $NVIMR_OBJBR_ALLNAMES = "TRUE"
    endif
    let $NVIMR_RPATH = g:rplugin.Rcmd

    let $NVIMR_LOCAL_TMPDIR = g:rplugin.localtmpdir

    " We have to set R's home directory on Window because nvimrserver will
    " run R to build the list for omni completion.
    if has('win32')
        call SetRHome()
    endif
    let g:rplugin.jobs["Server"] = StartJob([ncs], g:rplugin.job_handlers)
    " let g:rplugin.jobs["Server"] = StartJob(['valgrind', '--log-file=/dev/shm/nvimrserver_valgrind_log', '--leak-check=full', ncs], g:rplugin.job_handlers)
    if has('win32')
        call UnsetRHome()
    endif

    unlet $NVIMR_OPENDF
    unlet $NVIMR_OPENLS
    unlet $NVIMR_OBJBR_ALLNAMES
    unlet $NVIMR_RPATH
    unlet $NVIMR_LOCAL_TMPDIR
endfunction

function ListRLibsFromBuffer()
    if !exists("g:R_start_libs")
        let g:R_start_libs = "base,stats,graphics,grDevices,utils,methods"
    endif

    let lines = getline(1, "$")
    call filter(lines, "v:val =~ '^\\s*library\\|require\\s*('")
    call map(lines, 'substitute(v:val, "\\s*).*", "", "")')
    call map(lines, 'substitute(v:val, "\\s*,.*", "", "")')
    call map(lines, 'substitute(v:val, "\\s*\\(library\\|require\\)\\s*(\\s*", "", "")')
    call map(lines, 'substitute(v:val, "' . '[' . "'" . '\"]' . '", "", "g")')
    call map(lines, 'substitute(v:val, "\\", "", "g")')
    let libs = ""
    if len(g:R_start_libs) > 4
        let libs = '"' . substitute(g:R_start_libs, ",", '", "', "g") . '"'
    endif
    if len(lines) > 0
        if libs != ""
            let libs .= ", "
        endif
        let libs .= '"' . join(lines, '", "') . '"'
    endif
    return libs
endfunction

" Get information from nvimrserver (currently only the names of loaded libraries).
function RequestNCSInfo()
    call JobStdin(g:rplugin.jobs["Server"], "42\n")
endfunction

command RGetNCSInfo :call RequestNCSInfo()

" Callback function
function EchoNCSInfo(info)
    echo a:info
endfunction

" Called by nvimrserver when it gets error running R code
function ShowBuildOmnilsError(stt)
    if filereadable(g:rplugin.tmpdir . '/run_R_stderr')
        let ferr = readfile(g:rplugin.tmpdir . '/run_R_stderr')
        let g:rplugin.debug_info['Error running R code'] = 'Exit status: ' . a:stt . "\n" . join(ferr, "\n")
        call RWarningMsg('Error building omnils_ file. Run :RDebugInfo for details.')
        call delete(g:rplugin.tmpdir . '/run_R_stderr')
        if g:rplugin.debug_info['Error running R code'] =~ "Error in library(.nvimcom.).*there is no package called .*nvimcom"
            " This will happen if the user manually changes .libPaths
            call delete(g:rplugin.compldir . "/nvimcom_info")
            let g:rplugin.debug_info['Error running R code'] .= "\nPlease, restart " . v:progname
        endif
    else
        call RWarningMsg(g:rplugin.tmpdir . '/run_R_stderr not found')
    endif
endfunction

function BAAExit(...)
    if a:2 == 0 || a:2 == 512 " ssh success seems to be 512
        call JobStdin(g:rplugin.jobs["Server"], "41\n")
    endif
endfunction

function s:BuildAllArgs(...)
    if filereadable(g:rplugin.compldir . '/args_lock')
        call timer_start(5000, function("s:BuildAllArgs"))
        return
    endif

    let flist = glob(g:rplugin.compldir . '/omnils_*', v:false, v:true)
    call map(flist, 'substitute(v:val, "/omnils_", "/args_", "")')
    let rscrpt = ['library("nvimcom", warn.conflicts = FALSE)']
    for afile in flist
        if filereadable(afile) == 0
            let pkg = substitute(substitute(afile, ".*/args_", "", ""), "_.*", "", "")
            let rscrpt += ['nvimcom:::nvim.buildargs("' . afile . '", "' . pkg . '")']
        endif
    endfor
    if len(rscrpt) == 1
        return
    endif
    call writefile([""], g:rplugin.compldir . '/args_lock')
    let rscrpt += ['unlink("' . g:rplugin.compldir . '/args_lock")']

    let scrptnm = g:rplugin.tmpdir . "/build_args.R"
    call AddForDeletion(scrptnm)
    call writefile(rscrpt, scrptnm)
    if exists("g:R_remote_compldir")
        let scrptnm = g:R_remote_compldir . "/tmp/build_args.R"
    endif
    if has('nvim')
        let jobh = {'on_exit': function('BAAExit')}
    else
        let jobh = {'exit_cb': 'BAAExit'}
    endif
    let g:rplugin.jobs["Build_args"] = StartJob([g:rplugin.Rcmd, "--quiet", "--no-save", "--no-restore", "--slave", "-f", scrptnm], jobh)
endfunction

" This function is called for the first time before R is running because we
" support syntax highlighting and omni completion of default libraries' objects.
function UpdateSynRhlist()
    if !filereadable(g:rplugin.localtmpdir . "/libs_in_nrs_" . $NVIMR_ID)
        return
    endif

    let g:rplugin.libs_in_nrs = readfile(g:rplugin.localtmpdir . "/libs_in_nrs_" . $NVIMR_ID)
    for lib in g:rplugin.libs_in_nrs
        call AddToRhelpList(lib)
    endfor
    if exists("*FunHiOtherBf")
        " R/functions.vim will not be sourced if r_syntax_fun_pattern = 1
        call FunHiOtherBf()
    endif
    " Building args_ files is too time consuming. Do it asynchronously.
    call timer_start(1, function("s:BuildAllArgs"))
endfunction

" Filter words to :Rhelp
function RLisObjs(arglead, cmdline, curpos)
    let lob = []
    let rkeyword = '^' . a:arglead
    for xx in s:Rhelp_list
        if xx =~ rkeyword
            call add(lob, xx)
        endif
    endfor
    return lob
endfunction

let s:Rhelp_list = []
let s:Rhelp_loaded = []

" Add words to completion list of :Rhelp
function AddToRhelpList(lib)
    for lbr in s:Rhelp_loaded
        if lbr == a:lib
            return
        endif
    endfor
    let s:Rhelp_loaded += [a:lib]

    let omf = g:rplugin.compldir . '/omnils_' . a:lib

    " List of objects
    let olist = readfile(omf)

    " Library setwidth has no functions
    if len(olist) == 0 || (len(olist) == 1 && len(olist[0]) < 3)
        return
    endif

    " List of objects for :Rhelp completion
    for xx in olist
        let xxx = split(xx, "\x06")
        if len(xxx) > 0 && xxx[0] !~ '\$'
            call add(s:Rhelp_list, xxx[0])
        endif
    endfor
endfunction

" The calls to system() and executable() below are in this script to run
" asynchronously and avoid slow startup on Mac OS X.
" See https://github.com/jalvesaq/Nvim-R/issues/625
if !executable(g:rplugin.R)
    call RWarningMsg("R executable not found: '" . g:rplugin.R . "'")
endif

"==============================================================================
" Check for the existence of duplicated or obsolete code and deprecated options
"==============================================================================

" Check if Vim-R-plugin is installed
if exists("*WaitVimComStart")
    echohl WarningMsg
    call input("Please, uninstall Vim-R-plugin before using Nvim-R. [Press <Enter> to continue]")
    echohl None
endif

let s:ff = split(globpath(&rtp, "R/functions.vim"), '\n')
if len(s:ff) > 1
    function WarnDupNvimR()
        let ff = split(globpath(&rtp, "R/functions.vim"), '\n')
        let msg = ["", "===   W A R N I N G   ===", "",
                    \ "It seems that Nvim-R is installed in more than one place.",
                    \ "Please, remove one of them to avoid conflicts.",
                    \ "Below are the paths of the possibly duplicated installations:", ""]
        for ffd in ff
            let msg += ["  " . substitute(ffd, "R/functions.vim", "", "g")]
        endfor
        unlet ff
        let msg  += ["", "Please, uninstall one version of Nvim-R.", ""]
        exe len(msg) . "split Warning"
        call setline(1, msg)
        setlocal bufhidden=wipe
        setlocal noswapfile
        set buftype=nofile
        set nomodified
        redraw
    endfunction
    if v:vim_did_enter
        call WarnDupNvimR()
    else
        autocmd VimEnter * call WarnDupNvimR()
    endif
endif
unlet s:ff

" 2017-02-07
if exists("g:R_vsplit")
    call RWarningMsg("The option R_vsplit is deprecated. If necessary, use R_min_editor_width instead.")
endif

" 2017-03-14
if exists("g:R_ca_ck")
    call RWarningMsg("The option R_ca_ck was renamed as R_clear_line. Please, update your vimrc.")
endif

" 2017-11-15
if len(g:R_latexcmd[0]) == 1
    call RWarningMsg("The option R_latexcmd should be a list. Please update your vimrc.")
endif

" 2017-12-14
if hasmapto("<Plug>RCompleteArgs", "i")
    call RWarningMsg("<Plug>RCompleteArgs no longer exists. Please, delete it from your vimrc.")
else
    " Delete <C-X><C-A> mapping in RCreateEditMaps()
    function RCompleteArgs()
        stopinsert
        call RWarningMsg("Completion of function arguments are now done by omni completion.")
        return []
    endfunction
endif

" 2018-03-31
if exists('g:R_tmux_split')
    call RWarningMsg('The option R_tmux_split no longer exists. Please see https://github.com/jalvesaq/Nvim-R/blob/master/R/tmux_split.md')
endif

" 2020-05-18
if exists('g:R_complete')
    call RWarningMsg("The option 'R_complete' no longer exists.")
endif
if exists('R_args_in_stline')
    call RWarningMsg("The option 'R_args_in_stline' no longer exists.")
endif
if exists('R_sttline_fmt')
    call RWarningMsg("The option 'R_sttline_fmt' no longer exists.")
endif
if exists('R_show_args')
    call RWarningMsg("The option 'R_show_args' no longer exists.")
endif

" 2020-06-16
if exists('g:R_in_buffer')
    call RWarningMsg('The option "R_in_buffer" was replaced with "R_external_term".')
endif
if exists('g:R_term')
    call RWarningMsg('The option "R_term" was replaced with "R_external_term".')
endif
if exists('g:R_term_cmd')
    call RWarningMsg('The option "R_term_cmd" was replaced with "R_external_term".')
endif

" 2023-06-03
if exists("g:R_auto_omni")
    call RWarningMsg('R_auto_omni no longer exists. Alternative: https://github.com/jalvesaq/cmp-nvim-r')
endif

" 2023-07-23
if exists('g:R_commented_lines')
    call RWarningMsg('R_commented_lines no longer exists. See: https://github.com/jalvesaq/Nvim-R/issues/743')
endif

" 2023-10-23
if exists('g:R_hi_fun_globenv')
    call RWarningMsg('R_hi_fun_globenv no longer exists.')
endif
