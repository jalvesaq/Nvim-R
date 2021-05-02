
if exists("*SyncTeX_forward2")
    finish
endif

function ROpenPDF2(fullpath)
    call system("env NVIMR_PORT=" . g:rplugin.myport . " " .
                \ g:macvim_skim_app_path . '/Contents/MacOS/Skim "' .
                \ a:fullpath . '" 2> /dev/null >/dev/null &')
endfunction

function SyncTeX_forward2(tpath, ppath, texln, tryagain)
    " This command is based on macvim-skim
    call system("NVIMR_PORT=" . g:rplugin.myport . " " .
                \ g:macvim_skim_app_path . '/Contents/SharedSupport/displayline -r ' .
                \ a:texln . ' "' . a:ppath . '" "' . a:tpath . '" 2> /dev/null >/dev/null &')
endfunction
