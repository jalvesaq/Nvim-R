
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
    if len(g:rplugin.libraries_in_ncs) > 0
        for s:lib in g:rplugin.libraries_in_ncs
            " Add rFunction keywords to r syntax
            call SourceRFunList(s:lib)
        endfor
    else
        for s:lib in s:lists_to_load
            call SourceRFunList(s:lib)
        endfor
    endif
    unlet s:lib
    finish
endif

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Set global variables when this script is called for the first time
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if !exists('g:rplugin')
    " Also in common_global.vim
    let g:rplugin = {'debug_info': {'Build_omnils_pkg': '', 'libraries': []},
                \ 'libraries_in_ncs': [],
                \ 'loaded_libs': []}
endif

let s:Rhelp_list = []

" syntax/r.vim may have being called before ftplugin/r.vim
if !has_key(g:rplugin, "compldir")
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/setcompldir.vim"
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Function for highlighting rFunction keywords
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" let s:fun_sourced = ';'

" Must be run for each buffer
function SourceRFunList(lib)
    "if s:fun_sourced =~# ';' . a:lib . ';'
    "    return
    "endif

    if isdirectory(g:rplugin.compldir)
        let fnf = split(globpath(g:rplugin.compldir, 'fun_' . a:lib . '_*'), "\n")
        if len(fnf) == 1 && (!exists("g:R_hi_fun") || g:R_hi_fun != 0)
            "let s:fun_sourced .= a:lib . ';'
            " Highlight R functions
            if !exists("g:R_hi_fun_paren") || g:R_hi_fun_paren == 0
                exe "source " . substitute(fnf[0], ' ', '\\ ', 'g')
            else
                let lines = readfile(fnf[0])
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
        elseif len(fnf) == 0
            let g:rplugin.debug_info['libraries'] += ['Function list for "' . a:lib . '" not found.']
        elseif len(fnf) > 1
            let g:rplugin.debug_info['libraries'] += ['There is more than one function list for "' . a:lib . '".']
            for obl in fnf
                let g:rplugin.debug_info['libraries'] += [obl]
            endfor
        endif
    endif
endfunction

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Omnicompletion functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function RLisObjs(arglead, cmdline, curpos)
    let lob = []
    let rkeyword = '^' . a:arglead
    for xx in s:Rhelp_list
        if xx =~ rkeyword
            call add(lob, xx)
        endif
    endfor
    return lob
endfunction

let s:Rhelp_loaded = []

function AddToRhelpList(lib)
    for lbr in s:Rhelp_loaded
        if lbr == a:lib
            return
        endif
    endfor
    let s:Rhelp_loaded += [a:lib]

    if isdirectory(g:rplugin.compldir)
        let omf = split(globpath(g:rplugin.compldir, 'omnils_' . a:lib . '_*'), "\n")
        if len(omf) == 1
            let g:rplugin.loaded_libs += [a:lib]

            " List of objects
            let olist = readfile(omf[0])

            " Library setwidth has no functions
            if len(olist) == 0 || (len(olist) == 1 && len(olist[0]) < 3)
                return
            endif

            " List of objects for :Rhelp completion
            for xx in olist
                let xxx = split(xx, "\x06")
                if len(xxx) > 0 && xxx[0] !~ '\$'
                    call add(s:Rhelp_list, xxx[0])
                endif
            endfor
        elseif len(omf) == 0
            let g:rplugin.debug_info['libraries'] += ['Omnils list for "' . a:lib . '" not found.']
        elseif len(omf) > 1
            let g:rplugin.debug_info['libraries'] += ['There is more than one omnils and function list for "' . a:lib . '".']
            for obl in omf
                let g:rplugin.debug_info['libraries'] += [obl]
            endfor
        endif
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

" Users may define the value of g:R_start_libs
if !exists("g:R_start_libs")
    let g:R_start_libs = "base,stats,graphics,grDevices,utils,methods"
endif

let s:lists_to_load = split(g:R_start_libs, ',')
for s:lib in s:lists_to_load
    call SourceRFunList(s:lib)
    call AddToRhelpList(s:lib)
endfor
unlet s:lib
