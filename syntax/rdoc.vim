" Vim syntax file
" Language:	R documentation
" Maintainer:	Jakson A. Aquino <jalvesaq@gmail.com>

if exists("b:current_syntax")
    finish
endif

setlocal iskeyword=@,48-57,_,.
setlocal conceallevel=2
setlocal concealcursor=nvc

if exists("rdoc_minlines") && exists("rdoc_maxlines")
    exec "syn sync minlines=" . rdoc_minlines . " maxlines=" . rdoc_maxlines
else
    syn sync fromstart
endif


syn match  rdocTitle	      "^[A-Z].*:$"
syn match  rdocTitle "^\S.*R Documentation$"
syn match rdocFunction "\([A-Z]\|[a-z]\|\.\|_\)\([A-Z]\|[a-z]\|[0-9]\|\.\|_\)*" contained
syn region rdocStringS  start="\%u2018" end="\%u2019" contains=rdocFunction transparent keepend
syn region rdocStringS  start="\%x91" end="\%x92" contains=rdocFunction transparent keepend
syn region rdocStringD  start='"' skip='\\"' end='"'
syn match rdocURL " |.\{-}|" contains=rdocURLBar
syn match rdocURLBar contained " " conceal
syn match rdocURLBar contained "|" conceal
syn keyword rdocNote		note Note NOTE note: Note: NOTE: Notes Notes:

" When using vim as R pager to see the output of help.search():
syn region rdocPackage start="^[A-Za-z]\S*::" end="[\s\r]" contains=rdocPackName,rdocFuncName transparent
syn match rdocPackName "^[A-Za-z][A-Za-z0-9\.]*" contained
syn match rdocFuncName "::[A-Za-z0-9\.\-_]*" contained

syn region rdocArgReg matchgroup=rdocArgTitle start="^Arguments:" matchgroup=NONE end="^ \t" contains=rdocArg,rdocArgTitle,rdocPackage,rdocFuncName,rdocStringS keepend transparent
syn match rdocArg "^\s*\([A-Z]\|[a-z]\|[0-9]\|\.\|_\)*\ze:" contained extend

syn include @rdocR syntax/r.vim
syn region rdocExample matchgroup=rdocExTitle start="^Examples:$" matchgroup=rdocExEnd end='^###$' contains=@rdocR keepend
syn region rdocUsage matchgroup=rdocTitle start="^Usage:$" matchgroup=NONE end='^\t' contains=@rdocR

syn sync match rdocSyncExample grouphere rdocExample "^Examples:$"
syn sync match rdocSyncUsage grouphere rdocUsage "^Usage:$"
syn sync match rdocSyncArg grouphere rdocArgReg "^Arguments:"
syn sync match rdocSyncNONE grouphere NONE "^\t$"
syn sync match rdocSyncNONE grouphere NONE "^ \t$"


" Define the default highlighting.
hi def link rdocTitle	    Title
hi def link rdocArgTitle    Title
hi def link rdocExTitle   Title
hi def link rdocExEnd   Comment
hi def link rdocFunction    Function
hi def link rdocStringD     String
hi def link rdocURL    Underlined
hi def link rdocArg         Special
hi def link rdocNote  Todo

hi def link rdocPackName Title
hi def link rdocFuncName Function

let b:current_syntax = "rdoc"

" vim: ts=8 sw=4
