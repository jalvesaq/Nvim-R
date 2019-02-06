if $TMUX == ''
    finish
endif

if exists("*TmuxActivePane")
    finish
endif

let g:R_in_buffer = 0
let g:R_applescript = 0
let g:rplugin.tmux_split = 1
let g:R_tmux_title = get(g:, 'R_tmux_title', 'NvimR')

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

" Replace StartR_ExternalTerm with a function that starts R in a Tmux split pane
function! StartR_ExternalTerm(rcmd)
    let g:rplugin.editor_pane = $TMUX_PANE
    let tmuxconf = ['set-environment NVIMR_TMPDIR "' . g:rplugin.tmpdir . '"',
                \ 'set-environment NVIMR_COMPLDIR "' . substitute(g:rplugin.compldir, ' ', '\\ ', "g") . '"',
                \ 'set-environment NVIMR_ID ' . $NVIMR_ID ,
                \ 'set-environment NVIMR_SECRET ' . $NVIMR_SECRET ,
                \ 'set-environment NVIMR_PORT ' . $NVIMR_PORT ,
                \ 'set-environment R_DEFAULT_PACKAGES ' . $R_DEFAULT_PACKAGES ]
    if $NVIM_IP_ADDRESS != ""
        call extend(tmuxconf, ['set-environment NVIM_IP_ADDRESS ' . $NVIM_IP_ADDRESS ])
    endif
    if $R_LIBS_USER != ""
        call extend(tmuxconf, ['set-environment R_LIBS_USER ' . $R_LIBS_USER ])
    endif
    if &t_Co == 256
        call extend(tmuxconf, ['set default-terminal "' . $TERM . '"'])
    endif
    call writefile(tmuxconf, g:rplugin.tmpdir . "/tmux" . $NVIMR_ID . ".conf")
    call system("tmux source-file '" . g:rplugin.tmpdir . "/tmux" . $NVIMR_ID . ".conf" . "'")
    call delete(g:rplugin.tmpdir . "/tmux" . $NVIMR_ID . ".conf")
    let tcmd = "tmux split-window "
    if g:R_rconsole_width > 0 && winwidth(0) > (g:R_rconsole_width + g:R_min_editor_width + 1 + (&number * &numberwidth))
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
    let s:rplugin_rconsole_pane = TmuxActivePane()
    let rlog = system("tmux select-pane -t " . g:rplugin.editor_pane)
    if v:shell_error
        call RWarningMsg(rlog)
        return
    endif
    let g:SendCmdToR = function('SendCmdToR_TmuxSplit')
    let g:rplugin.last_rcmd = a:rcmd
    if g:R_tmux_title != "automatic" && g:R_tmux_title != ""
        call system("tmux rename-window " . g:R_tmux_title)
    endif
    call WaitNvimcomStart()
    " Environment variables persist across Tmux windows.
    " Unset NVIMR_TMPDIR to avoid nvimcom loading its C library
    " when R was not started by Neovim:
    call system("tmux set-environment -u NVIMR_TMPDIR")
    " Also unset R_DEFAULT_PACKAGES so that other R instances do not
    " load nvimcom unnecessarily
    call system("tmux set-environment -u R_DEFAULT_PACKAGES")
endfunction

function SendCmdToR_TmuxSplit(...)
    if g:R_clear_line
        if g:R_editing_mode == "emacs"
            let cmd = "\001\013" . a:1
        else
            let cmd = "\x1b0Da" . a:1
        endif
    else
        let cmd = a:1
    endif

    if !exists("s:rplugin_rconsole_pane")
        " Should never happen
        call RWarningMsg("Missing internal variable: s:rplugin_rconsole_pane")
    endif
    let str = substitute(cmd, "'", "'\\\\''", "g")
    if str =~ '^-'
        let str = ' ' . str
    endif
    if a:0 == 2 && a:2 == 0
        let scmd = "tmux set-buffer '" . str . "' && tmux paste-buffer -t " . s:rplugin_rconsole_pane
    else
        let scmd = "tmux set-buffer '" . str . "\<C-M>' && tmux paste-buffer -t " . s:rplugin_rconsole_pane
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
