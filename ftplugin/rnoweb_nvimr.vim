
if exists("g:disable_r_ftplugin")
    finish
endif

" Source scripts common to R, Rnoweb, Rhelp and Rdoc:
runtime R/common_global.vim
if exists("g:rplugin_failed")
    finish
endif

" Some buffer variables common to R, Rnoweb, Rhelp and Rdoc need to be defined
" after the global ones:
runtime R/common_buffer.vim

call RSetDefaultValue("g:R_latexmk", 1)
if !exists("s:has_latexmk")
    if g:R_latexmk && executable("latexmk") && executable("perl")
        let s:has_latexmk = 1
    else
        let s:has_latexmk = 0
    endif
endif

function! RWriteChunk()
    if getline(".") =~ "^\\s*$" && RnwIsInRCode(0) == 0
        call setline(line("."), "<<>>=")
        exe "normal! o@"
        exe "normal! 0kl"
    else
        exe "normal! a<"
    endif
endfunction

function! RnwIsInRCode(vrb)
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

function! RnwPreviousChunk() range
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

function! RnwNextChunk() range
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
function! RKnitRmCache()
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
function! RWeave(bibtex, knit, pdf)
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
function! RnwSendChunkToR(e, m)
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

if g:R_rnowebchunk == 1
    " Write code chunk in rnoweb files
    inoremap <buffer><silent> < <Esc>:call RWriteChunk()<CR>a
endif

" Pointers to functions whose purposes are the same in rnoweb, rrst, rmd,
" rhelp and rdoc and which are called at common_global.vim
let b:IsInRCode = function("RnwIsInRCode")
let b:PreviousRChunk = function("RnwPreviousChunk")
let b:NextRChunk = function("RnwNextChunk")
let b:SendChunkToR = function("RnwSendChunkToR")


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
    runtime R/gui_running.vim
    call MakeRMenu()
endif

"==========================================================================
" SyncTeX support:

function! SyncTeX_GetMaster()
    if filereadable(expand("%:t:r") . "-concordance.tex")
        return [expand("%:t:r"), "."]
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
            let mdir = "."
        endif
        let basenm = substitute(mfile, '\....$', '', '')
        return [basenm, mdir]
    endif

    " Maybe this buffer is a master Rnoweb not compiled yet.
    return [expand("%:t:r"), "."]
endfunction

" See http://www.stats.uwo.ca/faculty/murdoch/9864/Sweave.pdf page 25
function! SyncTeX_readconc(basenm)
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

function! GoToBuf(rnwbn, rnwf, basedir, rnwln)
    if bufname("%") != a:rnwbn
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

function! SyncTeX_backward(fname, ln)
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

function! SyncTeX_forward_Zathura(basenm, texln, vrbs)
    if g:rplugin_zathura_pid[a:basenm] == 0
        return 0
    endif
    let result = system("zathura --synctex-forward=" . a:texln . ":1:" . a:basenm . ".tex --synctex-pid=" . g:rplugin_zathura_pid[a:basenm] . " " . a:basenm . ".pdf")
    if v:shell_error
        let g:rplugin_zathura_pid[a:basenm] = 0
        if a:vrbs
            call RWarningMsg(substitute(result, "\n", " ", "g"))
        endif
        return 0
    endif
    return 1
endfunction

" Avoid possible infinite loop if Evince cannot open the document and
" synctex_evince_forward.py keeps sending the message to Neovim run
" SyncTeX_forward() again.
function! Evince_Again()
    let g:rplugin_evince_loop += 1
    call SyncTeX_forward()
endfunction

function! SyncTeX_forward(...)
    let basenm = expand("%:t:r")
    let lnum = 0
    let rnwf = expand("%:t")

    let olddir = getcwd()
    if olddir != expand("%:p:h")
        exe "cd " . substitute(expand("%:p:h"), ' ', '\\ ', 'g')
    endif

    if filereadable(basenm . "-concordance.tex")
        let lnum = line(".")
    else
        let ischild = search('% *!Rnw *root *=', 'bwn')
        if ischild
            let mfile = substitute(getline(ischild), '.*% *!Rnw *root *= *\(.*\) *', '\1', '')
            let basenm = substitute(mfile, '\....$', '', '')
            if filereadable(basenm . "-concordance.tex")
                let mlines = readfile(mfile)
                for ii in range(len(mlines))
                    " Sweave has detailed child information
                    if mlines[ii] =~ 'SweaveInput.*' . bufname("%")
                        let lnum = line(".")
                        break
                    endif
                    " Knitr does not include detailed child information
                    if mlines[ii] =~ '<<.*child *=.*' . bufname("%") . '["' . "']"
                        let lnum = ii + 1
                        let rnwf = substitute(mfile, '.*/', '', '')
                        break
                    endif
                endfor
                if lnum == 0
                    call RWarningMsg('Could not find "child=' . bufname("%") . '" in ' . mfile . '.')
                    exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
                    return
                endif
            else
                call RWarningMsg('Nvim-R [SyncTeX]: "' . basenm . '-concordance.tex" not found.')
                exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
                return
            endif
        else
            call RWarningMsg('SyncTeX [Nvim-R]: "' . basenm . '-concordance.tex" not found.')
            exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
            return
        endif
    endif

    if !filereadable(basenm . ".tex")
        call RWarningMsg('"' . basenm . '.tex" not found.')
        exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
        return
    endif
    let concdata = SyncTeX_readconc(basenm)
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
        exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
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
        exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
        return
    endif

    if !filereadable(basenm . ".pdf")
        call RWarningMsg('SyncTeX forward cannot be done because the file "' . basenm . '.pdf" is missing.')
        exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
        return
    endif
    if !filereadable(basenm . ".synctex.gz")
        call RWarningMsg('SyncTeX forward cannot be done because the file "' . basenm . '.synctex.gz" is missing.')
        if g:R_latexcmd != "default" && g:R_latexcmd !~ "synctex"
            call RWarningMsg('Note: The string "-synctex=1" is not in your R_latexcmd. Please check your vimrc.')
        endif
        exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
        return
    endif

    if g:rplugin_pdfviewer == "zathura"
        if system("wmctrl -xl") =~ 'Zathura.*' . basenm . '.pdf' && g:rplugin_zathura_pid[basenm] != 0
            if SyncTeX_forward_Zathura(basenm, texln, 0) == 0
                " The user closed Zathura and later opened the pdf manually
                call RStart_Zathura(basenm)
                sleep 900m
                call SyncTeX_forward_Zathura(basenm, texln, 1)
            endif
        else
            let g:rplugin_zathura_pid[basenm] = 0
            call RStart_Zathura(basenm)
            sleep 900m
            call SyncTeX_forward_Zathura(basenm, texln, 1)
        endif
        call system("wmctrl -a '" . basenm . ".pdf'")
    elseif g:rplugin_pdfviewer == "okular"
        call system("NVIMR_PORT=" . g:rplugin_myport . " okular --unique " . basenm . ".pdf#src:" . texln . substitute(expand("%:p:h"), ' ', '\\ ', 'g') . "/./" . substitute(basenm, ' ', '\\ ', 'g') . ".tex 2> /dev/null >/dev/null &")
    elseif g:rplugin_pdfviewer == "evince"
        if g:rplugin_evince_loop < 2
            let g:rplugin_jobs["Python (Evince forward)"] = StartJob(["python", g:rplugin_home . "/R/synctex_evince_forward.py",  basenm . ".pdf", string(texln), basenm . ".tex"], g:rplugin_job_handlers)
        else
            let g:rplugin_evince_loop = 0
        endif
        if g:rplugin_has_wmctrl
            call system("wmctrl -a '" . basenm . ".pdf'")
        endif
    elseif g:rplugin_pdfviewer == "sumatra"
        if basenm =~ ' '
            call RWarningMsg('You must remove the empty spaces from the rnoweb file name ("' . basenm .'") to get SyncTeX support with SumatraPDF.')
        endif
        if SumatraInPath()
            let $NVIMR_PORT = g:rplugin_myport
            call writefile(['start SumatraPDF.exe -reuse-instance -forward-search ' . basenm . '.tex ' . texln . ' -inverse-search "nclientserver.exe %%f %%l" ' . basenm . '.pdf'], g:rplugin_tmpdir . "/run_cmd.bat")
            call system(g:rplugin_tmpdir . "/run_cmd.bat")
        endif
    elseif g:rplugin_pdfviewer == "skim"
        " This command is based on macvim-skim
        call system("NVIMR_PORT=" . g:rplugin_myport . " " . g:macvim_skim_app_path . '/Contents/SharedSupport/displayline -r ' . texln . ' "' . basenm . '.pdf" "' . basenm . '.tex" 2> /dev/null >/dev/null &')
    else
        call RWarningMsg('SyncTeX support for "' . g:rplugin_pdfviewer . '" not implemented.')
    endif
    exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
endfunction

function! Run_EvinceBackward()
    let olddir = getcwd()
    if olddir != expand("%:p:h")
        try
            exe "cd " . substitute(expand("%:p:h"), ' ', '\\ ', 'g')
        catch /.*/
            return
        endtry
    endif
    let [basenm, basedir] = SyncTeX_GetMaster()
    if basedir != '.'
        exe "cd " . substitute(basedir, ' ', '\\ ', 'g')
    endif
    let did_evince = 0
    if !exists("s:evince_list")
        let s:evince_list = []
    else
        for bb in s:evince_list
            if bb == basenm
                let did_evince = 1
                break
            endif
        endfor
    endif
    if !did_evince
        call add(s:evince_list, basenm)
        let g:rplugin_jobs["Python (Evince backward)"] = StartJob(["python", g:rplugin_home . "/R/synctex_evince_backward.py", basenm . ".pdf"], g:rplugin_job_handlers)
    endif
    exe "cd " . substitute(olddir, ' ', '\\ ', 'g')
endfunction

call RSetPDFViewer()
if g:rplugin_pdfviewer != "none"
    if g:rplugin_pdfviewer == "zathura"
        let s:this_master = SyncTeX_GetMaster()[0]
        let s:key_list = keys(g:rplugin_zathura_pid)
        let s:has_key = 0
        for kk in s:key_list
            if kk == s:this_master
                let s:has_key = 1
                break
            endif
        endfor
        if s:has_key == 0
            let g:rplugin_zathura_pid[s:this_master] = 0
        endif
        unlet s:this_master
        unlet s:key_list
        unlet s:has_key
    endif
    if g:R_synctex
        if $DISPLAY != "" && g:rplugin_pdfviewer == "evince"
            let g:rplugin_evince_loop = 0
            call Run_EvinceBackward()
        elseif g:rplugin_nvimcom_bin_dir != "" && IsJobRunning("ClientServer") == 0 && !($DISPLAY == "" && (g:rplugin_pdfviewer == "zathura" || g:rplugin_pdfviewer == "okular"))
            if !has("win32")
                if $PATH !~ g:rplugin_nvimcom_bin_dir
                    let $PATH = g:rplugin_nvimcom_bin_dir . ':' . $PATH
                endif
                if v:windowid != 0 && $WINDOWID == ""
                    let $WINDOWID = v:windowid
                endif
                let g:rplugin_jobs["ClientServer"] = StartJob("nclientserver", g:rplugin_job_handlers)
            endif
        endif
    endif
endif

call RSourceOtherScripts()

if exists("b:undo_ftplugin")
    let b:undo_ftplugin .= " | unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
else
    let b:undo_ftplugin = "unlet! b:IsInRCode b:PreviousRChunk b:NextRChunk b:SendChunkToR"
endif
