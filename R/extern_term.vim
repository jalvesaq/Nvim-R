
" Define a function to retrieve tmux settings
function TmuxOption(option, isglobal)
	if a:isglobal == "global"
		let result = system("tmux -L NvimR show-options -gv ". a:option)
	else
		let result = system("tmux -L NvimR show-window-options -gv ". a:option)
	endif
	return substitute(result, '\n\+$', '', '')
endfunction

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

        if executable('/bin/sh')
            let cnflines += ['set-option -g default-shell "/bin/sh"']
        endif

        if s:term_name == "rxvt" || s:term_name == "urxvt"
            let cnflines = cnflines + [
                        \ "set terminal-overrides 'rxvt*:smcup@:rmcup@'" ]
        endif

        if s:term_name == "alacritty"
            let cnflines = cnflines + [
                        \ "set terminal-overrides 'alacritty:smcup@:rmcup@'" ]
        endif

        call writefile(cnflines, g:rplugin.tmpdir . "/tmux.conf")
        call AddForDeletion(g:rplugin.tmpdir . "/tmux.conf")
        let tmuxcnf = '-f "' . g:rplugin.tmpdir . "/tmux.conf" . '"'
    endif

    let rcmd = 'NVIMR_TMPDIR=' . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') .
                \ ' NVIMR_COMPLDIR=' . substitute(g:rplugin.compldir, ' ', '\\ ', 'g') .
                \ ' NVIMR_ID=' . $NVIMR_ID .
                \ ' NVIMR_SECRET=' . $NVIMR_SECRET .
                \ ' NVIMR_PORT=' . g:rplugin.myport .
                \ ' R_DEFAULT_PACKAGES=' . $R_DEFAULT_PACKAGES

    if $NVIM_IP_ADDRESS != ""
        let rcmd .= ' NVIM_IP_ADDRESS='. $NVIM_IP_ADDRESS
    endif

    let rcmd .= ' ' . a:rcmd


    call system("tmux -L NvimR has-session -t " . g:rplugin.tmuxsname)
    if v:shell_error
        if g:rplugin.is_darwin
            let rcmd = 'TERM=screen-256color ' . rcmd
            let opencmd = printf("tmux -L NvimR -2 %s new-session -s %s '%s'",
                        \ tmuxcnf, g:rplugin.tmuxsname, rcmd)
            call writefile(["#!/bin/sh", opencmd], $NVIMR_TMPDIR . "/openR")
            call system("chmod +x '" . $NVIMR_TMPDIR . "/openR'")
            let opencmd = "open '" . $NVIMR_TMPDIR . "/openR'"
        elseif s:term_name == "konsole"
            let opencmd = printf("%s 'tmux -L NvimR -2 %s new-session -s %s \"%s\"'",
                        \ s:term_cmd, tmuxcnf, g:rplugin.tmuxsname, rcmd)
        else
            let opencmd = printf("%s tmux -L NvimR -2 %s new-session -s %s \"%s\"",
                        \ s:term_cmd, tmuxcnf, g:rplugin.tmuxsname, rcmd)
        endif
    else
        if g:rplugin.is_darwin
            call RWarningMsg("Tmux session with R is already running")
            return
        endif
        let opencmd = printf("%s tmux -L NvimR -2 %s attach-session -d -t %s",
                    \ s:term_cmd, tmuxcnf, g:rplugin.tmuxsname)
    endif

    if g:R_silent_term
        let opencmd .= " &"
        let rlog = system(opencmd)
        if v:shell_error
            call RWarningMsg(rlog)
            return
        endif
    else
        let initterm = ['cd "' . getcwd() . '"',
                    \ opencmd ]
        call writefile(initterm, g:rplugin.tmpdir . "/initterm_" . $NVIMR_ID . ".sh")
        if has("nvim")
            let g:rplugin.jobs["Terminal emulator"] = StartJob(["sh", g:rplugin.tmpdir . "/initterm_" . $NVIMR_ID . ".sh"],
                        \ {'on_stderr': function('ROnJobStderr'), 'on_exit': function('ROnJobExit'), 'detach': 1})
        else
            let g:rplugin.jobs["Terminal emulator"] = StartJob(["sh", g:rplugin.tmpdir . "/initterm_" . $NVIMR_ID . ".sh"],
                        \ {'err_cb': 'ROnJobStderr', 'exit_cb': 'ROnJobExit'})
        endif
        call AddForDeletion(g:rplugin.tmpdir . "/initterm_" . $NVIMR_ID . ".sh")
    endif
    let g:rplugin.debug_info['R open command'] = opencmd

    let g:SendCmdToR = function('SendCmdToR_Term')
    call WaitNvimcomStart()
endfunction

function SendCmdToR_Term(...)
    if g:R_clear_line
        if g:R_editing_mode == "emacs"
            let cmd = "\001\013" . a:1
        else
            let cmd = "\x1b0Da" . a:1
        endif
    else
        let cmd = a:1
    endif

    " Send the command to R running in an external terminal emulator
    let str = substitute(cmd, "'", "'\\\\''", "g")
    if str =~ '^-'
        let str = ' ' . str
    endif
    if a:0 == 2 && a:2 == 0
        let scmd = "tmux -L NvimR set-buffer '" . str . "' ; tmux -L NvimR paste-buffer -t " . g:rplugin.tmuxsname . '.' . TmuxOption("pane-base-index", "window")
    else
        let scmd = "tmux -L NvimR set-buffer '" . str . "\<CR>' ; tmux -L NvimR paste-buffer -t " . g:rplugin.tmuxsname . '.' . TmuxOption("pane-base-index", "window")
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

" The Object Browser can run in a Tmux pane only if Neovim is inside a Tmux session
let g:R_objbr_place = substitute(g:R_objbr_place, "console", "script", "")

let g:R_silent_term = get(g:, "R_silent_term", 0)

if g:rplugin.is_darwin
    let s:term_name = 'xterm'
    let s:term_cmd = 'xterm -title R -e'
    finish
endif

if type(g:R_external_term) == v:t_string
    let s:term_name = substitute(g:R_external_term, ' .*', '', '')
    let s:term_cmd = g:R_external_term
    if g:R_external_term =~ ' '
        " The terminal command is complete
        finish
    endif
endif

if exists("s:term_name")
    if !executable(s:term_name)
        call RWarningMsg("'" . s:term_name . "' not found. Please change the value of 'R_external_term' in your vimrc.")
        finish
    endif
else
    " Choose a terminal (code adapted from screen.vim)
    let s:terminals = ['gnome-terminal', 'konsole', 'xfce4-terminal', 'Eterm',
                \ 'rxvt', 'urxvt', 'aterm', 'roxterm', 'lxterminal', 'alacritty', 'xterm']
    if $WAYLAND_DISPLAY != ''
        let s:terminals = ['foot'] + s:terminals
    endif
    for s:term in s:terminals
        if executable(s:term)
            let s:term_name = s:term
            break
        endif
    endfor
    unlet s:term
    unlet s:terminals
endif

if !exists("s:term_name")
    call RWarningMsg("Please, set the variable 'g:R_external_term' in your vimrc. See the plugin documentation for details.")
    let g:rplugin.failed = 1
    finish
endif

if s:term_name =~ '^\(foot\|gnome-terminal\|xfce4-terminal\|roxterm\|Eterm\|aterm\|lxterminal\|rxvt\|urxvt\|alacritty\)$'
    let s:term_cmd = s:term_name . " --title R"
elseif s:term_name =~ '^\(xterm\|uxterm\|lxterm\)$'
    let s:term_cmd = s:term_name . " -title R"
else
    let s:term_cmd = s:term_name
endif

if s:term_name == 'foot'
    let s:term_cmd .= ' --log-level error'
endif

if !g:R_nvim_wd
    if s:term_name =~ '^\(gnome-terminal\|xfce4-terminal\|lxterminal\)$'
        let s:term_cmd .= " --working-directory='" . expand("%:p:h") . "'"
    elseif s:term_name == "konsole"
        let s:term_cmd .= " -p tabtitle=R --workdir '" . expand("%:p:h") . "'"
    elseif s:term_name == "roxterm"
        let s:term_cmd .= " --directory='" . expand("%:p:h") . "'"
    endif
endif

if s:term_name == "gnome-terminal"
    let s:term_cmd .= " --"
elseif s:term_name =~ '^\(terminator\|xfce4-terminal\)$'
    let s:term_cmd .= " -x"
else
    let s:term_cmd .= " -e"
endif
