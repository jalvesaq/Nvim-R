
if exists("g:disable_r_ftplugin")
    finish
endif

" Source scripts common to R, Rnoweb, Rhelp and Rdoc:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_global.vim"
if exists("g:rplugin_failed")
    finish
endif

" Some buffer variables common to R, Rnoweb, Rhelp and Rdoc need to be defined
" after the global ones:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_buffer.vim"

let g:R_rnowebchunk = get(g:, "R_rnowebchunk", 1)

if g:R_rnowebchunk == 1
    " Write code chunk in rnoweb files
    inoremap <buffer><silent> < <Esc>:call RWriteChunk()<CR>a
endif

exe "source " . substitute(g:rplugin_home, " ", "\\ ", "g") . "/R/rnw_fun.vim"
call SetPDFdir()

function! s:GetBibFileName()
    if !exists('b:rplugin_bibf')
        let b:rplugin_bibf = []
    endif
    let newbibf = glob(expand("%:p:h") . '/*.bib', 0, 1)
    if newbibf != b:rplugin_bibf
        let b:rplugin_bibf = newbibf
        if IsJobRunning('BibComplete')
            call JobStdin(g:rplugin_jobs["BibComplete"], 'SetBibliography ' . expand("%:p") . "\x05" . join(b:rplugin_bibf, "\x06") . "\n")
        else
            let aa = [g:rplugin_py3, g:rplugin_home . '/R/bibcompl.py'] + [expand("%:p")] + b:rplugin_bibf
            let g:rplugin_jobs["BibComplete"] = StartJob(aa, g:rplugin_job_handlers)
        endif
    endif
endfunction

function! RnwNonRCompletion(findstart, base)
    if a:findstart
        let line = getline(".")
        let cpos = getpos(".")
        let idx = cpos[2] -2
        while line[idx] =~ '\w' && idx > 0
            let idx -= 1
        endwhile
        return idx + 1
    else
        let citekey = substitute(a:base, '^@', '', '')
        let resp = RCompleteBib(citekey)
        return resp
    endif
endfunction

" Use LaTeX-Box completion if available
if exists('*g:LatexBox_Complete')
    let b:rplugin_nonr_omnifunc = "g:LatexBox_Complete"
elseif g:R_bib_disable == 0
    if !exists("g:rplugin_py3")
        call CheckPyBTeX()
    endif
    if !has_key(g:rplugin_debug_info, 'BibComplete')
        " Use BibComplete if possible
        call s:GetBibFileName()
        let b:rplugin_nonr_omnifunc = "RnwNonRCompletion"
        autocmd BufWritePost <buffer> call s:GetBibFileName()
    endif
endif



" Pointers to functions whose purposes are the same in rnoweb, rrst, rmd,
" rhelp and rdoc and which are called at common_global.vim
let b:IsInRCode = function("RnwIsInRCode")
let b:PreviousRChunk = function("RnwPreviousChunk")
let b:NextRChunk = function("RnwNextChunk")
let b:SendChunkToR = function("RnwSendChunkToR")

let b:rplugin_knitr_pattern = "^<<.*>>=$"

"==========================================================================
" Key bindings and menu items

call RCreateStartMaps()
call RCreateEditMaps()
call RCreateSendMaps()
call RControlMaps()
call RCreateMaps("nvi", '<Plug>RSetwd',        'rd', ':call RSetWD()')

" Only .Rnw files use these functions:
call RCreateMaps("nvi", '<Plug>RSweave',      'sw', ':call RWeave("nobib", 0, 0)')
call RCreateMaps("nvi", '<Plug>RMakePDF',     'sp', ':call RWeave("nobib", 0, 1)')
call RCreateMaps("nvi", '<Plug>RBibTeX',      'sb', ':call RWeave("bibtex", 0, 1)')
if exists("g:R_rm_knit_cache") && g:R_rm_knit_cache == 1
    call RCreateMaps("nvi", '<Plug>RKnitRmCache', 'kr', ':call RKnitRmCache()')
endif
call RCreateMaps("nvi", '<Plug>RKnit',        'kn', ':call RWeave("nobib", 1, 0)')
call RCreateMaps("nvi", '<Plug>RMakePDFK',    'kp', ':call RWeave("nobib", 1, 1)')
call RCreateMaps("nvi", '<Plug>RBibTeXK',     'kb', ':call RWeave("bibtex", 1, 1)')
call RCreateMaps("nvi", '<Plug>RIndent',      'si', ':call RnwToggleIndentSty()')
call RCreateMaps("ni",  '<Plug>RSendChunk',   'cc', ':call b:SendChunkToR("silent", "stay")')
call RCreateMaps("ni",  '<Plug>RESendChunk',  'ce', ':call b:SendChunkToR("echo", "stay")')
call RCreateMaps("ni",  '<Plug>RDSendChunk',  'cd', ':call b:SendChunkToR("silent", "down")')
call RCreateMaps("ni",  '<Plug>REDSendChunk', 'ca', ':call b:SendChunkToR("echo", "down")')
call RCreateMaps("nvi", '<Plug>ROpenPDF',     'op', ':call ROpenPDF("Get Master")')
if g:R_synctex
    call RCreateMaps("ni",  '<Plug>RSyncFor',     'gp', ':call SyncTeX_forward()')
    call RCreateMaps("ni",  '<Plug>RGoToTeX',     'gt', ':call SyncTeX_forward(1)')
endif
call RCreateMaps("n",  '<Plug>RNextRChunk',     'gn', ':call b:NextRChunk()')
call RCreateMaps("n",  '<Plug>RPreviousRChunk', 'gN', ':call b:PreviousRChunk()')

" Menu R
if has("gui_running")
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/gui_running.vim"
    call MakeRMenu()
endif

if g:R_synctex && $DISPLAY != "" && g:rplugin_pdfviewer == "evince"
    let g:rplugin_evince_loop = 0
    call Run_EvinceBackward()
endif

call RSourceOtherScripts()

if exists("b:undo_ftplugin")
    let b:undo_ftplugin .= " | unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
else
    let b:undo_ftplugin = "unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
endif
