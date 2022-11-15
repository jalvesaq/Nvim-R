
nvim.srcdir <- function(dr = ".") {
    for (f in list.files(path = dr, pattern = "\\.[RrSsQq]$")) {
        cat(f, "\n")
        source(paste0(dr, "/", f))
    }
    return(invisible(NULL))
}
