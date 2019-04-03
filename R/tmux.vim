" Check whether Tmux is OK
if !executable('tmux')
    if exists("*termopen")
        let g:R_in_buffer = 1
    else
        call RWarningMsg("tmux executable not found")
    endif
    finish
endif

if system("uname") =~ "OpenBSD"
    " Tmux does not have -V option on OpenBSD: https://github.com/jcfaria/Vim-R-plugin/issues/200
    let s:tmuxversion = "0.0"
else
    let s:tmuxversion = system("tmux -V")
    let s:tmuxversion = substitute(s:tmuxversion, "master", "1.8", "")
    let s:tmuxversion = substitute(s:tmuxversion, "next", "1.8", "")
    let s:tmuxversion = substitute(s:tmuxversion, '.*tmux \([0-9]\.[0-9]\).*', '\1', '')
    if strlen(s:tmuxversion) != 3
        let s:tmuxversion = "1.0"
    endif
    if s:tmuxversion < "1.8"
        call RWarningMsg("Nvim-R requires Tmux >= 1.8")
        let g:rplugin.failed = 1
        finish
    endif
endif
unlet s:tmuxversion

let g:rplugin.tmuxsname = "NvimR-" . substitute(localtime(), '.*\(...\)', '\1', '')

let g:R_setwidth = get(g:, 'R_setwidth', 2)

if !exists('g:R_source') || (exists('g:R_source') && g:R_source !~# 'tmux_split.vim')
    exe 'source ' . substitute(expand('<sfile>:h:h'), ' ', '\ ', 'g') . '/R/extern_term.vim'
endif

