" This file contains code used only when R run in Neovim buffer

function SendCmdToR_Neovim(...)
    if g:rplugin_R_job
        call jobsend(g:rplugin_R_job, a:1 . "\n")
        return 1
    else
        call RWarningMsg("Is R running?")
        return 0
    endif
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
            silent exe "belowright " . g:R_rconsole_width . "vnew"
        else
            silent belowright vnew
        endif
    else
        if g:R_rconsole_height > 6 && g:R_rconsole_height < (winheight(0) - 6)
            silent exe "belowright " . g:R_rconsole_height . "new"
        else
            silent belowright new
        endif
    endif
    call cursor("$", 1)
    let g:rplugin_R_job = termopen("R " . r_args_str, {'on_exit': function('ROnJobExit')})
    let g:rplugin_R_bufname = bufname("%")
    let b:objbrtitle = objbrttl
    let b:rscript_buffer = curbufnm
    if g:R_hl_term
        runtime syntax/rout.vim
    endif
    exe "sbuffer " . edbuf
    stopinsert
    call WaitNvimcomStart()
endfunction

