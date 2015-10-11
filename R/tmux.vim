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

let g:rplugin_tmuxsname = "NvimR-" . substitute(localtime(), '.*\(...\)', '\1', '')

if g:R_tmux_split
    runtime R/tmux_split.vim
else
    runtime R/extern_term.vim
endif

