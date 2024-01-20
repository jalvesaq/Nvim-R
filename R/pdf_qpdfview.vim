
function ROpenPDF2(fullpath)
    call system("env NVIMR_PORT=" . g:rplugin.myport .
                \ " qpdfview --unique '" . a:fullpath . "' 2>/dev/null >/dev/null &")
    if g:R_synctex && a:fullpath =~ " "
        call RWarningMsg("Qpdfview does support file names with spaces: SyncTeX backward will not work.")
    endif
endfunction

function SyncTeX_forward2(tpath, ppath, texln, tryagain)
    let texname = substitute(a:tpath, ' ', '\\ ', 'g')
    let pdfname = substitute(a:ppath, ' ', '\\ ', 'g')
    call system("NVIMR_PORT=" . g:rplugin.myport . " qpdfview --unique " .
                \ pdfname . "#src:" . texname . ":" . a:texln . ":1 2> /dev/null >/dev/null &")
    call RRaiseWindow(substitute(substitute(a:ppath, ".*/", "", ""), ".pdf$", "", ""))
endfunction
