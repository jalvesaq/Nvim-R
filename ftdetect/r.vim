augroup rft
    au!
    autocmd BufRead *.Rhistory set ft=r
    if !exists('#rquarto')
        autocmd BufNewFile,BufRead *.qmd set ft=quarto
    endif
    autocmd BufNewFile,BufRead *.Rout set ft=rout
    autocmd BufNewFile,BufRead *.Rout.fail set ft=rout
    autocmd BufNewFile,BufRead *.Rout.save set ft=rout
    autocmd BufNewFile,BufRead *.Rproj set syntax=yaml
augroup END
