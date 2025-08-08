# Function called by R if options(editor = vim.edit).
# Vim-R sets this option during vimcom loading.
vim.edit <- function(name, file, title) {
    if (file != "")
        stop("Feature not implemented. Use vim to edit files.")
    if (is.null(name))
        stop("Feature not implemented. Use vim to create R objects from scratch.")

    waitf <- paste0(Sys.getenv("VIMR_TMPDIR"), "/edit_", Sys.getenv("VIMR_ID"), "_wait")
    editf <- paste0(Sys.getenv("VIMR_TMPDIR"), "/edit_", Sys.getenv("VIMR_ID"))
    unlink(editf)
    writeLines(text = "Waiting...", con = waitf)

    initial <- paste0(Sys.getenv("VIMR_TMPDIR"), "/vimcom_edit_",
                      round(runif(1, min = 100, max = 999)))
    sink(initial)
    dput(name)
    sink()

    .C("vimcom_msg_to_vim",
       paste0("call EditRObject('", initial, "')"),
       PACKAGE = "vimcom")

    while (file.exists(waitf))
        Sys.sleep(1)
    x <- eval(parse(editf))
    unlink(initial)
    unlink(editf)
    x
}

# Substitute for utils::vi
vi <- function(name = NULL, file = "") {
    vim.edit(name, file)
}

#' Function called by Vim-R when the user wants to source a line of code and
#' capture its output in a new Vim tab (default key binding `o`)
#' @param s A string representing the line of code to be source.
#' @param nm The name of the buffer to be created in the Vim tab.
vim_capture_source_output <- function(s, nm) {
    o <- capture.output(base::source(s, echo = TRUE), file = NULL)
    o <- paste0(o, collapse = "\x14")
    o <- gsub("'", "\x13", o)
    .C("vimcom_msg_to_vim", paste0("call GetROutput('", nm, "', '", o, "')"),
       PACKAGE = "vimcom")
}

#' Function called by Vim-R when the user wants to run the command `dput()`
#' over the word under cursor and see its output in a new Vim tab.
#' @param oname The name of the object under cursor.
#' @param howto How to show the output (never included when called by Vim-R).
vim_dput <- function(oname, howto = "tabnew") {
    o <- capture.output(eval(parse(text = paste0("dput(", oname, ")"))))
    o <- paste0(o, collapse = "\x14")
    o <- gsub("'", "\x13", o)
    .C("vimcom_msg_to_vim",
       paste0("call ShowRObj('", howto, "', '", oname, "', 'r', '", o, "')"),
       PACKAGE = "vimcom")
}

#' Function called by Vim-R when the user wants to see a `data.frame` or
#' `matrix` (default key bindings: `\rv`, `\vs`, `\vv`, and `\rh`).
#' @param oname The name of the object (`data.frame` or `matrix`).
#' @param fenc File encoding to be used.
#' @param nrows How many lines to show.
#' @param howto How to display the output in Vim.
#' @param R_df_viewer R function to be called to show the `data.frame` or
#' `matrix`.
vim_viewobj <- function(oname, fenc = "", nrows = NULL, howto = "tabnew", R_df_viewer = NULL) {
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
            .C("vimcom_msg_to_vim",
               paste0("call RWarningMsg('", '"', oname, '"', " not found in .GlobalEnv')"),
               PACKAGE = "vimcom")
            return(invisible(NULL))
        }
    }
    if (is.data.frame(o) || is.matrix(o)) {
        if (!is.null(nrows)) {
          o <- utils::head(o, n = nrows)
        }
        if (!is.null(R_df_viewer)) {
            .C("vimcom_msg_to_vim",
               paste0("call g:SendCmdToR(printf(g:R_df_viewer, '", oname, "'))"),
               PACKAGE = "vimcom")
            return(invisible(NULL))
        }
        if (getOption("vimcom.delim") == "\t") {
            txt <- capture.output(write.table(o, sep = "\t", row.names = FALSE, quote = FALSE,
                                              fileEncoding = fenc))
        } else {
            txt <- capture.output(write.table(o, sep = getOption("vimcom.delim"), row.names = FALSE,
                                              fileEncoding = fenc))
        }
        txt <- paste0(txt, collapse = "\x14")
        txt <- gsub("'", "\x13", txt)
        .C("vimcom_msg_to_vim",
           paste0("call RViewDF('", oname, "', '", howto, "', '", txt, "')"),
           PACKAGE = "vimcom")
    } else {
        vim_dput(oname, howto)
    }
    return(invisible(NULL))
}

#' Call base::source.
#' @param ... Further arguments passed to base::source.
#' @param print.eval See base::source.
#' @param spaced See base::source.
VimR.source <- function(..., print.eval = TRUE, spaced = FALSE) {
    base::source(getOption("vimcom.source.path"), ...,
                 print.eval = print.eval, spaced = spaced)
}

#' Call base::source.
#' This function is sent to R Console when the user press `\ss`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
VimR.selection <- function(..., local = parent.frame()) VimR.source(..., local = local)

#' Call base::source.
#' This function is sent to R Console when the user press `\pp`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
VimR.paragraph <- function(..., local = parent.frame()) VimR.source(..., local = local)

#' Call base::source.
#' This function is sent to R Console when the user press `\bb`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
VimR.block <- function(..., local = parent.frame()) VimR.source(..., local = local)

#' Call base::source.
#' This function is sent to R Console when the user press `\ff`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
VimR.function <- function(..., local = parent.frame()) VimR.source(..., local = local)

#' Call base::source.
#' This function is sent to R Console when the user press `\cc`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
VimR.chunk <- function(..., local = parent.frame()) VimR.source(..., local = local)

#' Creates a temporary copy of an R file, source it, and, finally, delete it.
#' This function is sent to R Console when the user press `\aa`, `\ae`, or `\ao`.
#' @param ... Further arguments passed to base::source.
#' @param local See base::source.
source.and.clean <- function(f, print.eval = TRUE, spaced = FALSE, ...) {
    on.exit(unlink(f))
    base::source(f, print.eval = print.eval, spaced = spaced, ...)
}

#' Format R code.
#' Sent to vimcom through vimrserver by Vim-R when the user runs the
#' `Rformat` command.
#' @param l1 First line of selection. Vim-R needs the information to know
#' what lines to replace.
#' @param l2 Last line of selection. Vim-R needs the information to know
#' what lines to replace.
#' @param wco Text width, based on Vim option 'textwidth'.
#' @param sw Vim option 'shiftwidth'.
#' @param txt Text to be formatted.
vim_format <- function(l1, l2, wco, sw, txt) {
    if (is.null(getOption("vimcom.formatfun"))) {
        if (length(find.package("styler", quiet = TRUE, verbose = FALSE)) > 0) {
           options(vimcom.formatfun = "style_text")
        } else {
            if (length(find.package("formatR", quiet = TRUE, verbose = FALSE)) > 0) {
                options(vimcom.formatfun = "tidy_source")
            } else {
                .C("vimcom_msg_to_vim",
                   "call RWarningMsg('You have to install either formatR or styler in order to run :Rformat')",
                   PACKAGE = "vimcom")
                return(invisible(NULL))
            }
        }
    }

    txt <- strsplit(gsub("\x13", "'", txt), "\x14")[[1]]
    if (getOption("vimcom.formatfun") == "tidy_source") {
        ok <- formatR::tidy_source(text = txt, width.cutoff = wco, output = FALSE)
        if (inherits(ok, "try-error")) {
            .C("vimcom_msg_to_vim",
               "call RWarningMsg('Error trying to execute the function formatR::tidy_source()')",
               PACKAGE = "vimcom")
            return(invisible(NULL))
        }
        txt <- gsub("'", "\x13", paste0(ok$text.tidy, collapse = "\x14"))
    } else if (getOption("vimcom.formatfun") == "style_text") {
        ok <- try(styler::style_text(txt, indent_by = sw))
        if (inherits(ok, "try-error")) {
            .C("vimcom_msg_to_vim",
               "call RWarningMsg('Error trying to execute the function styler::style_text()')",
               PACKAGE = "vimcom")
            return(invisible(NULL))
        }
        txt <- gsub("'", "\x13", paste0(ok, collapse = "\x14"))
    }

    .C("vimcom_msg_to_vim",
       paste0("call FinishRFormatCode(", l1, ", ", l2, ", '", txt, "')"),
       PACKAGE = "vimcom")
    return(invisible(NULL))
}

#' Returns the output of command to be inserted by Vim-R.
#' The function is called when the user runs the command `:Rinsert`.
#' @param cmd Command to be executed.
#' @param howto How Vim-R should insert the result.
vim_insert <- function(cmd, howto = "tabnew") {
    try(o <- capture.output(cmd))
    if (inherits(o, "try-error")) {
        .C("vimcom_msg_to_vim",
           paste0("call RWarningMsg('Error trying to execute the command \"", cmd, "\"')"),
           PACKAGE = "vimcom")
    } else {
        o <- paste0(o, collapse = "\x14")
        o <- gsub("'", "\x13", o)
        .C("vimcom_msg_to_vim",
           paste0("call FinishRInsert('", howto, "', '", o, "')"),
           PACKAGE = "vimcom")
    }
    return(invisible(NULL))
}

#' Output the arguments of a function as extra information to be shown during
#' omni or auto-completion.
#' Called by vimrserver when the user selects a function created in the
#' .GlobalEnv environment in the completion menu.
#' menu.
#' @param funcname Name of function selected in the completion menu.
vim.GlobalEnv.fun.args <- function(funcname) {
    txt <- vim.args(funcname)
    txt <- gsub('\\\\\\"', '\005', txt)
    txt <- gsub('"', '\\\\"', txt)
    if (Sys.getenv("VIMR_COMPLCB") == "SetComplMenu") {
        .C("vimcom_msg_to_vim",
           paste0('call FinishGlbEnvFunArgs("', funcname, '", "', txt, '")'), PACKAGE = "vimcom")
    } else {
        .C("vimcom_msg_to_vim",
           paste0("call v:lua.require'cmp_vim_r'.finish_ge_fun_args(\"", txt, '")'),
           PACKAGE = "vimcom")
    }
    return(invisible(NULL))
}

#' Output the summary as extra information on an object during omni or
#' auto-completion.
#' @param obj Object selected in the completion menu.
#' @param wdth Maximum width of lines in the output.
vim.get.summary <- function(obj, wdth) {
    isnull <- try(is.null(obj), silent = TRUE)
    if (class(isnull)[1] != "logical")
        return(invisible(NULL))
    if (isnull == TRUE)
        return(invisible(NULL))


    owd <- getOption("width")
    options(width = wdth)
    if (Sys.getenv("VIMR_COMPLCB") == "SetComplMenu") {
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

    if (Sys.getenv("VIMR_COMPLCB") == "SetComplMenu") {
        .C("vimcom_msg_to_vim", paste0("call FinishGetSummary('", txt, "')"), PACKAGE = "vimcom")
    } else {
        .C("vimcom_msg_to_vim", paste0("call v:lua.require'cmp_vim_r'.finish_summary('", txt, "')"),
                                         PACKAGE = "vimcom")
    }
    return(invisible(NULL))
}

#' List arguments of a function
#' This function is sent to R Console by Vim-R when the user press `\ra` over
#' an R object.
#' @param ff The object under cursor.
vim.list.args <- function(ff) {
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
#' This function is sent to R Console by Vim-R when the user press `\rg` over
#' an R object.
#' @param x The object under cursor.
vim.plot <- function(x) {
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
#' This function is sent to R Console by Vim-R when the user press `\rn` over
#' an R object.
#' @param x The object under cursor.
vim.names <- function(x) {
    if (isS4(x)) {
        slotNames(x)
    } else {
        names(x)
    }
}

#' Get the class of object.
#' @param x R object.
vim.getclass <- function(x) {
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
#' Called during omni-completion or vim-cmp completion with cmp-vim-r as
#' source.
#' @param id Completion identification number.
#' @param rkeyword0 Name of function whose arguments are being completed.
#' @param argkey First characters of argument to be completed.
#' @param firstobj First parameter of function being completed.
#' @param lib Name of library preceding the name of the function
#' (example: `library::function`).
#' @param ldf Whether the function is in `R_fun_data_1` or not.
vim_complete_args <- function(id, rkeyword0, argkey, firstobj = "", lib = NULL, ldf = FALSE) {
    if (firstobj == "") {
        res <- vim.args(rkeyword0, argkey, lib, extrainfo = TRUE, edq = FALSE)
    } else {
        objclass <- vim.getclass(firstobj)
        if (objclass[1] == "#E#" || objclass[1] == "") {
            res <- vim.args(rkeyword0, argkey, lib, extrainfo = TRUE, edq = FALSE)
        } else {
            res <- vim.args(rkeyword0, argkey, lib, objclass, extrainfo = TRUE, edq = FALSE)
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
                                          ifelse(is.null(nlab), "", vim.fix.string(nlab)),
                                          "'}},"))
            }
        }
    }

    res <- paste0(res, collapse = " ")
    .C("vimcom_msg_to_vim",
       paste0("+A", id, ";", argkey, ";", rkeyword0, ";", res),
       PACKAGE = "vimcom")
    return(invisible(NULL))
}
