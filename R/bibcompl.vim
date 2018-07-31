if exists('b:rplugin_bib_engine')
    finish
endif

if exists('g:R_bib_engine')
    let b:rplugin_bib_engine = g:R_bib_engine
elseif &filetype == 'rnoweb'
    let b:rplugin_bib_engine = 'bibtex'
else
    " Unless bib files are already in use...
    let s:bibf = glob(expand("%:p:h") . '/*.bib', 0, 1)
    if len(s:bibf) > 0
        let b:rplugin_bib_engine = 'bibtex'
    elseif getline(1) == '---'
        let lines = getline(2, '$')
        for line in lines
            if line =~ '^\s*bibliography\s*:'
                let b:rplugin_bib_engine = 'bibtex'
                break
            elseif line == '...' || line == '---'
                break
            endif
        endfor
    endif
    " ... zotero has priority:
    if !exists('b:rplugin_bib_engine')
        if exists('g:R_zotero_sqlite') || filereadable(expand('~/Zotero/zotero.sqlite'))
            let b:rplugin_bib_engine = 'zotero'
        else
            let b:rplugin_bib_engine = 'bibtex'
        endif
    endif
endif

if exists('*RCompleteBib')
    finish
endif

function RCompleteBib(base)
    if !IsJobRunning("BibComplete")
        return []
    endif
    if b:rplugin_bib_engine == 'bibtex' && b:rplugin_bibf == ''
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

function CheckZotero()
    if !s:HasPython3()
        return
    endif
    if exists("g:R_zotero_sqlite")
        if !filereadable(g:R_zotero_sqlite)
            call RWarningMsgInp('Could not read g:R_zotero_sqlite: "' . g:R_zotero_sqlite . '"')
            unlet g:R_zotero_sqlite
        endif
    elseif filereadable(expand('~/Zotero/zotero.sqlite'))
        let g:R_zotero_sqlite = expand('~/Zotero/zotero.sqlite')
    endif

    if !exists("g:R_zotero_sqlite")
        let g:rplugin_debug_info['BibComplete'] = "No zotero.sqlite"
    endif

    if !exists("g:R_banned_keys")
        let g:R_banned_keys = 'a an the some from on in to of do with'
        let banned = {'es': ' el la las lo los uno una unos unas al de en no con para',
                    \ 'fr': ' la les l un une quelques à un de avec pour',
                    \ 'pt': ' o um uma uns umas à ao de da dos em na no com para',
                    \ 'it': ' la le l gli un una alcuni alcune all alla da dei nell con per',
                    \ 'de': ' der die das ein eine einer eines einem einen einige im zu mit für von'
                    \ }
        if has_key(banned, tolower(v:lang[0:1]))
            let g:R_banned_keys .= banned[tolower(v:lang[0:1])]
        endif
    endif
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

function GetZoteroAttachment()
    if b:IsInRCode(0)
        exe 'tag ' . expand('<cword>')
        return
    endif
    let oldisk = &iskeyword
    set iskeyword=@,48-57,_,192-255,@-@
    let wrd = expand('<cword>')
    exe 'set iskeyword=' . oldisk
    if wrd =~ '^@'
        let wrd = substitute(wrd, '^@', '', '')
        if wrd != ''
            let g:rplugin_last_attach = ''
            if b:rplugin_bib_engine == 'zotero'
                call JobStdin(g:rplugin_jobs["BibComplete"], "\x02" . b:rplugin_cllctn . "\x05" . wrd . "\n")
            else
                call JobStdin(g:rplugin_jobs["BibComplete"], "\x02" . expand("%:p") . "\x05" . wrd . "\n")
            endif
            sleep 20m
            let count = 0
            while count < 100 && g:rplugin_last_attach == ''
                let count += 1
                sleep 10m
            endwhile
            if g:rplugin_last_attach == 'nOaTtAChMeNt'
                call RWarningMsg(wrd . "'s attachment not found")
            elseif g:rplugin_last_attach =~ 'nOcLlCtN:'
                call RWarningMsg('Collection "' . substitute(g:rplugin_last_attach, 'nOcLlCtN:', '', '') . '" not found')
            elseif g:rplugin_last_attach =~ 'nObIb:'
                call RWarningMsg('"' . substitute(g:rplugin_last_attach, 'nObIb:', '', '') . '" not found')
            elseif g:rplugin_last_attach == 'nOcItEkEy'
                call RWarningMsg(wrd . " not found")
            elseif g:rplugin_last_attach == ''
                call RWarningMsg('No reply from BibComplete')
            else
                let fpath = g:rplugin_last_attach
                if b:rplugin_bib_engine == 'zotero' && g:rplugin_last_attach =~ ':storage:'
                    let fpath = expand('~/Zotero/storage/') . substitute(g:rplugin_last_attach, ':storage:', '/', '')
                elseif b:rplugin_bib_engine == 'bibtex'
                    let fls = split(fpath, ':')
                    if filereadable(fls[0])
                        let fpath = [0]
                    elseif len(fls) > 1 && filereadable(fls[1])
                        let fpath = fls[1]
                    endif
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
