" This file contains code used only when R run in Neovim buffer

function SendCmdToR_Neovim(...)
    if g:rplugin_R_job
        if g:R_ca_ck
            let cmd = "\001" . "\013" . a:1
        else
            let cmd = a:1
        endif

        let curbuf = bufname("%")
        let savesb = &switchbuf
        set switchbuf=useopen
        exe 'sb ' . g:rplugin_R_bufname
        let rwnwdth = winwidth(0)
        exe 'sb ' . curbuf
        exe 'set switchbuf=' . savesb
        if rwnwdth != g:rplugin_R_width && rwnwdth != -1 && rwnwdth > 10 && rwnwdth < 999
            let g:rplugin_R_width = rwnwdth
            call SendToNvimcom("\x08" . $NVIMR_ID . "options(width=" . g:rplugin_R_width. ")")
            sleep 10m
        endif

        if a:0 == 2 && a:2 == 0
            call jobsend(g:rplugin_R_job, cmd)
        else
            call jobsend(g:rplugin_R_job, cmd . "\n")
        endif
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
    let g:rplugin_R_job = termopen(g:rplugin_R . " " . join(g:rplugin_r_args), {'on_exit': function('ROnJobExit')})
    let g:rplugin_R_bufname = bufname("%")
    let g:rplugin_R_width = 0
    let b:objbrtitle = objbrttl
    let b:rscript_buffer = curbufnm
    if g:R_hl_term
        runtime syntax/rout.vim
    endif
    if g:R_esc_term
        tnoremap <buffer> <Esc> <C-\><C-n>
    endif
    exe "sbuffer " . edbuf
    stopinsert
    call WaitNvimcomStart()
endfunction

if has("win32")
    call RSetDefaultValue("g:R_hl_term", 1)
else
    let s:hlterm = 1
    if filereadable(expand("~/.Rprofile"))
        let s:rprfl = readfile(expand("~/.Rprofile"))
        if len(s:rprfl)
            for s:lin in s:rprfl
                let s:lin = substitute(s:lin, '^\s*#.*', '', '')
                if s:lin =~ "library.*colorout" || s:lin =~ "require.*colorout" || s:lin =~ "source"
                    let s:hlterm = 0
                    break
                endif
            endfor
            unlet s:lin
        endif
        unlet s:rprfl
    else
        let s:hlterm = 0
    endif
    call RSetDefaultValue("g:R_hl_term", s:hlterm)
    unlet s:hlterm
endif
