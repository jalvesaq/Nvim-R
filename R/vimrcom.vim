function JobStdin(ch, cmd)
    call ch_sendraw(a:ch, a:cmd)
endfunction

function StartJob(cmd, opt)
    let jobid = job_start(a:cmd, a:opt)
    return job_getchannel(jobid)
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
function ROnJobStdout(job_id, msg)
    let cmd = substitute(a:msg, '\n', '', 'g')
    let cmd = substitute(cmd, '\r', '', 'g')
    " DEBUG: call writefile([cmd], "/dev/shm/nvimrserver_vim_stdout", "a")

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
    elseif cmd != ""
        if len(cmd) > 128
            let cmd = substitute(cmd, '^\(.\{128}\).*', '\1', '') . ' [...]'
        endif
        call RWarningMsg("[" . GetJobTitle(a:job_id) . "] Unknown command: " . cmd)
    endif
endfunction

function ROnJobStderr(job_id, msg)
    call RWarningMsg("[" . GetJobTitle(a:job_id) . "] " . substitute(a:msg, '\n', '', 'g'))
endfunction

function ROnJobExit(job_id, stts)
    let key = GetJobTitle(a:job_id)
    if key != "Job"
        let g:rplugin.jobs[key] = "no"
    endif
    if a:stts != 0
        call RWarningMsg('"' . key . '"' . ' exited with status ' . a:stts)
    endif
    if key ==# 'R'
        call ClearRInfo()
    endif
    if key ==# 'Server'
        let g:rplugin.nrs_running = 0
    endif
endfunction

function IsJobRunning(key)
    try
        let chstt =  ch_status(g:rplugin.jobs[a:key])
    catch /.*/
        let chstt = "no"
    endtry
    if chstt == "open"
        return 1
    else
        return 0
    endif
endfunction

let g:rplugin.jobs = {"Server": "no", "R": "no", "Terminal emulator": "no", "BibComplete": "no"}
let g:rplugin.job_handlers = {
            \ 'out_cb':  'ROnJobStdout',
            \ 'err_cb':  'ROnJobStderr',
            \ 'exit_cb': 'ROnJobExit'}


" Check if Vim-R-plugin is installed
let s:ff = globpath(&rtp, "r-plugin/functions.vim")
let s:ft = globpath(&rtp, "ftplugin/r*_rplugin.vim")
if s:ff != "" || s:ft != ""
    let s:ff = substitute(s:ff, "functions.vim", "", "g")
    call RWarningMsg("Nvim-R conflicts with Vim-R-plugin. Please, uninstall Vim-R-plugin.\n" .
                \ "At least the following directories and files are from a Vim-R-plugin installation:\n" . s:ff . "\n" . s:ft . "\n")
endif
unlet s:ff
unlet s:ft
