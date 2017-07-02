# This file is part of nvimcom R package
#
# It is distributed under the GNU General Public License.
# See the file ../LICENSE for details.
#
# (c) 2011 Jakson Aquino: jalvesaq@gmail.com
#
###############################################################

NvimcomEnv <- new.env()
NvimcomEnv$pkgdescr <- list()

.onLoad <- function(libname, pkgname) {
    if(Sys.getenv("NVIMR_TMPDIR") == "")
        return(invisible(NULL))
    library.dynam("nvimcom", pkgname, libname, local = FALSE)

    if(is.null(getOption("nvimcom.verbose")))
        options(nvimcom.verbose = 0)

    # The remaining options are set by Neovim. Don't try to set them in your
    # ~/.Rprofile because they will be overridden here:
    if(file.exists(paste0(Sys.getenv("NVIMR_TMPDIR"), "/start_options.R"))){
        source(paste0(Sys.getenv("NVIMR_TMPDIR"), "/start_options.R"))
    } else {
        options(nvimcom.opendf = TRUE)
        options(nvimcom.openlist = FALSE)
        options(nvimcom.allnames = FALSE)
        options(nvimcom.texerrs = TRUE)
        options(nvimcom.labelerr = TRUE)
        options(nvimcom.nvimpager = TRUE)
    }
    if(getOption("nvimcom.nvimpager"))
        options(pager = nvim.hmsg)
}

.onAttach <- function(libname, pkgname) {
    if(Sys.getenv("NVIMR_TMPDIR") == "")
        return(invisible(NULL))
    if(version$os == "mingw32")
        termenv <- "MinGW"
    else
        termenv <- Sys.getenv("TERM")

    if(interactive() && termenv != "" && termenv != "dumb" && Sys.getenv("NVIMR_COMPLDIR") != ""){
        dir.create(Sys.getenv("NVIMR_COMPLDIR"), showWarnings = FALSE)
        .C("nvimcom_Start",
           as.integer(getOption("nvimcom.verbose")),
           as.integer(getOption("nvimcom.opendf")),
           as.integer(getOption("nvimcom.openlist")),
           as.integer(getOption("nvimcom.allnames")),
           as.integer(getOption("nvimcom.labelerr")),
           path.package("nvimcom"),
           as.character(utils::packageVersion("nvimcom")),
           paste(search(), collapse = " "),
           paste0(version$major, ".", version$minor),
           PACKAGE="nvimcom")
    }
}

.onUnload <- function(libpath) {
    if(is.loaded("nvimcom_Stop", PACKAGE = "nvimcom")){
        .C("nvimcom_Stop", PACKAGE="nvimcom")
        if(Sys.getenv("NVIMR_TMPDIR") != ""){
            unlink(paste0(Sys.getenv("NVIMR_TMPDIR"), "/nvimcom_running_",
                          Sys.getenv("NVIMR_ID")))
            if(.Platform$OS.type == "windows")
                unlink(paste0(Sys.getenv("NVIMR_TMPDIR"), "/rconsole_hwnd_",
                              Sys.getenv("NVIMR_SECRET")))
        }
        Sys.sleep(0.2)
        library.dynam.unload("nvimcom", libpath)
    }
}

nvim.edit <- function(name, file, title)
{
    if(file != "")
        stop("Feature not implemented. Use nvim to edit files.")
    if(is.null(name))
        stop("Feature not implemented. Use nvim to create R objects from scratch.")

    waitf <- paste0(Sys.getenv("NVIMR_TMPDIR"), "/edit_", Sys.getenv("NVIMR_ID"), "_wait")
    editf <- paste0(Sys.getenv("NVIMR_TMPDIR"), "/edit_", Sys.getenv("NVIMR_ID"))
    unlink(editf)
    writeLines(text = "Waiting...", con = waitf)

    initial = paste0(Sys.getenv("NVIMR_TMPDIR"), "/nvimcom_edit_", round(runif(1, min = 100, max = 999)))
    sink(initial)
    dput(name)
    sink()

    .C("nvimcom_msg_to_nvim",
       paste0("ShowRObject('", initial, "')"),
       PACKAGE="nvimcom")

    while(file.exists(waitf))
        Sys.sleep(1)
    x <- eval(parse(editf))
    unlink(initial)
    unlink(editf)
    x
}

vi <- function(name = NULL, file = "")
{
    nvim.edit(name, file)
}

nvim_capture_source_output <- function(s, o)
{
    capture.output(base::source(s, echo = TRUE), file = o)
    .C("nvimcom_msg_to_nvim", paste0("GetROutput('", o, "')"), PACKAGE="nvimcom")
}

nvim_viewdf <- function(oname)
{
    ok <- try(o <- get(oname, envir = .GlobalEnv), silent = TRUE)
    if(inherits(ok, "try-error")){
        .C("nvimcom_msg_to_nvim",
           paste0("RWarningMsg('", '"', oname, '"', " not found in .GlobalEnv')"),
           PACKAGE="nvimcom")
        return(invisible(NULL))
    }
    if(is.data.frame(o) || is.matrix(o)){
        write.table(o, sep = "\t", row.names = FALSE, quote = FALSE,
                    file = paste0(Sys.getenv("NVIMR_TMPDIR"), "/Rinsert"))
        .C("nvimcom_msg_to_nvim", paste0("RViewDF('", oname, "')"), PACKAGE="nvimcom")
    } else {
        .C("nvimcom_msg_to_nvim",
           paste0("RWarningMsg('", '"', oname, '"', " is not a data.frame or matrix')"),
           PACKAGE="nvimcom")
    }
    return(invisible(NULL))
}

source.and.clean <- function(f, ...)
{
    on.exit(unlink(f))
    source(f, ...)
}
