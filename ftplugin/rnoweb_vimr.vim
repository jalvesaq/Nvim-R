
if exists("g:R_filetypes") && type(g:R_filetypes) == v:t_list && index(g:R_filetypes, 'rnoweb') == -1
    finish
endif

" Define some buffer variables common to R, Rnoweb, Rmd, Rrst, Rhelp and rdoc:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_buffer.vim"

" Bibliographic completion
if index(g:R_bib_compl, 'rnoweb') > -1
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/bibcompl.vim"
endif

if exists('g:R_cite_pattern')
    let s:cite_ptrn = g:R_cite_pattern
elseif exists('g:LatexBox_cite_pattern')
    let s:cite_ptrn = g:LatexBox_cite_pattern
else
    " From LaTeX-Box/ftplugin/latex-box/complete.vim:
    let s:cite_ptrn = '\C\\\a*cite\a*\*\?\(\[[^\]]*\]\)*\_\s*{'
endif

let g:R_rnowebchunk = get(g:, "R_rnowebchunk", 1)

if g:R_rnowebchunk == 1
    " Write code chunk in rnoweb files
    inoremap <buffer><silent> < <Esc>:call RWriteChunk()<CR>a
endif

exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/rnw_fun.vim"

function! s:CompleteEnv(base)
    " List from LaTeX-Box
    let lenv = ['abstract]', 'align*}', 'align}', 'center}', 'description}',
                \ 'document}', 'enumerate}', 'equation}', 'figure}',
                \ 'itemize}', 'table}', 'tabular}']

    call filter(lenv, 'v:val =~ "' . a:base . '"')

    call sort(lenv)
    let rr = []
    for env in lenv
        call add(rr, {'word': env})
    endfor
    return rr
endfunction

function! s:CompleteLaTeXCmd(base)
    " List from LaTeX-Box
    let lcmd = ['\begin{', '\bottomrule', '\caption', '\chapter', '\cite',
                \ '\citep', '\citet', '\cmidrule{', '\end{', '\eqref', '\hline',
                \ '\includegraphics', '\item', '\label', '\midrule', '\multicolumn{',
                \ '\multirow{', '\newcommand', '\pageref', '\ref', '\section{',
                \ '\subsection{', '\subsubsection{', '\toprule', '\usepackage{']

    let newbase = '\' . a:base
    call filter(lcmd, 'v:val =~ newbase')

    call sort(lcmd)
    let rr = []
    for cmd in lcmd
        call add(rr, {'word': cmd})
    endfor
    return rr
endfunction

function! s:CompleteRef(base)
    " Get \label{abc}
    let lines = getline(1, '$')
    let bigline = join(lines)
    let labline = substitute(bigline, '^.\{-}\\label{', '', 'g')
    let labline = substitute(labline, '\\label{', "\x05", 'g')
    let labels = split(labline, "\x05")
    call map(labels, 'substitute(v:val, "}.*", "", "g")')
    call filter(labels, 'len(v:val) < 40')

    " Get chunk label if it has fig.cap
    let lfig = copy(lines)
    call filter(lfig, 'v:val =~ "^<<.*fig\\.cap\\s*="')
    call map(lfig, 'substitute(v:val, "^<<", "", "")')
    call map(lfig, 'substitute(v:val, ",.*", "", "")')
    call map(lfig, '"fig:" . v:val')
    let labels += lfig

    " Get label="tab:abc"
    call filter(lines, 'v:val =~ "label\\s*=\\s*.tab:"')
    call map(lines, 'substitute(v:val, ".*label\\s*=\\s*.", "", "")')
    call map(lines, 'substitute(v:val, "' . "'" . '.*", "", "")')
    call map(lines, "substitute(v:val, '" . '"' . ".*', '', '')")
    let labels += lines

    call filter(labels, 'v:val =~ "^' . a:base . '"')

    let resp = []
    for lbl in labels
        call add(resp, {'word': lbl})
    endfor
    return resp
endfunction

let s:compl_type = 0

function! RnwNonRCompletion(findstart, base)
    if a:findstart
        let line = getline('.')
        let idx = col('.') - 2
        let widx = idx

        " Where is the cursor in 'text \command{ } text'?
        let s:compl_type = 0
        while idx >= 0
            if line[idx] =~ '\w'
                let widx = idx
            elseif line[idx] == '\'
                let s:compl_type = 1
                return idx
            elseif line[idx] == '{'
                let s:compl_type = 2
                return widx
            elseif line[idx] == '}'
                return widx
            endif
            let idx -= 1
        endwhile
    else
        if s:compl_type == 0
            return []
        elseif s:compl_type == 1
            return s:CompleteLaTeXCmd(a:base)
        endif

        let line = getline('.')
        let cpos = getpos(".")
        let idx = cpos[2] - 2
        let piece = line[0:idx]
        let piece = substitute(piece, ".*\\", "\\", '')
        let piece = substitute(piece, ".*}", "", '')

        " Get completions even for 'empty' base
        if piece =~ '^\\' && a:base == '{'
            let piece .= '{'
            let newbase = ''
        else
            let newbase = a:base
        endif

        if newbase != '' && piece =~ s:cite_ptrn
            return RCompleteBib(newbase)
        elseif piece == '\begin{'
            let s:compl_type = 9
            return s:CompleteEnv(newbase)
        elseif piece == '\ref{' || piece == '\pageref{'
            return s:CompleteRef(newbase)
        endif

        return []
    endif
endfunction

function! RnwOnCompleteDone()
    if s:compl_type == 9
        let s:compl_type = 0
        if has_key(v:completed_item, 'word')
            call append(line('.'), [repeat(' ', indent(line('.'))) . '\end{' . v:completed_item['word']])
        endif
    endif
endfunction


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
call RCreateMaps('nvi', 'RSetwd',        'rd', ':call RSetWD()')

" Only .Rnw files use these functions:
call RCreateMaps('nvi', 'RSweave',      'sw', ':call RWeave("nobib", 0, 0)')
call RCreateMaps('nvi', 'RMakePDF',     'sp', ':call RWeave("nobib", 0, 1)')
call RCreateMaps('nvi', 'RBibTeX',      'sb', ':call RWeave("bibtex", 0, 1)')
if exists("g:R_rm_knit_cache") && g:R_rm_knit_cache == 1
    call RCreateMaps('nvi', 'RKnitRmCache', 'kr', ':call RKnitRmCache()')
endif
call RCreateMaps('nvi', 'RKnit',        'kn', ':call RWeave("nobib", 1, 0)')
call RCreateMaps('nvi', 'RMakePDFK',    'kp', ':call RWeave("nobib", 1, 1)')
call RCreateMaps('nvi', 'RBibTeXK',     'kb', ':call RWeave("bibtex", 1, 1)')
call RCreateMaps('ni',  'RSendChunk',   'cc', ':call b:SendChunkToR("silent", "stay")')
call RCreateMaps('ni',  'RESendChunk',  'ce', ':call b:SendChunkToR("echo", "stay")')
call RCreateMaps('ni',  'RDSendChunk',  'cd', ':call b:SendChunkToR("silent", "down")')
call RCreateMaps('ni',  'REDSendChunk', 'ca', ':call b:SendChunkToR("echo", "down")')
call RCreateMaps('nvi', 'ROpenPDF',     'op', ':call ROpenPDF("Get Master")')
if g:R_synctex
    call RCreateMaps('ni', 'RSyncFor',  'gp', ':call SyncTeX_forward()')
    call RCreateMaps('ni', 'RGoToTeX',  'gt', ':call SyncTeX_forward(1)')
endif
call RCreateMaps('n', 'RNextRChunk',     'gn', ':call b:NextRChunk()')
call RCreateMaps('n', 'RPreviousRChunk', 'gN', ':call b:PreviousRChunk()')

" Menu R
if has("gui_running")
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/gui_running.vim"
    call MakeRMenu()
endif

call RSourceOtherScripts()

if g:R_non_r_compl && index(g:R_bib_compl, 'rnoweb') > -1
    call timer_start(1, "CheckPyBTeX")
endif

function! RPDFinit(...)
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/pdf_init.vim"
endfunction

call timer_start(1, "RPDFinit")

if exists("b:undo_ftplugin")
    let b:undo_ftplugin .= " | unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
else
    let b:undo_ftplugin = "unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
endif
