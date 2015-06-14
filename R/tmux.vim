" Check whether Tmux is OK
if !executable('tmux')
    let g:R_in_buffer = 1
    let g:R_tmux_ob = 0
    finish
endif

let s:tmuxversion = system("tmux -V")
let s:tmuxversion = substitute(s:tmuxversion, '.*tmux \([0-9]\.[0-9]\).*', '\1', '')
if strlen(s:tmuxversion) != 3
    let s:tmuxversion = "1.0"
endif
if s:tmuxversion < "1.8"
    call RWarningMsgInp("Nvim-R requires Tmux >= 1.8")
    let g:rplugin_failed = 1
    finish
endif
unlet s:tmuxversion

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
                \ 'let g:rplugin_editor_pane = "' . g:rplugin_editor_pane . '"',
                \ 'let g:rplugin_rconsole_pane = "' . g:rplugin_rconsole_pane . '"',
                \ 'let $NVIMR_ID = "' . $NVIMR_ID . '"',
                \ 'let showmarks_enable = 0',
                \ 'let g:rplugin_tmuxsname = "' . g:rplugin_tmuxsname . '"',
                \ 'let b:rscript_buffer = "' . bufname("%") . '"',
                \ 'set filetype=rbrowser',
                \ 'let $PATH = "' . g:rplugin_nvimcom_bin_dir . '" . ":" . $PATH',
                \ 'let g:rplugin_nvimcom_port = "' . g:rplugin_nvimcom_port . '"',
                \ 'let b:objbrtitle = "' . b:objbrtitle . '"',
                \ 'let b:rplugin_extern_ob = 1',
                \ 'set shortmess=atI',
                \ 'set rulerformat=%3(%l%)',
                \ 'set laststatus=0',
                \ 'set noruler',
                \ 'let g:SendCmdToR = function("SendCmdToR_TmuxSplit")',
                \ 'let g:RBrOpenCloseLs = function("RBrOpenCloseLs_Nvim")',
                \ 'let g:rplugin_clt_job = jobstart("nvimrclient", g:rplugin_job_handlers)',
                \ 'call jobsend(g:rplugin_clt_job, "\001V' . g:rplugin_myport . '\n")',
                \ 'call jobsend(g:rplugin_clt_job, "\001R' . g:rplugin_nvimcom_port . '\n")',
                \ 'let g:rplugin_srv_job = jobstart("nvimrserver", g:rplugin_job_handlers)'], objbrowserfile)

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

function RBrOpenCloseLs_TmuxNeovim(status)
    if g:rplugin_ob_port
        call SendToOtherNvim('call RBrOpenCloseLs_Nvim(' . a:status . ')')
    endif
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
        call SendToOtherNvim("call ExternOBQuit()")
        unlet g:rplugin_ob_pane
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

let g:rplugin_tmuxsname = "NvimR-" . substitute(localtime(), '.*\(...\)', '\1', '')

if g:rplugin_do_tmux_split
    finish
endif

function StartR_ExternalTerm(rcmd)
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

function SendCmdToR_Term(...)
    if g:R_ca_ck
        let cmd = "\001" . "\013" . a:1
    else
        let cmd = a:1
    endif

    " Send the command to R running in an external terminal emulator
    let str = substitute(cmd, "'", "'\\\\''", "g")
    if a:0 == 2 && a:2 == 0
        let scmd = "tmux set-buffer '" . str . "' && tmux paste-buffer -t " . g:rplugin_tmuxsname . '.0'
    else
        let scmd = "tmux set-buffer '" . str . "\<C-M>' && tmux paste-buffer -t " . g:rplugin_tmuxsname . '.0'
    endif
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

" Choose a terminal (code adapted from screen.vim)
if exists("g:R_term")
    if !executable(g:R_term)
        call RWarningMsgInp("'" . g:R_term . "' not found. Please change the value of 'R_term' in your nvimrc.")
        let g:R_term = "xterm"
    endif
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

" The Object Browser can run in a Tmux pane only if Neovim is inside a Tmux session
let g:R_objbr_place = substitute(g:R_objbr_place, "console", "script", "")
