
if exists("g:R_filetypes") && type(g:R_filetypes) == v:t_list && index(g:R_filetypes, 'quarto') == -1
    finish
endif

let g:R_quarto_preview_args = get(g:, 'R_quarto_preview_args', '')
let g:R_quarto_render_args = get(g:, 'R_quarto_render_args', '')

function! RQuarto(what)
    if a:what == "render"
        update
        call g:SendCmdToR('quarto::quarto_render("' . substitute(expand('%'), '\\', '/', 'g') . '"' . g:R_quarto_render_args . ')')
    elseif a:what == "preview"
        update
        call g:SendCmdToR('quarto::quarto_preview("' . substitute(expand('%'), '\\', '/', 'g') . '"' . g:R_quarto_preview_args . ')')
    else
        call g:SendCmdToR('quarto::quarto_preview_stop()')
    endif
endfunction

" Necessary for RCreateMaps():
exe "source " . substitute(expand("<sfile>:h:h"), ' ', '\ ', 'g') . "/R/common_global.vim"

call RCreateMaps('n',   'RQuartoRender',  'qr', ':call RQuarto("render")')
call RCreateMaps('n',   'RQuartoPreview',  'qp', ':call RQuarto("preview")')
call RCreateMaps('n',   'RQuartoStop',  'qs', ':call RQuarto("stop")')

exe "source " . substitute(expand("<sfile>:h"), ' ', '\ ', 'g') . "/rmd_nvimr.vim"
