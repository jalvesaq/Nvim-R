if !exists("*job_getchannel") || !has("patch-7.4.1538")
    call RWarningMsgInp("Nvim-R requires either Neovim >= 0.1.2 or Vim >= 7.4.1538. If using Vim, both +channel and +job features must be enabled.")
    let g:rplugin_failed = 1
    finish
endif

function JobStdin(ch, cmd)
    call ch_sendraw(a:ch, a:cmd)
endfunction

function StartJob(cmd, opt)
    let jobid = job_start(a:cmd, a:opt)
    return job_getchannel(jobid)
endfunction

function GetJobTitle(job_id)
    for key in keys(g:rplugin_jobs)
        if g:rplugin_jobs[key] == a:job_id
            return key
        endif
    endfor
    return "Job"
endfunction

function ROnJobStdout(job_id, msg)
    let cmd = substitute(a:msg, '\n', '', 'g')
    let cmd = substitute(cmd, '\r', '', 'g')
    if cmd =~ "^call " || cmd  =~ "^let " || cmd =~ "^unlet "
        exe cmd
    else
        call RWarningMsg("[" . GetJobTitle(a:job_id) . "] Unknown command: " . cmd)
    endif
endfunction

function ROnJobStderr(job_id, msg)
    let msg = substitute(a:msg, '\n', '', 'g')
    if msg != "DETACH"
        call RWarningMsg("[" . GetJobTitle(a:job_id) . "] " . msg)
    endif
endfunction

function ROnJobExit(job_id)
    let key = GetJobTitle(a:job_id)
    if key != "Job"
        let g:rplugin_jobs[key] = "no"
    endif
endfunction

function IsJobRunning(key)
    try
        let chstt =  ch_status(g:rplugin_jobs[a:key])
    catch
        let chstt = "no"
    endtry
    if chstt == "open"
        return 1
    else
        return 0
    endif
endfunction

let g:rplugin_jobs = {"ClientServer": "no", "R": "no", "Terminal emulator": "no"}
let g:rplugin_job_handlers = {
            \ 'out-cb':   function('ROnJobStdout'),
            \ 'err-cb':   function('ROnJobStderr'),
            \ 'close-cb': function('ROnJobExit')}
