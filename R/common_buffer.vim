"==============================================================================
" The variables defined here are not in the ftplugin directory because they
" are common for all file types supported by Nvim-R.
"==============================================================================


" Set omni completion (both automatic and triggered by CTRL-X CTRL-O)
if index(g:R_set_omnifunc, &filetype) > -1
    setlocal omnifunc=CompleteR
endif
if index(g:R_auto_omni, &filetype) > -1
    autocmd TextChangedI <buffer> call RTriggerCompletion()
    let b:rplugin_saved_completeopt = &completeopt
    autocmd BufLeave <buffer> exe 'set completeopt=' . b:rplugin_saved_completeopt
    autocmd BufEnter <buffer> set completeopt=menuone,noselect
endif

let b:rplugin_knitr_pattern = ''
if &filetype == "rnoweb" || &filetype == "rrst" || &filetype == "rmd"
    if &omnifunc == "CompleteR"
        let b:rplugin_non_r_omnifunc = ""
    else
        let b:rplugin_non_r_omnifunc = &omnifunc
    endif
endif

" Plugins that automatically run omni completion will work better if they
" don't have to wait for the omni list to be built.
autocmd InsertEnter <buffer> call ROnInsertEnter()

" Set the name of the Object Browser caption if not set yet
let s:tnr = tabpagenr()
if !exists("b:objbrtitle")
    if s:tnr == 1
        let b:objbrtitle = "Object_Browser"
    else
        let b:objbrtitle = "Object_Browser" . s:tnr
    endif
    unlet s:tnr
endif

let g:rplugin.lastft = &filetype

" Check if b:pdf_is_open already exists to avoid errors at other places
if !exists("b:pdf_is_open")
    let b:pdf_is_open = 0
endif

if !exists("g:SendCmdToR")
    let g:SendCmdToR = function('SendCmdToR_fake')
endif

autocmd! InsertLeave <buffer> if pumvisible() == 0 | pclose | endif

if g:R_assign == 3
    iabb <buffer> _ <-
endif
