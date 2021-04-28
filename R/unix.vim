
if exists("g:R_path")
    let s:rpath = split(g:R_path, ':')
    call map(s:rpath, 'expand(v:val)')
    call reverse(s:rpath)
    for s:dir in s:rpath
        if isdirectory(s:dir)
            let $PATH = s:dir . ':' . $PATH
        else
            call RWarningMsg('"' . s:dir . '" is not a directory. Fix the value of R_path in your vimrc.')
        endif
    endfor
    unlet s:rpath
    unlet s:dir
endif

if !executable(g:rplugin.R)
    call RWarningMsg('"' . g:rplugin.R . '" not found. Fix the value of either R_path or R_app in your vimrc.')
endif

if (type(g:R_external_term) == v:t_number && g:R_external_term == 1) ||
            \ type(g:R_external_term) == v:t_string ||
            \ (exists('g:R_source') && g:R_source =~# 'tmux_split.vim')
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/tmux.vim"
endif
