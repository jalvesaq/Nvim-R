
function ROpenPDF2(fullpath)
    if g:R_synctex && g:rplugin.nvimcom_bin_dir != "" && IsJobRunning("ClientServer") == 0
        call StartNClientServer('ROpenPDFOkular')
    endif

    call system("env NVIMR_PORT=" . g:rplugin.myport .
                \ " okular --unique '" . a:fullpath . "' 2>/dev/null >/dev/null &")
endfunction

function SyncTeX_forward2(tpath, ppath, texln, tryagain)
    let texname = substitute(a:tpath, ' ', '\\ ', 'g')
    let pdfname = substitute(a:ppath, ' ', '\\ ', 'g')
    call system("NVIMR_PORT=" . g:rplugin.myport . " okular --unique " .
                \ pdfname . "#src:" . a:texln . texname . " 2> /dev/null >/dev/null &")
endfunction

