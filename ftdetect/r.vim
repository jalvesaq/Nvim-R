autocmd BufNewFile,BufRead *.R set ft=r
autocmd BufNewFile,BufRead *.r set ft=r
autocmd BufNewFile,BufRead *.Rprofile set ft=r
autocmd BufRead *.Rhistory set ft=r

autocmd BufNewFile,BufRead *.Rmd set ft=rmd
autocmd BufNewFile,BufRead *.rmd set ft=rmd
autocmd BufNewFile,BufRead *.qmd set ft=quarto

autocmd BufNewFile,BufRead *.Rrst set ft=rrst
autocmd BufNewFile,BufRead *.rrst set ft=rrst

autocmd BufNewFile,BufRead *.Rout set ft=rout
autocmd BufNewFile,BufRead *.Rout.fail set ft=rout
autocmd BufNewFile,BufRead *.Rout.save set ft=rout

autocmd BufNewFile,BufRead *.Rproj set syntax=yaml
