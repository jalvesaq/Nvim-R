" Nothing yet
if exists("*SumatraInPath")
    finish
endif

function ROpenPDF2(fullpath)
    if SumatraInPath()
        let pdir = substitute(a:fullpath, '\(.*\)/.*', '\1', '')
        let pname = substitute(a:fullpath, '.*/\(.*\)', '\1', '')
        let olddir = substitute(substitute(getcwd(), '\\', '/', 'g'), ' ', '\\ ', 'g')
        exe "cd " . pdir
        let $NVIMR_PORT = g:rplugin_myport
        call writefile(['start SumatraPDF.exe -reuse-instance -inverse-search "nclientserver.exe %%f %%l" "' . a:fullpath . '"'], g:rplugin_tmpdir . "/run_cmd.bat")
        call system(g:rplugin_tmpdir . "/run_cmd.bat")
        exe "cd " . olddir
    endif
endfunction

let s:sumatra_in_path = 0

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

function SyncTeX_forward2(tpath, ppath, texln, unused)
    if a:tpath =~ ' '
        " call RWarningMsg('You must remove the empty spaces from the rnoweb file name ("' . a:tpath .'") to get SyncTeX support with SumatraPDF.')
    endif
    if SumatraInPath()
        let tname = substitute(a:tpath, '.*/\(.*\)', '\1', '')
        let tdir = substitute(a:tpath, '\(.*\)/.*', '\1', '')
        let pname = substitute(a:ppath, tdir . '/', '', '')
        let olddir = substitute(substitute(getcwd(), '\\', '/', 'g'), ' ', '\\ ', 'g')
        exe "cd " . substitute(tdir, ' ', '\\ ', 'g')
        let $NVIMR_PORT = g:rplugin_myport
        call writefile(['start SumatraPDF.exe -reuse-instance -forward-search "' . tname . '" ' . a:texln . ' -inverse-search "nclientserver.exe %%f %%l" "' . pname . '"'], g:rplugin_tmpdir . "/run_cmd.bat")
        call system(g:rplugin_tmpdir . "/run_cmd.bat")
        exe "cd " . olddir
    endif
endfunction
