
NvimcomEnv <- new.env()
NvimcomEnv$pkgdescr <- list()

#' Function called by R when nvimcom is being loaded.
#' Nvim-R creates environment variables and the start_options.R file to set
#' nvimcom options.
.onLoad <- function(libname, pkgname) {
    if (Sys.getenv("NVIMR_TMPDIR") == "")
        return(invisible(NULL))
    library.dynam("nvimcom", pkgname, libname, local = FALSE)

    if (is.null(getOption("nvimcom.verbose")))
        options(nvimcom.verbose = 0)

    # The remaining options are set by Neovim. Don't try to set them in your
    # ~/.Rprofile because they will be overridden here:
    if (file.exists(paste0(Sys.getenv("NVIMR_TMPDIR"), "/start_options_utf8.R"))) {
        source(paste0(Sys.getenv("NVIMR_TMPDIR"), "/start_options_utf8.R"), encoding = "UTF-8")
    } else if (file.exists(paste0(Sys.getenv("NVIMR_TMPDIR"), "/start_options.R"))) {
        source(paste0(Sys.getenv("NVIMR_TMPDIR"), "/start_options.R"))
    } else {
        options(nvimcom.allnames = FALSE)
        options(nvimcom.texerrs = TRUE)
        options(nvimcom.setwidth = TRUE)
        options(nvimcom.autoglbenv = FALSE)
        options(nvimcom.debug_r = TRUE)
        options(nvimcom.nvimpager = TRUE)
        options(nvimcom.delim = "\t")
    }
    if (getOption("nvimcom.nvimpager"))
        options(pager = nvim.hmsg)
}

#' Function called by R right after loading nvimcom to establish the TCP
#' connection with the nvimrserver
.onAttach <- function(libname, pkgname) {
    if (Sys.getenv("NVIMR_TMPDIR") == "")
        return(invisible(NULL))
    if (version$os == "mingw32") {
        termenv <- "MinGW"
    } else {
        termenv <- Sys.getenv("TERM")
    }

    if (interactive() && termenv != "" && termenv != "dumb" && Sys.getenv("NVIMR_COMPLDIR") != "") {
        dir.create(Sys.getenv("NVIMR_COMPLDIR"), showWarnings = FALSE)
        pd <- utils::packageDescription("nvimcom")
        hascolor <- FALSE
        if ((length(find.package("colorout", quiet = TRUE, verbose = FALSE)) > 0 && colorout::isColorOut()) ||
            Sys.getenv("RADIAN_VERSION") != "")
            hascolor <- TRUE
        .C("nvimcom_Start",
           as.integer(getOption("nvimcom.verbose")),
           as.integer(getOption("nvimcom.allnames")),
           as.integer(getOption("nvimcom.setwidth")),
           as.integer(getOption("nvimcom.autoglbenv")),
           as.integer(getOption("nvimcom.debug_r")),
           pd$Version,
           paste(sub("R ([^;]*).*", "\\1", pd$Built),
                 getOption("OutDec"),
                 gsub("\n", "#N#", getOption("prompt")),
                 getOption("continue"),
                 as.integer(hascolor),
                 sep = "\x12"),
           PACKAGE = "nvimcom")
    }
    if (!is.na(utils::localeToCharset()[1]) &&
        utils::localeToCharset()[1] == "UTF-8" && version$os != "cygwin") {
        NvimcomEnv$isAscii <- FALSE
    } else {
        NvimcomEnv$isAscii <- TRUE
    }
}


#' Stop the connection with nvimrserver and unload the nvimcom library
#' This function is called by the command:
#' detach("package:nvimcom", unload = TRUE)
.onUnload <- function(libpath) {
    if (is.loaded("nvimcom_Stop", PACKAGE = "nvimcom")) {
        .C("nvimcom_Stop", PACKAGE = "nvimcom")
        if (Sys.getenv("NVIMR_TMPDIR") != "" && .Platform$OS.type == "windows") {
                unlink(paste0(Sys.getenv("NVIMR_TMPDIR"), "/rconsole_hwnd_",
                              Sys.getenv("NVIMR_SECRET")))
        }
        Sys.sleep(0.2)
        library.dynam.unload("nvimcom", libpath)
    }
}
