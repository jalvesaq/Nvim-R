syntax clear

syn match inLineCodeDelim /`/ conceal contained
syn match mdIBDelim /*/ conceal contained

syn region markdownCode start="`" end="`" keepend contains=inLineCodeDelim concealends
syn region mdItalic start="\*\ze\S" end="\S\zs\*\|^$" skip="\\\*" contains=mdIBDelim keepend concealends
syn region mdBold start="\*\*\ze\S" end="\S\zs\*\*\|^$" skip="\\\*" contains=mdIBDelim keepend concealends
syn region mdBoldItalic start="\*\*\*\ze\S" end="\S\zs\*\*\*\|^$" skip="\\\*" contains=mdIBDelim keepend concealends

if g:rplugin.compl_cls == 'f'
    syn include @R syntax/r.vim
    syn region rCodeRegion start="^```{R} $" end="^\ze```$" contains=@R,docCodeDelim1,docCodeDelim2
    syn match docCodeDelim2 /```/ contained conceal
    syn match docCodeDelim1 /```{R}/ contained conceal
else
    syn include @Rout syntax/rout.vim
    syn region rCodeRegion start="^```{Rout} $" end="^```$" contains=@Rout,docCodeDelim1,docCodeDelim2
    syn match docCodeDelim2 /```/ contained conceal
    syn match docCodeDelim1 /```{Rout}/ contained conceal
endif

hi link markdownCode Special
hi mdItalic term=italic cterm=italic gui=italic
hi mdBold term=bold cterm=bold gui=bold
hi mdBoldItalic term=bold cterm=bold gui=bold
