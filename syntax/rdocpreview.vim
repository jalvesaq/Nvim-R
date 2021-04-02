
syntax clear

if g:rplugin.compl_cls == 'f'
    runtime syntax/r.vim
    syn region previewDescr matchgroup=NONE start="^ " matchgroup=NONE end=' $'
elseif g:rplugin.compl_cls == 'a'
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
