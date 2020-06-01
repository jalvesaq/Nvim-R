
syntax clear

if has('nvim-0.4.3') || has('patch-8.1.1705')
    if g:rplugin.compl_cls == 'function'
        runtime syntax/r.vim
        syn region previewDescr matchgroup=NONE start="^ " matchgroup=NONE end=' $'
    elseif g:rplugin.compl_cls == 'argument'
        runtime syntax/rdoc.vim
        syn match previewArg "^ \zs\S\{-}\ze:"
    else
        runtime syntax/rout.vim
        syn region previewDescr matchgroup=NONE start="^ " matchgroup=NONE end=' $'
    endif
    syn match previewSep "———*"

    hi def link previewDescr NormalFloat
    hi def link previewSep   NormalFloat
    hi def link previewArg Special
    hi def link rLstElmt     NormalFloat
    hi def link rNameWSpace  NormalFloat
else
    exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/syntax/rdoc.vim"
    syn match rdocArg2 "^\([A-Z]\|[a-z]\|[0-9]\|\.\|_\)\{-}\ze:"
    syn match rdocTitle2 '^Description: '
    syn region rdocUsage matchgroup=rdocTitle start="^Usage: " matchgroup=NONE end='\t$' contains=@rdocR
    hi def link rdocTitle2 Title
    hi def link rdocArg2 Special
endif
