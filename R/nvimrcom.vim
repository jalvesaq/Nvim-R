function JobStdin(job, cmd)
    call jobsend(a:job, a:cmd)
endfunction

function StartJob(cmd, opt)
    let jobid = jobstart(a:cmd, a:opt)
    if jobid == 0
        call RWarningMsg("Invalid arguments in: " . string(a:cmd))
    elseif jobid == -1
        call RWarningMsg("Command not executable in: " . string(a:cmd))
    endif
    return jobid
endfunction

function GetJobTitle(job_id)
    for key in keys(g:rplugin_jobs)
        if g:rplugin_jobs[key] == a:job_id
            return key
        endif
    endfor
    return "Job"
endfunction

function ROnJobStdout(job_id, data, etype)
    for cmd in a:data
        let cmd = substitute(cmd, '\r', '', 'g')
        if cmd == ""
            continue
        endif
        if cmd =~ "^call " || cmd  =~ "^let " || cmd =~ "^unlet "
            exe cmd
        else
            call RWarningMsg("[" . GetJobTitle(a:job_id) . "] Unknown command: " . cmd)
        endif
    endfor
endfunction

function ROnJobStderr(job_id, data, etype)
    call RWarningMsg("[" . GetJobTitle(a:job_id) . "] " . substitute(join(a:data), '\r', '', 'g'))
endfunction

function ROnJobExit(job_id, data, etype)
    let key = GetJobTitle(a:job_id)
    if key != "Job"
        let g:rplugin_jobs[key] = 0
    endif
    if a:data != 0
        call RWarningMsg('"' . key . '"' . ' exited with status ' . a:data)
    endif
endfunction

function IsJobRunning(key)
    return g:rplugin_jobs[a:key]
endfunction

let g:rplugin_jobs = {"ClientServer": 0, "R": 0, "Terminal emulator": 0}
let g:rplugin_job_handlers = {
            \ 'on_stdout': function('ROnJobStdout'),
            \ 'on_stderr': function('ROnJobStderr'),
            \ 'on_exit':   function('ROnJobExit')}
