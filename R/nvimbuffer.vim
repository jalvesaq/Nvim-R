" This file contains code used only by Neovim

" For debugging
let g:lastjobdata = []

function GetRActivity()
    if v:job_data[1] == 'stdout' || v:job_data[1] == 'stderr'
        let g:lastjobdata += [v:job_data[2]]
        let edbuf = bufname("%")
        if edbuf == "R_Output"
            let isrout = 1
        else
            let isrout = 0
            sbuffer R_Output
        endif

        " Newline at the beginning disappears after split(). Put it now:
        if v:job_data[2] =~ "^\x0a"
            " Prefix ': '  for syntax highlight
            if v:job_data[1] == 'stderr'
                call append("$", ": ")
            else
                call append("$", "")
            endif
            let g:rplugin_last_r_prompt = ""
        endif

        " Fix DOS end of line
        let outstr = substitute(v:job_data[2], "\x0d\x0a", "\x0a", "g")

        let outlst = split(outstr, '\n')

        let lastline = len(outlst) - 1
        " Newline at the end disappears after split()
        if v:job_data[2] =~ '\n$'
            let g:rplugin_last_r_prompt = ""
            let hasnl = 1
        else
            let g:rplugin_last_r_prompt = substitute(outlst[-1], ' *$', '', '')
            let hasnl = 0
        endif

        for idx in range(len(outlst))
            let lin = outlst[idx]
            " Do carriage return
            if lin =~ "\x0d"
                let lin = substitute(lin, ".*\x0d", "", "g")
                call setline("$", "")
            endif

            " Append characters to current last line
            call setline("$", getline("$") . lin)

            " Add new line
            if idx != lastline
                if v:job_data[1] == 'stderr'
                    call append("$", ": ")
                else
                    call append("$", "")
                endif
            endif
        endfor

        " Add final newline
        if hasnl
            call append("$", "")
        endif

        call cursor("$", 999)
        if !isrout
            exe "sbuffer " . edbuf
        endif
    else
        let g:rplugin_rjob = 0
        let g:rplugin_r_pid = 0
        let g:SendCmdToR = function('SendCmdToR_fake')
        if bufname("%") == "R_Output"
            call append("$", ':    ---  R Finished  ---')
            call append("$", "")
            sleep 500m
            quit
        endif
        if mode() == "n"
            call RWarningMsg("R finished")
        endif
    endif
endfunction

function CompleteFromHistory()
    if line(".") != line("$")
        return
    endif

    let key = substitute(getline("."), '^>', '', '')
    let key = substitute(key, '^ ', '', '')
    let key = substitute(key, '^\s*\(.*\)\s*', '\1', '')
    let histlin = [key]
    call setline(".", "> ")
    for lin in g:rplugin_rhistory
        if lin =~ key
            let histlin += [lin]
        endif
    endfor
    call complete(3, histlin)
    return ''
endfunction

function ShowRhistory()
    tabnew R_history
    call setline(".", g:rplugin_rhistory)
    set ft=r
endfunction

function AddToRHistory(rcmd)
    let g:rplugin_rhist_pos += 1
    let g:rplugin_dyn_rhist_pos = g:rplugin_rhist_pos
    let g:rplugin_rhistory += [a:rcmd]
endfunction

function SendCmdToR_Neovim(...)
    let curbuf = bufname("%")
    sbuffer R_Output
    if winwidth(0) != b:winwidth
        let b:winwidth = winwidth(0)
        call SendToNvimcom("\x08" . $NVIMR_ID . "options(width=" . b:winwidth . ")")
    endif
    if a:0 == 1
        call setline("$", getline("$") . a:1)
    endif
    call append("$", "")
    call cursor("$", 1)
    let g:rplugin_addedtohist = 0
    if a:1 !~ '^base::source('
        call AddToRHistory(a:1)
    endif
    exe "sbuffer " . curbuf
    let ok = jobsend(g:rplugin_rjob, a:1 . "\n")
    return ok
endfunction

function RConsoleArrow(dir)
    if line(".") != line("$")
        return
    endif

    " Check if current last typed line of R_Output is already in history
    if g:rplugin_addedtohist == 0
        let lin = substitute(getline("."), '^>', '', '')
        let lin = substitute(lin, '^ ', '', '')
        call AddToRHistory(lin)
        let g:rplugin_addedtohist = 1
    endif

    if a:dir == "down"
        let g:rplugin_dyn_rhist_pos += 1
        if g:rplugin_dyn_rhist_pos > g:rplugin_rhist_pos
            let g:rplugin_dyn_rhist_pos -= 1
            return
        endif
    else
        let g:rplugin_dyn_rhist_pos -= 1
        if g:rplugin_dyn_rhist_pos < 0
            let g:rplugin_dyn_rhist_pos = 0
            return
        endif
    endif
    call setline(".", "> " . g:rplugin_rhistory[g:rplugin_dyn_rhist_pos])
endfunction

function EnterRCmd()
    if line(".") != line("$")
        call append(".", "")
        call cursor(line(".")+1, 1)
        return
    endif
    " First delete the last received prompt:
    let lin = substitute(getline("."), '^' . g:rplugin_last_r_prompt, '', '')
    " Now delete one space in the beginning, if there is any:
    let lin = substitute(lin, '^ ', '', '')
    call SendCmdToR_Neovim(lin, 0)
endfunction

function StartR_Neovim()
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        return
    endif
    let g:rplugin_do_tmux_split = 0

    let g:SendCmdToR = function('SendCmdToR_Neovim')

    let edbuf = bufname("%")
    let g:tmp_objbrtitle = b:objbrtitle
    let g:tmp_curbufname = bufname("%")
    set switchbuf=useopen
    if g:R_vsplit
        if g:R_rconsole_width > 16 && g:R_rconsole_width < (winwidth(0) - 16)
            silent exe "belowright " . g:R_rconsole_width . "vsplit R_Output"
        else
            silent belowright vsplit R_Output
        endif
    else
        if g:R_rconsole_height > 6 && g:R_rconsole_height < (winheight(0) - 6)
            silent exe "belowright " . g:R_rconsole_height . "split R_Output"
        else
            silent belowright split R_Output
        endif
    endif
    let b:winwidth = 0
    set filetype=rout
    setlocal noswapfile
    setlocal bufhidden=hide
    setlocal formatoptions=
    set buftype=nofile
    set omnifunc=CompleteR
    if hasmapto("<Plug>RCompleteArgs", "i")
        imap <buffer><silent> <Plug>RCompleteArgs <C-R>=RCompleteArgs()<CR>
    else
        imap <buffer><silent> <C-X><C-A> <C-R>=RCompleteArgs()<CR>
    endif
    let b:objbrtitle = g:tmp_objbrtitle
    let b:rscript_buffer = g:tmp_curbufname
    unlet g:tmp_objbrtitle
    unlet g:tmp_curbufname
    imap <buffer> <CR> <Esc>:call EnterRCmd()<CR>A
    imap <buffer> <C-C> <Esc>:RStop<CR>a
    imap <buffer> <Up> <Esc>:call RConsoleArrow("up")<CR>A
    imap <buffer> <Down> <Esc>:call RConsoleArrow("down")<CR>A
    imap <buffer><silent> <C-H> <C-R>=CompleteFromHistory()<CR>
    call cursor("$", 1)
    exe "sbuffer " . edbuf

    nmap <LocalLeader><LocalLeader> :call OpenRScratch()<CR>

    let savedterm = $TERM
    let $TERM="NeovimTerm"
    let rargs = b:rplugin_r_args + ['--no-readline', '--interactive']
    let g:rplugin_rjob = jobstart("Rjob", 'R', rargs, 'su')
    exe 'let $TERM="' . savedterm . '"'
    call WaitNvimcomStart()
endfunction

