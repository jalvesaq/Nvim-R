function JobStdin(job, cmd)
    call chansend(a:job, a:cmd)
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
    for key in keys(g:rplugin.jobs)
        if g:rplugin.jobs[key] == a:job_id
            return key
        endif
    endfor
    return "Job"
endfunction

function StopWaitingNCS(...)
    if s:waiting_more_input
        let s:waiting_more_input = 0
        call RWarningMsg('Incomplete string received. Expected ' .
                    \ s:incomplete_input['size'] . ' bytes; received ' .
                    \ s:incomplete_input['received'] . '.')
    endif
    let s:incomplete_input = {'size': 0, 'received': 0, 'str': ''}
endfunction

let s:incomplete_input = {'size': 0, 'received': 0, 'str': ''}
let s:waiting_more_input = 0
function ROnJobStdout(job_id, data, etype)
    " DEBUG: call writefile(a:data, "/dev/shm/nvimrserver_stdout", "a")
    for cmd in a:data
        let cmd = substitute(cmd, '\r', '', 'g')
        if cmd == ""
            continue
        endif

        if cmd[0] == "\005"
            " Check the size of possibly very big string (dictionary for menu completion).
            let cmdsplt = split(cmd, "\005")
            let size = str2nr(cmdsplt[0])
            let received = strlen(cmdsplt[1])
            if size == received
                let cmd = cmdsplt[1]
            else
                let s:waiting_more_input = 1
                let s:incomplete_input['size'] = size
                let s:incomplete_input['received'] = received
                let s:incomplete_input['str'] = cmdsplt[1]
                call timer_start(100, 'StopWaitingNCS')
                return
            endif
        endif

        if s:waiting_more_input
            let s:incomplete_input['received'] += strlen(cmd)
            if s:incomplete_input['received'] == s:incomplete_input['size']
                let s:waiting_more_input = 0
                let cmd = s:incomplete_input['str'] . cmd
            else
                let s:incomplete_input['str'] .= cmd
                if s:incomplete_input['received'] > s:incomplete_input['size']
                    call RWarningMsg('Received larger than expected message.')
                endif
                return
            endif
        endif

        if cmd =~ "^call " || cmd  =~ "^let " || cmd =~ "^unlet "
            exe cmd
        else
            if len(cmd) > 128
                let cmd = substitute(cmd, '^\(.\{128}\).*', '\1', '') . ' [...]'
            endif
            call RWarningMsg("[" . GetJobTitle(a:job_id) . "] Unknown command: " . cmd)
        endif
    endfor
endfunction

function ROnJobStderr(job_id, data, etype)
    let msg = substitute(join(a:data), '\r', '', 'g')
    if msg !~ "^\s*$"
        call RWarningMsg("[" . GetJobTitle(a:job_id) . "] " . msg)
    endif
endfunction

function ROnJobExit(job_id, data, etype)
    let key = GetJobTitle(a:job_id)
    if key != "Job"
        let g:rplugin.jobs[key] = 0
    endif
    if a:data != 0
        call RWarningMsg('"' . key . '"' . ' exited with status ' . a:data)
    endif
    if key ==# 'R' || key ==# 'RStudio'
        call ClearRInfo()
    endif
    if key ==# 'Server'
        let g:rplugin.nrs_running = 0
    endif
endfunction

function IsJobRunning(key)
    return g:rplugin.jobs[a:key]
endfunction

let g:rplugin.jobs = {"Server": 0, "R": 0, "Terminal emulator": 0, "BibComplete": 0}
let g:rplugin.job_handlers = {
            \ 'on_stdout': function('ROnJobStdout'),
            \ 'on_stderr': function('ROnJobStderr'),
            \ 'on_exit':   function('ROnJobExit')}
