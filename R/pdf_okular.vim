
function ROpenPDF2(fullpath)
    call system("env NVIMR_PORT=" . g:rplugin.myport .
                \ " okular --unique '" . a:fullpath . "' 2>/dev/null >/dev/null &")
endfunction

function SyncTeX_forward2(tpath, ppath, texln, tryagain)
    let texname = substitute(a:tpath, ' ', '\\ ', 'g')
    let pdfname = substitute(a:ppath, ' ', '\\ ', 'g')
    call system("NVIMR_PORT=" . g:rplugin.myport . " okular --unique " .
                \ pdfname . "#src:" . a:texln . texname . " 2> /dev/null >/dev/null &")
    if g:rplugin.has_awbt
        call RaiseWindow(pdfname)
    endif
endfunction

