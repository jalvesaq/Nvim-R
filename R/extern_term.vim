
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

        if g:R_term == "rxvt" || g:R_term == "urxvt"
            let cnflines = cnflines + [
                        \ "set terminal-overrides 'rxvt*:smcup@:rmcup@'" ]
        endif

        call writefile(cnflines, g:rplugin.tmpdir . "/tmux.conf")
        call AddForDeletion(g:rplugin.tmpdir . "/tmux.conf")
        let tmuxcnf = '-f "' . g:rplugin.tmpdir . "/tmux.conf" . '"'
    endif

    let rcmd = 'NVIMR_TMPDIR=' . substitute(g:rplugin.tmpdir, ' ', '\\ ', 'g') .
                \ ' NVIMR_COMPLDIR=' . substitute(g:rplugin.compldir, ' ', '\\ ', 'g') .
                \ ' NVIMR_ID=' . $NVIMR_ID .
                \ ' NVIMR_SECRET=' . $NVIMR_SECRET .
                \ ' NVIMR_PORT=' . $NVIMR_PORT .
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
        elseif g:R_term == "konsole"
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
        let scmd = "tmux -L NvimR set-buffer '" . str . "' && tmux -L NvimR paste-buffer -t " . g:rplugin.tmuxsname . '.' . TmuxOption("pane-base-index", "window")
    else
        let scmd = "tmux -L NvimR set-buffer '" . str . "\<C-M>' && tmux -L NvimR paste-buffer -t " . g:rplugin.tmuxsname . '.' . TmuxOption("pane-base-index", "window")
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
    let g:R_term = "xterm"
    finish
endif

" Choose a terminal (code adapted from screen.vim)
if exists("g:R_term")
    if !executable(g:R_term)
        call RWarningMsg("'" . g:R_term . "' not found. Please change the value of 'R_term' in your vimrc.")
        finish
    endif
endif

if !exists("g:R_term")
    let s:terminals = ['gnome-terminal', 'konsole', 'xfce4-terminal', 'Eterm',
                \ 'rxvt', 'urxvt', 'aterm', 'roxterm', 'lxterminal', 'xterm']
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
    call RWarningMsg("Please, set the variable 'g:R_term_cmd' in your vimrc. Read the plugin documentation for details.")
    let g:rplugin.failed = 1
    finish
endif

let s:term_cmd = g:R_term

if g:R_term =~ '^\(gnome-terminal\|xfce4-terminal\|roxterm\|Eterm\|aterm\|lxterminal\|rxvt\|urxvt\)$'
    let s:term_cmd = s:term_cmd . " --title R"
elseif g:R_term == '^\(xterm\|uxterm\|lxterm\)$'
    let s:term_cmd = s:term_cmd . " -title R"
endif

if !g:R_nvim_wd
    if g:R_term =~ '^\(gnome-terminal\|xfce4-terminal\|lxterminal\)$'
        let s:term_cmd = g:R_term . " --working-directory='" . expand("%:p:h") . "'"
    elseif g:R_term == "konsole"
        let s:term_cmd = "konsole -p tabtitle=R --workdir '" . expand("%:p:h") . "'"
    elseif g:R_term == "roxterm"
        let s:term_cmd = "roxterm --directory='" . expand("%:p:h") . "'"
    endif
endif

if g:R_term == "gnome-terminal"
    let s:gtv = split(system("gnome-terminal --version"))
    if len(s:gtv) > 2 && s:gtv[2] >= "3.24.2"
        let s:term_cmd = s:term_cmd . " --"
    else
        let s:term_cmd = s:term_cmd . " -x"
    endif
    unlet s:gtv
elseif g:R_term == "xfce4-terminal"
    let s:term_cmd = s:term_cmd . " -x"
else
    let s:term_cmd = s:term_cmd . " -e"
endif

" Override default settings:
if exists("g:R_term_cmd")
    let s:term_cmd = g:R_term_cmd
endif
