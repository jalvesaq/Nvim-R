" This file contains code used only when R run in Neovim buffer

function SendCmdToR_Neovim(...)
    let curbuf = bufname("%")
    let saved_reg = @"
    let @" = a:1 . "\r"
    exe "sbuffer " . g:rplugin_R_bufname
    normal! p
    exe "sbuffer " . curbuf
    let @" = saved_reg
    return 1
endfunction

function StartR_Neovim()
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        return
    endif
    let g:rplugin_do_tmux_split = 0

    let g:SendCmdToR = function('SendCmdToR_Neovim')

    let edbuf = bufname("%")
    let objbrttl = b:objbrtitle
    let r_args_str = b:rplugin_r_args_str
    let curbufnm = bufname("%")
    set switchbuf=useopen
    if g:R_vsplit
        if g:R_rconsole_width > 16 && g:R_rconsole_width < (winwidth(0) - 16)
            silent exe "belowright " . g:R_rconsole_width . "vsplit"
        else
            silent belowright vsplit
        endif
    else
        if g:R_rconsole_height > 6 && g:R_rconsole_height < (winheight(0) - 6)
            silent exe "belowright " . g:R_rconsole_height . "split"
        else
            silent belowright split
        endif
    endif
    call cursor("$", 1)
    exe "term R " . r_args_str
    let g:rplugin_R_bufname = bufname("%")
    let b:objbrtitle = objbrttl
    let b:rscript_buffer = curbufnm
    exe "sbuffer " . edbuf
    stopinsert
    call WaitNvimcomStart()
endfunction

