" This file contains code used only on Windows

let g:rplugin_sumatra_in_path = 0

call RSetDefaultValue("g:R_set_home_env", 1)
call RSetDefaultValue("g:R_i386", 0)

if !exists("g:rplugin_R_path")
    call writefile(['reg.exe QUERY "HKLM\SOFTWARE\R-core\R" /s'], g:rplugin_tmpdir . "/run_cmd.bat")
    let rip = filter(split(system(g:rplugin_tmpdir . "/run_cmd.bat"), "\n"), 'v:val =~ ".*InstallPath.*REG_SZ"')
    if len(rip) > 0
        let s:rinstallpath = substitute(rip[0], '.*InstallPath.*REG_SZ\s*', '', '')
        let s:rinstallpath = substitute(s:rinstallpath, '\n', '', 'g')
        let s:rinstallpath = substitute(s:rinstallpath, '\s*$', '', 'g')
    endif
    if !exists("s:rinstallpath")
        call RWarningMsgInp("Could not find R path in Windows Registry. If you have already installed R, please, set the value of 'R_path'.")
        let g:rplugin_failed = 1
        finish
    endif
    if isdirectory(s:rinstallpath . '\bin\i386')
        if !isdirectory(s:rinstallpath . '\bin\x64')
            let g:R_i386 = 1
        endif
        if g:R_i386
            let $PATH = s:rinstallpath . '\bin\i386;' . $PATH
        else
            let $PATH = s:rinstallpath . '\bin\x64;' . $PATH
        endif
    else
        let $PATH = s:rinstallpath . '\bin;' . $PATH
    endif
    unlet s:rinstallpath
endif

if !exists("g:R_args")
    if g:R_in_buffer
        let g:R_args = ["--no-save"]
    else
        let g:R_args = ["--sdi", "--no-save"]
    endif
endif

let g:R_R_window_title = "R Console"

function SumatraInPath()
    if g:rplugin_sumatra_in_path
        return 1
    endif
    if $PATH =~ "SumatraPDF"
        let g:rplugin_sumatra_in_path = 1
        return 1
    endif

    " $ProgramFiles has different values for win32 and win64
    if executable($ProgramFiles . "\\SumatraPDF\\SumatraPDF.exe")
        let $PATH = $ProgramFiles . "\\SumatraPDF;" . $PATH
        let g:rplugin_sumatra_in_path = 1
        return 1
    endif
    if executable($ProgramFiles . " (x86)\\SumatraPDF\\SumatraPDF.exe")
        let $PATH = $ProgramFiles . " (x86)\\SumatraPDF;" . $PATH
        let g:rplugin_sumatra_in_path = 1
        return 1
    endif
    return 0
endfunction

function SetRHome()
    " R and Vim use different values for the $HOME variable.
    if g:R_set_home_env
        let s:saved_home = $HOME
        call writefile(['reg.exe QUERY "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Personal"'], g:rplugin_tmpdir . "/run_cmd.bat")
        let prs = system(g:rplugin_tmpdir . "/run_cmd.bat")
        if len(prs) > 0
            let prs = substitute(prs, '.*REG_SZ\s*', '', '')
            let prs = substitute(prs, '\n', '', 'g')
            let prs = substitute(prs, '\r', '', 'g')
            let prs = substitute(prs, '\s*$', '', 'g')
            let $HOME = prs
        endif
    endif
endfunction

function UnsetRHome()
    if exists("s:saved_home")
        let $HOME = s:saved_home
        unlet s:saved_home
    endif
endfunction

function StartR_Windows()
    if string(g:SendCmdToR) != "function('SendCmdToR_fake')"
        call RWarningMsg('R was already started.')
    endif

    call SetRHome()
    if has("nvim")
        call system("start " . g:rplugin_R . ' ' . join(g:R_args))
    else
        silent exe "!start " . g:rplugin_R . ' ' . join(g:R_args)
    endif
    call UnsetRHome()

    let g:SendCmdToR = function('SendCmdToR_Windows')
    if WaitNvimcomStart()
        if g:R_arrange_windows && filereadable(g:rplugin_compldir . "/win_pos")
            " ArrangeWindows
            call JobStdin(g:rplugin_jobs["ClientServer"], "\005" . g:rplugin_compldir . "\n")
        endif
        if g:R_after_start != ''
            call system(g:R_after_start)
        endif
    endif
endfunction

function SendCmdToR_Windows(...)
    if g:R_ca_ck
        let cmd = "\001" . "\013" . a:1 . "\n"
    else
        let cmd = a:1 . "\n"
    endif
    call JobStdin(g:rplugin_jobs["ClientServer"], "\003" . cmd)
    return 1
endfunction
