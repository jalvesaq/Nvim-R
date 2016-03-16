
if exists("*TmuxActivePane")
    finish
endif

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

function StartR_TmuxSplit(rcmd)
    let g:rplugin_editor_pane = $TMUX_PANE
    let tmuxconf = ['set-environment NVIMR_TMPDIR "' . g:rplugin_tmpdir . '"',
                \ 'set-environment NVIMR_COMPLDIR "' . substitute(g:rplugin_compldir, ' ', '\\ ', "g") . '"',
                \ 'set-environment NVIMR_ID ' . $NVIMR_ID ,
                \ 'set-environment NVIMR_SECRET ' . $NVIMR_SECRET ,
                \ 'set-environment R_DEFAULT_PACKAGES ' . $R_DEFAULT_PACKAGES ]
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

    " Let Tmux automatically kill the panel when R quits.
    let tcmd .= " '" . a:rcmd . "'"

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

function StartObjBrowser_Tmux()
    if g:rplugin_myport == 0
        call RWarningMsg("Nvimcom server port not defined yet.")
        return
    endif
    if exists("b:rplugin_extern_ob")
        " This is the Object Browser
        echoerr "StartObjBrowser_Tmux() called."
        return
    endif

    " Force Neovim to update the window size
    mode

    " Don't start the Object Browser if it already exists
    if IsExternalOBRunning()
        return
    endif

    let objbrowserfile = g:rplugin_tmpdir . "/objbrowserInit"
    let tmxs = " "

    if has("nvim")
        let jopt = '{"on_stdout": "ROnJobStdout", "on_stderr": "ROnJobStderr"}'
    else
        let jopt = '{"out_cb": "ROnJobStdout", "err_cb": "ROnJobStderr"}'
    endif

    call writefile([
                \ 'let g:rplugin_editor_pane = "' . g:rplugin_editor_pane . '"',
                \ 'let g:rplugin_rconsole_pane = "' . g:rplugin_rconsole_pane . '"',
                \ 'let $NVIMR_ID = "' . $NVIMR_ID . '"',
                \ 'let showmarks_enable = 0',
                \ 'let g:rplugin_tmuxsname = "' . g:rplugin_tmuxsname . '"',
                \ 'let b:rscript_buffer = "' . bufname("%") . '"',
                \ 'set filetype=rbrowser',
                \ 'let g:rplugin_nvimcom_port = "' . g:rplugin_nvimcom_port . '"',
                \ 'let $NVIMCOMPORT = "' . g:rplugin_nvimcom_port . '"',
                \ 'let b:objbrtitle = "' . b:objbrtitle . '"',
                \ 'let b:rplugin_extern_ob = 1',
                \ 'set shortmess=atI',
                \ 'set rulerformat=%3(%l%)',
                \ 'set laststatus=0',
                \ 'set noruler',
                \ 'runtime R/tmux_split.vim',
                \ 'let g:SendCmdToR = function("SendCmdToR_TmuxSplit")',
                \ 'let g:rplugin_jobs["ClientServer"] = StartJob("nclientserver", ' . jopt . ')',
                \ 'sleep 150m',],
                \ objbrowserfile)

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

    let cmd = "tmux split-window -h -l " . panewidth . " -t " . obpane . ' "TERM=' . $TERM . ' ' . v:progname . " -c 'source " . substitute(objbrowserfile, ' ', '\\ ', 'g') . "'" . '"'
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

function SendCmdToR_TmuxSplit(...)
    if g:R_ca_ck
        let cmd = "\001" . "\013" . a:1
    else
        let cmd = a:1
    endif

    if !exists("g:rplugin_rconsole_pane")
        " Should never happen
        call RWarningMsg("Missing internal variable: g:rplugin_rconsole_pane")
    endif
    let str = substitute(cmd, "'", "'\\\\''", "g")
    if str =~ '^-'
        let str = ' ' . str
    endif
    if a:0 == 2 && a:2 == 0
        let scmd = "tmux set-buffer '" . str . "' && tmux paste-buffer -t " . g:rplugin_rconsole_pane
    else
        let scmd = "tmux set-buffer '" . str . "\<C-M>' && tmux paste-buffer -t " . g:rplugin_rconsole_pane
    endif
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

function CloseExternalOB()
    if IsExternalOBRunning()
        sleep 300m
        let g:rplugin_ob_port = 0
        let qcmd = "tmux set-buffer ':quit\<C-M>' && tmux paste-buffer -t " . g:rplugin_ob_pane
        unlet g:rplugin_ob_pane
        call system(qcmd)
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
