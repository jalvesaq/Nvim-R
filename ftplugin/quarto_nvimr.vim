
if exists("g:disable_r_ftplugin")
    finish
endif

let g:R_quarto_preview_args = get(g:, 'R_quarto_preview_args', '')
let g:R_quarto_render_args = get(g:, 'R_quarto_render_args', '')

function! RQuarto(what)
    if a:what == "render"
        update
        call g:SendCmdToR('quarto::quarto_render("' . expand('%') . '"' . g:R_quarto_render_args . ')')
    elseif a:what == "preview"
        update
        call g:SendCmdToR('quarto::quarto_preview("' . expand('%') . '"' . g:R_quarto_preview_args . ')')
    else
        call g:SendCmdToR('quarto::quarto_stop()')
    endif
endfunction

" Necessary for RCreateMaps():
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_global.vim"

call RCreateMaps('n',   'RQuartoRender',  'qr', ':call RQuarto("render")')
call RCreateMaps('n',   'RQuartoPreview',  'qp', ':call RQuarto("preview")')
call RCreateMaps('n',   'RQuartoStop',  'qs', ':call RQuarto("stop")')

exe "source " . substitute(expand("<sfile>:h"), ' ', '\ ', 'g') . "/rmd_nvimr.vim"
