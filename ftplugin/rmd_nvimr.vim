
if exists("g:disable_r_ftplugin")
    finish
endif


" Source scripts common to R, Rrst, Rnoweb, Rhelp and Rdoc:
runtime R/common_global.vim
if exists("g:rplugin_failed")
    finish
endif

" Some buffer variables common to R, Rmd, Rrst, Rnoweb, Rhelp and Rdoc need to
" be defined after the global ones:
runtime R/common_buffer.vim

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

function! RMakeRmd(t)
    update

    if a:t == "odt"
        if has("win32")
            let g:rplugin_soffbin = "soffice.exe"
        else
            let g:rplugin_soffbin = "soffice"
        endif
        if !executable(g:rplugin_soffbin)
            call RWarningMsg("Is Libre Office installed? Cannot convert into ODT: '" . g:rplugin_soffbin . "' not found.")
            return
        endif
    endif

    let rmddir = expand("%:p:h")
    if has("win32")
        let rmddir = substitute(rmddir, '\\', '/', 'g')
    endif
    if a:t == "default"
        let rcmd = 'nvim.interlace.rmd("' . expand("%:t") . '", rmddir = "' . rmddir . '"'
    else
        let rcmd = 'nvim.interlace.rmd("' . expand("%:t") . '", outform = "' . a:t .'", rmddir = "' . rmddir . '"'
    endif
    if (g:R_openhtml  == 0 && a:t == "html_document") || (g:R_openpdf == 0 && (a:t == "pdf_document" || a:t == "beamer_presentation" || a:t == "word_document"))
        let rcmd .= ", view = FALSE"
    endif
    let rcmd = rcmd . ', envir = ' . g:R_rmd_environment . ')'
    call g:SendCmdToR(rcmd)
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

let b:IsInRCode = function("RmdIsInRCode")
let b:PreviousRChunk = function("RmdPreviousChunk")
let b:NextRChunk = function("RmdNextChunk")
let b:SendChunkToR = function("SendRmdChunkToR")

"==========================================================================
" Key bindings and menu items

call RCreateStartMaps()
call RCreateEditMaps()
call RCreateSendMaps()
call RControlMaps()
call RCreateMaps("nvi", '<Plug>RSetwd',        'rd', ':call RSetWD()')

" Only .Rmd files use these functions:
call RCreateMaps("nvi", '<Plug>RKnit',          'kn', ':call RKnit()')
call RCreateMaps("nvi", '<Plug>RMakeRmd',       'kr', ':call RMakeRmd("default")')
call RCreateMaps("nvi", '<Plug>RMakePDFK',      'kp', ':call RMakeRmd("pdf_document")')
call RCreateMaps("nvi", '<Plug>RMakePDFKb',     'kl', ':call RMakeRmd("beamer_presentation")')
call RCreateMaps("nvi", '<Plug>RMakeWord',      'kw', ':call RMakeRmd("word_document")')
call RCreateMaps("nvi", '<Plug>RMakeHTML',      'kh', ':call RMakeRmd("html_document")')
call RCreateMaps("nvi", '<Plug>RMakeODT',       'ko', ':call RMakeRmd("odt")')
call RCreateMaps("ni",  '<Plug>RSendChunk',     'cc', ':call b:SendChunkToR("silent", "stay")')
call RCreateMaps("ni",  '<Plug>RESendChunk',    'ce', ':call b:SendChunkToR("echo", "stay")')
call RCreateMaps("ni",  '<Plug>RDSendChunk',    'cd', ':call b:SendChunkToR("silent", "down")')
call RCreateMaps("ni",  '<Plug>REDSendChunk',   'ca', ':call b:SendChunkToR("echo", "down")')
call RCreateMaps("n",  '<Plug>RNextRChunk',     'gn', ':call b:NextRChunk()')
call RCreateMaps("n",  '<Plug>RPreviousRChunk', 'gN', ':call b:PreviousRChunk()')

" Menu R
if has("gui_running")
    runtime R/gui_running.vim
    call MakeRMenu()
endif

let g:rplugin_has_pandoc = 0
let g:rplugin_has_soffice = 0

call RSetPDFViewer()

call RSourceOtherScripts()

if exists("b:undo_ftplugin")
    let b:undo_ftplugin .= " | unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
else
    let b:undo_ftplugin = "unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
endif
