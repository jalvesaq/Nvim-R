#' Source all files in a directory
#' The function is called by the Vim command `:RSourceDirectory`.
#' @param dr Directory to be sourced.
nvim.srcdir <- function(dr = ".") {
    for (f in list.files(path = dr, pattern = "\\.[RrSsQq]$")) {
        cat(f, "\n")
        source(paste0(dr, "/", f))
    }
    return(invisible(NULL))
}
