# Function called by R if options(editor = nvim.edit).
# Nvim-R sets this option during nvimcom loading.
nvim.edit <- function(name, file, title) {
    if (file != "")
        stop("Feature not implemented. Use nvim to edit files.")
    if (is.null(name))
        stop("Feature not implemented. Use nvim to create R objects from scratch.")

    waitf <- paste0(Sys.getenv("NVIMR_TMPDIR"), "/edit_", Sys.getenv("NVIMR_ID"), "_wait")
    editf <- paste0(Sys.getenv("NVIMR_TMPDIR"), "/edit_", Sys.getenv("NVIMR_ID"))
    unlink(editf)
    writeLines(text = "Waiting...", con = waitf)

    initial <- paste0(Sys.getenv("NVIMR_TMPDIR"), "/nvimcom_edit_",
                      round(runif(1, min = 100, max = 999)))
    sink(initial)
    dput(name)
    sink()

    .C("nvimcom_msg_to_nvim",
       paste0("call EditRObject('", initial, "')"),
       PACKAGE = "nvimcom")

    while (file.exists(waitf))
        Sys.sleep(1)
    x <- eval(parse(editf))
    unlink(initial)
    unlink(editf)
    x
}

# Substitute for utils::vi
vi <- function(name = NULL, file = "") {
    nvim.edit(name, file)
}

#' Function called by Nvim-R when the user wants to source a line of code and
#' capture its output in a new Vim tab (default key binding `o`)
#' @param s A string representing the line of code to be source.
#' @param nm The name of the buffer to be created in the Vim tab.
nvim_capture_source_output <- function(s, nm) {
    o <- capture.output(base::source(s, echo = TRUE), file = NULL)
    o <- paste0(o, collapse = "\x14")
    o <- gsub("'", "\x13", o)
    .C("nvimcom_msg_to_nvim", paste0("call GetROutput('", nm, "', '", o, "')"),
       PACKAGE = "nvimcom")
}

#' Function called by Nvim-R when the user wants to run the command `dput()`
#' over the word under cursor and see its output in a new Vim tab.
#' @param oname The name of the object under cursor.
#' @param howto How to show the output (never included when called by Nvim-R).
nvim_dput <- function(oname, howto = "tabnew") {
    o <- capture.output(eval(parse(text = paste0("dput(", oname, ")"))))
    o <- paste0(o, collapse = "\x14")
    o <- gsub("'", "\x13", o)
    .C("nvimcom_msg_to_nvim",
       paste0("call ShowRObj('", howto, "', '", oname, "', 'r', '", o, "')"),
       PACKAGE = "nvimcom")
}

#' Function called by Nvim-R when the user wants to see a `data.frame` or
#' `matrix` (default key bindings: `\rv`, `\vs`, `\vv`, and `\rh`).
#' @param oname The name of the object (`data.frame` or `matrix`).
#' @param fenc File encoding to be used.
#' @param nrows How many lines to show.
#' @param howto How to display the output in Vim.
#' @param R_df_viewer R function to be called to show the `data.frame` or
#' `matrix`.
nvim_viewobj <- function(oname, fenc = "", nrows = NULL, howto = "tabnew", R_df_viewer = NULL) {
    if (is.data.frame(oname) || is.matrix(oname)) {
        # Only when the rkeyword includes "::"
        o <- oname
        oname <- sub("::", "_", deparse(substitute(oname)))
    } else {
        oname_split <- unlist(strsplit(oname, "$", fixed = TRUE))
        oname_split <- unlist(strsplit(oname_split, "[[", fixed = TRUE))
        oname_split <- unlist(strsplit(oname_split, "]]", fixed = TRUE))
        ok <- try(o <- get(oname_split[[1]], envir = .GlobalEnv), silent = TRUE)
        if (length(oname_split) > 1) {
            for (i in 2:length(oname_split)) {
                oname_integer <- suppressWarnings(o <- as.integer(oname_split[[i]]))
                if (is.na(oname_integer)) {
                    ok <- try(o <- ok[[oname_split[[i]]]], silent = TRUE)
                } else {
                    ok <- try(o <- ok[[oname_integer]], silent = TRUE)
                }
            }
        }
        if (inherits(ok, "try-error")) {
            .C("nvimcom_msg_to_nvim",
               paste0("call RWarningMsg('", '"', oname, '"', " not found in .GlobalEnv')"),
               PACKAGE = "nvimcom")
            return(invisible(NULL))
        }
    }
    if (is.data.frame(o) || is.matrix(o)) {
        if (!is.null(nrows)) {
          o <- utils::head(o, n = nrows)
        }
        if (!is.null(R_df_viewer)) {
            .C("nvimcom_msg_to_nvim",
               paste0("call g:SendCmdToR(printf(g:R_df_viewer, '", oname, "'))"),
               PACKAGE = "nvimcom")
            return(invisible(NULL))
        }
        if (getOption("nvimcom.delim") == "\t") {
            txt <- capture.output(write.table(o, sep = "\t", row.names = FALSE, quote = FALSE,
                                              fileEncoding = fenc))
        } else {
            txt <- capture.output(write.table(o, sep = getOption("nvimcom.delim"), row.names = FALSE,
                                              fileEncoding = fenc))
        }
        txt <- paste0(txt, collapse = "\x14")
        txt <- gsub("'", "\x13", txt)
        .C("nvimcom_msg_to_nvim",
           paste0("call RViewDF('", oname, "', '", howto, "', '", txt, "')"),
           PACKAGE = "nvimcom")
    } else {
        nvim_dput(oname, howto)
    }
    return(invisible(NULL))
}

#' Call base::source.
#' @param ... Further arguments passed to base::source.
#' @param print.eval See base::source.
#' @param spaced See base::source.
NvimR.source <- function(..., print.eval = TRUE, spaced = FALSE) {
    if (with(R.Version(), paste(major, minor, sep = ".")) >= "3.4.0") {
        base::source(getOption("nvimcom.source.path"), ...,
                     print.eval = print.eval, spaced = spaced)
    } else {
        base::source(getOption("nvimcom.source.path"), ..., print.eval = print.eval)
    }
}

#' Call base::source.
#' This function is sent to R Console when the user press `\ss`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
NvimR.selection <- function(..., local = parent.frame()) NvimR.source(..., local = local)

#' Call base::source.
#' This function is sent to R Console when the user press `\pp`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
NvimR.paragraph <- function(..., local = parent.frame()) NvimR.source(..., local = local)

#' Call base::source.
#' This function is sent to R Console when the user press `\bb`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
NvimR.block <- function(..., local = parent.frame()) NvimR.source(..., local = local)

#' Call base::source.
#' This function is sent to R Console when the user press `\ff`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
NvimR.function <- function(..., local = parent.frame()) NvimR.source(..., local = local)

#' Call base::source.
#' This function is sent to R Console when the user press `\cc`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
NvimR.chunk <- function(..., local = parent.frame()) NvimR.source(..., local = local)

#' Creates a temporary copy of an R file, source it, and, finally, delete it.
#' This function is sent to R Console when the user press `\aa`, `\ae`, or `\ao`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
source.and.clean <- function(f, ...) {
    on.exit(unlink(f))
    base::source(f, ...)
}

#' Format R code.
#' Sent to nvimcom through nvimrserver by Nvim-R when the user runs the
#' `Rformat` command.
#' @param l1 First line of selection. Nvim-R needs the information to know
#' what lines to replace.
#' @param l2 Last line of selection. Nvim-R needs the information to know
#' what lines to replace.
#' @param wco Text width, based on Vim option 'textwidth'.
#' @param sw Vim option 'shiftwidth'.
#' @param txt Text to be formatted.
nvim_format <- function(l1, l2, wco, sw, txt) {
    if (is.null(getOption("nvimcom.formatfun"))) {
        if (length(find.package("styler", quiet = TRUE, verbose = FALSE)) > 0) {
           options(nvimcom.formatfun = "style_text")
        } else {
            if (length(find.package("formatR", quiet = TRUE, verbose = FALSE)) > 0) {
                options(nvimcom.formatfun = "tidy_source")
            } else {
                .C("nvimcom_msg_to_nvim",
                   "call RWarningMsg('You have to install either formatR or styler in order to run :Rformat')",
                   PACKAGE = "nvimcom")
                return(invisible(NULL))
            }
        }
    }

    txt <- strsplit(gsub("\x13", "'", txt), "\x14")[[1]]
    if (getOption("nvimcom.formatfun") == "tidy_source") {
        ok <- formatR::tidy_source(text = txt, width.cutoff = wco, output = FALSE)
        if (inherits(ok, "try-error")) {
            .C("nvimcom_msg_to_nvim",
               "call RWarningMsg('Error trying to execute the function formatR::tidy_source()')",
               PACKAGE = "nvimcom")
            return(invisible(NULL))
        }
        txt <- gsub("'", "\x13", paste0(ok$text.tidy, collapse = "\x14"))
    } else if (getOption("nvimcom.formatfun") == "style_text") {
        ok <- try(styler::style_text(txt, indent_by = sw))
        if (inherits(ok, "try-error")) {
            .C("nvimcom_msg_to_nvim",
               "call RWarningMsg('Error trying to execute the function styler::style_text()')",
               PACKAGE = "nvimcom")
            return(invisible(NULL))
        }
        txt <- gsub("'", "\x13", paste0(ok, collapse = "\x14"))
    }

    .C("nvimcom_msg_to_nvim",
       paste0("call FinishRFormatCode(", l1, ", ", l2, ", '", txt, "')"),
       PACKAGE = "nvimcom")
    return(invisible(NULL))
}

#' Returns the output of command to be inserted by Nvim-R.
#' The function is called when the user runs the command `:Rinsert`.
#' @param cmd Command to be executed.
#' @param howto How Nvim-R should insert the result.
nvim_insert <- function(cmd, howto = "tabnew") {
    try(o <- capture.output(cmd))
    if (inherits(o, "try-error")) {
        .C("nvimcom_msg_to_nvim",
           paste0("call RWarningMsg('Error trying to execute the command \"", cmd, "\"')"),
           PACKAGE = "nvimcom")
    } else {
        o <- paste0(o, collapse = "\x14")
        o <- gsub("'", "\x13", o)
        .C("nvimcom_msg_to_nvim",
           paste0("call FinishRInsert('", howto, "', '", o, "')"),
           PACKAGE = "nvimcom")
    }
    return(invisible(NULL))
}

#' Output the arguments of a function as extra information to be shown during
#' omni or auto-completion.
#' Called by nvimrserver when the user selects a function created in the
#' .GlobalEnv environment in the completion menu.
#' menu.
#' @param funcname Name of function selected in the completion menu.
nvim.GlobalEnv.fun.args <- function(funcname) {
    txt <- nvim.args(funcname)
    txt <- gsub('\\\\\\"', '\005', txt)
    txt <- gsub('"', '\\\\"', txt)
    if (Sys.getenv("NVIMR_COMPLCB") == "SetComplMenu") {
        .C("nvimcom_msg_to_nvim",
           paste0('call FinishGlbEnvFunArgs("', funcname, '", "', txt, '")'), PACKAGE = "nvimcom")
    } else {
        .C("nvimcom_msg_to_nvim",
           paste0("call v:lua.require'cmp_nvim_r'.finish_ge_fun_args(\"", txt, '")'),
           PACKAGE = "nvimcom")
    }
    return(invisible(NULL))
}

#' Output the summary as extra information on an object during omni or
#' auto-completion.
#' @param obj Object selected in the completion menu.
#' @param wdth Maximum width of lines in the output.
nvim.get.summary <- function(obj, wdth) {
    isnull <- try(is.null(obj), silent = TRUE)
    if (class(isnull)[1] != "logical")
        return(invisible(NULL))
    if (isnull == TRUE)
        return(invisible(NULL))


    owd <- getOption("width")
    options(width = wdth)
    if (Sys.getenv("NVIMR_COMPLCB") == "SetComplMenu") {
        sobj <- try(summary(obj), silent = TRUE)
        txt <- capture.output(print(sobj))
    } else {
        txt <- ""
        objlbl <- attr(obj, "label")
        if (!is.null(objlbl))
            txt <- append(txt, capture.output(cat("\n\n", objlbl)))
        txt <- append(txt, capture.output(cat("\n\n```rout\n")))
        if (is.factor(obj) || is.numeric(obj) || is.logical(obj)) {
            sobj <- try(summary(obj), silent = TRUE)
            txt <- append(txt, capture.output(print(sobj)))
        } else {
            sobj <- try(capture.output(utils::str(obj)), silent = TRUE)
            txt <- append(txt, sobj)
        }
        txt <- append(txt, capture.output(cat("```\n")))
    }
    options(width = owd)

    txt <- paste0(txt, collapse = "\n")
    txt <- gsub("'", "\x13", gsub("\n", "\x14", txt))

    if (Sys.getenv("NVIMR_COMPLCB") == "SetComplMenu") {
        .C("nvimcom_msg_to_nvim", paste0("call FinishGetSummary('", txt, "')"), PACKAGE = "nvimcom")
    } else {
        .C("nvimcom_msg_to_nvim", paste0("call v:lua.require'cmp_nvim_r'.finish_summary('", txt, "')"),
                                         PACKAGE = "nvimcom")
    }
    return(invisible(NULL))
}

#' List arguments of a function
#' This function is sent to R Console by Nvim-R when the user press `\ra` over
#' an R object.
#' @param ff The object under cursor.
nvim.list.args <- function(ff) {
    saved.warn <- getOption("warn")
    options(warn = -1)
    on.exit(options(warn = saved.warn))
    mm <- try(methods(ff), silent = TRUE)
    if (class(mm)[1] == "MethodsFunction" && length(mm) > 0) {
        for (i in seq_along(mm)) {
            if (exists(mm[i])) {
                cat(ff, "[method ", mm[i], "]:\n", sep = "")
                print(args(mm[i]))
                cat("\n")
            }
        }
        return(invisible(NULL))
    }
    print(args(ff))
}

#' Plot an object.
#' This function is sent to R Console by Nvim-R when the user press `\rg` over
#' an R object.
#' @param x The object under cursor.
nvim.plot <- function(x) {
    xname <- deparse(substitute(x))
    if (length(grep("numeric", class(x))) > 0 || length(grep("integer", class(x))) > 0) {
        oldpar <- par(no.readonly = TRUE)
        par(mfrow = c(2, 1))
        hist(x, col = "lightgray", main = paste("Histogram of", xname), xlab = xname)
        boxplot(x, main = paste("Boxplot of", xname),
                col = "lightgray", horizontal = TRUE)
        par(oldpar)
    } else {
        plot(x)
    }
}

#' Output the names of an object.
#' This function is sent to R Console by Nvim-R when the user press `\rn` over
#' an R object.
#' @param x The object under cursor.
nvim.names <- function(x) {
    if (isS4(x)) {
        slotNames(x)
    } else {
        names(x)
    }
}

#' Get the class of object.
#' @param x R object.
nvim.getclass <- function(x) {
    if (missing(x) || length(charToRaw(x)) == 0)
        return("#E#")

    if (x == "#c#") {
        return("character")
    } else if (x == "#n#") {
        return("numeric")
    }

    if (!exists(x, where = .GlobalEnv)) {
        return("#E#")
    }

    saved.warn <- getOption("warn")
    options(warn = -1)
    on.exit(options(warn = saved.warn))
    tr <- try(cls <- class(get(x, envir = .GlobalEnv)), silent = TRUE)
    if (class(tr)[1] == "try-error")
        return("#E#")

    return(cls)
}

#' Complete arguments of functions.
#' Called during omni-completion or nvim-cmp completion with cmp-nvim-r as
#' source.
#' @param id Completion identification number.
#' @param rkeyword0 Name of function whose arguments are being completed.
#' @param argkey First characters of argument to be completed.
#' @param firstobj First parameter of function being completed.
#' @param lib Name of library preceding the name of the function
#' (example: `library::function`).
#' @param ldf Whether the function is in `R_fun_data_1` or not.
nvim_complete_args <- function(id, rkeyword0, argkey, firstobj = "", lib = NULL, ldf = FALSE) {
    if (firstobj == "") {
        res <- nvim.args(rkeyword0, argkey, lib, extrainfo = TRUE, edq = FALSE)
    } else {
        objclass <- nvim.getclass(firstobj)
        if (objclass[1] == "#E#" || objclass[1] == "") {
            res <- nvim.args(rkeyword0, argkey, lib, extrainfo = TRUE, edq = FALSE)
        } else {
            res <- nvim.args(rkeyword0, argkey, lib, objclass, extrainfo = TRUE, edq = FALSE)
        }
    }
    if (ldf && exists(firstobj)) {
        dtfrm <- get(firstobj)
        if (is.data.frame(dtfrm)) {
            for (n in names(dtfrm)) {
                nlab <- attr(dtfrm[[n]], "label")
                res <- append(res, paste0("{'word': '", n, "', 'menu': '[", firstobj,
                                          "]', 'user_data': {'word': '", firstobj, "$", n,
                                          "', 'env': '", ifelse(is.null(lib), ".GlobalEnv", lib),
                                          "', 'cls': 'v', 'descr': '",
                                          ifelse(is.null(nlab), "", nvim.fix.string(nlab)),
                                          "'}},"))
            }
        }
    }

    res <- paste0(res, collapse = " ")
    .C("nvimcom_msg_to_nvim",
       paste0("+A", id, ";", argkey, ";", rkeyword0, ";", res),
       PACKAGE = "nvimcom")
    return(invisible(NULL))
}
