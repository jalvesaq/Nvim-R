
if exists("g:R_filetypes") && type(g:R_filetypes) == v:t_list && index(g:R_filetypes, 'rrst') == -1
    finish
endif

" Define some buffer variables common to R, Rnoweb, Rmd, Rrst, Rhelp and rdoc:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_buffer.vim"

function! RrstIsInRCode(vrb)
    let chunkline = search("^\\.\\. {r", "bncW")
    let docline = search("^\\.\\. \\.\\.", "bncW")
    if chunkline == line(".")
        return 2
    elseif chunkline > docline
        return 1
    else
        if a:vrb
            call RWarningMsg("Not inside an R code chunk.")
        endif
        return 0
    endif
endfunction

function! RrstPreviousChunk() range
    let rg = range(a:firstline, a:lastline)
    let chunk = len(rg)
    for var in range(1, chunk)
        let curline = line(".")
        if RrstIsInRCode(0) == 1
            let i = search("^\\.\\. {r", "bnW")
            if i != 0
                call cursor(i-1, 1)
            endif
        endif
        let i = search("^\\.\\. {r", "bnW")
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

function! RrstNextChunk() range
    let rg = range(a:firstline, a:lastline)
    let chunk = len(rg)
    for var in range(1, chunk)
        let i = search("^\\.\\. {r", "nW")
        if i == 0
            call RWarningMsg("There is no next R code chunk to go.")
            return
        else
            call cursor(i+1, 1)
        endif
    endfor
    return
endfunction

function! RMakeHTMLrrst(t)
    call RSetWD()
    update
    if s:has_rst2pdf == 0
        if executable("rst2pdf")
            let s:has_rst2pdf = 1
        else
            call RWarningMsg("Is 'rst2pdf' application installed? Cannot convert into HTML/ODT: 'rst2pdf' executable not found.")
            return
        endif
    endif

    let rcmd = 'require(knitr)'
    if g:R_strict_rst
        let rcmd = rcmd . '; render_rst(strict=TRUE)'
    endif
    let rcmd = rcmd . '; knit("' . expand("%:t") . '")'

    if a:t == "odt"
        let rcmd = rcmd . '; system("rst2odt ' . expand("%:r:t") . ".rst " . expand("%:r:t") . '.odt")'
    else
        let rcmd = rcmd . '; system("rst2html ' . expand("%:r:t") . ".rst " . expand("%:r:t") . '.html")'
    endif

    if g:R_openhtml && a:t == "html"
        let rcmd = rcmd . '; browseURL("' . expand("%:r:t") . '.html")'
    endif
    call g:SendCmdToR(rcmd)
endfunction

function! RMakePDFrrst()
    if !has_key(g:rplugin, "pdfviewer")
        call RSetPDFViewer()
    endif

    update
    call RSetWD()
    if s:has_rst2pdf == 0
        if exists("g:R_rst2pdfpath") && executable(g:R_rst2pdfpath)
            let s:has_rst2pdf = 1
        elseif executable("rst2pdf")
            let s:has_rst2pdf = 1
        else
            call RWarningMsg("Is 'rst2pdf' application installed? Cannot convert into PDF: 'rst2pdf' executable not found.")
            return
        endif
    endif

    let rrstdir = expand("%:p:h")
    if has("win32")
        let rrstdir = substitute(rrstdir, '\\', '/', 'g')
    endif
    let pdfcmd = 'nvim.interlace.rrst("' . expand("%:t") . '", rrstdir = "' . rrstdir . '"'
    if exists("g:R_rrstcompiler")
        let pdfcmd = pdfcmd . ", compiler='" . g:R_rrstcompiler . "'"
    endif
    if exists("g:R_knitargs")
        let pdfcmd = pdfcmd . ", " . g:R_knitargs
    endif
    if exists("g:R_rst2pdfpath")
        let pdfcmd = pdfcmd . ", rst2pdfpath='" . g:R_rst2pdfpath . "'"
    endif
    if exists("g:R_rst2pdfargs")
        let pdfcmd = pdfcmd . ", " . g:R_rst2pdfargs
    endif
    let pdfcmd = pdfcmd . ")"
    let ok = g:SendCmdToR(pdfcmd)
    if ok == 0
        return
    endif
endfunction

" Send Rrst chunk to R
function! SendRrstChunkToR(e, m)
    if RrstIsInRCode(0) == 2
        call cursor(line(".")+1, 1)
    elseif RrstIsInRCode(0)
        call RWarningMsg("Not inside an R code chunk.")
        return
    endif
    let chunkline = search("^\\.\\. {r", "bncW") + 1
    let docline = search("^\\.\\. \\.\\.", "ncW") - 1
    let lines = getline(chunkline, docline)
    let ok = RSourceLines(lines, a:e, "chunk")
    if ok == 0
        return
    endif
    if a:m == "down"
        call RrstNextChunk()
    endif
endfunction

let b:IsInRCode = function("RrstIsInRCode")
let b:PreviousRChunk = function("RrstPreviousChunk")
let b:NextRChunk = function("RrstNextChunk")
let b:SendChunkToR = function("SendRrstChunkToR")

let b:rplugin_knitr_pattern = "^.. {r.*}$"

"==========================================================================
" Key bindings and menu items

call RCreateStartMaps()
call RCreateEditMaps()
call RCreateSendMaps()
call RControlMaps()
call RCreateMaps('nvi', 'RSetwd',          'rd', ':call RSetWD()')

" Only .Rrst files use these functions:
call RCreateMaps('nvi', 'RKnit',           'kn', ':call RKnit()')
call RCreateMaps('nvi', 'RMakePDFK',       'kp', ':call RMakePDFrrst()')
call RCreateMaps('nvi', 'RMakeHTML',       'kh', ':call RMakeHTMLrrst("html")')
call RCreateMaps('nvi', 'RMakeODT',        'ko', ':call RMakeHTMLrrst("odt")')
call RCreateMaps('nvi', 'RIndent',         'si', ':call RrstToggleIndentSty()')
call RCreateMaps('ni',  'RSendChunk',      'cc', ':call b:SendChunkToR("silent", "stay")')
call RCreateMaps('ni',  'RESendChunk',     'ce', ':call b:SendChunkToR("echo", "stay")')
call RCreateMaps('ni',  'RDSendChunk',     'cd', ':call b:SendChunkToR("silent", "down")')
call RCreateMaps('ni',  'REDSendChunk',    'ca', ':call b:SendChunkToR("echo", "down")')
call RCreateMaps('n',   'RNextRChunk',     'gn', ':call b:NextRChunk()')
call RCreateMaps('n',   'RPreviousRChunk', 'gN', ':call b:PreviousRChunk()')

let g:R_strict_rst = get(g:, "R_strict_rst",         1)

" Menu R
if has("gui_running")
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/gui_running.vim"
    call MakeRMenu()
endif

let s:has_rst2pdf = 0

call RSourceOtherScripts()

function! RPDFinit(...)
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/pdf_init.vim"
endfunction

call timer_start(1, "RPDFinit")

if exists("b:undo_ftplugin")
    let b:undo_ftplugin .= " | unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
else
    let b:undo_ftplugin = "unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
endif
