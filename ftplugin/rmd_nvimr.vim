
if exists("g:disable_r_ftplugin")
    finish
endif

" Source scripts common to R, Rrst, Rnoweb, Rhelp and Rdoc:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_global.vim"
if exists("g:rplugin_failed")
    finish
endif

" Some buffer variables common to R, Rmd, Rrst, Rnoweb, Rhelp and Rdoc need to
" be defined after the global ones:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_buffer.vim"

" Bibliographic completion
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/bibcompl.vim"

let g:R_rmdchunk = get(g:, "R_rmdchunk", 1)

if g:R_rmdchunk == 1
    " Write code chunk in rnoweb files
    inoremap <buffer><silent> ` <Esc>:call RWriteRmdChunk()<CR>a
endif

function! RWriteRmdChunk()
    if getline(".") =~ "^\\s*$" && RmdIsInRCode(0) == 0
        let curline = line(".")
        call setline(curline, "```{r}")
        call append(curline, ["```", ""])
        call cursor(curline, 5)
    else
        exe "normal! a`"
    endif
endfunction

function! s:GetYamlField(field)
    let value = []
    let lastl = line('$')
    let idx = 2
    while idx < lastl
        let line = getline(idx)
        if line == '...' || line == '---'
            break
        endif
        if line =~ '^\s*' . a:field . '\s*:'
            let bstr = substitute(line, '^\s*' . a:field . '\s*:\s*\(.*\)\s*', '\1', '')
            if bstr =~ '^".*"$' || bstr =~ "^'.*'$"
                let bib = substitute(bstr, '"', '', 'g')
                let bib = substitute(bib, "'", '', 'g')
                let bibl = [bib]
            elseif bstr =~ '^\[.*\]$'
                try
                    let l:bbl = eval(bstr)
                catch *
                    call RWarningMsg('YAML line invalid for Vim: ' . line)
                    let bibl = []
                endtry
                if exists('l:bbl')
                    let bibl = l:bbl
                endif
            else
                let bibl = [bstr]
            endif
            for fn in bibl
                call add(value, fn)
            endfor
            break
        endif
        let idx += 1
    endwhile
    if value == []
        return ''
    endif
    if a:field == "bibliography"
        call map(value, "expand(v:val)")
    endif
    return join(value, "\x06")
endfunction

function! s:GetBibFileName()
    if !exists('b:rplugin_bibf')
        let b:rplugin_bibf = ''
    endif
    let newbibf = s:GetYamlField('bibliography')
    if newbibf == ''
        let newbibf = join(glob(expand("%:p:h") . '/*.bib', 0, 1), "\x06")
    endif
    if newbibf != b:rplugin_bibf
        let b:rplugin_bibf = newbibf
        if IsJobRunning('BibComplete')
            call JobStdin(g:rplugin_jobs["BibComplete"], "\x04" . expand("%:p") . "\x05" . b:rplugin_bibf . "\n")
        else
            let aa = [g:rplugin_py3, g:rplugin_home . '/R/bibtex.py', expand("%:p"), b:rplugin_bibf]
            let g:rplugin_jobs["BibComplete"] = StartJob(aa, g:rplugin_job_handlers)
            call RCreateMaps("n",  '<Plug>ROpenRefFile',   'od', ':call GetBibAttachment()')
        endif
    endif
endfunction

function! RmdIsInRCode(vrb)
    let chunkline = search("^[ \t]*```[ ]*{r", "bncW")
    let docline = search("^[ \t]*```$", "bncW")
    if chunkline > docline && chunkline != line(".")
        return 1
    else
        if a:vrb
            call RWarningMsg("Not inside an R code chunk.")
        endif
        return 0
    endif
endfunction

function! RmdPreviousChunk() range
    let rg = range(a:firstline, a:lastline)
    let chunk = len(rg)
    for var in range(1, chunk)
        let curline = line(".")
        if RmdIsInRCode(0)
            let i = search("^[ \t]*```[ ]*{r", "bnW")
            if i != 0
                call cursor(i-1, 1)
            endif
        endif
        let i = search("^[ \t]*```[ ]*{r", "bnW")
        if i == 0
            call cursor(curline, 1)
            call RWarningMsg("There is no previous R code chunk to go.")
            return
        else
            call cursor(i+1, 1)
        endif
    endfor
    return
endfunction

function! RmdNextChunk() range
    let rg = range(a:firstline, a:lastline)
    let chunk = len(rg)
    for var in range(1, chunk)
        let i = search("^[ \t]*```[ ]*{r", "nW")
        if i == 0
            call RWarningMsg("There is no next R code chunk to go.")
            return
        else
            call cursor(i+1, 1)
        endif
    endfor
    return
endfunction


" Send Rmd chunk to R
function! SendRmdChunkToR(e, m)
    if RmdIsInRCode(0) == 0
        call RWarningMsg("Not inside an R code chunk.")
        return
    endif
    let chunkline = search("^[ \t]*```[ ]*{r", "bncW") + 1
    let docline = search("^[ \t]*```", "ncW") - 1
    let lines = getline(chunkline, docline)
    let ok = RSourceLines(lines, a:e)
    if ok == 0
        return
    endif
    if a:m == "down"
        call RmdNextChunk()
    endif
endfunction

function! RmdNonRCompletion(findstart, base)
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
        return RCompleteBib(citekey)
    endif
endfunction

" If zotcite is installed, use it
if exists('*zotcite#CompleteBib')
    let b:rplugin_non_r_omnifunc = 'zotcite#CompleteBib'
elseif g:R_non_r_compl
    call CheckPyBTeX()
    if !has_key(g:rplugin_debug_info, 'BibComplete')
        call s:GetBibFileName()
        let b:rplugin_non_r_omnifunc = "RmdNonRCompletion"
        if !exists("b:rplugin_did_bib_autocmd")
            let b:rplugin_did_bib_autocmd = 1
            autocmd BufWritePost <buffer> call s:GetBibFileName()
        endif
    endif
endif

" If zotcite is not installed and PyBTeX is not available, try pandoc
if b:rplugin_non_r_omnifunc == '' && exists('*pandoc#completion#Complete')
    let b:rplugin_non_r_omnifunc = 'pandoc#completion#Complete'
endif

let b:IsInRCode = function("RmdIsInRCode")
let b:PreviousRChunk = function("RmdPreviousChunk")
let b:NextRChunk = function("RmdNextChunk")
let b:SendChunkToR = function("SendRmdChunkToR")

let b:rplugin_knitr_pattern = "^``` *{r.*}$"

"==========================================================================
" Key bindings and menu items

call RCreateStartMaps()
call RCreateEditMaps()
call RCreateSendMaps()
call RControlMaps()
call RCreateMaps("nvi", '<Plug>RSetwd',        'rd', ':call RSetWD()')

" Only .Rmd files use these functions:
call RCreateMaps("nvi", '<Plug>RKnit',          'kn', ':call RKnit()')
call RCreateMaps("ni",  '<Plug>RSendChunk',     'cc', ':call b:SendChunkToR("silent", "stay")')
call RCreateMaps("ni",  '<Plug>RESendChunk',    'ce', ':call b:SendChunkToR("echo", "stay")')
call RCreateMaps("ni",  '<Plug>RDSendChunk',    'cd', ':call b:SendChunkToR("silent", "down")')
call RCreateMaps("ni",  '<Plug>REDSendChunk',   'ca', ':call b:SendChunkToR("echo", "down")')
call RCreateMaps("n",  '<Plug>RNextRChunk',     'gn', ':call b:NextRChunk()')
call RCreateMaps("n",  '<Plug>RPreviousRChunk', 'gN', ':call b:PreviousRChunk()')

" Menu R
if has("gui_running")
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/gui_running.vim"
    call MakeRMenu()
endif

call RSourceOtherScripts()

if exists("b:undo_ftplugin")
    let b:undo_ftplugin .= " | unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
else
    let b:undo_ftplugin = "unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
endif
