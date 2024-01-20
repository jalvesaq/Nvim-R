"==============================================================================
" Support for rGlobEnvFun
"==============================================================================
" File types that embed R, such as Rnoweb, require at least one keyword
" defined immediately
syn keyword rGlobEnvFun ThisIsADummyGlobEnvFunKeyword
hi def link rGlobEnvFun  Function

"==============================================================================
" Only source the remaining of this script once
"==============================================================================
if exists("*SourceRFunList")
    if len(g:rplugin.libs_in_nrs) > 0
        for s:lib in g:rplugin.libs_in_nrs
            " Add rFunction keywords to r syntax
            call SourceRFunList(s:lib)
        endfor
        unlet s:lib
    endif
    finish
endif

"==============================================================================
" Set global variables when this script is called for the first time
"==============================================================================

if !exists('g:rplugin')
    " Attention: also in common_global.vim because either of them might be sourced first.
    let g:rplugin = {'debug_info': {}, 'libs_in_nrs': [], 'nrs_running': 0, 'myport': 0, 'R_pid': 0}
endif

" syntax/r.vim may have being called before ftplugin/r.vim
if !has_key(g:rplugin, "compldir")
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/setcompldir.vim"
endif

let g:R_hi_fun = get(g:, "R_hi_fun", 1)

"==============================================================================
" Function for highlighting rFunction keywords
"==============================================================================

" Must be run for each buffer
function SourceRFunList(lib)
    if g:R_hi_fun == 0
        return
    endif

    let fnm = g:rplugin.compldir . '/fun_' . a:lib

    if has_key(g:rplugin, "localfun")
        call UpdateLocalFunctions(g:rplugin.localfun)
    endif

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


"==============================================================================
" Function called when nvimcom updates the list of loaded libraries
"==============================================================================

function FunHiOtherBf()
    if &diff || g:R_hi_fun == 0
        return
    endif

    " Syntax highlight other buffers
    if has("nvim")
        for bId in nvim_list_bufs()
            let bsyn = nvim_buf_get_option(bId, "syntax")
            if bsyn == 'r' || bsyn == 'quarto' || bsyn == 'rhelp' || bsyn == 'rmd' || bsyn == 'rnoweb' || bsyn == 'rrst'
                call nvim_set_option_value("syntax", bsyn, {'buf': bId})
            endif
        endfor
    else
        silent exe 'set syntax=' . &syntax
        redraw
    endif
endfunction
