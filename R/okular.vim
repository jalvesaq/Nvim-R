
function ROpenPDF2(fullpath)
    call system("env NVIMR_PORT=" . g:rplugin_myport .
                \ " okular --unique '" . a:fullpath . "' 2>/dev/null >/dev/null &")
endfunction

function SyncTeX_forward2(tpath, ppath, texln, tryagain)
    let texname = substitute(a:tpath, ' ', '\\ ', 'g')
    let pdfname = substitute(a:ppath, ' ', '\\ ', 'g')
    call system("NVIMR_PORT=" . g:rplugin_myport . " okular --unique " .
                \ pdfname . "#src:" . a:texln . texname . " 2> /dev/null >/dev/null &")
endfunction

if g:R_synctex && g:rplugin_nvimcom_bin_dir != "" && IsJobRunning("ClientServer") == 0 && $DISPLAY != ""
    if $PATH !~ g:rplugin_nvimcom_bin_dir
        let $PATH = g:rplugin_nvimcom_bin_dir . ':' . $PATH
    endif
    let g:rplugin_jobs["ClientServer"] = StartJob("nclientserver", g:rplugin_job_handlers)
endif
