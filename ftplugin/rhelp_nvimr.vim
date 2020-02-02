
if exists("g:disable_r_ftplugin")
    finish
endif

" Source scripts common to R, Rnoweb, Rhelp and rdoc files:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_global.vim"
if exists("g:rplugin.failed")
    finish
endif

" Some buffer variables common to R, Rnoweb, Rhelp and rdoc file need be
" defined after the global ones:
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_buffer.vim"

function! RhelpIsInRCode(vrb)
    let lastsec = search('^\\[a-z][a-z]*{', "bncW")
    let secname = getline(lastsec)
    if line(".") > lastsec && (secname =~ '^\\usage{' || secname =~ '^\\examples{' || secname =~ '^\\dontshow{' || secname =~ '^\\dontrun{' || secname =~ '^\\donttest{' || secname =~ '^\\testonly{')
        return 1
    else
        if a:vrb
            call RWarningMsg("Not inside an R section.")
        endif
        return 0
    endif
endfunction

function! RhelpComplete(findstart, base)
    if a:findstart
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && (line[start - 1] =~ '\w' || line[start - 1] == '\')
            let start -= 1
        endwhile
        return start
    else
        let resp = []
        let hwords = ['\Alpha', '\Beta', '\Chi', '\Delta', '\Epsilon',
                    \ '\Eta', '\Gamma', '\Iota', '\Kappa', '\Lambda', '\Mu', '\Nu',
                    \ '\Omega', '\Omicron', '\Phi', '\Pi', '\Psi', '\R', '\Rdversion',
                    \ '\Rho', '\S4method', '\Sexpr', '\Sigma', '\Tau', '\Theta', '\Upsilon',
                    \ '\Xi', '\Zeta', '\acronym', '\alias', '\alpha', '\arguments',
                    \ '\author', '\beta', '\bold', '\chi', '\cite', '\code', '\command',
                    \ '\concept', '\cr', '\dQuote', '\delta', '\deqn', '\describe',
                    \ '\description', '\details', '\dfn', '\docType', '\dontrun', '\dontshow',
                    \ '\donttest', '\dots', '\email', '\emph', '\encoding', '\enumerate',
                    \ '\env', '\epsilon', '\eqn', '\eta', '\examples', '\file', '\format',
                    \ '\gamma', '\ge', '\href', '\iota', '\item', '\itemize', '\kappa',
                    \ '\kbd', '\keyword', '\lambda', '\ldots', '\le',
                    \ '\link', '\linkS4class', '\method', '\mu', '\name', '\newcommand',
                    \ '\note', '\nu', '\omega', '\omicron', '\option', '\phi', '\pi',
                    \ '\pkg', '\preformatted', '\psi', '\references', '\renewcommand', '\rho',
                    \ '\sQuote', '\samp', '\section', '\seealso', '\sigma', '\source',
                    \ '\special', '\strong', '\subsection', '\synopsis', '\tab', '\tabular',
                    \ '\tau', '\testonly', '\theta', '\title', '\upsilon', '\url', '\usage',
                    \ '\value', '\var', '\verb', '\xi', '\zeta']
        for word in hwords
            if word =~ '^' . escape(a:base, '\')
                call add(resp, {'word': word})
            endif
        endfor
        return resp
    endif
endfunction

let b:IsInRCode = function("RhelpIsInRCode")
let b:rplugin_non_r_omnifunc = "RhelpComplete"

"==========================================================================
" Key bindings and menu items

call RCreateStartMaps()
call RCreateEditMaps()
call RCreateSendMaps()
call RControlMaps()
call RCreateMaps('nvi', 'RSetwd', 'rd', ':call RSetWD()')

" Menu R
if has("gui_running")
    exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/gui_running.vim"
    call MakeRMenu()
endif

call RSourceOtherScripts()

if exists("b:undo_ftplugin")
    let b:undo_ftplugin .= " | unlet! b:IsInRCode"
else
    let b:undo_ftplugin = "unlet! b:IsInRCode"
endif
