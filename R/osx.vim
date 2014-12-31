" This file contains code used only on OS X

function StartR_OSX()
    if IsSendCmdToRFake()
        return
    endif
    if g:rplugin_r64app
        let rcmd = "/Applications/R64.app"
    else
        let rcmd = "/Applications/R.app"
    endif

    if b:rplugin_r_args_str != " "
        " https://github.com/jcfaria/Vim-R-plugin/issues/63
        " https://stat.ethz.ch/pipermail/r-sig-mac/2013-February/009978.html
        call RWarningMsg('R.app does not support command line arguments. To pass "' . b:rplugin_r_args_str . '" to R, you must put "let R_applescript = 0" in your nvimrc to run R in a terminal emulator.')
    endif
    let rlog = system("open " . rcmd)
    if v:shell_error
        call RWarningMsg(rlog)
    endif
    if g:R_nvim_wd == 0
        lcd -
    endif
    let g:SendCmdToR = function('SendCmdToR_OSX')
    WaitVimComStart()
endfunction

function SendCmdToR_OSX(cmd)
    if g:R_ca_ck
        let cmd = "\001" . "\013" . a:cmd
    else
        let cmd = a:cmd
    endif

    if g:rplugin_r64app
        let rcmd = "R64"
    else
        let rcmd = "R"
    endif

    " for some reason it doesn't like "\025"
    let cmd = a:cmd
    let cmd = substitute(cmd, "\\", '\\\', 'g')
    let cmd = substitute(cmd, '"', '\\"', "g")
    let cmd = substitute(cmd, "'", "'\\\\''", "g")
    call system("osascript -e 'tell application \"".rcmd."\" to cmd \"" . cmd . "\"'")
    return 1
endfunction

