
syntax clear
exe "source " . substitute(g:rplugin.home, " ", "\\ ", "g") . "/syntax/rdoc.vim"
syn match rdocArg2 "^\([A-Z]\|[a-z]\|[0-9]\|\.\|_\)\{-}\ze:"
syn match rdocTitle2 '^Description: '
syn region rdocUsage matchgroup=rdocTitle start="^Usage: " matchgroup=NONE end='\t$' contains=@rdocR
hi def link rdocArg2 Special
hi def link rdocTitle2 Title
