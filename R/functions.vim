
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Support for rGlobEnvFun
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" File types that embed R, such as Rnoweb, require at least one keyword
" defined immediately
syn keyword rGlobEnvFun ThisIsADummyGlobEnvFunKeyword
hi def link rGlobEnvFun  Function

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Only source the remaining of this script once
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if exists("*SourceRFunList")
    if len(g:rplugin.libraries_in_R) > 0
        for s:lib in g:rplugin.libraries_in_R
            " Add rFunction keywords to r syntax
            call SourceRFunList(s:lib)
        endfor
        unlet s:lib
    elseif len(g:rplugin.default_libs) > 0
        for s:lib in g:rplugin.default_libs
            call SourceRFunList(s:lib)
        endfor
        unlet s:lib
    endif
    finish
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Set global variables when this script is called for the first time
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if !exists('g:rplugin')
    " Also in common_global.vim
    let g:rplugin = {'debug_info': {'Build_omnils_pkg': '', 'libraries': []},
                \ 'libraries_in_R': [],
                \ 'default_libs': []}
endif

" syntax/r.vim may have being called before ftplugin/r.vim
if !has_key(g:rplugin, "compldir")
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/setcompldir.vim"
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function for highlighting rFunction keywords
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Must be run for each buffer
function SourceRFunList(lib)
    if exists("g:R_hi_fun") && g:R_hi_fun == 0
        return
    endif

    let fnm = g:rplugin.compldir . '/fun_' . a:lib

    " Highlight R functions
    if !exists("g:R_hi_fun_paren") || g:R_hi_fun_paren == 0
        exe "source " . substitute(fnm, ' ', '\\ ', 'g')
    else
        let lines = readfile(fnm)
        for line in lines
            let newline = substitute(line, "\\.", "\\\\.", "g")
            if substitute(line, "syn keyword rFunction ", "", "") =~ "[ ']"
                let newline = substitute(newline, "keyword rFunction ", "match rSpaceFun /`\\\\zs", "")
                exe newline . "\\ze`\\s*(/ contained"
            else
                let newline = substitute(newline, "keyword rFunction ", "match rFunction /\\\\<", "")
                exe newline . "\\s*\\ze(/"
            endif
        endfor
    endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function called when nvimcom updates the list of loaded libraries
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function FunHiOtherBf()
    " Syntax highlight other buffers
    if !exists("g:R_hi_fun") || g:R_hi_fun != 0
        if exists("*nvim_buf_set_option")
            for bId in nvim_list_bufs()
                call nvim_buf_set_option(bId, "syntax", nvim_buf_get_option(bId, "syntax"))
            endfor
        else
            silent exe 'set syntax=' . &syntax
            redraw
        endif
    endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Source the Syntax scripts for the first time, before the
" buffer is drawn to include rFunction keywords in r syntax
" and build the list for completion of :Rhelp
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if len(g:rplugin.default_libs) == 0 && filereadable(g:rplugin.compldir . '/last_default_libnames')
    let s:deflibs = readfile(g:rplugin.compldir . '/last_default_libnames')
    for s:lib in s:deflibs
        if filereadable(g:rplugin.compldir . '/fun_' . s:lib)
            let g:rplugin.default_libs += [s:lib]
        endif
    endfor
    unlet s:lib
endif
if len(g:rplugin.default_libs) > 0
    for s:lib in g:rplugin.default_libs
        call SourceRFunList(s:lib)
    endfor
    unlet s:lib
endif
