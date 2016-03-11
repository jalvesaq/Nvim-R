
nvim.srcdir <- function(dr = "."){
    for(f in list.files(path = dr, pattern = "\\.[RrSsQq]$")){
        cat(f, "\n")
        source(paste(dr, "/", f, sep = ""))
    }
    return(invisible(NULL))
}
