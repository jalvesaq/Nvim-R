if exists('*RCompleteBib')
    finish
endif

function RCompleteBib(base)
    if !IsJobRunning("BibComplete")
        return []
    endif
    if b:rplugin_bibf == ''
        call RWarningMsgInp('Bib file not defined')
        return []
    endif
    call delete(g:rplugin_tmpdir . "/bibcompl")
    let g:rplugin_bib_finished = 0
    call JobStdin(g:rplugin_jobs["BibComplete"], "\x03" . a:base . "\x05" . expand("%:p") . "\n")
    call AddForDeletion(g:rplugin_tmpdir . "/bibcompl")
    let resp = []
    let wt = 0
    sleep 20m
    while wt < 10 && g:rplugin_bib_finished == 0
        let wt += 1
        sleep 50m
    endwhile
    if filereadable(g:rplugin_tmpdir . "/bibcompl")
        let lines = readfile(g:rplugin_tmpdir . "/bibcompl")
        for line in lines
            let tmp = split(line, "\x09")
            call add(resp, {'word': tmp[0], 'abbr': tmp[1], 'menu': tmp[2]})
        endfor
    endif
    return resp
endfunction

function s:HasPython3()
    if exists("g:R_python3")
        if filereadable("g:R_python3")
            if executable("g:R_python3")
                let g:rplugin_py3 = g:R_python3
                return 1
            else
                call RWarningMsg(g:R_python3 . ' is not executable')
            endif
        else
            call RWarningMsg(g:R_python3 . ' not found')
        endif
        return 0
    endif
    let out = system('python3 --version')
    if v:shell_error == 0 && out =~ 'Python 3'
        let g:rplugin_py3 = 'python3'
    else
        let out = system('python --version')
        if v:shell_error == 0 && out =~ 'Python 3'
            let g:rplugin_py3 = 'python'
        else
            let g:rplugin_debug_info['BibComplete'] = "No Python 3"
            let g:rplugin_py3 = ''
            return 0
        endif
    endif
    return 1
endfunction

function CheckPyBTeX()
    if !s:HasPython3()
        return
    endif
    call system(g:rplugin_py3, "from pybtex.database import parse_file\n")
    if v:shell_error != 0
        let g:rplugin_debug_info['BibComplete'] = "No PyBTex"
        let g:rplugin_py3 = ''
    endif
endfunction

function GetBibAttachment()
    let oldisk = &iskeyword
    set iskeyword=@,48-57,_,192-255,@-@
    let wrd = expand('<cword>')
    exe 'set iskeyword=' . oldisk
    if wrd =~ '^@'
        let wrd = substitute(wrd, '^@', '', '')
        if wrd != ''
            let g:rplugin_last_attach = ''
            call JobStdin(g:rplugin_jobs["BibComplete"], "\x02" . expand("%:p") . "\x05" . wrd . "\n")
            sleep 20m
            let count = 0
            while count < 100 && g:rplugin_last_attach == ''
                let count += 1
                sleep 10m
            endwhile
            if g:rplugin_last_attach == 'nOaTtAChMeNt'
                call RWarningMsg(wrd . "'s attachment not found")
            elseif g:rplugin_last_attach =~ 'nObIb:'
                call RWarningMsg('"' . substitute(g:rplugin_last_attach, 'nObIb:', '', '') . '" not found')
            elseif g:rplugin_last_attach == 'nOcItEkEy'
                call RWarningMsg(wrd . " not found")
            elseif g:rplugin_last_attach == ''
                call RWarningMsg('No reply from BibComplete')
            else
                let fpath = g:rplugin_last_attach
                let fls = split(fpath, ':')
                if filereadable(fls[0])
                    let fpath = [0]
                elseif len(fls) > 1 && filereadable(fls[1])
                    let fpath = fls[1]
                endif
                if filereadable(fpath)
                    if has('win32') || g:rplugin_is_darwin
                        call system('open "' . fpath . '"')
                    else
                        call system('xdg-open "' . fpath . '"')
                    endif
                else
                    call RWarningMsg('Could not find "' . fpath . '"')
                endif
            endif
        endif
    endif
endfunction
