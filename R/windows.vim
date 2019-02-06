" This file contains code used only on Windows

let s:sumatra_in_path = 0

let g:R_set_home_env = get(g:, "R_set_home_env", 1)
let g:R_i386 = get(g:, "R_i386", 0)

if !exists("g:rplugin.R_path")
    call writefile(['reg.exe QUERY "HKLM\SOFTWARE\R-core\R" /s'], g:rplugin.tmpdir . "/run_cmd.bat")
    let ripl = system(g:rplugin.tmpdir . "/run_cmd.bat")
    let rip = filter(split(ripl, "\n"), 'v:val =~ ".*InstallPath.*REG_SZ"')
    if len(rip) == 0
        " Normally, 32 bit applications access only 32 bit registry and...
        " We have to try again if the user has installed R only in the other architecture.
        if has("win64")
            call writefile(['reg.exe QUERY "HKLM\SOFTWARE\R-core\R" /s /reg:32'], g:rplugin.tmpdir . "/run_cmd.bat")
        else
            call writefile(['reg.exe QUERY "HKLM\SOFTWARE\R-core\R" /s /reg:64'], g:rplugin.tmpdir . "/run_cmd.bat")
        endif
        let ripl = system(g:rplugin.tmpdir . "/run_cmd.bat")
        let rip = filter(split(ripl, "\n"), 'v:val =~ ".*InstallPath.*REG_SZ"')
    endif
    if len(rip) > 0
        let s:rinstallpath = substitute(rip[0], '.*InstallPath.*REG_SZ\s*', '', '')
        let s:rinstallpath = substitute(s:rinstallpath, '\n', '', 'g')
        let s:rinstallpath = substitute(s:rinstallpath, '\s*$', '', 'g')
    endif
    if !exists("s:rinstallpath")
        call RWarningMsg("Could not find R path in Windows Registry. If you have already installed R, please, set the value of 'R_path'.")
        let g:rplugin.failed = 1
        finish
    endif
    let hasR32 = isdirectory(s:rinstallpath . '\bin\i386')
    let hasR64 = isdirectory(s:rinstallpath . '\bin\x64')
    if hasR32 && !hasR64
        let g:R_i386 = 1
    endif
    if hasR64 && !hasR32
        let g:R_i386 = 0
    endif
    if hasR32 && g:R_i386
        let $PATH = s:rinstallpath . '\bin\i386;' . $PATH
    elseif hasR64 && g:R_i386 == 0
        let $PATH = s:rinstallpath . '\bin\x64;' . $PATH
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

function SetRtoolsPath()
    let s:oldpath = $PATH
    " Ensure that the first gcc in the PATH will be capable of building both 32
    " and 64 bit binaries
    if exists("g:Rtools_path")
        let s:rtpath = g:Rtools_path
    else
        let s:rtpath = ""
        let wgcc = split(system("where gcc"), "\n")
        if len(wgcc) > 0 && wgcc[0] !~ "Rtools"
            let path = split($PATH, ";")
            for pth in path
                if pth =~ "Rtools"
                    let s:rtpath = substitute(pth, "Rtools.*", "Rtools", "")
                    break
                endif
            endfor
        endif
        let g:rplugin.debug_info["Rtools where gcc"] = s:rtpath
        if s:rtpath != "" && !isdirectory(s:rtpath)
            let s:rtpath = ""
        endif
        if s:rtpath == "" && executable("wmic")
            let dstr = system("wmic logicaldisk get name")
            let dstr = substitute(dstr, "\001", "", "g")
            let dstr = substitute(dstr, " ", "", "g")
            let dlst = split(dstr, "\r\n")
            for lttr in dlst
                if lttr =~ ":" && isdirectory(lttr . "\\Rtools")
                    let s:rtpath = lttr . "\\Rtools"
                    break
                endif
            endfor
            let g:rplugin.debug_info["Rtools wmic"] = s:rtpath
        endif
    endif
    if s:rtpath != ""
        let gccpath = globpath(s:rtpath, "gcc*")
        if gccpath == ""
            let $PATH = s:rtpath . "\\bin;" .s:rtpath . "\\mingw_64\\bin;" .  s:rtpath . "\\mingw_32\\bin;" . $PATH
        else
            let $PATH = s:rtpath . "\\bin;" . gccpath . "\\bin;" . $PATH
        endif
        let g:rplugin.debug_info["Rtools new PATH"] = $PATH
    endif
    let s:rtpath = substitute(s:rtpath, "\\", "/", "g")
endfunction

function UnSetRtoolsPath()
    let $PATH = s:oldpath
endfunction

function CheckRtools()
    if s:rtpath == ""
        call RWarningMsg('Is Rtools installed?')
        return
    else
        if !isdirectory(s:rtpath)
            call RWarningMsg('Is Rtools installed? "' . s:rtpath . '" is not a directory.')
            return
        endif
    endif

    if s:rtpath != ""
        let Rtvf = s:rtpath . "/VERSION.txt"
        let g:rplugin.debug_info["Rtools version file"] = Rtvf
        if !filereadable(s:rtpath . "/mingw_32/bin/gcc.exe")
            call RWarningMsg('Did you install Rtools with 32 bit support? "' .
                        \ s:rtpath . "/mingw_32/bin/gcc.exe" . '" not found.')
            return
        endif
        if !filereadable(s:rtpath . "/mingw_64/bin/gcc.exe")
            call RWarningMsg('Did you install Rtools with 64 bit support? "' .
                        \ s:rtpath . "/mingw_64/bin/gcc.exe" . '" not found.')
            return
        endif
        if filereadable(Rtvf)
            let Rtvrsn = readfile(Rtvf)
            if Rtvrsn[0] =~ "version 3.4"
                call RWarningMsg("Nvim-R is incompatible with Rtools 3.4 (August 2016). Please, try Rtools 3.3.")
            endif
        endif
    endif
endfunction

function SetRHome()
    " R and Vim use different values for the $HOME variable.
    if g:R_set_home_env
        let s:saved_home = $HOME
        call writefile(['reg.exe QUERY "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Personal"'], g:rplugin.tmpdir . "/run_cmd.bat")
        let prs = system(g:rplugin.tmpdir . "/run_cmd.bat")
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
        call JobStdin(g:rplugin.jobs["ClientServer"], "\x0bCheck if R is running\n")
        return
    endif

    if g:rplugin.R =~? 'Rterm' && g:R_app =~? 'Rterm'
        call RWarningMsg('"R_app" cannot be "Rterm.exe". R will crash if you send any command.')
        sleep 200m
    endif

    let g:SendCmdToR = function('SendCmdToR_NotYet')

    call SetRHome()
    if has("nvim")
        call system("start " . g:rplugin.R . ' ' . join(g:R_args))
    else
        silent exe "!start " . g:rplugin.R . ' ' . join(g:R_args)
    endif
    call UnsetRHome()

    call WaitNvimcomStart()
endfunction

function CleanNvimAndStartR()
    call ClearRInfo()
    call StartR_Windows()
endfunction

function SendCmdToR_Windows(...)
    if g:R_clear_line
        let cmd = "\001" . "\013" . a:1 . "\n"
    else
        let cmd = a:1 . "\n"
    endif
    call JobStdin(g:rplugin.jobs["ClientServer"], "\003" . cmd)
    return 1
endfunction
