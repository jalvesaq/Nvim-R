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
    echohl None
endif

" Do this only once
if exists("s:did_global_stuff")
    finish
endif
let s:did_global_stuff = 1

if !exists('g:rplugin')
    let g:rplugin = {}
endif
let g:rplugin.debug_info = {}

"==========================================================================
" Functions that are common to r, rnoweb, rhelp and rdoc
"==========================================================================

function RWarningMsg(wmsg)
    if v:vim_did_enter == 0
        exe 'autocmd VimEnter * call RWarningMsg("' . escape(a:wmsg, '"') . '")'
        return
    endif
    echohl WarningMsg
    echomsg a:wmsg
    echohl None
endfunction

if has("nvim")
    if !has("nvim-0.2.1")
        call RWarningMsg("Nvim-R requires Neovim >= 0.2.1.")
        let g:rplugin.failed = 1
        finish
    endif
elseif v:version < "801"
    call RWarningMsg("Nvim-R requires either Neovim >= 0.2.1 or Vim >= 8.1.")
    let g:rplugin.failed = 1
    finish
elseif !has("channel") || !has("job")
    call RWarningMsg("Nvim-R requires either Neovim >= 0.2.1 or Vim >= 8.1.\nIf using Vim, it must have been compiled with both +channel and +job features.\n")
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
    let rr = []
    " https://github.com/yihui/yihui.name/blob/master/content/knitr/options.md
    " 2017-02-03
    let ktopt = ['eval=TRUE', 'echo=TRUE', 'results="markup|asis|hold|hide"',
                \ 'warning=TRUE', 'error=TRUE', 'message=TRUE', 'split=FALSE',
                \ 'include=TRUE', 'strip.white=TRUE', 'tidy=FALSE',
                \ 'tidy.opts= ', 'prompt=FALSE', 'comment="##"',
                \ 'highlight=TRUE', 'background="#F7F7F7"', 'cache=FALSE',
                \ 'cache.path="cache/"', 'cache.vars= ',
                \ 'cache.lazy=TRUE', 'cache.comments= ', 'cache.rebuild=FALSE',
                \ 'dependson=""', 'autodep=FALSE', 'fig.path= ',
                \ 'fig.keep="high|none|all|first|last"',
                \ 'fig.show="asis|hold|animate|hide"', 'dev= ', 'dev.args= ',
                \ 'fig.ext= ', 'dpi=72', 'fig.width=7', 'fig.height=7',
                \ 'fig.asp= ', 'fig.dim=c(7, 7)', 'out.width="7in"',
                \ 'out.height="7in"', 'out.extra= ', 'resize.width= ',
                \ 'resize.height= ', 'fig.align="left|right|center"',
                \ 'fig.ncol=""', 'fig.sep=""', 'fig.showtext=FALSE',
                \ 'fig.env="figure"', 'fig.cap=""', 'fig.scap=""', 'fig.lp="fig:"',
                \ 'fig.pos=""', 'fig.subcap= ', 'fig.process= ', 'interval=1',
                \ 'aniopts="controls,loop"', 'ffmpeg.bitrate="1M"',
                \ 'ffmpeg.format="webm"', 'code= ', 'ref.label= ', 'child= ',
                \ 'engine="R"', 'engine.path=""', 'opts.label=""', 'purl=TRUE',
                \ "R.options= "]
    if &filetype == 'rnoweb'
        let ktopt += ['external=TRUE', 'sanitize=FALSE', 'size="normalsize"']
    endif
    if &filetype == 'rmd' || &filetype == 'rrst'
        let ktopt += ['fig.retina=1', 'class.output=""', 'class.source=""']
        if &filetype == 'rmd'
            let ktopt += ['collapse=FALSE']
        endif
    endif

    if strlen(a:base) > 0
        let newbase = '^' . substitute(a:base, "\\$$", "", "")
        call filter(ktopt, 'v:val =~ newbase')
    endif

    call sort(ktopt)
    for kopt in ktopt
        let tmp = split(kopt, "=")
        call add(rr, {'word': tmp[0] . '=', 'abbr': tmp[0], 'menu': '= ' . tmp[1]})
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

function FinishArgsCompletion()
    let s:ArgCompletionFinished = 1
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

function IsDirWritable(dir)
    if has("nvim") && has("win32")
        " The Neovim's filewritable() function gives wrong result on Windows:
        " https://github.com/neovim/neovim/issues/9683
        let dw = 0
        try
            if !filereadable(a:dir . '/IsItPossibleToWriteThisFile')
                call writefile(['this is a test'], a:dir . '/IsItPossibleToWriteThisFile')
                if filereadable(a:dir . '/IsItPossibleToWriteThisFile')
                    let dw = 2
                    call delete(a:dir . '/IsItPossibleToWriteThisFile')
                endif
            endif
        catch E482
        endtry
        return dw
    endif
    return filewritable(a:dir)
endfunction

function CheckNvimcomVersion()
    let neednew = 0
    if isdirectory(substitute(s:nvimcom_home, "nvimcom", "", "") . "00LOCK-nvimcom")
        let s:has_warning = 1
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
                let rversion = system(g:rplugin.Rcmd . ' --version')
                let rversion = substitute(rversion, '.*R version \(\S\{-}\) .*', '\1', '')
                let g:rplugin.debug_info['R_version'] = rversion
                if g:rplugin.R_version != rversion
                    let neednew = 1
                endif
            endif
        endif
    endif

    " Nvim-R might have been installed as root in a non writable directory.
    " We have to build nvimcom in a writable directory before installing it.
    if neednew
        exe "cd " . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g')
        if has("win32")
            call SetRHome()
            let cmpldir = substitute(g:rplugin.compldir, '\\', '/', 'g')
        else
            let cmpldir = g:rplugin.compldir
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
                    \ 'sink()',
                    \ 'sink("' . cmpldir . '/path_to_nvimcom")',
                    \ 'cat(.libPaths()[1L],',
                    \ '    unlist(strsplit(Sys.getenv("R_LIBS_USER"), .Platform$path.sep))[1L],',
                    \ '    sep = "\n")',
                    \ 'sink()' ]
        call writefile(rcode, g:rplugin.tmpdir . '/nvimcom_path.R')
        let g:rplugin.debug_info['.libPaths()'] = system(g:rplugin.Rcmd . ' --no-restore --no-save --slave -f "' . g:rplugin.tmpdir . '/nvimcom_path.R"')
        if v:shell_error
            let s:has_warning = 1
            call RWarningMsg(g:rplugin.debug_info['.libPaths()'])
            return 0
        endif
        let libpaths = readfile(g:rplugin.tmpdir . "/libpaths")
        call map(libpaths, 'substitute(expand(v:val), "\\", "/", "g")')
        let g:rplugin.debug_info['libPaths'] = libpaths
        if !(isdirectory(libpaths[0]) && IsDirWritable(libpaths[0]) == 2) && !exists("g:R_remote_tmpdir")
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

        let s:has_warning = 1
        echo "Updating nvimcom... "
        if !exists("g:R_remote_tmpdir")
            let g:rplugin.debug_info['CMD_build'] = system(g:rplugin.Rcmd . ' CMD build "' . g:rplugin.home . '/R/nvimcom"')
        else
            call system('cp -R "' . g:rplugin.home . '/R/nvimcom" .')
            let g:rplugin.debug_info['CMD_build'] = system(g:rplugin.Rcmd . ' CMD build "' . g:R_remote_tmpdir . '/nvimcom"')
            call system('rm -rf "' . g:R_tmpdir . '/nvimcom"')
        endif
        if v:shell_error
            call ShowRSysLog(g:rplugin.debug_info['CMD_build'], "Error_building_nvimcom", "Failed to build nvimcom")
            return 0
        else
            if has("win32")
                call SetRtoolsPath()
                let g:rplugin.debug_info['CMD_INSTALL'] = system(g:rplugin.Rcmd . " CMD INSTALL --no-multiarch nvimcom_" . s:required_nvimcom . ".tar.gz")
                call UnSetRtoolsPath()
            else
                let g:rplugin.debug_info['CMD_INSTALL'] = system(g:rplugin.Rcmd . " CMD INSTALL --no-lock nvimcom_" . s:required_nvimcom . ".tar.gz")
            endif
            if v:shell_error
                if filereadable(expand("~/.R/Makevars"))
                    call ShowRSysLog(g:rplugin.debug_info['CMD_INSTALL'], "Error_installing_nvimcom", "Failed to install nvimcom. Please, check your '~/.R/Makevars'.")
                else
                    call ShowRSysLog(g:rplugin.debug_info['CMD_INSTALL'], "Error_installing_nvimcom", "Failed to install nvimcom")
                endif
                if has("win32")
                    call CheckRtools()
                endif
                call delete("nvimcom_" . s:required_nvimcom . ".tar.gz")
                return 0
            else
                call RSetDefaultPkg()
                echon "Building lists for omni completion... "
                let rdp = $R_DEFAULT_PACKAGES
                if rdp !~ "\<base\>"
                    let rdp .= ",base"
                endif
                let blist = 'nvimcom:::nvim.buildomnils("' . rdp . '")'
                let blist = substitute(blist, ',', '");nvimcom:::nvim.buildomnils("', 'g')
                call writefile(split(blist, ";"), g:rplugin.tmpdir . "/buildomnils.R")
                let g:rplugin.debug_info['Build_Omnils'] = system(g:rplugin.Rcmd .
                            \ ' --quiet --no-save --no-restore -f "' .
                            \ g:rplugin.tmpdir . '/buildomnils.R"')
                if v:shell_error
                    call ShowRSysLog(g:rplugin.debug_info['Build_Omnils'], "Error_building_compl_data", "Failed to build lists")
                    call delete(g:rplugin.tmpdir . "/buildomnils.R")
                    return 0
                endif
                echon "OK!"
                call delete(g:rplugin.tmpdir . "/buildomnils.R")
            endif
        endif
        if has("win32")
            call UnsetRHome()
        endif
        call delete("nvimcom_" . s:required_nvimcom . ".tar.gz")
        silent cd -
    else
        call RSetDefaultPkg()
    endif
    return 1
endfunction

function StartNClientServer(w)
    if IsJobRunning("ClientServer")
        call FinishStartingR()
        return
    endif
    if !filereadable(g:rplugin.compldir . '/path_to_nvimcom')
        return
    endif

    let g:rplugin.debug_info['Start_nclientserver'] = a:w

    if has("win32")
        let nvc = "nclientserver.exe"
        let pathsep = ";"
    else
        let nvc = "nclientserver"
        let pathsep = ":"
    endif

    let nvimcomdir = readfile(g:rplugin.compldir . '/path_to_nvimcom')
    call map(nvimcomdir, 'substitute(expand(v:val), "\\", "/", "g")')

    if g:rplugin.nvimcom_bin_dir == ""
        if exists("g:R_nvimcom_home") && filereadable(g:R_nvimcom_home . '/bin/' . nvc)
            let g:rplugin.nvimcom_bin_dir = g:R_nvimcom_home . '/bin'
        elseif filereadable(nvimcomdir[0] . '/nvimcom/bin/' . nvc)
            let g:rplugin.nvimcom_bin_dir = nvimcomdir[0] . '/nvimcom/bin'
        elseif filereadable(nvimcomdir[1] . '/nvimcom/bin/' . nvc)
            let g:rplugin.nvimcom_bin_dir = nvimcomdir[1] . '/nvimcom/bin'
        elseif filereadable(nvimcomdir[0] . '/nvimcom/bin/x64/' . nvc)
            let g:rplugin.nvimcom_bin_dir = nvimcomdir[0] . '/nvimcom/bin/x64'
        elseif filereadable(nvimcomdir[0] . '/nvimcom/bin/i386/' . nvc)
            let g:rplugin.nvimcom_bin_dir = nvimcomdir[0] . '/nvimcom/bin/i386'
        else
            call RWarningMsg('Application "' . nvc . '" not found.')
            return
        endif
    endif

    if g:rplugin.nvimcom_bin_dir != "" && $PATH !~ g:rplugin.nvimcom_bin_dir
        let $PATH = g:rplugin.nvimcom_bin_dir . pathsep . $PATH
    endif

    if a:w ==# 'StartR' && !s:has_warning
        echon "\rWait..."
    endif
    if $NVIMR_ID == ""
        if has('nvim')
            let randstr = system([nvc, 'random'])
        else
            let randstr = system(nvc . ' random')
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
    let g:rplugin.jobs["ClientServer"] = StartJob([nvc], g:rplugin.job_handlers)
endfunction

" Start R
function StartR(whatr)
    let s:wait_nvimcom = 1

    if !g:R_in_buffer
        let g:R_objbr_place = substitute(g:R_objbr_place, 'console', 'script', '')
    endif

    if !isdirectory(g:rplugin.tmpdir)
        call mkdir(g:rplugin.tmpdir, "p", 0700)
    endif

    " https://github.com/jalvesaq/Nvim-R/issues/157
    if !exists("*FillRLibList")
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/functions.vim"
    endif

    let s:has_warning = 0
    if !CheckNvimcomVersion()
        return
    endif

    let s:what_r = a:whatr
    call StartNClientServer('StartR')
endfunction

function FinishStartingR()
    if s:what_r =~ "custom"
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
    unlet s:what_r

    call writefile([], g:rplugin.tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    call writefile([], g:rplugin.tmpdir . "/globenv_" . $NVIMR_ID)
    call writefile([], g:rplugin.tmpdir . "/liblist_" . $NVIMR_ID)
    call delete(g:rplugin.tmpdir . "/libnames_" . $NVIMR_ID)

    call AddForDeletion(g:rplugin.tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/globenv_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/liblist_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/libnames_" . $NVIMR_ID)
    call AddForDeletion(g:rplugin.tmpdir . "/nvimbol_finished")
    call AddForDeletion(g:rplugin.tmpdir . "/start_options.R")
    if has("win32")
        call AddForDeletion(g:rplugin.tmpdir . "/run_cmd.bat")
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
    if g:R_hi_fun_globenv
        let start_options += ['options(nvimcom.higlobfun = TRUE)']
    else
        let start_options += ['options(nvimcom.higlobfun = FALSE)']
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
    if g:R_in_buffer && g:R_esc_term
        let start_options += ['options(editor = nvimcom:::nvim.edit)']
    endif
    if exists("g:R_csv_delim") && (g:R_csv_delim == "," || g:R_csv_delim == ";")
        let start_options += ['options(nvimcom.delim = "' . g:R_csv_delim. '")']
    else
        let start_options += ['options(nvimcom.delim = "\t")']
    endif
    let start_options += ['options(nvimcom.lsenvtol = ' . g:R_ls_env_tol . ')',
                \ 'options(nvimcom.source.path = "' . s:Rsource_read . '")']

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
    call writefile(start_options, g:rplugin.tmpdir . "/start_options.R")

    call delete(g:rplugin.compldir . "/nvimcom_info")

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

    let args_str = join(g:rplugin.r_args)
    if args_str == ""
        let rcmd = g:rplugin.R
    else
        let rcmd = g:rplugin.R . " " . args_str
    endif

    call StartR_ExternalTerm(rcmd)
endfunction

" Send SIGINT to R
function StopR()
    if s:R_pid
        call system("kill -s SIGINT " . s:R_pid)
    endif
endfunction

function SetSendCmdToR(...)
    if exists("g:RStudio_cmd")
        let g:SendCmdToR = function('SendCmdToRStudio')
    elseif g:R_in_buffer
        let g:SendCmdToR = function('SendCmdToR_Buffer')
    elseif has("win32")
        let g:SendCmdToR = function('SendCmdToR_Windows')
    endif
    if !s:has_warning
        echon "\r       "
    endif
    let s:wait_nvimcom = 0
endfunction

function CheckIfNvimcomIsRunning(...)
    let s:nseconds = s:nseconds - 1
    if g:rplugin.nvimcom_port == 0
        if s:nseconds > 0
            call timer_start(1000, "CheckIfNvimcomIsRunning")
        else
            let s:nvimcom_version = "0"
            let s:nvimcom_home = ""
            let g:rplugin.nvimcom_bin_dir = ""
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
    let s:nvimcom_version = a:nvimcomversion
    if exists("g:R_nvimcom_home")
        let s:nvimcom_home = g:R_nvimcom_home
    else
        let s:nvimcom_home = a:nvimcomhome
    endif
    let g:rplugin.nvimcom_port = a:bindportn
    let s:R_pid = a:rpid
    let $RCONSOLE = a:wid
    if s:nvimcom_version != s:required_nvimcom_dot
        call RWarningMsg('This version of Nvim-R requires nvimcom ' .
                    \ s:required_nvimcom . '.')
        let s:has_warning = 1
        sleep 1
    endif

    let Rinfo = split(a:r_info, "\x02")
    let g:rplugin.R_version = Rinfo[0]
    if !exists("g:R_OutDec")
        let g:R_OutDec = Rinfo[1]
    endif
    let g:Rout_prompt_str = substitute(Rinfo[2], ' $', '', '')
    let g:Rout_continue_str = substitute(Rinfo[3], ' $', '', '')

    if has('nvim') && g:R_in_buffer
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

    if isdirectory(s:nvimcom_home . "/bin/x64")
        let g:rplugin.nvimcom_bin_dir = s:nvimcom_home . "/bin/x64"
    elseif isdirectory(s:nvimcom_home . "/bin/i386")
        let g:rplugin.nvimcom_bin_dir = s:nvimcom_home . "/bin/i386"
    else
        let g:rplugin.nvimcom_bin_dir = s:nvimcom_home . "/bin"
    endif

    call writefile([s:nvimcom_version, s:nvimcom_home,
                \ g:rplugin.nvimcom_bin_dir, g:rplugin.R_version],
                \ g:rplugin.compldir . "/nvimcom_info")

    if IsJobRunning("ClientServer")
        " Set RConsole window ID in nclientserver to ArrangeWindows()
        if has("win32")
            if $RCONSOLE == "0"
                call RWarningMsg("nvimcom did not save R window ID")
                let s:has_warning = 1
            endif
        endif
        " Set nvimcom port in nvimclient
        if has("win32")
            call JobStdin(g:rplugin.jobs["ClientServer"], "\001" . g:rplugin.nvimcom_port . " " . $RCONSOLE . "\n")
        else
            call JobStdin(g:rplugin.jobs["ClientServer"], "\001" . g:rplugin.nvimcom_port . "\n")
        endif
    else
        call RWarningMsg("nvimcom is not running")
        let s:has_warning = 1
    endif

    if exists("g:RStudio_cmd")
        if has("win32") && g:R_arrange_windows && filereadable(g:rplugin.compldir . "/win_pos")
            " ArrangeWindows
            call JobStdin(g:rplugin.jobs["ClientServer"], "\005" . g:rplugin.compldir . "\n")
        endif
    elseif has("win32")
        if g:R_arrange_windows && filereadable(g:rplugin.compldir . "/win_pos")
            " ArrangeWindows
            call JobStdin(g:rplugin.jobs["ClientServer"], "\005" . g:rplugin.compldir . "\n")
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
                sil exe 'aboveleft vsplit ' . b:objbrtitle
            elseif g:R_objbr_place =~# 'below'
                sil exe 'belowright vsplit ' . b:objbrtitle
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
        let g:rplugin.ob_winnr = win_getid()
        if exists("*nvim_win_get_buf")
            let g:rplugin.ob_buf = nvim_win_get_buf(g:rplugin.ob_winnr)
        endif

        " Inheritance of some local variables
        let b:objbrtitle = g:tmp_objbrtitle
        unlet g:tmp_objbrtitle
        call SendToNvimcom("\002" . g:rplugin.myport)
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
    call SendToNvimcom("\007" . a:stt)
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
    call JobStdin(g:rplugin.jobs["ClientServer"], "\002" . a:cmd . "\n")
endfunction

" This function is called by nclientserver
function RSetMyPort(p)
    let g:rplugin.myport = a:p
    let $NVIMR_PORT = a:p
    if exists("s:what_r")
        call FinishStartingR()
    endif
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

    call SendToNvimcom("\x08" . $NVIMR_ID . 'nvimcom:::nvim_format(' . a:firstline . ', ' . a:lastline . ', ' . wco . ')')
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

function FinishRInsert(type)
    if a:type == "newtab"
        tabnew
        set ft=rout
    endif

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
        if g:R_csv_app =~# '^terminal:'
            let csv_app = split(g:R_csv_app, ':')[1]
            if executable(csv_app)
                call system('cp "' . g:rplugin.tmpdir . '/Rinsert" "' . a:oname . '.csv"')
                tabnew
                exe 'terminal ' . csv_app . ' ' . a:oname . '.csv'
                startinsert
            else
                call RWarningMsg('R_csv_app ("' . csv_app . '") is not executable')
            endif
            return
        endif

        if !executable(g:R_csv_app) && !executable(split(g:R_csv_app)[0])
            call RWarningMsg('R_csv_app ("' . g:R_csv_app . '") is not executable')
            return
        endif
        normal! :<Esc>
        call system('cp "' . g:rplugin.tmpdir . '/Rinsert" "' . a:oname . '.csv"')
        if has("win32")
            silent exe '!start "' . g:R_csv_app . '" "' . a:oname . '.csv"'
        else
            call system(g:R_csv_app . ' "' . a:oname . '.csv" >/dev/null 2>/dev/null &')
        endif
        return
    endif
    let location = get(a:, 1, "tabnew")
    echo 'Opening "' . a:oname . '.csv"'
    silent exe location . ' ' . a:oname . '.csv'
    silent 1,$d
    silent exe 'read ' . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') . '/Rinsert'
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
        if rpd < 0
            let line1 = line(".")
            let cline = line1 + 1
            while cline <= line("$")
                let txt = getline(cline)
                if chunkend != "" && txt == chunkend
                    break
                endif
                let rpd += RParenDiff(txt)
                let cline += 1
                if rpd == 0
                    for lnum in range(line1, cline - 1)
                        if g:R_bracketed_paste
                            if lnum == line1 && lnum == cline - 1
                                let ok = g:SendCmdToR("\x1b[200~" . getline(lnum) . "\n\x1b[201~", 0)
                            elseif lnum == line1
                                let ok = g:SendCmdToR("\x1b[200~" . getline(lnum))
                            elseif lnum == cline - 1
                                let ok = g:SendCmdToR(getline(lnum) . "\n\x1b[201~", 0)
                            else
                                let ok = g:SendCmdToR(getline(lnum))
                            endif
                        else
                            let ok = g:SendCmdToR(getline(lnum))
                        end
                        if !ok
                            " always close bracketed mode upon failure
                            if g:R_bracketed_paste
                                call g:SendCmdToR("\x1b[201~", 0)
                            end
                            return
                        endif
                    endfor
                    call cursor(cline - 1, 1)
                    let block = 1
                    break
                endif
            endwhile
        endif
    endif

    if !block
        if g:R_bracketed_paste
            let ok = g:SendCmdToR("\x1b[200~" . line . "\n\x1b[201~", 0)
        else
            let ok = g:SendCmdToR(line)
        end
    endif

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
        call JobStdin(g:rplugin.jobs["ClientServer"], "\006\n")
        sleep 50m
        call JobStdin(g:rplugin.jobs["ClientServer"], "\007\n")
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
    call delete(g:rplugin.tmpdir . "/libnames_" . $NVIMR_ID)
    call delete(g:rplugin.tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    for fn in s:del_list
        call delete(fn)
    endfor
    let g:SendCmdToR = function('SendCmdToR_fake')
    let s:R_pid = 0
    let g:rplugin.nvimcom_port = 0

    " Legacy support for running R in a Tmux split pane
    if exists('g:rplugin.tmux_split') && exists('g:R_tmux_title') && g:rplugin.tmux_split
                \ && g:R_tmux_title != 'automatic' && g:R_tmux_title != ''
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
        call JobStdin(g:rplugin.jobs["ClientServer"], "\004" . $NVIMR_COMPLDIR . "\n")
    endif

    " In Neovim, the cursor must be in the term buffer to get TermClose event
    " triggered
    if g:R_in_buffer && exists("g:rplugin.R_bufname") && has("nvim")
        exe "sbuffer " . g:rplugin.R_bufname
        startinsert
    endif

    if bufloaded(b:objbrtitle)
        exe "bunload! " . b:objbrtitle
        sleep 30m
    endif

    call g:SendCmdToR(qcmd)

    if exists('g:rplugin.tmux_split') || a:how == 'save'
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
    if bufname("%") =~ "Object_Browser" || (exists("g:rplugin.R_bufname") && bufname("%") == g:rplugin.R_bufname)
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

    if exists("g:rplugin.R_bufname") && bufname("%") == g:rplugin.R_bufname
        " Exit Terminal mode and go to Normal mode
        stopinsert
    endif

    " Legacy support for running R in a Tmux split pane.
    " If the help command was triggered in the R Console, jump to Vim pane:
    if exists('g:rplugin.tmux_split') && g:rplugin.tmux_split && !s:running_rhelp
        let slog = system("tmux select-pane -t " . g:rplugin.editor_pane)
        if v:shell_error
            call RWarningMsg(slog)
        endif
    endif
    let s:running_rhelp = 0

    if bufname("%") =~ "Object_Browser" || (exists("g:rplugin.R_bufname") && bufname("%") == g:rplugin.R_bufname)
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
        if a:rcmd == "viewdf"
            if exists("g:R_df_viewer")
                call g:SendCmdToR(printf(g:R_df_viewer, rkeyword))
            else
                if a:0 == 1 && a:1 =~ '^,'
                    let argmnts = a:1
                elseif a:0 == 2 && a:2 =~ '^,'
                    let argmnts = a:2
                else
                    let argmnts = ''
                endif
                echo "Wait..."
                call delete(g:rplugin.tmpdir . "/Rinsert")
                call AddForDeletion(g:rplugin.tmpdir . "/Rinsert")
                if rkeyword =~ '::'
                    call SendToNvimcom("\x08" . $NVIMR_ID .
                                \'nvimcom:::nvim_viewdf(' . rkeyword . argmnts . ')')
                else
                    if has("win32") && &encoding == "utf-8"
                        call SendToNvimcom("\x08" . $NVIMR_ID .
                                    \'nvimcom:::nvim_viewdf("' . rkeyword . '"' . argmnts .
                                    \', fenc="UTF-8"' . ')')
                    else
                        call SendToNvimcom("\x08" . $NVIMR_ID .
                                    \'nvimcom:::nvim_viewdf("' . rkeyword . '"' . argmnts . ')')
                    endif
                endif
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

        if a:0 == 1 && a:1 =~ '^,'
            let argmnts = a:1
        elseif a:0 == 2 && a:2 =~ '^,'
            let argmnts = a:2
        else
            let argmnts = ''
        endif
        let raction = rfun . '(' . rkeyword . argmnts . ')'
        call g:SendCmdToR(raction)
    endif
endfunction

" render a document with rmarkdown
function! RMakeRmd(t)
    if !exists("g:rplugin.pdfviewer")
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
        if hasmapto('<Plug>' . a:plug, "n")
            exec 'noremap <buffer><silent> <Plug>' . a:plug . ' ' . tg
        elseif g:R_user_maps_only == 0
            exec 'noremap <buffer><silent> <LocalLeader>' . a:combo . ' ' . tg
        endif
    endif
    if a:type =~ "v"
        if hasmapto('<Plug>' . a:plug, "v")
            exec 'vnoremap <buffer><silent> <Plug>' . a:plug . ' <Esc>' . tg
        elseif g:R_user_maps_only == 0
            exec 'vnoremap <buffer><silent> <LocalLeader>' . a:combo . ' <Esc>' . tg
        endif
    endif
    if g:R_insert_mode_cmds == 1 && a:type =~ "i"
        if hasmapto('<Plug>' . a:plug, "i")
            exec 'inoremap <buffer><silent> <Plug>' . a:plug . ' <Esc>' . tg . il
        elseif g:R_user_maps_only == 0
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
    call RCreateMaps('ni', 'RViewDF',      'rv', ':call RAction("viewdf")')
    call RCreateMaps('ni', 'RViewDF',      'vs', ':call RAction("viewdf", ", location=''split''")')
    call RCreateMaps('ni', 'RViewDF',      'vv', ':call RAction("viewdf", ", location=''vsplit''")')
    call RCreateMaps('ni', 'RViewDF',      'vh', ':call RAction("viewdf", ", location=''above 7split'', nrows=6")')
    call RCreateMaps('ni', 'RDputObj',     'td', ':call RAction("dputtab")')
    call RCreateMaps('ni', 'RPrintObj',    'tp', ':call RAction("printtab")')

    call RCreateMaps('v', 'RObjectPr',     'rp', ':call RAction("print", "v")')
    call RCreateMaps('v', 'RObjectNames',  'rn', ':call RAction("nvim.names", "v")')
    call RCreateMaps('v', 'RObjectStr',    'rt', ':call RAction("str", "v")')
    call RCreateMaps('v', 'RViewDF',       'rv', ':call RAction("viewdf", "v")')
    call RCreateMaps('v', 'RViewDF',       'vs', ':call RAction("viewdf", "v", ", location=''split''")')
    call RCreateMaps('v', 'RViewDF',       'vv', ':call RAction("viewdf", "v", ", location=''vsplit''")')
    call RCreateMaps('v', 'RViewDF',       'vh', ':call RAction("viewdf", "v", ", location=''above 7split'', nrows=6")')
    call RCreateMaps('v', 'RDputObj',      'td', ':call RAction("dputtab", "v")')
    call RCreateMaps('v', 'RPrintObj',     'tp', ':call RAction("printtab", "v")')

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
    call RCreateMaps('nvi', 'ROpenLists',        'r=', ':call RBrOpenCloseLs(1)')
    call RCreateMaps('nvi', 'RCloseLists',       'r-', ':call RBrOpenCloseLs(0)')

    " Render script with rmarkdown
    "-------------------------------------
    call RCreateMaps('nvi', 'RMakeRmd',    'kr', ':call RMakeRmd("default")')
    call RCreateMaps('nvi', 'RMakePDFK',   'kp', ':call RMakeRmd("pdf_document")')
    call RCreateMaps('nvi', 'RMakePDFKb',  'kl', ':call RMakeRmd("beamer_presentation")')
    call RCreateMaps('nvi', 'RMakeWord',   'kw', ':call RMakeRmd("word_document")')
    call RCreateMaps('nvi', 'RMakeHTML',   'kh', ':call RMakeRmd("html_document")')
    call RCreateMaps('nvi', 'RMakeODT',    'ko', ':call RMakeRmd("odt_document")')
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
    exe "sb " . g:rplugin.curbuf
    let &splitright = splr
    exe "set switchbuf=" . savesb
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
    if g:R_args_in_stline
        autocmd InsertCharPre * call RSetStatusLine()
        autocmd InsertLeave * call RestoreStatusLine(1)
    endif

    if !hasmapto("<Plug>RCompleteArgs", "i")
        inoremap <buffer><silent> <C-X><C-A> <C-R>=RCompleteArgs()<CR>
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
    call RCreateMaps('ni0', 'RDSendLineAndInsertOutput', 'o', ':call SendLineToRAndInsertOutput()')
    call RCreateMaps('v',   'RDSendLineAndInsertOutput', 'o', ':call RWarningMsg("This command does not work over a selection of lines.")')
    call RCreateMaps('i',   'RSendLAndOpenNewOne', 'q', ':call SendLineToR("newline")')
    call RCreateMaps('ni.', 'RSendMotion', 'm', ':set opfunc=SendMotionToR<CR>g@')
    call RCreateMaps('n',   'RNLeftPart', 'r<left>', ':call RSendPartOfLine("left", 0)')
    call RCreateMaps('n',   'RNRightPart', 'r<right>', ':call RSendPartOfLine("right", 0)')
    call RCreateMaps('i',   'RILeftPart', 'r<left>', 'l:call RSendPartOfLine("left", 1)')
    call RCreateMaps('i',   'RIRightPart', 'r<right>', 'l:call RSendPartOfLine("right", 1)')
    if &filetype == "r"
        call RCreateMaps('n', 'RSendAboveLines',  'su', ':call SendAboveLinesToR()')
    endif
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
                if exists('*chanclose')
                    call chanclose(g:rplugin.jobs[job])
                else
                    call jobstop(g:rplugin.jobs[job])
                endif
            endif
        endfor
    endif
    " give some time to get the jobs closed
    sleep 20m

    for fn in s:del_list
        call delete(fn)
    endfor
    if executable("rmdir")
        call system("rmdir '" . g:rplugin.tmpdir . "'")
    endif
endfunction

let s:nglobfun = 0
function CheckRGlobalEnv()
    if g:R_hi_fun_globenv == 0
        return
    endif
    if !filereadable(g:rplugin.tmpdir . '/GlobalEnvList_' . $NVIMR_ID)
        return
    endif
    let s:globalenv_lines = readfile(g:rplugin.tmpdir . '/GlobalEnvList_' . $NVIMR_ID)
    let funlist = filter(copy(s:globalenv_lines), 'v:val =~# "\x06function\x06function\x06"')

    if g:R_hi_fun_globenv == 2 && (s:nglobfun || len(funlist))
        " Completely redo the syntax highlight of .GlobalEnv functions
        syntax clear rGlobEnvFun
        let s:nglobfun = len(funlist)
    endif

    if len(funlist)
        " Highlight functions that were not highlighted yet
        call map(funlist, 'substitute(v:val, "\x06.*", "", "")')
        let hifunlist = filter(split(execute("syntax"), "\n"), 'v:val =~# "rGlobEnvFun"')
        let hifunlist = map(hifunlist, 'substitute(v:val, ".* ", "", "")')
        for globf in funlist
            let found = 0
            for hf in hifunlist
                if globf ==# hf
                    let found = 1
                    break
                endif
            endfor
            if !found
                if !exists('g:R_hi_fun_paren') || g:R_hi_fun_paren == 0
                    exe 'syntax keyword rGlobEnvFun ' . globf
                else
                    exe 'syntax match rGlobEnvFun /\<' . globf . '\s*\ze(/'
                endif
            endif
        endfor
    endif
endfunction

function FinishBuildROmniList()
    let s:NvimbolFinished = 1
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

    let s:NvimbolFinished = 0
    call delete(g:rplugin.tmpdir . "/nvimbol_finished")
    call AddForDeletion(g:rplugin.tmpdir . "/nvimbol_finished")

    call SendToNvimcom("\x08" . $NVIMR_ID . omnilistcmd)

    if g:rplugin.nvimcom_port == 0
        sleep 500m
        return
    endif

    " We can't return from this function and wait for a message from nvimcom
    " because omni completion in Vim/Neovim requires the list of completions
    " as the return value of the 'omnifunc'.
    sleep 10m
    let ii = 0
    let max_ii = 100 * g:R_wait_reply
    while s:NvimbolFinished == 0 && ii < max_ii
        let ii += 1
        sleep 10m
    endwhile
    if ii == max_ii
        call RWarningMsg("No longer waiting...")
        return
    endif

    if string(g:SendCmdToR) == "function('SendCmdToR_fake')"
        let s:globalenv_lines = []
    else
        let s:globalenv_lines = readfile(g:rplugin.tmpdir . "/GlobalEnvList_" . $NVIMR_ID)
    endif
endfunction

function RFillOmniMenu(base, newbase, prefix, pkg, olines, toplev)
    let resp = []
    let newlist = filter(copy(a:olines), 'v:val =~ a:newbase')
    for line in newlist
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

        let tmp = split(sln[4], "\x08")
        if len(tmp) == 2
            let descr = substitute(tmp[1], '\\N', "\n", "g") . "\n"
        else
            let descr = ""
        endif
        let ttl = "] " . substitute(descr, "\x05.*", "", "")

        if g:R_show_args && len(sln) > 4
            if tmp[0] =~ '""'
                let tmp[0] = substitute(tmp[0], '"""', '"\\""', 'g')
                let tmp[0] = substitute(tmp[0], "\"\"'\"", "\"\\\\\"'\"", 'g')
            endif
            let tmp[0] = substitute(tmp[0], "NO_ARGS", "", "")
            let tmp[0] = substitute(tmp[0], "\x07", " = ", "g")
            let descr = "Description: " . substitute(descr, ".*\x05", "", "")
            if has("win32")
                " curly single quote in UTF-8
                let descr = substitute(descr, "\x91", "\xe2\x80\x98", "g")
                let descr = substitute(descr, "\x92", "\xe2\x80\x99", "g")
            endif
            if descr ==# 'Description: '
                let descr = ''
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
            call add(resp, {'word': a:prefix . sln[0], 'menu': sln[1] . ' [' . sln[3] . ttl, 'info': descr . usage})
        elseif len(sln) > 3
            call add(resp, {'word': a:prefix . sln[0], 'menu': sln[1] . ' [' . sln[3] . ttl})
        endif
    endfor
    return resp
endfunction

function RGetNewBase(base)
    if a:base =~ ":::"
        return ["", "", ""]
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
    return [newbase, prefix, pkg]
endfunction

function GetRCompletion(base)
    let resp = []

    if strlen(a:base) == 0
        return resp
    endif

    if len(g:rplugin_omni_lines) == 0
        call add(resp, {'word': a:base, 'menu': " [ List is empty. Was nvimcom library ever loaded? ]"})
    endif

    let baseinfo = RGetNewBase(a:base)
    let newbase = baseinfo[0]
    let prefix = baseinfo[1]
    let pkg = baseinfo[2]

    if newbase == ""
        return resp
    endif

    if pkg == ""
        call BuildROmniList(a:base)
        let resp = RFillOmniMenu(a:base, newbase, prefix, pkg, s:globalenv_lines, [])
        if filereadable(g:rplugin.tmpdir . "/nvimbol_finished")
            let toplev = readfile(g:rplugin.tmpdir . "/nvimbol_finished")
        else
            let toplev = []
        endif
        let resp += RFillOmniMenu(a:base, newbase, prefix, pkg, g:rplugin_omni_lines, toplev)
    else
        let omf = split(globpath(g:rplugin.compldir, 'omnils_' . pkg . '_*'), "\n")
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
endfunction

function GetRArgs0(base, rkeyword)
    " If R isn't running, use the prebuilt list of objects
    let argls = []
    let flines = g:rplugin_omni_lines + s:globalenv_lines
    call filter(flines, 'v:val =~ a:rkeyword && v:val =~ "\x06function\x06function\x06"')
    for omniL in flines
        let tmp1 = split(omniL, "\x06")
        if len(tmp1) < 5
            return []
        endif
        let info = tmp1[4]
        let info = substitute(info, "\x08.*", "", "")
        let argsL = split(info, "\x09")
        for id in range(len(argsL))
            let newkey = '^' . a:base
            let tmp2 = split(argsL[id], "\x07")
            if a:base == '' || tmp2[0] =~ newkey
                if tmp2[0] == '...'
                    let bv = "..."
                    let wd = ""
                    let mn = ""
                elseif tmp2[0] == "NO_ARGS"
                    let wd = ""
                    let bv = "No arguments"
                    let mn = ""
                else
                    let wd = tmp2[0] . " = "
                    let bv = tmp2[0]
                    if len(tmp2) == 2
                        let mn = "= " . tmp2[1]
                    else
                        let mn = "="
                    endif
                endif
                call add(argls, {'word': wd, 'abbr': bv, 'menu': mn})
            endif
        endfor
    endfor
    return argls
endfunction

function GetRArgs1(base, rkeyword0, firstobj, pkg)
    let msg = 'nvimcom:::nvim_complete_args("' . a:rkeyword0 . '", "' . a:base . '"'
    if a:firstobj != ""
        let msg .= ', firstobj = "' . a:firstobj . '"'
    elseif a:pkg != ""
        let msg .= ', pkg = ' . a:pkg
    endif
    if g:R_show_arg_help
        let msg .= ', extrainfo = TRUE'
    endif
    let msg .= ')'
    let s:ArgCompletionFinished = 0
    call AddForDeletion(g:rplugin.tmpdir . "/args_for_completion")
    call SendToNvimcom("\x08" . $NVIMR_ID . msg)

    let ii = 200
    while ii > 0 && s:ArgCompletionFinished == 0
        let ii = ii - 1
        sleep 30m
    endwhile

    if s:ArgCompletionFinished == 0 && ii == 0
        return []
    endif

    let args_line = readfile(g:rplugin.tmpdir . "/args_for_completion")[0]
    call delete(g:rplugin.tmpdir . "/args_for_completion")
    let argls = []
    if args_line[0] == "\x04" &&
                \ len(split(args_line, "\x04")) == 1 ||
                \ args_line == ""
        return []
    endif
    let tmp0 = split(args_line, "\x04")
    let tmp = split(tmp0[0], "\x09")
    if(len(tmp) > 0)
        for id in range(len(tmp))
            let tmp1 = split(tmp[id], "\x08")
            if len(tmp1) > 1
                let info = substitute(tmp1[1], "\\\\N", "\n", "g")
            else
                let info = " "
            endif
            let tmp2 = split(tmp1[0], "\x07")
            if tmp2[0] == '...'
                let wd = ""
                let bv = "..."
                let mn = ""
            elseif tmp2[0] == "NO_ARGS"
                let wd = ""
                let bv = "No arguments"
                let mn = ""
            else
                let wd = tmp2[0] . " = "
                let bv = tmp2[0]
                if len(tmp2) > 1
                    let mn = "= " . tmp2[1]
                else
                    let mn = "="
                endif
            endif
            if g:R_show_arg_help
                call add(argls,  {'word': wd, 'abbr': bv, 'menu': mn, 'info': info})
            else
                call add(argls,  {'word': wd, 'abbr': bv, 'menu': mn})
            endif
        endfor
        if len(argls) > 0 && len(tmp0) > 1
            call add(argls, {'word': '', 'abbr': ' ', 'menu': tmp0[1]})
        endif
    endif
    return argls
endfunction

function GetListOfRLibs(base)
    let argls = []
    if filereadable(g:rplugin.compldir . "/pack_descriptions")
        let pd = readfile(g:rplugin.compldir . "/pack_descriptions")
        call filter(pd, 'v:val =~ "^" . a:base')
        for line in pd
            let tmp = split(line, "\x09")
            call add(argls, {'word': tmp[0], 'menu': tmp[1], 'info': "Description: " . tmp[2]})
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

function CompleteR(findstart, base)
    if a:findstart
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
                let rkeyword = '^' . rkeyword0 . "\x06"
                call cursor(cpos[1], cpos[2])

                if (rkeyword0 == "library" || rkeyword0 == "require") && IsFirstRArg(lnum, cpos)
                    let argls = GetListOfRLibs(a:base)
                    if len(argls)
                        let s:is_completing = 1
                        return argls
                    endif
                endif

                " If R is running, use it
                if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
                    let argls = GetRArgs1(a:base, rkeyword0, firstobj, pkg)
                else
                    let argls = GetRArgs0(a:base, rkeyword)
                endif
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
        if g:R_complete == 2 || len(argls) == 0
            let argls += GetRCompletion(s:argkey)
        endif
        let s:is_completing = 1
        return argls
    endif
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

command -nargs=1 -complete=customlist,RLisObjs Rinsert :call RInsert(<q-args>, "default")
command -range=% Rformat <line1>,<line2>:call RFormatCode()
command RBuildTags :call RBuildTags()
command -nargs=? -complete=customlist,RLisObjs Rhelp :call RAskHelp(<q-args>)
command -nargs=? -complete=dir RSourceDir :call RSourceDirectory(<q-args>)
command RStop :call StopR()
command -nargs=? RSend :call g:SendCmdToR(<q-args>)
command RDebugInfo :call ShowRDebugInfo()


"==========================================================================
" Global variables
" Convention: R_        for user options
"             rplugin_  for internal parameters
"==========================================================================

if !exists("g:rplugin.compldir")
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
        elseif isdirectory("/tmp")
            let g:rplugin.tmpdir = "/tmp/Nvim-R-" . g:rplugin.userlogin
        else
            let g:rplugin.tmpdir = g:rplugin.uservimfiles . "/R/tmp"
        endif
    endif
endif

" For compatibility with ncm-R:
let g:rplugin_tmpdir = g:rplugin.tmpdir

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
let g:R_complete          = get(g:, "R_complete",           1)
let g:R_rmhidden          = get(g:, "R_rmhidden",           0)
let g:R_assign            = get(g:, "R_assign",             1)
let g:R_assign_map        = get(g:, "R_assign_map",       "_")
let g:R_paragraph_begin   = get(g:, "R_paragraph_begin",    1)
let g:R_strict_rst        = get(g:, "R_strict_rst",         1)
let g:R_synctex           = get(g:, "R_synctex",            1)
let g:R_non_r_compl       = get(g:, "R_non_r_compl",        1)
let g:R_nvim_wd           = get(g:, "R_nvim_wd",            0)
let g:R_commented_lines   = get(g:, "R_commented_lines",    0)
let g:R_after_start       = get(g:, "R_after_start",       [])
let g:R_after_ob_open     = get(g:, "R_after_ob_open",     [])
let g:R_csv_warn          = get(g:, "R_csv_warn",           1)
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
let g:R_objbr_labelerr    = get(g:, "R_objbr_labelerr",     1)
let g:R_applescript       = get(g:, "R_applescript",        0)
let g:R_esc_term          = get(g:, "R_esc_term",           1)
let g:R_close_term        = get(g:, "R_close_term",         1)
let g:R_buffer_opts       = get(g:, "R_buffer_opts", "winfixwidth nobuflisted")
let g:R_wait              = get(g:, "R_wait",              60)
let g:R_wait_reply        = get(g:, "R_wait_reply",         2)
let g:R_show_args         = get(g:, "R_show_args",          1)
let g:R_show_arg_help     = get(g:, "R_show_arg_help",      1)
let g:R_never_unmake_menu = get(g:, "R_never_unmake_menu",  0)
let g:R_insert_mode_cmds  = get(g:, "R_insert_mode_cmds",   0)
let g:R_disable_cmds      = get(g:, "R_disable_cmds",    [''])
let g:R_in_buffer         = get(g:, "R_in_buffer",          1)
let g:R_open_example      = get(g:, "R_open_example",       1)
let g:R_openhtml          = get(g:, "R_openhtml",           1)
let g:R_hi_fun            = get(g:, "R_hi_fun",             1)
let g:R_hi_fun_paren      = get(g:, "R_hi_fun_paren",       0)
let g:R_hi_fun_globenv    = get(g:, "R_hi_fun_globenv",     0)
let g:R_ls_env_tol        = get(g:, "R_ls_env_tol",       500)
let g:R_args_in_stline    = get(g:, "R_args_in_stline",     0)
let g:R_bracketed_paste   = get(g:, "R_bracketed_paste",    0)
let g:R_sttline_fmt       = get(g:, "R_sttline_fmt", "%fun(%args)")
if exists(":terminal") != 2
    let g:R_in_buffer = 0
endif
if !has("nvim") && !exists("*term_start")
    " exists(':terminal') return 2 even when Vim does not have the +terminal feature
    let g:R_in_buffer = 0
endif

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

if has('win32') && !g:R_in_buffer
    " Sending multiple lines at once to Rgui on Windows does not work.
    let g:R_parenblock = get(g:, 'R_parenblock',         0)
else
    let g:R_parenblock = get(g:, 'R_parenblock',         1)
endif

if g:R_in_buffer
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

if g:R_complete != 1 && g:R_complete != 2
    let R_complete = 1
    call RWarningMsg("Valid values for 'R_complete' are 1 and 2. Please, fix your vimrc.")
endif

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

if g:R_hi_fun == 0 || (exists("g:r_syntax_fun_pattern") && g:r_syntax_fun_pattern == 1)
    let g:R_hi_fun_globenv = 0
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
if !exists("g:rplugin.hasmenu")
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

" Syntax highlighting for preview window of omni completion
let s:is_completing = 0
function RCompleteSyntax()
    if &previewwindow && s:is_completing
        let s:is_completing = 0
        set encoding=utf-8
        syntax clear
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/syntax/rdoc.vim"
        syn match rdocArg2 "^\s*\([A-Z]\|[a-z]\|[0-9]\|\.\|_\)\{-}\ze:"
        syn match rdocTitle2 '^Description: '
        syn region rdocUsage matchgroup=rdocTitle start="^Usage: " matchgroup=NONE end='\t$' contains=@rdocR
        hi def link rdocArg2 Special
        hi def link rdocTitle2 Title
    endif
endfunction
if &completeopt =~ "preview"
    autocmd! BufWinEnter * call RCompleteSyntax()
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

let s:filelines = readfile(g:rplugin.home . "/R/nvimcom/DESCRIPTION")
let s:required_nvimcom = substitute(s:filelines[1], "Version: ", "", "")
let s:required_nvimcom_dot = substitute(s:required_nvimcom, "-", ".", "")
unlet s:filelines

let s:nvimcom_version = "0"
let s:nvimcom_home = ""
let g:rplugin.nvimcom_bin_dir = ""
let g:rplugin.R_version = "0"
if filereadable(g:rplugin.compldir . "/nvimcom_info")
    let s:filelines = readfile(g:rplugin.compldir . "/nvimcom_info")
    if len(s:filelines) == 4
        if isdirectory(s:filelines[1]) && isdirectory(s:filelines[2])
            let s:nvimcom_version = s:filelines[0]
            let s:nvimcom_home = s:filelines[1]
            if has("win32")
                let s:nvc = "nclientserver.exe"
            else
                let s:nvc = "nclientserver"
            endif
            if filereadable(s:filelines[2] . '/' . s:nvc)
                let g:rplugin.nvimcom_bin_dir = s:filelines[2]
            endif
            unlet s:nvc
            let g:rplugin.R_version = s:filelines[3]
        endif
    endif
    unlet s:filelines
endif
if exists("g:R_nvimcom_home")
    let s:nvimcom_home = g:R_nvimcom_home
endif

if has("nvim")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/nvimrcom.vim"
else
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/vimrcom.vim"
endif

" SyncTeX options
let g:rplugin.has_wmctrl = 0

let s:docfile = g:rplugin.tmpdir . "/Rdoc"

" List of files to be deleted on VimLeave
let s:del_list = [s:Rsource_write]

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
        if g:R_in_buffer
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

" Add R directory to the $PATH
if exists("g:R_path")
    let g:rplugin.R_path = expand(g:R_path)
    if !isdirectory(g:rplugin.R_path)
        call RWarningMsg('"' . g:R_path . '" is not a directory. Fix the value of R_path in your vimrc.')
        let g:rplugin.failed = 1
        finish
    endif
    if $PATH !~ g:rplugin.R_path
        if has("win32")
            let $PATH = g:rplugin.R_path . ';' . $PATH
        else
            let $PATH = g:rplugin.R_path . ':' . $PATH
        endif
    endif
    if !executable(g:rplugin.R)
        call RWarningMsg('"' . g:rplugin.R . '" not found. Fix the value of either R_path or R_app in your vimrc.')
        let g:rplugin.failed = 1
        finish
    endif
endif

if exists("g:RStudio_cmd")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/rstudio.vim"
endif

if has("win32")
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/windows.vim"
endif

if g:R_applescript
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/osx.vim"
endif

if (exists('g:R_source') && g:R_source =~# 'tmux_split.vim') || (!has("win32") && !g:R_applescript && !g:R_in_buffer)
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/tmux.vim"
endif

if g:R_in_buffer
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

" Check if r-plugin/functions.vim exist
let s:ff = split(globpath(&rtp, "r-plugin/functions.vim"), " ", "\n")
" Check if other Vim-R-plugin files are installed
let s:ft = split(globpath(&rtp, "ftplugin/r*_rplugin.vim"), " ", "\n")
if len(s:ff) > 0 || len(s:ft) > 0
    call RWarningMsg("It seems that Vim-R-plugin is installed.\n" .
                \ "Please, completely uninstall it before using Nvim-R.\n" .
                \ "Below is a list of what looks like Vim-R-plugin files:\n" . join(s:ff, "\n") . "\n" . join(s:ft) . "\n")
endif

" Check if there is more than one copy of Nvim-R
" (e.g. from the Vimballl and from a plugin manager)
let s:ff = split(substitute(globpath(&rtp, "R/functions.vim"), "functions.vim", "", "g"), "\n")
let s:ft = split(globpath(&rtp, "ftplugin/r*_nvimr.vim"), "\n")
if len(s:ff) > 1 || len(s:ft) > 5
    call RWarningMsg("It seems that Nvim-R is installed in more than one place.\n" .
                \ "Please, remove one of them to avoid conflicts.\n" .
                \ "Below is a list of some of the possibly duplicated directories and files:\n" . join(s:ff, "\n") . "\n" . join(s:ft, "\n") . "\n")
endif
unlet s:ff
unlet s:ft

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

" 2017-12-06
if exists("g:R_term") && g:R_term == "terminator"
    call RWarningMsg('"terminator" is no longer supported. Please, choose another value for R_term.')
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
