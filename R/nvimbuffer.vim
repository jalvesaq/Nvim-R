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
        if g:R_setwidth != 0 && g:R_setwidth != 2
            let rwnwdth = winwidth(g:rplugin.R_winnr)
            if rwnwdth != s:R_width && rwnwdth != -1 && rwnwdth > 10 && rwnwdth < 999
                let s:R_width = rwnwdth
                let Rwidth = s:R_width + s:number_col
                if has("win32")
                    let cmd = "options(width=" . Rwidth . "); ". cmd
                else
                    call SendToNvimcom("\x08" . $NVIMR_ID . "options(width=" . Rwidth . ")")
                    sleep 10m
                endif
            endif
        endif

        if g:R_auto_scroll && cmd !~ '^quit('
            if exists("*nvim_win_set_cursor")
                " These functions exist only in Neovim >= 0.4.0:
                call nvim_win_set_cursor(g:rplugin.R_winnr, [nvim_buf_line_count(nvim_win_get_buf(g:rplugin.R_winnr)), 0])
            else
                " TODO: Delete this code and update the documentation when
                " everyone is using Neovim >= 0.4.0 (released on 2019-04-08)
                let sbopt = &switchbuf
                set switchbuf=useopen,usetab
                let curtab = tabpagenr()
                let isnormal = mode() ==# 'n'
                let curwin = winnr()
                exe 'sb ' . g:rplugin.R_bufname
                call cursor('$', 1)
                if tabpagenr() != curtab
                    exe 'normal! ' . curtab . 'gt'
                endif
                exe curwin . 'wincmd w'
                if isnormal
                    stopinsert
                endif
                exe 'set switchbuf=' . sbopt
            endif
        endif

        if !(a:0 == 2 && a:2 == 0)
            let cmd = cmd . "\n"
        endif
        if exists('*chansend')
            call chansend(g:rplugin.jobs["R"], cmd)
        else
            call jobsend(g:rplugin.jobs["R"], cmd)
        endif
        return 1
    else
        call RWarningMsg("Is R running?")
        return 0
    endif
endfunction

function OnTermClose()
    if exists("g:rplugin.R_bufname")
        if g:rplugin.R_bufname == bufname("%")
            if g:R_close_term
                if g:R_clear_line
                    call feedkeys('a ')
                else
                    call feedkeys(' ')
                endif
            endif
        endif
        unlet g:rplugin.R_bufname
    endif

    " Set nvimcom port to 0 in nclientserver
    if g:rplugin.jobs["ClientServer"]
        if exists('*chansend')
            call chansend(g:rplugin.jobs["ClientServer"], "\001R0\n")
        else
            call jobsend(g:rplugin.jobs["ClientServer"], "\001R0\n")
        endif
    endif
endfunction

function StartR_InBuffer()
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        return
    endif

    let g:SendCmdToR = function('SendCmdToR_NotYet')

    let edbuf = bufname("%")
    let objbrttl = b:objbrtitle
    set switchbuf=useopen

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

    if has("win32")
        call SetRHome()
    endif
    let g:rplugin.jobs["R"] = termopen(g:rplugin.R . " " . join(g:rplugin.r_args), {'on_exit': function('ROnJobExit')})
    if has("win32")
        redraw
        call UnsetRHome()
    endif
    let g:rplugin.R_bufname = bufname("%")
    let g:rplugin.R_winnr = win_getid()
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
    let b:objbrtitle = objbrttl
    if exists("g:R_hl_term") && g:R_hl_term
        silent set syntax=rout
    endif
    if g:R_esc_term
        tnoremap <buffer> <Esc> <C-\><C-n>
    endif
    autocmd TermClose <buffer> call OnTermClose()
    for optn in split(g:R_buffer_opts)
        exe 'setlocal ' . optn
    endfor
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
