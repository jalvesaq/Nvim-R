
VimcomEnv <- new.env()
VimcomEnv$pkgdescr <- list()
VimcomEnv$tcb <- FALSE

#' Function called by R when vimcom is being loaded.
#' Vim-R creates environment variables and the start_options.R file to set
#' vimcom options.
.onLoad <- function(libname, pkgname) {
    if (Sys.getenv("VIMR_TMPDIR") == "")
        return(invisible(NULL))
    library.dynam("vimcom", pkgname, libname, local = FALSE)

    if (is.null(getOption("vimcom.verbose")))
        options(vimcom.verbose = 0)

    # The remaining options are set by Vim. Don't try to set them in your
    # ~/.Rprofile because they will be overridden here:
    if (file.exists(paste0(Sys.getenv("VIMR_TMPDIR"), "/start_options_utf8.R"))) {
        source(paste0(Sys.getenv("VIMR_TMPDIR"), "/start_options_utf8.R"), encoding = "UTF-8")
    } else if (file.exists(paste0(Sys.getenv("VIMR_TMPDIR"), "/start_options.R"))) {
        source(paste0(Sys.getenv("VIMR_TMPDIR"), "/start_options.R"))
    } else {
        options(vimcom.allnames = FALSE)
        options(vimcom.texerrs = TRUE)
        options(vimcom.setwidth = TRUE)
        options(vimcom.autoglbenv = FALSE)
        options(vimcom.debug_r = TRUE)
        options(vimcom.vimpager = TRUE)
        options(vimcom.max_depth = 12)
        options(vimcom.max_size = 1000000)
        options(vimcom.max_time = 100)
        options(vimcom.delim = "\t")
    }
    if (getOption("vimcom.vimpager"))
        options(pager = vim.hmsg)
}

#' Function called by R right after loading vimcom to establish the TCP
#' connection with the vimrserver
.onAttach <- function(libname, pkgname) {
    if (Sys.getenv("VIMR_TMPDIR") == "")
        return(invisible(NULL))
    if (version$os == "mingw32") {
        termenv <- "MinGW"
    } else {
        termenv <- Sys.getenv("TERM")
    }

    if (interactive() && termenv != "" && termenv != "dumb" && Sys.getenv("VIMR_COMPLDIR") != "") {
        dir.create(Sys.getenv("VIMR_COMPLDIR"), showWarnings = FALSE)
        pd <- utils::packageDescription("vimcom")
        hascolor <- FALSE
        if ((length(find.package("colorout", quiet = TRUE, verbose = FALSE)) > 0 && colorout::isColorOut()) ||
            Sys.getenv("RADIAN_VERSION") != "")
            hascolor <- TRUE
        ok <- .Call("vimcom_Start",
           as.integer(getOption("vimcom.verbose")),
           as.integer(getOption("vimcom.allnames")),
           as.integer(getOption("vimcom.setwidth")),
           as.integer(getOption("vimcom.autoglbenv")),
           as.integer(getOption("vimcom.debug_r")),
           as.integer(getOption("vimcom.max_depth")),
           as.integer(getOption("vimcom.max_size")),
           as.integer(getOption("vimcom.max_time")),
           pd$Version,
           paste(sub("R ([^;]*).*", "\\1", pd$Built),
                 getOption("OutDec"),
                 gsub("\n", "#N#", getOption("prompt")),
                 getOption("continue"),
                 as.integer(hascolor),
                 sep = "\x12"),
           PACKAGE = "vimcom")
        if (ok)
            add_tcb()
    }
    if (!is.na(utils::localeToCharset()[1]) &&
        utils::localeToCharset()[1] == "UTF-8" && version$os != "cygwin") {
        VimcomEnv$isAscii <- FALSE
    } else {
        VimcomEnv$isAscii <- TRUE
    }
}


#' Stop the connection with vimrserver and unload the vimcom library
#' This function is called by the command:
#' detach("package:vimcom", unload = TRUE)
.onUnload <- function(libpath) {
    VimcomEnv$tcb <- FALSE
    if (is.loaded("vimcom_Stop", PACKAGE = "vimcom")) {
        .C("vimcom_Stop", PACKAGE = "vimcom")
        if (Sys.getenv("VIMR_TMPDIR") != "" && .Platform$OS.type == "windows") {
                unlink(paste0(Sys.getenv("VIMR_TMPDIR"), "/rconsole_hwnd_",
                              Sys.getenv("VIMR_SECRET")))
        }
        Sys.sleep(0.2)
        library.dynam.unload("vimcom", libpath)
    }
}

run_tcb <- function(...) {
    if (!VimcomEnv$tcb)
        return(invisible(FALSE))
    .C("vimcom_task", PACKAGE = "vimcom")
    return(invisible(TRUE))
}

add_tcb <- function() {
    VimcomEnv$tcb <- TRUE
    addTaskCallback(run_tcb)
}
