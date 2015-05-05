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

" floating point number with integer and fractional parts and optional exponent
syn match routFloat "\<\d\+\.\d*\([Ee][-+]\=\d\+\)\="
syn match routNegFlt "-\<\d\+\.\d*\([Ee][-+]\=\d\+\)\="
" floating point number with no integer part and optional exponent
syn match routFloat "\<\.\d\+\([Ee][-+]\=\d\+\)\="
syn match routNegFlt "-\<\.\d\+\([Ee][-+]\=\d\+\)\="
" floating point number with no fractional part and optional exponent
syn match routFloat "\<\d\+[Ee][-+]\=\d\+"
syn match routNegFlt "-\<\d\+[Ee][-+]\=\d\+"

" complex number
syn match routComplex "\<\d\+i"
syn match routComplex "\<\d\++\d\+i"
syn match routComplex "\<0x\([0-9]\|[a-f]\|[A-F]\)\+i"
syn match routComplex "\<\d\+\.\d*\([Ee][-+]\=\d\+\)\=i"
syn match routComplex "\<\.\d\+\([Ee][-+]\=\d\+\)\=i"
syn match routComplex "\<\d\+[Ee][-+]\=\d\+i"

" dates and times
syn match routDate "[0-9][0-9][0-9][0-9][-/][0-9][0-9][-/][0-9][-0-9]"
syn match routDate "[0-9][0-9][-/][0-9][0-9][-/][0-9][0-9][0-9][-0-9]"
syn match routDate "[0-9][0-9]:[0-9][0-9]:[0-9][-0-9]"

if !exists("g:Rout_more_colors")
    let g:Rout_more_colors = 0
endif

if g:Rout_more_colors
    syn include @routR syntax/r.vim
    syn region routColoredR start="^>" end='$' contains=@routR keepend
    syn region routColoredR start="^+" end='$' contains=@routR keepend
else
    " Input
    syn match routInput /^>.*/
    syn match routInput /^+.*/
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
    hi def link routNegFlt	Float
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
    if has("gui_running")
        " Default 256 colors scheme for R output:
        hi routInput	guifg=#9e9e9e
        hi routNormal	guifg=#00d700
        hi routNumber	guifg=#ffaf00
        hi routInteger	guifg=#ffaf00
        hi routFloat	guifg=#ffaf00
        hi routComplex	guifg=#ffaf00
        hi routNegNum	guifg=#ff875f
        hi routNegFlt	guifg=#ff875f
        hi routDate	guifg=#d7af5f
        hi routFalse	guifg=#ff5f5f
        hi routTrue	guifg=#5fd787
        hi routInf      guifg=#00afff
        hi routConst	guifg=#00af5f
        hi routString	guifg=#5fffaf
        hi routError	guifg=#ffffff guibg=#c00000
        hi routWarn	guifg=#c00000
        hi routIndex	guifg=#87afaf
    elseif &t_Co == 256
        " Default 256 colors scheme for R output:
        hi routInput	ctermfg=247
        hi routNormal	ctermfg=40
        hi routNumber	ctermfg=214
        hi routInteger	ctermfg=214
        hi routFloat	ctermfg=214
        hi routComplex	ctermfg=214
        hi routNegNum	ctermfg=209
        hi routNegFlt	ctermfg=209
        hi routDate	ctermfg=179
        hi routFalse	ctermfg=203
        hi routTrue	ctermfg=78
        hi routInf      ctermfg=39
        hi routConst	ctermfg=35
        hi routString	ctermfg=85
        hi routError	ctermfg=15 ctermbg=1
        hi routWarn	ctermfg=1
        hi routIndex	ctermfg=109
    else
        " Default 16 colors scheme for R output:
        hi routInput	ctermfg=gray
        hi routNormal	ctermfg=darkgreen
        hi routNumber	ctermfg=darkyellow
        hi routInteger	ctermfg=darkyellow
        hi routFloat	ctermfg=darkyellow
        hi routComplex	ctermfg=darkyellow
        hi routNegNum	ctermfg=darkyellow
        hi routNegFlt	ctermfg=darkyellow
        hi routDate	ctermfg=darkyellow
        hi routInf	ctermfg=darkyellow
        hi routFalse	ctermfg=magenta
        hi routTrue	ctermfg=darkgreen
        hi routConst	ctermfg=magenta
        hi routString	ctermfg=darkcyan
        hi routError	ctermfg=white ctermbg=red
        hi routWarn	ctermfg=red
        hi routIndex	ctermfg=darkgreen
    endif

    " Change colors under user request:
    if exists("g:rout_color_input")
        exe "hi routInput " . g:rout_color_input
    endif
    if exists("g:rout_color_normal")
        exe "hi routNormal " . g:rout_color_normal
    endif
    if exists("g:rout_color_number")
        exe "hi routNumber " . g:rout_color_number
    endif
    if exists("g:rout_color_integer")
        exe "hi routInteger " . g:rout_color_integer
    endif
    if exists("g:rout_color_float")
        exe "hi routFloat " . g:rout_color_float
    endif
    if exists("g:rout_color_complex")
        exe "hi routComplex " . g:rout_color_complex
    endif
    if exists("g:rout_color_negnum")
        exe "hi routNegNum " . g:rout_color_negnum
    endif
    if exists("g:rout_color_negfloat")
        exe "hi routNegFlt " . g:rout_color_negfloat
    endif
    if exists("g:rout_color_date")
        exe "hi routDate " . g:rout_color_date
    endif
    if exists("g:rout_color_false")
        exe "hi routFalse " . g:rout_color_false
    endif
    if exists("g:rout_color_true")
        exe "hi routTrue " . g:rout_color_true
    endif
    if exists("g:rout_color_inf")
        exe "hi routInf " . g:rout_color_inf
    endif
    if exists("g:rout_color_constant")
        exe "hi routConst " . g:rout_color_constant
    endif
    if exists("g:rout_color_string")
        exe "hi routString " . g:rout_color_string
    endif
    if exists("g:rout_color_error")
        exe "hi routError " . g:rout_color_error
    endif
    if exists("g:rout_color_warn")
        exe "hi routWarn " . g:rout_color_warn
    endif
    if exists("g:rout_color_index")
        exe "hi routIndex " . g:rout_color_index
    endif
endif

let   b:current_syntax = "rout"

" vim: ts=8 sw=4
