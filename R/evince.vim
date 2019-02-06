
if exists("*Run_EvinceBackward")
    finish
endif

function ROpenPDF2(fullpath)
    let pcmd = "evince '" . a:fullpath . "' 2>/dev/null >/dev/null &"
    call system(pcmd)
endfunction

function SyncTeX_forward2(tpath, ppath, texln, unused)
    " Most of Evince's code requires spaces replaced by %20, but the
    " actual file name is processed by a SyncTeX library that does not:
    let n1 = substitute(a:tpath, '\(^/.*/\).*', '\1', '')
    let n2 = substitute(a:tpath, '.*/\(.*\)', '\1', '')
    let texname = substitute(n1, " ", "%20", "g") . n2

    let pdfname = substitute(a:ppath, " ", "%20", "g")

    if g:rplugin.evince_loop < 2
        let g:rplugin.jobs["Python (Evince forward)"] = StartJob(["python",
                    \ g:rplugin.home . "/R/synctex_evince_forward.py",
                    \ texname, pdfname, string(a:texln)], g:rplugin.job_handlers)
    else
        let g:rplugin.evince_loop = 0
    endif
    if g:rplugin.has_wmctrl
        call system("wmctrl -a '" . substitute(a:ppath, ".*/", "", "") . "'")
    endif
endfunction

function Run_EvinceBackward()
    let basenm = SyncTeX_GetMaster() . ".pdf"
    let pdfpath = b:rplugin_pdfdir . "/" . substitute(basenm, ".*/", "", "")
    let did_evince = 0
    if !exists("s:evince_list")
        let s:evince_list = []
    else
        for bb in s:evince_list
            if bb == pdfpath
                let did_evince = 1
                break
            endif
        endfor
    endif
    if !did_evince
        call add(s:evince_list, pdfpath)
        let g:rplugin.jobs["Python (Evince backward)"] = StartJob(["python", g:rplugin.home . "/R/synctex_evince_backward.py", pdfpath], g:rplugin.job_handlers)
    endif
endfunction

" Avoid possible infinite loop if Evince cannot open the document and
" synctex_evince_forward.py keeps sending the message to Neovim run
" SyncTeX_forward() again.
function! Evince_Again()
    let g:rplugin.evince_loop += 1
    call SyncTeX_forward()
endfunction
