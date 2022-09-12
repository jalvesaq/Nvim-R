
if exists("*SyncTeX_forward2")
    finish
endif

let g:rplugin.zathura_pid = {}

if !executable("zathura")
    let g:rplugin.pdfviewer = "none"
    call RWarningMsg('Please, either install "zathura" or set the value of R_pdfviewer.')
endif

if executable("dbus-send")
    let s:has_dbus_send = 1
else
    let s:has_dbus_send = 0
endif

function ROpenPDF2(fullpath)
    if g:R_openpdf == 1
        call RStart_Zathura(a:fullpath)
        return
    endif

    if $WAYLAND_DISPLAY != "" && $GNOME_SHELL_SESSION_MODE != ""
        if g:rplugin.has_awbt
            sleep 200m " Time to Zathura reload the PDF
            let fname = substitute(a:fullpath, ".*/", "", "")
            let sout = system("busctl --user call org.gnome.Shell " .
                        \ "/de/lucaswerkmeister/ActivateWindowByTitle " .
                        \ "de.lucaswerkmeister.ActivateWindowByTitle " .
                        \ "activateBySubstring s '" . fname . "'")
            if sout =~ 'false'
                call RStart_Zathura(a:fullpath)
            endif
        else
            call RStart_Zathura(a:fullpath)
        endif
        return
    endif

    if !has_key(g:rplugin.zathura_pid, a:fullpath)
        let g:rplugin.zathura_pid[a:fullpath] = 0
    endif
    let fname = substitute(a:fullpath, ".*/", "", "")
    if system("wmctrl -xl") =~ 'Zathura.*' . fname &&
                \ has_key(g:rplugin.zathura_pid, a:fullpath) &&
                \ g:rplugin.zathura_pid[a:fullpath] != 0
        call system("wmctrl -a '" . fname . "'")
    else
        call RStart_Zathura(a:fullpath)
    endif

    if g:rplugin.has_wmctrl
        call system("wmctrl -a '" . substitute(a:fullpath, ".*/", "", "") . "'")
    endif
endfunction

function SyncTeX_forward2(tpath, ppath, texln, tryagain)
    let texname = substitute(a:tpath, ' ', '\\ ', 'g')
    let pdfname = substitute(a:ppath, ' ', '\\ ', 'g')
    let shortp  = substitute(a:ppath, '.*/', '', 'g')

    if !has_key(g:rplugin.zathura_pid, a:ppath) || (has_key(g:rplugin.zathura_pid, a:ppath) && g:rplugin.zathura_pid[a:ppath] == 0)
        call RStart_Zathura(a:ppath)
        sleep 900m
    endif

    let result = system("zathura --synctex-forward=" . a:texln . ":1:" . texname . " --synctex-pid=" . g:rplugin.zathura_pid[a:ppath] . " " . pdfname)
    if v:shell_error
        let g:rplugin.zathura_pid[a:ppath] = 0
        if a:tryagain
            call RStart_Zathura(a:ppath)
            sleep 900m
            call SyncTeX_forward2(a:tpath, a:ppath, a:texln, 0)
        else
            call RWarningMsg(substitute(result, "\n", " ", "g"))
            return
        endif
    endif

    call RaiseWindow(shortp)
endfunction

function StartZathuraNeovim(fullpath)
    let g:rplugin.jobs["Zathura"] = jobstart(["zathura",
                \ "--synctex-editor-command",
                \ "nclientserver %{input} %{line}", a:fullpath],
                \ {"detach": 1, "on_stderr": function('ROnJobStderr')})
    if g:rplugin.jobs["Zathura"] < 1
        call RWarningMsg("Failed to run Zathura...")
    else
        let g:rplugin.zathura_pid[a:fullpath] = jobpid(g:rplugin.jobs["Zathura"])
    endif
endfunction

function StartZathuraVim(fullpath)
    let jobid = job_start(["zathura",
                \ "--synctex-editor-command",
                \ "nclientserver %{input} %{line}", a:fullpath],
                \ {"stoponexit": "", "err_cb": function('ROnJobStderr')})
    if job_info(jobid)["status"] == "run"
        let g:rplugin.jobs["Zathura"] = job_getchannel(jobid)
        let g:rplugin.zathura_pid[a:fullpath] = job_info(jobid)["process"]
    else
        call RWarningMsg("Failed to run Zathura...")
    endif
endfunction

function RStart_Zathura(fullpath)
    " Use wmctrl to check if the pdf is already open and get Zathura's PID to
    " close the document and kill Zathura.
    let fname = substitute(a:fullpath, ".*/", "", "")
    if g:rplugin.has_wmctrl && s:has_dbus_send && filereadable("/proc/sys/kernel/pid_max")
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

    let $NVIMR_PORT = g:rplugin.myport
    if has("nvim")
        call StartZathuraNeovim(a:fullpath)
    else
        call StartZathuraVim(a:fullpath)
    endif
endfunction
