
function StartRStudio()
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        call JobStdin(g:rplugin_jobs["ClientServer"], "\x0bCheck if R is running\n")
        return
    endif

    let g:SendCmdToR = function('SendCmdToR_NotYet')

    call SetRHome()
    if has("nvim")
        call system("start " . g:RStudio_cmd)
    else
        silent exe "!start " . g:RStudio_cmd
    endif
    call UnsetRHome()

    call WaitNvimcomStart()
endfunction

function SendCmdToRStudio(...)
    let cmd = substitute(a:1, '"', '\\"', "g")
    call SendToNvimcom("\x08" . $NVIMR_ID . 'sendToConsole("' . cmd . '", execute=TRUE)')
    return 1
endfunction
