if exists('*RCompleteBib')
    finish
endif

function RCompleteBib(base)
    if !IsJobRunning("BibComplete")
        return []
    endif
    if b:rplugin_bibf == ''
        call RWarningMsg('Bib file not defined')
        return []
    endif
    call delete(g:rplugin.tmpdir . "/bibcompl")
    let g:rplugin.bib_finished = 0
    call JobStdin(g:rplugin.jobs["BibComplete"], "\x03" . a:base . "\x05" . expand("%:p") . "\n")
    call AddForDeletion(g:rplugin.tmpdir . "/bibcompl")
    let resp = []
    let wt = 0
    sleep 20m
    while wt < 10 && g:rplugin.bib_finished == 0
        let wt += 1
        sleep 50m
    endwhile
    if filereadable(g:rplugin.tmpdir . "/bibcompl")
        let lines = readfile(g:rplugin.tmpdir . "/bibcompl")
        for line in lines
            let tmp = split(line, "\x09")
            call add(resp, {'word': tmp[0], 'abbr': tmp[1], 'menu': tmp[2]})
        endfor
    endif
    return resp
endfunction

function! s:GetBibFileName()
    if !exists('b:rplugin_bibf')
        let b:rplugin_bibf = ''
    endif
    if &filetype == 'rmd' || &filetype == 'quarto'
        let newbibf = RmdGetYamlField('bibliography')
        if newbibf == ''
            let newbibf = join(glob(expand("%:p:h") . '/*.bib', 0, 1), "\x06")
        endif
    else
        let newbibf = join(glob(expand("%:p:h") . '/*.bib', 0, 1), "\x06")
    endif
    if newbibf != b:rplugin_bibf && newbibf !~ 'zotcite.bib$'
        let b:rplugin_bibf = newbibf
        if IsJobRunning('BibComplete')
            call JobStdin(g:rplugin.jobs["BibComplete"], "\x04" . expand("%:p") . "\x05" . b:rplugin_bibf . "\n")
        else
            let aa = [g:rplugin.py3, g:rplugin.home . '/R/bibtex.py', expand("%:p"), b:rplugin_bibf]
            let g:rplugin.jobs["BibComplete"] = StartJob(aa, g:rplugin.job_handlers)
            call RCreateMaps('n', 'ROpenRefFile', 'od', ':call GetBibAttachment()')
        endif
    endif
endfunction

function s:HasPython3()
    if exists("g:R_python3")
        if filereadable("g:R_python3")
            if executable("g:R_python3")
                let g:rplugin.py3 = g:R_python3
                return 1
            else
                let g:rplugin.debug_info['BibComplete'] = g:R_python3 . ' is not executable'
            endif
        else
            let g:rplugin.debug_info['BibComplete'] = g:R_python3 . ' not found'
        endif
        return 0
    endif
    silent let out = system('python3 --version')
    if v:shell_error == 0 && out =~ 'Python 3'
        let g:rplugin.py3 = 'python3'
    else
        silent let out = system('python --version')
        if v:shell_error == 0 && out =~ 'Python 3'
            let g:rplugin.py3 = 'python'
        else
            let g:rplugin.debug_info['BibComplete'] = "No Python 3"
            let g:rplugin.py3 = ''
            return 0
        endif
    endif
    return 1
endfunction

function CheckPyBTeX(...)
    if !has_key(g:rplugin.debug_info, 'BibComplete')
        if !s:HasPython3()
            return
        endif
        silent call system(g:rplugin.py3, "from pybtex.database import parse_file\n")
        if v:shell_error == 0
            let g:rplugin.debug_info['BibComplete'] = "PyBTex OK"
        else
            let g:rplugin.debug_info['BibComplete'] = "No PyBTex"
            let g:rplugin.py3 = ''
        endif
    endif
    if g:rplugin.debug_info['BibComplete'] == "PyBTex OK"
        " Use RBibComplete if possible
        call s:GetBibFileName()
        if !exists("b:rplugin_did_bib_autocmd")
            autocmd BufWritePost <buffer> call s:GetBibFileName()
            if &filetype == 'rnoweb'
                let b:rplugin_non_r_omnifunc = "RnwNonRCompletion"
                autocmd CompleteDone <buffer> call RnwOnCompleteDone()
            endif
        endif
        let b:rplugin_did_bib_autocmd = 1
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
            let g:rplugin.last_attach = ''
            call JobStdin(g:rplugin.jobs["BibComplete"], "\x02" . expand("%:p") . "\x05" . wrd . "\n")
            sleep 20m
            let count = 0
            while count < 100 && g:rplugin.last_attach == ''
                let count += 1
                sleep 10m
            endwhile
            if g:rplugin.last_attach == 'nOaTtAChMeNt'
                call RWarningMsg(wrd . "'s attachment not found")
            elseif g:rplugin.last_attach =~ 'nObIb:'
                call RWarningMsg('"' . substitute(g:rplugin.last_attach, 'nObIb:', '', '') . '" not found')
            elseif g:rplugin.last_attach == 'nOcItEkEy'
                call RWarningMsg(wrd . " not found")
            elseif g:rplugin.last_attach == ''
                call RWarningMsg('No reply from BibComplete')
            else
                let fpath = g:rplugin.last_attach
                let fls = split(fpath, ':')
                if filereadable(fls[0])
                    let fpath = fls[0]
                elseif len(fls) > 1 && filereadable(fls[1])
                    let fpath = fls[1]
                endif
                if filereadable(fpath)
                    if has('win32') || g:rplugin.is_darwin
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
