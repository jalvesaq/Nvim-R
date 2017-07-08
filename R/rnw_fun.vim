
" Source functions only once
if exists("*RWriteChunk")
    finish
endif

let g:R_latexmk = get(g:, "R_latexmk", 1)
if !exists("s:has_latexmk")
    if g:R_latexmk && executable("latexmk") && executable("perl")
        let s:has_latexmk = 1
    else
        let s:has_latexmk = 0
    endif
endif

function RWriteChunk()
    if getline(".") =~ "^\\s*$" && RnwIsInRCode(0) == 0
        call setline(line("."), "<<>>=")
        exe "normal! o@"
        exe "normal! 0kl"
    else
        exe "normal! a<"
    endif
endfunction

function RnwIsInRCode(vrb)
    let chunkline = search("^<<", "bncW")
    let docline = search("^@", "bncW")
    if chunkline > docline && chunkline != line(".")
        return 1
    else
        if a:vrb
            call RWarningMsg("Not inside an R code chunk.")
        endif
        return 0
    endif
endfunction

function RnwPreviousChunk() range
    let rg = range(a:firstline, a:lastline)
    let chunk = len(rg)
    for var in range(1, chunk)
        let curline = line(".")
        if RnwIsInRCode(0)
            let i = search("^<<.*$", "bnW")
            if i != 0
                call cursor(i-1, 1)
            endif
        endif
        let i = search("^<<.*$", "bnW")
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

function RnwNextChunk() range
    let rg = range(a:firstline, a:lastline)
    let chunk = len(rg)
    for var in range(1, chunk)
        let i = search("^<<.*$", "nW")
        if i == 0
            call RWarningMsg("There is no next R code chunk to go.")
            return
        else
            call cursor(i+1, 1)
        endif
    endfor
    return
endfunction


" Because this function delete files, it will not be documented.
" If you want to try it, put in your vimrc:
"
" let R_rm_knit_cache = 1
"
" If don't want to answer the question about deleting files, and
" if you trust this code more than I do, put in your vimrc:
"
" let R_ask_rm_knitr_cache = 0
"
" Note that if you have the string "cache.path=" in more than one place only
" the first one above the cursor position will be found. The path must be
" surrounded by quotes; if it's an R object, it will not be recognized.
function RKnitRmCache()
    let lnum = search('\<cache\.path\>\s*=', 'bnwc')
    if lnum == 0
        let pathdir = "cache/"
    else
        let pathregexpr = '.*\<cache\.path\>\s*=\s*[' . "'" . '"]\(.\{-}\)[' . "'" . '"].*'
        let pathdir = substitute(getline(lnum), pathregexpr, '\1', '')
        if pathdir !~ '/$'
            let pathdir .= '/'
        endif
    endif
    if exists("g:R_ask_rm_knitr_cache") && g:R_ask_rm_knitr_cache == 0
        let cleandir = 1
    else
        call inputsave()
        let answer = input('Delete all files from "' . pathdir . '"? [y/n]: ')
        call inputrestore()
        if answer == "y"
            let cleandir = 1
        else
            let cleandir = 0
        endif
    endif
    normal! :<Esc>
    if cleandir
        call g:SendCmdToR('rm(list=ls(all.names=TRUE)); unlink("' . pathdir . '*")')
    endif
endfunction

" Weave and compile the current buffer content
function RWeave(bibtex, knit, pdf)
    if g:rplugin_nvimcom_port == 0
        call RWarningMsg("The nvimcom package is required to make and open the PDF.")
    endif
    update
    let rnwdir = expand("%:p:h")
    if has("win32")
        let rnwdir = substitute(rnwdir, '\\', '/', 'g')
    endif
    let pdfcmd = 'nvim.interlace.rnoweb("' . expand("%:t") . '", rnwdir = "' . rnwdir . '"'

    if a:knit == 0
        let pdfcmd = pdfcmd . ', knit = FALSE'
    endif

    if a:pdf == 0
        let pdfcmd = pdfcmd . ', buildpdf = FALSE'
    endif

    if s:has_latexmk == 0
        let pdfcmd = pdfcmd . ', latexmk = FALSE'
    endif

    if g:R_latexcmd != "default"
        let pdfcmd = pdfcmd . ", latexcmd = '" . g:R_latexcmd . "'"
    endif

    if g:R_synctex == 0
        let pdfcmd = pdfcmd . ", synctex = FALSE"
    endif

    if a:bibtex == "bibtex"
        let pdfcmd = pdfcmd . ", bibtex = TRUE"
    endif

    if a:pdf == 0 || g:R_openpdf == 0 || b:pdf_is_open
        let pdfcmd = pdfcmd . ", view = FALSE"
    endif

    if a:pdf && g:R_openpdf == 1
        let b:pdf_is_open = 1
    endif

    if a:knit == 0 && exists("g:R_sweaveargs")
        let pdfcmd = pdfcmd . ", " . g:R_sweaveargs
    endif

    let pdfcmd = pdfcmd . ")"
    call g:SendCmdToR(pdfcmd)
endfunction

" Send Sweave chunk to R
function RnwSendChunkToR(e, m)
    if RnwIsInRCode(0) == 0
        call RWarningMsg("Not inside an R code chunk.")
        return
    endif
    let chunkline = search("^<<", "bncW") + 1
    let docline = search("^@", "ncW") - 1
    let lines = getline(chunkline, docline)
    let ok = RSourceLines(lines, a:e)
    if ok == 0
        return
    endif
    if a:m == "down"
        call RnwNextChunk()
    endif
endfunction

function SyncTeX_GetMaster()
    if filereadable(expand("%:p:r") . "-concordance.tex")
        if has("win32")
            return substitute(expand("%:p:r"), '\\', '/', 'g')
        else
            return expand("%:p:r")
        endif
    endif

    let ischild = search('% *!Rnw *root *=', 'bwn')
    if ischild
        let mfile = substitute(getline(ischild), '.*% *!Rnw *root *= *\(.*\) *', '\1', '')
        if mfile =~ "/"
            let mdir = substitute(mfile, '\(.*\)/.*', '\1', '')
            let mfile = substitute(mfile, '.*/', '', '')
            if mdir == '..'
                let mdir = expand("%:p:h:h")
            endif
        else
            let mdir = expand("%:p:h")
        endif
        let basenm = substitute(mfile, '\....$', '', '')
        if has("win32")
            return substitute(mdir, '\\', '/', 'g') . "/" . basenm
        else
            return mdir . "/" . basenm
        endif
    endif

    " Maybe this buffer is a master Rnoweb not compiled yet.
    if has("win32")
        return substitute(expand("%:p:r"), '\\', '/', 'g')
    else
        return expand("%:p:r")
    endif
endfunction

" See http://www.stats.uwo.ca/faculty/murdoch/9864/Sweave.pdf page 25
function SyncTeX_readconc(basenm)
    let texidx = 0
    let rnwidx = 0
    let ntexln = len(readfile(a:basenm . ".tex"))
    let lstexln = range(1, ntexln)
    let lsrnwf = range(1, ntexln)
    let lsrnwl = range(1, ntexln)
    let conc = readfile(a:basenm . "-concordance.tex")
    let idx = 0
    let maxidx = len(conc)
    while idx < maxidx && texidx < ntexln && conc[idx] =~ "Sconcordance"
        let texf = substitute(conc[idx], '\\Sconcordance{concordance:\(.\{-}\):.*', '\1', "g")
        let rnwf = substitute(conc[idx], '\\Sconcordance{concordance:.\{-}:\(.\{-}\):.*', '\1', "g")
        let idx += 1
        let concnum = ""
        while idx < maxidx && conc[idx] !~ "Sconcordance"
            let concnum = concnum . conc[idx]
            let idx += 1
        endwhile
        let concnum = substitute(concnum, '%', '', 'g')
        let concnum = substitute(concnum, '}', '', '')
        let concl = split(concnum)
        let ii = 0
        let maxii = len(concl) - 2
        let rnwl = str2nr(concl[0])
        let lsrnwl[texidx] = rnwl
        let lsrnwf[texidx] = rnwf
        let texidx += 1
        while ii < maxii && texidx < ntexln
            let ii += 1
            let lnrange = range(1, concl[ii])
            let ii += 1
            for iii in lnrange
                if  texidx >= ntexln
                    break
                endif
                let rnwl += concl[ii]
                let lsrnwl[texidx] = rnwl
                let lsrnwf[texidx] = rnwf
                let texidx += 1
            endfor
        endwhile
    endwhile
    return {"texlnum": lstexln, "rnwfile": lsrnwf, "rnwline": lsrnwl}
endfunction

function GoToBuf(rnwbn, rnwf, basedir, rnwln)
    if expand("%:t") != a:rnwbn
        if bufloaded(a:basedir . '/' . a:rnwf)
            let savesb = &switchbuf
            set switchbuf=useopen,usetab
            exe "sb " . substitute(a:basedir . '/' . a:rnwf, ' ', '\\ ', 'g')
            exe "set switchbuf=" . savesb
        elseif bufloaded(a:rnwf)
            let savesb = &switchbuf
            set switchbuf=useopen,usetab
            exe "sb " . substitute(a:rnwf, ' ', '\\ ', 'g')
            exe "set switchbuf=" . savesb
        else
            if filereadable(a:basedir . '/' . a:rnwf)
                exe "tabnew " . substitute(a:basedir . '/' . a:rnwf, ' ', '\\ ', 'g')
            elseif filereadable(a:rnwf)
                exe "tabnew " . substitute(a:rnwf, ' ', '\\ ', 'g')
            else
                call RWarningMsg('Could not find either "' . a:rnwbn . ' or "' . a:rnwf . '" in "' . a:basedir . '".')
                return 0
            endif
        endif
    endif
    exe a:rnwln
    redraw
    return 1
endfunction

function SyncTeX_backward(fname, ln)
    let g:TheFnameLn = [a:fname, a:ln]
    let flnm = substitute(a:fname, '/\./', '/', '')   " Okular
    let basenm = substitute(flnm, "\....$", "", "")   " Delete extension
    if basenm =~ "/"
        let basedir = substitute(basenm, '\(.*\)/.*', '\1', '')
    else
        let basedir = '.'
    endif
    if filereadable(basenm . "-concordance.tex")
        if !filereadable(basenm . ".tex")
            call RWarningMsg('SyncTeX [Nvim-R]: "' . basenm . '.tex" not found.')
            return
        endif
        let concdata = SyncTeX_readconc(basenm)
        let texlnum = concdata["texlnum"]
        let rnwfile = concdata["rnwfile"]
        let rnwline = concdata["rnwline"]
        let rnwln = 0
        for ii in range(len(texlnum))
            if texlnum[ii] >= a:ln
                let rnwf = rnwfile[ii]
                let rnwln = rnwline[ii]
                break
            endif
        endfor
        if rnwln == 0
            call RWarningMsg("Could not find Rnoweb source line.")
            return
        endif
    else
        if filereadable(basenm . ".Rnw") || filereadable(basenm . ".rnw")
            call RWarningMsg('SyncTeX [Nvim-R]: "' . basenm . '-concordance.tex" not found.')
            return
        elseif filereadable(flnm)
            let rnwf = flnm
            let rnwln = a:ln
        else
            call RWarningMsg("Could not find '" . basenm . ".Rnw'.")
            return
        endif
    endif

    let rnwbn = substitute(rnwf, '.*/', '', '')
    let rnwf = substitute(rnwf, '^\./', '', '')

    if GoToBuf(rnwbn, rnwf, basedir, rnwln)
        if g:rplugin_has_wmctrl
            if v:windowid != 0
                call system("wmctrl -ia " . v:windowid)
            elseif $WINDOWID != ""
                call system("wmctrl -ia " . $WINDOWID)
            endif
        elseif has("gui_running")
            if has("win32")
                " Attempt 1
                call JobStdin(g:rplugin_jobs["ClientServer"], "\007\n")

                " Attempt 2
                " if has("nvim")
                "     call rpcnotify(0, 'Gui', 'Foreground')
                " else
                "     call foreground()
            else
                call foreground()
            endif
        endif
    endif
endfunction

function SyncTeX_forward(...)
    let basenm = expand("%:t:r")
    let lnum = 0
    let rnwf = expand("%:t")

    if filereadable(expand("%:p:r") . "-concordance.tex")
        let lnum = line(".")
    else
        let ischild = search('% *!Rnw *root *=', 'bwn')
        if ischild
            let mfile = substitute(getline(ischild), '.*% *!Rnw *root *= *\(.*\) *', '\1', '')
            let basenm = substitute(mfile, '\....$', '', '')
            if filereadable(expand("%:p:h") . "/" . basenm . "-concordance.tex")
                let mlines = readfile(expand("%:p:h") . "/" . mfile)
                for ii in range(len(mlines))
                    " Sweave has detailed child information
                    if mlines[ii] =~ 'SweaveInput.*' . expand("%:t")
                        let lnum = line(".")
                        break
                    endif
                    " Knitr does not include detailed child information
                    if mlines[ii] =~ '<<.*child *=.*' . expand("%:t") . '["' . "']"
                        let lnum = ii + 1
                        let rnwf = expand("%:p:h") . "/" . mfile
                        break
                    endif
                endfor
                if lnum == 0
                    call RWarningMsg('Could not find "child=' . expand("%:t") . '" in ' . expand("%:p:h") . "/" . mfile . '.')
                    return
                endif
            else
                call RWarningMsg('Nvim-R [SyncTeX]: "' . basenm . '-concordance.tex" not found.')
                return
            endif
        else
            call RWarningMsg('SyncTeX [Nvim-R]: "' . basenm . '-concordance.tex" not found.')
            return
        endif
    endif

    if !filereadable(expand("%:p:h") . "/" . basenm . ".tex")
        call RWarningMsg('"' . expand("%:p:h") . "/" . basenm . '.tex" not found.')
        return
    endif
    let concdata = SyncTeX_readconc(expand("%:p:h") . "/" . basenm)
    let rnwf = substitute(rnwf, ".*/", "", "")
    let texlnum = concdata["texlnum"]
    let rnwfile = concdata["rnwfile"]
    let rnwline = concdata["rnwline"]
    let texln = 0
    for ii in range(len(texlnum))
        if rnwfile[ii] =~ rnwf && rnwline[ii] >= lnum
            let texln = texlnum[ii]
            break
        endif
    endfor

    if texln == 0
        call RWarningMsg("Error: did not find LaTeX line.")
        return
    endif
    if basenm =~ '/'
        let basedir = substitute(basenm, '\(.*\)/.*', '\1', '')
        let basenm = substitute(basenm, '.*/', '', '')
        exe "cd " . substitute(basedir, ' ', '\\ ', 'g')
    else
        let basedir = ''
    endif

    if a:0 && a:1
        call GoToBuf(basenm . ".tex", basenm . ".tex", basedir, texln)
        return
    endif

    if !filereadable(b:rplugin_pdfdir . "/" . basenm . ".pdf")
        call RWarningMsg('SyncTeX forward cannot be done because the file "' . b:rplugin_pdfdir . "/" . basenm . '.pdf" is missing.')
        return
    endif
    if !filereadable(b:rplugin_pdfdir . "/" . basenm . ".synctex.gz")
        call RWarningMsg('SyncTeX forward cannot be done because the file "' . b:rplugin_pdfdir . "/" . basenm . '.synctex.gz" is missing.')
        if g:R_latexcmd != "default" && g:R_latexcmd !~ "synctex"
            call RWarningMsg('Note: The string "-synctex=1" is not in your R_latexcmd. Please check your vimrc.')
        endif
        return
    endif

    call SyncTeX_forward2(SyncTeX_GetMaster() . '.tex', b:rplugin_pdfdir . "/" . basenm . ".pdf", texln, 1)
endfunction

function SetPDFdir()
    let master = SyncTeX_GetMaster()
    let mdir = substitute(master, '\(.*\)/.*', '\1', '')
    let b:rplugin_pdfdir = "."
    " Latexmk has an option to create the PDF in a directory other than '.'
    if (g:R_latexcmd =~ "default" || g:R_latexcmd =~ "latexmk") && filereadable(expand("~/.latexmkrc"))
        let ltxmk = readfile(expand("~/.latexmkrc"))
        for line in ltxmk
            if line =~ '\$out_dir\s*='
                let b:rplugin_pdfdir = substitute(line, '.*\$out_dir\s*=\s*"\(.*\)".*', '\1', '')
                let b:rplugin_pdfdir = substitute(b:rplugin_pdfdir, ".*\\$out_dir\\s*=\\s*'\\(.*\\)'.*", '\1', '')
            endif
        endfor
    endif
    if g:R_latexcmd =~ "-outdir" || g:R_latexcmd =~ "-output-directory"
        let b:rplugin_pdfdir = substitute(g:R_latexcmd, '.*\(-outdir\|-output-directory\)\s*=*\s*', '', '')
        let b:rplugin_pdfdir = substitute(b:rplugin_pdfdir, " .*", "", "")
        let b:rplugin_pdfdir = substitute(b:rplugin_pdfdir, '["' . "']", "", "")
    endif
    if b:rplugin_pdfdir == "."
        let b:rplugin_pdfdir = mdir
    elseif b:rplugin_pdfdir !~ "^/"
        let b:rplugin_pdfdir = mdir . "/" . b:rplugin_pdfdir
        if !isdirectory(b:rplugin_pdfdir)
            let b:rplugin_pdfdir = "."
        endif
    endif
endfunction

call RSetPDFViewer()
