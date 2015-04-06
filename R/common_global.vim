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
if exists("g:rplugin_did_global_stuff")
    finish
endif
let g:rplugin_did_global_stuff = 1

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

function! ReadEvalReply()
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
    return reply
endfunction

function! CompleteChunkOptions()
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
            let rkeyword0 = RGetKeyWord()
            let classfor = RGetClassFor(rkeyword0)
            let classfor = substitute(classfor, '\\', "", "g")
            let classfor = substitute(classfor, '\(.\)"\(.\)', '\1\\"\2', "g")
            let rkeyword = '^' . rkeyword0 . "\x06"
            call cursor(cpos[1], cpos[2])

            " If R is running, use it
            if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
                call delete(g:rplugin_tmpdir . "/eval_reply")
                let msg = 'nvimcom:::nvim.args("'
                if classfor == ""
                    let msg = msg . rkeyword0 . '", "' . argkey . '"'
                else
                    let msg = msg . rkeyword0 . '", "' . argkey . '", classfor = ' . classfor
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
                    if g:rplugin_lastev != "NOT_EXISTS" && g:rplugin_lastev != "NO_ARGS" && g:rplugin_lastev != "R is busy." && g:rplugin_lastev != "NOANSWER" && g:rplugin_lastev != "INVALID" && g:rplugin_lastev != "" && g:rplugin_lastev != "No reply"
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
            let flines = g:rplugin_globalenvlines + g:rplugin_omni_lines
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

    if line =~ '^\s*' . a:cmt
        let line = substitute(line, '^\s*' . a:cmt . '*', '', '')
        call setline(a:lnum, line)
        normal! ==
    else
        if g:R_indent_commented
            while line =~ '^\s*\t'
                let line = substitute(line, '^\(\s*\)\t', '\1' . s:curtabstop, "")
            endwhile
            let line = strpart(line, a:ind)
        endif
        let line = a:cmt . ' ' . line
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
            let cmt = '##'
        else
            let cmt = '###'
        endif
    else
        let cmt = '#'
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

" Skip empty lines and lines whose first non blank char is '#'
function GoDown()
    if &filetype == "rnoweb"
        let curline = getline(".")
        let fc = curline[0]
        if fc == '@'
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
    let curline = substitute(getline("."), '^\s*', "", "")
    let fc = curline[0]
    let lastLine = line("$")
    while i < lastLine && (fc == '#' || strlen(curline) == 0)
        let i = i + 1
        call cursor(i, 1)
        let curline = substitute(getline("."), '^\s*', "", "")
        let fc = curline[0]
    endwhile
endfunction

" Adapted from screen plugin:
function TmuxActivePane()
  let line = system("tmux list-panes | grep \'(active)$'")
  let paneid = matchstr(line, '\v\%\d+ \(active\)')
  if !empty(paneid)
    return matchstr(paneid, '\v^\%\d+')
  else
    return matchstr(line, '\v^\d+')
  endif
endfunction

function DelayedFillLibList()
    autocmd! RStarting
    augroup! RStarting
    let g:rplugin_starting_R = 0
    call FillRLibList()
endfunction

function StartR_TmuxSplit(rcmd)
    let g:rplugin_starting_R = 1
    let g:rplugin_editor_pane = $TMUX_PANE
    let tmuxconf = ['set-environment NVIMR_TMPDIR "' . g:rplugin_tmpdir . '"',
                \ 'set-environment NVIMR_COMPLDIR "' . substitute(g:rplugin_compldir, ' ', '\\ ', "g") . '"',
                \ 'set-environment NVIMR_ID ' . $NVIMR_ID ,
                \ 'set-environment NVIMR_SECRET ' . $NVIMR_SECRET ]
    if &t_Co == 256
        call extend(tmuxconf, ['set default-terminal "' . $TERM . '"'])
    endif
    call writefile(tmuxconf, g:rplugin_tmpdir . "/tmux" . $NVIMR_ID . ".conf")
    call system("tmux source-file '" . g:rplugin_tmpdir . "/tmux" . $NVIMR_ID . ".conf" . "'")
    call delete(g:rplugin_tmpdir . "/tmux" . $NVIMR_ID . ".conf")
    let tcmd = "tmux split-window "
    if g:R_vsplit
        if g:R_rconsole_width == -1
            let tcmd .= "-h"
        else
            let tcmd .= "-h -l " . g:R_rconsole_width
        endif
    else
        let tcmd .= "-l " . g:R_rconsole_height
    endif
    if !g:R_restart
        " Let Tmux automatically kill the panel when R quits.
        let tcmd .= " '" . a:rcmd . "'"
    endif
    let rlog = system(tcmd)
    if v:shell_error
        call RWarningMsg(rlog)
        return
    endif
    let g:rplugin_rconsole_pane = TmuxActivePane()
    let rlog = system("tmux select-pane -t " . g:rplugin_editor_pane)
    if v:shell_error
        call RWarningMsg(rlog)
        return
    endif
    let g:SendCmdToR = function('SendCmdToR_TmuxSplit')
    if g:R_restart
        sleep 200m
        let ca_ck = g:R_ca_ck
        let g:R_ca_ck = 0
        call g:SendCmdToR(a:rcmd)
        let g:R_ca_ck = ca_ck
    endif
    let g:rplugin_last_rcmd = a:rcmd
    if g:R_tmux_title != "automatic" && g:R_tmux_title != ""
        call system("tmux rename-window " . g:R_tmux_title)
    endif
    if WaitNvimcomStart()
        if g:R_after_start != ''
            call system(g:R_after_start)
        endif
    endif
endfunction


function StartR_ExternalTerm(rcmd)
    if $DISPLAY == "" && !g:rplugin_is_darwin
        call RWarningMsg("Start 'tmux' before Nvim. The X Window system is required to run R in an external terminal.")
        return
    endif

    if g:R_notmuxconf
        let tmuxcnf = ' '
    else
        " Create a custom tmux.conf
        let cnflines = ['set-option -g prefix C-a',
                    \ 'unbind-key C-b',
                    \ 'bind-key C-a send-prefix',
                    \ 'set-window-option -g mode-keys vi',
                    \ 'set -g status off',
                    \ 'set -g default-terminal "screen-256color"',
                    \ "set -g terminal-overrides 'xterm*:smcup@:rmcup@'" ]

        if g:R_term == "rxvt" || g:R_term == "urxvt"
            let cnflines = cnflines + [
                    \ "set terminal-overrides 'rxvt*:smcup@:rmcup@'" ]
        endif

        if g:R_tmux_ob || !has("gui_running")
            call extend(cnflines, ['set -g mode-mouse on', 'set -g mouse-select-pane on', 'set -g mouse-resize-pane on'])
        endif
        call writefile(cnflines, g:rplugin_tmpdir . "/tmux.conf")
        let tmuxcnf = '-f "' . g:rplugin_tmpdir . "/tmux.conf" . '"'
    endif

    let rcmd = 'NVIMR_TMPDIR=' . substitute(g:rplugin_tmpdir, ' ', '\\ ', 'g') . ' NVIMR_COMPLDIR=' . substitute(g:rplugin_compldir, ' ', '\\ ', 'g') . ' NVIMR_ID=' . $NVIMR_ID . ' NVIMR_SECRET=' . $NVIMR_SECRET . ' ' . a:rcmd

    call system("tmux has-session -t " . g:rplugin_tmuxsname)
    if v:shell_error
        if g:rplugin_is_darwin
            let rcmd = 'TERM=screen-256color ' . rcmd
            let opencmd = printf("tmux -2 %s new-session -s %s '%s'", tmuxcnf, g:rplugin_tmuxsname, rcmd)
            call writefile(["#!/bin/sh", opencmd], $NVIMR_TMPDIR . "/openR")
            call system("chmod +x '" . $NVIMR_TMPDIR . "/openR'")
            let opencmd = "open '" . $NVIMR_TMPDIR . "/openR'"
        else
            if g:rplugin_termcmd =~ "gnome-terminal" || g:rplugin_termcmd =~ "xfce4-terminal" || g:rplugin_termcmd =~ "terminal" || g:rplugin_termcmd =~ "iterm"
                let opencmd = printf("%s 'tmux -2 %s new-session -s %s \"%s\"' &", g:rplugin_termcmd, tmuxcnf, g:rplugin_tmuxsname, rcmd)
            else
                let opencmd = printf("%s tmux -2 %s new-session -s %s \"%s\" &", g:rplugin_termcmd, tmuxcnf, g:rplugin_tmuxsname, rcmd)
            endif
        endif
    else
        if g:rplugin_is_darwin
            call RWarningMsg("Tmux session with R is already running")
            return
        endif
        if g:rplugin_termcmd =~ "gnome-terminal" || g:rplugin_termcmd =~ "xfce4-terminal" || g:rplugin_termcmd =~ "terminal" || g:rplugin_termcmd =~ "iterm"
            let opencmd = printf("%s 'tmux -2 %s attach-session -d -t %s' &", g:rplugin_termcmd, tmuxcnf, g:rplugin_tmuxsname)
        else
            let opencmd = printf("%s tmux -2 %s attach-session -d -t %s &", g:rplugin_termcmd, tmuxcnf, g:rplugin_tmuxsname)
        endif
    endif

    let rlog = system(opencmd)
    if v:shell_error
        call RWarningMsg(rlog)
        return
    endif
    let g:SendCmdToR = function('SendCmdToR_Term')
    if WaitNvimcomStart()
        if g:R_after_start != ''
            call system(g:R_after_start)
        endif
    endif
endfunction

function IsSendCmdToRFake()
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        if exists("g:maplocalleader")
            call RWarningMsg("As far as I know, R is already running. Did you quit it from within Nvim (" . g:maplocalleader . "rq if not remapped)?")
        else
            call RWarningMsg("As far as I know, R is already running. Did you quit it from within Nvim (\\rq if not remapped)?")
        endif
        return 1
    endif
    return 0
endfunction

" Start R
function StartR(whatr)
    call writefile([], g:rplugin_tmpdir . "/globenv_" . $NVIMR_ID)
    call writefile([], g:rplugin_tmpdir . "/liblist_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/libnames_" . $NVIMR_ID)

    if !exists("b:rplugin_R")
        call SetRPath()
    endif

    " Change to buffer's directory before starting R
    if g:R_nvim_wd == 0
        lcd %:p:h
    endif

    if a:whatr =~ "custom"
        call inputsave()
        let r_args = input('Enter parameters for R: ')
        call inputrestore()
        let b:rplugin_r_args = split(r_args)
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
    if g:R_objbr_texerr
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
    call writefile(start_options, g:rplugin_tmpdir . "/start_options.R")

    if g:R_in_buffer
        call StartR_Neovim()
        return
    endif

    let b:rplugin_r_args_str = join(b:rplugin_r_args)

    if g:R_applescript
        call StartR_OSX()
        return
    endif

    if has("win32") || has("win64")
        call StartR_Windows()
        return
    endif

    if g:R_only_in_tmux && $TMUX_PANE == ""
        call RWarningMsg("Not inside Tmux.")
        if g:R_nvim_wd == 0
            lcd -
        endif
        return
    endif

    " R was already started. Should restart it or warn?
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        if g:rplugin_do_tmux_split
            if g:R_restart
                call g:SendCmdToR('quit(save = "no")')
                sleep 100m
                call delete(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
                let ca_ck = g:R_ca_ck
                let g:R_ca_ck = 0
                call g:SendCmdToR(g:rplugin_last_rcmd)
                let g:R_ca_ck = ca_ck
                if WaitNvimcomStart()
                    sleep 100m
                    call g:SendCmdToR("\014")
                endif
                if IsExternalOBRunning()
                    call jobsend(g:rplugin_clt_job, g:rplugin_ob_port . ' ' . $NVIMR_SECRET . 'let g:rplugin_nvimcom_port = ' . g:rplugin_nvimcom_port . "\n")
                endif
                return
            elseif IsSendCmdToRFake()
		return
            endif
        else
            if g:R_restart
                call RQuit("restartR")
                let g:rplugin_nvimcom_port = 0
            endif
        endif
    endif

    if b:rplugin_r_args_str == ""
        let rcmd = b:rplugin_R
    else
        let rcmd = b:rplugin_R . " " . b:rplugin_r_args_str
    endif

    if g:rplugin_do_tmux_split
        call StartR_TmuxSplit(rcmd)
    else
        if g:R_restart && bufloaded(b:objbrtitle)
            call delete(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
        endif
        call StartR_ExternalTerm(rcmd)
        if g:R_restart && bufloaded(b:objbrtitle)
            if WaitNvimcomStart()
                call SendToNvimcom("\002" . g:rplugin_myport)
            endif
        endif
    endif

    " Go back to original directory:
    if g:R_nvim_wd == 0
        lcd -
    endif
    echon
endfunction

" To be called by edit() in R running in Neovim buffer.
function ShowRObject(fname)
    call RWarningMsg("ShowRObject not implemented yet: '" . a:fname . "'")
    let fcont = readfile(a:fname)
    let s:finalA = g:rplugin_tmpdir . "/nvimcom_edit_" . $NVIMR_ID . "_A"
    let finalB = g:rplugin_tmpdir . "/nvimcom_edit_" . $NVIMR_ID . "_B"
    let finalB = substitute(finalB, ' ', '\\ ', 'g')
    exe "tabnew " . finalB
    call setline(".", fcont)
    set ft=r
    stopinsert
    autocmd BufUnload <buffer> call delete(s:finalA) | unlet s:finalA | startinsert
endfunction

" Send SIGINT to R
function StopR()
    if g:rplugin_r_pid
        call system("kill -s SIGINT " . g:rplugin_r_pid)
    endif
endfunction

function OpenRScratch()
    below 6split R_Scratch
    set filetype=r
    setlocal noswapfile
    set buftype=nofile
    nmap <buffer><silent> <Esc> :quit<CR>
    nmap <buffer><silent> q :quit<CR>
    startinsert
endfunction

function WaitNvimcomStart()
    if b:rplugin_r_args_str =~ "vanilla"
        return 0
    endif
    if g:R_nvimcom_wait < 0
        return 0
    endif
    if g:R_nvimcom_wait < 300
        g:R_nvimcom_wait = 300
    endif
    redraw
    echo "Waiting nvimcom loading..."
    sleep 300m
    let ii = 300
    let waitmsg = 0
    while !filereadable(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID) && ii < g:R_nvimcom_wait
        let ii = ii + 200
        sleep 200m
    endwhile
    echon "\r                              "
    redraw
    sleep 100m
    if filereadable(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
        let vr = readfile(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
        let nvimcom_version = vr[0]
        let g:rplugin_nvimcom_home = vr[1]
        let g:rplugin_nvimcom_port = vr[2]
        let g:rplugin_r_pid = vr[3]
        if nvimcom_version != "0.9.2"
            call RWarningMsg('This version of Nvim-R requires nvimcom 0.9.2.')
            sleep 1
        endif
        if g:rplugin_clt_job
            call jobstop(g:rplugin_clt_job)
            let g:rplugin_clt_job = 0
        endif
        if g:rplugin_srv_job
            call jobstop(g:rplugin_srv_job)
            let g:rplugin_srv_job = 0
        endif
        if has("win64")
            let nvc = g:rplugin_nvimcom_home . "/bin/x64/nvimclient.exe"
            let nvs = g:rplugin_nvimcom_home . "/bin/x64/nvimserver.exe"
        elseif has("win32")
            let nvc = g:rplugin_nvimcom_home . "/bin/i386/nvimclient.exe"
            let nvs = g:rplugin_nvimcom_home . "/bin/i386/nvimserver.exe"
        else
            let nvc = g:rplugin_nvimcom_home . "/bin/nvimclient"
            let nvs = g:rplugin_nvimcom_home . "/bin/nvimserver"
        endif
        if filereadable(nvc)
            let g:rplugin_clt_job = jobstart([nvc], g:rplugin_job_handlers)
        else
            call RWarningMsg('Application "' . nvc . '" not found.")
        endif
        if filereadable(nvs)
            let g:rplugin_srv_job = jobstart([nvs], g:rplugin_job_handlers)
        else
            call RWarningMsg('Application "' . nvs . '" not found.')
        endif
        call delete(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)

        augroup RStarting
            autocmd!
            autocmd CursorMoved <buffer> call DelayedFillLibList()
            autocmd CursorMovedI <buffer> call DelayedFillLibList()
        augroup END

        if g:rplugin_do_tmux_split
            " Environment variables persists across Tmux windows.
            " Unset NVIMR_TMPDIR to avoid nvimcom loading its C library
            " when R was not started by Neovim:
            call system("tmux set-environment -u NVIMR_TMPDIR")
        endif
        return 1
    else
        call RWarningMsg("The package nvimcom wasn't loaded yet.")
        sleep 500m
        return 0
    endif
endfunction

function IsExternalOBRunning()
    if exists("g:rplugin_ob_pane")
        let plst = system("tmux list-panes | cat")
        if plst =~ g:rplugin_ob_pane
            return 1
        endif
    endif
    return 0
endfunction

function StartObjBrowser_Tmux()
    if b:rplugin_extern_ob
        " This is the Object Browser
        echoerr "StartObjBrowser_Tmux() called."
        return
    endif

    let g:RBrOpenCloseLs = function("RBrOpenCloseLs_TmuxNeovim")
    " Force Neovim to update the window size
    mode

    " Don't start the Object Browser if it already exists
    if IsExternalOBRunning()
        return
    endif

    let objbrowserfile = g:rplugin_tmpdir . "/objbrowserInit"
    let tmxs = " "

    call writefile([
                \ 'let g:rplugin_editor_port = ' . g:rplugin_myport,
                \ 'let g:rplugin_editor_pane = "' . g:rplugin_editor_pane . '"',
                \ 'let g:rplugin_rconsole_pane = "' . g:rplugin_rconsole_pane . '"',
                \ 'let $NVIMR_ID = "' . $NVIMR_ID . '"',
                \ 'let showmarks_enable = 0',
                \ 'let g:rplugin_tmuxsname = "' . g:rplugin_tmuxsname . '"',
                \ 'let b:rscript_buffer = "' . bufname("%") . '"',
                \ 'set filetype=rbrowser',
                \ 'let g:rplugin_nvimcom_home = "' . g:rplugin_nvimcom_home . '"',
                \ 'let g:rplugin_nvimcom_port = "' . g:rplugin_nvimcom_port . '"',
                \ 'let b:objbrtitle = "' . b:objbrtitle . '"',
                \ 'let b:rplugin_extern_ob = 1',
                \ 'set shortmess=atI',
                \ 'set rulerformat=%3(%l%)',
                \ 'set laststatus=0',
                \ 'set noruler',
                \ 'let g:SendCmdToR = function("SendCmdToR_TmuxSplit")',
                \ 'let g:RBrOpenCloseLs = function("RBrOpenCloseLs_Nvim")',
                \ 'let g:rplugin_clt_job = jobstart(["' . g:rplugin_nvimcom_home . '/bin/nvimclient"' . '], g:rplugin_job_handlers)',
                \ 'let g:rplugin_srv_job = jobstart(["' . g:rplugin_nvimcom_home . '/bin/nvimserver"' . '], g:rplugin_job_handlers)'], objbrowserfile)

    if g:R_objbr_place =~ "left"
        let panw = system("tmux list-panes | cat")
        if g:R_objbr_place =~ "console"
            " Get the R Console width:
            let panw = substitute(panw, '.*[0-9]: \[\([0-9]*\)x[0-9]*.\{-}' . g:rplugin_rconsole_pane . '\>.*', '\1', "")
        else
            " Get the Nvim width
            let panw = substitute(panw, '.*[0-9]: \[\([0-9]*\)x[0-9]*.\{-}' . g:rplugin_editor_pane . '\>.*', '\1', "")
        endif
        let panewidth = panw - g:R_objbr_w
        " Just to be safe: If the above code doesn't work as expected
        " and we get a spurious value:
        if panewidth < 30 || panewidth > 180
            let panewidth = 80
        endif
    else
        let panewidth = g:R_objbr_w
    endif
    if g:R_objbr_place =~ "console"
        let obpane = g:rplugin_rconsole_pane
    else
        let obpane = g:rplugin_editor_pane
    endif

    let cmd = "tmux split-window -h -l " . panewidth . " -t " . obpane . ' "TERM=' . $TERM . ' nvim ' . " -c 'source " . substitute(objbrowserfile, ' ', '\\ ', 'g') . "'" . '"'
    let rlog = system(cmd)
    if v:shell_error
        let rlog = substitute(rlog, '\n', ' ', 'g')
        let rlog = substitute(rlog, '\r', ' ', 'g')
        call RWarningMsg(rlog)
        let g:rplugin_running_objbr = 0
        return 0
    endif

    let g:rplugin_ob_pane = TmuxActivePane()
    let rlog = system("tmux select-pane -t " . g:rplugin_editor_pane)
    if v:shell_error
        call RWarningMsg(rlog)
        return 0
    endif

    if g:R_objbr_place =~ "left"
        if g:R_objbr_place =~ "console"
            call system("tmux swap-pane -d -s " . g:rplugin_rconsole_pane . " -t " . g:rplugin_ob_pane)
        else
            call system("tmux swap-pane -d -s " . g:rplugin_editor_pane . " -t " . g:rplugin_ob_pane)
        endif
    endif
    " Force Neovim to update the window size
    mode
    return
endfunction

function StartObjBrowser_Nvim()
    let g:RBrOpenCloseLs = function("RBrOpenCloseLs_Nvim")

    " Either load or reload the Object Browser
    let savesb = &switchbuf
    set switchbuf=useopen,usetab
    if bufloaded(b:objbrtitle)
        exe "sb " . b:objbrtitle
    else
        " Copy the values of some local variables that will be inherited
        let g:tmp_objbrtitle = b:objbrtitle
        let g:tmp_tmuxsname = g:rplugin_tmuxsname
        let g:tmp_curbufname = bufname("%")

        let l:sr = &splitright
        if g:R_objbr_place =~ "left"
            set nosplitright
        else
            set splitright
        endif
        if g:R_objbr_place =~ "console"
            sb g:rplugin_R_bufname
        endif
        sil exe "vsplit " . b:objbrtitle
        let &splitright = l:sr
        sil exe "vertical resize " . g:R_objbr_w
        sil set filetype=rbrowser
        let b:rplugin_extern_ob = 0

        " Inheritance of some local variables
        let g:rplugin_tmuxsname = g:tmp_tmuxsname
        let b:objbrtitle = g:tmp_objbrtitle
        let b:rscript_buffer = g:tmp_curbufname
        unlet g:tmp_objbrtitle
        unlet g:tmp_tmuxsname
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

    if g:rplugin_running_objbr == 1
        " Called twice due to BufEnter event
        return
    endif

    let g:rplugin_running_objbr = 1

    if !b:rplugin_extern_ob
        if g:R_tmux_ob
            call StartObjBrowser_Tmux()
        else
            call StartObjBrowser_Nvim()
        endif
    endif
    let g:rplugin_running_objbr = 0
    return
endfunction

function RBrOpenCloseLs_Nvim(status)
    if !exists("g:rplugin_curview")
        return
    endif
    if a:status == 1 && g:rplugin_curview == "libraries"
        echohl WarningMsg
        echon "GlobalEnv command only."
        sleep 1
        echohl Normal
        normal! :<Esc>
        return
    endif
    if g:rplugin_curview == "GlobalEnv"
        let stt = a:status
    else
        let stt = a:status + 2
    endif

    call SendToNvimcom("\007" . stt)
endfunction

function RBrOpenCloseLs_TmuxNeovim(status)
    if g:rplugin_ob_port
        call jobsend(g:rplugin_clt_job, g:rplugin_ob_port . ' ' . $NVIMR_SECRET . 'call RBrOpenCloseLs_Nvim(' . a:status . ')' . "\n")
    endif
endfunction

function SendToNvimcom(cmd)
    if g:rplugin_clt_job == 0
        call RWarningMsg("nvimcom client not running.")
        return
    endif
    call jobsend(g:rplugin_clt_job, g:rplugin_nvimcom_port . ' ' . a:cmd . "\n")
endfunction

function RSetMyPort(p)
    let g:rplugin_myport = a:p
    if &filetype == "rbrowser" && g:rplugin_do_tmux_split
        call SendToNvimcom("\002" . a:p)
        call jobsend(g:rplugin_clt_job, g:rplugin_editor_port . ' ' . $NVIMR_SECRET . 'let g:rplugin_ob_port = ' . g:rplugin_myport . "\n")
    else
        call SendToNvimcom("\001" . a:p)
    endif
endfunction

function RFormatCode() range
    if g:rplugin_nvimcom_port == 0
        return
    endif

    let lns = getline(a:firstline, a:lastline)
    call writefile(lns, g:rplugin_tmpdir . "/unformatted_code")
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
    if g:rplugin_lastev == "R is busy." || g:rplugin_lastev == "UNKNOWN" || g:rplugin_lastev =~ "^Error" || g:rplugin_lastev == "INVALID" || g:rplugin_lastev == "ERROR" || g:rplugin_lastev == "EMPTY" || g:rplugin_lastev == "No reply"
        call RWarningMsg(g:rplugin_lastev)
        return
    endif
    let lns = readfile(g:rplugin_tmpdir . "/formatted_code")
    silent exe a:firstline . "," . a:lastline . "delete"
    call append(a:firstline - 1, lns)
    echo (a:lastline - a:firstline + 1) . " lines formatted."
endfunction

function RInsert(cmd)
    if g:rplugin_nvimcom_port == 0
        return
    endif

    call delete(g:rplugin_tmpdir . "/eval_reply")
    call delete(g:rplugin_tmpdir . "/Rinsert")
    call SendToNvimcom("\x08" . $NVIMR_ID . 'capture.output(' . a:cmd . ', file = "' . g:rplugin_tmpdir . '/Rinsert")')
    let g:rplugin_lastev = ReadEvalReply()
    if g:rplugin_lastev == "R is busy." || g:rplugin_lastev == "UNKNOWN" || g:rplugin_lastev =~ "^Error" || g:rplugin_lastev == "INVALID" || g:rplugin_lastev == "ERROR" || g:rplugin_lastev == "EMPTY" || g:rplugin_lastev == "No reply"
        call RWarningMsg(g:rplugin_lastev)
    else
        silent exe "read " . substitute(g:rplugin_tmpdir, ' ', '\\ ', 'g') . "/Rinsert"
    endif
endfunction

function SendLineToRAndInsertOutput()
    let lin = getline(".")
    call RInsert("print(" . lin . ")")
    let curpos = getpos(".")
    " comment the output
    let ilines = readfile(substitute(g:rplugin_tmpdir, ' ', '\\ ', 'g') . "/Rinsert")
    for iln in ilines
        call RSimpleCommentLine("normal", "c")
        normal! j
    endfor
    call setpos(".", curpos)
endfunction

" Function to send commands
" return 0 on failure and 1 on success
function SendCmdToR_fake(cmd)
    call RWarningMsg("Did you already start R?")
    return 0
endfunction

function SendCmdToR_TmuxSplit(cmd)
    if g:R_ca_ck
        let cmd = "\001" . "\013" . a:cmd
    else
        let cmd = a:cmd
    endif

    if !exists("g:rplugin_rconsole_pane")
        " Should never happen
        call RWarningMsg("Missing internal variable: g:rplugin_rconsole_pane")
    endif
    let str = substitute(cmd, "'", "'\\\\''", "g")
    let scmd = "tmux set-buffer '" . str . "\<C-M>' && tmux paste-buffer -t " . g:rplugin_rconsole_pane
    let rlog = system(scmd)
    if v:shell_error
        let rlog = substitute(rlog, "\n", " ", "g")
        let rlog = substitute(rlog, "\r", " ", "g")
        call RWarningMsg(rlog)
        call ClearRInfo()
        return 0
    endif
    return 1
endfunction

function SendCmdToR_Term(cmd)
    if g:R_ca_ck
        let cmd = "\001" . "\013" . a:cmd
    else
        let cmd = a:cmd
    endif

    " Send the command to R running in an external terminal emulator
    let str = substitute(cmd, "'", "'\\\\''", "g")
    let scmd = "tmux set-buffer '" . str . "\<C-M>' && tmux paste-buffer -t " . g:rplugin_tmuxsname . '.0'
    let rlog = system(scmd)
    if v:shell_error
        let rlog = substitute(rlog, '\n', ' ', 'g')
        let rlog = substitute(rlog, '\r', ' ', 'g')
        call RWarningMsg(rlog)
        call ClearRInfo()
        return 0
    endif
    return 1
endfunction

" Get the word either under or after the cursor.
" Works for word(| where | is the cursor position.
function RGetKeyWord()
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
    setlocal iskeyword=@,48-57,_,.,$,@-@
    let rkeyword = expand("<cword>")
    exe "setlocal iskeyword=" . save_keyword
    call setpos(".", save_cursor)
    return rkeyword
endfunction

" Send sources to R
function RSourceLines(lines)
    let lines = a:lines
    if &filetype == "rrst"
        let lines = map(copy(lines), 'substitute(v:val, "^\\.\\. \\?", "", "")')
    endif
    if &filetype == "rmd"
        let lines = map(copy(lines), 'substitute(v:val, "^\\`\\`\\?", "", "")')
    endif
    call writefile(lines, g:rplugin_rsource)
    if g:R_source_args == ""
        let rcmd = 'base::source("' . g:rplugin_rsource . '")'
    else
        let rcmd = 'base::source("' . g:rplugin_rsource . '", ' . g:R_source_args . ')'
    endif
    let ok = g:SendCmdToR(rcmd)
    return ok
endfunction

" Send file to R
function SendFileToR()
    update
    let fpath = expand("%:p")
    if has("win32") || has("win64")
        let fpath = substitute(fpath, "\\", "/", "g")
    endif
    if g:R_source_args == ""
        call g:SendCmdToR('base::source("' . fpath . '")')
    else
        call g:SendCmdToR('base::source("' . fpath . '", ' . g:R_source_args . ')')
    endif
endfunction

" Send block to R
" Adapted from marksbrowser plugin
" Function to get the marks which the cursor is between
function SendMBlockToR(m)
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
    let ok = b:SourceLines(lines)
    if ok == 0
        return
    endif
    if a:m == "down" && lineB != line("$")
        call cursor(lineB, 1)
        call GoDown()
    endif
endfunction

" Send functions to R
function SendFunctionToR(m)
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
        call SendFunctionToR(a:m)
        call setpos(".", save_cursor)
        return
    endif

    let lines = getline(firstline, lastline)
    let ok = b:SourceLines(lines)
    if  ok == 0
        return
    endif
    if a:m == "down"
        call cursor(lastline, 1)
        call GoDown()
    endif
endfunction

" Send selection to R
function SendSelectionToR(m)
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
        let ok = g:SendCmdToR(line)
        if ok && a:m =~ "down"
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

    let ok = b:SourceLines(lines)
    if ok == 0
        return
    endif

    if a:m == "down"
        call GoDown()
    else
        normal! gv
    endif
endfunction

" Send paragraph to R
function SendParagraphToR(m)
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
    let ok = b:SourceLines(lines)
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
                call b:SourceLines(codelines)
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
    call b:SourceLines(codelines)
endfunction

function KnitChild(line, godown)
    let nline = substitute(a:line, '.*child *= *', "", "")
    let cfile = substitute(nline, nline[0], "", "")
    let cfile = substitute(cfile, nline[0] . '.*', "", "")
    if filereadable(cfile)
        let ok = g:SendCmdToR("require(knitr); knit('" . cfile . "', output=" . g:rplugin_null . ")")
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
        let line = substitute(line, "^\\`\\`\\?", "", "")
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
    call g:SendCmdToR("\014")
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
    if has("win32") || has("win64")
        let wdcmd = substitute(wdcmd, "\\", "/", "g")
    endif
    call g:SendCmdToR(wdcmd)
    sleep 100m
endfunction

function CloseExternalOB()
    if IsExternalOBRunning()
        call jobsend(g:rplugin_clt_job, g:rplugin_ob_port . ' ' . $NVIMR_SECRET . "call ExternOBQuit()\n")
        unlet g:rplugin_ob_pane
    endif
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
    call delete(g:rplugin_tmpdir . "/rconsole_hwnd_" . $NVIMR_SECRET)
    let g:SendCmdToR = function('SendCmdToR_fake')
    let g:rplugin_r_pid = 0
    let g:rplugin_nvimcom_port = 0

    if g:rplugin_do_tmux_split && g:R_tmux_title != "automatic" && g:R_tmux_title != ""
        call system("tmux set automatic-rename on")
    endif

    if g:rplugin_clt_job
        call jobstop(g:rplugin_clt_job)
    endif
    if g:rplugin_srv_job
        call jobstop(g:rplugin_srv_job)
    endif
endfunction

" Quit R
function RQuit(how)
    if a:how != "restartR"
        if bufloaded(b:objbrtitle)
            exe "bunload! " . b:objbrtitle
            sleep 30m
        endif
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

    if g:R_save_win_pos && v:servername != ""
        let repl = libcall(g:rplugin_vimcom_lib, "SaveWinPos", $NVIMR_COMPLDIR)
        if repl != "OK"
            call RWarningMsg(repl)
        endif
    endif

    call g:SendCmdToR(qcmd)
    if g:rplugin_do_tmux_split
        if a:how == "save"
            sleep 200m
        endif
        if g:R_restart
            let ca_ck = g:R_ca_ck
            let g:R_ca_ck = 0
            call g:SendCmdToR("exit")
            let g:R_ca_ck = ca_ck
        endif
    endif

    sleep 50m
    call CloseExternalOB()

    if g:rplugin_do_tmux_split
        " Force Neovim to update the window size
        sleep 500m
        mode
    elseif g:R_in_buffer && exists("g:rplugin_R_bufname")
        exe "sbuffer " . g:rplugin_R_bufname
        sleep 500m
        " Enter Insert mode and press 'any key' to close the buffer
        call feedkeys("a ")
    endif

    if !g:R_in_buffer
        call ClearRInfo()
    endif
endfunction

" knit the current buffer content
function! RKnit()
    update
    if has("win32") || has("win64")
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
        let g:rplugin_htw = substitute(htw, "\\..*", "", "")
        let g:rplugin_htw = g:rplugin_htw - (&number || &relativenumber) * &numberwidth
    endif
endfunction

function RGetClassFor(rkeyword)
    let classfor = ""
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
            return classfor
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
            let classfor = strpart(line, 0, idx)
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
            let classfor = strpart(line, 0, idx)
        else
            let classfor = substitute(line, ').*', '', "")
            let classfor = substitute(classfor, ',.*', '', "")
            let classfor = substitute(classfor, ' .*', '', "")
        endif
    endif
    if classfor =~ "^'" && classfor =~ "'$"
        let classfor = substitute(classfor, "^'", '"', "")
        let classfor = substitute(classfor, "'$", '"', "")
    endif
    return classfor
endfunction

" Show R's help doc in Nvim's buffer
" (based  on pydoc plugin)
function AskRDoc(rkeyword, package, getclass)
    if filewritable(g:rplugin_docfile)
        call delete(g:rplugin_docfile)
    endif

    let classfor = ""
    if bufname("%") =~ "Object_Browser" || (exists("g:rplugin_R_bufname") && bufname("%") == g:rplugin_R_bufname)
        let savesb = &switchbuf
        set switchbuf=useopen,usetab
        exe "sb " . b:rscript_buffer
        exe "set switchbuf=" . savesb
    else
        if a:getclass
            let classfor = RGetClassFor(a:rkeyword)
        endif
    endif

    if classfor =~ '='
        let classfor = "eval(expression(" . classfor . "))"
    endif

    call SetRTextWidth(a:rkeyword)

    if classfor == "" && a:package == ""
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . g:rplugin_htw . 'L)'
    elseif a:package != ""
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . g:rplugin_htw . 'L, package="' . a:package  . '")'
    else
        let classfor = substitute(classfor, '\\', "", "g")
        let classfor = substitute(classfor, '\(.\)"\(.\)', '\1\\"\2', "g")
        let rcmd = 'nvimcom:::nvim.help("' . a:rkeyword . '", ' . g:rplugin_htw . 'L, ' . classfor . ')'
    endif

    call SendToNvimcom("\x08" . $NVIMR_ID . rcmd)
endfunction

" This function is called by nvimcom
function ShowRDoc(rkeyword)
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
            call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim.help("' . msgs[-1] . '", ' . g:rplugin_htw . 'L, package="' . msgs[chn] . '")')
        endif
        return
    endif

    if exists("g:rplugin_R_bufname") && bufname("%") == g:rplugin_R_bufname
        call RWarningMsg("See https://github.com/neovim/neovim/issues/2301")
        sleep 200m
        return
        " Exit Terminal mode and go to Normal mode
        call feedkeys("\<C-\>\<C-N>", 't')
    endif

    " If the help command was triggered in the R Console, jump to Vim pane
    if g:rplugin_do_tmux_split && !g:rplugin_running_rhelp
        let slog = system("tmux select-pane -t " . g:rplugin_editor_pane)
        if v:shell_error
            call RWarningMsg(slog)
        endif
    endif
    let g:rplugin_running_rhelp = 0

    if bufname("%") =~ "Object_Browser" || (exists("g:rplugin_R_bufname") && bufname("%") == g:rplugin_R_bufname)
        let savesb = &switchbuf
        set switchbuf=useopen,usetab
        exe "sb " . b:rscript_buffer
        exe "set switchbuf=" . savesb
    endif
    call SetRTextWidth(rkeyw)

    " Local variables that must be inherited by the rdoc buffer
    let g:tmp_tmuxsname = g:rplugin_tmuxsname
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
            call RWarningMsg('R_nvimpager = "no". You should put options(nvimcom.nvimpager=FALSE) in your .Rprofile?')
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
    let g:rplugin_tmuxsname = g:tmp_tmuxsname
    unlet g:tmp_objbrtitle
    unlet g:tmp_tmuxsname

    let save_unnamed_reg = @@
    sil normal! ggdG
    let fcntt = readfile(g:rplugin_docfile)
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

function RSetPDFViewer()
    if exists("g:R_pdfviewer") && g:R_pdfviewer != "none"
        let g:rplugin_pdfviewer = tolower(g:R_pdfviewer)
    else
        " Try to guess what PDF viewer is used:
        if has("win32") || has("win64")
            let g:rplugin_pdfviewer = "sumatra"
        elseif g:rplugin_is_darwin
            let g:rplugin_pdfviewer = "skim"
        elseif executable("evince")
            let g:rplugin_pdfviewer = "evince"
        elseif executable("okular")
            let g:rplugin_pdfviewer = "okular"
        elseif executable("zathura")
            let g:rplugin_pdfviewer = "zathura"
        else
            let g:rplugin_pdfviewer = "none"
            if $R_PDFVIEWER == ""
                let pdfvl = ["xdg-open"]
            else
                let pdfvl = [$R_PDFVIEWER, "xdg-open"]
            endif
            " List from R configure script:
            let pdfvl += ["xpdf", "gv", "gnome-gv", "ggv", "kpdf", "gpdf", "kghostview,", "acroread", "acroread4"]
            for prog in pdfvl
                if executable(prog)
                    let g:rplugin_pdfviewer = prog
                    break
                endif
            endfor
        endif
    endif

    if executable("wmctrl")
        let g:rplugin_has_wmctrl = 1
    else
        let g:rplugin_has_wmctrl = 0
    endif

    if g:rplugin_pdfviewer == "zathura"
        if g:rplugin_has_wmctrl == 0
            let g:rplugin_pdfviewer = "none"
            call RWarningMsgInp("The application wmctrl must be installed to use Zathura as PDF viewer.")
        else
            if executable("dbus-send")
                let g:rplugin_has_dbussend = 1
            else
                let g:rplugin_has_dbussend = 0
            endif
        endif
    endif

    " Try to guess the title of the window where Nvim is running:
    if has("gui_running")
        call RSetDefaultValue("g:R_nvim_window", "'GVim'")
    elseif g:rplugin_pdfviewer == "evince"
        call RSetDefaultValue("g:R_nvim_window", "'Terminal'")
    elseif g:rplugin_pdfviewer == "okular"
        call RSetDefaultValue("g:R_nvim_window", "'Konsole'")
    else
        call RSetDefaultValue("g:R_nvim_window", "'term'")
    endif

endfunction

function RStart_Zathura(basenm)
    let shcode = ['#!/bin/sh', 'echo "call SyncTeX_backward(' . "'$1'" . ', $2)" >> "' . g:rplugin_tmpdir . '/zathura_search"']
    call writefile(shcode, g:rplugin_tmpdir . "/synctex_back.sh")
    let a2 = "a2 = 'sh " . g:rplugin_tmpdir . "/synctex_back.sh %{input} %{line}'"
    let pycode = ["import subprocess",
                \ "import os",
                \ "import sys",
                \ "FNULL = open(os.devnull, 'w')",
                \ "a1 = '--synctex-editor-command'",
                \ a2,
                \ "a3 = '" . a:basenm . ".pdf'",
                \ "zpid = subprocess.Popen(['zathura', a1, a2, a3], stdout = FNULL, stderr = FNULL).pid",
                \ "sys.stdout.write(str(zpid))" ]
    call writefile(pycode, g:rplugin_tmpdir . "/start_zathura.py")
    let pid = system("python '" . g:rplugin_tmpdir . "/start_zathura.py" . "'")
    let g:rplugin_zathura_pid[a:basenm] = pid
    call delete(g:rplugin_tmpdir . "/start_zathura.py")
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
        exe "cd " . substitute(expand("%:p:h"), ' ', '\\ ', 'g')
    endif

    if !filereadable(basenm . ".pdf")
        call RWarningMsg('File not found: "' . basenm . '.pdf".')
        exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
        return
    endif
    if g:rplugin_pdfviewer == "none"
        call RWarningMsg("Could not find a PDF viewer, and R_pdfviewer is not defined.")
    else
        if g:rplugin_pdfviewer == "okular"
            let pcmd = "okular --unique '" .  pdfpath . "' 2>/dev/null >/dev/null &"
        elseif g:rplugin_pdfviewer == "zathura"
            if system("wmctrl -xl") =~ 'Zathura.*' . basenm . '.pdf' && g:rplugin_zathura_pid[basenm] != 0
                call system("wmctrl -a '" . basenm . ".pdf'")
            else
                let g:rplugin_zathura_pid[basenm] = 0
                call RStart_Zathura(basenm)
            endif
            exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
            return
        elseif g:rplugin_pdfviewer == "sumatra" && (g:rplugin_sumatra_path != "" || FindSumatra())
            silent exe '!start "' . g:rplugin_sumatra_path . '" -reuse-instance -inverse-search "vim --servername ' . v:servername . " --remote-expr SyncTeX_backward('\\%f',\\%l)" . '" "' . basenm . '.pdf"'
            exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
            return
        elseif g:rplugin_pdfviewer == "skim"
            call system(g:macvim_skim_app_path . '/Contents/MacOS/Skim "' . basenm . '.pdf" 2> /dev/null >/dev/null &')
        else
            let pcmd = g:rplugin_pdfviewer . " '" . pdfpath . "' 2>/dev/null >/dev/null &"
            call system(pcmd)
        endif
        if g:rplugin_has_wmctrl
            call system("wmctrl -a '" . basenm . ".pdf'")
        endif
    endif
    exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
endfunction


function RSourceDirectory(...)
    if has("win32") || has("win64")
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
    if &filetype == "r" || b:IsInRCode(0)
        let rkeyword = RGetKeyWord()
        let s:sttl_str = g:rplugin_status_line
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
endfunction

function RArgsStatusLine()
    return s:sttl_str
endfunction

function RestoreStatusLine()
    exe 'set statusline=' . substitute(g:rplugin_status_line, ' ', '\\ ', 'g')
    normal! a)
endfunction

function PrintRObject(rkeyword)
    if bufname("%") =~ "Object_Browser"
        let classfor = ""
    else
        let classfor = RGetClassFor(a:rkeyword)
    endif
    if classfor == ""
        call g:SendCmdToR("print(" . a:rkeyword . ")")
    else
        call g:SendCmdToR('nvim.print("' . a:rkeyword . '", ' . classfor . ")")
    endif
endfunction

" Call R functions for the word under cursor
function RAction(rcmd)
    if &filetype == "rbrowser"
        let rkeyword = RBrowserGetName(1, 0)
    else
        let rkeyword = RGetKeyWord()
    endif
    if strlen(rkeyword) > 0
        if a:rcmd == "help"
            let g:rplugin_running_rhelp = 1
            if g:R_nvimpager == "no"
                call g:SendCmdToR("help(" . rkeyword . ")")
            else
                if bufname("%") =~ "Object_Browser" || b:rplugin_extern_ob
                    if g:rplugin_curview == "libraries"
                        let pkg = RBGetPkgName()
                    else
                        let pkg = ""
                    endif
                    if b:rplugin_extern_ob
                        call jobsend(g:rplugin_clt_job, g:rplugin_editor_port . ' ' . $NVIMR_SECRET . 'call AskRDoc("' . rkeyword . '", "' . pkg . '", 0)' . "\n")
                        let slog = system("tmux select-pane -t " . g:rplugin_editor_pane)
                        if v:shell_error
                            call RWarningMsg(slog)
                        endif
                        return
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
        if a:rcmd == "args" && g:R_listmethods == 1
            let rfun = "nvim.list.args"
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

        let raction = rfun . "(" . rkeyword . ")"
        call g:SendCmdToR(raction)
    endif
endfunction

if exists('g:maplocalleader')
    let s:tll = '<Tab>' . g:maplocalleader
else
    let s:tll = '<Tab>\\'
endif

redir => s:ikblist
silent imap
redir END
redir => s:nkblist
silent nmap
redir END
redir => s:vkblist
silent vmap
redir END
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

function RCreateMenuItem(type, label, plug, combo, target)
    if a:type =~ '0'
        let tg = a:target . '<CR>0'
        let il = 'i'
    else
        let tg = a:target . '<CR>'
        let il = 'a'
    endif
    if a:type =~ "n"
        if hasmapto(a:plug, "n")
            let boundkey = RNMapCmd(a:plug)
            exec 'nmenu <silent> &R.' . a:label . '<Tab>' . boundkey . ' ' . tg
        else
            exec 'nmenu <silent> &R.' . a:label . s:tll . a:combo . ' ' . tg
        endif
    endif
    if a:type =~ "v"
        if hasmapto(a:plug, "v")
            let boundkey = RVMapCmd(a:plug)
            exec 'vmenu <silent> &R.' . a:label . '<Tab>' . boundkey . ' ' . '<Esc>' . tg
        else
            exec 'vmenu <silent> &R.' . a:label . s:tll . a:combo . ' ' . '<Esc>' . tg
        endif
    endif
    if a:type =~ "i"
        if hasmapto(a:plug, "i")
            let boundkey = RIMapCmd(a:plug)
            exec 'imenu <silent> &R.' . a:label . '<Tab>' . boundkey . ' ' . '<Esc>' . tg . il
        else
            exec 'imenu <silent> &R.' . a:label . s:tll . a:combo . ' ' . '<Esc>' . tg . il
        endif
    endif
endfunction

function RBrowserMenu()
    call RCreateMenuItem("nvi", 'Object\ browser.Show/Update', '<Plug>RUpdateObjBrowser', 'ro', ':call RObjBrowser()')
    call RCreateMenuItem("nvi", 'Object\ browser.Expand\ (all\ lists)', '<Plug>ROpenLists', 'r=', ':call g:RBrOpenCloseLs(1)')
    call RCreateMenuItem("nvi", 'Object\ browser.Collapse\ (all\ lists)', '<Plug>RCloseLists', 'r-', ':call g:RBrOpenCloseLs(0)')
    if &filetype == "rbrowser"
        imenu <silent> R.Object\ browser.Toggle\ (cur)<Tab>Enter <Esc>:call RBrowserDoubleClick()<CR>
        nmenu <silent> R.Object\ browser.Toggle\ (cur)<Tab>Enter :call RBrowserDoubleClick()<CR>
    endif
    let g:rplugin_hasmenu = 1
endfunction

function RControlMenu()
    call RCreateMenuItem("nvi", 'Command.List\ space', '<Plug>RListSpace', 'rl', ':call g:SendCmdToR("ls()")')
    call RCreateMenuItem("nvi", 'Command.Clear\ console\ screen', '<Plug>RClearConsole', 'rr', ':call RClearConsole()')
    call RCreateMenuItem("nvi", 'Command.Clear\ all', '<Plug>RClearAll', 'rm', ':call RClearAll()')
    "-------------------------------
    menu R.Command.-Sep1- <nul>
    call RCreateMenuItem("nvi", 'Command.Print\ (cur)', '<Plug>RObjectPr', 'rp', ':call RAction("print")')
    call RCreateMenuItem("nvi", 'Command.Names\ (cur)', '<Plug>RObjectNames', 'rn', ':call RAction("nvim.names")')
    call RCreateMenuItem("nvi", 'Command.Structure\ (cur)', '<Plug>RObjectStr', 'rt', ':call RAction("str")')
    "-------------------------------
    menu R.Command.-Sep2- <nul>
    call RCreateMenuItem("nvi", 'Command.Arguments\ (cur)', '<Plug>RShowArgs', 'ra', ':call RAction("args")')
    call RCreateMenuItem("nvi", 'Command.Example\ (cur)', '<Plug>RShowEx', 're', ':call RAction("example")')
    call RCreateMenuItem("nvi", 'Command.Help\ (cur)', '<Plug>RHelp', 'rh', ':call RAction("help")')
    "-------------------------------
    menu R.Command.-Sep3- <nul>
    call RCreateMenuItem("nvi", 'Command.Summary\ (cur)', '<Plug>RSummary', 'rs', ':call RAction("summary")')
    call RCreateMenuItem("nvi", 'Command.Plot\ (cur)', '<Plug>RPlot', 'rg', ':call RAction("plot")')
    call RCreateMenuItem("nvi", 'Command.Plot\ and\ summary\ (cur)', '<Plug>RSPlot', 'rb', ':call RAction("plotsumm")')
    let g:rplugin_hasmenu = 1
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
    call RCreateMaps("nvi", '<Plug>ROpenLists',        'r=', ':call g:RBrOpenCloseLs(1)')
    call RCreateMaps("nvi", '<Plug>RCloseLists',       'r-', ':call g:RBrOpenCloseLs(0)')
endfunction


" For each noremap we need a vnoremap including <Esc> before the :call,
" otherwise nvim will call the function as many times as the number of selected
" lines. If we put the <Esc> in the noremap, nvim will bell.
" RCreateMaps Args:
"   type : modes to which create maps (normal, visual and insert) and whether
"          the cursor have to go the beginning of the line
"   plug : the <Plug>Name
"   combo: the combination of letter that make the shortcut
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
        silent exe 'imap <buffer><silent> ' . g:R_assign_map . ' <Esc>:call ReplaceUnderS()<CR>a'
    endif
    if g:R_args_in_stline
        imap <buffer><silent> ( <Esc>:call DisplayArgs()<CR>a
        imap <buffer><silent> ) <Esc>:call RestoreStatusLine()<CR>a
    endif
    if hasmapto("<Plug>RCompleteArgs", "i")
        imap <buffer><silent> <Plug>RCompleteArgs <C-R>=RCompleteArgs()<CR>
    else
        imap <buffer><silent> <C-X><C-A> <C-R>=RCompleteArgs()<CR>
    endif
endfunction

function RCreateSendMaps()
    " Block
    "-------------------------------------
    call RCreateMaps("ni", '<Plug>RSendMBlock',     'bb', ':call SendMBlockToR("stay")')
    call RCreateMaps("ni", '<Plug>RDSendMBlock',    'bd', ':call SendMBlockToR("down")')

    " Function
    "-------------------------------------
    call RCreateMaps("nvi", '<Plug>RSendFunction',  'ff', ':call SendFunctionToR("stay")')
    call RCreateMaps("nvi", '<Plug>RDSendFunction', 'fd', ':call SendFunctionToR("down")')

    " Selection
    "-------------------------------------
    call RCreateMaps("v", '<Plug>RSendSelection',   'ss', ':call SendSelectionToR("stay")')
    call RCreateMaps("v", '<Plug>RDSendSelection',  'sd', ':call SendSelectionToR("down")')

    " Paragraph
    "-------------------------------------
    call RCreateMaps("ni", '<Plug>RSendParagraph',   'pp', ':call SendParagraphToR("stay")')
    call RCreateMaps("ni", '<Plug>RDSendParagraph',  'pd', ':call SendParagraphToR("down")')

    if &filetype == "rnoweb" || &filetype == "rmd" || &filetype == "rrst"
        call RCreateMaps("ni", '<Plug>RSendChunkFH', 'ch', ':call SendFHChunkToR()')
    endif

    " *Line*
    "-------------------------------------
    call RCreateMaps("ni", '<Plug>RSendLine', 'l', ':call SendLineToR("stay")')
    call RCreateMaps('ni0', '<Plug>RDSendLine', 'd', ':call SendLineToR("down")')
    call RCreateMaps('ni0', '<Plug>RDSendLineAndInsertOutput', 'o', ':call SendLineToRAndInsertOutput()')
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

function RVimLeave()
    call delete(g:rplugin_rsource)
    call delete(g:rplugin_tmpdir . "/start_options.R")
    call delete(g:rplugin_tmpdir . "/eval_reply")
    call delete(g:rplugin_tmpdir . "/formatted_code")
    call delete(g:rplugin_tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/globenv_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/liblist_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/libnames_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/objbrowserInit")
    call delete(g:rplugin_tmpdir . "/Rdoc")
    call delete(g:rplugin_tmpdir . "/Rinsert")
    call delete(g:rplugin_tmpdir . "/tmux.conf")
    call delete(g:rplugin_tmpdir . "/unformatted_code")
    call delete(g:rplugin_tmpdir . "/nvimbol_finished")
    call delete(g:rplugin_tmpdir . "/nvimcom_running_" . $NVIMR_ID)
    call delete(g:rplugin_tmpdir . "/rconsole_hwnd_" . $NVIMR_SECRET)
    call delete(g:rplugin_tmpdir . "/openR'")
    if executable("rmdir")
        call system("rmdir '" . g:rplugin_tmpdir . "'")
    endif
endfunction

function SetRPath()
    if exists("g:R_path")
        let b:rplugin_R = expand(g:R_path)
        if isdirectory(b:rplugin_R)
            let b:rplugin_R = b:rplugin_R . "/R"
        endif
    else
        let b:rplugin_R = "R"
    endif
    if !executable(b:rplugin_R)
        call RWarningMsgInp("R executable not found: '" . b:rplugin_R . "'")
    endif
    let b:rplugin_r_args = []
    if exists("g:R_args")
        let b:rplugin_r_args = g:R_args
    endif
    let b:rplugin_r_args_str = join(b:rplugin_r_args)
endfunction

" Tell R to create a list of objects file listing all currently available
" objects in its environment. The file is necessary for omni completion.
function BuildROmniList()
    if string(g:SendCmdToR) == "function('SendCmdToR_fake')"
        return
    endif

    let omnilistcmd = 'nvimcom:::nvim.bol("' . g:rplugin_tmpdir . "/GlobalEnvList_" . $NVIMR_ID . '"'
    if g:R_allnames == 1
        let omnilistcmd = omnilistcmd . ', allnames = TRUE'
    endif
    let omnilistcmd = omnilistcmd . ')'

    call delete(g:rplugin_tmpdir . "/nvimbol_finished")
    call delete(g:rplugin_tmpdir . "/eval_reply")
    call SendToNvimcom("\x08" . $NVIMR_ID . omnilistcmd)
    if g:rplugin_nvimcom_port == 0
        sleep 500m
        return
    endif
    let g:rplugin_lastev = ReadEvalReply()
    if g:rplugin_lastev == "R is busy." || g:rplugin_lastev == "No reply"
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

    let g:rplugin_globalenvlines = readfile(g:rplugin_tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
endfunction

function CompleteR(findstart, base)
    if &filetype == "rnoweb" && RnwIsInRCode(0) == 0 && exists("*LatexBox_Complete")
        let texbegin = LatexBox_Complete(a:findstart, a:base)
        return texbegin
    endif
    if a:findstart
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && (line[start - 1] =~ '\w' || line[start - 1] =~ '\.' || line[start - 1] =~ '\$')
            let start -= 1
        endwhile
        call BuildROmniList()
        return start
    else
        let resp = []
        if strlen(a:base) == 0
            return resp
        endif

        if len(g:rplugin_omni_lines) == 0
            call add(resp, {'word': a:base, 'menu': " [ List is empty. Did you load nvimcom package? ]"})
        endif

        let flines = g:rplugin_omni_lines + g:rplugin_globalenvlines
        " The char '$' at the end of 'a:base' is treated as end of line, and
        " the pattern is never found in 'line'.
        let newbase = '^' . substitute(a:base, "\\$$", "", "")
        for line in flines
            if line =~ newbase
                " Skip cols of data frames unless the user is really looking for them.
                if a:base !~ '\$' && line =~ '\$'
                    continue
                endif
                let tmp1 = split(line, "\x06", 1)
                if g:R_show_args
                    let info = tmp1[4]
                    let info = substitute(info, "\t", ", ", "g")
                    let info = substitute(info, "\x07", " = ", "g")
                    let tmp2 = {'word': tmp1[0], 'menu': tmp1[1] . ' ' . tmp1[3], 'info': info}
                else
                    let tmp2 = {'word': tmp1[0], 'menu': tmp1[1] . ' ' . tmp1[3]}
                endif
                call add(resp, tmp2)
            endif
        endfor

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

command -nargs=1 -complete=customlist,RLisObjs Rinsert :call RInsert(<q-args>)
command -range=% Rformat <line1>,<line2>:call RFormatCode()
command RBuildTags :call g:SendCmdToR('rtags(ofile = "TAGS")')
command -nargs=? -complete=customlist,RLisObjs Rhelp :call RAskHelp(<q-args>)
command -nargs=? -complete=dir RSourceDir :call RSourceDirectory(<q-args>)
command RStop :call StopR()
command Rhistory :call ShowRhistory()


"==========================================================================
" Global variables
" Convention: R_ for user options
"             rplugin_    for internal parameters
"==========================================================================

if !exists("g:rplugin_compldir")
    runtime R/setcompldir.vim
endif


if exists("g:R_tmpdir")
    let g:rplugin_tmpdir = expand(g:R_tmpdir)
else
    if has("win32") || has("win64")
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
let g:rplugin_rsource = g:rplugin_tmpdir . "/Rsource-" . getpid()

let g:rplugin_is_darwin = system("uname") =~ "Darwin"

" Variables whose default value is fixed
call RSetDefaultValue("g:R_allnames",          0)
call RSetDefaultValue("g:R_rmhidden",          0)
call RSetDefaultValue("g:R_assign",            1)
call RSetDefaultValue("g:R_assign_map",    "'_'")
call RSetDefaultValue("g:R_args_in_stline",    0)
call RSetDefaultValue("g:R_rnowebchunk",       1)
call RSetDefaultValue("g:R_strict_rst",        1)
call RSetDefaultValue("g:R_openpdf",           2)
call RSetDefaultValue("g:R_synctex",           1)
call RSetDefaultValue("g:R_openhtml",          0)
call RSetDefaultValue("g:R_nvim_wd",           0)
call RSetDefaultValue("g:R_source_args",    "''")
call RSetDefaultValue("g:R_after_start",    "''")
call RSetDefaultValue("g:R_restart",           0)
call RSetDefaultValue("g:R_vsplit",            0)
call RSetDefaultValue("g:R_rconsole_width",   -1)
call RSetDefaultValue("g:R_rconsole_height",  15)
call RSetDefaultValue("g:R_tmux_title","'NvimR'")
call RSetDefaultValue("g:R_listmethods",       0)
call RSetDefaultValue("g:R_specialplot",       0)
call RSetDefaultValue("g:R_notmuxconf",        0)
call RSetDefaultValue("g:R_only_in_tmux",      0)
call RSetDefaultValue("g:R_routnotab",         0)
call RSetDefaultValue("g:R_editor_w",         66)
call RSetDefaultValue("g:R_help_w",           46)
call RSetDefaultValue("g:R_objbr_w",          40)
call RSetDefaultValue("g:R_objbr_opendf",      1)
call RSetDefaultValue("g:R_objbr_openlist",    0)
call RSetDefaultValue("g:R_objbr_allnames",    0)
call RSetDefaultValue("g:R_objbr_texerr",      1)
call RSetDefaultValue("g:R_objbr_labelerr",    1)
call RSetDefaultValue("g:R_in_buffer",         0)
call RSetDefaultValue("g:R_hl_term",           0)
call RSetDefaultValue("g:R_nvimcom_wait",   5000)
call RSetDefaultValue("g:R_show_args",         0)
call RSetDefaultValue("g:R_never_unmake_menu", 0)
call RSetDefaultValue("g:R_insert_mode_cmds",  0)
call RSetDefaultValue("g:R_indent_commented",  1)
call RSetDefaultValue("g:R_source",         "''")
call RSetDefaultValue("g:R_rcomment_string", "'# '")
if g:R_in_buffer
    let g:rplugin_rhistory = [ ]
    let g:rplugin_rhist_pos = -1
    let g:rplugin_addedtohist = 0
    call RSetDefaultValue("g:R_nvimpager", "'vertical'")
else
    call RSetDefaultValue("g:R_nvimpager",      "'tab'")
endif
call RSetDefaultValue("g:R_objbr_place",     "'script,right'")
call RSetDefaultValue("g:R_user_maps_only", 0)
call RSetDefaultValue("g:R_latexcmd", "'default'")
call RSetDefaultValue("g:R_rmd_environment", "'.GlobalEnv'")
if has("win32") || has("win64")
    call RSetDefaultValue("g:R_Rterm",           0)
    call RSetDefaultValue("g:R_save_win_pos",    1)
    call RSetDefaultValue("g:R_arrange_windows", 1)
else
    let g:R_Rterm = 0
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

function ROnJobStdout(job_id, data)
    for cmd in a:data
        if cmd == ""
            continue
        endif
        if cmd =~ "^call " || cmd  =~ "^let " || cmd =~ "^unlet "
            exe cmd
        else
            call RWarningMsg("[Job] Unknown command: " . cmd)
        endif
    endfor
endfunction

function ROnJobStderr(job_id, data)
    call RWarningMsg('Job error: ' . join(a:data))
endfunction

function ROnJobExit(job_id, data)
    if a:job_id == g:rplugin_clt_job
        let g:rplugin_clt_job = 0
    elseif a:job_id == g:rplugin_srv_job
        let g:rplugin_srv_job = 0
    elseif a:job_id == g:rplugin_R_job
        let g:rplugin_R_job = 0
        unlet g:rplugin_R_bufname
        call ClearRInfo()
    endif
endfunction


" ^K (\013) cleans from cursor to the right and ^U (\025) cleans from cursor
" to the left. However, ^U causes a beep if there is nothing to clean. The
" solution is to use ^A (\001) to move the cursor to the beginning of the line
" before sending ^K. But the control characters may cause problems in some
" circumstances.
call RSetDefaultValue("g:R_ca_ck", 0)

" ========================================================================
" Set default mean of communication with R

if has('gui_running')
    let g:rplugin_do_tmux_split = 0
endif

if g:rplugin_is_darwin
    let g:rplugin_r64app = 0
    if isdirectory("/Applications/R64.app")
        call RSetDefaultValue("g:R_applescript", 1)
        let g:rplugin_r64app = 1
    elseif isdirectory("/Applications/R.app")
        call RSetDefaultValue("g:R_applescript", 1)
    else
        call RSetDefaultValue("g:R_applescript", 0)
    endif
    if !exists("g:macvim_skim_app_path")
        let g:macvim_skim_app_path = '/Applications/Skim.app'
    endif
else
    let g:R_applescript = 0
endif

if has("gui_running") || g:R_applescript
    let R_only_in_tmux = 0
endif

if has("gui_running") || has("win32") || g:R_applescript
    let g:R_tmux_ob = 0
    if !g:R_in_buffer
        if g:R_objbr_place =~ "console"
            let g:R_objbr_place = substitute(g:R_objbr_place, "console", "script", "")
        endif
    endif
endif

if g:R_in_buffer
    let g:R_tmux_ob = 0
    let g:rplugin_do_tmux_split = 0
endif

if $TMUX == ""
    let g:rplugin_do_tmux_split = 0
    call RSetDefaultValue("g:R_tmux_ob", 0)
else
    let g:rplugin_do_tmux_split = 1
    let g:R_applescript = 0
    call RSetDefaultValue("g:R_tmux_ob", 1)
endif
if g:R_objbr_place =~ "console" && !g:R_in_buffer
    let g:R_tmux_ob = 1
endif


" ========================================================================

" Check whether Tmux is OK
if !has("win32") && !has("win64") && !has("gui_win32") && !has("gui_win64") && !g:R_applescript && !g:R_in_buffer
    if !executable('tmux') && g:R_source !~ "screenR"
        call RWarningMsgInp("Please, install the 'Tmux' application to enable the Nvim-R.")
        let g:rplugin_failed = 1
        finish
    endif

    let s:tmuxversion = system("tmux -V")
    let s:tmuxversion = substitute(s:tmuxversion, '.*tmux \([0-9]\.[0-9]\).*', '\1', '')
    if strlen(s:tmuxversion) != 3
        let s:tmuxversion = "1.0"
    endif
    if s:tmuxversion < "1.5" && g:R_source !~ "screenR"
        call RWarningMsgInp("Nvim-R requires Tmux >= 1.5")
        let g:rplugin_failed = 1
        finish
    endif
    unlet s:tmuxversion
endif

" Start with an empty list of objects in the workspace
let g:rplugin_globalenvlines = []

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


" Choose a terminal (code adapted from screen.vim)
if exists("g:R_term")
    if !executable(g:R_term)
        call RWarningMsgInp("'" . g:R_term . "' not found. Please change the value of 'R_term' in your nvimrc.")
        let g:R_term = "xterm"
    endif
endif
if has("win32") || has("win64") || g:rplugin_is_darwin || g:rplugin_do_tmux_split || g:R_in_buffer
    " No external terminal emulator will be called, so any value is good
    let g:R_term = "xterm"
endif
if !exists("g:R_term")
    let s:terminals = ['gnome-terminal', 'konsole', 'xfce4-terminal', 'terminal', 'Eterm',
                \ 'rxvt', 'urxvt', 'aterm', 'roxterm', 'terminator', 'lxterminal', 'xterm']
    for s:term in s:terminals
        if executable(s:term)
            let g:R_term = s:term
            break
        endif
    endfor
    unlet s:term
    unlet s:terminals
endif

if !exists("g:R_term") && !exists("g:R_term_cmd")
    call RWarningMsgInp("Please, set the variable 'g:R_term_cmd' in your .nvimrc. Read the plugin documentation for details.")
    let g:rplugin_failed = 1
    finish
endif

let g:rplugin_termcmd = g:R_term . " -e"

if g:R_term == "gnome-terminal" || g:R_term == "xfce4-terminal" || g:R_term == "terminal" || g:R_term == "lxterminal"
    " Cannot set gnome-terminal icon: http://bugzilla.gnome.org/show_bug.cgi?id=126081
    if g:R_nvim_wd
        let g:rplugin_termcmd = g:R_term . " --title R -e"
    else
        let g:rplugin_termcmd = g:R_term . " --working-directory='" . expand("%:p:h") . "' --title R -e"
    endif
endif

if g:R_term == "terminator"
    if g:R_nvim_wd
        let g:rplugin_termcmd = "terminator --title R -x"
    else
        let g:rplugin_termcmd = "terminator --working-directory='" . expand("%:p:h") . "' --title R -x"
    endif
endif

if g:R_term == "konsole"
    if g:R_nvim_wd
        let g:rplugin_termcmd = "konsole --icon " . g:rplugin_home . "/bitmaps/ricon.png -e"
    else
        let g:rplugin_termcmd = "konsole --workdir '" . expand("%:p:h") . "' --icon " . g:rplugin_home . "/bitmaps/ricon.png -e"
    endif
endif

if g:R_term == "Eterm"
    let g:rplugin_termcmd = "Eterm --icon " . g:rplugin_home . "/bitmaps/ricon.png -e"
endif

if g:R_term == "roxterm"
    " Cannot set icon: http://bugzilla.gnome.org/show_bug.cgi?id=126081
    if g:R_nvim_wd
        let g:rplugin_termcmd = "roxterm --title R -e"
    else
        let g:rplugin_termcmd = "roxterm --directory='" . expand("%:p:h") . "' --title R -e"
    endif
endif

if g:R_term == "xterm" || g:R_term == "uxterm"
    let g:rplugin_termcmd = g:R_term . " -xrm '*iconPixmap: " . g:rplugin_home . "/bitmaps/ricon.xbm' -e"
endif

if g:R_term == "rxvt" || g:R_term == "urxvt"
    let g:rplugin_termcmd = g:R_term . " -cd '" . expand("%:p:h") . "' -title R -xrm '*iconPixmap: " . g:rplugin_home . "/bitmaps/ricon.xbm' -e"
endif

" Override default settings:
if exists("g:R_term_cmd")
    let g:rplugin_termcmd = g:R_term_cmd
endif

if filewritable('/dev/null')
    let g:rplugin_null = "'/dev/null'"
elseif has("win32") && filewritable('NUL')
    let g:rplugin_null = "'NUL'"
else
    let g:rplugin_null = 'tempfile()'
endif

autocmd BufEnter * call RBufEnter()
if &filetype != "rbrowser"
    autocmd VimLeave * call RVimLeave()
endif

let g:rplugin_firstbuffer = expand("%:p")
let g:rplugin_status_line = &statusline
let g:rplugin_running_objbr = 0
let g:rplugin_running_rhelp = 0
let g:rplugin_clt_job = 0
let g:rplugin_srv_job = 0
let g:rplugin_R_job = 0
let g:rplugin_r_pid = 0
let g:rplugin_myport = 0
let g:rplugin_ob_port = 0
let g:rplugin_nvimcom_port = 0
let g:rplugin_nvimcom_home = ""
let g:rplugin_lastev = ""
let g:rplugin_last_r_prompt = ""
let g:rplugin_tmuxsname = "NvimR-" . substitute(localtime(), '.*\(...\)', '\1', '')
let g:rplugin_starting_R = 0

" Set the JobActivities here because to guarantee that the callback function
" will be called only once
if exists("##JobActivity")
    call RWarningMsgInp("You must update Neovim! Run 'git pull', 'make', etc...")
else
    let g:rplugin_job_handlers = {'on_stdout': function('ROnJobStdout'), 'on_stderr': function('ROnJobStderr'), 'on_exit': function('ROnJobExit')}
endif

" SyncTeX options
let g:rplugin_has_wmctrl = 0
let g:rplugin_zathura_pid = {}

let g:rplugin_py_exec = "none"
if executable("python3")
    let g:rplugin_py_exec = "python3"
elseif executable("python")
    let g:rplugin_py_exec = "python"
endif

function GetRandomNumber(width)
    if g:rplugin_py_exec != "none"
        let pycode = ["import os, sys, base64",
                    \ "sys.stdout.write(base64.b64encode(os.urandom(" . a:width . ")).decode())" ]
        call writefile(pycode, g:rplugin_tmpdir . "/getRandomNumber.py")
        let randnum = system(g:rplugin_py_exec . ' "' . g:rplugin_tmpdir . '/getRandomNumber.py"')
        call delete(g:rplugin_tmpdir . "/getRandomNumber.py")
    elseif !has("win32") && !has("win64") && !has("gui_win32") && !has("gui_win64")
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

let g:rplugin_docfile = g:rplugin_tmpdir . "/Rdoc"

" Create an empty file to avoid errors if the user do Ctrl-X Ctrl-O before
" starting R:
if &filetype != "rbrowser"
    call writefile([], g:rplugin_tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
endif

if has("win32") || has("win64")
    runtime R/windows.vim
else
    call SetRPath()
endif
if has("gui_running")
    runtime R/gui_running.vim
endif
if g:R_applescript
    runtime R/osx.vim
endif
runtime R/nvimbuffer.vim

