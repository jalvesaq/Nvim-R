" This file contains code used only when R run in a Neovim buffer

let g:R_auto_scroll = get(g:, 'R_auto_scroll', 1)

function SendCmdToR_Buffer(...)
    if g:rplugin.jobs["R"]
        if g:R_clear_line
            if g:R_editing_mode == "emacs"
                let cmd = "\001\013" . a:1
            else
                let cmd = "\x1b0Da" . a:1
            endif
        else
            let cmd = a:1
        endif

        " Update the width, if necessary
        try
            let bwid = bufwinid(g:rplugin.R_bufnr)
        catch /.*/
            let bwid = -1
        endtry
        if g:R_setwidth != 0 && g:R_setwidth != 2 && bwid != -1
            let rwnwdth = winwidth(bwid)
            if rwnwdth != s:R_width && rwnwdth != -1 && rwnwdth > 10 && rwnwdth < 999
                let s:R_width = rwnwdth
                let Rwidth = s:R_width + s:number_col
                if has("win32")
                    let cmd = "options(width=" . Rwidth . "); ". cmd
                else
                    call SendToNvimcom("E", "options(width=" . Rwidth . ")")
                    sleep 10m
                endif
            endif
        endif

        if g:R_auto_scroll && cmd !~ '^quit(' && bwid != -1
            call nvim_win_set_cursor(bwid, [nvim_buf_line_count(nvim_win_get_buf(bwid)), 0])
        endif

        if !(a:0 == 2 && a:2 == 0)
            let cmd = cmd . "\n"
        endif
        call chansend(g:rplugin.jobs["R"], cmd)
        return 1
    else
        call RWarningMsg("Is R running?")
        return 0
    endif
endfunction

function CloseRTerm()
    if has_key(g:rplugin, "R_bufnr")
        try
            " R migh have been killed by closing the terminal buffer with the :q command
            exe "sbuffer " . g:rplugin.R_bufnr
        catch /E94/
        endtry
        if g:R_close_term && g:rplugin.R_bufnr == bufnr("%")
            startinsert
            call feedkeys(' ')
        endif
        unlet g:rplugin.R_bufnr
    endif
endfunction

function SplitWindowToR()
    if g:R_rconsole_width > 0 && winwidth(0) > (g:R_rconsole_width + g:R_min_editor_width + 1 + (&number * &numberwidth))
        if g:R_rconsole_width > 16 && g:R_rconsole_width < (winwidth(0) - 17)
            silent exe "belowright " . g:R_rconsole_width . "vnew"
        else
            silent belowright vnew
        endif
    else
        if g:R_rconsole_height > 0 && g:R_rconsole_height < (winheight(0) - 1)
            silent exe "belowright " . g:R_rconsole_height . "new"
        else
            silent belowright new
        endif
    endif
endfunction

function ReOpenRWin()
    let wlist = nvim_list_wins()
    for wnr in wlist
        if nvim_win_get_buf(wnr) == g:rplugin.R_bufnr
            " The R buffer is visible
            return
        endif
    endfor
    let edbuf = bufname("%")
    call SplitWindowToR()
    call nvim_win_set_buf(0, g:rplugin.R_bufnr)
    exe "sbuffer " . edbuf
endfunction

function StartR_InBuffer()
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        call ReOpenRWin()
        return
    endif

    let g:SendCmdToR = function('SendCmdToR_NotYet')

    let edbuf = bufname("%")
    set switchbuf=useopen

    call SplitWindowToR()

    if has("win32")
        call SetRHome()
    endif
    let g:rplugin.jobs["R"] = termopen(g:rplugin.R . " " . join(g:rplugin.r_args), {'on_exit': function('ROnJobExit')})
    if has("win32")
        redraw
        call UnsetRHome()
    endif
    let g:rplugin.R_bufnr = bufnr("%")
    if exists("g:R_hl_term") && g:R_hl_term
        silent set syntax=rout
    endif
    if g:R_esc_term
        tnoremap <buffer> <Esc> <C-\><C-n>
    endif
    for optn in split(g:R_buffer_opts)
        exe 'setlocal ' . optn
    endfor

    let s:R_width = 0
    if &number
        if g:R_setwidth < 0 && g:R_setwidth > -17
            let s:number_col = g:R_setwidth
        else
            let s:number_col = -6
        endif
    else
        let s:number_col = 0
    endif

    " Set b:pdf_is_open to avoid error when the user has to go to R Console to
    " deal with latex errors while compiling the pdf
    let b:pdf_is_open = 1
    exe "sbuffer " . edbuf
    stopinsert
    call WaitNvimcomStart()
endfunction

let g:R_setwidth = get(g:, 'R_setwidth', 1)

if has("win32")
    " The R package colorout only works on Unix systems
    let g:R_hl_term = get(g:, "R_hl_term", 1)
endif
