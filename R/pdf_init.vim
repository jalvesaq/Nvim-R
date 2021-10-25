
if exists('*RSetPDFViewer')
    finish
endif

function RSetPDFViewer()
    let g:rplugin.pdfviewer = tolower(g:R_pdfviewer)

    if g:rplugin.pdfviewer == "zathura"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/pdf_zathura.vim"
    elseif g:rplugin.pdfviewer == "evince"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/pdf_evince.vim"
    elseif g:rplugin.pdfviewer == "okular"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/pdf_okular.vim"
    elseif has("win32") && g:rplugin.pdfviewer == "sumatra"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/pdf_sumatra.vim"
    elseif g:rplugin.is_darwin && g:rplugin.pdfviewer == "skim"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/pdf_skim.vim"
    elseif g:rplugin.pdfviewer == "qpdfview"
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/pdf_qpdfview.vim"
    else
        exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/R/pdf_generic.vim"
        if !executable(g:R_pdfviewer)
            call RWarningMsg("R_pdfviewer (" . g:R_pdfviewer . ") not found.")
            return
        endif
        if g:R_synctex
            call RWarningMsg('Invalid value for R_pdfviewer: "' . g:R_pdfviewer . '" (SyncTeX will not work)')
        endif
    endif

    if !has("win32") && !g:rplugin.is_darwin
        if executable("wmctrl")
            let g:rplugin.has_wmctrl = 1
        else
            let g:rplugin.has_wmctrl = 0
            if &filetype == "rnoweb" && g:R_synctex
                call RWarningMsg("The application wmctrl must be installed to edit Rnoweb effectively.")
            endif
        endif
    endif
endfunction

if g:rplugin.is_darwin
    let g:R_openpdf = get(g:, "R_openpdf", 1)
    let g:R_pdfviewer = "skim"
else
    let g:R_openpdf = get(g:, "R_openpdf", 2)
    if has("win32")
        let g:R_pdfviewer = "sumatra"
    else
        let g:R_pdfviewer = get(g:, "R_pdfviewer", "zathura")
    endif
endif

if g:rplugin.is_darwin
    if !exists("g:macvim_skim_app_path")
        let g:macvim_skim_app_path = '/Applications/Skim.app'
    endif
else
    let g:R_applescript = 0
endif

if &filetype == 'rnoweb'
    call RSetPDFViewer()
    call SetPDFdir()
    if g:R_synctex && $DISPLAY != "" && g:rplugin.pdfviewer == "evince"
        let g:rplugin.evince_loop = 0
        call Run_EvinceBackward()
    endif
endif
