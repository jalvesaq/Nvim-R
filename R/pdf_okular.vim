
function OkularJobStdout(job_id, data, etype)
    for cmd in a:data
        if cmd =~ "^call "
            exe cmd
        endif
    endfor
endfunction

function StartOkularNeovim(fullpath)
    let g:rplugin.jobs["Okular"] = jobstart(["okular", "--unique",
                \ "--editor-cmd", "echo 'call SyncTeX_backward(\"%f\",  \"%l\")'", a:fullpath],
                \ {"detach": 1, "on_stdout": function('OkularJobStdout')})
    if g:rplugin.jobs["Okular"] < 1
        call RWarningMsg("Failed to run Okular...")
    endif
endfunction

function OkularJobStdoutV(job_id, msg)
    let cmd = substitute(a:msg, '\n', '', 'g')
    let cmd = substitute(cmd, '\r', '', 'g')
    if cmd =~ "^call "
        exe cmd
    endif
endfunction

function StartOkularVim(fullpath)
    let jobid = job_start(["okular", "--unique",
                \ "--editor-cmd", "echo 'call SyncTeX_backward(\"%f\",  \"%l\")'", a:fullpath],
                \ {"stoponexit": "", "out_cb": function("OkularJobStdoutV")})
    if job_info(jobid)["status"] == "run"
        let g:rplugin.jobs["Okular"] = job_getchannel(jobid)
    else
        call RWarningMsg("Failed to run Okular...")
    endif
endfunction

function ROpenPDF2(fullpath)
    if has('nvim')
        call StartOkularNeovim(a:fullpath)
    else
        call StartOkularVim(a:fullpath)
    endif
endfunction

function SyncTeX_forward2(tpath, ppath, texln, tryagain)
    let texname = substitute(a:tpath, ' ', '\\ ', 'g')
    let pdfname = substitute(a:ppath, ' ', '\\ ', 'g')
    if has('nvim')
        let g:rplugin.jobs["OkularSyncTeX"] = jobstart(["okular", "--unique", 
                    \ "--editor-cmd", "echo 'call SyncTeX_backward(\"%f\",  \"%l\")'",
                    \ pdfname . "#src:" . a:texln . texname],
                    \ {"detach": 1, "on_stdout": function('OkularJobStdout')})
        if g:rplugin.jobs["OkularSyncTeX"] < 1
            call RWarningMsg("Failed to run Okular (SyncTeX forward)...")
        endif
    else
        let jobid = job_start(["okular", "--unique",
                    \ "--editor-cmd", "echo 'call SyncTeX_backward(\"%f\",  \"%l\")'",
                    \ pdfname . "#src:" . a:texln . texname],
                    \ {"stoponexit": "", "out_cb": function("OkularJobStdoutV")})
        if job_info(jobid)["status"] == "run"
            let g:rplugin.jobs["OkularSyncTeX"] = job_getchannel(jobid)
        else
            call RWarningMsg("Failed to run Okular (SyncTeX forward)...")
        endif
    endif
    if g:rplugin.has_awbt
        call RRaiseWindow(pdfname)
    endif
endfunction
