"  This program is free software; you can redistribute it and/or modify
"  it under the terms of the GNU General Public License as published by
"  the Free Software Foundation; either version 2 of the License, or
"  (at your option) any later version.
"
"  This program is distributed in the hope that it will be useful,
"  but WITHOUT ANY WARRANTY; without even the implied warranty of
"  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"  GNU General Public License for more details.
"
"  A copy of the GNU General Public License is available at
"  http://www.r-project.org/Licenses/

"==========================================================================
" ftplugin for R files
"
" Authors: Jakson Alves de Aquino <jalvesaq@gmail.com>
"          Jose Claudio Faria
"
"          Based on previous work by Johannes Ranke
"
" Please see doc/Nvim-R.txt for usage details.
"==========================================================================


" Set completion with CTRL-X CTRL-O to autoloaded function.
if exists('&ofu')
    let b:rplugin_knitr_pattern = ''
    if &filetype == "rnoweb" || &filetype == "rrst" || &filetype == "rmd"
        if &omnifunc == "CompleteR"
            let b:rplugin_non_r_omnifunc = ""
        else
            let b:rplugin_non_r_omnifunc = &omnifunc
        endif
    endif
    if &filetype == "r" || &filetype == "rnoweb" || &filetype == "rdoc" || &filetype == "rhelp" || &filetype == "rrst" || &filetype == "rmd"
        setlocal omnifunc=CompleteR
    endif
endif

" Set the name of the Object Browser caption if not set yet
let s:tnr = tabpagenr()
if !exists("b:objbrtitle")
    if s:tnr == 1
        let b:objbrtitle = "Object_Browser"
    else
        let b:objbrtitle = "Object_Browser" . s:tnr
    endif
    unlet s:tnr
endif

let g:rplugin.lastft = &filetype

" Check if b:pdf_is_open already exists because this script is called when
" FillRLibList() is called
if !exists("b:pdf_is_open")
    let b:pdf_is_open = 0
endif

if !exists("g:SendCmdToR")
    let g:SendCmdToR = function('SendCmdToR_fake')
endif

" Were new libraries loaded by R?
if !exists("b:rplugin_new_libs")
    let b:rplugin_new_libs = 0
endif
" When using as a global plugin for non R files, RCheckLibList will not exist
if exists("*RCheckLibList") && !exists("*nvim_buf_set_option")
    autocmd BufEnter <buffer> call RCheckLibList()
endif

if g:R_assign == 3
    iabb <buffer> _ <-
endif
