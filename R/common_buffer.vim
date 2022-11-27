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

if (index(g:R_auto_omni, &filetype) > -1 || index(g:R_auto_omni, &filetype) > -1)
    if !exists("*CompleteR")
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/complete.vim"
    endif
    if &filetype == "rnoweb" || &filetype == "rrst" || &filetype == "rmd" || &filetype == "quarto"
        if &omnifunc == "CompleteR"
            let b:rplugin_non_r_omnifunc = ""
        else
            let b:rplugin_non_r_omnifunc = &omnifunc
        endif
    endif
endif
if index(g:R_auto_omni, &filetype) > -1
    let g:R_hi_fun_globenv = 2
    call RComplAutCmds()
endif
