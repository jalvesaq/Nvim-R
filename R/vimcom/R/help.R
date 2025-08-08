# Function called by R if options(pager = vim.hmsg).
# Vim-R sets this option during vimcom loading.
vim.hmsg <- function(files, header, title, delete.file) {
    doc <- gsub("'", "\x13", paste(readLines(files[1]), collapse = "\x14"))
    ttl <- sub("R Help on '(.*)'", "\\1 (help)", title)
    ttl <- sub("R Help on \u2018(.*)\u2019", "\\1 (help)", ttl)
    ttl <- gsub("'", "''", ttl)
    .C("vimcom_msg_to_vim", paste0("call ShowRDoc('", ttl, "', '", doc, "')"), PACKAGE = "vimcom")
    return(invisible(NULL))
}

#' Function called by Vim-R after `\rh` or `:Rhelp`.
#' Vim-R sends the command through the vimrserver TCP connection to vimcom
#' and R evaluates the command when idle.
#' @param topic The word under cursor when `\rh` was pressed.
#' @param w The width that lines should have in the formatted document.
#' @param firstobj The first argument of `topic`, if any. There will be a first
#' object if the user requests the documentation of `topic(firstobj)`.
#' @param package The name of the package, if any. There will be a package if
#' the user request the documentation from the Object Browser or the cursor is
#' over `package::topic`.
vim.help <- function(topic, w, firstobj, package) {
    if (!missing(firstobj) && firstobj != "") {
        objclass <- vim.getclass(firstobj)
        if (objclass[1] != "#E#" && objclass[1] != "") {
            saved.warn <- getOption("warn")
            options(warn = -1)
            on.exit(options(warn = saved.warn))
            mlen <- try(length(methods(topic)), silent = TRUE)
            if (class(mlen)[1] == "integer" && mlen > 0) {
                for (i in seq_along(objclass)) {
                    newtopic <- paste0(topic, ".", objclass[i])
                    if (length(utils::help(newtopic))) {
                        topic <- newtopic
                        break
                    }
                }
            }
        }
    }

    oldRdOp <- tools::Rd2txt_options()
    on.exit(tools::Rd2txt_options(oldRdOp))
    tools::Rd2txt_options(width = w)

    oldpager <- getOption("pager")
    on.exit(options(pager = oldpager), add = TRUE)
    options(pager = vim.hmsg)

    warn <- function(msg) {
        .C("vimcom_msg_to_vim",
           paste0("call RWarningMsg('", as.character(msg), "')"),
           PACKAGE = "vimcom")
    }

    if ("pkgload" %in% loadedNamespaces()) {
        ret <- try(pkgload::dev_help(topic), silent = TRUE)

        if (!inherits(ret, "try-error")) {
            suppressMessages(print(ret))
            return(invisible(NULL))
        } else if (!missing(package) && pkgload::is_dev_package(package)) {
            warn(ret)
            return(invisible(NULL))
        }
    }

    if ("devtools" %in% loadedNamespaces()) {
        ret <- suppressMessages(try(devtools::dev_help(topic), silent = TRUE))

        if (!inherits(ret, "try-error")) {
            return(invisible(NULL))
        } else if (!missing(package) && package %in% devtools::dev_packages()) {
            warn(ret)
            return(invisible(NULL))
        }
    }

    if (missing(package)) {
        h <- utils::help(topic, help_type = "text")
    } else {
        h <- utils::help(topic, package = as.character(package), help_type = "text")
    }

    if (length(h) == 0) {
        msg <- paste0('No documentation for "', topic, '" in loaded packages and libraries.')
        .C("vimcom_msg_to_vim", paste0("call RWarningMsg('", msg, "')"), PACKAGE = "vimcom")
        return(invisible(NULL))
    }
    if (length(h) > 1) {
        if (missing(package)) {
            h <- sub("/help/.*", "", h)
            h <- sub(".*/", "", h)
            .C("vimcom_msg_to_vim",
               paste0("call ShowRDoc('MULTILIB ", topic, "', '", paste(h, collapse = " "), "')"),
               PACKAGE = "vimcom")
            return(invisible(NULL))
        } else {
            h <- h[grep(paste0("/", package, "/"), h)]
            if (length(h) == 0) {
                msg <- paste0("Package '", package, "' has no documentation for '", topic, "'")
                .C("vimcom_msg_to_vim", paste0("call RWarningMsg('", msg, "')"), PACKAGE = "vimcom")
                return(invisible(NULL))
            }
        }
    }
    print(h)

    return(invisible(NULL))
}

#' Function called by Vim-R after `\re`.
#' @param The word under cursor. Should be a function.
vim.example <- function(topic) {
    saved.warn <- getOption("warn")
    options(warn = -1)
    on.exit(options(warn = saved.warn))
    ret <- try(example(topic, give.lines = TRUE, character.only = TRUE,
                       package = NULL), silent = TRUE)
    if (inherits(ret, "try-error")) {
        .C("vimcom_msg_to_vim",
           paste0("call RWarningMsg('", as.character(ret), "')"), PACKAGE = "vimcom")
    } else {
        if (is.character(ret)) {
            if (length(ret) > 0) {
                writeLines(ret, paste0(Sys.getenv("VIMR_TMPDIR"), "/example.R"))
                .C("vimcom_msg_to_vim", "call OpenRExample()", PACKAGE = "vimcom")
            } else {
                .C("vimcom_msg_to_vim",
                   paste0("call RWarningMsg('There is no example for \"", topic, "\"')"),
                   PACKAGE = "vimcom")
            }
        } else {
            .C("vimcom_msg_to_vim",
               paste0("call RWarningMsg('There is no help for \"", topic, "\".')"),
               PACKAGE = "vimcom")
        }
    }
    return(invisible(NULL))
}
