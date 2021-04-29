"  This program is free software; you can redistribute it and/or modify
"  it under the terms of the GNU General Public License as published by
"  the Free Software Foundation; either version 2 of the License, or
"  (at your option) any later version.
"
"  This program is distributed in the hope that it will be useful,
"  but WITHOUT ANY WARRANTY; without even the implied warranty of
"  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"  GNU General Public License for more details.
"
"  A copy of the GNU General Public License is available at
"  http://www.r-project.org/Licenses/

"==========================================================================
" Authors: Jakson Alves de Aquino <jalvesaq@gmail.com>
"          Jose Claudio Faria
"
" Purposes of this file: Create all functions and commands and set the
" value of all global variables and some buffer variables.for r,
" rnoweb, rhelp, rdoc, and rbrowser files
"
" Why not an autoload script? Because autoload was designed to store
" functions that are only occasionally used. The Nvim-R has
" global variables and functions that are common to five file types
" and most of these functions will be used every time the plugin is
" used.
"==========================================================================

set encoding=utf-8
scriptencoding utf-8

" Do this only once
if exists("s:did_global_stuff")
    finish
endif
let s:did_global_stuff = 1

if !exists('g:rplugin')
    " Also in functions.vim
    let g:rplugin = {'debug_info': {}, 'libs_in_ncs': []}
endif

"==========================================================================
" Check if there is more than one copy of Nvim-R
" (e.g. from the Vimballl and from a plugin manager)
"==========================================================================

if exists("*RWarningMsg")
    " A common_global.vim script was sourced from another version of NvimR.
    finish
endif

"==========================================================================
" Functions that are common to r, rnoweb, rhelp and rdoc
"==========================================================================

function CloseRWarn(timer)
    let id = win_id2win(s:float_warn)
    if id > 0
        call nvim_win_close(s:float_warn, 1)
    endif
endfunction

function RFloatWarn(wmsg)
    let fmsg = ' ' . FormatTxt(a:wmsg, ' ', " \n ", 60)
    let fmsgl = split(fmsg, "\n")
    let realwidth = 10
    for lin in fmsgl
        if strdisplaywidth(lin) > realwidth
            let realwidth = strdisplaywidth(lin)
        endif
    endfor
    let wht = len(fmsgl) > 3 ? 3 : len(fmsgl)
    if has('nvim')
        if !exists('s:warn_buf')
            let s:warn_buf = nvim_create_buf(v:false, v:true)
            call setbufvar(s:warn_buf, '&buftype', 'nofile')
            call setbufvar(s:warn_buf, '&bufhidden', 'hide')
            call setbufvar(s:warn_buf, '&swapfile', 0)
            call setbufvar(s:warn_buf, '&tabstop', 2)
            call setbufvar(s:warn_buf, '&undolevels', -1)
        endif
        call nvim_buf_set_option(s:warn_buf, 'syntax', 'off')
        call nvim_buf_set_lines(s:warn_buf, 0, -1, v:true, fmsgl)
        let opts = {'relative': 'editor', 'width': realwidth, 'height': wht,
                    \ 'col': winwidth(0) - realwidth,
                    \ 'row': &lines - 3 - wht, 'anchor': 'NW', 'style': 'minimal'}
        let s:float_warn = nvim_open_win(s:warn_buf, 0, opts)
        hi FloatWarnNormal ctermfg=196 guifg=#ff0000 guibg=#222200
        call nvim_win_set_option(s:float_warn, 'winhl', 'Normal:FloatWarnNormal')
        call timer_start(2000 * len(fmsgl), 'CloseRWarn')
    else
        let fline = &lines - 2 - wht
        let fcol = winwidth(0) - realwidth
        let s:float_warn = popup_create(fmsgl, #{
                    \ line: fline,
                    \ col: fcol,
                    \ highlight: 'WarningMsg',
                    \ time: 2000 * len(fmsgl),
                    \ })
    endif
endfunction

function RWarningMsg(wmsg)
    if v:vim_did_enter == 0
        exe 'autocmd VimEnter * call RWarningMsg("' . escape(a:wmsg, '"') . '")'
        return
    endif
    if mode() == 'i' && (has('nvim-0.4.3') || has('patch-8.1.1705'))
        call RFloatWarn(a:wmsg)
    endif
    echohl WarningMsg
    echomsg a:wmsg
    echohl None
endfunction

if has("nvim")
    if !has("nvim-0.4.3")
        call RWarningMsg("Nvim-R requires Neovim >= 0.4.3.")
        let g:rplugin.failed = 1
        finish
    endif
elseif v:version < "801"
    call RWarningMsg("Nvim-R requires either Neovim >= 0.4.3 or Vim >= 8.1.1705")
    let g:rplugin.failed = 1
    finish
elseif !has("channel") || !has("job") || !has('patch-8.1.1705')
    call RWarningMsg("Nvim-R requires either Neovim >= 0.4.3 or Vim >= 8.1.1705\nIf using Vim, it must have been compiled with both +channel and +job features.\n")
    let g:rplugin.failed = 1
    finish
endif

function ReplaceUnderS()
    if &filetype != "r" && b:IsInRCode(0) == 0
        let isString = 1
    else
        let save_unnamed_reg = @@
        let j = col(".")
        let s = getline(".")
        if g:R_assign == 1 && g:R_assign_map == "_" && j > 3 && s[j-3] == "<" && s[j-2] == "-" && s[j-1] == " "
            exe "normal! 3h3xr_"
            let @@ = save_unnamed_reg
            return
        endif
        let isString = 0
        let synName = synIDattr(synID(line("."), j, 1), "name")
        if synName == "rSpecial"
            let isString = 1
        else
            if synName == "rString"
                let isString = 1
                if s[j-1] == '"' || s[j-1] == "'" && g:R_assign == 1
                    let synName = synIDattr(synID(line("."), j-2, 1), "name")
                    if synName == "rString" || synName == "rSpecial"
                        let isString = 0
                    endif
                endif
            else
                if g:R_assign == 2
                    if s[j-1] != "_" && !(j > 3 && s[j-3] == "<" && s[j-2] == "-" && s[j-1] == " ")
                        let isString = 1
                    elseif j > 3 && s[j-3] == "<" && s[j-2] == "-" && s[j-1] == " "
                        exe "normal! 3h3xr_a_"
                        let @@ = save_unnamed_reg
                        return
                    else
                        if j == len(s)
                            exe "normal! 1x"
                            let @@ = save_unnamed_reg
                        else
                            exe "normal! 1xi <- "
                            let @@ = save_unnamed_reg
                            return
                        endif
                    endif
                endif
            endif
        endif
    endif
    if isString
        exe "normal! a" . g:R_assign_map
    else
        exe "normal! a <- "
    endif
endfunction

function ReadRMsg()
    let msg = readfile($NVIMR_TMPDIR . "/nvimcom_msg")
    exe "call " . msg[0]
    call delete($NVIMR_TMPDIR . "/nvimcom_msg")
endfunction

function CompleteChunkOptions(base)
    " https://yihui.org/knitr/options/#chunk-options (2021-04-19)
    let lines = readfile(g:rplugin.home . '/R/chunk_options')

    let ktopt = []
    for lin in lines
        let dict = eval(lin)
        let dict['abbr'] = dict['word']
        let dict['word'] = dict['word'] . '='
        let dict['menu'] = '= ' . dict['menu']
        let dict['user_data']['cls'] = 'k'
        let ktopt += [deepcopy(dict)]
    endfor

    let rr = []

    if strlen(a:base) > 0
        let newbase = '^' . substitute(a:base, "\\$$", "", "")
        call filter(ktopt, 'v:val["abbr"] =~ newbase')
    endif

    call sort(ktopt)
    for kopt in ktopt
        if has('nvim-0.5.0') || has('patch-8.2.84')
            call add(rr, kopt)
        else
            let s:user_data[kopt['word']] = remove(kopt, 'user_data')
            call add(rr, kopt)
        endif
    endfor
    return rr
endfunction

function IsFirstRArg(lnum, cpos)
    let line = getline(a:lnum)
    let ii = a:cpos[2] - 2
    let cchar = line[ii]
    while ii > 0 && cchar != '('
        let cchar = line[ii]
        if cchar == ','
            return 0
        endif
        let ii -= 1
    endwhile
    return 1
endfunction

function FinishArgsCompletion(base, rkey)
    if exists('s:compl_menu')
        unlet s:compl_menu
    endif
    call JobStdin(g:rplugin.jobs["ClientServer"], "5A" . a:base .
                \ "\002" . a:rkey . "\n")
endfunction

function RGetFL(mode)
    if a:mode == "normal"
        let fline = line(".")
        let lline = line(".")
    else
        let fline = line("'<")
        let lline = line("'>")
    endif
    if fline > lline
        let tmp = lline
        let lline = fline
        let fline = tmp
    endif
    return [fline, lline]
endfunction

function IsLineInRCode(vrb, line)
    let save_cursor = getpos(".")
    call setpos(".", [0, a:line, 1, 0])
    let isR = b:IsInRCode(a:vrb)
    call setpos('.', save_cursor)
    return isR
endfunction

function RSimpleCommentLine(mode, what)
    let [fline, lline] = RGetFL(a:mode)
    let cstr = g:R_rcomment_string
    if (&filetype == "rnoweb"|| &filetype == "rhelp") && IsLineInRCode(0, fline) == 0
        let cstr = "%"
    elseif (&filetype == "rmd" || &filetype == "rrst") && IsLineInRCode(0, fline) == 0
        return
    endif

    if a:what == "c"
        for ii in range(fline, lline)
            call setline(ii, cstr . getline(ii))
        endfor
    else
        for ii in range(fline, lline)
            call setline(ii, substitute(getline(ii), "^" . cstr, "", ""))
        endfor
    endif
endfunction

function RCommentLine(lnum, ind, cmt)
    let line = getline(a:lnum)
    call cursor(a:lnum, 0)

    if line =~ '^\s*' . a:cmt || line =~ '^\s*#'
        let line = substitute(line, '^\s*' . a:cmt, '', '')
        let line = substitute(line, '^\s*#*', '', '')
        call setline(a:lnum, line)
        normal! ==
    else
        if g:R_indent_commented
            while line =~ '^\s*\t'
                let line = substitute(line, '^\(\s*\)\t', '\1' . s:curtabstop, "")
            endwhile
            let line = strpart(line, a:ind)
        endif
        let line = a:cmt . line
        call setline(a:lnum, line)
        if g:R_indent_commented
            normal! ==
        endif
    endif
endfunction

function RComment(mode)
    let cpos = getpos(".")
    let [fline, lline] = RGetFL(a:mode)

    " What comment string to use?
    if g:r_indent_ess_comments
        if g:R_indent_commented
            let cmt = '## '
        else
            let cmt = '### '
        endif
    else
        let cmt = g:R_rcomment_string
    endif
    if (&filetype == "rnoweb" || &filetype == "rhelp") && IsLineInRCode(0, fline) == 0
        let cmt = "%"
    elseif (&filetype == "rmd" || &filetype == "rrst") && IsLineInRCode(0, fline) == 0
        return
    endif

    let lnum = fline
    let ind = &tw
    while lnum <= lline
        let idx = indent(lnum)
        if idx < ind
            let ind = idx
        endif
        let lnum += 1
    endwhile

    let lnum = fline
    let s:curtabstop = repeat(' ', &tabstop)
    while lnum <= lline
        call RCommentLine(lnum, ind, cmt)
        let lnum += 1
    endwhile
    call cursor(cpos[1], cpos[2])
endfunction

function MovePosRCodeComment(mode)
    if a:mode == "selection"
        let fline = line("'<")
        let lline = line("'>")
    else
        let fline = line(".")
        let lline = fline
    endif

    let cpos = g:r_indent_comment_column
    let lnum = fline
    while lnum <= lline
        let line = getline(lnum)
        let cleanl = substitute(line, '\s*#.*', "", "")
        let llen = strlen(cleanl)
        if llen > (cpos - 2)
            let cpos = llen + 2
        endif
        let lnum += 1
    endwhile

    let lnum = fline
    while lnum <= lline
        call MovePosRLineComment(lnum, cpos)
        let lnum += 1
    endwhile
    call cursor(fline, cpos + 1)
    if a:mode == "insert"
        startinsert!
    endif
endfunction

function MovePosRLineComment(lnum, cpos)
    let line = getline(a:lnum)

    let ok = 1

    if &filetype == "rnoweb"
        if search("^<<", "bncW") > search("^@", "bncW")
            let ok = 1
        else
            let ok = 0
        endif
        if line =~ "^<<.*>>=$"
            let ok = 0
        endif
        if ok == 0
            call RWarningMsg("Not inside an R code chunk.")
            return
        endif
    endif

    if &filetype == "rhelp"
        let lastsection = search('^\\[a-z]*{', "bncW")
        let secname = getline(lastsection)
        if secname =~ '^\\usage{' || secname =~ '^\\examples{' || secname =~ '^\\dontshow{' || secname =~ '^\\dontrun{' || secname =~ '^\\donttest{' || secname =~ '^\\testonly{' || secname =~ '^\\method{.*}{.*}('
            let ok = 1
        else
            let ok = 0
        endif
        if ok == 0
            call RWarningMsg("Not inside an R code section.")
            return
        endif
    endif

    if line !~ '#'
        " Write the comment character
        let line = line . repeat(' ', a:cpos)
        let cmd = "let line = substitute(line, '^\\(.\\{" . (a:cpos - 1) . "}\\).*', '\\1# ', '')"
        exe cmd
        call setline(a:lnum, line)
    else
        " Align the comment character(s)
        let line = substitute(line, '\s*#', '#', "")
        let idx = stridx(line, '#')
        let str1 = strpart(line, 0, idx)
        let str2 = strpart(line, idx)
        let line = str1 . repeat(' ', a:cpos - idx - 1) . str2
        call setline(a:lnum, line)
    endif
endfunction

" Count braces
function CountBraces(line)
    let line2 = substitute(a:line, "{", "", "g")
    let line3 = substitute(a:line, "}", "", "g")
    let result = strlen(line3) - strlen(line2)
    return result
endfunction

function CleanOxygenLine(line)
    let cline = a:line
    if cline =~ "^\s*#\\{1,2}'"
        let synName = synIDattr(synID(line("."), col("."), 1), "name")
        if synName == "rOExamples"
            let cline = substitute(cline, "^\s*#\\{1,2}'", "", "")
        endif
    endif
    return cline
endfunction

function CleanCurrentLine()
    let curline = substitute(getline("."), '^\s*', "", "")
    if &filetype == "r"
        let curline = CleanOxygenLine(curline)
    endif
    return curline
endfunction

" Skip empty lines and lines whose first non blank char is '#'
function GoDown()
    if &filetype == "rnoweb"
        let curline = getline(".")
        if curline[0] == '@'
            call RnwNextChunk()
            return
        endif
    elseif &filetype == "rmd"
        let curline = getline(".")
        if curline =~ '^```$'
            call RmdNextChunk()
            return
        endif
    elseif &filetype == "rrst"
        let curline = getline(".")
        if curline =~ '^\.\. \.\.$'
            call RrstNextChunk()
            return
        endif
    endif

    let i = line(".") + 1
    call cursor(i, 1)
    let curline = CleanCurrentLine()
    let lastLine = line("$")
    while i < lastLine && (curline[0] == '#' || strlen(curline) == 0)
        let i = i + 1
        call cursor(i, 1)
        let curline = CleanCurrentLine()
    endwhile
endfunction

function IsSendCmdToRFake()
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        let qcmd = "\\rq"
        let nkblist = execute("nmap")
        let nkbls = split(nkblist, "\n")
        for nkb in nkbls
            if stridx(nkb, "RQuit('nosave')") > 0
                let qls = split(nkb, " ")
                let qcmd = qls[1]
                break
            endif
        endfor
        call RWarningMsg("As far as I know, R is already running. If it is not running, did you quit it from within ". v:progname . " (command " . qcmd . ")?")
        return 1
    endif
    return 0
endfunction

function RSetDefaultPkg()
    if $R_DEFAULT_PACKAGES == ""
        let $R_DEFAULT_PACKAGES = "datasets,utils,grDevices,graphics,stats,methods,nvimcom"
    elseif $R_DEFAULT_PACKAGES !~ "nvimcom"
        let $R_DEFAULT_PACKAGES .= ",nvimcom"
    endif
    if exists("g:RStudio_cmd") && $R_DEFAULT_PACKAGES !~ "rstudioapi"
        let $R_DEFAULT_PACKAGES .= ",rstudioapi"
    endif
endfunction

function ShowBuildOmnilsError(stt)
    let ferr = readfile(g:rplugin.tmpdir . '/run_R_stderr')
    let g:rplugin.debug_info['Error running R code'] = 'Exit status: ' . a:stt . "\n" . join(ferr, "\n")
    call RWarningMsg('Error building omnils_ file. Run :RDebugInfo for details.')
endfunction

function UpdateSynRhlist()
    if !filereadable(g:rplugin.tmpdir . "/libs_in_ncs_" . $NVIMR_ID)
        return
    endif

    let g:rplugin.libs_in_ncs = readfile(g:rplugin.tmpdir . "/libs_in_ncs_" . $NVIMR_ID)
    for lib in g:rplugin.libs_in_ncs
        call SourceRFunList(lib)
        call AddToRhelpList(lib)
    endfor
    call FunHiOtherBf()
endfunction

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

function CheckNvimcomVersion()
    let neednew = 0
    if isdirectory(s:nvimcom_home . "/00LOCK-nvimcom")
        call RWarningMsg('Perhaps you should delete the directory "' .
                    \ s:nvimcom_home . '/00LOCK-nvimcom"')
    endif

    let flines = readfile(g:rplugin.home . "/R/nvimcom/DESCRIPTION")
    let s:required_nvimcom = substitute(flines[1], "Version: ", "", "")

    if s:nvimcom_home == ""
        let neednew = 1
        let g:rplugin.debug_info['Why build nvimcom'] = 'nvimcom_home = ""'
    else
        if !filereadable(s:nvimcom_home . "/nvimcom/DESCRIPTION")
            let neednew = 1
            let g:rplugin.debug_info['Why build nvimcom'] = 'No DESCRIPTION'
        else
            let ndesc = readfile(s:nvimcom_home . "/nvimcom/DESCRIPTION")
            let nvers = substitute(ndesc[1], "Version: ", "", "")
            if nvers != s:required_nvimcom
                let neednew = 1
                let g:rplugin.debug_info['Why build nvimcom'] = 'Version mismatch'
            else
                let rversion = system(g:rplugin.Rcmd . ' --version')
                let rversion = substitute(rversion, '.*R version \(\S\{-}\) .*', '\1', '')
                if rversion < '4.0.0'
                    call RWarningMsg("Nvim-R requires R >= 4.0.0")
                endif
                let g:rplugin.debug_info['R_version'] = rversion
                if s:R_version != rversion
                    let neednew = 1
                    let g:rplugin.debug_info['Why build nvimcom'] = 'Other R version'
                endif
            endif
        endif
    endif

    " Nvim-R might have been installed as root in a non writable directory.
    " We have to build nvimcom in a writable directory before installing it.
    if neednew
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
                call SetRHome()
            endif
            return 0
        endif
        let libpaths = readfile(g:rplugin.tmpdir . "/libpaths")
        call map(libpaths, 'substitute(expand(v:val), "\\", "/", "g")')
        let g:rplugin.debug_info['libPaths'] = libpaths
        if !(isdirectory(libpaths[0]) && filewritable(libpaths[0]) == 2) && !exists("g:R_remote_tmpdir")
            if !isdirectory(libpaths[1])
                let resp = input('"' . libpaths[0] . '" is not writable. Should "' . libpaths[1] . '" be created now? [y/n] ')
                if resp[0] ==? "y"
                    call mkdir(libpaths[1], "p")
                endif
                echo " "
            endif
        endif
        call delete(g:rplugin.tmpdir . '/nvimcom_path.R')
        call delete(g:rplugin.tmpdir . "/libpaths")

        if !exists("g:R_remote_tmpdir")
            let cmds = [g:rplugin.Rcmd . ' CMD build "' . g:rplugin.home . '/R/nvimcom"']
        else
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
function RBuildStdout(...)
    if has('nvim')
        let s:RBout += [substitute(join(a:2), '\r', '', 'g')]
    else
        let s:RBout += [substitute(a:2, '\r', '', 'g')]
    endif
endfunction

let s:RBerr = []
function RBuildStderr(...)
    if has('nvim')
        let s:RBerr += [substitute(join(a:2), '\r', '', 'g')]
    else
        let s:RBerr += [substitute(a:2, '\r', '', 'g')]
    endif
endfunction

function RBuildExit(...)
    if a:2 == 0 && filereadable(g:rplugin.compldir . '/nvimcom_info')
        let info = readfile(g:rplugin.compldir . '/nvimcom_info')
        if len(info) == 3
            let s:nvimcom_version = info[0]
            let s:nvimcom_home = info[1]
            let s:ncs_path = FindNCSpath(info[1])
            let s:R_version = info[2]
            call StartNClientServer()
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


function NclientserverInfo(info)
    echo a:info
endfunction

function RequestNCSInfo()
    call JobStdin(g:rplugin.jobs["ClientServer"], "4\n")
endfunction

command RGetNCSInfo :call RequestNCSInfo()

function StartNClientServer()
    if IsJobRunning("ClientServer")
        return
    endif

    let s:starting_ncs = 1

    let ncspath = substitute(s:ncs_path, '/nclientserver.*', '', '')
    let ncs = substitute(s:ncs_path, '.*/nclientserver', 'nclientserver', '')

    if $PATH !~ ncspath
        if has('win32')
            let $PATH = ncspath . ';' . $PATH
        else
            let $PATH = ncspath . ':' . $PATH
        endif
    endif

    if $NVIMR_ID == ""
        if has('nvim')
            let randstr = system([ncs, 'random'])
        else
            let randstr = system(ncs . ' random')
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

    if g:R_objbr_opendf
        let $NVIMR_OPENDF = "TRUE"
    endif
    if g:R_objbr_openlist
        let $NVIMR_OPENLS = "TRUE"
    endif
    if g:R_objbr_allnames
        let $NVIMR_OBJBR_ALLNAMES = "TRUE"
    endif
    if exists("g:R_omni_size")
        let $NVIMR_MAX_CHANNEL_BUFFER_SIZE = string(g:R_omni_size)
    else
        if has("nvim") && g:rplugin.is_darwin
            let $NVIMR_MAX_CHANNEL_BUFFER_SIZE = "7600"
        else
            let $NVIMR_MAX_CHANNEL_BUFFER_SIZE = "65000"
        endif
    endif
    if g:R_omni_tmp_file
        let $NVIMR_OMNI_TMP_FILE = "1"
    endif
    "let g:rplugin.jobs["ClientServer"] = StartJob([ncs], g:rplugin.job_handlers)
    let g:rplugin.jobs["ClientServer"] = StartJob(['valgrind', '--log-file=/tmp/nclientserver_valgrind_log', '--leak-check=full', ncs], g:rplugin.job_handlers)
    unlet $NVIMR_OPENDF
    unlet $NVIMR_OPENLS
    unlet $NVIMR_OBJBR_ALLNAMES
    unlet $NVIMR_MAX_CHANNEL_BUFFER_SIZE
    unlet $NVIMR_OMNI_TMP_FILE

    call RSetDefaultPkg()
endfunction

" Start R
function StartR(whatr)
    let s:wait_nvimcom = 1

    if s:starting_ncs == 1
        " The user called StartR too quickly
        echon "Waiting nclientserver..."
        let ii = 0
        while s:starting_ncs == 1
            sleep 100m
            let ii += 1
            if ii == 30
                break
            endif
        endwhile
        let s:starting_ncs = 0
    endif

    if (type(g:R_external_term) == v:t_number && g:R_external_term == 1) || type(g:R_external_term) == v:t_string
        let g:R_objbr_place = substitute(g:R_objbr_place, 'console', 'script', '')
    endif

    if !isdirectory(g:rplugin.tmpdir)
        call mkdir(g:rplugin.tmpdir, "p", 0700)
    endif

    " https://github.com/jalvesaq/Nvim-R/issues/157
    if !exists("*FunHiOtherBf")
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/functions.vim"
    endif

    if a:whatr =~ "custom"
        call inputsave()
        let r_args = input('Enter parameters for R: ')
        call inputrestore()
        let g:rplugin.r_args = split(r_args)
    else
        if exists("g:R_args")
            let g:rplugin.r_args = g:R_args
        else
            let g:rplugin.r_args = []
        endif
    endif

    call writefile([], g:rplugin.tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    call writefile([], g:rplugin.tmpdir . "/globenv_" . $NVIMR_ID)
    call writefile([], g:rplugin.tmpdir . "/liblist_" . $NVIMR_ID)

    call AddForDeletion(g:rplugin.tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/globenv_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/liblist_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/nvimbol_finished")
    call AddForDeletion(g:rplugin.tmpdir . "/start_options.R")
    call AddForDeletion(g:rplugin.tmpdir . "/args_for_completion")

    " Reset R_DEFAULT_PACKAGES to its original value (see https://github.com/jalvesaq/Nvim-R/issues/554):
    let start_options = ['Sys.setenv("R_DEFAULT_PACKAGES" = "' . s:r_default_pkgs . '")']

    if g:R_objbr_allnames
        let start_options += ['options(nvimcom.allnames = TRUE)']
    else
        let start_options += ['options(nvimcom.allnames = FALSE)']
    endif
    if g:R_texerr
        let start_options += ['options(nvimcom.texerrs = TRUE)']
    else
        let start_options += ['options(nvimcom.texerrs = FALSE)']
    endif
    if exists('g:R_setwidth') && g:R_setwidth == 2
        let start_options += ['options(nvimcom.setwidth = TRUE)']
    else
        let start_options += ['options(nvimcom.setwidth = FALSE)']
    endif
    if g:R_nvimpager == "no"
        let start_options += ['options(nvimcom.nvimpager = FALSE)']
    else
        let start_options += ['options(nvimcom.nvimpager = TRUE)']
    endif
    if type(g:R_external_term) == v:t_number && g:R_external_term == 0 && g:R_esc_term
        let start_options += ['options(editor = nvimcom:::nvim.edit)']
    endif
    if exists("g:R_csv_delim") && (g:R_csv_delim == "," || g:R_csv_delim == ";")
        let start_options += ['options(nvimcom.delim = "' . g:R_csv_delim. '")']
    else
        let start_options += ['options(nvimcom.delim = "\t")']
    endif
    let start_options += ['options(nvimcom.source.path = "' . s:Rsource_read . '")']

    let rwd = ""
    if g:R_nvim_wd == 0
        let rwd = expand("%:p:h")
    elseif g:R_nvim_wd == 1
        let rwd = getcwd()
    endif
    if rwd != ""
        if has("win32")
            let rwd = substitute(rwd, '\\', '/', 'g')
        endif

        " `rwd` will not be a real directory if editing a file on the internet
        " with netrw plugin
        if isdirectory(rwd)
            if has("win32") && &encoding == "utf-8"
                let start_options += ['.nvim.rwd <- "' . rwd . '"']
                let start_options += ['Encoding(.nvim.rwd) <- "UTF-8"']
                let start_options += ['setwd(.nvim.rwd)']
                let start_options += ['rm(.nvim.rwd)']
            else
                let start_options += ['setwd("' . rwd . '")']
            endif
        endif
    endif
    call writefile(start_options, g:rplugin.tmpdir . "/start_options.R")

    if exists("g:RStudio_cmd")
        call StartRStudio()
        return
    endif

    if type(g:R_external_term) == v:t_number && g:R_external_term == 0
        call StartR_InBuffer()
        return
    endif

    if g:R_applescript
        call StartR_OSX()
        return
    endif

    if has("win32")
        call StartR_Windows()
        return
    endif

    if IsSendCmdToRFake()
        return
    endif

    let args_str = join(g:rplugin.r_args)
    if args_str == ""
        let rcmd = g:rplugin.R
    else
        let rcmd = g:rplugin.R . " " . args_str
    endif

    call StartR_ExternalTerm(rcmd)
endfunction

" Send SIGINT to R
function SignalToR(signal)
    if s:R_pid
        call system('kill -s ' . a:signal . ' ' . s:R_pid)
    endif
endfunction

function SetSendCmdToR(...)
    if exists("g:RStudio_cmd")
        let g:SendCmdToR = function('SendCmdToRStudio')
    elseif type(g:R_external_term) == v:t_number && g:R_external_term == 0
        let g:SendCmdToR = function('SendCmdToR_Buffer')
    elseif has("win32")
        let g:SendCmdToR = function('SendCmdToR_Windows')
    endif
    let s:wait_nvimcom = 0
endfunction

function CheckIfNvimcomIsRunning(...)
    let s:nseconds = s:nseconds - 1
    if g:rplugin.nvimcom_port == 0
        if s:nseconds > 0
            call timer_start(1000, "CheckIfNvimcomIsRunning")
        else
            let msg = "The package nvimcom wasn't loaded yet. Please, quit R and try again."
            call RWarningMsg(msg)
            sleep 500m
        endif
    endif
endfunction

function WaitNvimcomStart()
    let args_str = join(g:rplugin.r_args)
    if args_str =~ "vanilla"
        return 0
    endif
    if g:R_wait < 2
        g:R_wait = 2
    endif

    let s:nseconds = g:R_wait
    call timer_start(1000, "CheckIfNvimcomIsRunning")
endfunction

function SetNvimcomInfo(nvimcomversion, nvimcomhome, bindportn, rpid, wid, r_info)
    if !exists("g:R_nvimcom_home") && a:nvimcomhome != s:nvimcom_home
        call RWarningMsg('Mismatch in directory names: "' . s:nvimcom_home . '" and "' . a:nvimcomhome . '"')
        sleep 1
    endif

    if s:nvimcom_version != a:nvimcomversion
        call RWarningMsg('Mismatch in nvimcom versions: "' . s:nvimcom_version . '" and "' . a:nvimcomversion . '"')
        sleep 1
    endif

    let g:rplugin.nvimcom_port = a:bindportn
    let s:R_pid = a:rpid
    let $RCONSOLE = a:wid

    let Rinfo = split(a:r_info, "\x02")
    let s:R_version = Rinfo[0]
    if !exists("g:R_OutDec")
        let g:R_OutDec = Rinfo[1]
    endif
    let g:Rout_prompt_str = substitute(Rinfo[2], ' $', '', '')
    let g:Rout_continue_str = substitute(Rinfo[3], ' $', '', '')
    let g:Rout_prompt_str = substitute(g:Rout_prompt_str, '.*#N#', '', '')
    let g:Rout_continue_str = substitute(g:Rout_continue_str, '.*#N#', '', '')

    if has('nvim') && has_key(g:rplugin, "R_bufname")
        " Put the cursor and the end of the buffer to ensure automatic scrolling
        " See: https://github.com/neovim/neovim/issues/2636
        let isnormal = mode() ==# 'n'
        let curwin = winnr()
        exe 'sb ' . g:rplugin.R_bufname
        if !exists('g:R_hl_term')
            if Rinfo[4] =~# 'colorout'
                let g:R_hl_term = 0
            else
                let g:R_hl_term = 1
                set syntax=rout
            endif
        endif
        call cursor('$', 1)
        exe curwin . 'wincmd w'
        if isnormal
            stopinsert
        endif
    endif

    if IsJobRunning("ClientServer")
        " Set RConsole window ID in nclientserver to ArrangeWindows()
        if has("win32")
            if $RCONSOLE == "0"
                call RWarningMsg("nvimcom did not save R window ID")
            endif
        endif
        " Set nvimcom port in nvimclient
        if has("win32")
            call JobStdin(g:rplugin.jobs["ClientServer"], "1" . g:rplugin.nvimcom_port . " " . $RCONSOLE . "\n")
        else
            call JobStdin(g:rplugin.jobs["ClientServer"], "1" . g:rplugin.nvimcom_port . "\n")
        endif
    else
        call RWarningMsg("nvimcom is not running")
    endif

    if exists("g:RStudio_cmd")
        if has("win32") && g:R_arrange_windows && filereadable(g:rplugin.compldir . "/win_pos")
            " ArrangeWindows
            call JobStdin(g:rplugin.jobs["ClientServer"], "75" . g:rplugin.compldir . "\n")
        endif
    elseif has("win32")
        if g:R_arrange_windows && filereadable(g:rplugin.compldir . "/win_pos")
            " ArrangeWindows
            call JobStdin(g:rplugin.jobs["ClientServer"], "75" . g:rplugin.compldir . "\n")
        endif
    elseif g:R_applescript
        call foreground()
        sleep 200m
    else
        call delete(g:rplugin.tmpdir . "/initterm_" . $NVIMR_ID . ".sh")
        call delete(g:rplugin.tmpdir . "/openR")
    endif

    if type(g:R_after_start) == 1
        " Backward compatibility: R_after_start was a string until November, 2019.
        if g:R_after_start != ''
            call system(g:R_after_start)
        endif
    elseif type(g:R_after_start) == 3
        for cmd in g:R_after_start
            if cmd =~ '^!'
                call system(substitute(cmd, '^!', '', ''))
            elseif cmd =~ '^:'
                exe substitute(cmd, '^:', '', '')
            else
                call RWarningMsg("R_after_start must be a list of strings starting with either '!' or ':'")
            endif
        endfor
    endif
    call timer_start(1000, "SetSendCmdToR")
endfunction

function StartObjBrowser()
    " Either open or close the Object Browser
    let savesb = &switchbuf
    set switchbuf=useopen,usetab
    if bufloaded(b:objbrtitle)
        let curwin = win_getid()
        exe "sb " . b:objbrtitle
        quit
        call win_gotoid(curwin)
    else
        " Copy the values of some local variables that will be inherited
        let g:tmp_objbrtitle = b:objbrtitle

        if g:R_objbr_place =~# 'RIGHT'
            sil exe 'botright vsplit ' . b:objbrtitle
        elseif g:R_objbr_place =~# 'LEFT'
            sil exe 'topleft vsplit ' . b:objbrtitle
        elseif g:R_objbr_place =~# 'TOP'
            sil exe 'topleft split ' . b:objbrtitle
        elseif g:R_objbr_place =~# 'BOTTOM'
            sil exe 'botright split ' . b:objbrtitle
        else
            if g:R_objbr_place =~? 'console'
                sil exe 'sb ' . g:rplugin.R_bufname
            endif
            if g:R_objbr_place =~# 'right'
                sil exe 'rightbelow vsplit ' . b:objbrtitle
            elseif g:R_objbr_place =~# 'left'
                sil exe 'leftabove vsplit ' . b:objbrtitle
            elseif g:R_objbr_place =~# 'above'
                sil exe 'aboveleft split ' . b:objbrtitle
            elseif g:R_objbr_place =~# 'below'
                sil exe 'belowright split ' . b:objbrtitle
            else
                call RWarningMsg('Invalid value for R_objbr_place: "' . R_objbr_place . '"')
                exe "set switchbuf=" . savesb
                return
            endif
        endif
        if g:R_objbr_place =~? 'left' || g:R_objbr_place =~? 'right'
            sil exe 'vertical resize ' . g:R_objbr_w
        else
            sil exe 'resize ' . g:R_objbr_h
        endif
        sil set filetype=rbrowser
        let g:rplugin.curview = "GlobalEnv"
        let g:rplugin.ob_winnr = win_getid()
        if exists("*nvim_win_get_buf")
            let g:rplugin.ob_buf = nvim_win_get_buf(g:rplugin.ob_winnr)
        endif

        " Inheritance of some local variables
        let b:objbrtitle = g:tmp_objbrtitle
        unlet g:tmp_objbrtitle
    endif
    exe "set switchbuf=" . savesb
endfunction

" Open an Object Browser window
function RObjBrowser()
    " Only opens the Object Browser if R is running
    if string(g:SendCmdToR) == "function('SendCmdToR_fake')"
        call RWarningMsg("The Object Browser can be opened only if R is running.")
        return
    endif

    if s:running_objbr == 1
        " Called twice due to BufEnter event
        return
    endif

    let s:running_objbr = 1

    call UpdateRGlobalEnv(1)
    call JobStdin(g:rplugin.jobs["ClientServer"], "31\n")
    call SendToNvimcom("\002" . $NVIMR_ID)

    call StartObjBrowser()
    let s:running_objbr = 0

    if len(g:R_after_ob_open) > 0
        redraw
        for cmd in g:R_after_ob_open
            exe substitute(cmd, '^:', '', '')
        endfor
    endif

    return
endfunction

function RBrOpenCloseLs(stt)
    call JobStdin(g:rplugin.jobs["ClientServer"], "34" . a:stt . g:rplugin.curview . "\n")
endfunction

let s:wait_nvimcom = 0
function SendToNvimcom(cmd)
    if s:wait_nvimcom
        if string(g:SendCmdToR) == "function('SendCmdToR_fake')"
            call RWarningMsg("R is not running")
        elseif string(g:SendCmdToR) == "function('SendCmdToR_NotYet')"
            call RWarningMsg("R is not ready yet")
        endif
        return
    endif

    if !IsJobRunning("ClientServer")
        call RWarningMsg("ClientServer not running.")
        return
    endif
    call JobStdin(g:rplugin.jobs["ClientServer"], "2" . a:cmd . "\n")
endfunction

" This function is called by nclientserver
function RSetMyPort(p)
    let g:rplugin.myport = a:p
    let $NVIMR_PORT = a:p
    let s:starting_ncs = 0

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

" No support for break points
"if synIDattr(synIDtrans(hlID("SignColumn")), "bg") =~ '^#'
"    exe 'hi def StopSign guifg=red guibg=' . synIDattr(synIDtrans(hlID("SignColumn")), "bg")
"else
"    exe 'hi def StopSign ctermfg=red ctermbg=' . synIDattr(synIDtrans(hlID("SignColumn")), "bg")
"endif
"call sign_define('stpline', {'text': '●', 'texthl': 'StopSign', 'linehl': 'None', 'numhl': 'None'})

" Functions sign_define(), sign_place() and sign_unplace() require Neovim >= 0.4.3
"call sign_define('dbgline', {'text': '▬▶', 'texthl': 'SignColumn', 'linehl': 'QuickFixLine', 'numhl': 'Normal'})

if &ambiwidth == "double" || (has("win32") && !has("nvim"))
    sign define dbgline text==> texthl=SignColumn linehl=QuickFixLine
else
    sign define dbgline text=▬▶ texthl=SignColumn linehl=QuickFixLine
endif

let s:func_offset = -2
let s:rdebugging = 0
function StopRDebugging()
    if !g:R_debug
        return
    endif
    "call sign_unplace('rdebugcurline')
    "sign unplace rdebugcurline
    sign unplace 1
    let s:func_offset = -2 " Did not seek yet
    let s:rdebugging = 0
endfunction

function FindDebugFunc(srcref)
    if type(g:R_external_term) == v:t_number && g:R_external_term == 0
        let s:func_offset = -1 " Not found
        let sbopt = &switchbuf
        set switchbuf=useopen,usetab
        let curtab = tabpagenr()
        let isnormal = mode() ==# 'n'
        let curwin = winnr()
        exe 'sb ' . g:rplugin.R_bufname
        sleep 30m " Time to fill the buffer lines
        let rlines = getline(1, "$")
        exe 'sb ' . g:rplugin.rscript_name
    elseif string(g:SendCmdToR) == "function('SendCmdToR_Term')"
        let tout = system('tmux -L NvimR capture-pane -p -t ' . g:rplugin.tmuxsname)
        let rlines = split(tout, "\n")
    elseif string(g:SendCmdToR) == "function('SendCmdToR_TmuxSplit')"
        let tout = system('tmux capture-pane -p -t ' . g:rplugin.rconsole_pane)
        let rlines = split(tout, "\n")
    else
        let rlines = []
    endif

    let idx = len(rlines) - 1
    while idx > 0
        if rlines[idx] =~# '^debugging in: '
            let funcnm = substitute(rlines[idx], '^debugging in: \(.\{-}\)(.*', '\1', '')
            let s:func_offset = search('.*\<' . funcnm . '\s*<-\s*function\s*(', 'b')
            if s:func_offset > 0
                let s:func_offset -= 1
            endif
            if a:srcref == '<text>'
                if &filetype == 'rmd'
                    let s:func_offset = search('^\s*```\s*{\s*r', 'nb')
                elseif &filetype == 'rnoweb'
                    let s:func_offset = search('^<<', 'nb')
                endif
            endif
            break
        endif
        let idx -= 1
    endwhile

    if type(g:R_external_term) == v:t_number && g:R_external_term == 0
        if tabpagenr() != curtab
            exe 'normal! ' . curtab . 'gt'
        endif
        exe curwin . 'wincmd w'
        if isnormal
            stopinsert
        endif
        exe 'set switchbuf=' . sbopt
    endif
endfunction

function RDebugJump(fnm, lnum)
    if !g:R_debug
        return
    endif
    if a:fnm == '' || a:fnm == '<text>'
        " Functions sent directly to R Console have no associated source file
        " and functions sourced by knitr have '<text>' as source reference.
        if s:func_offset == -2
            call FindDebugFunc(a:fnm)
        endif
        if s:func_offset <= 0
            return
        endif
    endif

    if s:func_offset > 0
        let flnum = a:lnum + s:func_offset
        let fname = g:rplugin.rscript_name
    else
        let flnum = a:lnum
        let fname = expand(a:fnm)
    endif

    let bname = bufname("%")

    if !bufloaded(fname) && fname != g:rplugin.rscript_name && fname != expand("%") && fname != expand("%:p")
        if filereadable(fname)
            exe 'sb ' . g:rplugin.rscript_name
            if &modified
                split
            endif
            exe 'edit ' . fname
        elseif glob("*") =~ fname
            exe 'sb ' . g:rplugin.rscript_name
            if &modified
                split
            endif
            exe 'edit ' . fname
        else
            return
        endif
    endif

    if bufloaded(fname)
        exe 'sb ' . fname
        exe ':' . flnum
    endif

    " Call sign_place() and sign_unplace() when requiring Vim 8.2 and Neovim 0.5
    "call sign_unplace('rdebugcurline')
    "call sign_place(1, 'rdebugcurline', 'dbgline', fname, {'lnum': flnum})
    sign unplace 1
    exe 'sign place 1 line=' . flnum . ' name=dbgline file=' . fname
    if g:R_dbg_jump && !s:rdebugging && type(g:R_external_term) == v:t_number && g:R_external_term == 0
        exe 'sb ' . g:rplugin.R_bufname
        startinsert
    else
        exe 'sb ' . bname
    endif
    let s:rdebugging = 1
endfunction

function RFormatCode() range
    if g:rplugin.nvimcom_port == 0
        return
    endif

    let lns = getline(a:firstline, a:lastline)
    call writefile(lns, g:rplugin.tmpdir . "/unformatted_code")
    call AddForDeletion(g:rplugin.tmpdir . "/unformatted_code")
    call AddForDeletion(g:rplugin.tmpdir . "/formatted_code")

    let wco = &textwidth
    if wco == 0
        let wco = 78
    elseif wco < 20
        let wco = 20
    elseif wco > 180
        let wco = 180
    endif

    call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim_format(' . a:firstline . ', ' . a:lastline . ', ' . wco . ', ' . &shiftwidth. ')')
endfunction

function FinishRFormatCode(lnum1, lnum2)
    let lns = readfile(g:rplugin.tmpdir . "/formatted_code")
    silent exe a:lnum1 . "," . a:lnum2 . "delete"
    call append(a:lnum1 - 1, lns)
    call delete(g:rplugin.tmpdir . "/formatted_code")
    call delete(g:rplugin.tmpdir . "/unformatted_code")
    echo (a:lnum2 - a:lnum1 + 1) . " lines formatted."
endfunction

function RInsert(cmd, type)
    if g:rplugin.nvimcom_port == 0
        return
    endif

    call delete(g:rplugin.tmpdir . "/Rinsert")
    call AddForDeletion(g:rplugin.tmpdir . "/Rinsert")

    call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim_insert(' . a:cmd . ', "' . a:type . '")')
endfunction

function SendLineToRAndInsertOutput()
    let lin = getline(".")
    let cleanl = substitute(lin, '".\{-}"', '', 'g')
    if cleanl =~ ';'
        call RWarningMsg('`print(line)` works only if `line` is a single command')
    endif
    let cleanl = substitute(lin, '\s*#.*', "", "")
    call RInsert("print(" . cleanl . ")", "comment")
endfunction

function ShowRObj(howto, bname, ftype)
    let bfnm = substitute(a:bname, '[ [:punct:]]', '_', 'g')
    call AddForDeletion(g:rplugin.tmpdir . "/" . bfnm)
    silent exe a:howto . ' ' . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . '/' . bfnm
    silent exe 'set ft=' . a:ftype
    let objf = readfile(g:rplugin.tmpdir . "/Rinsert")
    call setline(1, objf)
    set nomodified
endfunction

function FinishRInsert(type)
    silent exe "read " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . "/Rinsert"

    if a:type == "comment"
        let curpos = getpos(".")
        " comment the output
        let ilines = readfile(g:rplugin.tmpdir . "/Rinsert")
        for iln in ilines
            call RSimpleCommentLine("normal", "c")
            normal! j
        endfor
        call setpos(".", curpos)
    endif
endfunction

" Function to send commands
" return 0 on failure and 1 on success
function SendCmdToR_fake(...)
    call RWarningMsg("Did you already start R?")
    return 0
endfunction

function SendCmdToR_NotYet(...)
    call RWarningMsg("Not ready yet")
    return 0
endfunction

" Get the word either under or after the cursor.
" Works for word(| where | is the cursor position.
function RGetKeyword(iskw)
    " Go back some columns if character under cursor is not valid
    let save_cursor = getpos(".")
    let curline = line(".")
    let line = getline(curline)
    if strlen(line) == 0
        return ""
    endif
    " line index starts in 0; cursor index starts in 1:
    let i = col(".") - 1
    while i > 0 && "({[ " =~ line[i]
        call setpos(".", [0, line("."), i])
        let i -= 1
    endwhile
    let save_keyword = &iskeyword
    exe "setlocal iskeyword=" . a:iskw
    let rkeyword = expand("<cword>")
    exe "setlocal iskeyword=" . save_keyword
    call setpos(".", save_cursor)
    return rkeyword
endfunction

function GetROutput(outf)
    if a:outf =~ g:rplugin.tmpdir
        let tnum = 1
        while bufexists("so" . tnum)
            let tnum += 1
        endwhile
        exe 'tabnew so' . tnum
        exe 'read ' . substitute(a:outf, " ", '\\ ', 'g')
        set filetype=rout
        setlocal buftype=nofile
        setlocal noswapfile
    else
        exe 'tabnew ' . substitute(a:outf, " ", '\\ ', 'g')
    endif
    normal! gT
    redraw
endfunction

function RViewDF(oname, ...)
    if exists('g:R_csv_app')
        let tsvnm = g:rplugin.tmpdir . '/' . a:oname . '.tsv'
        call system('cp "' . g:rplugin.tmpdir . '/Rinsert" "' . tsvnm . '"')
        call AddForDeletion(tsvnm)

        if g:R_csv_app =~# '^terminal:'
            let csv_app = split(g:R_csv_app, ':')[1]
            if executable(csv_app)
                tabnew
                exe 'terminal ' . csv_app . ' ' . substitute(tsvnm, ' ', '\\ ', 'g')
                startinsert
            else
                call RWarningMsg('R_csv_app ("' . csv_app . '") is not executable')
            endif
            return
        elseif g:R_csv_app =~# '^tmux new-window '
            let csv_app = substitute(g:R_csv_app, '^tmux new-window *', '', '')
            if !executable(csv_app)
                call RWarningMsg('R_csv_app ("' . csv_app . '") is not executable')
                return
            endif
        elseif !executable(g:R_csv_app) && !executable(split(g:R_csv_app)[0])
            call RWarningMsg('R_csv_app ("' . g:R_csv_app . '") is not executable')
            return
        endif

        normal! :<Esc>
        if has("nvim")
            let appcmd = split(g:R_csv_app) + [tsvnm]
            call jobstart(appcmd, {'detach': v:true})
        elseif has("win32")
            silent exe '!start "' . g:R_csv_app . '" "' . tsvnm . '"'
        else
            call system(g:R_csv_app . ' "' . tsvnm . '" >/dev/null 2>/dev/null &')
        endif
        return
    endif

    let location = get(a:, 1, "tabnew")
    silent exe location . ' ' . a:oname
    silent 1,$d
    silent exe 'read ' . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . '/Rinsert'
    silent 1d
    setlocal filetype=csv
    setlocal nomodified
    setlocal bufhidden=wipe
    setlocal noswapfile
    set buftype=nofile
    redraw
endfunction

function GetSourceArgs(e)
    let sargs = ""
    if g:R_source_args != ""
        let sargs = ", " . g:R_source_args
    endif
    if a:e == "echo"
        let sargs .= ', echo=TRUE'
    endif
    return sargs
endfunction

" Send sources to R
function RSourceLines(...)
    let lines = a:1
    if &filetype == "rrst"
        let lines = map(copy(lines), 'substitute(v:val, "^\\.\\. \\?", "", "")')
    endif
    if &filetype == "rmd"
        let lines = map(copy(lines), 'substitute(v:val, "^(\\`\\`)\\?", "", "")')
    endif
    if !g:R_commented_lines
        let newlines = []
        for line in lines
            if line !~ '^\s*#'
                call add(newlines, line)
            endif
        endfor
        let lines = newlines
    endif

    if a:0 == 3 && a:3 == "NewtabInsert"
        call writefile(lines, s:Rsource_write)
        call AddForDeletion(g:rplugin.tmpdir . '/Rinsert')
        call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim_capture_source_output("' . s:Rsource_read . '", "' . g:rplugin.tmpdir . '/Rinsert")')
        return 1
    endif

    " The "brackted paste" option is not documented because it is not well
    " tested and source() have always worked flawlessly.
    if g:R_source_args == "bracketed paste"
        let rcmd = "\x1b[200~" . join(lines, "\n") . "\x1b[201~"
    else
        call writefile(lines, s:Rsource_write)
        let sargs = substitute(GetSourceArgs(a:2), '^, ', '', '')
        if a:0 == 3
            let rcmd = 'NvimR.' . a:3 . '(' . sargs . ')'
        else
            let rcmd = 'NvimR.source(' . sargs . ')'
        endif
    endif

    if a:0 == 3 && a:3 == "PythonCode"
        let rcmd = 'reticulate::py_run_file("' . s:Rsource_read . '")'
    endif

    let ok = g:SendCmdToR(rcmd)
    return ok
endfunction

" Send motion to R
function SendMotionToR(type)
    let lstart = line("'[")
    let lend = line("']")
    if lstart == lend
        call SendLineToR("stay", lstart)
    else
        let lines = getline(lstart, lend)
        call RSourceLines(lines, "", "block")
    endif
endfunction

" Send file to R
function SendFileToR(e)
    let flines = getline(1, "$")
    let fpath = expand("%:p") . ".tmp.R"

    if filereadable(fpath)
        call RWarningMsg('Error: cannot create "' . fpath . '" because it already exists. Please, delete it.')
        return
    endif

    if has("win32")
        let fpath = substitute(fpath, "\\", "/", "g")
    endif
    call writefile(flines, fpath)
    call AddForDeletion(fpath)
    let sargs = GetSourceArgs(a:e)
    let ok = g:SendCmdToR('nvimcom:::source.and.clean("' . fpath .  '"' . sargs . ')')
    if !ok
        call delete(fpath)
    endif
endfunction

" Send block to R
" Adapted from marksbrowser plugin
" Function to get the marks which the cursor is between
function SendMBlockToR(e, m)
    if &filetype != "r" && b:IsInRCode(1) == 0
        return
    endif

    let curline = line(".")
    let lineA = 1
    let lineB = line("$")
    let maxmarks = strlen(s:all_marks)
    let n = 0
    while n < maxmarks
        let c = strpart(s:all_marks, n, 1)
        let lnum = line("'" . c)
        if lnum != 0
            if lnum <= curline && lnum > lineA
                let lineA = lnum
            elseif lnum > curline && lnum < lineB
                let lineB = lnum
            endif
        endif
        let n = n + 1
    endwhile
    if lineA == 1 && lineB == (line("$"))
        call RWarningMsg("The file has no mark!")
        return
    endif
    if lineB < line("$")
        let lineB -= 1
    endif
    let lines = getline(lineA, lineB)
    let ok = RSourceLines(lines, a:e, "block")
    if ok == 0
        return
    endif
    if a:m == "down" && lineB != line("$")
        call cursor(lineB, 1)
        call GoDown()
    endif
endfunction

" Send functions to R
function SendFunctionToR(e, m)
    if &filetype != "r" && b:IsInRCode(1) == 0
        return
    endif

    let startline = line(".")
    let save_cursor = getpos(".")
    let line = SanitizeRLine(getline("."))
    let i = line(".")
    while i > 0 && line !~ "function"
        let i -= 1
        let line = SanitizeRLine(getline(i))
    endwhile
    if i == 0
        call RWarningMsg("Begin of function not found.")
        return
    endif
    let functionline = i
    while i > 0 && line !~ '\(<-\|=\)[[:space:]]*\($\|function\)'
        let i -= 1
        let line = SanitizeRLine(getline(i))
    endwhile
    if i == 0
        call RWarningMsg("The function assign operator  <-  was not found.")
        return
    endif
    let firstline = i
    let i = functionline
    let line = SanitizeRLine(getline(i))
    let tt = line("$")
    while i < tt && line !~ "{"
        let i += 1
        let line = SanitizeRLine(getline(i))
    endwhile
    if i == tt
        call RWarningMsg("The function opening brace was not found.")
        return
    endif
    let nb = CountBraces(line)
    while i < tt && nb > 0
        let i += 1
        let line = SanitizeRLine(getline(i))
        let nb += CountBraces(line)
    endwhile
    if nb != 0
        call RWarningMsg("The function closing brace was not found.")
        return
    endif
    let lastline = i

    if startline > lastline
        call setpos(".", [0, firstline - 1, 1])
        call SendFunctionToR(a:e, a:m)
        call setpos(".", save_cursor)
        return
    endif

    let lines = getline(firstline, lastline)
    let ok = RSourceLines(lines, a:e, "function")
    if  ok == 0
        return
    endif
    if a:m == "down"
        call cursor(lastline, 1)
        call GoDown()
    endif
endfunction

" Send all lines above to R
function SendAboveLinesToR()
    let lines = getline(1, line(".") - 1)
    call RSourceLines(lines, "")
endfunction

" Send selection to R
function SendSelectionToR(...)
    let ispy = 0
    if &filetype != "r"
        if &filetype == 'rmd' && RmdIsInPythonCode(0)
            let ispy = 1
        elseif b:IsInRCode(0) == 0
            if (&filetype == "rnoweb" && getline(".") !~ "\\Sexpr{") || (&filetype == "rmd" && getline(".") !~ "`r ") || (&filetype == "rrst" && getline(".") !~ ":r:`")
                call RWarningMsg("Not inside an R code chunk.")
                return
            endif
        endif
    endif

    if line("'<") == line("'>")
        let i = col("'<") - 1
        let j = col("'>") - i
        let l = getline("'<")
        let line = strpart(l, i, j)
        if &filetype == "r"
            let line = CleanOxygenLine(line)
        endif
        let ok = g:SendCmdToR(line)
        if ok && a:2 =~ "down"
            call GoDown()
        endif
        return
    endif

    let lines = getline("'<", "'>")

    if visualmode() == "\<C-V>"
        let lj = line("'<")
        let cj = col("'<")
        let lk = line("'>")
        let ck = col("'>")
        if cj > ck
            let bb = ck - 1
            let ee = cj - ck + 1
        else
            let bb = cj - 1
            let ee = ck - cj + 1
        endif
        if cj > len(getline(lj)) || ck > len(getline(lk))
            for idx in range(0, len(lines) - 1)
                let lines[idx] = strpart(lines[idx], bb)
            endfor
        else
            for idx in range(0, len(lines) - 1)
                let lines[idx] = strpart(lines[idx], bb, ee)
            endfor
        endif
    else
        let i = col("'<") - 1
        let j = col("'>")
        let lines[0] = strpart(lines[0], i)
        let llen = len(lines) - 1
        let lines[llen] = strpart(lines[llen], 0, j)
    endif

    let curpos = getpos(".")
    let curline = line("'<")
    for idx in range(0, len(lines) - 1)
        call setpos(".", [0, curline, 1, 0])
        if &filetype == "r"
            let lines[idx] = CleanOxygenLine(lines[idx])
        endif
        let curline += 1
    endfor
    call setpos(".", curpos)

    if a:0 == 3 && a:3 == "NewtabInsert"
        let ok = RSourceLines(lines, a:1, "NewtabInsert")
    elseif ispy
        let ok = RSourceLines(lines, a:1, 'PythonCode')
    else
        let ok = RSourceLines(lines, a:1, 'selection')
    endif

    if ok == 0
        return
    endif

    if a:2 == "down"
        call GoDown()
    else
        if a:0 < 3 || (a:0 == 3 && a:3 != "normal")
            normal! gv
        endif
    endif
endfunction

" Send paragraph to R
function SendParagraphToR(e, m)
    if &filetype != "r" && b:IsInRCode(1) == 0
        return
    endif

    let o = line(".")
    let c = col(".")
    let i = o
    if g:R_paragraph_begin && getline(i) !~ '^\s*$'
        let line = getline(i-1)
        while i > 1 && !(line =~ '^\s*$' ||
                    \ (&filetype == "rnoweb" && line =~ "^<<") ||
                    \ (&filetype == "rmd" && line =~ "^[ \t]*```{\\(r\\|python\\)"))
            let i -= 1
            let line = getline(i-1)
        endwhile
    endif
    let max = line("$")
    let j = i
    let gotempty = 0
    while j < max
        let line = getline(j+1)
        if line =~ '^\s*$' ||
                    \ (&filetype == "rnoweb" && line =~ "^@$") ||
                    \ (&filetype == "rmd" && line =~ "^[ \t]*```$")
            break
        endif
        let j += 1
    endwhile
    let lines = getline(i, j)
    let ok = RSourceLines(lines, a:e, "paragraph")
    if ok == 0
        return
    endif
    if j < max
        call cursor(j, 1)
    else
        call cursor(max, 1)
    endif
    if a:m == "down"
        call GoDown()
    else
        call cursor(o, c)
    endif
endfunction

" Send R code from the first chunk up to current line
function SendFHChunkToR()
    if &filetype == "rnoweb"
        let begchk = "^<<.*>>=\$"
        let endchk = "^@"
        let chdchk = "^<<.*child *= *"
    elseif &filetype == "rmd"
        let begchk = "^[ \t]*```[ ]*{r"
        let endchk = "^[ \t]*```$"
        let chdchk = "^```.*child *= *"
    elseif &filetype == "rrst"
        let begchk = "^\\.\\. {r"
        let endchk = "^\\.\\. \\.\\."
        let chdchk = "^\.\. {r.*child *= *"
    else
        " Should never happen
        call RWarningMsg('Strange filetype (SendFHChunkToR): "' . &filetype . '"')
    endif

    let codelines = []
    let here = line(".")
    let curbuf = getline(1, "$")
    let idx = 0
    while idx < here
        if curbuf[idx] =~ begchk && curbuf[idx] !~ '\<eval\s*=\s*F'
            " Child R chunk
            if curbuf[idx] =~ chdchk
                " First run everything up to child chunk and reset buffer
                call RSourceLines(codelines, "silent", "chunk")
                let codelines = []

                " Next run child chunk and continue
                call KnitChild(curbuf[idx], 'stay')
                let idx += 1
                " Regular R chunk
            else
                let idx += 1
                while curbuf[idx] !~ endchk && idx < here
                    let codelines += [curbuf[idx]]
                    let idx += 1
                endwhile
            endif
        else
            let idx += 1
        endif
    endwhile
    call RSourceLines(codelines, "silent", "chunk")
endfunction

function KnitChild(line, godown)
    let nline = substitute(a:line, '.*child *= *', "", "")
    let cfile = substitute(nline, nline[0], "", "")
    let cfile = substitute(cfile, nline[0] . '.*', "", "")
    if filereadable(cfile)
        let ok = g:SendCmdToR("require(knitr); knit('" . cfile . "', output=" . s:null . ")")
        if a:godown =~ "down"
            call cursor(line(".")+1, 1)
            call GoDown()
        endif
    else
        call RWarningMsg("File not found: '" . cfile . "'")
    endif
endfunction

function RParenDiff(str)
    let clnln = substitute(a:str, '\\"',  "", "g")
    let clnln = substitute(clnln, "\\\\'",  "", "g")
    let clnln = substitute(clnln, '".\{-}"',  '', 'g')
    let clnln = substitute(clnln, "'.\\{-}'",  "", "g")
    let clnln = substitute(clnln, "#.*", "", "g")
    let llen1 = strlen(substitute(clnln, '[{(\[]', '', 'g'))
    let llen2 = strlen(substitute(clnln, '[})\]]', '', 'g'))
    return llen1 - llen2
endfunction

" Send current line to R.
function SendLineToR(godown, ...)
    let lnum = get(a:, 1, ".")
    let line = getline(lnum)
    if strlen(line) == 0
        if a:godown =~ "down"
            call GoDown()
        endif
        return
    endif

    if &filetype == "rnoweb"
        if line == "@"
            if a:godown =~ "down"
                call GoDown()
            endif
            return
        endif
        if line =~ "^<<.*child *= *"
            call KnitChild(line, a:godown)
            return
        endif
        if RnwIsInRCode(1) == 0
            return
        endif
    endif

    if &filetype == "rmd"
        if line == "```"
            if a:godown =~ "down"
                call GoDown()
            endif
            return
        endif
        if line =~ "^```.*child *= *"
            call KnitChild(line, a:godown)
            return
        endif
        let line = substitute(line, "^(\\`\\`)\\?", "", "")
        if RmdIsInRCode(0) == 0
            if RmdIsInPythonCode(0) == 0
                call RWarningMsg("Not inside an R code chunk.")
                return
            else
                let line = 'reticulate::py_run_string("' . substitute(line, '"', '\\"', 'g') . '")'
            endif
        endif
    endif

    if &filetype == "rrst"
        if line == ".. .."
            if a:godown =~ "down"
                call GoDown()
            endif
            return
        endif
        if line =~ "^\.\. {r.*child *= *"
            call KnitChild(line, a:godown)
            return
        endif
        let line = substitute(line, "^\\.\\. \\?", "", "")
        if RrstIsInRCode(1) == 0
            return
        endif
    endif

    if &filetype == "rdoc"
        if getline(1) =~ '^The topic'
            let topic = substitute(line, '.*::', '', "")
            let package = substitute(line, '::.*', '', "")
            call AskRDoc(topic, package, 1)
            return
        endif
        if RdocIsInRCode(1) == 0
            return
        endif
    endif

    if &filetype == "rhelp" && RhelpIsInRCode(1) == 0
        return
    endif

    if &filetype == "r"
        let line = CleanOxygenLine(line)
    endif

    let block = 0
    if g:R_parenblock
        let chunkend = ""
        if &filetype == "rmd"
            let chunkend = "```"
        elseif &filetype == "rnoweb"
            let chunkend = "@"
        elseif &filetype == "rrst"
            let chunkend = ".. .."
        endif
        let rpd = RParenDiff(line)
        let has_op = line =~ '%>%\s*$'
        if rpd < 0
            let line1 = line(".")
            let cline = line1 + 1
            while cline <= line("$")
                let txt = getline(cline)
                if chunkend != "" && txt == chunkend
                    break
                endif
                let rpd += RParenDiff(txt)
                if rpd == 0
                    let has_op = getline(cline) =~ '%>%\s*$'
                    for lnum in range(line1, cline)
                        if g:R_bracketed_paste
                            if lnum == line1 && lnum == cline
                                let ok = g:SendCmdToR("\x1b[200~" . getline(lnum) . "\x1b[201~\n", 0)
                            elseif lnum == line1
                                let ok = g:SendCmdToR("\x1b[200~" . getline(lnum))
                            elseif lnum == cline
                                let ok = g:SendCmdToR(getline(lnum) . "\x1b[201~\n", 0)
                            else
                                let ok = g:SendCmdToR(getline(lnum))
                            endif
                        else
                            let ok = g:SendCmdToR(getline(lnum))
                        end
                        if !ok
                            " always close bracketed mode upon failure
                            if g:R_bracketed_paste
                                call g:SendCmdToR("\x1b[201~\n", 0)
                            end
                            return
                        endif
                    endfor
                    call cursor(cline, 1)
                    let block = 1
                    break
                endif
                let cline += 1
            endwhile
        endif
    endif

    if !block
        if g:R_bracketed_paste
            let ok = g:SendCmdToR("\x1b[200~" . line . "\x1b[201~\n", 0)
        else
            let ok = g:SendCmdToR(line)
        end
    endif

    if ok
        if a:godown =~ "down"
            call GoDown()
            if exists('has_op') && has_op
                call SendLineToR(a:godown)
            endif
        else
            if a:godown == "newline"
                normal! o
            endif
        endif
    endif
endfunction

function RSendPartOfLine(direction, correctpos)
    let lin = getline(".")
    let idx = col(".") - 1
    if a:correctpos
        call cursor(line("."), idx)
    endif
    if a:direction == "right"
        let rcmd = strpart(lin, idx)
    else
        let rcmd = strpart(lin, 0, idx + 1)
    endif
    call g:SendCmdToR(rcmd)
endfunction

" Clear the console screen
function RClearConsole()
    if g:R_clear_console == 0
        return
    endif
    if has("win32") && type(g:R_external_term) == v:t_number && g:R_external_term == 1
        call JobStdin(g:rplugin.jobs["ClientServer"], "76\n")
        sleep 50m
        call JobStdin(g:rplugin.jobs["ClientServer"], "77\n")
    else
        call g:SendCmdToR("\014", 0)
    endif
endfunction

" Remove all objects
function RClearAll()
    if g:R_rmhidden
        call g:SendCmdToR("rm(list=ls(all.names = TRUE))")
    else
        call g:SendCmdToR("rm(list=ls())")
    endif
    sleep 500m
    call RClearConsole()
endfunction

"Set working directory to the path of current buffer
function RSetWD()
    let wdcmd = 'setwd("' . expand("%:p:h") . '")'
    if has("win32")
        let wdcmd = substitute(wdcmd, "\\", "/", "g")
    endif
    call g:SendCmdToR(wdcmd)
    sleep 100m
endfunction

function ClearRInfo()
    call delete(g:rplugin.tmpdir . "/globenv_" . $NVIMR_ID)
    call delete(g:rplugin.tmpdir . "/liblist_" . $NVIMR_ID)
    call delete(g:rplugin.tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    for fn in s:del_list
        call delete(fn)
    endfor
    let g:SendCmdToR = function('SendCmdToR_fake')
    let s:R_pid = 0
    let g:rplugin.nvimcom_port = 0

    " Legacy support for running R in a Tmux split pane
    if has_key(g:rplugin, "tmux_split") && exists('g:R_tmux_title') && g:rplugin.tmux_split
                \ && g:R_tmux_title != 'automatic' && g:R_tmux_title != ''
        call system("tmux set automatic-rename on")
    endif

    if type(g:R_external_term) == v:t_number && g:R_external_term == 0 && has("nvim")
        call CloseRTerm()
    endif

endfunction

" Quit R
function RQuit(how)
    if exists("b:quit_command")
        let qcmd = b:quit_command
    else
        if a:how == "save"
            let qcmd = 'quit(save = "yes")'
        else
            let qcmd = 'quit(save = "no")'
        endif
    endif

    if has("win32") && type(g:R_external_term) == v:t_number && g:R_external_term == 1
        " SaveWinPos
        call JobStdin(g:rplugin.jobs["ClientServer"], "74" . $NVIMR_COMPLDIR . "\n")
    endif

    if bufloaded(b:objbrtitle)
        exe "bunload! " . b:objbrtitle
        sleep 30m
    endif

    call g:SendCmdToR(qcmd)

    if has_key(g:rplugin, "tmux_split") || a:how == 'save'
        sleep 200m
    endif

    sleep 50m
    call ClearRInfo()
endfunction

" knit the current buffer content
function RKnit()
    update
    if has("win32")
        call g:SendCmdToR('require(knitr); .nvim_oldwd <- getwd(); setwd("' . substitute(expand("%:p:h"), '\\', '/', 'g') . '"); knit("' . expand("%:t") . '"); setwd(.nvim_oldwd); rm(.nvim_oldwd)')
    else
        call g:SendCmdToR('require(knitr); .nvim_oldwd <- getwd(); setwd("' . expand("%:p:h") . '"); knit("' . expand("%:t") . '"); setwd(.nvim_oldwd); rm(.nvim_oldwd)')
    endif
endfunction

function SetRTextWidth(rkeyword)
    if g:R_nvimpager == "tabnew"
        let s:rdoctitle = a:rkeyword
    else
        let s:tnr = tabpagenr()
        if g:R_nvimpager != "tab" && s:tnr > 1
            let s:rdoctitle = "R_doc" . s:tnr
        else
            let s:rdoctitle = "R_doc"
        endif
        unlet s:tnr
    endif
    if !bufloaded(s:rdoctitle) || g:R_newsize == 1
        let g:R_newsize = 0

        " s:vimpager is used to calculate the width of the R help documentation
        " and to decide whether to obey R_nvimpager = 'vertical'
        let s:vimpager = g:R_nvimpager

        let wwidth = winwidth(0)

        " Not enough room to split vertically
        if g:R_nvimpager == "vertical" && wwidth <= (g:R_help_w + g:R_editor_w)
            let s:vimpager = "horizontal"
        endif

        if s:vimpager == "horizontal"
            " Use the window width (at most 80 columns)
            let htwf = (wwidth > 80) ? 88.1 : ((wwidth - 1) / 0.9)
        elseif g:R_nvimpager == "tab" || g:R_nvimpager == "tabnew"
            let wwidth = &columns
            let htwf = (wwidth > 80) ? 88.1 : ((wwidth - 1) / 0.9)
        else
            let min_e = (g:R_editor_w > 80) ? g:R_editor_w : 80
            let min_h = (g:R_help_w > 73) ? g:R_help_w : 73

            if wwidth > (min_e + min_h)
                " The editor window is large enough to be split
                let s:hwidth = min_h
            elseif wwidth > (min_e + g:R_help_w)
                " The help window must have less than min_h columns
                let s:hwidth = wwidth - min_e
            else
                " The help window must have the minimum value
                let s:hwidth = g:R_help_w
            endif
            let htwf = (s:hwidth - 1) / 0.9
        endif
        let htw = printf("%f", htwf)
        let s:htw = substitute(htw, "\\..*", "", "")
        let s:htw = s:htw - (&number || &relativenumber) * &numberwidth
    endif
endfunction

function RGetFirstObj(rkeyword)
    let firstobj = ""
    let line = substitute(getline("."), '#.*', '', "")
    let begin = col(".")
    if strlen(line) > begin
        let piece = strpart(line, begin)
        while piece !~ '^' . a:rkeyword && begin >= 0
            let begin -= 1
            let piece = strpart(line, begin)
        endwhile
        let line = piece
        if line !~ '^\k*\s*('
            return firstobj
        endif
        let begin = 1
        let linelen = strlen(line)
        while line[begin] != '(' && begin < linelen
            let begin += 1
        endwhile
        let begin += 1
        let line = strpart(line, begin)
        let line = substitute(line, '^\s*', '', "")
        if (line =~ '^\k*\s*(' || line =~ '^\k*\s*=\s*\k*\s*(') && line !~ '[.*('
            let idx = 0
            while line[idx] != '('
                let idx += 1
            endwhile
            let idx += 1
            let nparen = 1
            let len = strlen(line)
            let lnum = line(".")
            while nparen != 0
                if idx == len
                    let lnum += 1
                    while lnum <= line("$") && strlen(substitute(getline(lnum), '#.*', '', "")) == 0
                        let lnum += 1
                    endwhile
                    if lnum > line("$")
                        return ""
                    endif
                    let line = line . substitute(getline(lnum), '#.*', '', "")
                    let len = strlen(line)
                endif
                if line[idx] == '('
                    let nparen += 1
                else
                    if line[idx] == ')'
                        let nparen -= 1
                    endif
                endif
                let idx += 1
            endwhile
            let firstobj = strpart(line, 0, idx)
        elseif line =~ '^\(\k\|\$\)*\s*[' || line =~ '^\(k\|\$\)*\s*=\s*\(\k\|\$\)*\s*[.*('
            let idx = 0
            while line[idx] != '['
                let idx += 1
            endwhile
            let idx += 1
            let nparen = 1
            let len = strlen(line)
            let lnum = line(".")
            while nparen != 0
                if idx == len
                    let lnum += 1
                    while lnum <= line("$") && strlen(substitute(getline(lnum), '#.*', '', "")) == 0
                        let lnum += 1
                    endwhile
                    if lnum > line("$")
                        return ""
                    endif
                    let line = line . substitute(getline(lnum), '#.*', '', "")
                    let len = strlen(line)
                endif
                if line[idx] == '['
                    let nparen += 1
                else
                    if line[idx] == ']'
                        let nparen -= 1
                    endif
                endif
                let idx += 1
            endwhile
            let firstobj = strpart(line, 0, idx)
        else
            let firstobj = substitute(line, ').*', '', "")
            let firstobj = substitute(firstobj, ',.*', '', "")
            let firstobj = substitute(firstobj, ' .*', '', "")
        endif
    endif

    if firstobj =~ "="
        let firstobj = ""
    endif

    if firstobj[0] == '"' || firstobj[0] == "'"
        let firstobj = "#c#"
    elseif firstobj[0] >= "0" && firstobj[0] <= "9"
        let firstobj = "#n#"
    endif


    if firstobj =~ '"'
        let firstobj = substitute(firstobj, '"', '\\"', "g")
    endif

    return firstobj
endfunction

" Show R's help doc in Nvim's buffer
" (based  on pydoc plugin)
function AskRDoc(rkeyword, package, getclass)
    if filewritable(s:docfile)
        call delete(s:docfile)
    endif
    call AddForDeletion(s:docfile)

    let firstobj = ""
    if bufname("%") =~ "Object_Browser" || (has_key(g:rplugin, "R_bufname") && bufname("%") == g:rplugin.R_bufname)
        let savesb = &switchbuf
        set switchbuf=useopen,usetab
        exe "sb " . g:rplugin.rscript_name
        exe "set switchbuf=" . savesb
    else
        if a:getclass
            let firstobj = RGetFirstObj(a:rkeyword)
        endif
    endif

    call SetRTextWidth(a:rkeyword)

    if firstobj == "" && a:package == ""
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . s:htw . 'L)'
    elseif a:package != ""
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . s:htw . 'L, package="' . a:package  . '")'
    else
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . s:htw . 'L, "' . firstobj . '")'
    endif

    call SendToNvimcom("\x08" . $NVIMR_ID . rcmd)
endfunction

function StartTxtBrowser(brwsr, url)
    if exists("*termopen")
        tabnew
        call termopen(a:brwsr . " " . a:url)
        startinsert
    elseif $TMUX != ""
        call system("tmux new-window '" . a:brwsr . " " . a:url . "'")
    else
        call RWarningMsg('Cannot run "' . a:brwsr . '".')
    endif
endfunction

" This function is called by nvimcom
function ShowRDoc(rkeyword)
    call AddForDeletion(s:docfile)

    let rkeyw = a:rkeyword
    if a:rkeyword =~ "^MULTILIB"
        let msgs = split(a:rkeyword)
        let msg = "The topic '" . msgs[-1] . "' was found in more than one library:\n"
        for idx in range(1, len(msgs) - 2)
            let msg .= idx . " : " . msgs[idx] . "\n"
        endfor
        redraw
        let chn = input(msg . "Please, select one of them: ")
        if chn > 0 && chn < (len(msgs) - 1)
            call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim.help("' . msgs[-1] . '", ' . s:htw . 'L, package="' . msgs[chn] . '")')
        endif
        return
    endif

    if has_key(g:rplugin, "R_bufname") && bufname("%") == g:rplugin.R_bufname
        " Exit Terminal mode and go to Normal mode
        stopinsert
    endif

    " Legacy support for running R in a Tmux split pane.
    " If the help command was triggered in the R Console, jump to Vim pane:
    if has_key(g:rplugin, "tmux_split") && g:rplugin.tmux_split && !s:running_rhelp
        let slog = system("tmux select-pane -t " . g:rplugin.editor_pane)
        if v:shell_error
            call RWarningMsg(slog)
        endif
    endif
    let s:running_rhelp = 0

    if bufname("%") =~ "Object_Browser" || (has_key(g:rplugin, "R_bufname") && bufname("%") == g:rplugin.R_bufname)
        let savesb = &switchbuf
        set switchbuf=useopen,usetab
        exe "sb " . g:rplugin.rscript_name
        exe "set switchbuf=" . savesb
    endif
    call SetRTextWidth(rkeyw)

    " Local variables that must be inherited by the rdoc buffer
    let g:tmp_objbrtitle = b:objbrtitle

    let rdoccaption = substitute(s:rdoctitle, '\', '', "g")
    if a:rkeyword =~ "R History"
        let rdoccaption = "R_History"
        let s:rdoctitle = "R_History"
    endif
    if bufloaded(rdoccaption)
        let curtabnr = tabpagenr()
        let savesb = &switchbuf
        set switchbuf=useopen,usetab
        exe "sb ". s:rdoctitle
        exe "set switchbuf=" . savesb
        if g:R_nvimpager == "tabnew"
            exe "tabmove " . curtabnr
        endif
    else
        if g:R_nvimpager == "tab" || g:R_nvimpager == "tabnew"
            exe 'tabnew ' . s:rdoctitle
        elseif s:vimpager == "vertical"
            let splr = &splitright
            set splitright
            exe s:hwidth . 'vsplit ' . s:rdoctitle
            let &splitright = splr
        elseif s:vimpager == "horizontal"
            exe 'split ' . s:rdoctitle
            if winheight(0) < 20
                resize 20
            endif
        elseif s:vimpager == "no"
            " The only way of ShowRDoc() being called when R_nvimpager=="no"
            " is the user setting the value of R_nvimpager to 'no' after
            " Neovim startup. It should be set in the vimrc.
            if type(g:R_external_term) == v:t_number && g:R_external_term == 0
                let g:R_nvimpager = "vertical"
            else
                let g:R_nvimpager = "tab"
            endif
            call ShowRDoc(a:rkeyword)
            return
        else
            echohl WarningMsg
            echomsg 'Invalid R_nvimpager value: "' . g:R_nvimpager . '". Valid values are: "tab", "vertical", "horizontal", "tabnew" and "no".'
            echohl None
            return
        endif
    endif

    setlocal modifiable
    let g:rplugin.curbuf = bufname("%")

    " Inheritance of local variables from the script buffer
    let b:objbrtitle = g:tmp_objbrtitle
    unlet g:tmp_objbrtitle

    let save_unnamed_reg = @@
    set modifiable
    sil normal! ggdG
    let fcntt = readfile(s:docfile)
    call setline(1, fcntt)
    if a:rkeyword =~ "R History"
        set filetype=r
        call cursor(1, 1)
    elseif a:rkeyword =~ "^MULTILIB"
        syn match Special '<Enter>'
        exe 'syn match String /"' . rkeyw . '"/'
        for idx in range(1, len(msgs) - 2)
            exe "syn match PreProc '^   " . msgs[idx] . "'"
        endfor
        exe 'nnoremap <buffer><silent> <CR> :call AskRDoc("' . rkeyw . '", expand("<cword>"), 0)<CR>'
        redraw
        call cursor(5, 4)
    elseif a:rkeyword =~ '(help)' || search("\x08", "nw") > 0
        set filetype=rdoc
        call cursor(1, 1)
    elseif a:rkeyword =~? '\.Rd$'
        " Called by devtools::load_all().
        " See https://github.com/jalvesaq/Nvim-R/issues/482
        set filetype=rhelp
        call cursor(1, 1)
    else
        set filetype=rout
        setlocal bufhidden=wipe
        setlocal nonumber
        setlocal noswapfile
        set buftype=nofile
        nnoremap <buffer><silent> q :q<CR>
        call cursor(1, 1)
    endif
    let @@ = save_unnamed_reg
    setlocal nomodified
    stopinsert
    redraw
endfunction

" This function is called by nvimcom
function EditRObject(fname)
    let fcont = readfile(a:fname)
    exe "tabnew " . substitute($NVIMR_TMPDIR . "/edit_" . $NVIMR_ID, ' ', '\\ ', 'g')
    call setline(".", fcont)
    set filetype=r
    stopinsert
    autocmd BufUnload <buffer> call delete($NVIMR_TMPDIR . "/edit_" . $NVIMR_ID . "_wait") | startinsert
endfunction

function ROpenPDF(fullpath)
    if a:fullpath == "Get Master"
        let fpath = SyncTeX_GetMaster() . ".pdf"
        let fpath = b:rplugin_pdfdir . "/" . substitute(fpath, ".*/", "", "")
        call ROpenPDF(fpath)
        return
    endif

    if g:R_openpdf == 0
        return
    endif

    if b:pdf_is_open == 0
        if g:R_openpdf == 1
            let b:pdf_is_open = 1
        endif
        call ROpenPDF2(a:fullpath)
    endif
endfunction

function RLoadHTML(fullpath, browser)
    if g:R_openhtml == 0
        return
    endif

    let brwsr = a:browser
    if brwsr == ''
        if has('win32') || g:rplugin.is_darwin
            let brwsr = 'open'
        else
            let brwsr = 'xdg-open'
        endif
    endif

    if has('nvim')
        call jobstart([brwsr, a:fullpath], {'detach': 1})
    else
        call job_start([brwsr, a:fullpath])
    endif
endfunction

function ROpenDoc(fullpath, browser)
    if !filereadable(a:fullpath)
        call RWarningMsg('The file "' . a:fullpath . '" does not exist.')
        return
    endif
    if a:fullpath =~ '.odt$'
        call system('lowriter ' . a:fullpath . ' &')
    elseif a:fullpath =~ '.pdf$'
        call ROpenPDF(a:fullpath)
    elseif a:fullpath =~ '.html$'
        call RLoadHTML(a:fullpath, a:browser)
    else
        call RWarningMsg("Unknown file type from nvim.interlace: " . a:fullpath)
    endif
endfunction

function RSetPDFViewer()
    let g:rplugin.pdfviewer = tolower(g:R_pdfviewer)

    if g:rplugin.pdfviewer == "zathura"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/zathura.vim"
    elseif g:rplugin.pdfviewer == "evince"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/evince.vim"
    elseif g:rplugin.pdfviewer == "okular"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/okular.vim"
    elseif has("win32") && g:rplugin.pdfviewer == "sumatra"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/sumatra.vim"
    elseif g:rplugin.is_darwin && g:rplugin.pdfviewer == "skim"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/skim.vim"
    elseif g:rplugin.pdfviewer == "qpdfview"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/qpdfview.vim"
    else
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/pdfviewer.vim"
        if !executable(g:R_pdfviewer)
            call RWarningMsg("R_pdfviewer (" . g:R_pdfviewer . ") not found.")
            return
        endif
        if g:R_synctex
            call RWarningMsg('Invalid value for R_pdfviewer: "' . g:R_pdfviewer . '" (SyncTeX will not work)')
        endif
    endif

    if !has("win32") && !g:rplugin.is_darwin
        if executable("wmctrl")
            let g:rplugin.has_wmctrl = 1
        else
            let g:rplugin.has_wmctrl = 0
            if &filetype == "rnoweb" && g:R_synctex
                call RWarningMsg("The application wmctrl must be installed to edit Rnoweb effectively.")
            endif
        endif
    endif
endfunction

function RSourceDirectory(...)
    if has("win32")
        let dir = substitute(a:1, '\\', '/', "g")
    else
        let dir = a:1
    endif
    if dir == ""
        call g:SendCmdToR("nvim.srcdir()")
    else
        call g:SendCmdToR("nvim.srcdir('" . dir . "')")
    endif
endfunction

function RAskHelp(...)
    if a:1 == ""
        call g:SendCmdToR("help.start()")
        return
    endif
    if g:R_nvimpager == "no"
        call g:SendCmdToR("help(" . a:1. ")")
    else
        call AskRDoc(a:1, "", 0)
    endif
endfunction


function PrintRObject(rkeyword)
    if bufname("%") =~ "Object_Browser"
        let firstobj = ""
    else
        let firstobj = RGetFirstObj(a:rkeyword)
    endif
    if firstobj == ""
        call g:SendCmdToR("print(" . a:rkeyword . ")")
    else
        call g:SendCmdToR('nvim.print("' . a:rkeyword . '", "' . firstobj . '")')
    endif
endfunction

function OpenRExample()
    if bufloaded(g:rplugin.tmpdir . "/example.R")
        exe "bunload! " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g')
    endif
    if g:R_nvimpager == "tabnew" || g:R_nvimpager == "tab"
        exe "tabnew " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . "/example.R"
    else
        let nvimpager = g:R_nvimpager
        if g:R_nvimpager == "vertical"
            let wwidth = winwidth(0)
            let min_e = (g:R_editor_w > 78) ? g:R_editor_w : 78
            let min_h = (g:R_help_w > 78) ? g:R_help_w : 78
            if wwidth < (min_e + min_h)
                let nvimpager = "horizontal"
            endif
        endif
        if nvimpager == "vertical"
            exe "belowright vsplit " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . "/example.R"
        else
            exe "belowright split " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . "/example.R"
        endif
    endif
    nnoremap <buffer><silent> q :q<CR>
    setlocal bufhidden=wipe
    setlocal noswapfile
    set buftype=nofile
    call delete(g:rplugin.tmpdir . "/example.R")
endfunction

" Call R functions for the word under cursor
function RAction(rcmd, ...)
    if &filetype == "rbrowser"
        let rkeyword = RBrowserGetName(1, 0)
    elseif a:0 == 1 && a:1 == "v" && line("'<") == line("'>")
        let rkeyword = strpart(getline("'>"), col("'<") - 1, col("'>") - col("'<") + 1)
    elseif a:0 == 1 && a:1 != "v" && a:1 !~ '^,'
        let rkeyword = RGetKeyword(a:1)
    else
        let rkeyword = RGetKeyword('@,48-57,_,.,:,$,@-@')
    endif
    if strlen(rkeyword) > 0
        if a:rcmd == "help"
            if rkeyword =~ "::"
                let rhelplist = split(rkeyword, "::")
                let rhelppkg = rhelplist[0]
                let rhelptopic = rhelplist[1]
            else
                let rhelppkg = ""
                let rhelptopic = rkeyword
            endif
            let s:running_rhelp = 1
            if g:R_nvimpager == "no"
                call g:SendCmdToR("help(" . rkeyword . ")")
            else
                if bufname("%") =~ "Object_Browser"
                    if g:rplugin.curview == "libraries"
                        let pkg = RBGetPkgName()
                    else
                        let pkg = ""
                    endif
                endif
                call AskRDoc(rhelptopic, rhelppkg, 1)
            endif
            return
        endif
        if a:rcmd == "print"
            call PrintRObject(rkeyword)
            return
        endif
        let rfun = a:rcmd
        if a:rcmd == "args"
            if g:R_listmethods == 1 && rkeyword !~ '::'
                call g:SendCmdToR('nvim.list.args("' . rkeyword . '")')
            else
                call g:SendCmdToR('args(' . rkeyword . ')')
            endif
            return
        endif
        if a:rcmd == "plot" && g:R_specialplot == 1
            let rfun = "nvim.plot"
        endif
        if a:rcmd == "plotsumm"
            if g:R_specialplot == 1
                let raction = "nvim.plot(" . rkeyword . "); summary(" . rkeyword . ")"
            else
                let raction = "plot(" . rkeyword . "); summary(" . rkeyword . ")"
            endif
            call g:SendCmdToR(raction)
            return
        endif

        if g:R_open_example && a:rcmd == "example"
            call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim.example("' . rkeyword . '")')
            return
        endif

        if a:0 == 1 && a:1 =~ '^,'
            let argmnts = a:1
        elseif a:0 == 2 && a:2 =~ '^,'
            let argmnts = a:2
        else
            let argmnts = ''
        endif

        if a:rcmd == "viewobj" || a:rcmd == "dputtab"
            call delete(g:rplugin.tmpdir . "/Rinsert")
            call AddForDeletion(g:rplugin.tmpdir . "/Rinsert")

            if a:rcmd == "viewobj"
                if exists("g:R_df_viewer")
                    let argmnts .= ', R_df_viewer = "' . g:R_df_viewer . '"'
                endif
                if rkeyword =~ '::'
                    call SendToNvimcom("\x08" . $NVIMR_ID .
                                \'nvimcom:::nvim_viewobj(' . rkeyword . argmnts . ')')
                else
                    if has("win32") && &encoding == "utf-8"
                        call SendToNvimcom("\x08" . $NVIMR_ID .
                                    \'nvimcom:::nvim_viewobj("' . rkeyword . '"' . argmnts .
                                    \', fenc="UTF-8"' . ')')
                    else
                        call SendToNvimcom("\x08" . $NVIMR_ID .
                                    \'nvimcom:::nvim_viewobj("' . rkeyword . '"' . argmnts . ')')
                    endif
                endif
            else
                call SendToNvimcom("\x08" . $NVIMR_ID .
                            \'nvimcom:::nvim_dput("' . rkeyword . '"' . argmnts . ')')
            endif
            return
        endif

        let raction = rfun . '(' . rkeyword . argmnts . ')'
        call g:SendCmdToR(raction)
    endif
endfunction

" render a document with rmarkdown
function! RMakeRmd(t)
    if !has_key(g:rplugin, "pdfviewer")
        call RSetPDFViewer()
    endif

    update

    let rmddir = expand("%:p:h")
    if has("win32")
        let rmddir = substitute(rmddir, '\\', '/', 'g')
    endif
    if a:t == "default"
        let rcmd = 'nvim.interlace.rmd("' . expand("%:t") . '", rmddir = "' . rmddir . '"'
    else
        let rcmd = 'nvim.interlace.rmd("' . expand("%:t") . '", outform = "' . a:t .'", rmddir = "' . rmddir . '"'
    endif
    let rcmd = rcmd . ', envir = ' . g:R_rmd_environment . ')'
    call g:SendCmdToR(rcmd)
endfunction

" For each noremap we need a vnoremap including <Esc> before the :call,
" otherwise nvim will call the function as many times as the number of selected
" lines. If we put <Esc> in the noremap, nvim will bell.
" RCreateMaps Args:
"   type : modes to which create maps (normal, visual and insert) and whether
"          the cursor have to go the beginning of the line
"   plug : the <Plug>Name
"   combo: combination of letters that make the shortcut
"   target: the command or function to be called
function RCreateMaps(type, plug, combo, target)
    if index(g:R_disable_cmds, a:plug) > -1
        return
    endif
    if a:type =~ '0'
        let tg = a:target . '<CR>0'
        let il = 'i'
    elseif a:type =~ '\.'
        let tg = a:target
        let il = 'a'
    else
        let tg = a:target . '<CR>'
        let il = 'a'
    endif
    if a:type =~ "n"
        exec 'noremap <buffer><silent> <Plug>' . a:plug . ' ' . tg
        if g:R_user_maps_only != 1 && !hasmapto('<Plug>' . a:plug, "n")
            exec 'noremap <buffer><silent> <LocalLeader>' . a:combo . ' ' . tg
        endif
    endif
    if a:type =~ "v"
        exec 'vnoremap <buffer><silent> <Plug>' . a:plug . ' <Esc>' . tg
        if g:R_user_maps_only != 1 && !hasmapto('<Plug>' . a:plug, "v")
            exec 'vnoremap <buffer><silent> <LocalLeader>' . a:combo . ' <Esc>' . tg
        endif
    endif
    if g:R_insert_mode_cmds == 1 && a:type =~ "i"
        exec 'inoremap <buffer><silent> <Plug>' . a:plug . ' <Esc>' . tg . il
        if g:R_user_maps_only != 1 && !hasmapto('<Plug>' . a:plug, "i")
            exec 'inoremap <buffer><silent> <LocalLeader>' . a:combo . ' <Esc>' . tg . il
        endif
    endif
endfunction

function RControlMaps()
    " List space, clear console, clear all
    "-------------------------------------
    call RCreateMaps('nvi', 'RListSpace',    'rl', ':call g:SendCmdToR("ls()")')
    call RCreateMaps('nvi', 'RClearConsole', 'rr', ':call RClearConsole()')
    call RCreateMaps('nvi', 'RClearAll',     'rm', ':call RClearAll()')

    " Print, names, structure
    "-------------------------------------
    call RCreateMaps('ni', 'RObjectPr',    'rp', ':call RAction("print")')
    call RCreateMaps('ni', 'RObjectNames', 'rn', ':call RAction("nvim.names")')
    call RCreateMaps('ni', 'RObjectStr',   'rt', ':call RAction("str")')
    call RCreateMaps('ni', 'RViewDF',      'rv', ':call RAction("viewobj")')
    call RCreateMaps('ni', 'RViewDFs',     'vs', ':call RAction("viewobj", ", howto=''split''")')
    call RCreateMaps('ni', 'RViewDFv',     'vv', ':call RAction("viewobj", ", howto=''vsplit''")')
    call RCreateMaps('ni', 'RViewDFa',     'vh', ':call RAction("viewobj", ", howto=''above 7split'', nrows=6")')
    call RCreateMaps('ni', 'RDputObj',     'td', ':call RAction("dputtab")')

    call RCreateMaps('v', 'RObjectPr',     'rp', ':call RAction("print", "v")')
    call RCreateMaps('v', 'RObjectNames',  'rn', ':call RAction("nvim.names", "v")')
    call RCreateMaps('v', 'RObjectStr',    'rt', ':call RAction("str", "v")')
    call RCreateMaps('v', 'RViewDF',       'rv', ':call RAction("viewobj", "v")')
    call RCreateMaps('v', 'RViewDFs',      'vs', ':call RAction("viewobj", "v", ", howto=''split''")')
    call RCreateMaps('v', 'RViewDFv',      'vv', ':call RAction("viewobj", "v", ", howto=''vsplit''")')
    call RCreateMaps('v', 'RViewDFa',      'vh', ':call RAction("viewobj", "v", ", howto=''above 7split'', nrows=6")')
    call RCreateMaps('v', 'RDputObj',      'td', ':call RAction("dputtab", "v")')

    " Arguments, example, help
    "-------------------------------------
    call RCreateMaps('nvi', 'RShowArgs',   'ra', ':call RAction("args")')
    call RCreateMaps('nvi', 'RShowEx',     're', ':call RAction("example")')
    call RCreateMaps('nvi', 'RHelp',       'rh', ':call RAction("help")')

    " Summary, plot, both
    "-------------------------------------
    call RCreateMaps('ni', 'RSummary',     'rs', ':call RAction("summary")')
    call RCreateMaps('ni', 'RPlot',        'rg', ':call RAction("plot")')
    call RCreateMaps('ni', 'RSPlot',       'rb', ':call RAction("plotsumm")')

    call RCreateMaps('v', 'RSummary',      'rs', ':call RAction("summary", "v")')
    call RCreateMaps('v', 'RPlot',         'rg', ':call RAction("plot", "v")')
    call RCreateMaps('v', 'RSPlot',        'rb', ':call RAction("plotsumm", "v")')

    " Build list of objects for omni completion
    "-------------------------------------
    call RCreateMaps('nvi', 'RUpdateObjBrowser', 'ro', ':call RObjBrowser()')
    call RCreateMaps('nvi', 'ROpenLists',        'r=', ':call RBrOpenCloseLs("O")')
    call RCreateMaps('nvi', 'RCloseLists',       'r-', ':call RBrOpenCloseLs("C")')

    " Render script with rmarkdown
    "-------------------------------------
    call RCreateMaps('nvi', 'RMakeRmd',    'kr', ':call RMakeRmd("default")')
    call RCreateMaps('nvi', 'RMakePDFK',   'kp', ':call RMakeRmd("pdf_document")')
    call RCreateMaps('nvi', 'RMakePDFKb',  'kl', ':call RMakeRmd("beamer_presentation")')
    call RCreateMaps('nvi', 'RMakeWord',   'kw', ':call RMakeRmd("word_document")')
    call RCreateMaps('nvi', 'RMakeHTML',   'kh', ':call RMakeRmd("html_document")')
    call RCreateMaps('nvi', 'RMakeODT',    'ko', ':call RMakeRmd("odt_document")')
endfunction

function RCreateStartMaps()
    " Start
    "-------------------------------------
    call RCreateMaps('nvi', 'RStart',       'rf', ':call StartR("R")')
    call RCreateMaps('nvi', 'RCustomStart', 'rc', ':call StartR("custom")')

    " Close
    "-------------------------------------
    call RCreateMaps('nvi', 'RClose',       'rq', ":call RQuit('nosave')")
    call RCreateMaps('nvi', 'RSaveClose',   'rw', ":call RQuit('save')")

endfunction

function RCreateEditMaps()
    " Edit
    "-------------------------------------
    call RCreateMaps('ni', 'RToggleComment',   'xx', ':call RComment("normal")')
    call RCreateMaps('v',  'RToggleComment',   'xx', ':call RComment("selection")')
    call RCreateMaps('ni', 'RSimpleComment',   'xc', ':call RSimpleCommentLine("normal", "c")')
    call RCreateMaps('v',  'RSimpleComment',   'xc', ':call RSimpleCommentLine("selection", "c")')
    call RCreateMaps('ni', 'RSimpleUnComment', 'xu', ':call RSimpleCommentLine("normal", "u")')
    call RCreateMaps('v',  'RSimpleUnComment', 'xu', ':call RSimpleCommentLine("selection", "u")')
    call RCreateMaps('ni', 'RRightComment',     ';', ':call MovePosRCodeComment("normal")')
    call RCreateMaps('v',  'RRightComment',     ';', ':call MovePosRCodeComment("selection")')
    " Replace 'underline' with '<-'
    if g:R_assign == 1 || g:R_assign == 2
        silent exe 'inoremap <buffer><silent> ' . g:R_assign_map . ' <Esc>:call ReplaceUnderS()<CR>a'
    endif
endfunction

function RCreateSendMaps()
    " Block
    "-------------------------------------
    call RCreateMaps('ni', 'RSendMBlock',     'bb', ':call SendMBlockToR("silent", "stay")')
    call RCreateMaps('ni', 'RESendMBlock',    'be', ':call SendMBlockToR("echo", "stay")')
    call RCreateMaps('ni', 'RDSendMBlock',    'bd', ':call SendMBlockToR("silent", "down")')
    call RCreateMaps('ni', 'REDSendMBlock',   'ba', ':call SendMBlockToR("echo", "down")')

    " Function
    "-------------------------------------
    call RCreateMaps('nvi', 'RSendFunction',  'ff', ':call SendFunctionToR("silent", "stay")')
    call RCreateMaps('nvi', 'RDSendFunction', 'fe', ':call SendFunctionToR("echo", "stay")')
    call RCreateMaps('nvi', 'RDSendFunction', 'fd', ':call SendFunctionToR("silent", "down")')
    call RCreateMaps('nvi', 'RDSendFunction', 'fa', ':call SendFunctionToR("echo", "down")')

    " Selection
    "-------------------------------------
    call RCreateMaps('n', 'RSendSelection',   'ss', ':call SendSelectionToR("silent", "stay", "normal")')
    call RCreateMaps('n', 'RESendSelection',  'se', ':call SendSelectionToR("echo", "stay", "normal")')
    call RCreateMaps('n', 'RDSendSelection',  'sd', ':call SendSelectionToR("silent", "down", "normal")')
    call RCreateMaps('n', 'REDSendSelection', 'sa', ':call SendSelectionToR("echo", "down", "normal")')

    call RCreateMaps('v', 'RSendSelection',   'ss', ':call SendSelectionToR("silent", "stay")')
    call RCreateMaps('v', 'RESendSelection',  'se', ':call SendSelectionToR("echo", "stay")')
    call RCreateMaps('v', 'RDSendSelection',  'sd', ':call SendSelectionToR("silent", "down")')
    call RCreateMaps('v', 'REDSendSelection', 'sa', ':call SendSelectionToR("echo", "down")')
    call RCreateMaps('v', 'RSendSelAndInsertOutput', 'so', ':call SendSelectionToR("echo", "stay", "NewtabInsert")')

    " Paragraph
    "-------------------------------------
    call RCreateMaps('ni', 'RSendParagraph',   'pp', ':call SendParagraphToR("silent", "stay")')
    call RCreateMaps('ni', 'RESendParagraph',  'pe', ':call SendParagraphToR("echo", "stay")')
    call RCreateMaps('ni', 'RDSendParagraph',  'pd', ':call SendParagraphToR("silent", "down")')
    call RCreateMaps('ni', 'REDSendParagraph', 'pa', ':call SendParagraphToR("echo", "down")')

    if &filetype == "rnoweb" || &filetype == "rmd" || &filetype == "rrst"
        call RCreateMaps('ni', 'RSendChunkFH', 'ch', ':call SendFHChunkToR()')
    endif

    " *Line*
    "-------------------------------------
    call RCreateMaps('ni',  'RSendLine', 'l', ':call SendLineToR("stay")')
    call RCreateMaps('ni0', 'RDSendLine', 'd', ':call SendLineToR("down")')
    call RCreateMaps('ni0', '(RDSendLineAndInsertOutput)', 'o', ':call SendLineToRAndInsertOutput()')
    call RCreateMaps('v',   '(RDSendLineAndInsertOutput)', 'o', ':call RWarningMsg("This command does not work over a selection of lines.")')
    call RCreateMaps('i',   'RSendLAndOpenNewOne', 'q', ':call SendLineToR("newline")')
    call RCreateMaps('ni.', 'RSendMotion', 'm', ':set opfunc=SendMotionToR<CR>g@')
    call RCreateMaps('n',   'RNLeftPart', 'r<left>', ':call RSendPartOfLine("left", 0)')
    call RCreateMaps('n',   'RNRightPart', 'r<right>', ':call RSendPartOfLine("right", 0)')
    call RCreateMaps('i',   'RILeftPart', 'r<left>', 'l:call RSendPartOfLine("left", 1)')
    call RCreateMaps('i',   'RIRightPart', 'r<right>', 'l:call RSendPartOfLine("right", 1)')
    if &filetype == "r"
        call RCreateMaps('n', 'RSendAboveLines',  'su', ':call SendAboveLinesToR()')
    endif

    " Debug
    call RCreateMaps('n',   'RDebug', 'bg', ':call RAction("debug")')
    call RCreateMaps('n',   'RUndebug', 'ud', ':call RAction("undebug")')
endfunction

function RBufEnter()
    let g:rplugin.curbuf = bufname("%")
    if has("gui_running")
        if &filetype != g:rplugin.lastft
            call UnMakeRMenu()
            if &filetype == "r" || &filetype == "rnoweb" || &filetype == "rmd" || &filetype == "rrst" || &filetype == "rdoc" || &filetype == "rbrowser" || &filetype == "rhelp"
                if &filetype == "rbrowser"
                    call MakeRBrowserMenu()
                else
                    call MakeRMenu()
                endif
            endif
        endif
        if &buftype != "nofile" || (&buftype == "nofile" && &filetype == "rbrowser")
            let g:rplugin.lastft = &filetype
        endif
    endif
    if &filetype == "r" || &filetype == "rnoweb" || &filetype == "rmd" || &filetype == "rrst" || &filetype == "rhelp"
        let g:rplugin.rscript_name = bufname("%")
    endif
endfunction

function AddForDeletion(fname)
    for fn in s:del_list
        if fn == a:fname
            return
        endif
    endfor
    call add(s:del_list, a:fname)
endfunction

function RVimLeave()
    if has('nvim')
        for job in keys(g:rplugin.jobs)
            if IsJobRunning(job)
                if job == 'ClientServer' || job == 'BibComplete'
                    " Avoid warning of exit status 141
                    call JobStdin(g:rplugin.jobs[job], "8\n")
                    sleep 20m
                endif
            endif
        endfor
    endif

    for fn in s:del_list
        call delete(fn)
    endfor
    if executable("rmdir")
        call system("rmdir '" . g:rplugin.tmpdir . "'")
    endif
endfunction

" Did R successfully finished evaluating a command?
let s:R_task_completed = 0

" Function called by nvimcom
function RTaskCompleted()
    let s:R_task_completed = 1
    if g:R_hi_fun_globenv == 2
        call SendToNvimcom("\002" . $NVIMR_ID)
        call UpdateRGlobalEnv(0)
    endif
endfunction

let s:updating_globalenvlist = 0
let s:waiting_glblnv_list = 0
" Function called by nvimcom
function GlblEnvUpdated(changed)
    let s:updating_globalenvlist = 0
    if s:waiting_glblnv_list
        if a:changed == 0
            " Nothing to update
            let s:waiting_glblnv_list = 0
        endif
    endif
endfunction

function ROnInsertEnter()
    if g:R_hi_fun_globenv != 0
        call UpdateRGlobalEnv(0)
    endif
endfunction

let s:nglobfun = 0
function UpdateRGlobalEnv(block)
    if ! s:R_task_completed
        return
    endif
    let s:R_task_completed = 0

    if string(g:SendCmdToR) == "function('SendCmdToR_fake')"
        return
    endif

    " If UpdateRGlobalEnv() is called at least once, increase the
    " value of g:R_hi_fun_globenv to 1.
    if g:R_hi_fun_globenv == 0
        let g:R_hi_fun_globenv = 1
    endif

    let s:updating_globalenvlist = 1
    call SendToNvimcom("\004" . $NVIMR_ID)

    if g:rplugin.nvimcom_port == 0
        sleep 500m
        return
    endif

    if a:block
        " We can't return from this function and wait for a message from
        " nvimcom because both omni completion and the Object Browser require
        " the list of completions immediately.
        sleep 10m
        let ii = 0
        let max_ii = 100 * g:R_wait_reply
        while s:updating_globalenvlist && ii < max_ii
            let ii += 1
            sleep 10m
        endwhile
        if ii == max_ii
            call RWarningMsg("No longer waiting...")
            return
        endif
    else
        let s:waiting_glblnv_list = 1
    endif
endfunction

function UpdateLocalFunctions(funnames)
    syntax clear rGlobEnvFun
    let flist = split(a:funnames, " ")
    for fnm in flist
        if !exists('g:R_hi_fun_paren') || g:R_hi_fun_paren == 0
            exe 'syntax keyword rGlobEnvFun ' . fnm
        else
            exe 'syntax match rGlobEnvFun /\<' . fnm . '\s*\ze(/'
        endif
    endfor
endfunction

let s:float_win = 0
let s:compl_event = {}
let g:rplugin.compl_cls = ''

function FormatInfo(width, needblank)
    let ud = s:compl_event['completed_item']['user_data']
    let g:rplugin.compl_cls = ud['cls']

    let info = ''
    if ud['cls'] == 'a'
        let info = ' ' . FormatTxt(ud['argument'], ' ', " \n  ", a:width - 1)
    elseif ud['cls'] == 'l'
        let info = ' ' . FormatTxt(ud['ttl'], ' ', " \n ", a:width - 1) . ' '
        let info .= "\n————\n"
        let info .= ' ' . FormatTxt(ud['descr'], ' ', " \n ", a:width - 1)
    else
        if ud['descr'] != ''
            let info = ' ' . FormatTxt(ud['descr'], ' ', " \n ", a:width - 1) . ' '
        endif
        if ud['cls'] == 'f'
            if ud['descr'] != '' && s:usage != ''
                let info .= "\n————\n"
            endif
            if s:usage != ''
                " Function usage delimited by non separable spaces (digraph NS)
                let info .= ' ' . FormatTxt(s:usage, ', ', ",  \n   ", a:width) . ' '
            endif
        endif
        if a:width > 59 && has_key(ud, 'summary')
            if ud['descr'] != ''
                let info .= "\n————\n"
            endif
            let info .= " " . join(ud['summary'], "\n ") . " "
        endif
    endif

    if info == ''
        return []
    endif
    if a:needblank
        let lines = [''] + split(info, "\n") + ['']
    else
        let lines = split(info, "\n") + ['']
    endif
    return lines
endfunction

function CreateNewFloat(...)
    if len(s:compl_event) == 0
        return
    endif

    let wrd = s:compl_event['completed_item']['word']

    " Get the required height for a standard float preview window
    let flines = FormatInfo(60, 1)
    if len(flines) == 0
        call CloseFloatWin()
        return
    endif
    let reqh = len(flines) > 15 ? 15 : len(flines)

    " Ensure that some variables are integers:
    exe 'let mc = ' . substitute(string(s:compl_event['col']), '\..*', '', '')
    exe 'let mr = ' . substitute(string(s:compl_event['row']), '\..*', '', '')
    exe 'let mw = ' . substitute(string(s:compl_event['width']), '\..*', '', '')
    exe 'let mh = ' . substitute(string(s:compl_event['height']), '\..*', '', '')

    " Default position and size of float window (at the right side of the popup menu)
    let has_space = 1
    let needblank = 0
    let frow = mr
    let flwd = 60
    let fanchor = 'NW'
    let fcol = mc + mw + s:compl_event['scrollbar']

    " Required to fix the position and size of the float window
    let dspwd = &columns
    let freebelow = (mr == (line('.') - line('w0')) ? &lines - mr - mh : &lines - mr) - 3
    let freeright = dspwd - mw - mc - s:compl_event['scrollbar']
    let freeleft = mc - 1
    let freetop = mr - 1

    " If there is enough vertical space, open the window beside the menu
    if freebelow > reqh && (freeright > 30 || freeleft > 30)
        if freeright > 30
            " right side
            let flwd = freeright > 60 ? 60 : freeright
        else
            " left side
            let flwd = (mc - 1) > 60 ? 60 : (mc - 1)
            let fcol = mc - 1
            let fanchor = 'NE'
        endif
    else
        " If there is enough vertical space and enough right space, then, if the menu
        "   - is below the current line, open the window below the menu
        "   - is above the current line, open the window above the menu
        let freeright = dspwd - mc
        let freeabove = mr - 1
        let freebelow = &lines - mr - mh - 3

        if freeright > 45 && (mr == (line('.') - line('w0') + 1)) && freebelow > reqh
            " below the menu
            let flwd = freeright > 60 ? 60 : freeright
            let fcol = mc - 1
            let frow = mr + mh
            let needblank = 1
        elseif freeright > 45 && (line('.') - line('w0') + 1) > mr && freeabove > reqh
            " above the menu
            let flwd = freeright > 60 ? 60 : freeright
            let fcol = mc - 1
            let frow = mr
            let fanchor = 'SW'
        else
            " Finally, check if it's possible to open the window
            " either on the top or on the bottom of the display
            let flwd = dspwd
            let flines = FormatInfo(flwd, 0)
            let reqh = len(flines) > 15 ? 15 : len(flines)
            let fcol = 0

            if freeabove > reqh || (freeabove > 3 && freeabove > freebelow)
                " top
                let frow = 0
            elseif freebelow > 3
                " bottom
                let frow = &lines
                let fanchor = 'SW'
            else
                " no space available
                let has_space = 0
            endif
        endif
    endif

    if len(flines) == 0 || has_space == 0
        return
    endif

    " Now that the position is defined, calculate the available height
    if frow == &lines
        if mr == (line('.') - line('w0') + 1)
            let maxh = &lines - mr - mh - 2
        else
            let maxh = &lines - line('.') + line('w0') - 2
        endif
        let needblank = 1
    elseif frow == 0
        let maxh = mr - 3
    else
        let maxh = &lines - frow - 2
    endif

    " Open the window if there is enough available height
    if maxh < 2
        return
    endif

    let flines = FormatInfo(flwd, needblank)
    " replace ———— with a complete line
    let realwidth = 10
    for lin in flines
        if strdisplaywidth(lin) > realwidth
            let realwidth = strdisplaywidth(lin)
        endif
    endfor

    if has("win32") && !has("nvim")
        call map(flines, 'substitute(v:val, "^————$", repeat("-", realwidth), "")')
    else
        call map(flines, 'substitute(v:val, "^————$", repeat("—", realwidth), "")')
    endif

    let flht = (len(flines) > maxh) ? maxh : len(flines)

    if has('nvim')
        if !exists('s:float_buf')
            let s:float_buf = nvim_create_buf(v:false, v:true)
            call setbufvar(s:float_buf, '&buftype', 'nofile')
            call setbufvar(s:float_buf, '&bufhidden', 'hide')
            call setbufvar(s:float_buf, '&swapfile', 0)
            call setbufvar(s:float_buf, '&tabstop', 2)
            call setbufvar(s:float_buf, '&undolevels', -1)
        endif
        call nvim_buf_set_option(s:float_buf, 'syntax', 'rdocpreview')

        call nvim_buf_set_lines(s:float_buf, 0, -1, v:true, flines)

        let opts = {'relative': 'editor', 'width': realwidth, 'height': flht,
                    \ 'col': fcol, 'row': frow, 'anchor': fanchor, 'style': 'minimal'}
        if s:float_win
            call nvim_win_set_config(s:float_win, opts)
        else
            let s:float_win = nvim_open_win(s:float_buf, 0, opts)
            call setwinvar(s:float_win, '&wrap', 1)
            call setwinvar(s:float_win, '&colorcolumn', 0)
            call setwinvar(s:float_win, '&signcolumn', 'no')
        endif
    else
        if fanchor == 'NE'
            let fpos = 'topright'
        elseif fanchor == 'SW'
            let fpos = 'botleft'
            let frow -= 1
        else
            let fpos = 'topleft'
        endif
        if s:float_win
            call popup_close(s:float_win)
        endif
        let s:float_win = popup_create(flines, #{
                    \ line: frow + 1, col: fcol, pos: fpos,
                    \ maxheight: flht})
    endif
endfunction

function CloseFloatWin(...)
    if has('nvim')
        let id = win_id2win(s:float_win)
        if id > 0
            let ok = 1
            try
                call nvim_win_close(s:float_win, 1)
            catch /E5/
                " Cannot close the float window after cycling through all the
                " items and going back to the original uncompleted pattern
                let ok = 0
            finally
                if ok
                    let s:float_win = 0
                endif
            endtry
        endif
    else
        call popup_close(s:float_win)
        let s:float_win = 0
    endif
endfunction

function OnCompleteDone()
    call CloseFloatWin()
    let s:user_data = {}
endfunction

" TODO: delete s:user_data when Ubuntu has('nvim-0.5.0') && has('patch-8.2.84')
let s:user_data = {}
function AskForComplInfo()
    if ! pumvisible()
        return
    endif
    " Other plugins fill the 'user_data' dictionary
    if has_key(v:event, 'completed_item') && has_key(v:event['completed_item'], 'word')
        let s:compl_event = deepcopy(v:event)
        if s:user_data != {}
            " TODO: Delete this code when Neovim 0.5 is released
            let s:compl_event['completed_item']['user_data'] = deepcopy(s:user_data[v:event['completed_item']['word']])
        endif
        if has_key(s:compl_event['completed_item'], 'user_data') &&
                    \ type(s:compl_event['completed_item']['user_data']) == v:t_dict
            if has_key(s:compl_event['completed_item']['user_data'], 'pkg')
                let pkg = s:compl_event['completed_item']['user_data']['pkg']
                let wrd = s:compl_event['completed_item']['word']
                " Request function description and usage
                call JobStdin(g:rplugin.jobs["ClientServer"], "6" . wrd . "\002" . pkg . "\n")
            else
                " Neovim doesn't allow to open a float window from here:
                call timer_start(1, 'CreateNewFloat', {})
            endif
        endif
    elseif s:float_win
        call CloseFloatWin()
    endif
endfunction

function FinishGlbEnvFunArgs(fnm)
    if filereadable(g:rplugin.tmpdir . "/args_for_completion")
        let usage = readfile(g:rplugin.tmpdir . "/args_for_completion")[0]
        let usage = '[' . substitute(usage, "\004", "'", 'g') . ']'
        let usage = eval(usage)
        call map(usage, 'join(v:val, " = ")')
        let usage = join(usage, ", ")
        let s:usage = a:fnm . '(' . usage . ')'
    else
        let s:usage = "COULD NOT GET ARGUMENTS"
    endif
    call CreateNewFloat()
endfunction

function FinishGetSummary()
    if filereadable(g:rplugin.tmpdir . "/args_for_completion")
        let s:compl_event['completed_item']['user_data']['summary'] = readfile(g:rplugin.tmpdir . "/args_for_completion")
    endif
    call CreateNewFloat()
endfunction

function SetComplInfo(dctnr)
    " Replace user_data with the complete version
    let s:compl_event['completed_item']['user_data'] = deepcopy(a:dctnr)

    if a:dctnr['cls'] == 'f'
        let usage = deepcopy(a:dctnr['usage'])
        call map(usage, 'join(v:val, " = ")')
        let usage = join(usage, ", ")
        if usage == 'not_checked'
            " Function at the .GlobalEnv
            call delete(g:rplugin.tmpdir . "/args_for_completion")
            call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim.GlobalEnv.fun.args("' . a:dctnr['word'] . '")')
            return
        endif
        let s:usage = a:dctnr['word'] . '(' . usage . ')'
    elseif a:dctnr['word'] =~ '\k\{-}\$\k\{-}'
        call delete(g:rplugin.tmpdir . "/args_for_completion")
        call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim.get.summary(' . a:dctnr['word'] . ', 59)')
        return
    endif

    if len(a:dctnr) > 0
        call CreateNewFloat()
    endif
endfunction

autocmd CompleteChanged * call AskForComplInfo()
autocmd CompleteDone * call OnCompleteDone()

function FormatPrgrph(text, splt, jn, maxlen)
    let wlist = split(a:text, a:splt)
    let txt = ['']
    let ii = 0
    for wrd in wlist
        if strdisplaywidth(txt[ii] . a:splt . wrd) < a:maxlen
            let txt[ii] .= a:splt . wrd
        else
            let ii += 1
            let txt += [wrd]
        endif
    endfor
    let txt[0] = substitute(txt[0], '^' . a:splt, '', '')
    return join(txt, a:jn)
endfunction

function FormatTxt(text, splt, jn, maxl)
    let maxlen = a:maxl - len(a:jn)
    let atext = substitute(a:text, "\004", "'", "g")
    let plist = split(atext, "\002")
    let txt = ''
    for prg in plist
        let txt .= "\n " . FormatPrgrph(prg, a:splt, a:jn, maxlen)
    endfor
    let txt = substitute(txt, "^\n ", "", "")
    return txt
endfunction

function GetRArgs(base, rkeyword0, firstobj, pkg)
    if string(g:SendCmdToR) == "function('SendCmdToR_fake')"
        return []
    endif

    call delete(g:rplugin.tmpdir . "/args_for_completion")
    let msg = 'nvimcom:::nvim_complete_args("' . a:rkeyword0 . '", "' . a:base . '"'
    if a:firstobj != ""
        let msg .= ', firstobj = "' . a:firstobj . '"'
    elseif a:pkg != ""
        let msg .= ', pkg = ' . a:pkg
    endif
    let msg .= ')'

    " Save documentation of arguments to be used by nclientserver
    call SendToNvimcom("\x08" . $NVIMR_ID . msg)

    return WaitRCompletion()
endfunction

function GetListOfRLibs(base)
    let argls = []
    if filereadable(g:rplugin.compldir . "/pack_descriptions")
        let pd = readfile(g:rplugin.compldir . "/pack_descriptions")
        call filter(pd, 'v:val =~ "^" . a:base')
        for line in pd
            let tmp = split(line, "\x09")
            if has('nvim-0.5.0') || has('patch-8.2.84')
                call add(argls, {'word': tmp[0], 'user_data': {'ttl': tmp[1], 'descr': tmp[2], 'cls': 'l'}})
            else
                call add(argls, {'word': tmp[0]})
                let s:user_data[tmp[0]] = {'ttl': tmp[1], 'descr': tmp[2], 'cls': 'l'}
            endif
        endfor
    endif
    return argls
endfunction

function FindStartRObj()
    let line = getline(".")
    let lnum = line(".")
    let cpos = getpos(".")
    let idx = cpos[2] - 2
    let idx2 = cpos[2] - 2
    call cursor(lnum, cpos[2] - 1)
    if line[idx2] == ' ' || line[idx2] == ',' || line[idx2] == '('
        let idx2 = cpos[2]
        let s:argkey = ''
    else
        let idx1 = idx2
        while line[idx1] =~ '\w' || line[idx1] == '.' || line[idx1] == '_' ||
                    \ line[idx1] == ':' || line[idx1] == '$' || line[idx1] == '@'
            let idx1 -= 1
        endwhile
        let idx1 += 1
        let argkey = strpart(line, idx1, idx2 - idx1 + 1)
        let idx2 = cpos[2] - strlen(argkey)
        let s:argkey = argkey
    endif
    return idx2 - 1
endfunction

function ReadComplMenu()
    if filereadable(g:rplugin.tmpdir . "/nvimbol_finished")
        let txt = readfile(g:rplugin.tmpdir . "/nvimbol_finished")[0]
        let s:compl_menu = deepcopy(eval(txt))
        call delete(g:rplugin.tmpdir . "/nvimbol_finished")
    else
        let s:compl_menu = {}
    endif
    let s:waiting_compl_menu = 0
endfunction

function SetComplMenu(cmn)
    let s:compl_menu = deepcopy(a:cmn)
    let s:waiting_compl_menu = 0
endfunction

function CompleteR(findstart, base)
    if a:findstart
        let s:user_data = {}
        let line = getline(".")
        if b:rplugin_knitr_pattern != '' && line =~ b:rplugin_knitr_pattern
            let s:compl_type = 3
            return FindStartRObj()
        elseif b:IsInRCode(0) == 0 && b:rplugin_non_r_omnifunc != ''
            let s:compl_type = 2
            let Ofun = function(b:rplugin_non_r_omnifunc)
            return Ofun(a:findstart, a:base)
        else
            let s:compl_type = 1
            return FindStartRObj()
        endif
    else
        if s:compl_type == 3
            return CompleteChunkOptions(a:base)
        elseif s:compl_type == 2
            let Ofun = function(b:rplugin_non_r_omnifunc)
            return Ofun(a:findstart, a:base)
        endif

        " The base might have changed because the user has hit the backspace key
        call CloseFloatWin()

        if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
            " Check if we need function arguments
            let line = getline(".")
            let lnum = line(".")
            let cpos = getpos(".")
            let idx = cpos[2] - 2
            let idx2 = cpos[2] - 2
            let np = 1
            let nl = 0
            let argls = []
            " Look up to 10 lines above for an opening parenthesis
            while nl < 10
                if line[idx] == '('
                    let np -= 1
                elseif line[idx] == ')'
                    let np += 1
                endif
                if np == 0
                    " The opening parenthesis was found
                    call cursor(lnum, idx)
                    let rkeyword0 = RGetKeyword('@,48-57,_,.,:,$,@-@')
                    let firstobj = ""
                    if rkeyword0 =~ "::"
                        let pkg = '"' . substitute(rkeyword0, "::.*", "", "") . '"'
                        let rkeyword0 = substitute(rkeyword0, ".*::", "", "")
                    else
                        if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
                            let firstobj = RGetFirstObj(rkeyword0)
                        endif
                        let pkg = ""
                    endif
                    call cursor(cpos[1], cpos[2])

                    if (rkeyword0 == "library" || rkeyword0 == "require") && IsFirstRArg(lnum, cpos)
                        let argls = GetListOfRLibs(a:base)
                        if len(argls)
                            let s:is_completing = 1
                            return argls
                        endif
                    endif

                    call UpdateRGlobalEnv(1)
                    let s:waiting_compl_menu = 1
                    return GetRArgs(a:base, rkeyword0, firstobj, pkg)
                endif
                let idx -= 1
                if idx <= 0
                    let lnum -= 1
                    if lnum == 0
                        break
                    endif
                    let line = getline(lnum)
                    let idx = strlen(line)
                    let nl +=1
                endif
            endwhile
        endif

        if a:base == ''
            " Require at least one character to try omni completion
            return []
        endif

        if exists('s:compl_menu')
            unlet s:compl_menu
        endif
        call UpdateRGlobalEnv(1)
        let s:waiting_compl_menu = 1
        call JobStdin(g:rplugin.jobs["ClientServer"], "51" . a:base . "\n")
        return WaitRCompletion()
    endif
endfunction

function WaitRCompletion()
    sleep 10m
    let nwait = 0
    while s:waiting_compl_menu && nwait < 100
        let nwait += 1
        sleep 10m
    endwhile
    if exists('s:compl_menu')
        let s:is_completing = 1
        if has('nvim-0.5.0') || has('patch-8.2.84')
            " 'user_data' might be a dictionary
            return s:compl_menu
        else
            " 'user_data' must be string (Ubuntu 20.04)
            let s:user_data = {}
            for item in s:compl_menu
                let wrd = item['word']
                if has_key(item, 'user_data')
                    let s:user_data[wrd] = deepcopy(item['user_data'])
                    let item['user_data'] = ''
                endif
            endfor
        endif
        return s:compl_menu
    endif
    return []
endfunction

function RSourceOtherScripts()
    if exists("g:R_source")
        let flist = split(g:R_source, ",")
        for fl in flist
            if fl =~ " "
                call RWarningMsg("Invalid file name (empty spaces are not allowed): '" . fl . "'")
            else
                exe "source " . escape(fl, ' \')
            endif
        endfor
    endif

    if (g:R_auto_start == 1 && v:vim_did_enter == 0) || g:R_auto_start == 2
        call timer_start(200, 'AutoStartR')
    endif
endfunction

function RBuildTags()
    if filereadable("etags")
        call RWarningMsg('The file "etags" exists. Please, delete it and try again.')
        return
    endif
    call g:SendCmdToR('rtags(ofile = "etags"); etags2ctags("etags", "tags"); unlink("etags")')
endfunction

function ShowRDebugInfo()
    for key in keys(g:rplugin.debug_info)
        echohl Title
        echo key
        echohl None
        echo g:rplugin.debug_info[key]
        echo ""
    endfor
endfunction

function AutoStartR(...)
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        return
    endif
    if v:vim_did_enter == 0
        call timer_start(100, 'AutoStartR')
        return
    endif
    if exists('s:starting_ncs') && s:starting_ncs == 1
        call timer_start(200, 'AutoStartR')
        return
    endif
    call StartR("R")
endfunction

command -nargs=1 -complete=customlist,RLisObjs Rinsert :call RInsert(<q-args>, "here")
command -range=% Rformat <line1>,<line2>:call RFormatCode()
command RBuildTags :call RBuildTags()
command -nargs=? -complete=customlist,RLisObjs Rhelp :call RAskHelp(<q-args>)
command -nargs=? -complete=dir RSourceDir :call RSourceDirectory(<q-args>)
command RStop :call SignalToR('SIGINT')
command RKill :call SignalToR('SIGKILL')
command -nargs=? RSend :call g:SendCmdToR(<q-args>)
command RDebugInfo :call ShowRDebugInfo()


"==========================================================================
" Global variables
" Convention: R_        for user options
"             rplugin_  for internal parameters
"==========================================================================

if !has_key(g:rplugin, "compldir")
    exe "source " . substitute(expand("<sfile>:h:h"), " ", "\\ ", "g") . "/R/setcompldir.vim"
endif

if exists("g:R_tmpdir")
    let g:rplugin.tmpdir = expand(g:R_tmpdir)
else
    if has("win32")
        if isdirectory($TMP)
            let g:rplugin.tmpdir = $TMP . "/NvimR-" . g:rplugin.userlogin
        elseif isdirectory($TEMP)
            let g:rplugin.tmpdir = $TEMP . "/Nvim-R-" . g:rplugin.userlogin
        else
            let g:rplugin.tmpdir = g:rplugin.uservimfiles . "/R/tmp"
        endif
        let g:rplugin.tmpdir = substitute(g:rplugin.tmpdir, "\\", "/", "g")
    else
        if isdirectory($TMPDIR)
            if $TMPDIR =~ "/$"
                let g:rplugin.tmpdir = $TMPDIR . "Nvim-R-" . g:rplugin.userlogin
            else
                let g:rplugin.tmpdir = $TMPDIR . "/Nvim-R-" . g:rplugin.userlogin
            endif
        elseif isdirectory("/dev/shm")
            let g:rplugin.tmpdir = "/dev/shm/Nvim-R-" . g:rplugin.userlogin
        elseif isdirectory("/tmp")
            let g:rplugin.tmpdir = "/tmp/Nvim-R-" . g:rplugin.userlogin
        else
            let g:rplugin.tmpdir = g:rplugin.uservimfiles . "/R/tmp"
        endif
    endif
endif

let $NVIMR_TMPDIR = g:rplugin.tmpdir
if !isdirectory(g:rplugin.tmpdir)
    call mkdir(g:rplugin.tmpdir, "p", 0700)
endif

" Make the file name of files to be sourced
if exists("g:R_remote_tmpdir")
    let s:Rsource_read = g:R_remote_tmpdir . "/Rsource-" . getpid()
else
    let s:Rsource_read = g:rplugin.tmpdir . "/Rsource-" . getpid()
endif
let s:Rsource_write = g:rplugin.tmpdir . "/Rsource-" . getpid()


let g:rplugin.is_darwin = system("uname") =~ "Darwin"

" Variables whose default value is fixed
let g:R_allnames          = get(g:, "R_allnames",           0)
let g:R_rmhidden          = get(g:, "R_rmhidden",           0)
let g:R_assign            = get(g:, "R_assign",             1)
let g:R_assign_map        = get(g:, "R_assign_map",       "_")
let g:R_paragraph_begin   = get(g:, "R_paragraph_begin",    1)
let g:R_strict_rst        = get(g:, "R_strict_rst",         1)
let g:R_synctex           = get(g:, "R_synctex",            1)
let g:R_non_r_compl       = get(g:, "R_non_r_compl",        1)
let g:R_nvim_wd           = get(g:, "R_nvim_wd",            0)
let g:R_commented_lines   = get(g:, "R_commented_lines",    0)
let g:R_auto_start        = get(g:, "R_auto_start",         0)
let g:R_after_start       = get(g:, "R_after_start",       [])
let g:R_after_ob_open     = get(g:, "R_after_ob_open",     [])
let g:R_min_editor_width  = get(g:, "R_min_editor_width",  80)
let g:R_rconsole_width    = get(g:, "R_rconsole_width",    80)
let g:R_rconsole_height   = get(g:, "R_rconsole_height",   15)
let g:R_listmethods       = get(g:, "R_listmethods",        0)
let g:R_specialplot       = get(g:, "R_specialplot",        0)
let g:R_notmuxconf        = get(g:, "R_notmuxconf",         0)
let g:R_routnotab         = get(g:, "R_routnotab",          0)
let g:R_editor_w          = get(g:, "R_editor_w",          66)
let g:R_help_w            = get(g:, "R_help_w",            46)
let g:R_objbr_w           = get(g:, "R_objbr_w",           40)
let g:R_objbr_h           = get(g:, "R_objbr_h",           10)
let g:R_objbr_opendf      = get(g:, "R_objbr_opendf",       1)
let g:R_objbr_openlist    = get(g:, "R_objbr_openlist",     0)
let g:R_objbr_allnames    = get(g:, "R_objbr_allnames",     0)
let g:R_applescript       = get(g:, "R_applescript",        0)
let g:R_esc_term          = get(g:, "R_esc_term",           1)
let g:R_close_term        = get(g:, "R_close_term",         1)
let g:R_buffer_opts       = get(g:, "R_buffer_opts", "winfixwidth nobuflisted")
let g:R_debug             = get(g:, "R_debug",              1)
let g:R_dbg_jump          = get(g:, "R_dbg_jump",           1)
let g:R_wait              = get(g:, "R_wait",              60)
let g:R_wait_reply        = get(g:, "R_wait_reply",         2)
let g:R_never_unmake_menu = get(g:, "R_never_unmake_menu",  0)
let g:R_insert_mode_cmds  = get(g:, "R_insert_mode_cmds",   0)
let g:R_disable_cmds      = get(g:, "R_disable_cmds",    [''])
let g:R_open_example      = get(g:, "R_open_example",       1)
let g:R_openhtml          = get(g:, "R_openhtml",           1)
let g:R_hi_fun            = get(g:, "R_hi_fun",             1)
let g:R_hi_fun_paren      = get(g:, "R_hi_fun_paren",       0)
let g:R_hi_fun_globenv    = get(g:, "R_hi_fun_globenv",     0)
let g:R_omni_tmp_file     = get(g:, "R_omni_tmp_file",      1)
let g:R_bracketed_paste   = get(g:, "R_bracketed_paste",    0)
let g:R_clear_console     = get(g:, "R_clear_console",      1)

if exists(":terminal") != 2
    let g:R_external_term = get(g:, "R_external_term", 1)
endif
if !has("nvim") && !exists("*term_start")
    " exists(':terminal') return 2 even when Vim does not have the +terminal feature
    let g:R_external_term = get(g:, "R_external_term", 1)
endif
let g:R_external_term = get(g:, "R_external_term", 0)

let s:editing_mode = "emacs"
if filereadable(expand("~/.inputrc"))
    let s:inputrc = readfile(expand("~/.inputrc"))
    call map(s:inputrc, 'substitute(v:val, "^\s*#.*", "", "")')
    call filter(s:inputrc, 'v:val =~ "set.*editing-mode"')
    if len(s:inputrc) && s:inputrc[len(s:inputrc) - 1] =~ '^\s*set\s*editing-mode\s*vi\>'
        let s:editing_mode = "vi"
    endif
    unlet s:inputrc
endif
let g:R_editing_mode = get(g:, "R_editing_mode", s:editing_mode)
unlet s:editing_mode

if has('win32') && !(type(g:R_external_term) == v:t_number && g:R_external_term == 0)
    " Sending multiple lines at once to Rgui on Windows does not work.
    let g:R_parenblock = get(g:, 'R_parenblock',         0)
else
    let g:R_parenblock = get(g:, 'R_parenblock',         1)
endif

if type(g:R_external_term) == v:t_number && g:R_external_term == 0
    let g:R_nvimpager = get(g:, 'R_nvimpager', 'vertical')
else
    let g:R_nvimpager = get(g:, 'R_nvimpager', 'tab')
endif

let g:R_objbr_place      = get(g:, "R_objbr_place",    "script,right")
let g:R_source_args      = get(g:, "R_source_args",                "")
let g:R_user_maps_only   = get(g:, "R_user_maps_only",              0)
let g:R_latexcmd         = get(g:, "R_latexcmd",          ["default"])
let g:R_texerr           = get(g:, "R_texerr",                      1)
let g:R_rmd_environment  = get(g:, "R_rmd_environment",  ".GlobalEnv")
let g:R_indent_commented = get(g:, "R_indent_commented",            1)

if g:rplugin.is_darwin
    let g:R_openpdf = get(g:, "R_openpdf", 1)
    let g:R_pdfviewer = "skim"
else
    let g:R_openpdf = get(g:, "R_openpdf", 2)
    if has("win32")
        let g:R_pdfviewer = "sumatra"
    else
        let g:R_pdfviewer = get(g:, "R_pdfviewer", "zathura")
    endif
endif

if !exists("g:r_indent_ess_comments")
    let g:r_indent_ess_comments = 0
endif
if g:r_indent_ess_comments
    if g:R_indent_commented
        let g:R_rcomment_string = get(g:, "R_rcomment_string", "## ")
    else
        let g:R_rcomment_string = get(g:, "R_rcomment_string", "### ")
    endif
else
    let g:R_rcomment_string = get(g:, "R_rcomment_string", "# ")
endif

if type(g:R_external_term) == v:t_number && g:R_external_term == 0
    let g:R_save_win_pos = 0
    let g:R_arrange_windows  = 0
endif
if has("win32")
    let g:R_save_win_pos    = get(g:, "R_save_win_pos",    1)
    let g:R_arrange_windows = get(g:, "R_arrange_windows", 1)
else
    let g:R_save_win_pos    = get(g:, "R_save_win_pos",    0)
    let g:R_arrange_windows = get(g:, "R_arrange_windows", 0)
endif

" Look for invalid options
let objbrplace = split(g:R_objbr_place, ',')
if len(objbrplace) > 2
    call RWarningMsg('Too many options for R_objbr_place.')
    let g:rplugin.failed = 1
    finish
endif
for pos in objbrplace
    if pos !=? 'console' && pos !=? 'script' &&
                \ pos !=# 'left' && pos !=# 'right' &&
                \ pos !=# 'LEFT' && pos !=# 'RIGHT' &&
                \ pos !=# 'above' && pos !=# 'below' &&
                \ pos !=# 'TOP' && pos !=# 'BOTTOM'
        call RWarningMsg('Invalid value for R_objbr_place: "' . pos . ". Please see Nvim-R's documentation.")
        let g:rplugin.failed = 1
        finish
    endif
endfor
unlet pos
unlet objbrplace


" ^K (\013) cleans from cursor to the right and ^U (\025) cleans from cursor
" to the left. However, ^U causes a beep if there is nothing to clean. The
" solution is to use ^A (\001) to move the cursor to the beginning of the line
" before sending ^K. But the control characters may cause problems in some
" circumstances.
let g:R_clear_line = get(g:, "R_clear_line", 0)


" ========================================================================
" Check if default mean of communication with R is OK

if g:rplugin.is_darwin
    if !exists("g:macvim_skim_app_path")
        let g:macvim_skim_app_path = '/Applications/Skim.app'
    endif
else
    let g:R_applescript = 0
endif


" ========================================================================

" Minimum width for the Object Browser
if g:R_objbr_w < 10
    let g:R_objbr_w = 10
endif

" Minimum height for the Object Browser
if g:R_objbr_h < 4
    let g:R_objbr_h = 4
endif

" Control the menu 'R' and the tool bar buttons
if !has_key(g:rplugin, "hasmenu")
    let g:rplugin.hasmenu = 0
endif

" List of marks that the plugin seeks to find the block to be sent to R
let s:all_marks = "abcdefghijklmnopqrstuvwxyz"

if filewritable('/dev/null')
    let s:null = "'/dev/null'"
elseif has("win32") && filewritable('NUL')
    let s:null = "'NUL'"
else
    let s:null = 'tempfile()'
endif

autocmd BufEnter * call RBufEnter()
if &filetype != "rbrowser"
    autocmd VimLeave * call RVimLeave()
endif

if v:windowid != 0 && $WINDOWID == ""
    let $WINDOWID = v:windowid
endif

let s:firstbuffer = expand("%:p")
let s:running_objbr = 0
let s:running_rhelp = 0
let s:R_pid = 0
let g:rplugin.myport = 0
let g:rplugin.nvimcom_port = 0

" Current view of the object browser: .GlobalEnv X loaded libraries
let g:rplugin.curview = "None"

if has("nvim")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/nvimrcom.vim"
else
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/vimrcom.vim"
endif

let s:nvimcom_version = "0"
let s:nvimcom_home = ""
let s:ncs_path = ""
let s:R_version = "0"
if filereadable(g:rplugin.compldir . "/nvimcom_info")
    let s:flines = readfile(g:rplugin.compldir . "/nvimcom_info")
    if len(s:flines) == 3
        let s:ncs_path = FindNCSpath(s:flines[1])
        if s:ncs_path != ''
            let s:nvimcom_version = s:flines[0]
            let s:nvimcom_home = s:flines[1]
            let s:R_version = s:flines[2]
        endif
    endif
    unlet s:flines
endif
if exists("g:R_nvimcom_home")
    let s:nvimcom_home = substitute(g:R_nvimcom_home, '/nvimcom', '', '')
endif

" SyncTeX options
let g:rplugin.has_wmctrl = 0

let s:docfile = g:rplugin.tmpdir . "/Rdoc"

" List of files to be deleted on VimLeave
let s:del_list = [s:Rsource_write,
            \ g:rplugin.tmpdir . '/run_R_stdout',
            \ g:rplugin.tmpdir . '/run_R_stderr']

" Create an empty file to avoid errors if the user do Ctrl-X Ctrl-O before
" starting R:
if &filetype != "rbrowser"
endif

" Set the name of R executable
if exists("g:R_app")
    let g:rplugin.R = g:R_app
    if !has("win32") && !exists("g:R_cmd")
        let g:R_cmd = g:R_app
    endif
else
    if has("win32")
        if type(g:R_external_term) == v:t_number && g:R_external_term == 0
            let g:rplugin.R = "Rterm.exe"
        else
            let g:rplugin.R = "Rgui.exe"
        endif
    else
        let g:rplugin.R = "R"
    endif
endif

" Set the name of R executable to be used in `R CMD`
if exists("g:R_cmd")
    let g:rplugin.Rcmd = g:R_cmd
else
    let g:rplugin.Rcmd = "R"
endif

if exists("g:RStudio_cmd")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/rstudio.vim"
endif

if has("win32")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/windows.vim"
else
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/unix.vim"
endif

if g:R_applescript
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/osx.vim"
endif

if type(g:R_external_term) == v:t_number && g:R_external_term == 0
    if has("nvim")
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/nvimbuffer.vim"
    else
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/vimbuffer.vim"
    endif
endif

if has("gui_running")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/gui_running.vim"
endif

if !executable(g:rplugin.R)
    call RWarningMsg("R executable not found: '" . g:rplugin.R . "'")
endif

let s:r_default_pkgs  = $R_DEFAULT_PACKAGES

function GlobalRInit(...)
    call CheckNvimcomVersion()
endfunction

function PreGlobalRealInit()
    call timer_start(1, "GlobalRInit")
endfunction

let s:starting_ncs = 1
if v:vim_did_enter == 0
    autocmd VimEnter * call PreGlobalRealInit()
else
    call GlobalRInit()
endif

" Check if Vim-R-plugin is installed
if exists("*WaitVimComStart")
    echohl WarningMsg
    call input("Please, uninstall Vim-R-plugin before using Nvim-R. [Press <Enter> to continue]")
    echohl None
endif

let s:ff = split(globpath(&rtp, "R/functions.vim"))
if len(s:ff) > 1
    function WarnDupNvimR()
        let ff = split(globpath(&rtp, "R/functions.vim"))
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

" 2016-08-25
if exists("g:R_nvimcom_wait")
    call RWarningMsg("The option R_nvimcom_wait is deprecated. Use R_wait (in seconds) instead.")
endif

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

" 2018-03-27: Delete this warning before releasing the next version
if g:R_openhtml == 2
    call RWarningMsg("Valid values of R_openhtml are only 0 and 1. The value 2 is no longer valid.")
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
