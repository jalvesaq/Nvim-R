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
        options(nvimcom.higlobfun = TRUE)
        options(nvimcom.setwidth = TRUE)
        options(nvimcom.nvimpager = TRUE)
        options(nvimcom.lsenvtol = 500)
        options(nvimcom.delim = "\t")
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
        if(as.integer(getOption("nvimcom.lsenvtol")) < 10)
            options(nvimcom.lsenvtol = 10)
        if(as.integer(getOption("nvimcom.lsenvtol")) > 10000)
            options(nvimcom.lsenvtol = 10000)
        .C("nvimcom_Start",
           as.integer(getOption("nvimcom.verbose")),
           as.integer(getOption("nvimcom.opendf")),
           as.integer(getOption("nvimcom.openlist")),
           as.integer(getOption("nvimcom.allnames")),
           as.integer(getOption("nvimcom.labelerr")),
           as.integer(getOption("nvimcom.higlobfun")),
           as.integer(getOption("nvimcom.setwidth")),
           path.package("nvimcom"),
           as.character(utils::packageVersion("nvimcom")),
           paste(paste0(version$major, ".", version$minor),
                  getOption("OutDec"),
                  getOption("prompt"),
                  getOption("continue"),
                  paste(.packages(), collapse = " "),
                  sep = "\x02"),
           as.integer(getOption("nvimcom.lsenvtol")),
           PACKAGE="nvimcom")
    }
}

.onUnload <- function(libpath) {
    if(is.loaded("nvimcom_Stop", PACKAGE = "nvimcom")){
        .C("nvimcom_Stop", PACKAGE="nvimcom")
        if(Sys.getenv("NVIMR_TMPDIR") != "" && .Platform$OS.type == "windows"){
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

nvim_viewdf <- function(oname, fenc = "", nrows = NULL, location = "tabnew")
{
    if(is.data.frame(oname) || is.matrix(oname)){
        # Only when the rkeyword includes "::"
        o <- oname
        oname <- sub("::", "_", deparse(substitute(oname)))
    } else {
        oname_split <- unlist(strsplit(oname, "$", fixed = TRUE))
        oname_split <- unlist(strsplit(oname_split, "[[", fixed = TRUE))
        oname_split <- unlist(strsplit(oname_split, "]]", fixed = TRUE))
        ok <- try(o <- get(oname_split[[1]], envir = .GlobalEnv), silent = TRUE)
        if(length(oname_split) > 1){
            for (i in 2:length(oname_split)) {
                oname_integer <- suppressWarnings(o <- as.integer(oname_split[[i]]))
                if(is.na(oname_integer)){
                    ok <- try(o <- ok[[oname_split[[i]]]], silent = TRUE)
                } else {
                    ok <- try(o <- ok[[oname_integer]], silent = TRUE)
                }
            }
        }
        if(inherits(ok, "try-error")){
            .C("nvimcom_msg_to_nvim",
               paste0("RWarningMsg('", '"', oname, '"', " not found in .GlobalEnv')"),
               PACKAGE="nvimcom")
            return(invisible(NULL))
        }
    }
    if(is.data.frame(o) || is.matrix(o)){
        if(!is.null(nrows)){
          o <- head(o, n = nrows)
        }
        if(getOption("nvimcom.delim") == "\t"){
            write.table(o, sep = "\t", row.names = FALSE, quote = FALSE,
                        fileEncoding = fenc,
                        file = paste0(Sys.getenv("NVIMR_TMPDIR"), "/Rinsert"))
        } else {
            write.table(o, sep = getOption("nvimcom.delim"), row.names = FALSE,
                        fileEncoding = fenc,
                        file = paste0(Sys.getenv("NVIMR_TMPDIR"), "/Rinsert"))
        }
        .C("nvimcom_msg_to_nvim", paste0("RViewDF('", oname, "', '", location, "')"), PACKAGE="nvimcom")
    } else {
        .C("nvimcom_msg_to_nvim",
           paste0("RWarningMsg('", '"', oname, '"', " is not a data.frame or matrix')"),
           PACKAGE="nvimcom")
    }
    return(invisible(NULL))
}

NvimR.source <- function(..., print.eval = TRUE, spaced = FALSE)
{
    if (with(R.Version(), paste(major, minor, sep = '.')) >= '3.4.0') {
        base::source(getOption("nvimcom.source.path"), ..., print.eval = print.eval, spaced = spaced)
    } else {
        base::source(getOption("nvimcom.source.path"), ..., print.eval = print.eval)
    }
}

NvimR.selection <- function(..., local = parent.frame()) NvimR.source(..., local = local)

NvimR.paragraph <- function(..., local = parent.frame()) NvimR.source(..., local = local)

NvimR.block <- function(..., local = parent.frame()) NvimR.source(..., local = local)

NvimR.function <- function(..., local = parent.frame()) NvimR.source(..., local = local)

NvimR.chunk <- function(..., local = parent.frame()) NvimR.source(..., local = local)

source.and.clean <- function(f, ...)
{
    on.exit(unlink(f))
    source(f, ...)
}

nvim_format <- function(l1, l2, wco)
{
    ok <- try(formatR::tidy_source(paste0(Sys.getenv("NVIMR_TMPDIR"), "/unformatted_code"),
                                   file = paste0(Sys.getenv("NVIMR_TMPDIR"), "/formatted_code"),
                                   width.cutoff = wco))
    if(inherits(ok, "try-error")){
        .C("nvimcom_msg_to_nvim",
           "RWarningMsg('Error trying to execute the function formatR::tyde_source()')",
           PACKAGE="nvimcom")
    } else {
        .C("nvimcom_msg_to_nvim",
           paste0("FinishRFormatCode(", l1, ", ", l2, ")"),
           PACKAGE="nvimcom")
    }
    return(invisible(NULL))
}

nvim_insert <- function(cmd, type = "default")
{
    try(ok <- capture.output(cmd, file = paste0(Sys.getenv("NVIMR_TMPDIR"), "/Rinsert")))
    if(inherits(ok, "try-error")){
        .C("nvimcom_msg_to_nvim",
           paste0("RWarningMsg('Error trying to execute the command \"", cmd, "\"')"),
           PACKAGE="nvimcom")
    } else {
        .C("nvimcom_msg_to_nvim",
           paste0('FinishRInsert("', type , '")'),
           PACKAGE="nvimcom")
    }
    return(invisible(NULL))
}
