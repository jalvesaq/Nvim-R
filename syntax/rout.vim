" Vim syntax file
" Language:    R output Files
" Maintainer:  Jakson Aquino <jalvesaq@gmail.com>


if exists("b:current_syntax")
    finish
endif

setlocal iskeyword=@,48-57,_,.

syn case match

" Normal text
syn match routNormal "."

" Strings
syn region routString start=/"/ skip=/\\\\\|\\"/ end=/"/ end=/$/

" Constants
syn keyword routConst  NULL NA NaN
syn keyword routTrue   TRUE
syn keyword routFalse  FALSE
syn match routConst "\<Na's\>"
syn match routInf "-Inf\>"
syn match routInf "\<Inf\>"

" integer
syn match routInteger "\<\d\+L"
syn match routInteger "\<0x\([0-9]\|[a-f]\|[A-F]\)\+L"
syn match routInteger "\<\d\+[Ee]+\=\d\+L"

" number with no fractional part or exponent
syn match routNumber "\<\d\+\>"
syn match routNegNum "-\<\d\+\>"
" hexadecimal number
syn match routNumber "\<0x\([0-9]\|[a-f]\|[A-F]\)\+"

let g:R_OutDec = get(g:, "R_OutDec", ".")

if g:R_OutDec == ","
    syn match routFloat "\<\d\+,\d*\([Ee][-+]\=\d\+\)\="
    syn match routNegFloat "-\<\d\+,\d*\([Ee][-+]\=\d\+\)\="
    syn match routFloat "\<,\d\+\([Ee][-+]\=\d\+\)\="
    syn match routNegFloat "-\<,\d\+\([Ee][-+]\=\d\+\)\="
    syn match routFloat "\<\d\+[Ee][-+]\=\d\+"
    syn match routNegFloat "-\<\d\+[Ee][-+]\=\d\+"
    syn match routComplex "\<\d\+i"
    syn match routComplex "\<\d\++\d\+i"
    syn match routComplex "\<0x\([0-9]\|[a-f]\|[A-F]\)\+i"
    syn match routComplex "\<\d\+,\d*\([Ee][-+]\=\d\+\)\=i"
    syn match routComplex "\<,\d\+\([Ee][-+]\=\d\+\)\=i"
    syn match routComplex "\<\d\+[Ee][-+]\=\d\+i"
else
    " floating point number with integer and fractional parts and optional exponent
    syn match routFloat "\<\d\+\.\d*\([Ee][-+]\=\d\+\)\="
    syn match routNegFloat "-\<\d\+\.\d*\([Ee][-+]\=\d\+\)\="
    " floating point number with no integer part and optional exponent
    syn match routFloat "\<\.\d\+\([Ee][-+]\=\d\+\)\="
    syn match routNegFloat "-\<\.\d\+\([Ee][-+]\=\d\+\)\="
    " floating point number with no fractional part and optional exponent
    syn match routFloat "\<\d\+[Ee][-+]\=\d\+"
    syn match routNegFloat "-\<\d\+[Ee][-+]\=\d\+"
    " complex number
    syn match routComplex "\<\d\+i"
    syn match routComplex "\<\d\++\d\+i"
    syn match routComplex "\<0x\([0-9]\|[a-f]\|[A-F]\)\+i"
    syn match routComplex "\<\d\+\.\d*\([Ee][-+]\=\d\+\)\=i"
    syn match routComplex "\<\.\d\+\([Ee][-+]\=\d\+\)\=i"
    syn match routComplex "\<\d\+[Ee][-+]\=\d\+i"
endif


" dates and times
syn match routDate "[0-9][0-9][0-9][0-9][-/][0-9][0-9][-/][0-9][-0-9]"
syn match routDate "[0-9][0-9][-/][0-9][0-9][-/][0-9][0-9][0-9][-0-9]"
syn match routDate "[0-9][0-9]:[0-9][0-9]:[0-9][-0-9]"

if !exists("g:Rout_more_colors")
    let g:Rout_more_colors = 0
endif

let g:Rout_prompt_str = get(g:, 'Rout_prompt_str', '>')
let g:Rout_continue_str = get(g:, 'Rout_continue_str', '+')

if g:Rout_more_colors
    syn include @routR syntax/r.vim
    exe 'syn region routColoredR start=/^' . g:Rout_prompt_str . '/ end=/$/ contains=@routR keepend'
    exe 'syn region routColoredR start=/^' . g:Rout_continue_str . '/ end=/$/ contains=@routR keepend'
else
    " Input
    exe 'syn match routInput /^' . g:Rout_prompt_str . '.*/'
    exe 'syn match routInput /^' . g:Rout_continue_str . '.*/'
endif

" Index of vectors
syn match routIndex /^\s*\[\d\+\]/

" Errors and warnings
syn match routError "^Error.*"
syn match routWarn "^Warning.*"

if v:lang =~ "^da"
    syn match routError	"^Fejl.*"
    syn match routWarn	"^Advarsel.*"
endif

if v:lang =~ "^de"
    syn match routError	"^Fehler.*"
    syn match routWarn	"^Warnung.*"
endif

if v:lang =~ "^es"
    syn match routWarn	"^Aviso.*"
endif

if v:lang =~ "^fr"
    syn match routError	"^Erreur.*"
    syn match routWarn	"^Avis.*"
endif

if v:lang =~ "^it"
    syn match routError	"^Errore.*"
    syn match routWarn	"^Avviso.*"
endif

if v:lang =~ "^nn"
    syn match routError	"^Feil.*"
    syn match routWarn	"^Åtvaring.*"
endif

if v:lang =~ "^pl"
    syn match routError	"^BŁĄD.*"
    syn match routError	"^Błąd.*"
    syn match routWarn	"^Ostrzeżenie.*"
endif

if v:lang =~ "^pt_BR"
    syn match routError	"^Erro.*"
    syn match routWarn	"^Aviso.*"
endif

if v:lang =~ "^ru"
    syn match routError	"^Ошибка.*"
    syn match routWarn	"^Предупреждение.*"
endif

if v:lang =~ "^tr"
    syn match routError	"^Hata.*"
    syn match routWarn	"^Uyarı.*"
endif

" Define the default highlighting.
if g:Rout_more_colors == 0
    hi def link routInput	Comment
endif

if exists("g:rout_follow_colorscheme") && g:rout_follow_colorscheme
    " Default when following :colorscheme
    hi def link routNormal	Normal
    hi def link routNumber	Number
    hi def link routInteger	Number
    hi def link routFloat	Float
    hi def link routComplex	Number
    hi def link routNegNum	Number
    hi def link routNegFloat	Float
    hi def link routDate	Number
    hi def link routTrue	Boolean
    hi def link routFalse	Boolean
    hi def link routInf  	Number
    hi def link routConst	Constant
    hi def link routString	String
    hi def link routIndex	Special
    hi def link routError	ErrorMsg
    hi def link routWarn	WarningMsg
else
    function s:SetGroupColor(group, cgui, c256, c16)
        if exists("g:rout_color_" . tolower(a:group))
            exe "hi rout" . a:group . eval("g:rout_color_" . tolower(a:group))
        elseif &t_Co == 256
            exe "hi rout" . a:group . "ctermfg=" . a:c256 . " guifg=" . a:cgui
        else
            exe "hi rout" . a:group . "ctermfg=" . a:c16 . " guifg=" . a:cgui
        endif
    endfunction
    call s:SetGroupColor("Input ",    "#9e9e9e",               "247",          "gray")
    call s:SetGroupColor("Normal ",   "#00d700",               "40",           "darkgreen")
    call s:SetGroupColor("Number ",   "#ffaf00",               "214",          "darkyellow")
    call s:SetGroupColor("Integer ",  "#ffaf00",               "214",          "darkyellow")
    call s:SetGroupColor("Float ",    "#ffaf00",               "214",          "darkyellow")
    call s:SetGroupColor("Complex ",  "#ffaf00",               "214",          "darkyellow")
    call s:SetGroupColor("NegNum ",   "#ff875f",               "209",          "darkyellow")
    call s:SetGroupColor("NegFloat ", "#ff875f",               "209",          "darkyellow")
    call s:SetGroupColor("Date ",     "#d7af5f",               "179",          "darkyellow")
    call s:SetGroupColor("False ",    "#ff5f5f",               "203",          "darkyellow")
    call s:SetGroupColor("True ",     "#5fd787",               "78",           "magenta")
    call s:SetGroupColor("Inf ",      "#00afff",               "39",           "darkgreen")
    call s:SetGroupColor("Const ",    "#00af5f",               "35",           "magenta")
    call s:SetGroupColor("String ",   "#5fffaf",               "85",           "darkcyan")
    call s:SetGroupColor("Error ",    "#ffffff guibg=#c00000", "15 ctermbg=1", "white ctermbg=red")
    call s:SetGroupColor("Warn ",     "#c00000",               "1",            "red")
    call s:SetGroupColor("Index ",    "#87afaf",               "109",          "darkgreen")
    delfunction s:SetGroupColor
endif

let   b:current_syntax = "rout"

" vim: ts=8 sw=4
