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

" Check if Vim-R-plugin is installed
if exists("*WaitVimComStart")
    echohl WarningMsg
    call input("Please, uninstall Vim-R-plugin before using Nvim-R. [Press <Enter> to continue]")
    echohl Normal
endif

" Do this only once
if exists("s:did_global_stuff")
    finish
endif
let s:did_global_stuff = 1

let g:rplugin_debug_info = {}

"==========================================================================
" Functions that are common to r, rnoweb, rhelp and rdoc
"==========================================================================

function RWarningMsg(wmsg)
    echohl WarningMsg
    echomsg a:wmsg
    echohl Normal
endfunction

function RWarningMsgInp(wmsg)
    let savedlz = &lazyredraw
    if savedlz == 0
        set lazyredraw
    endif
    let savedsm = &shortmess
    set shortmess-=T
    echohl WarningMsg
    call input(a:wmsg . " [Press <Enter> to continue] ")
    echohl Normal
    if savedlz == 0
        set nolazyredraw
    endif
    let &shortmess = savedsm
endfunction

if has("nvim")
    if !has("nvim-0.1.7")
        call RWarningMsgInp("Nvim-R requires Neovim >= 0.1.7.")
        let g:rplugin_failed = 1
        finish
    endif
elseif v:version < "800"
    call RWarningMsgInp("Nvim-R requires either Neovim >= 0.1.7 or Vim >= 8.0.")
    let g:rplugin_failed = 1
    finish
elseif !has("channel") || !has("job")
    call RWarningMsgInp("Nvim-R requires either Neovim >= 0.1.7 or Vim >= 8.0.\nIf using Vim, it must have been compiled with both +channel and +job features.\n")
    let g:rplugin_failed = 1
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

function ReadEvalReply()
    if g:R_wait_reply < 1
        let g:R_wait_reply = 1
    endif
    if g:R_wait_reply == 1
        let reply = "No reply within 1 second."
    else
        let reply = "No reply within " . g:R_wait_reply . " seconds."
    endif
    let haswaitwarn = 0
    let ii = 0
    while ii < g:R_wait_reply * 10
        sleep 100m
        if filereadable($NVIMR_TMPDIR . "/eval_reply")
            let tmp = readfile($NVIMR_TMPDIR . "/eval_reply")
            if len(tmp) > 0
                let reply = tmp[0]
                break
            endif
        endif
        let ii += 1
        if ii == 2
            echon "\rWaiting for reply"
            let haswaitwarn = 1
        endif
    endwhile
    if haswaitwarn
        echon "\r                 "
        redraw
    endif
    if reply =~ "^No reply within" || reply =~ "^Error" || reply == "INVALID" || reply == "ERROR" || reply == "EMPTY" || reply == "NO_ARGS" || reply == "NOT_EXISTS"
        return "R error: " . reply
    else
        return reply
    endif
endfunction

function CompleteChunkOptions()
    let cline = getline(".")
    let cpos = getpos(".")
    let idx1 = cpos[2] - 2
    let idx2 = cpos[2] - 1
    while cline[idx1] =~ '\w' || cline[idx1] == '.' || cline[idx1] == '_'
        let idx1 -= 1
    endwhile
    let idx1 += 1
    let base = strpart(cline, idx1, idx2 - idx1)
    let rr = []
    if strlen(base) == 0
        let newbase = '.'
    else
        let newbase = '^' . substitute(base, "\\$$", "", "")
    endif

    let ktopt = ["eval=;TRUE", "echo=;TRUE", "results=;'markup|asis|hold|hide'",
                \ "warning=;TRUE", "error=;TRUE", "message=;TRUE", "split=;FALSE",
                \ "include=;TRUE", "strip.white=;TRUE", "tidy=;FALSE", "tidy.opts=; ",
                \ "prompt=;FALSE", "comment=;'##'", "highlight=;TRUE", "background=;'#F7F7F7'",
                \ "cache=;FALSE", "cache.path=;'cache/'", "cache.vars=; ",
                \ "cache.lazy=;TRUE", "cache.comments=; ", "dependson=;''",
                \ "autodep=;FALSE", "fig.path=; ", "fig.keep=;'high|none|all|first|last'",
                \ "fig.show=;'asis|hold|animate|hide'", "dev=; ", "dev.args=; ",
                \ "fig.ext=; ", "dpi=;72", "fig.width=;7", "fig.height=;7",
                \ "out.width=;'7in'", "out.height=;'7in'", "out.extra=; ",
                \ "resize.width=; ", "resize.height=; ", "fig.align=;'left|right|center'",
                \ "fig.env=;'figure'", "fig.cap=;''", "fig.scap=;''", "fig.lp=;'fig:'",
                \ "fig.pos=;''", "fig.subcap=; ", "fig.process=; ", "interval=;1",
                \ "aniopts=;'controls.loop'", "code=; ", "ref.label=; ",
                \ "child=; ", "engine=;'R'", "opts.label=;''", "purl=;TRUE",
                \ 'R.options=; ']
    if &filetype == "rnoweb"
        let ktopt += ["external=;TRUE", "sanitize=;FALSE", "size=;'normalsize'"]
    endif
    if &filetype == "rmd" || &filetype == "rrst"
        let ktopt += ["fig.retina=;1"]
        if &filetype == "rmd"
            let ktopt += ["collapse=;FALSE"]
        endif
    endif
    call sort(ktopt)

    for kopt in ktopt
        if kopt =~ newbase
            let tmp1 = split(kopt, ";")
            let tmp2 = {'word': tmp1[0], 'menu': tmp1[1]}
            call add(rr, tmp2)
        endif
    endfor
    call complete(idx1 + 1, rr)
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

function RCompleteArgs()
    let line = getline(".")
    if (&filetype == "rnoweb" && line =~ "^<<.*>>=$") || (&filetype == "rmd" && line =~ "^``` *{r.*}$") || (&filetype == "rrst" && line =~ "^.. {r.*}$") || (&filetype == "r" && line =~ "^#\+")
        call CompleteChunkOptions()
        return ''
    endif

    let lnum = line(".")
    let cpos = getpos(".")
    let idx = cpos[2] - 2
    let idx2 = cpos[2] - 2
    call cursor(lnum, cpos[2] - 1)
    if line[idx2] == ' ' || line[idx2] == ',' || line[idx2] == '('
        let idx2 = cpos[2]
        let argkey = ''
    else
        let idx1 = idx2
        while line[idx1] =~ '\w' || line[idx1] == '.' || line[idx1] == '_'
            let idx1 -= 1
        endwhile
        let idx1 += 1
        let argkey = strpart(line, idx1, idx2 - idx1 + 1)
        let idx2 = cpos[2] - strlen(argkey)
    endif

    let np = 1
    let nl = 0

    while np != 0 && nl < 10
        if line[idx] == '('
            let np -= 1
        elseif line[idx] == ')'
            let np += 1
        endif
        if np == 0
            call cursor(lnum, idx)
            let rkeyword0 = RGetKeyword('@,48-57,_,.,:,$,@-@')
            let objclass = ""
            if rkeyword0 =~ "::"
                let pkg = '"' . substitute(rkeyword0, "::.*", "", "") . '"'
                let rkeyword0 = substitute(rkeyword0, ".*::", "", "")
            else
                if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
                    let objclass = RGetFirstObjClass(rkeyword0)
                endif
                let pkg = ""
            endif
            let rkeyword = '^' . rkeyword0 . "\x06"
            call cursor(cpos[1], cpos[2])

            " If R is running, use it
            if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
                call delete(g:rplugin_tmpdir . "/eval_reply")
                let msg = 'nvimcom:::nvim.args("' . rkeyword0 . '", "' . argkey . '"'
                if objclass != ""
                    let msg .= ', objclass = ' . objclass
                elseif pkg != ""
                    let msg .= ', pkg = ' . pkg
                endif
                if rkeyword0 == "library" || rkeyword0 == "require"
                    let isfirst = IsFirstRArg(lnum, cpos)
                else
                    let isfirst = 0
                endif
                if isfirst
                    let msg .= ', firstLibArg = TRUE'
                endif
                if g:R_show_arg_help
                    let msg .= ', extrainfo = TRUE)'
                else
                    let msg .= ')'
                endif
                call SendToNvimcom("\x08" . $NVIMR_ID . msg)

                if g:rplugin_nvimcom_port > 0
                    let g:rplugin_lastev = ReadEvalReply()
                    if g:rplugin_lastev !~ "^R error: "
                        let args = []
                        if g:rplugin_lastev[0] == "\x04" &&
                                    \ len(split(g:rplugin_lastev, "\x04")) == 1 ||
                                    \ g:rplugin_lastev == ""
                            return ''
                        endif
                        let tmp0 = split(g:rplugin_lastev, "\x04")
                        let tmp = split(tmp0[0], "\x09")
                        if(len(tmp) > 0)
                            for id in range(len(tmp))
                                let tmp1 = split(tmp[id], "\x08")
                                if len(tmp1) > 1
                                    let info = tmp1[1]
                                    let info = substitute(info, "\\\\N", "\n", "g")
                                else
                                    let info = " "
                                endif
                                let tmp2 = split(tmp1[0], "\x07")
                                if tmp2[0] == '...' || isfirst
                                    let word = tmp2[0]
                                else
                                    let word = tmp2[0] . " = "
                                endif
                                if word == "NO_ARGS = "
                                    call add(args,  {'word': " ", 'menu': "No arguments"})
                                elseif len(tmp2) > 1
                                    call add(args,  {'word': word, 'menu': tmp2[1], 'info': info})
                                else
                                    call add(args,  {'word': word, 'menu': ' ', 'info': info})
                                endif
                            endfor
                            if len(args) > 0 && len(tmp0) > 1
                                call add(args, {'word': ' ', 'menu': tmp0[1]})
                            endif
                            let s:is_completing = 1
                            call complete(idx2, args)
                        endif
                        return ''
                    endif
                endif
            endif

            " If R isn't running, use the prebuilt list of objects
            let flines = g:rplugin_omni_lines + s:globalenv_lines
            for omniL in flines
                if omniL =~ rkeyword && omniL =~ "\x06function\x06function\x06"
                    let tmp1 = split(omniL, "\x06")
                    if len(tmp1) < 5
                        return ''
                    endif
                    let info = tmp1[4]
                    let info = substitute(info, "\x08.*", "", "")
                    let argsL = split(info, "\x09")
                    let args = []
                    for id in range(len(argsL))
                        let newkey = '^' . argkey
                        let tmp2 = split(argsL[id], "\x07")
                        if argkey == '' || tmp2[0] =~ newkey
                            if tmp2[0] != '...'
                                let tmp2[0] = tmp2[0] . " = "
                            endif
                            if len(tmp2) == 2
                                let tmp3 = {'word': tmp2[0], 'menu': tmp2[1]}
                            elseif tmp2[0] == "NO_ARGS = "
                                let tmp3 = {'word': " ", 'menu': 'No arguments'}
                            else
                                let tmp3 = {'word': tmp2[0], 'menu': ''}
                            endif
                            call add(args, tmp3)
                        endif
                    endfor
                    call complete(idx2, args)
                    return ''
                endif
            endfor
            break
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
    call cursor(cpos[1], cpos[2])
    return ''
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
        let nkblist = execute("nmap")
        let nkbls = split(nkblist, "\n")
        let qcmd = "\\rq"
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

function ShowRSysLog(slog, fname, msg)
    let logl = split(a:slog, "\n")
    exe len(logl) . "split " . a:fname
    call setline(1, logl)
    set nomodified
    redraw
    call RWarningMsg(a:msg)
    if has("win32")
        call UnsetRHome()
    endif
    sleep 1
endfunction

function CheckNvimcomVersion()
    let neednew = 0
    if isdirectory(substitute(s:nvimcom_home, "nvimcom", "", "") . "00LOCK-nvimcom")
        call RWarningMsg('Perhaps you should delete the directory "' .
                    \ substitute(s:nvimcom_home, "nvimcom", "", "") . '00LOCK-nvimcom"')
    endif
    if s:nvimcom_home == ""
        let neednew = 1
    else
        if !filereadable(s:nvimcom_home . "/DESCRIPTION")
            let neednew = 1
        else
            let ndesc = readfile(s:nvimcom_home . "/DESCRIPTION")
            let nvers = substitute(ndesc[1], "Version: ", "", "")
            if nvers != s:required_nvimcom
                let neednew = 1
            else
                let rversion = split(system("R --version"))[2]
                if g:rplugin_R_version != rversion
                    let neednew = 1
                endif
            endif
        endif
    endif

    " Nvim-R might have been installed as root in a non writable directory.
    " We have to build nvimcom in a writable directory before installing it.
    if neednew
        exe "cd " . substitute(g:rplugin_tmpdir, ' ', '\\ ', 'g')
        if has("win32")
            call SetRHome()
        endif

        " The user libs directory may not exist yet if R was just upgraded
        if exists("g:R_remote_tmpdir")
            let tmpdir = g:R_remote_tmpdir
        else
            let tmpdir = g:rplugin_tmpdir
        endif
        let rcode = [ 'sink("' . tmpdir . '/libpaths")',
                    \ 'cat(.libPaths()[1L],',
                    \ '    unlist(strsplit(Sys.getenv("R_LIBS_USER"), .Platform$path.sep))[1L],',
                    \ '    sep = "\n")',
                    \ 'sink()']
        if has("win32") && g:R_in_buffer == 0
            " g:rplugin_R is Rgui.exe which will ignore the script
            let slog = system('R --no-save', rcode)
        else
            " Works even with local Vim and remote R (but not on Windows)
            let slog = system(g:rplugin_Rcmd . ' --no-save', rcode)
        endif
        if v:shell_error
            call RWarningMsg(slog)
            return 0
        endif
        let libpaths = readfile(g:rplugin_tmpdir . "/libpaths")
        if !(isdirectory(expand(libpaths[0])) && filewritable(expand(libpaths[0])) == 2) && !exists("g:R_remote_tmpdir")
            if !isdirectory(expand(libpaths[1]))
                let resp = input('"' . libpaths[0] . '" is not writable. Should "' . libpaths[1] . '" be created now? [y/n] ')
                if resp[0] == "y" || resp[0] == "Y"
                    call mkdir(expand(libpaths[1]), "p")
                endif
                echo " "
            endif
        endif
        call delete(g:rplugin_tmpdir . "/libpaths")

        echo "Updating nvimcom... "
        if !exists("g:R_remote_tmpdir")
            let slog = system(g:rplugin_Rcmd . ' CMD build "' . g:rplugin_home . '/R/nvimcom"')
        else
            call system('cp -R "' . g:rplugin_home . '/R/nvimcom" .')
            let slog = system(g:rplugin_Rcmd . ' CMD build "' . g:R_remote_tmpdir . '/nvimcom"')
            call system('rm -rf "' . g:R_tmpdir . '/nvimcom"')
        endif
        if v:shell_error
            call ShowRSysLog(slog, "Error_building_nvimcom", "Failed to build nvimcom")
            return 0
        else
            if has("win32")
                call SetRtoolsPath()
                let slog = system(g:rplugin_Rcmd . " CMD INSTALL --no-multiarch nvimcom_" . s:required_nvimcom . ".tar.gz")
                call UnSetRtoolsPath()
            else
                let slog = system(g:rplugin_Rcmd . " CMD INSTALL nvimcom_" . s:required_nvimcom . ".tar.gz")
            endif
            if v:shell_error
                call ShowRSysLog(slog, "Error_installing_nvimcom", "Failed to install nvimcom")
                if has("win32")
                    call CheckRtools()
                endif
                return 0
            else
                echon "OK!"
            endif
        endif
        if has("win32")
            call UnsetRHome()
        endif
        call delete("nvimcom_" . s:required_nvimcom . ".tar.gz")
        silent cd -
    endif
    return 1
endfunction

" Start R
function StartR(whatr)
    if !isdirectory(g:rplugin_tmpdir)
        call mkdir(g:rplugin_tmpdir, "p", 0700)
    endif
    call writefile([], g:rplugin_tmpdir . "/globenv_" . $NVIMR_ID)
    call writefile([], g:rplugin_tmpdir . "/liblist_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/libnames_" . $NVIMR_ID)

    call AddForDeletion(g:rplugin_tmpdir . "/eval_reply")
    call AddForDeletion(g:rplugin_tmpdir . "/globenv_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin_tmpdir . "/liblist_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin_tmpdir . "/libnames_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin_tmpdir . "/start_options.R")
    call AddForDeletion(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
    if has("win32")
        call AddForDeletion(g:rplugin_tmpdir . "/waitnvimcom.bat")
        call AddForDeletion(g:rplugin_tmpdir . "/run_cmd.bat")
    else
        call AddForDeletion(g:rplugin_tmpdir . "/waitnvimcom.sh")
    endif

    if !CheckNvimcomVersion()
        return
    endif

    if $R_DEFAULT_PACKAGES == ""
        let $R_DEFAULT_PACKAGES = "datasets,utils,grDevices,graphics,stats,methods,nvimcom"
    elseif $R_DEFAULT_PACKAGES !~ "nvimcom"
        let $R_DEFAULT_PACKAGES .= ",nvimcom"
    endif
    if exists("g:RStudio_cmd") && $R_DEFAULT_PACKAGES !~ "rstudioapi"
        let $R_DEFAULT_PACKAGES .= ",rstudioapi"
    endif

    if a:whatr =~ "custom"
        call inputsave()
        let r_args = input('Enter parameters for R: ')
        call inputrestore()
        let g:rplugin_r_args = split(r_args)
    else
        if exists("g:R_args")
            let g:rplugin_r_args = g:R_args
        else
            let g:rplugin_r_args = []
        endif
    endif

    if g:R_objbr_opendf
        let start_options = ['options(nvimcom.opendf = TRUE)']
    else
        let start_options = ['options(nvimcom.opendf = FALSE)']
    endif
    if g:R_objbr_openlist
        let start_options += ['options(nvimcom.openlist = TRUE)']
    else
        let start_options += ['options(nvimcom.openlist = FALSE)']
    endif
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
    if g:R_objbr_labelerr
        let start_options += ['options(nvimcom.labelerr = TRUE)']
    else
        let start_options += ['options(nvimcom.labelerr = FALSE)']
    endif
    if g:R_nvimpager == "no"
        let start_options += ['options(nvimcom.nvimpager = FALSE)']
    else
        let start_options += ['options(nvimcom.nvimpager = TRUE)']
    endif
    if g:R_in_buffer && g:R_esc_term
        let start_options += ['options(editor = nvimcom:::nvim.edit)']
    endif

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
    let start_options += ['if(utils::packageVersion("nvimcom") != "' .
                \ s:required_nvimcom_dot .
                \ '") warning("Your version of Nvim-R requires nvimcom-' .
                \ s:required_nvimcom .
                \ '.", call. = FALSE)']
    call writefile(start_options, g:rplugin_tmpdir . "/start_options.R")

    if exists("g:RStudio_cmd")
        call StartRStudio()
        return
    endif

    if g:R_in_buffer
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

    let args_str = join(g:rplugin_r_args)
    if args_str == ""
        let rcmd = g:rplugin_R
    else
        let rcmd = g:rplugin_R . " " . args_str
    endif

    if g:R_tmux_split
        call StartR_TmuxSplit(rcmd)
    else
        call StartR_ExternalTerm(rcmd)
    endif
endfunction

" Send SIGINT to R
function StopR()
    if s:R_pid
        call system("kill -s SIGINT " . s:R_pid)
    endif
endfunction

function CheckIfNvimcomIsRunning(...)
    let s:nseconds = s:nseconds - 1
    if filereadable(g:rplugin_tmpdir . '/nvimcom_running_' . $NVIMR_ID)
        call GetNvimcomInfo()
    elseif s:nseconds > 0
        call timer_start(1000, "CheckIfNvimcomIsRunning")
    else
       call RWarningMsg("R did not load nvimcom yet")
    endif
endfunction

function WaitNvimcomStart()
    let args_str = join(g:rplugin_r_args)
    if args_str =~ "vanilla"
        return 0
    endif
    if g:R_wait < 2
        g:R_wait = 2
    endif

    let s:nseconds = g:R_wait
    call timer_start(1000, "CheckIfNvimcomIsRunning")
endfunction

function GetNvimcomInfo()
    sleep 1200m
    if filereadable(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
        let vr = readfile(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
        let s:nvimcom_version = vr[0]
        let s:nvimcom_home = vr[1]
        let g:rplugin_nvimcom_port = vr[2]
        let s:R_pid = vr[3]
        let $RCONSOLE = vr[4]
        let search_list = vr[5]
        let g:rplugin_R_version = vr[6]
        if len(vr) == 8
            let $R_IP_ADDRESS = vr[7]
        endif
        call delete(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
        if s:nvimcom_version != s:required_nvimcom_dot
            call RWarningMsg('This version of Nvim-R requires nvimcom ' .
                        \ s:required_nvimcom . '.')
            sleep 1
        endif

        if search_list =~ "package:colorout" && !exists("g:R_hl_term")
            let g:R_hl_term = 0
        endif

        if exists("g:R_nvimcom_home")
            let s:nvimcom_home = g:R_nvimcom_home
        endif

        if isdirectory(s:nvimcom_home . "/bin/x64")
            let g:rplugin_nvimcom_bin_dir = s:nvimcom_home . "/bin/x64"
        elseif isdirectory(s:nvimcom_home . "/bin/i386")
            let g:rplugin_nvimcom_bin_dir = s:nvimcom_home . "/bin/i386"
        else
            let g:rplugin_nvimcom_bin_dir = s:nvimcom_home . "/bin"
        endif

        call writefile([s:nvimcom_version, s:nvimcom_home,
                    \ g:rplugin_nvimcom_bin_dir, g:rplugin_R_version],
                    \ g:rplugin_compldir . "/nvimcom_info")

        if has("win32")
            let nvc = "nclientserver.exe"
            if $PATH !~ g:rplugin_nvimcom_bin_dir
                let $PATH = g:rplugin_nvimcom_bin_dir . ';' . $PATH
            endif
        else
            let nvc = "nclientserver"
            if $PATH !~ g:rplugin_nvimcom_bin_dir
                let $PATH = g:rplugin_nvimcom_bin_dir . ':' . $PATH
            endif
        endif
        if filereadable(g:rplugin_nvimcom_bin_dir . '/' . nvc)
            " Set nvimcom port in the nclientserver
            let $NVIMCOMPORT = g:rplugin_nvimcom_port
            " Set RConsole window ID in nclientserver to ArrangeWindows()
            if has("win32")
                if $RCONSOLE == "0"
                    call RWarningMsg("nvimcom did not save R window ID")
                endif
            endif
            if !IsJobRunning("ClientServer")
                let g:rplugin_jobs["ClientServer"] = StartJob(nvc, g:rplugin_job_handlers)
            else
                " ClientServer already started
                if has("win32")
                    call JobStdin(g:rplugin_jobs["ClientServer"], "\001" . g:rplugin_nvimcom_port . " " . $RCONSOLE . "\n")
                else
                    call JobStdin(g:rplugin_jobs["ClientServer"], "\001" . g:rplugin_nvimcom_port . "\n")
                endif
                call SendToNvimcom("\001" . g:rplugin_myport)
            endif
        else
            call RWarningMsg('Application "' . nvc . '" not found.')
        endif

        if exists("g:RStudio_cmd")
            if has("win32") && g:R_arrange_windows && filereadable(g:rplugin_compldir . "/win_pos")
                " ArrangeWindows
                call JobStdin(g:rplugin_jobs["ClientServer"], "\005" . g:rplugin_compldir . "\n")
            endif
            let g:SendCmdToR = function('SendCmdToRStudio')
        elseif g:R_in_buffer
            let g:SendCmdToR = function('SendCmdToR_Buffer')
        elseif has("win32")
            if g:R_arrange_windows && filereadable(g:rplugin_compldir . "/win_pos")
                " ArrangeWindows
                call JobStdin(g:rplugin_jobs["ClientServer"], "\005" . g:rplugin_compldir . "\n")
            endif
            let g:SendCmdToR = function('SendCmdToR_Windows')
        elseif g:R_applescript
            call foreground()
            sleep 200m
        elseif g:R_tmux_split
            " Environment variables persist across Tmux windows.
            " Unset NVIMR_TMPDIR to avoid nvimcom loading its C library
            " when R was not started by Neovim:
            call system("tmux set-environment -u NVIMR_TMPDIR")
            " Also unset R_DEFAULT_PACKAGES so that other R instances do not
            " load nvimcom unnecessarily
            call system("tmux set-environment -u R_DEFAULT_PACKAGES")
        else
            call delete(g:rplugin_tmpdir . "/initterm_" . $NVIMR_ID . ".sh")
            call delete(g:rplugin_tmpdir . "/openR")
        endif

        if g:R_after_start != ''
            call system(g:R_after_start)
        endif
        return
    else
        if filereadable(g:rplugin_compldir . "/nvimcom_info")
            " The information on nvimcom home might be invalid if R was upgraded
            call delete(g:rplugin_compldir . "/nvimcom_info")
            let s:nvimcom_version = "0"
            let s:nvimcom_home = ""
            let g:rplugin_nvimcom_bin_dir = ""
            let msg = "The package nvimcom wasn't loaded yet. Please, quit R and try again."
        else
            let msg = "The package nvimcom wasn't loaded yet. Please, see  :h nvimcom-not-loaded"
        endif
        if g:R_tmux_split
            call RWarningMsgInp(msg)
        else
            call RWarningMsg(msg)
            sleep 500m
        endif
        return 0
    endif
endfunction

function StartObjBrowser()
    " Either load or reload the Object Browser
    let savesb = &switchbuf
    set switchbuf=useopen,usetab
    if bufloaded(b:objbrtitle)
        exe "sb " . b:objbrtitle
    else
        " Copy the values of some local variables that will be inherited
        let g:tmp_objbrtitle = b:objbrtitle
        let g:tmp_curbufname = bufname("%")

        let splr = &splitright
        let splb = &splitbelow
        if g:R_objbr_place =~ "left" || g:R_objbr_place =~ "right"
            if g:R_objbr_place =~ "left"
                set nosplitright
            else
                set splitright
            endif
        else
            if g:R_objbr_place =~ "bottom"
                set splitbelow
            else
                set nosplitbelow
            endif
        endif

        if g:R_objbr_place =~ "console"
            exe 'sb ' . g:rplugin_R_bufname
        endif
        if g:R_objbr_place =~ "left" || g:R_objbr_place =~ "right"
            sil exe "vsplit " . b:objbrtitle
            sil exe "vertical resize " . g:R_objbr_w
        else
            sil exe "split " . b:objbrtitle
            sil exe "resize " . g:R_objbr_h
        endif
        let &splitright = splr
        let $splitbelow = splb
        sil set filetype=rbrowser

        " Inheritance of some local variables
        let b:objbrtitle = g:tmp_objbrtitle
        let b:rscript_buffer = g:tmp_curbufname
        unlet g:tmp_objbrtitle
        unlet g:tmp_curbufname
        call SendToNvimcom("\002" . g:rplugin_myport)
    endif
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

    call StartObjBrowser()
    let s:running_objbr = 0
    return
endfunction

function RBrOpenCloseLs(stt)
    call SendToNvimcom("\007" . a:stt)
endfunction

function SendToNvimcom(cmd)
    if !IsJobRunning("ClientServer")
        call RWarningMsg("ClientServer not running.")
        return
    endif
    call JobStdin(g:rplugin_jobs["ClientServer"], "\002" . a:cmd . "\n")
endfunction

function RSetMyPort(p)
    let g:rplugin_myport = a:p
    let $NVIMR_PORT = a:p
    if IsJobRunning("ClientServer")
        if g:rplugin_nvimcom_port
            call SendToNvimcom("\001" . g:rplugin_myport)
        endif
    endif
endfunction

function RFormatCode() range
    if g:rplugin_nvimcom_port == 0
        return
    endif

    let lns = getline(a:firstline, a:lastline)
    call writefile(lns, g:rplugin_tmpdir . "/unformatted_code")
    call AddForDeletion(g:rplugin_tmpdir . "/unformatted_code")
    call AddForDeletion(g:rplugin_tmpdir . "/formatted_code")

    let wco = &textwidth
    if wco == 0
        let wco = 78
    elseif wco < 20
        let wco = 20
    elseif wco > 180
        let wco = 180
    endif
    call delete(g:rplugin_tmpdir . "/eval_reply")
    call SendToNvimcom("\x08" . $NVIMR_ID . 'formatR::tidy_source("' . g:rplugin_tmpdir . '/unformatted_code", file = "' . g:rplugin_tmpdir . '/formatted_code", width.cutoff = ' . wco . ')')
    let g:rplugin_lastev = ReadEvalReply()
    if g:rplugin_lastev =~ "^R error: "
        call RWarningMsg(g:rplugin_lastev)
        return
    endif
    let lns = readfile(g:rplugin_tmpdir . "/formatted_code")
    silent exe a:firstline . "," . a:lastline . "delete"
    call append(a:firstline - 1, lns)
    echo (a:lastline - a:firstline + 1) . " lines formatted."
endfunction

function RInsert(...)
    if g:rplugin_nvimcom_port == 0
        return
    endif

    call delete(g:rplugin_tmpdir . "/eval_reply")
    call delete(g:rplugin_tmpdir . "/Rinsert")
    call AddForDeletion(g:rplugin_tmpdir . "/Rinsert")

    call SendToNvimcom("\x08" . $NVIMR_ID . 'capture.output(' . a:1 . ', file = "' . g:rplugin_tmpdir . '/Rinsert")')
    let g:rplugin_lastev = ReadEvalReply()
    if g:rplugin_lastev =~ "^R error: "
        call RWarningMsg(g:rplugin_lastev)
    else
        if a:0 == 2 && a:2 == "newtab"
            tabnew
            set ft=rout
        endif
        silent exe "read " . substitute(g:rplugin_tmpdir, ' ', '\\ ', 'g') . "/Rinsert"
    endif
endfunction

function SendLineToRAndInsertOutput()
    let lin = getline(".")
    call RInsert("print(" . lin . ")")
    let curpos = getpos(".")
    " comment the output
    let ilines = readfile(g:rplugin_tmpdir . "/Rinsert")
    for iln in ilines
        call RSimpleCommentLine("normal", "c")
        normal! j
    endfor
    call setpos(".", curpos)
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
    if a:outf =~ g:rplugin_tmpdir
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

function RViewDF(oname)
    if exists("g:R_csv_app")
        if !executable(g:R_csv_app)
            call RWarningMsg('R_csv_app ("' . g:R_csv_app . '") is not executable')
            return
        endif
        normal! :<Esc>
        call system('cp "' . g:rplugin_tmpdir . '/Rinsert" "' . a:oname . '.csv"')
        if has("win32")
            silent exe '!start "' . g:R_csv_app . '" "' . a:oname . '.csv"'
        else
            call system(g:R_csv_app . ' "' . a:oname . '.csv" >/dev/null 2>/dev/null &')
        endif
        return
    endif
    echo 'Opening "' . a:oname . '.csv"'
    silent exe 'tabnew ' . a:oname . '.csv'
    silent 1,$d
    silent exe 'read ' . substitute(g:rplugin_tmpdir, " ", '\\ ', 'g') . '/Rinsert'
    silent 1d
    set filetype=csv
    set nomodified
    redraw
    if !exists(":CSVTable") && g:R_csv_warn
        call RWarningMsg("csv.vim is not installed (http://www.vim.org/scripts/script.php?script_id=2830)")
    endif
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
        call writefile(lines, s:Rsource)
        call AddForDeletion(g:rplugin_tmpdir . '/Rinsert')
        call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim_capture_source_output("' . s:Rsource . '", "' . g:rplugin_tmpdir . '/Rinsert")')
        return 1
    endif

    " The "brackted paste" option is not documented because it is not well
    " tested and source() have always worked flawlessly.
    if g:R_source_args == "bracketed paste"
        let rcmd = "\x1b[200~" . join(lines, "\n") . "\x1b[201~"
    else
        call writefile(lines, s:Rsource)
        let sargs = GetSourceArgs(a:2)
        let rcmd = 'base::source("' . s:Rsource . '"' . sargs . ')'
    endif


    let ok = g:SendCmdToR(rcmd)
    return ok
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
    let ok = RSourceLines(lines, a:e)
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
    let ok = RSourceLines(lines, a:e)
    if  ok == 0
        return
    endif
    if a:m == "down"
        call cursor(lastline, 1)
        call GoDown()
    endif
endfunction

" Send selection to R
function SendSelectionToR(...)
    if &filetype != "r"
        if b:IsInRCode(0) == 0
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
        let line = CleanOxygenLine(line)
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
        let lines[idx] = CleanOxygenLine(lines[idx])
        let curline += 1
    endfor
    call setpos(".", curpos)

    if a:0 == 3 && a:3 == "NewtabInsert"
        let ok = RSourceLines(lines, a:1, "NewtabInsert")
    else
        let ok = RSourceLines(lines, a:1)
    endif

    if ok == 0
        return
    endif

    if a:2 == "down"
        call GoDown()
    else
        normal! gv
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
                    \ (&filetype == "rmd" && line =~ "^[ \t]*```{r"))
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
    let ok = RSourceLines(lines, a:e)
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
        call RWarningMsg('Strange filetype (SendFHChunkToR): "' . &filetype '"')
    endif

    let codelines = []
    let here = line(".")
    let curbuf = getline(1, "$")
    let idx = 0
    while idx < here
        if curbuf[idx] =~ begchk
            " Child R chunk
            if curbuf[idx] =~ chdchk
                " First run everything up to child chunk and reset buffer
                call RSourceLines(codelines, "silent")
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
    call RSourceLines(codelines, "silent")
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

" Send current line to R.
function SendLineToR(godown)
    let line = getline(".")
    if strlen(line) == 0
        if a:godown =~ "down"
            call GoDown()
        endif
        return
    endif

    if &filetype == "rnoweb"
        if line =~ "^@$"
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
        if line =~ "^```$"
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
        if RmdIsInRCode(1) == 0
            return
        endif
    endif

    if &filetype == "rrst"
        if line =~ "^\.\. \.\.$"
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

    let ok = g:SendCmdToR(line)
    if ok
        if a:godown =~ "down"
            call GoDown()
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
    if has("win32") && !g:R_in_buffer
        call JobStdin(g:rplugin_jobs["ClientServer"], "\006\n")
        sleep 50m
        call JobStdin(g:rplugin_jobs["ClientServer"], "\007\n")
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
    if exists("g:rplugin_rconsole_pane")
        unlet g:rplugin_rconsole_pane
    endif

    call delete(g:rplugin_tmpdir . "/globenv_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/liblist_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/libnames_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
    let g:SendCmdToR = function('SendCmdToR_fake')
    let s:R_pid = 0
    let g:rplugin_nvimcom_port = 0

    if g:R_tmux_split && g:R_tmux_title != "automatic" && g:R_tmux_title != ""
        call system("tmux set automatic-rename on")
    endif

    if bufloaded(b:objbrtitle)
        exe "bunload! " . b:objbrtitle
        sleep 30m
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

    if g:R_save_win_pos
        " SaveWinPos
        call JobStdin(g:rplugin_jobs["ClientServer"], "\004" . $NVIMR_COMPLDIR . "\n")
    endif

    " In Neovim, the cursor must be in term buffer to get TermClose event
    " triggered
    if g:R_in_buffer && exists("g:rplugin_R_bufname") && has("nvim")
        exe "sbuffer " . g:rplugin_R_bufname
        startinsert
    endif

    if bufloaded(b:objbrtitle)
        exe "bunload! " . b:objbrtitle
        sleep 30m
    endif

    call g:SendCmdToR(qcmd)

    if g:R_tmux_split && a:how == "save"
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
        let s:rdoctitle = a:rkeyword . "\\ (help)"
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

function RGetFirstObjClass(rkeyword)
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

    " Fix some problems
    if firstobj =~ '^"' && firstobj !~ '"$'
        let firstobj = firstobj . '"'
    elseif firstobj =~ "^'" && firstobj !~ "'$"
        let firstobj = firstobj . "'"
    endif
    if firstobj =~ "^'" && firstobj =~ "'$"
        let firstobj = substitute(firstobj, "^'", '"', "")
        let firstobj = substitute(firstobj, "'$", '"', "")
    endif
    if firstobj =~ '='
        let firstobj = "eval(expression(" . firstobj . "))"
    endif

    let objclass = ""
    call SendToNvimcom("\x08" . $NVIMR_ID . "nvimcom:::nvim.getclass(" . firstobj . ")")
    if g:rplugin_nvimcom_port > 0
        let g:rplugin_lastev = ReadEvalReply()
        if g:rplugin_lastev !~ "^R error: "
            let objclass = '"' . g:rplugin_lastev . '"'
        endif
    endif

    return objclass
endfunction

" Show R's help doc in Nvim's buffer
" (based  on pydoc plugin)
function AskRDoc(rkeyword, package, getclass)
    if filewritable(s:docfile)
        call delete(s:docfile)
    endif
    call AddForDeletion(s:docfile)

    let objclass = ""
    if bufname("%") =~ "Object_Browser" || (exists("g:rplugin_R_bufname") && bufname("%") == g:rplugin_R_bufname)
        let savesb = &switchbuf
        set switchbuf=useopen,usetab
        exe "sb " . b:rscript_buffer
        exe "set switchbuf=" . savesb
    else
        if a:getclass
            let objclass = RGetFirstObjClass(a:rkeyword)
        endif
    endif

    call SetRTextWidth(a:rkeyword)

    if objclass == "" && a:package == ""
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . s:htw . 'L)'
    elseif a:package != ""
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . s:htw . 'L, package="' . a:package  . '")'
    else
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . s:htw . 'L, ' . objclass . ')'
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
            call delete(g:rplugin_tmpdir . "/eval_reply")
            call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim.help("' . msgs[-1] . '", ' . s:htw . 'L, package="' . msgs[chn] . '")')
        endif
        return
    endif

    if exists("g:rplugin_R_bufname") && bufname("%") == g:rplugin_R_bufname
        " Exit Terminal mode and go to Normal mode
        stopinsert
    endif

    " If the help command was triggered in the R Console, jump to Vim pane
    if g:R_tmux_split && !s:running_rhelp
        let slog = system("tmux select-pane -t " . g:rplugin_editor_pane)
        if v:shell_error
            call RWarningMsg(slog)
        endif
    endif
    let s:running_rhelp = 0

    if bufname("%") =~ "Object_Browser" || (exists("g:rplugin_R_bufname") && bufname("%") == g:rplugin_R_bufname)
        let savesb = &switchbuf
        set switchbuf=useopen,usetab
        exe "sb " . b:rscript_buffer
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
            if g:R_in_buffer
                let g:R_nvimpager = "vertical"
            else
                let g:R_nvimpager = "tab"
            endif
            call ShowRDoc(a:rkeyword)
            return
        else
            echohl WarningMsg
            echomsg 'Invalid R_nvimpager value: "' . g:R_nvimpager . '". Valid values are: "tab", "vertical", "horizontal", "tabnew" and "no".'
            echohl Normal
            return
        endif
    endif

    setlocal modifiable
    let g:rplugin_curbuf = bufname("%")

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
        exe 'nmap <buffer><silent> <CR> :call AskRDoc("' . rkeyw . '", expand("<cword>"), 0)<CR>'
        redraw
        call cursor(5, 4)
    else
        set filetype=rdoc
        call cursor(1, 1)
    endif
    let @@ = save_unnamed_reg
    setlocal nomodified
    stopinsert
    redraw
endfunction

" This function is called by nvimcom
function ShowRObject(fname)
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

    call ROpenPDF2(a:fullpath)
endfunction

function RSetPDFViewer()
    let g:rplugin_pdfviewer = tolower(g:R_pdfviewer)

    if g:rplugin_pdfviewer == "zathura"
        exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/zathura.vim"
    elseif g:rplugin_pdfviewer == "evince"
        exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/evince.vim"
    elseif g:rplugin_pdfviewer == "okular"
        exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/okular.vim"
    elseif has("win32") && g:rplugin_pdfviewer == "sumatra"
        exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/sumatra.vim"
    elseif g:rplugin_is_darwin && g:rplugin_pdfviewer == "skim"
        exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/skim.vim"
    else
        call RWarningMsgInp('Invalid value for R_pdfviewer: "' . g:R_pdfviewer . '"')
    endif

    if !has("win32") && !g:rplugin_is_darwin
        if executable("wmctrl")
            let g:rplugin_has_wmctrl = 1
        else
            let g:rplugin_has_wmctrl = 0
            if &filetype == "rnoweb"
                call RWarningMsgInp("The application wmctrl must be installed to edit Rnoweb effectively.")
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

function DisplayArgs()
    if !exists("s:status_line")
        let s:sttl_count = 0
        let s:status_line = [&statusline, "", "", "", "", "", "", ""]
    endif

    let s:sttl_count += 1
    if s:sttl_count > 7
        let s:sttl_count = 7
        return
    endif

    if &filetype == "r" || b:IsInRCode(0)
        let rkeyword = RGetKeyword('@,48-57,_,.,$,@-@')
        let fargs = "Not a function"
        for omniL in g:rplugin_omni_lines
            if omniL =~ '^' . rkeyword . "\x06"
                let omniL = substitute(omniL, "\x08.*", "", "")
                let tmp = split(omniL, "\x06")
                if len(tmp) < 5
                    break
                else
                    let fargs = tmp[4]
                endif
            endif
        endfor
        if fargs !~ "Not a function"
            let fargs = substitute(fargs, "NO_ARGS", "", "g")
            let fargs = substitute(fargs, "\x07", "=", "g")
            let fargs = substitute(fargs, "\x09", ", ", "g")
            let fargs = substitute(fargs, "%", "%%", "g")
            let fargs = substitute(fargs, '\\', '\\\\', "g")
            let sline = substitute(g:R_sttline_fmt, "%fun", rkeyword, "g")
            let sline = substitute(sline, "%args", fargs, "g") . '%<'
            if exists("g:R_set_sttline_cmd")
                silent exe g:R_set_sttline_cmd
            endif
            let s:status_line[s:sttl_count] = sline
            silent setlocal statusline=%!RArgsStatusLine()
        endif
    endif
endfunction

function RArgsStatusLine()
    return s:status_line[s:sttl_count]
endfunction

function RestoreStatusLine(backtozero)
    if !exists("s:status_line")
        let s:sttl_count = 0
        let s:status_line = [&statusline, "", "", "", "", "", "", ""]
    endif

    let s:sttl_count -= 1
    if s:sttl_count < 0
        " The status line is already in its original state
        let s:sttl_count = 0
        return
    endif

    if a:backtozero
        let s:sttl_count = 0
    endif

    if s:sttl_count == 0
        if exists("g:R_restore_sttline_cmd")
            exe g:R_restore_sttline_cmd
        elseif exists("*airline#update_statusline")
            call airline#update_statusline()
        else
            let &statusline = s:status_line[0]
        endif
    else
        silent setlocal statusline=%!RArgsStatusLine()
    endif
endfunction

function RSetStatusLine()
    if !(&filetype == "r" || &filetype == "rnoweb" || &filetype == "rmd" || &filetype == "rrst" || &filetype == "rhelp")
        return
    elseif v:char == '('
        call DisplayArgs()
    elseif v:char == ')'
        call RestoreStatusLine(0)
    endif
endfunction

function PrintRObject(rkeyword)
    if bufname("%") =~ "Object_Browser"
        let objclass = ""
    else
        let objclass = RGetFirstObjClass(a:rkeyword)
    endif
    if objclass == ""
        call g:SendCmdToR("print(" . a:rkeyword . ")")
    else
        call g:SendCmdToR('nvim.print("' . a:rkeyword . '", ' . objclass . ")")
    endif
endfunction

function OpenRExample()
    if bufloaded(g:rplugin_tmpdir . "/example.R")
        exe "bunload! " . substitute(g:rplugin_tmpdir, ' ', '\\ ', 'g')
    endif
    if g:R_nvimpager == "tabnew" || g:R_nvimpager == "tab"
        exe "tabnew " . substitute(g:rplugin_tmpdir, ' ', '\\ ', 'g') . "/example.R"
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
            exe "belowright vsplit " . substitute(g:rplugin_tmpdir, ' ', '\\ ', 'g') . "/example.R"
        else
            exe "belowright split " . substitute(g:rplugin_tmpdir, ' ', '\\ ', 'g') . "/example.R"
        endif
    endif
    nmap <buffer><silent> q :q<CR>
    setlocal bufhidden=wipe
    setlocal noswapfile
    set buftype=nofile
    call delete(g:rplugin_tmpdir . "/example.R")
endfunction

" Call R functions for the word under cursor
function RAction(rcmd, ...)
    if &filetype == "rbrowser"
        let rkeyword = RBrowserGetName(1, 0)
    elseif a:0 == 1 && a:1 == "v" && line("'<") == line("'>")
        let rkeyword = strpart(getline("'>"), col("'<") - 1, col("'>") - col("'<") + 1)
    elseif a:0 == 1 && a:1 != "v"
        let rkeyword = RGetKeyword(a:1)
    else
        if a:rcmd == "help" || (a:rcmd == "args" && g:R_listmethods) || a:rcmd == "viewdf"
            let rkeyword = RGetKeyword('@,48-57,_,.,$,@-@')
        else
            let rkeyword = RGetKeyword('@,48-57,_,.,:,$,@-@')
        endif
    endif
    if strlen(rkeyword) > 0
        if a:rcmd == "help"
            let s:running_rhelp = 1
            if g:R_nvimpager == "no"
                call g:SendCmdToR("help(" . rkeyword . ")")
            else
                if bufname("%") =~ "Object_Browser"
                    if g:rplugin_curview == "libraries"
                        let pkg = RBGetPkgName()
                    else
                        let pkg = ""
                    endif
                endif
                call AskRDoc(rkeyword, "", 1)
            endif
            return
        endif
        if a:rcmd == "print"
            call PrintRObject(rkeyword)
            return
        endif
        let rfun = a:rcmd
        if a:rcmd == "args"
            if g:R_listmethods == 1
                call g:SendCmdToR('nvim.list.args("' . rkeyword . '")')
            else
                call g:SendCmdToR('args("' . rkeyword . '")')
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
        if a:rcmd == "viewdf"
            if exists("g:R_df_viewer")
                call g:SendCmdToR(printf(g:R_df_viewer, rkeyword))
            else
                echo "Wait..."
                call delete(g:rplugin_tmpdir . "/Rinsert")
                call AddForDeletion(g:rplugin_tmpdir . "/Rinsert")
                call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim_viewdf("' . rkeyword . '")')
            endif
            return
        endif
        if a:rcmd == "dputtab" || a:rcmd == "printtab"
            if bufexists(rkeyword . ".R")
                tabnew
            else
                exe "tabnew " . rkeyword . ".R"
            endif
            exe "Rinsert " . substitute(a:rcmd, "tab", "", "") . "(" . rkeyword . ")"
            set nomodified
            return
        endif
        if g:R_open_example && a:rcmd == "example"
            call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim.example("' . rkeyword . '")')
            return
        endif

        let raction = rfun . "(" . rkeyword . ")"
        call g:SendCmdToR(raction)
    endif
endfunction

" render a document with rmarkdown
function! RMakeRmd(t)
    if !exists("g:rplugin_pdfviewer")
        call RSetPDFViewer()
    endif

    update

    if a:t == "odt"
        if has("win32")
            let soffice_bin = "soffice.exe"
        else
            let soffice_bin = "soffice"
        endif
        if !executable(soffice_bin)
            call RWarningMsg("Is Libre Office installed? Cannot convert into ODT: '" . soffice_bin . "' not found.")
            return
        endif
    endif

    let rmddir = expand("%:p:h")
    if has("win32")
        let rmddir = substitute(rmddir, '\\', '/', 'g')
    endif
    if a:t == "default"
        let rcmd = 'nvim.interlace.rmd("' . expand("%:t") . '", rmddir = "' . rmddir . '"'
    else
        let rcmd = 'nvim.interlace.rmd("' . expand("%:t") . '", outform = "' . a:t .'", rmddir = "' . rmddir . '"'
    endif
    if b:pdf_is_open || (g:R_openhtml  == 0 && a:t == "html_document") ||
                \ (g:R_openpdf == 0 && (a:t == "pdf_document" || a:t == "beamer_presentation" || a:t == "word_document"))
        let rcmd .= ", view = FALSE"
    elseif g:R_openpdf == 1 && (a:t == "pdf_document" || a:t == "beamer_presentation")
        let b:pdf_is_open = 1
    endif
    let rcmd = rcmd . ', envir = ' . g:R_rmd_environment . ')'
    call g:SendCmdToR(rcmd)
endfunction

let s:ikblist = execute("imap")
let s:nkblist = execute("nmap")
let s:vkblist = execute("vmap")
let s:iskblist = split(s:ikblist, "\n")
let s:nskblist = split(s:nkblist, "\n")
let s:vskblist = split(s:vkblist, "\n")
let s:imaplist = []
let s:vmaplist = []
let s:nmaplist = []
for i in s:iskblist
    let si = split(i)
    if len(si) == 3 && si[2] =~ "<Plug>R"
        call add(s:imaplist, [si[1], si[2]])
    endif
endfor
for i in s:nskblist
    let si = split(i)
    if len(si) == 3 && si[2] =~ "<Plug>R"
        call add(s:nmaplist, [si[1], si[2]])
    endif
endfor
for i in s:vskblist
    let si = split(i)
    if len(si) == 3 && si[2] =~ "<Plug>R"
        call add(s:vmaplist, [si[1], si[2]])
    endif
endfor
unlet s:ikblist
unlet s:nkblist
unlet s:vkblist
unlet s:iskblist
unlet s:nskblist
unlet s:vskblist
unlet i
unlet si

function RNMapCmd(plug)
    for [el1, el2] in s:nmaplist
        if el2 == a:plug
            return el1
        endif
    endfor
endfunction

function RIMapCmd(plug)
    for [el1, el2] in s:imaplist
        if el2 == a:plug
            return el1
        endif
    endfor
endfunction

function RVMapCmd(plug)
    for [el1, el2] in s:vmaplist
        if el2 == a:plug
            return el1
        endif
    endfor
endfunction

function RControlMaps()
    " List space, clear console, clear all
    "-------------------------------------
    call RCreateMaps("nvi", '<Plug>RListSpace',    'rl', ':call g:SendCmdToR("ls()")')
    call RCreateMaps("nvi", '<Plug>RClearConsole', 'rr', ':call RClearConsole()')
    call RCreateMaps("nvi", '<Plug>RClearAll',     'rm', ':call RClearAll()')

    " Print, names, structure
    "-------------------------------------
    call RCreateMaps("ni", '<Plug>RObjectPr',     'rp', ':call RAction("print")')
    call RCreateMaps("ni", '<Plug>RObjectNames',  'rn', ':call RAction("nvim.names")')
    call RCreateMaps("ni", '<Plug>RObjectStr',    'rt', ':call RAction("str")')
    call RCreateMaps("ni", '<Plug>RViewDF',       'rv', ':call RAction("viewdf")')
    call RCreateMaps("ni", '<Plug>RDputObj',      'td', ':call RAction("dputtab")')
    call RCreateMaps("ni", '<Plug>RPrintObj',     'tp', ':call RAction("printtab")')

    call RCreateMaps("v", '<Plug>RObjectPr',     'rp', ':call RAction("print", "v")')
    call RCreateMaps("v", '<Plug>RObjectNames',  'rn', ':call RAction("nvim.names", "v")')
    call RCreateMaps("v", '<Plug>RObjectStr',    'rt', ':call RAction("str", "v")')
    call RCreateMaps("v", '<Plug>RViewDF',       'rv', ':call RAction("viewdf", "v")')
    call RCreateMaps("v", '<Plug>RDputObj',      'td', ':call RAction("dputtab", "v")')
    call RCreateMaps("v", '<Plug>RPrintObj',     'tp', ':call RAction("printtab", "v")')

    " Arguments, example, help
    "-------------------------------------
    call RCreateMaps("nvi", '<Plug>RShowArgs',     'ra', ':call RAction("args")')
    call RCreateMaps("nvi", '<Plug>RShowEx',       're', ':call RAction("example")')
    call RCreateMaps("nvi", '<Plug>RHelp',         'rh', ':call RAction("help")')

    " Summary, plot, both
    "-------------------------------------
    call RCreateMaps("ni", '<Plug>RSummary',      'rs', ':call RAction("summary")')
    call RCreateMaps("ni", '<Plug>RPlot',         'rg', ':call RAction("plot")')
    call RCreateMaps("ni", '<Plug>RSPlot',        'rb', ':call RAction("plotsumm")')

    call RCreateMaps("v", '<Plug>RSummary',      'rs', ':call RAction("summary", "v")')
    call RCreateMaps("v", '<Plug>RPlot',         'rg', ':call RAction("plot", "v")')
    call RCreateMaps("v", '<Plug>RSPlot',        'rb', ':call RAction("plotsumm", "v")')

    " Build list of objects for omni completion
    "-------------------------------------
    call RCreateMaps("nvi", '<Plug>RUpdateObjBrowser', 'ro', ':call RObjBrowser()')
    call RCreateMaps("nvi", '<Plug>ROpenLists',        'r=', ':call RBrOpenCloseLs(1)')
    call RCreateMaps("nvi", '<Plug>RCloseLists',       'r-', ':call RBrOpenCloseLs(0)')

    " Render script with rmarkdown
    "-------------------------------------
    call RCreateMaps("nvi", '<Plug>RMakeRmd',       'kr', ':call RMakeRmd("default")')
    call RCreateMaps("nvi", '<Plug>RMakePDFK',      'kp', ':call RMakeRmd("pdf_document")')
    call RCreateMaps("nvi", '<Plug>RMakePDFKb',     'kl', ':call RMakeRmd("beamer_presentation")')
    call RCreateMaps("nvi", '<Plug>RMakeWord',      'kw', ':call RMakeRmd("word_document")')
    call RCreateMaps("nvi", '<Plug>RMakeHTML',      'kh', ':call RMakeRmd("html_document")')
    call RCreateMaps("nvi", '<Plug>RMakeODT',       'ko', ':call RMakeRmd("odt")')
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
    if a:type =~ '0'
        let tg = a:target . '<CR>0'
        let il = 'i'
    else
        let tg = a:target . '<CR>'
        let il = 'a'
    endif
    if a:type =~ "n"
        if hasmapto(a:plug, "n")
            exec 'noremap <buffer><silent> ' . a:plug . ' ' . tg
        elseif g:R_user_maps_only == 0
            exec 'noremap <buffer><silent> <LocalLeader>' . a:combo . ' ' . tg
        endif
    endif
    if a:type =~ "v"
        if hasmapto(a:plug, "v")
            exec 'vnoremap <buffer><silent> ' . a:plug . ' <Esc>' . tg
        elseif g:R_user_maps_only == 0
            exec 'vnoremap <buffer><silent> <LocalLeader>' . a:combo . ' <Esc>' . tg
        endif
    endif
    if g:R_insert_mode_cmds == 1 && a:type =~ "i"
        if hasmapto(a:plug, "i")
            exec 'inoremap <buffer><silent> ' . a:plug . ' <Esc>' . tg . il
        elseif g:R_user_maps_only == 0
            exec 'inoremap <buffer><silent> <LocalLeader>' . a:combo . ' <Esc>' . tg . il
        endif
    endif
endfunction


function SpaceForRGrDevice()
    let savesb = &switchbuf
    set switchbuf=useopen,usetab
    let splr = &splitright
    set splitright
    37vsplit Space_for_Graphics
    setlocal nomodifiable
    setlocal noswapfile
    set buftype=nofile
    set nowrap
    set winfixwidth
    exe "sb " . g:rplugin_curbuf
    let &splitright = splr
    exe "set switchbuf=" . savesb
endfunction

function RCreateStartMaps()
    " Start
    "-------------------------------------
    call RCreateMaps("nvi", '<Plug>RStart',        'rf', ':call StartR("R")')
    call RCreateMaps("nvi", '<Plug>RCustomStart',  'rc', ':call StartR("custom")')

    " Close
    "-------------------------------------
    call RCreateMaps("nvi", '<Plug>RClose',        'rq', ":call RQuit('nosave')")
    call RCreateMaps("nvi", '<Plug>RSaveClose',    'rw', ":call RQuit('save')")

endfunction

function RCreateEditMaps()
    " Edit
    "-------------------------------------
    call RCreateMaps("ni", '<Plug>RToggleComment',   'xx', ':call RComment("normal")')
    call RCreateMaps("v", '<Plug>RToggleComment',   'xx', ':call RComment("selection")')
    call RCreateMaps("ni", '<Plug>RSimpleComment',   'xc', ':call RSimpleCommentLine("normal", "c")')
    call RCreateMaps("v", '<Plug>RSimpleComment',   'xc', ':call RSimpleCommentLine("selection", "c")')
    call RCreateMaps("ni", '<Plug>RSimpleUnComment',   'xu', ':call RSimpleCommentLine("normal", "u")')
    call RCreateMaps("v", '<Plug>RSimpleUnComment',   'xu', ':call RSimpleCommentLine("selection", "u")')
    call RCreateMaps("ni", '<Plug>RRightComment',   ';', ':call MovePosRCodeComment("normal")')
    call RCreateMaps("v", '<Plug>RRightComment',    ';', ':call MovePosRCodeComment("selection")')
    " Replace 'underline' with '<-'
    if g:R_assign == 1 || g:R_assign == 2
        silent exe 'inoremap <buffer><silent> ' . g:R_assign_map . ' <Esc>:call ReplaceUnderS()<CR>a'
    endif
    if g:R_args_in_stline
        autocmd InsertCharPre * call RSetStatusLine()
        autocmd InsertLeave * call RestoreStatusLine(1)
    endif
    if hasmapto("<Plug>RCompleteArgs", "i")
        inoremap <buffer><silent> <Plug>RCompleteArgs <C-R>=RCompleteArgs()<CR>
    else
        inoremap <buffer><silent> <C-X><C-A> <C-R>=RCompleteArgs()<CR>
    endif
endfunction

function RCreateSendMaps()
    " Block
    "-------------------------------------
    call RCreateMaps("ni", '<Plug>RSendMBlock',     'bb', ':call SendMBlockToR("silent", "stay")')
    call RCreateMaps("ni", '<Plug>RESendMBlock',    'be', ':call SendMBlockToR("echo", "stay")')
    call RCreateMaps("ni", '<Plug>RDSendMBlock',    'bd', ':call SendMBlockToR("silent", "down")')
    call RCreateMaps("ni", '<Plug>REDSendMBlock',   'ba', ':call SendMBlockToR("echo", "down")')

    " Function
    "-------------------------------------
    call RCreateMaps("nvi", '<Plug>RSendFunction',  'ff', ':call SendFunctionToR("silent", "stay")')
    call RCreateMaps("nvi", '<Plug>RDSendFunction', 'fe', ':call SendFunctionToR("echo", "stay")')
    call RCreateMaps("nvi", '<Plug>RDSendFunction', 'fd', ':call SendFunctionToR("silent", "down")')
    call RCreateMaps("nvi", '<Plug>RDSendFunction', 'fa', ':call SendFunctionToR("echo", "down")')

    " Selection
    "-------------------------------------
    call RCreateMaps("v", '<Plug>RSendSelection',   'ss', ':call SendSelectionToR("silent", "stay")')
    call RCreateMaps("v", '<Plug>RESendSelection',  'se', ':call SendSelectionToR("echo", "stay")')
    call RCreateMaps("v", '<Plug>RDSendSelection',  'sd', ':call SendSelectionToR("silent", "down")')
    call RCreateMaps("v", '<Plug>REDSendSelection', 'sa', ':call SendSelectionToR("echo", "down")')
    call RCreateMaps('v', '<Plug>RSendSelAndInsertOutput', 'so', ':call SendSelectionToR("echo", "stay", "NewtabInsert")')

    " Paragraph
    "-------------------------------------
    call RCreateMaps("ni", '<Plug>RSendParagraph',   'pp', ':call SendParagraphToR("silent", "stay")')
    call RCreateMaps("ni", '<Plug>RESendParagraph',  'pe', ':call SendParagraphToR("echo", "stay")')
    call RCreateMaps("ni", '<Plug>RDSendParagraph',  'pd', ':call SendParagraphToR("silent", "down")')
    call RCreateMaps("ni", '<Plug>REDSendParagraph', 'pa', ':call SendParagraphToR("echo", "down")')

    if &filetype == "rnoweb" || &filetype == "rmd" || &filetype == "rrst"
        call RCreateMaps("ni", '<Plug>RSendChunkFH', 'ch', ':call SendFHChunkToR()')
    endif

    " *Line*
    "-------------------------------------
    call RCreateMaps("ni", '<Plug>RSendLine', 'l', ':call SendLineToR("stay")')
    call RCreateMaps('ni0', '<Plug>RDSendLine', 'd', ':call SendLineToR("down")')
    call RCreateMaps('ni0', '<Plug>RDSendLineAndInsertOutput', 'o', ':call SendLineToRAndInsertOutput()')
    call RCreateMaps('v', '<Plug>RDSendLineAndInsertOutput', 'o', ':call RWarningMsg("This command does not work over a selection of lines.")')
    call RCreateMaps('i', '<Plug>RSendLAndOpenNewOne', 'q', ':call SendLineToR("newline")')
    call RCreateMaps('n', '<Plug>RNLeftPart', 'r<left>', ':call RSendPartOfLine("left", 0)')
    call RCreateMaps('n', '<Plug>RNRightPart', 'r<right>', ':call RSendPartOfLine("right", 0)')
    call RCreateMaps('i', '<Plug>RILeftPart', 'r<left>', 'l:call RSendPartOfLine("left", 1)')
    call RCreateMaps('i', '<Plug>RIRightPart', 'r<right>', 'l:call RSendPartOfLine("right", 1)')
endfunction

function RBufEnter()
    let g:rplugin_curbuf = bufname("%")
    if has("gui_running")
        if &filetype != g:rplugin_lastft
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
            let g:rplugin_lastft = &filetype
        endif
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
    if IsJobRunning("ClientServer")
        call JobStdin(g:rplugin_jobs["ClientServer"], "\x08Quit\n")
    endif
    for fn in s:del_list
        call delete(fn)
    endfor
    if executable("rmdir")
        call system("rmdir '" . g:rplugin_tmpdir . "'")
    endif
endfunction

" Tell R to create a list of objects file listing all currently available
" objects in its environment. The file is necessary for omni completion.
function BuildROmniList(pattern)
    if string(g:SendCmdToR) == "function('SendCmdToR_fake')"
        return
    endif

    let omnilistcmd = 'nvimcom:::nvim.bol(".GlobalEnv"'

    if g:R_allnames == 1
        let omnilistcmd = omnilistcmd . ', allnames = TRUE'
    endif
    let omnilistcmd = omnilistcmd . ', pattern = "' . a:pattern . '")'

    call delete(g:rplugin_tmpdir . "/eval_reply")
    call delete(g:rplugin_tmpdir . "/nvimbol_finished")
    call AddForDeletion(g:rplugin_tmpdir . "/nvimbol_finished")

    call SendToNvimcom("\x08" . $NVIMR_ID . omnilistcmd)
    if g:rplugin_nvimcom_port == 0
        sleep 500m
        return
    endif
    let g:rplugin_lastev = ReadEvalReply()
    if g:rplugin_lastev =~ "^R error: "
        call RWarningMsg(g:rplugin_lastev)
        sleep 800m
        return
    endif
    sleep 20m
    let ii = 0
    while !filereadable(g:rplugin_tmpdir . "/nvimbol_finished") && ii < 5
        let ii += 1
        sleep
    endwhile
    echon "\r               "
    if ii == 5
        call RWarningMsg("No longer waiting...")
        return
    endif

    let s:globalenv_lines = readfile(g:rplugin_tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
endfunction

function RFillOmniMenu(base, newbase, prefix, pkg, olines, toplev)
    let resp = []
    for line in a:olines
        if line =~ a:newbase
            " Delete information about package eventually added by nvim.args()
            let line = substitute(line, "\x04.*", "", "")
            " Skip elements of lists unless the user is really looking for them.
            " Skip lists if the user is looking for one of its elements.
            let obj = substitute(line, "\x06.*", "", "")
            if (a:base !~ '\$' && obj =~ '\$') || (a:base =~ '\$' && obj !~ '\$')
                continue
            endif
            " Idem with S4 objects
            if (a:base !~ '@' && obj =~ '@') || (a:base =~ '@' && obj !~ '@')
                continue
            endif
            let sln = split(line, "\x06", 1)
            if a:pkg != "" && sln[3] != a:pkg
                continue
            endif
            if len(a:toplev)
                " Do not show an object from a package if it was masked by a
                " toplevel object in .GlobalEnv
                let masked = 0
                let pkgobj = substitute(sln[0], "\\$.*", "", "")
                let pkgobj = substitute(pkgobj, "@.*", "", "")
                for tplv in a:toplev
                    if tplv == pkgobj
                        let masked = 1
                        continue
                    endif
                endfor
                if masked
                    continue
                endif
            endif
            if sln[0] =~ "[ '%]"
                let sln[0] = "`" . sln[0] . "`"
            endif
            if g:R_show_args && len(sln) > 4
                let tmp = split(sln[4], "\x08")
                if tmp[0] =~ '""'
                    let tmp[0] = substitute(tmp[0], '"""', '"\\""', 'g')
                    let tmp[0] = substitute(tmp[0], "\"\"'\"", "\"\\\\\"'\"", 'g')
                endif
                let tmp[0] = substitute(tmp[0], "NO_ARGS", "", "")
                let tmp[0] = substitute(tmp[0], "\x07", " = ", "g")
                if len(tmp) == 2
                    let descr = "Description: " . substitute(tmp[1], '\\N', "\n", "g") . "\n"
                else
                    let descr = ""
                endif
                if tmp[0] == "Not a function"
                    let usage =  ""
                else
                    " Format usage paragraph according to the width of the current window
                    let xx = split(tmp[0], "\x09")
                    if len(xx) > 0
                        let usageL = ["Usage: " . a:prefix . sln[0] . "(" . xx[0]]
                        let ii = 0
                        let jj = 1
                        let ll = len(xx)
                        let wl = winwidth(0) - 1
                        while(jj < ll)
                            if(len(usageL[ii] . ", " . xx[jj]) < wl)
                                let usageL[ii] .= ", " . xx[jj]
                            elseif jj < ll
                                let usageL[ii] .= ","
                                let ii += 1
                                let usageL += ["           " . xx[jj]]
                            endif
                            let jj += 1
                        endwhile
                        let usage = join(usageL, "\n") . ")\t"
                    else
                        let usage = "Usage: " . a:prefix . sln[0] . "()\t"
                    endif
                endif
                call add(resp, {'word': a:prefix . sln[0], 'menu': sln[1] . ' ' . sln[3], 'info': descr . usage})
            elseif len(sln) > 3
                call add(resp, {'word': a:prefix . sln[0], 'menu': sln[1] . ' ' . sln[3]})
            endif
        endif
    endfor
    let s:is_completing = 1
    return resp
endfunction

function CompleteR(findstart, base)
    if (&filetype == "rnoweb" || &filetype == "rmd" || &filetype == "rrst" || &filetype == "rhelp") && b:IsInRCode(0) == 0 && b:rplugin_nonr_omnifunc != ""
        let Ofun = function(b:rplugin_nonr_omnifunc)
        let thebegin = Ofun(a:findstart, a:base)
        return thebegin
    endif
    if a:findstart
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && (line[start - 1] =~ '\w' || line[start - 1] =~ '\.' || line[start - 1] =~ '\$' || line[start - 1] =~ '@' || line[start - 1] =~ ':')
            let start -= 1
        endwhile
        return start
    else
        let resp = []

        if strlen(a:base) == 0
            return resp
        endif

        if len(g:rplugin_omni_lines) == 0
            call add(resp, {'word': a:base, 'menu': " [ List is empty. Was nvimcom library ever loaded? ]"})
        endif

        if a:base =~ ":::"
            return resp
        elseif a:base =~ "::"
            let newbase = substitute(a:base, ".*::", "", "")
            let prefix = substitute(a:base, "::.*", "::", "")
            let pkg = substitute(a:base, "::.*", "", "")
        else
            let newbase = a:base
            let prefix = ""
            let pkg = ""
        endif

        " The char '$' at the end of `a:base` is treated as end of line, and
        " the pattern is never found in `line`.
        let newbase = '^' . substitute(newbase, "\\$$", "", "")
        " A dot matches anything
        let newbase = substitute(newbase, '\.', '\\.', 'g')

        if pkg == ""
            call BuildROmniList(a:base)
            let resp = RFillOmniMenu(a:base, newbase, prefix, pkg, s:globalenv_lines, [])
            if filereadable(g:rplugin_tmpdir . "/nvimbol_finished")
                let toplev = readfile(g:rplugin_tmpdir . "/nvimbol_finished")
            else
                let toplev = []
            endif
            let resp += RFillOmniMenu(a:base, newbase, prefix, pkg, g:rplugin_omni_lines, toplev)
        else
            let omf = split(globpath(g:rplugin_compldir, 'omnils_' . pkg . '_*'), "\n")
            if len(omf) == 1
                let olines = readfile(omf[0])
                if len(olines) == 0 || (len(olines) == 1 && len(olines[0]) < 3)
                    return resp
                endif
                let resp = RFillOmniMenu(a:base, newbase, prefix, pkg, olines, [])
            else
                call add(resp, {'word': a:base, 'menu': ' [ List is empty. Was "' . pkg . '" library ever loaded? ]'})
            endif
        endif

        return resp
    endif
endfun

function RSourceOtherScripts()
    if exists("g:R_source")
        let flist = split(g:R_source, ",")
        for fl in flist
            if fl =~ " "
                call RWarningMsgInp("Invalid file name (empty spaces are not allowed): '" . fl . "'")
            else
                exe "source " . escape(fl, ' \')
            endif
        endfor
    endif
endfunction

function RBuildTags()
    if filereadable("etags")
        call RWarningMsg('The file "etags" exists. Please, delete it and try again.')
        return
    endif
    call g:SendCmdToR('rtags(ofile = "etags"); etags2ctags("etags", "tags"); unlink("etags")')
endfunction

command -nargs=1 -complete=customlist,RLisObjs Rinsert :call RInsert(<q-args>)
command -range=% Rformat <line1>,<line2>:call RFormatCode()
command RBuildTags :call RBuildTags()
command -nargs=? -complete=customlist,RLisObjs Rhelp :call RAskHelp(<q-args>)
command -nargs=? -complete=dir RSourceDir :call RSourceDirectory(<q-args>)
command RStop :call StopR()


"==========================================================================
" Global variables
" Convention: R_        for user options
"             rplugin_  for internal parameters
"==========================================================================

if !exists("g:rplugin_compldir")
    exe "source " . substitute(expand("<sfile>:h:h"), " ", "\\ ", "g") . "/R/setcompldir.vim"
endif


if exists("g:R_tmpdir")
    let g:rplugin_tmpdir = expand(g:R_tmpdir)
else
    if has("win32")
        if isdirectory($TMP)
            let g:rplugin_tmpdir = $TMP . "/NvimR-" . g:rplugin_userlogin
        elseif isdirectory($TEMP)
            let g:rplugin_tmpdir = $TEMP . "/Nvim-R-" . g:rplugin_userlogin
        else
            let g:rplugin_tmpdir = g:rplugin_uservimfiles . "/R/tmp"
        endif
        let g:rplugin_tmpdir = substitute(g:rplugin_tmpdir, "\\", "/", "g")
    else
        if isdirectory($TMPDIR)
            if $TMPDIR =~ "/$"
                let g:rplugin_tmpdir = $TMPDIR . "Nvim-R-" . g:rplugin_userlogin
            else
                let g:rplugin_tmpdir = $TMPDIR . "/Nvim-R-" . g:rplugin_userlogin
            endif
        elseif isdirectory("/tmp")
            let g:rplugin_tmpdir = "/tmp/Nvim-R-" . g:rplugin_userlogin
        else
            let g:rplugin_tmpdir = g:rplugin_uservimfiles . "/R/tmp"
        endif
    endif
endif

let $NVIMR_TMPDIR = g:rplugin_tmpdir
if !isdirectory(g:rplugin_tmpdir)
    call mkdir(g:rplugin_tmpdir, "p", 0700)
endif

" Make the file name of files to be sourced
let s:Rsource = g:rplugin_tmpdir . "/Rsource-" . getpid()

let g:rplugin_is_darwin = system("uname") =~ "Darwin"

" Variables whose default value is fixed
let g:R_allnames          = get(g:, "R_allnames",           0)
let g:R_rmhidden          = get(g:, "R_rmhidden",           0)
let g:R_assign            = get(g:, "R_assign",             1)
let g:R_assign_map        = get(g:, "R_assign_map",       "_")
let g:R_paragraph_begin   = get(g:, "R_paragraph_begin",    1)
let g:R_rnowebchunk       = get(g:, "R_rnowebchunk",        1)
let g:R_strict_rst        = get(g:, "R_strict_rst",         1)
let g:R_synctex           = get(g:, "R_synctex",            1)
let g:R_openhtml          = get(g:, "R_openhtml",           0)
let g:R_nvim_wd           = get(g:, "R_nvim_wd",            0)
let g:R_commented_lines   = get(g:, "R_commented_lines",    0)
let g:R_after_start       = get(g:, "R_after_start",       "")
let g:R_csv_warn          = get(g:, "R_csv_warn",           1)
let g:R_min_editor_width  = get(g:, "R_min_editor_width",  80)
let g:R_rconsole_width    = get(g:, "R_rconsole_width",    80)
let g:R_rconsole_height   = get(g:, "R_rconsole_height",   15)
let g:R_tmux_title        = get(g:, "R_tmux_title",   "NvimR")
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
let g:R_objbr_labelerr    = get(g:, "R_objbr_labelerr",     1)
let g:R_applescript       = get(g:, "R_applescript",        0)
let g:R_tmux_split        = get(g:, "R_tmux_split",         0)
let g:R_esc_term          = get(g:, "R_esc_term",           1)
let g:R_close_term        = get(g:, "R_close_term",         1)
let g:R_wait              = get(g:, "R_wait",              60)
let g:R_wait_reply        = get(g:, "R_wait_reply",         2)
let g:R_show_args         = get(g:, "R_show_args",          1)
let g:R_show_arg_help     = get(g:, "R_show_arg_help",      1)
let g:R_never_unmake_menu = get(g:, "R_never_unmake_menu",  0)
let g:R_insert_mode_cmds  = get(g:, "R_insert_mode_cmds",   0)
let g:R_source            = get(g:, "R_source",            "")
let g:R_in_buffer         = get(g:, "R_in_buffer",          1)
let g:R_open_example      = get(g:, "R_open_example",       1)
let g:R_hi_fun            = get(g:, "R_hi_fun",             1)
let g:R_hi_fun_paren      = get(g:, "R_hi_fun_paren",       0)
let g:R_args_in_stline    = get(g:, "R_args_in_stline",     0)
let g:R_sttline_fmt       = get(g:, "R_sttline_fmt", "%fun(%args)")
if !exists("*termopen") && !exists("*term_start")
    let g:R_in_buffer = 0
endif
if !has("nvim") && !has("patch-8.0.0910")
    let g:R_in_buffer = 0
endif
if g:R_in_buffer
    let g:R_nvimpager = get(g:, "R_nvimpager", "vertical")
else
    let g:R_nvimpager = get(g:, "R_nvimpager", "tab")
endif
let g:R_objbr_place      = get(g:, "R_objbr_place",    "script,right")
let g:R_source_args      = get(g:, "R_source_args", "print.eval=TRUE")
let g:R_user_maps_only   = get(g:, "R_user_maps_only",              0)
let g:R_latexcmd         = get(g:, "R_latexcmd",            "default")
let g:R_texerr           = get(g:, "R_texerr",                      1)
let g:R_rmd_environment  = get(g:, "R_rmd_environment",  ".GlobalEnv")
let g:R_indent_commented = get(g:, "R_indent_commented",            1)

if g:rplugin_is_darwin
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

if g:R_in_buffer
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
let objbrplace = split(g:R_objbr_place, ",")
let obpllen = len(objbrplace) - 1
if obpllen > 1
    call RWarningMsgInp("Too many options for R_objbr_place.")
    let g:rplugin_failed = 1
    finish
endif
for idx in range(0, obpllen)
    if objbrplace[idx] != "console" && objbrplace[idx] != "script" &&
                \ objbrplace[idx] != "left" && objbrplace[idx] != "right" &&
                \ objbrplace[idx] != "top" && objbrplace[idx] != "bottom"
        call RWarningMsgInp('Invalid option for R_objbr_place: "' . objbrplace[idx] . '". Valid options are: console or script and right or left."')
        let g:rplugin_failed = 1
        finish
    endif
endfor
unlet objbrplace
unlet obpllen


" ^K (\013) cleans from cursor to the right and ^U (\025) cleans from cursor
" to the left. However, ^U causes a beep if there is nothing to clean. The
" solution is to use ^A (\001) to move the cursor to the beginning of the line
" before sending ^K. But the control characters may cause problems in some
" circumstances.
let g:R_clear_line = get(g:, "R_clear_line", 0)

" ========================================================================
" Check if default mean of communication with R is OK

if g:rplugin_is_darwin
    if !exists("g:macvim_skim_app_path")
        let g:macvim_skim_app_path = '/Applications/Skim.app'
    endif
else
    let g:R_applescript = 0
endif

if has("gui_running") || g:R_applescript || g:R_in_buffer || $TMUX == ""
    let g:R_tmux_split = 0
endif

if !g:R_in_buffer && !g:R_tmux_split
    let g:R_objbr_place = substitute(g:R_objbr_place, "console", "script", "")
endif


" ========================================================================

" Start with an empty list of objects in the workspace
let s:globalenv_lines = []

" Minimum width for the Object Browser
if g:R_objbr_w < 10
    let g:R_objbr_w = 10
endif

" Minimum height for the Object Browser
if g:R_objbr_h < 4
    let g:R_objbr_h = 4
endif

" Control the menu 'R' and the tool bar buttons
if !exists("g:rplugin_hasmenu")
    let g:rplugin_hasmenu = 0
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

let s:is_completing = 0
function RCompleteSyntax()
    if &previewwindow && s:is_completing
        let s:is_completing = 0
        set encoding=utf-8
        syntax clear
        exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/syntax/rdoc.vim"
        syn match rdocArg2 "^\s*\([A-Z]\|[a-z]\|[0-9]\|\.\|_\)\{-}\ze:"
        syn match rdocTitle2 '^Description: '
        syn region rdocUsage matchgroup=rdocTitle start="^Usage: " matchgroup=NONE end='\t$' contains=@rdocR
        hi def link rdocArg2 Special
        hi def link rdocTitle2 Title
    endif
endfunction
autocmd! BufWinEnter * call RCompleteSyntax()

if v:windowid != 0 && $WINDOWID == ""
    let $WINDOWID = v:windowid
endif

let s:firstbuffer = expand("%:p")
let s:running_objbr = 0
let s:running_rhelp = 0
let s:R_pid = 0
let g:rplugin_myport = 0
let g:rplugin_nvimcom_port = 0
let g:rplugin_lastev = ""

let s:filelines = readfile(g:rplugin_home . "/R/nvimcom/DESCRIPTION")
let s:required_nvimcom = substitute(s:filelines[1], "Version: ", "", "")
let s:required_nvimcom_dot = substitute(s:required_nvimcom, "-", ".", "")
unlet s:filelines

let s:nvimcom_version = "0"
let s:nvimcom_home = ""
let g:rplugin_nvimcom_bin_dir = ""
let g:rplugin_R_version = "0"
if filereadable(g:rplugin_compldir . "/nvimcom_info")
    let s:filelines = readfile(g:rplugin_compldir . "/nvimcom_info")
    if len(s:filelines) == 4
        if isdirectory(s:filelines[1]) && isdirectory(s:filelines[2])
            let s:nvimcom_version = s:filelines[0]
            let s:nvimcom_home = s:filelines[1]
            let g:rplugin_nvimcom_bin_dir = s:filelines[2]
            let g:rplugin_R_version = s:filelines[3]
        endif
    endif
    unlet s:filelines
endif
if exists("g:R_nvimcom_home")
    let s:nvimcom_home = g:R_nvimcom_home
endif

if has("nvim")
    exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/nvimrcom.vim"
else
    exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/vimrcom.vim"
endif

" SyncTeX options
let g:rplugin_has_wmctrl = 0

let s:py_exec = "none"
if executable("python3")
    let s:py_exec = "python3"
elseif executable("python")
    let s:py_exec = "python"
endif

function GetRandomNumber(width)
    if s:py_exec != "none"
        let pycode = ["import os, sys, base64",
                    \ "sys.stdout.write(base64.b64encode(os.urandom(" . a:width . ")).decode())" ]
        call writefile(pycode, g:rplugin_tmpdir . "/getRandomNumber.py")
        let randnum = system(s:py_exec . ' "' . g:rplugin_tmpdir . '/getRandomNumber.py"')
        call delete(g:rplugin_tmpdir . "/getRandomNumber.py")
    elseif !has("win32")
        let randnum = system("echo $RANDOM")
    else
        let randnum = localtime()
    endif
    return substitute(randnum, '\W', '', 'g')
endfunction

" If this is the Object Browser running in a Tmux pane, $NVIMR_ID is
" already defined and shouldn't be changed
if &filetype == "rbrowser"
    if $NVIMR_ID == ""
        call RWarningMsgInp("NVIMR_ID is undefined")
    endif
else
    let $NVIMR_SECRET = GetRandomNumber(16)
    let $NVIMR_ID = GetRandomNumber(16)
endif

let s:docfile = g:rplugin_tmpdir . "/Rdoc"

" List of file to be deleted on VimLeave
let s:del_list = [s:Rsource,
            \ g:rplugin_tmpdir . "/GlobalEnvList_" . $NVIMR_ID]


" Create an empty file to avoid errors if the user do Ctrl-X Ctrl-O before
" starting R:
if &filetype != "rbrowser"
    call writefile([], g:rplugin_tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
endif

" Set the name of R executable
if exists("g:R_app")
    let g:rplugin_R = g:R_app
    if !has("win32") && !exists("g:R_cmd")
        let g:R_cmd = g:R_app
    endif
else
    if has("win32")
        if g:R_in_buffer
            let g:rplugin_R = "Rterm.exe"
        else
            let g:rplugin_R = "Rgui.exe"
        endif
    else
        let g:rplugin_R = "R"
    endif
endif

" Set the name of R executable to be used in `R CMD`
if exists("g:R_cmd")
    let g:rplugin_Rcmd = g:R_cmd
else
    let g:rplugin_Rcmd = "R"
endif

" Add R directory to the $PATH
if exists("g:R_path")
    let g:rplugin_R_path = expand(g:R_path)
    if !isdirectory(g:rplugin_R_path)
        call RWarningMsgInp('"' . g:R_path . '" is not a directory. Fix the value of R_path in your vimrc.')
        let g:rplugin_failed = 1
        finish
    endif
    if $PATH !~ g:rplugin_R_path
        if has("win32")
            let $PATH = g:rplugin_R_path . ';' . $PATH
        else
            let $PATH = g:rplugin_R_path . ':' . $PATH
        endif
    endif
    if !executable(g:rplugin_R)
        call RWarningMsgInp('"' . g:rplugin_R . '" not found. Fix the value of either R_path or R_app in your vimrc.')
        let g:rplugin_failed = 1
        finish
    endif
endif

if exists("g:RStudio_cmd")
    exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/rstudio.vim"
endif

if has("win32")
    exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/windows.vim"
endif

if g:R_applescript
    exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/osx.vim"
endif

if !has("win32") && !g:R_applescript && !g:R_in_buffer
    exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/tmux.vim"
endif

if g:R_in_buffer
    if has("nvim")
        exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/nvimbuffer.vim"
    else
        exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/vimbuffer.vim"
    endif
endif

if has("gui_running")
    exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/gui_running.vim"
endif

if !executable(g:rplugin_R)
    call RWarningMsgInp("R executable not found: '" . g:rplugin_R . "'")
endif

" Check if r-plugin/functions.vim exist
let s:ff = split(globpath(&rtp, "r-plugin/functions.vim"), " ", "\n")
" Check if other Vim-R-plugin files are installed
let s:ft = split(globpath(&rtp, "ftplugin/r*_rplugin.vim"), " ", "\n")
if len(s:ff) > 0 || len(s:ft) > 0
    call RWarningMsgInp("It seems that Vim-R-plugin is installed.\n" .
                \ "Please, completely uninstall it before using Nvim-R.\n" .
                \ "Below is a list of what looks like Vim-R-plugin files:\n" . join(s:ff, "\n") . "\n" . join(s:ft) . "\n")
endif

" Check if there is more than one copy of Nvim-R
" (e.g. from the Vimballl and from a plugin manager)
let s:ff = split(substitute(globpath(&rtp, "R/functions.vim"), "functions.vim", "", "g"), "\n")
let s:ft = split(globpath(&rtp, "ftplugin/r*_nvimr.vim"), "\n")
if len(s:ff) > 1 || len(s:ft) > 5
    call RWarningMsgInp("It seems that Nvim-R is installed in more than one place.\n" .
                \ "Please, remove one of them to avoid conflicts.\n" .
                \ "Below is a list of some of the possibly duplicated directories and files:\n" . join(s:ff, "\n") . "\n" . join(s:ft, "\n") . "\n")
endif
unlet s:ff
unlet s:ft

" 2016-08-25
if exists("g:R_nvimcom_wait")
    call RWarningMsgInp("The option R_nvimcom_wait is deprecated. Use R_wait (in seconds) instead.")
endif

" 2017-02-07
if exists("g:R_vsplit")
    call RWarningMsgInp("The option R_vsplit is deprecated. If necessary, use R_min_editor_width instead.")
endif

" 2017-03-14
if exists("g:R_ca_ck")
    call RWarningMsgInp("The option R_ca_ck was renamed as R_clear_line. Please, update your vimrc.")
endif
