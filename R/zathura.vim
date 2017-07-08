
if exists("*SyncTeX_forward2")
    finish
endif

let g:rplugin_zathura_pid = {}

if executable("zathura")
    let vv = split(system("zathura --version 2>/dev/null"))[1]
    if vv < '0.3.1'
        let g:rplugin_pdfviewer = "none"
        call RWarningMsgInp("Zathura version must be >= 0.3.1")
    endif
else
    let g:rplugin_pdfviewer = "none"
    call RWarningMsgInp('Please, either install "zathura" or set the value of R_pdfviewer.')
endif
if executable("dbus-send")
    let s:has_dbus_send = 1
else
    let s:has_dbus_send = 0
endif

function ROpenPDF2(fullpath)
    if !has_key(g:rplugin_zathura_pid, a:fullpath)
        let g:rplugin_zathura_pid[a:fullpath] = 0
    endif
    let fname = substitute(a:fullpath, ".*/", "", "")
    if system("wmctrl -xl") =~ 'Zathura.*' . fname &&
                \ has_key(g:rplugin_zathura_pid, a:fullpath) &&
                \ g:rplugin_zathura_pid[a:fullpath] != 0
        call system("wmctrl -a '" . fname . "'")
    else
        call RStart_Zathura(a:fullpath)
    endif

    if g:rplugin_has_wmctrl
        call system("wmctrl -a '" . substitute(a:fullpath, ".*/", "", "") . "'")
    endif
endfunction

function SyncTeX_forward2(tpath, ppath, texln, tryagain)
    let texname = substitute(a:tpath, ' ', '\\ ', 'g')
    let pdfname = substitute(a:ppath, ' ', '\\ ', 'g')
    let shortp  = substitute(a:ppath, '.*/', '', 'g')

    if !has_key(g:rplugin_zathura_pid, a:ppath) || (has_key(g:rplugin_zathura_pid, a:ppath) && g:rplugin_zathura_pid[a:ppath] == 0)
        call RStart_Zathura(a:ppath)
        sleep 900m
    endif

    let result = system("zathura --synctex-forward=" . a:texln . ":1:" . texname . " --synctex-pid=" . g:rplugin_zathura_pid[a:ppath] . " " . pdfname)
    if v:shell_error
        let g:rplugin_zathura_pid[a:ppath] = 0
        if a:tryagain
            call RStart_Zathura(a:ppath)
            sleep 900m
            call SyncTeX_forward2(a:tpath, a:ppath, a:texln, 0)
        else
            call RWarningMsg(substitute(result, "\n", " ", "g"))
            return
        endif
    endif

    if g:rplugin_has_wmctrl
        call system("wmctrl -a '" . shortp . "'")
    endif
endfunction

function StartZathuraNeovim(fullpath)
    let g:rplugin_jobs["Zathura"] = jobstart(["zathura",
                \ "--synctex-editor-command",
                \ "nclientserver %{input} %{line}", a:fullpath],
                \ {"detach": 1, "on_stderr": function('ROnJobStderr')})
    if g:rplugin_jobs["Zathura"] < 1
        call RWarningMsg("Failed to run Zathura...")
    else
        let g:rplugin_zathura_pid[a:fullpath] = jobpid(g:rplugin_jobs["Zathura"])
    endif
endfunction

function StartZathuraVim(fullpath)
    let pycode = ["# -*- coding: " . &encoding . " -*-",
                \ "import subprocess",
                \ "import os",
                \ "import sys",
                \ "FNULL = open(os.devnull, 'w')",
                \ "a3 = '" . a:fullpath . "'",
                \ "zpid = subprocess.Popen(['zathura', '--synctex-editor-command', 'nclientserver %{input} %{line}', a3], stdout = FNULL, stderr = FNULL).pid",
                \ "sys.stdout.write(str(zpid))" ]
    call writefile(pycode, g:rplugin_tmpdir . "/start_zathura.py")
    let pid = system("python '" . g:rplugin_tmpdir . "/start_zathura.py" . "'")
    if pid == 0
        call RWarningMsg("Failed to run Zathura: " . substitute(pid, "\n", " ", "g"))
    else
        let g:rplugin_zathura_pid[a:fullpath] = pid
    endif
    call delete(g:rplugin_tmpdir . "/start_zathura.py")
endfunction

function RStart_Zathura(fullpath)
    " Use wmctrl to check if the pdf is already open and get Zathura's PID to
    " close the document and kill Zathura.
    let fname = substitute(a:fullpath, ".*/", "", "")
    if g:rplugin_has_wmctrl && s:has_dbus_send && filereadable("/proc/sys/kernel/pid_max")
        let info = filter(split(system("wmctrl -xpl"), "\n"), 'v:val =~ "Zathura.*' . fname . '"')
        if len(info) > 0
            let pid = split(info[0])[2] + 0     " + 0 to convert into number
            let max_pid = readfile("/proc/sys/kernel/pid_max")[0] + 0
            if pid > 0 && pid <= max_pid
                " Instead of killing, it would be better to reset the backward
                " command, but Zathura does not have a Dbus message for this,
                " and we would have to change nclientserver to receive NVIMR_PORT
                " and NVIMR_SECRET as part of argv[].
                call system('dbus-send --print-reply --session --dest=org.pwmt.zathura.PID-' . pid . ' /org/pwmt/zathura org.pwmt.zathura.CloseDocument')
                sleep 5m
                call system('kill ' . pid)
                sleep 5m
            endif
        endif
    endif

    let $NVIMR_PORT = g:rplugin_myport
    if exists("*jobpid")
        call StartZathuraNeovim(a:fullpath)
    else
        call StartZathuraVim(a:fullpath)
    endif
endfunction

if g:R_synctex && g:rplugin_nvimcom_bin_dir != "" && IsJobRunning("ClientServer") == 0 && $DISPLAY != ""
    if $PATH !~ g:rplugin_nvimcom_bin_dir
        let $PATH = g:rplugin_nvimcom_bin_dir . ':' . $PATH
    endif
    let g:rplugin_jobs["ClientServer"] = StartJob("nclientserver", g:rplugin_job_handlers)
endif
