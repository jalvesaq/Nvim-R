" This file contains code used only on Windows

let s:sumatra_in_path = 0

call RSetDefaultValue("g:R_set_home_env", 1)
call RSetDefaultValue("g:R_i386", 0)

if !exists("g:rplugin_R_path")
    call writefile(['reg.exe QUERY "HKLM\SOFTWARE\R-core\R" /s'], g:rplugin_tmpdir . "/run_cmd.bat")
    let ripl = system(g:rplugin_tmpdir . "/run_cmd.bat")
    let rip = filter(split(ripl, "\n"), 'v:val =~ ".*InstallPath.*REG_SZ"')
    if len(rip) == 0
        " Normally, 32 bit applications access only 32 bit registry and...
        " We have to try again if the user has installed R only in the other architecture.
        if has("win64")
            call writefile(['reg.exe QUERY "HKLM\SOFTWARE\R-core\R" /s /reg:32'], g:rplugin_tmpdir . "/run_cmd.bat")
        else
            call writefile(['reg.exe QUERY "HKLM\SOFTWARE\R-core\R" /s /reg:64'], g:rplugin_tmpdir . "/run_cmd.bat")
        endif
        let ripl = system(g:rplugin_tmpdir . "/run_cmd.bat")
        let rip = filter(split(ripl, "\n"), 'v:val =~ ".*InstallPath.*REG_SZ"')
    endif
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

" Ensure that the first gcc in the PATH will be capable of building both 32
" and 64 bit binaries
if exists("g:Rtools_path")
    let s:rtpath = g:Rtools_path
else
    let s:rtpath = ""
    let s:wgcc = split(system("where gcc"), "\n")
    if len(s:wgcc) > 0 && s:wgcc[0] !~ "Rtools"
        let s:path = split($PATH, ";")
        for s:p in s:path
            if s:p =~ "Rtools"
                let s:rtpath = substitute(s:p, "Rtools.*", "Rtools", "")
                break
            endif
        endfor
        unlet s:path
        unlet s:p
    endif
    unlet s:wgcc
    if s:rtpath != "" && !isdirectory(s:rtpath)
        let s:rtpath = ""
    endif
    if s:rtpath == "" && executable("wmic")
        let s:dstr = system("wmic logicaldisk get name")
        let s:dstr = substitute(s:dstr, "\001", "", "g")
        let s:dstr = substitute(s:dstr, " ", "", "g")
        let s:dlst = split(s:dstr, "\r\n")
        for s:lttr in s:dlst
            if s:lttr =~ ":" && isdirectory(s:lttr . "\\Rtools")
                let s:rtpath = s:lttr . "\\Rtools"
                break
            endif
        endfor
        unlet s:dstr
        unlet s:dlst
        unlet s:lttr
    endif
endif
if s:rtpath != ""
    let s:gccpath = globpath(s:rtpath, "gcc*")
    if s:gccpath == ""
        let $PATH = s:rtpath . "\\bin;" . $PATH
    else
        let $PATH = s:rtpath . "\\bin;" . s:gccpath . "\\bin;" . $PATH
    endif
    unlet s:gccpath
endif
let s:rtpath = substitute(s:rtpath, "\\", "/", "g")

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
        let g:RtoolsVersion = Rtvf
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

function SumatraInPath()
    if s:sumatra_in_path
        return 1
    endif
    if $PATH =~ "SumatraPDF"
        let s:sumatra_in_path = 1
        return 1
    endif

    " $ProgramFiles has different values for win32 and win64
    if executable($ProgramFiles . "\\SumatraPDF\\SumatraPDF.exe")
        let $PATH = $ProgramFiles . "\\SumatraPDF;" . $PATH
        let s:sumatra_in_path = 1
        return 1
    endif
    if executable($ProgramFiles . " (x86)\\SumatraPDF\\SumatraPDF.exe")
        let $PATH = $ProgramFiles . " (x86)\\SumatraPDF;" . $PATH
        let s:sumatra_in_path = 1
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
        call JobStdin(g:rplugin_jobs["ClientServer"], "\x0bCheck if R is running\n")
        return
    endif

    let g:SendCmdToR = function('SendCmdToR_NotYet')

    call SetRHome()
    if has("nvim")
        call system("start " . g:rplugin_R . ' ' . join(g:R_args))
    else
        silent exe "!start " . g:rplugin_R . ' ' . join(g:R_args)
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
    call JobStdin(g:rplugin_jobs["ClientServer"], "\003" . cmd)
    return 1
endfunction
