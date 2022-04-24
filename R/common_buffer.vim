"==============================================================================
" The variables defined here are not in the ftplugin directory because they
" are common for all file types supported by Nvim-R.
"==============================================================================

" Source scripts common to R, Rnoweb, Rhelp and rdoc files:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_global.vim"


" Set omni completion (both automatic and triggered by CTRL-X CTRL-O)
if index(g:R_set_omnifunc, &filetype) > -1
    setlocal omnifunc=CompleteR
endif

" Plugins that automatically run omni completion will work better if they
" don't have to wait for the omni list to be built.
augroup RBuffer
    " Required to avoid the autocmd being registered three times
    autocmd!
    autocmd InsertEnter <buffer> call ROnInsertEnter()
    if index(g:R_auto_omni, &filetype) > -1
        let b:rplugin_saved_completeopt = &completeopt
        autocmd InsertCharPre <buffer> call RTriggerCompletion()
        autocmd BufLeave <buffer> exe 'set completeopt=' . b:rplugin_saved_completeopt
        autocmd BufEnter <buffer> set completeopt=menuone,noselect
    endif
    if index(g:R_auto_omni, &filetype) > -1 || index(g:R_set_omnifunc, &filetype) > -1
        autocmd CompleteChanged <buffer> call AskForComplInfo()
        autocmd CompleteDone <buffer> call OnCompleteDone()
    endif
augroup END

let b:rplugin_knitr_pattern = ''
if &filetype == "rnoweb" || &filetype == "rrst" || &filetype == "rmd" || &filetype == "quarto"
    if &omnifunc == "CompleteR"
        let b:rplugin_non_r_omnifunc = ""
    else
        let b:rplugin_non_r_omnifunc = &omnifunc
    endif
endif


let g:rplugin.lastft = &filetype

" Check if b:pdf_is_open already exists to avoid errors at other places
if !exists("b:pdf_is_open")
    let b:pdf_is_open = 0
endif

if g:R_assign == 3
    iabb <buffer> _ <-
endif
