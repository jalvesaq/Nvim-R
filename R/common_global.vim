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


" Do this only once
if exists("s:did_global_stuff")
    finish
endif
let s:did_global_stuff = 1

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

if !has("nvim") && v:version < "800"
    call RWarningMsgInp("Nvim-R requires either Neovim >= 0.1.5 or Vim >= 8.0.\nIf using Vim, it must have been compiled with both +channel and +job features.\n")
    let g:rplugin_failed = 1
    finish
endif

" Set default value of some variables:
function RSetDefaultValue(var, val)
    if !exists(a:var)
        exe "let " . a:var . " = " . a:val
    endif
endfunction

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
    let reply = "No reply"
    let haswaitwarn = 0
    let ii = 0
    while ii < 20
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
    if reply == "No reply" || reply =~ "^Error" || reply == "INVALID" || reply == "ERROR" || reply == "EMPTY" || reply == "NO_ARGS" || reply == "NOT_EXISTS"
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
            let rkeyword0 = RGetKeyword(1)
            if rkeyword0 =~ "::"
                let pkg = '"' . substitute(rkeyword0, "::.*", "", "") . '"'
                let rkeyword0 = substitute(rkeyword0, ".*::", "", "")
                let objclass = ""
            else
                let objclass = RGetFirstObjClass(rkeyword0)
                let pkg = ""
            endif
            let rkeyword = '^' . rkeyword0 . "\x06"
            call cursor(cpos[1], cpos[2])

            " If R is running, use it
            if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
                call delete(g:rplugin_tmpdir . "/eval_reply")
                let msg = 'nvimcom:::nvim.args("' . rkeyword0 . '", "' . argkey . '"'
                if objclass != ""
                    let msg = msg . ', objclass = ' . objclass
                elseif pkg != ""
                    let msg = msg . ', pkg = ' . pkg
                endif
                if rkeyword0 == "library" || rkeyword0 == "require"
                    let isfirst = IsFirstRArg(lnum, cpos)
                else
                    let isfirst = 0
                endif
                if isfirst
                    let msg = msg . ', firstLibArg = TRUE)'
                else
                    let msg = msg . ')'
                endif
                call SendToNvimcom("\x08" . $NVIMR_ID . msg)

                if g:rplugin_nvimcom_port > 0
                    let g:rplugin_lastev = ReadEvalReply()
                    if g:rplugin_lastev !~ "^R error: "
                        let args = []
                        if g:rplugin_lastev[0] == "\x04" && len(split(g:rplugin_lastev, "\x04")) == 1
                            return ''
                        endif
                        let tmp0 = split(g:rplugin_lastev, "\x04")
                        let tmp = split(tmp0[0], "\x09")
                        if(len(tmp) > 0)
                            for id in range(len(tmp))
                                let tmp2 = split(tmp[id], "\x07")
                                if tmp2[0] == '...' || isfirst
                                    let tmp3 = tmp2[0]
                                else
                                    let tmp3 = tmp2[0] . " = "
                                endif
                                if len(tmp2) > 1
                                    call add(args,  {'word': tmp3, 'menu': tmp2[1]})
                                else
                                    call add(args,  {'word': tmp3, 'menu': ' '})
                                endif
                            endfor
                            if len(args) > 0 && len(tmp0) > 1
                                call add(args, {'word': ' ', 'menu': tmp0[1]})
                            endif
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
                    let argsL = split(info, "\x09")
                    let args = []
                    for id in range(len(argsL))
                        let newkey = '^' . argkey
                        let tmp2 = split(argsL[id], "\x07")
                        if (argkey == '' || tmp2[0] =~ newkey) && tmp2[0] !~ "No arguments"
                            if tmp2[0] != '...'
                                let tmp2[0] = tmp2[0] . " = "
                            endif
                            if len(tmp2) == 2
                                let tmp3 = {'word': tmp2[0], 'menu': tmp2[1]}
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
        let rcode = [ 'sink("' . g:rplugin_tmpdir . '/libpaths")',
                    \ 'cat(.libPaths()[1L],',
                    \ '    unlist(strsplit(Sys.getenv("R_LIBS_USER"), .Platform$path.sep))[1L],',
                    \ '    sep = "\n")',
                    \ 'sink()']
        let slog = system('R --no-save', rcode)
        if v:shell_error
            call RWarningMsg(slog)
            return 0
        endif
        let libpaths = readfile(g:rplugin_tmpdir . "/libpaths")
        if !(isdirectory(expand(libpaths[0])) && filewritable(expand(libpaths[0])) == 2)
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
        let slog = system(g:rplugin_Rcmd . ' CMD build "' . g:rplugin_home . '/R/nvimcom"')
        if v:shell_error
            call ShowRSysLog(slog, "Error_building_nvimcom", "Failed to build nvimcom")
            return 0
        else
            let slog = system(g:rplugin_Rcmd . " CMD INSTALL nvimcom_" . s:required_nvimcom . ".tar.gz")
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

    if g:R_in_buffer
        call StartR_Neovim()
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
    sleep 300m
    if filereadable(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
        let vr = readfile(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
        let s:nvimcom_version = vr[0]
        let s:nvimcom_home = vr[1]
        let g:rplugin_nvimcom_port = vr[2]
        let s:R_pid = vr[3]
        let $RCONSOLE = vr[4]
        let search_list = vr[5]
        call delete(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
        if s:nvimcom_version != s:required_nvimcom_dot
            call RWarningMsg('This version of Nvim-R requires nvimcom ' .
                        \ s:required_nvimcom . '.')
            sleep 1
        endif

        if search_list =~ "package:colorout" && !exists("g:R_hl_term")
            let g:R_hl_term = 0
        endif
        if search_list =~ "package:setwidth" && !exists("g:R_setwidth")
            let g:R_setwidth = 0
        endif

        if isdirectory(s:nvimcom_home . "/bin/x64")
            let g:rplugin_nvimcom_bin_dir = s:nvimcom_home . "/bin/x64"
        elseif isdirectory(s:nvimcom_home . "/bin/i386")
            let g:rplugin_nvimcom_bin_dir = s:nvimcom_home . "/bin/i386"
        else
            let g:rplugin_nvimcom_bin_dir = s:nvimcom_home . "/bin"
        endif

        call writefile([s:nvimcom_version, s:nvimcom_home, g:rplugin_nvimcom_bin_dir], g:rplugin_compldir . "/nvimcom_info")

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
                if v:windowid != 0 && $WINDOWID == ""
                    let $WINDOWID = v:windowid
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

        if g:R_in_buffer
            let g:SendCmdToR = function('SendCmdToR_Neovim')
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

        let l:sr = &splitright
        if g:R_objbr_place =~ "left"
            set nosplitright
        else
            set splitright
        endif
        if g:R_objbr_place =~ "console"
            exe 'sb ' . g:rplugin_R_bufname
        endif
        sil exe "vsplit " . b:objbrtitle
        let &splitright = l:sr
        sil exe "vertical resize " . g:R_objbr_w
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
function RGetKeyword(colon)
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
    if a:colon
        setlocal iskeyword=@,48-57,_,.,:,$,@-@
    else
        setlocal iskeyword=@,48-57,_,.,$,@-@
    endif
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
    call writefile(lines, s:Rsource)

    if a:0 == 3 && a:3 == "NewtabInsert"
        call AddForDeletion(g:rplugin_tmpdir . '/Rinsert')
        call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim_capture_source_output("' . s:Rsource . '", "' . g:rplugin_tmpdir . '/Rinsert")')
        return 1
    endif

    let sargs = GetSourceArgs(a:2)
    let rcmd = 'base::source("' . s:Rsource . '"' . sargs . ')'
    let ok = g:SendCmdToR(rcmd)
    return ok
endfunction

" Send file to R
function SendFileToR(e)
    let flines = getline(1, "$")
    let fpath = expand("%:p") . ".tmp.R"

    if filereadable(fpath)
        call RWarningMsg('Error: cannot create "' . fpath . '" because it already exists. Please, delete it.")
        return
    endif

    if has("win32")
        let fpath = substitute(fpath, "\\", "/", "g")
    endif
    call writefile(flines, fpath)
    let sargs = GetSourceArgs(a:e)
    call g:SendCmdToR('nvimcom:::source.and.clean("' . fpath .  '"' . sargs . ')')
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
    while i > 0 && line !~ "<-"
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

    let i = line(".")
    let c = col(".")
    let max = line("$")
    let j = i
    let gotempty = 0
    while j < max
        let j += 1
        let line = getline(j)
        if &filetype == "rnoweb" && line =~ "^@$"
            let j -= 1
            break
        elseif &filetype == "rmd" && line =~ "^[ \t]*```$"
            let j -= 1
            break
        endif
        if line =~ '^\s*$'
            break
        endif
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
        call cursor(i, c)
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
    if g:R_in_buffer && has("win32")
        call RWarningMsg("RQuit not implemented yet for R_in_buffer on Windows.")
        return
    endif

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

    " Must be in term buffer to get TermClose event triggered
    if g:R_in_buffer && exists("g:rplugin_R_bufname")
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
                if line[idx] == '('
                    let nparen += 1
                else
                    if line[idx] == ')'
                        let nparen -= 1
                    endif
                endif
                let idx += 1
                if idx == len
                    let lnum += 1
                    let line = line . substitute(getline(lnum), '#.*', '', "")
                    let len = strlen(line)
                endif
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
                if line[idx] == '['
                    let nparen += 1
                else
                    if line[idx] == ']'
                        let nparen -= 1
                    endif
                endif
                let idx += 1
                if idx == len
                    let lnum += 1
                    let line = line . substitute(getline(lnum), '#.*', '', "")
                    let len = strlen(line)
                endif
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
            let l:sr = &splitright
            set splitright
            exe s:hwidth . 'vsplit ' . s:rdoctitle
            let &splitright = l:sr
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

function ROpenPDF(path)
    if a:path == "Get Master"
        let tmpvar = SyncTeX_GetMaster()
        let pdfpath = tmpvar[1] . '/' . tmpvar[0] . '.pdf'
    else
        let pdfpath = a:path
    endif
    let basenm = substitute(substitute(pdfpath, '.*/', '', ''), '\.pdf$', '', '')

    let olddir = getcwd()
    if olddir != expand("%:p:h")
        try
            " The :cd command will fail if the cursor is in the term buffer
            silent exe "cd " . substitute(expand("%:p:h"), ' ', '\\ ', 'g')
        catch /.*/
        endtry
    endif

    if !filereadable(basenm . ".pdf")
        call RWarningMsg('File not found: "' . basenm . '.pdf".')
        exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
        return
    endif
    if g:rplugin_pdfviewer == "zathura"
        if system("wmctrl -xl") =~ 'Zathura.*' . basenm . '.pdf' && g:rplugin_zathura_pid[basenm] != 0
            call system("wmctrl -a '" . basenm . ".pdf'")
        else
            let g:rplugin_zathura_pid[basenm] = 0
            call RStart_Zathura(basenm)
        endif
        exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
        return
    elseif g:rplugin_pdfviewer == "okular"
        let pcmd = "NVIMR_PORT=" . g:rplugin_myport . " okular --unique '" .  pdfpath . "' 2>/dev/null >/dev/null &"
        call system(pcmd)
    elseif g:rplugin_pdfviewer == "evince"
        let pcmd = "evince '" . pdfpath . "' 2>/dev/null >/dev/null &"
        call system(pcmd)
    elseif g:rplugin_pdfviewer == "sumatra"
        if basenm =~ ' '
            call RWarningMsg('You must remove the empty spaces from the rnoweb file name ("' . basenm .'") to get SyncTeX support with SumatraPDF.')
        endif
        if SumatraInPath()
            let $NVIMR_PORT = g:rplugin_myport
            call writefile(['start SumatraPDF.exe -reuse-instance -inverse-search "nclientserver.exe %%f %%l" ' . basenm . '.pdf'], g:rplugin_tmpdir . "/run_cmd.bat")
            call system(g:rplugin_tmpdir . "/run_cmd.bat")
            exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
        endif
    elseif g:rplugin_pdfviewer == "skim"
        call system("NVIMR_PORT=" . g:rplugin_myport . " " . g:macvim_skim_app_path . '/Contents/MacOS/Skim "' . basenm . '.pdf" 2> /dev/null >/dev/null &')
    endif
    if g:rplugin_has_wmctrl
        call system("wmctrl -a '" . basenm . ".pdf'")
    endif
    exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
endfunction

function StartZathuraNeovim(basenm)
    let g:rplugin_jobs["Zathura"] = jobstart(["zathura",
                \ "--synctex-editor-command",
                \ "nclientserver %{input} %{line}", a:basenm . ".pdf"],
                \ {"detach": 1, "on_stderr": function('ROnJobStderr')})
    if g:rplugin_jobs["Zathura"] < 1
        call RWarningMsg("Failed to run Zathura...")
    else
        let g:rplugin_zathura_pid[a:basenm] = jobpid(g:rplugin_jobs["Zathura"])
    endif
endfunction

function StartZathuraVim(basenm)
    let pycode = ["# -*- coding: " . &encoding . " -*-",
                \ "import subprocess",
                \ "import os",
                \ "import sys",
                \ "FNULL = open(os.devnull, 'w')",
                \ "a3 = '" . a:basenm . ".pdf'",
                \ "zpid = subprocess.Popen(['zathura', '--synctex-editor-command', 'nclientserver %{input} %{line}', a3], stdout = FNULL, stderr = FNULL).pid",
                \ "sys.stdout.write(str(zpid))" ]
    call writefile(pycode, g:rplugin_tmpdir . "/start_zathura.py")
    let pid = system("python '" . g:rplugin_tmpdir . "/start_zathura.py" . "'")
    if pid == 0
        call RWarningMsg("Failed to run Zathura: " . substitute(pid, "\n", " ", "g"))
    else
        let g:rplugin_zathura_pid[a:basenm] = pid
    endif
    call delete(g:rplugin_tmpdir . "/start_zathura.py")
endfunction

function RStart_Zathura(basenm)
    " Use wmctrl to check if the pdf is already open and get Zathura's PID to
    " close the document and kill Zathura.
    if g:rplugin_has_wmctrl && s:has_dbus_send && filereadable("/proc/sys/kernel/pid_max")
        let info = filter(split(system("wmctrl -xpl"), "\n"), 'v:val =~ "Zathura.*' . a:basenm . '"')
        if len(info) > 0
            let pid = split(info[0])[2] + 0     " + 0 to convert into number
            let max_pid = readfile("/proc/sys/kernel/pid_max")[0] + 0
            if pid > 0 && pid <= max_pid
                " Instead of killing, it would be better to reset the backward
                " command, but Zathura does not have a Dbus message for this,
                " and we would have to change nclientserver to receive NVIMR_PORT
                " and NVIMR_SECRET as part of argv[].
                call system('dbus-send --print-reply --session --dest=org.pwmt.zathura.PID-' . pid . ' /org/pwmt/zathura org.pwmt.zathura.CloseDocument')
                sleep 5m
                call system('kill ' . pid)
                sleep 5m
            endif
        endif
    endif

    let $NVIMR_PORT = g:rplugin_myport
    if exists("*jobpid")
        call StartZathuraNeovim(a:basenm)
    else
        call StartZathuraVim(a:basenm)
    endif
endfunction

function RSetPDFViewer()
    let g:rplugin_pdfviewer = tolower(g:R_pdfviewer)

    if !has("win32") && !g:rplugin_is_darwin
        if g:rplugin_pdfviewer == "zathura"
            if executable("zathura")
                let vv = split(system("zathura --version 2>/dev/null"))[1]
                if vv < '0.3.1'
                    call RWarningMsgInp("Zathura version must be >= 0.3.1")
                endif
            else
                call RWarningMsgInp('Please, either install "zathura" or set the value of R_pdfviewer.')
            endif
            if executable("dbus-send")
                let s:has_dbus_send = 1
            else
                let s:has_dbus_send = 0
            endif
        endif

        if g:rplugin_pdfviewer != "zathura" && g:rplugin_pdfviewer != "okular" && g:rplugin_pdfviewer != "evince"
            call RWarningMsgInp('Invalid value for R_pdfviewer: "' . g:R_pdfviewer . '"')
        endif

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
    let s:displaying_args = 1
    if &filetype == "r" || b:IsInRCode(0)
        let rkeyword = RGetKeyword(0)
        let s:sttl_str = s:status_line
        let fargs = "Not a function"
        for omniL in g:rplugin_omni_lines
            if omniL =~ '^' . rkeyword . "\x06"
                let tmp = split(omniL, "\x06")
                if len(tmp) < 5
                    break
                else
                    let fargs = rkeyword . '(' . tmp[4] . ')'
                endif
            endif
        endfor
        if fargs !~ "Not a function"
            let fargs = substitute(fargs, "NO_ARGS", '', 'g')
            let fargs = substitute(fargs, "\x07", '=', 'g')
            let s:sttl_str = substitute(fargs, "\x09", ', ', 'g')
            silent set statusline=%!RArgsStatusLine()
        endif
    endif
    exe "normal! a("
    let s:displaying_args = 0
endfunction

function RArgsStatusLine()
    return s:sttl_str
endfunction

function RestoreStatusLine(p)
    if s:displaying_args
        return
    endif
    exe 'set statusline=' . substitute(s:status_line, ' ', '\\ ', 'g')
    if a:p
        normal! a)
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
function RAction(rcmd)
    if &filetype == "rbrowser"
        let rkeyword = RBrowserGetName(1, 0)
    else
        if a:rcmd == "help" || (a:rcmd == "args" && g:R_listmethods) || a:rcmd == "viewdf"
            let rkeyword = RGetKeyword(0)
        else
            let rkeyword = RGetKeyword(1)
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
    call RCreateMaps("nvi", '<Plug>RObjectPr',     'rp', ':call RAction("print")')
    call RCreateMaps("nvi", '<Plug>RObjectNames',  'rn', ':call RAction("nvim.names")')
    call RCreateMaps("nvi", '<Plug>RObjectStr',    'rt', ':call RAction("str")')
    call RCreateMaps("nvi", '<Plug>RViewDF',       'rv', ':call RAction("viewdf")')

    " Arguments, example, help
    "-------------------------------------
    call RCreateMaps("nvi", '<Plug>RShowArgs',     'ra', ':call RAction("args")')
    call RCreateMaps("nvi", '<Plug>RShowEx',       're', ':call RAction("example")')
    call RCreateMaps("nvi", '<Plug>RHelp',         'rh', ':call RAction("help")')

    " Summary, plot, both
    "-------------------------------------
    call RCreateMaps("nvi", '<Plug>RSummary',      'rs', ':call RAction("summary")')
    call RCreateMaps("nvi", '<Plug>RPlot',         'rg', ':call RAction("plot")')
    call RCreateMaps("nvi", '<Plug>RSPlot',        'rb', ':call RAction("plotsumm")')

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
    let l:sr = &splitright
    set splitright
    37vsplit Space_for_Graphics
    setlocal nomodifiable
    setlocal noswapfile
    set buftype=nofile
    set nowrap
    set winfixwidth
    exe "sb " . g:rplugin_curbuf
    let &splitright = l:sr
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
        inoremap <buffer><silent> ( <Esc>:call DisplayArgs()<CR>a
        inoremap <buffer><silent> ) <Esc>:call RestoreStatusLine(1)<CR>a
        autocmd InsertLeave <buffer> call RestoreStatusLine(0)
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

    let omnilistcmd = 'nvimcom:::nvim.bol("' . g:rplugin_tmpdir . "/GlobalEnvList_" . $NVIMR_ID . '"'

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
            " Skip elements of lists unless the user is really looking for them.
            " Skip lists if the user is looking for one of its elements.
            if (a:base !~ '\$' && line =~ '\$') || (a:base =~ '\$' && line !~ '\$')
                continue
            endif
            " Idem with S4 objects
            if (a:base !~ '@' && line =~ '@') || (a:base =~ '@' && line !~ '@')
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
            if g:R_show_args
                let info = sln[4]
                let info = substitute(info, "\t", ", ", "g")
                let info = substitute(info, "\x07", " = ", "g")
                call add(resp, {'word': a:prefix . sln[0], 'menu': sln[1] . ' ' . sln[3], 'info': info})
            else
                call add(resp, {'word': a:prefix . sln[0], 'menu': sln[1] . ' ' . sln[3]})
            endif
        endif
    endfor
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

        " The char '$' at the end of 'a:base' is treated as end of line, and
        " the pattern is never found in 'line'.
        let newbase = '^' . substitute(newbase, "\\$$", "", "")

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
    if filereadable("TAGS")
        call RWarningMsg('The file "TAGS" exists. Please, delete it and try again.')
        return
    endif
    call g:SendCmdToR('rtags(ofile = "TAGS"); etags2ctags("TAGS", "tags"); unlink("TAGS")')
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
    runtime R/setcompldir.vim
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
call RSetDefaultValue("g:R_allnames",          0)
call RSetDefaultValue("g:R_rmhidden",          0)
call RSetDefaultValue("g:R_assign",            1)
call RSetDefaultValue("g:R_assign_map",    "'_'")
call RSetDefaultValue("g:R_args_in_stline",    0)
call RSetDefaultValue("g:R_rnowebchunk",       1)
call RSetDefaultValue("g:R_strict_rst",        1)
call RSetDefaultValue("g:R_synctex",           1)
call RSetDefaultValue("g:R_openhtml",          0)
call RSetDefaultValue("g:R_nvim_wd",           0)
call RSetDefaultValue("g:R_commented_lines",   0)
call RSetDefaultValue("g:R_after_start",    "''")
call RSetDefaultValue("g:R_vsplit",            0)
call RSetDefaultValue("g:R_csv_warn",          1)
call RSetDefaultValue("g:R_rconsole_width",   -1)
call RSetDefaultValue("g:R_rconsole_height",  15)
call RSetDefaultValue("g:R_tmux_title","'NvimR'")
call RSetDefaultValue("g:R_listmethods",       0)
call RSetDefaultValue("g:R_specialplot",       0)
call RSetDefaultValue("g:R_notmuxconf",        0)
call RSetDefaultValue("g:R_routnotab",         0)
call RSetDefaultValue("g:R_editor_w",         66)
call RSetDefaultValue("g:R_help_w",           46)
call RSetDefaultValue("g:R_objbr_w",          40)
call RSetDefaultValue("g:R_objbr_opendf",      1)
call RSetDefaultValue("g:R_objbr_openlist",    0)
call RSetDefaultValue("g:R_objbr_allnames",    0)
call RSetDefaultValue("g:R_objbr_labelerr",    1)
call RSetDefaultValue("g:R_applescript",       0)
call RSetDefaultValue("g:R_tmux_split",        0)
call RSetDefaultValue("g:R_esc_term",          1)
call RSetDefaultValue("g:R_close_term",        1)
call RSetDefaultValue("g:R_wait",             60)
call RSetDefaultValue("g:R_show_args",         0)
call RSetDefaultValue("g:R_never_unmake_menu", 0)
call RSetDefaultValue("g:R_insert_mode_cmds",  0)
call RSetDefaultValue("g:R_source",         "''")
call RSetDefaultValue("g:R_in_buffer",         1)
call RSetDefaultValue("g:R_open_example",      1)
if !exists("*termopen")
    let g:R_in_buffer = 0
endif
if g:R_in_buffer
    call RSetDefaultValue("g:R_nvimpager", "'vertical'")
else
    call RSetDefaultValue("g:R_nvimpager",      "'tab'")
endif
call RSetDefaultValue("g:R_objbr_place",     "'script,right'")
call RSetDefaultValue("g:R_source_args",  "'print.eval=TRUE'")
call RSetDefaultValue("g:R_user_maps_only", 0)
call RSetDefaultValue("g:R_latexcmd", "'default'")
call RSetDefaultValue("g:R_texerr",             1)
call RSetDefaultValue("g:R_rmd_environment", "'.GlobalEnv'")
call RSetDefaultValue("g:R_indent_commented",  1)

call RSetDefaultValue("g:R_hi_fun", 1)
if !g:R_hi_fun
    " Declare empty function to be called by nvimcom
    function FillRLibList()
    endfunction
endif

if g:rplugin_is_darwin
    call RSetDefaultValue("g:R_openpdf", 1)
    let g:R_pdfviewer = "skim"
else
    call RSetDefaultValue("g:R_openpdf", 2)
    if has("win32")
        let g:R_pdfviewer = "sumatra"
    else
        call RSetDefaultValue("g:R_pdfviewer", "'zathura'")
    endif
endif

if !exists("g:r_indent_ess_comments")
    let g:r_indent_ess_comments = 0
endif
if g:r_indent_ess_comments
    if g:R_indent_commented
        call RSetDefaultValue("g:R_rcomment_string", "'## '")
    else
        call RSetDefaultValue("g:R_rcomment_string", "'### '")
    endif
else
    call RSetDefaultValue("g:R_rcomment_string", "'# '")
endif

if g:R_in_buffer
    let g:R_save_win_pos = 0
    let g:R_arrange_windows  = 0
endif
if has("win32")
    call RSetDefaultValue("g:R_save_win_pos",    1)
    call RSetDefaultValue("g:R_arrange_windows", 1)
else
    call RSetDefaultValue("g:R_save_win_pos",    0)
    call RSetDefaultValue("g:R_arrange_windows", 0)
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
    if objbrplace[idx] != "console" && objbrplace[idx] != "script" && objbrplace[idx] != "left" && objbrplace[idx] != "right"
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
call RSetDefaultValue("g:R_ca_ck", 0)

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

let s:firstbuffer = expand("%:p")
let s:status_line = &statusline
let s:displaying_args = 0
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
if filereadable(g:rplugin_compldir . "/nvimcom_info")
    let s:filelines = readfile(g:rplugin_compldir . "/nvimcom_info")
    if len(s:filelines) == 3
        let s:nvimcom_version = s:filelines[0]
        let s:nvimcom_home = s:filelines[1]
        let g:rplugin_nvimcom_bin_dir = s:filelines[2]
    endif
    unlet s:filelines
endif

if has("nvim")
    runtime R/nvimrcom.vim
else
    runtime R/vimrcom.vim
endif

" SyncTeX options
let g:rplugin_has_wmctrl = 0
let g:rplugin_zathura_pid = {}

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

if has("win32")
    runtime R/windows.vim
endif

if g:R_applescript
    runtime R/osx.vim
endif

if !has("win32") && !g:R_applescript && !g:R_in_buffer
    runtime R/tmux.vim
endif

if g:R_in_buffer
    runtime R/nvimbuffer.vim
endif

if has("gui_running")
    runtime R/gui_running.vim
endif

if !executable(g:rplugin_R)
    call RWarningMsgInp("R executable not found: '" . g:rplugin_R . "'")
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

if exists("g:R_nvimcom_wait")
    call RWarningMsg("The option R_nvimcom_wait is deprecated. Use R_wait (in seconds) instead.")
endif
