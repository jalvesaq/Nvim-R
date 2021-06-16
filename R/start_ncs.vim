" Functions to start nclientserver and that are called only after the
" nclientserver is running


" Check if it's necessary to build and install nvimcom before attempting o load it
function CheckNvimcomVersion()
    let neednew = 0
    if isdirectory(g:rplugin.nvimcom_info['home'] . "/00LOCK-nvimcom")
        call RWarningMsg('Perhaps you should delete the directory "' .
                    \ g:rplugin.nvimcom_info['home'] . '/00LOCK-nvimcom"')
    endif

    " Compare version of nvimcom source with the installed version

    " Get version of current source code
    let flines = readfile(g:rplugin.home . "/R/nvimcom/DESCRIPTION")
    let s:required_nvimcom = substitute(flines[1], "Version: ", "", "")

    if g:rplugin.nvimcom_info['home'] == ""
        let neednew = 1
        let g:rplugin.debug_info['Why build nvimcom'] = 'nvimcom_home = ""'
    else
        if !filereadable(g:rplugin.nvimcom_info['home'] . "/nvimcom/DESCRIPTION")
            let neednew = 1
            let g:rplugin.debug_info['Why build nvimcom'] = 'No DESCRIPTION'
        else
            let ndesc = readfile(g:rplugin.nvimcom_info['home'] . "/nvimcom/DESCRIPTION")
            let nvers = substitute(ndesc[1], "Version: ", "", "")
            if nvers != s:required_nvimcom
                let neednew = 1
                let g:rplugin.debug_info['Why build nvimcom'] = 'Version mismatch'
            else
                " Nvimcom is up to date. Check if R version changed.
                let rversion = system(g:rplugin.Rcmd . ' --version')
                let rversion = substitute(rversion, '.*R version \(\S\{-}\) .*', '\1', '')
                if rversion < '4.0.0'
                    call RWarningMsg("Nvim-R requires R >= 4.0.0")
                endif
                let g:rplugin.debug_info['R_version'] = rversion
                if g:rplugin.nvimcom_info['Rversion'] != rversion
                    let neednew = 1
                    let g:rplugin.debug_info['Why build nvimcom'] = 'Other R version'
                endif
            endif
        endif
    endif

    " Nvim-R might have been installed as root in a non writable directory.
    " We have to build nvimcom in a writable directory before installing it.
    if neednew
        echon "Building nvimcom..."
        call delete(g:rplugin.compldir . '/nvimcom_info')
        exe "cd " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g')

        if has("win32")
            call SetRHome()
            let cmpldir = substitute(g:rplugin.compldir, '\\', '/', 'g')
            let scrptnm = 'cmds.cmd'
        else
            let cmpldir = g:rplugin.compldir
            let scrptnm = 'cmds.sh'
        endif

        " The user libs directory may not exist yet if R was just upgraded
        if exists("g:R_remote_tmpdir")
            let tmpdir = g:R_remote_tmpdir
        else
            let tmpdir = g:rplugin.tmpdir
        endif
        let rcode = [ 'sink("' . tmpdir . '/libpaths")',
                    \ 'cat(.libPaths()[1L],',
                    \ '    unlist(strsplit(Sys.getenv("R_LIBS_USER"), .Platform$path.sep))[1L],',
                    \ '    sep = "\n")',
                    \ 'sink()' ]
        call writefile(rcode, g:rplugin.tmpdir . '/nvimcom_path.R')
        let g:rplugin.debug_info['.libPaths()'] = system(g:rplugin.Rcmd . ' --no-restore --no-save --slave -f "' . g:rplugin.tmpdir . '/nvimcom_path.R"')
        if v:shell_error
            call RWarningMsg(g:rplugin.debug_info['.libPaths()'])
            if has("win32")
                call UnsetRHome()
            endif
            return 0
        endif
        let libpaths = readfile(g:rplugin.tmpdir . "/libpaths")
        call map(libpaths, 'substitute(expand(v:val), "\\", "/", "g")')
        let g:rplugin.debug_info['libPaths'] = libpaths
        if !(isdirectory(libpaths[0]) && filewritable(libpaths[0]) == 2) && !exists("g:R_remote_tmpdir")
            if !isdirectory(libpaths[1])
                redraw
                let resp = input('"' . libpaths[0] . '" is not writable. Should "' . libpaths[1] . '" be created now? [y/n] ')
                if resp[0] ==? "y"
                    call mkdir(libpaths[1], "p")
                endif
                echo " "
            endif
        endif
        call delete(g:rplugin.tmpdir . '/nvimcom_path.R')
        call delete(g:rplugin.tmpdir . "/libpaths")

        " Now that we ensured the existence of the directory where nvimcom is
        " going to be installed, write a script to:
        "   1. Build nvimcom
        "   2. Install nvimcom
        "   3. Save nvimcom_info in the cache directory (~/.cache/Nvim-R/ on Linux)

        if !exists("g:R_remote_tmpdir")
            let cmds = [g:rplugin.Rcmd . ' CMD build "' . g:rplugin.home . '/R/nvimcom"']
        else
            " Try to make it possible to run R and Vim in different machines
            let cmds =['cp -R "' . g:rplugin.home . '/R/nvimcom" .',
                        \ g:rplugin.Rcmd . ' CMD build "' . g:R_remote_tmpdir . '/nvimcom"',
                        \ 'rm -rf "' . g:R_tmpdir . '/nvimcom"']
        endif
        if has("win32")
            let cmds += [g:rplugin.Rcmd . " CMD INSTALL --no-multiarch nvimcom_" . s:required_nvimcom . ".tar.gz"]
        else
            let cmds += [g:rplugin.Rcmd . " CMD INSTALL --no-lock nvimcom_" . s:required_nvimcom . ".tar.gz"]
        endif
        let cmds += ["rm nvimcom_" . s:required_nvimcom . ".tar.gz",
                    \ g:rplugin.Rcmd . ' --no-restore --no-save --slave -e "' .
                    \ "cat(installed.packages()['nvimcom', c('Version', 'LibPath', 'Built')], sep = '\\n', file = '" . cmpldir . "/nvimcom_info')" . '"']

        call writefile(cmds, g:rplugin.tmpdir . '/' .  scrptnm)
        call AddForDeletion(g:rplugin.tmpdir . '/' .  scrptnm)
        let g:rplugin.debug_info["Build_cmds"] = join(cmds, "\n")

        " Run he script as a job, setting callback functions to receive its
        " stdout, stderr and exit code.
        if has('nvim')
            let jobh = {'on_stdout': function('RBuildStdout'),
                        \ 'on_stderr': function('RBuildStderr'),
                        \ 'on_exit': function('RBuildExit')}
        else
            let jobh = {'out_cb':  'RBuildStdout',
                        \ 'err_cb':  'RBuildStderr',
                        \ 'exit_cb': 'RBuildExit'}
        endif
        if has('win32')
            let g:rplugin.jobs["Build_R"] = StartJob([scrptnm], jobh)
        else
            let g:rplugin.jobs["Build_R"] = StartJob(['sh', g:rplugin.tmpdir . '/' . scrptnm], jobh)
        endif

        if has("win32")
            call UnsetRHome()
        endif
        silent cd -
    else
        call StartNClientServer()
    endif
endfunction

let s:RBout = []
let s:RBerr = []

" Get the output of R CMD build and INSTALL
function RBuildStdout(...)
    if has('nvim')
        let s:RBout += [substitute(join(a:2), '\r', '', 'g')]
    else
        let s:RBout += [substitute(a:2, '\r', '', 'g')]
    endif
endfunction

function RBuildStderr(...)
    if has('nvim')
        let s:RBerr += [substitute(join(a:2), '\r', '', 'g')]
    else
        let s:RBerr += [substitute(a:2, '\r', '', 'g')]
    endif
endfunction

" Check if the exit code of the script that built nvimcom was zero and if the
" file nvimcom_info seems to be OK (has three lines).
function RBuildExit(...)
    if a:2 == 0 && filereadable(g:rplugin.compldir . '/nvimcom_info')
        let info = readfile(g:rplugin.compldir . '/nvimcom_info')
        if len(info) == 3
            " Update nvimcom information
            let g:rplugin.nvimcom_info['version'] = info[0]
            let g:rplugin.nvimcom_info['home'] = info[1]
            let s:ncs_path = FindNCSpath(info[1])
            let g:rplugin.nvimcom_info['Rversion'] = info[2]
            call StartNClientServer()
            echon "OK"
        else
            call delete(g:rplugin.compldir . '/nvimcom_info')
            call RWarningMsg("ERROR! Please, do :RDebugInfo for details")
        endif
    else
        if filereadable(expand("~/.R/Makevars"))
            call RWarningMsg("ERROR! Please, run :RDebugInfo for details, and check your '~/.R/Makevars'.")
        else
            call RWarningMsg("ERROR! Please, run :RDebugInfo for details")
        endif
        call delete(g:rplugin.tmpdir . "nvimcom_" . s:required_nvimcom . ".tar.gz")
    endif
    "let g:rplugin.debug_info["RBuildOut"] = join(s:RBout, "\n")
    let g:rplugin.debug_info["RBuildErr"] = join(s:RBerr, "\n")
endfunction

function FindNCSpath(libdir)
    if has('win32')
        let ncs = 'nclientserver.exe'
    else
        let ncs = 'nclientserver'
    endif
    if filereadable(a:libdir . '/nvimcom/bin/' . ncs)
        return a:libdir . '/nvimcom/bin/' . ncs
    elseif filereadable(a:libdir . '/nvimcom/bin/x64/' . ncs)
        return a:libdir . '/nvimcom/bin/x64/' . ncs
    elseif filereadable(a:libdir . '/nvimcom/bin/i386/' . ncs)
        return a:libdir . '/nvimcom/bin/i386/' . ncs
    endif

    call RWarningMsg('Application "' . ncs . '" not found at "' . a:libdir . '"')
    return ''
endfunction

" Check and set some variables and, finally, start the nclientserver
function StartNClientServer()
    if IsJobRunning("ClientServer")
        return
    endif

    let g:rplugin.starting_ncs = 1

    let ncspath = substitute(s:ncs_path, '/nclientserver.*', '', '')
    let ncs = substitute(s:ncs_path, '.*/nclientserver', 'nclientserver', '')

    " Some pdf viewers run nclientserver to send SyncTeX messages back to Vim
    if $PATH !~ ncspath
        if has('win32')
            let $PATH = ncspath . ';' . $PATH
        else
            let $PATH = ncspath . ':' . $PATH
        endif
    endif

    " The nvimcom package includes a small application to generate random
    " number and we use it to set both $NVIMR_ID and $NVIMR_SECRET
    if $NVIMR_ID == ""
        if has('nvim')
            let randstr = system(['randint2'])
        else
            let randstr = system('randint2')
        endif
        if v:shell_error || strlen(randstr) < 8 || (strlen(randstr) > 0 && randstr[0] !~ '[0-9]')
            call RWarningMsg('Using insecure communication with R due to failure to get random numbers from nclientserver: '
                        \ . substitute(randstr, "[\r\n]", ' ', 'g'))
            let $NVIMR_ID = strftime('%m%d%Y%M%S%H')
            let $NVIMR_SECRET = strftime('%m%H%M%d%Y%S')
        else
            let randlst = split(randstr)
            let $NVIMR_ID = randlst[0]
            let $NVIMR_SECRET = randlst[1]
        endif
    endif
    call AddForDeletion(g:rplugin.tmpdir . "/libnames_" . $NVIMR_ID)

    " Options in the nclientserver application are set through environment variables
    if g:R_objbr_opendf
        let $NVIMR_OPENDF = "TRUE"
    endif
    if g:R_objbr_openlist
        let $NVIMR_OPENLS = "TRUE"
    endif
    if g:R_objbr_allnames
        let $NVIMR_OBJBR_ALLNAMES = "TRUE"
    endif

    " We have to set R's home directory on Window because nclientserver will
    " run R to build the list for omni completion.
    if has('win32')
        call SetRHome()
    endif
    let g:rplugin.jobs["ClientServer"] = StartJob([ncs], g:rplugin.job_handlers)
    "let g:rplugin.jobs["ClientServer"] = StartJob(['valgrind', '--log-file=/tmp/nclientserver_valgrind_log', '--leak-check=full', ncs], g:rplugin.job_handlers)
    if has('win32')
        call UnsetRHome()
    endif

    unlet $NVIMR_OPENDF
    unlet $NVIMR_OPENLS
    unlet $NVIMR_OBJBR_ALLNAMES

    call RSetDefaultPkg()
endfunction

" This function is called by nclientserver when its server binds to a specific port.
function RSetMyPort(p)
    let g:rplugin.myport = a:p
    let $NVIMR_PORT = a:p
    let g:rplugin.starting_ncs = 0

    " Now, build (if necessary) and load the default package before running R.
    if !exists("g:R_start_libs")
        let g:R_start_libs = "base,stats,graphics,grDevices,utils,methods"
    endif
    if !isdirectory(g:rplugin.tmpdir)
        call mkdir(g:rplugin.tmpdir, "p", 0700)
    endif
    let pkgs = "'" . substitute(g:R_start_libs, ",", "', '", "g") . "'"
    call JobStdin(g:rplugin.jobs["ClientServer"], "35" . pkgs . "\n")
    call AddForDeletion(g:rplugin.tmpdir . "/bo_code.R")
    call AddForDeletion(g:rplugin.tmpdir . "/libs_in_ncs_" . $NVIMR_ID)
endfunction

" Get information from nclientserver (currently only the names of loaded
" libraries).
function RequestNCSInfo()
    call JobStdin(g:rplugin.jobs["ClientServer"], "4\n")
endfunction

command RGetNCSInfo :call RequestNCSInfo()

" Callback function
function NclientserverInfo(info)
    echo a:info
endfunction

" Called by nclientserver when it gets error running R code
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

" This function is called for the first time before R is running because we
" support syntax highlighting and omni completion of default libraries' objects.
function UpdateSynRhlist()
    if !filereadable(g:rplugin.tmpdir . "/libs_in_ncs_" . $NVIMR_ID)
        return
    endif

    let g:rplugin.libs_in_ncs = readfile(g:rplugin.tmpdir . "/libs_in_ncs_" . $NVIMR_ID)
    for lib in g:rplugin.libs_in_ncs
        call AddToRhelpList(lib)
    endfor
    if exists("*FunHiOtherBf")
        " R/functions.vim will not be source if r_syntax_fun_pattern = 1
        call FunHiOtherBf()
    endif
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

" Get nvimcom_info from the last time that nvimcom was built
let g:rplugin.nvimcom_info = {'home': '', 'version': '0', 'Rversion': '0'}
let s:ncs_path = ""
if filereadable(g:rplugin.compldir . "/nvimcom_info")
    let s:flines = readfile(g:rplugin.compldir . "/nvimcom_info")
    if len(s:flines) == 3
        let s:ncs_path = FindNCSpath(s:flines[1])
        if s:ncs_path != ''
            let g:rplugin.nvimcom_info['version'] = s:flines[0]
            let g:rplugin.nvimcom_info['home'] = s:flines[1]
            let g:rplugin.nvimcom_info['Rversion'] = s:flines[2]
        endif
    endif
    unlet s:flines
endif
if exists("g:R_nvimcom_home")
    let g:rplugin.nvimcom_info['home'] = substitute(g:R_nvimcom_home, '/nvimcom', '', '')
endif

