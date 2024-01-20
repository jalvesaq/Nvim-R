
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

    if !has("win32") && !g:rplugin.is_darwin && $WAYLAND_DISPLAY == ""
        if executable("wmctrl")
            let g:rplugin.has_wmctrl = 1
        else
            if &filetype == "rnoweb" && g:R_synctex
                call RWarningMsg("The application wmctrl must be installed to edit Rnoweb effectively.")
            endif
        endif
    endif

    " FIXME: The ActivateWindowByTitle extension is no longer working
    return

    if $WAYLAND_DISPLAY != "" && $GNOME_SHELL_SESSION_MODE != ""
        if executable('busctl')
            let sout = system('busctl --user call org.gnome.Shell.Extensions ' .
                        \ '/org/gnome/Shell/Extensions org.gnome.Shell.Extensions ' .
                        \ 'GetExtensionInfo "s" "activate-window-by-title@lucaswerkmeister.de"')
            if sout =~ 'Activate Window'
                let g:rplugin.has_awbt = 1
            endif
        endif
    endif
endfunction

let g:rplugin.has_wmctrl = 0
let g:rplugin.has_awbt = 0
function RRaiseWindow(wttl)
    if g:rplugin.has_wmctrl
        call system("wmctrl -a '" . a:wttl . "'")
        if v:shell_error
            return 0
        else
            return 1
        endif
    elseif $WAYLAND_DISPLAY != ""
        if $GNOME_SHELL_SESSION_MODE != "" && g:rplugin.has_awbt
            let sout = system("busctl --user call org.gnome.Shell " .
                        \ "/de/lucaswerkmeister/ActivateWindowByTitle " .
                        \ "de.lucaswerkmeister.ActivateWindowByTitle " .
                        \ "activateBySubstring s '" . a:wttl . "'")
            if v:shell_error
                call RWarningMsg('Error running Gnome Shell Extension "Activate Window By Title": '
                            \ . substitute(sout, "\n", " ", "g"))
                return 0
            endif
            if sout =~ 'false'
                return 0
            else
                return 1
            endif
        elseif $XDG_CURRENT_DESKTOP == "sway"
            let sout = system("swaymsg -t get_tree")
            if v:shell_error
                call RWarningMsg('Error running swaymsg: ' . substitute(sout, "\n", " ", "g"))
                return 0
            endif
            if sout =~ a:wttl
                " Should move to the workspace where Zathura is, and, then, try to focus the window?
                " call system('swaymsg for_window [title="' . a:wttl . '"] focus')
                return 1
            else
                return 0
            endif
        endif
    endif
    return 0
endfunction

if $XDG_CURRENT_DESKTOP == "sway"
    let g:R_openpdf = get(g:, "R_openpdf", 2)
elseif g:rplugin.is_darwin || $WAYLAND_DISPLAY != ""
    let g:R_openpdf = get(g:, "R_openpdf", 1)
else
    let g:R_openpdf = get(g:, "R_openpdf", 2)
endif

if g:rplugin.is_darwin
    let g:R_pdfviewer = "skim"
else
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
