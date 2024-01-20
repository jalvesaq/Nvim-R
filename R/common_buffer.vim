"==============================================================================
" The variables defined here are not in the ftplugin directory because they
" are common for all file types supported by Nvim-R.
"==============================================================================

" Source scripts common to R, Rnoweb, Rhelp and rdoc files:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_global.vim"

let b:rplugin_knitr_pattern = ''

let g:rplugin.lastft = &filetype

" Check if b:pdf_is_open already exists to avoid errors at other places
if !exists("b:pdf_is_open")
    let b:pdf_is_open = 0
endif

if g:R_assign == 3
    iabb <buffer> _ <-
endif

if index(g:R_set_omnifunc, &filetype) > -1
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/complete.vim"
    call RComplAutCmds()
endif

if !exists('b:did_unrll_au')
    let b:did_unrll_au = 1
    autocmd BufWritePost <buffer> if exists("*UpdateNoRLibList") | call UpdateNoRLibList() | endif
    autocmd BufEnter <buffer> if exists("*UpdateNoRLibList") | call UpdateNoRLibList() | endif
endif
