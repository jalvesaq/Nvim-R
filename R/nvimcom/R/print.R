
nvim.print <- function(object, firstobj) {
    if (!exists(object))
        stop("object '", object, "' not found")
    if (!missing(firstobj)) {
        objclass <- nvim.getclass(firstobj)
        if (objclass[1] != "#E#" && objclass[1] != "") {
            saved.warn <- getOption("warn")
            options(warn = -1)
            on.exit(options(warn = saved.warn))
            mlen <- try(length(methods(object)), silent = TRUE)
            if (class(mlen)[1] == "integer" && mlen > 0) {
                for (cls in objclass) {
                    if (exists(paste0(object, ".", objclass))) {
                        .newobj <- get(paste0(object, ".", objclass))
                        message(paste0("Note: Printing ", object, ".", objclass))
                        break
                    }
                }
            }
        }
    }
    if (!exists(".newobj"))
        .newobj <- get(object)
    print(.newobj)
}
