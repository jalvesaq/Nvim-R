###############################################################################
# The code of the next four functions were copied from the gbRd package
# version 0.4-11 (released on 2012-01-04) and adapted to nvimcom.
# The gbRd package was developed by Georgi N. Boshnakov.

#' Get section of Rd data.
#' @param s Section title.
#' @param sectag Section.
#' @param eltag Type of element.
gbRd.set_sectag <- function(s, sectag, eltag) {
    attr(s, "Rd_tag") <- eltag  # using `structure' would be more elegant...
    res <- list(s)
    attr(res, "Rd_tag") <- sectag
    res
}

#' Get Rd information on a function.
#' @param x Function name.
#' @param pkg Library name.
gbRd.fun <- function(x, pkg) {
    rdo <- NULL # prepare the "Rd" object rdo
    x <- do.call(utils::help,
                 list(x, pkg, help_type = "text", verbose = FALSE,
                      try.all.packages = FALSE))
    if (length(x) == 0)
        return(NULL)

    # If more matches are found will `paths' have length > 1?
    f <- as.character(x[1]) # removes attributes of x.

    path <- dirname(f)
    dirpath <- dirname(path)
    pkgname <- basename(dirpath)
    RdDB <- file.path(path, pkgname)

    if (file.exists(paste(RdDB, "rdx", sep = "."))) {
        rdo <- tools:::fetchRdDB(RdDB, basename(f))
    }
    if (is.null(rdo))
        return(NULL)

    tags <- tools:::RdTags(rdo)
    keep_tags <- c("\\title", "\\name", "\\arguments")
    rdo[which(!(tags %in% keep_tags))] <-  NULL

    rdo
}

#' Get information on function arguments from R documentation.
#' @param rdo Rd object.
#' @param arg Argument.
gbRd.get_args <- function(rdo, arg) {
    tags <- tools:::RdTags(rdo)
    wtags <- which(tags == "\\arguments")

    if (length(wtags) != 1)
        return(NULL)

    rdargs <- rdo[[wtags]] # use of [[]] assumes only one element here
    f <- function(x) {
        wrk0 <- as.character(x[[1]])
        for (w in wrk0)
            if (w %in% arg)
                return(TRUE)

        wrk <- strsplit(wrk0, ",[ ]*")
        if (!is.character(wrk[[1]])) {
            warning("wrk[[1]] is not a character vector! ", wrk)
            return(FALSE)
        }
        wrk <- any(wrk[[1]] %in% arg)
        wrk
    }
    sel <- !sapply(rdargs, f)

    ## deal with "..." arg
    if ("..." %in% arg || "\\dots" %in% arg) {  # since formals() represents ... by "..."
        f2 <- function(x) {
            if (is.list(x[[1]]) && length(x[[1]]) > 0 &&
               attr(x[[1]][[1]], "Rd_tag") == "\\dots") {
                TRUE
            } else {
                FALSE
            }
        }
        i2 <- sapply(rdargs, f2)
        sel[i2] <- FALSE
    }

    rdargs[sel] <- NULL   # keeps attributes (even if 0 or 1 elem remain).
    rdargs
}

#' Get and convert information from Rd data to plain text.
#' @param pkg Library name.
#' @param rdo Rd object.
#' @param arglist List of arguments.
gbRd.args2txt <- function(pkg = NULL, rdo, arglist) {
    rdo <- gbRd.fun(rdo, pkg)

    if (is.null(rdo))
        return(list())

    get_items <- function(a, rdo) {
        if (is.null(a) || is.na(a))
            return(NA)
        # Build a dummy documentation with only one item in the "arguments" section
        x <- list()
        class(x) <- "Rd"
        x[[1]] <- gbRd.set_sectag("Dummy name", sectag = "\\name", eltag = "VERB")
        x[[2]] <- gbRd.set_sectag("Dummy title", sectag = "\\title", eltag = "TEXT")
        x[[3]] <- gbRd.get_args(rdo, a)
        tags <- tools:::RdTags(x)

        # We only need the section "arguments", but print(x) will result in
        # nothing useful if either "title" or "name" section is missing
        keep_tags <- c("\\title", "\\name", "\\arguments")
        x[which(!(tags %in% keep_tags))] <-  NULL

        res <- paste0(x, collapse = "", sep = "")

        # The result is (example from utils::available.packages()):
        # \name{Dummy name}\title{Dummy title}\arguments{\item{max_repo_cache_age}{any
        # cached values older than this in seconds     will be ignored. See \sQuote{Details}.   }}

        .Call("get_section", res, "arguments", PACKAGE = "nvimcom")
    }
    argl <- lapply(arglist, get_items, rdo)
    names(argl) <- arglist
    argl
}

###############################################################################


# For building omnls files
#' @param x
#' @param edq Whether double quotes should be escaped.
nvim.fix.string <- function(x, edq = TRUE) {
    x <- gsub("\n", "\\\\n", x)
    x <- gsub("\r", "\\\\r", x)
    x <- gsub("\t", "\\\\t", x)
    x <- gsub("'", "\x13", x)
    if (edq) {
        x <- gsub('"', '\\\\"', x)
    } else {
        x <- sub("^\\s*", "", x)
        x <- paste(x, collapse = "")
    }
    x
}

#' Get the list of arguments of a function
#' @param funcname Function name.
#' @param txt Begin of parameter name.
#' @param pkg Library name. If not NULL, restrict the search to `pkg`.
#' @param objclass Class of first argument of the function.
#' @param extrainfo Whether to include additional information for completion.
#' @param edq Whether double quotes should be escaped.
nvim.args <- function(funcname, txt = "", pkg = NULL, objclass, extrainfo = FALSE, edq = TRUE) {
    # Adapted from: https://stat.ethz.ch/pipermail/ess-help/2011-March/006791.html
    if (!exists(funcname))
        return("")
    frm <- NA
    funcmeth <- NA
    if (!missing(objclass) && nvim.grepl("[[:punct:]]", funcname) == FALSE) {
        saved.warn <- getOption("warn")
        options(warn = -1)
        on.exit(options(warn = saved.warn))
        mlen <- try(length(methods(funcname)), silent = TRUE) # Still get warns
        if (class(mlen)[1] == "integer" && mlen > 0) {
            for (i in seq_along(objclass)) {
                funcmeth <- paste0(funcname, ".", objclass[i])
                if (existsFunction(funcmeth)) {
                    funcname <- funcmeth
                    frm <- formals(funcmeth)
                    break
                }
            }
        }
    }

    if (is.null(pkg)) {
        pkgname <- sub(".*:", "", find(funcname, mode = "function")[1])
    } else {
        pkgname <- pkg
    }

    if (is.na(frm[1])) {
        if (is.null(pkg)) {
            deffun <- paste0(funcname, ".default")
            if (existsFunction(deffun) && pkgname != ".GlobalEnv") {
                funcname <- deffun
                funcmeth <- deffun
            } else if (!existsFunction(funcname)) {
                return("")
            }
            if (is.primitive(get(funcname))) {
                a <- args(funcname)
                if (is.null(a))
                    return("")
                frm <- formals(a)
            } else {
                try(frm <- formals(get(funcname, envir = globalenv())), silent = TRUE)
                if (length(frm) == 1 && is.na(frm))
                    return("")
            }
        } else {
            idx <- grep(paste0(":", pkg, "$"), search())
            if (length(idx)) {
                ff <- "NULL"
                tr <- try(ff <- get(paste0(funcname, ".default"), pos = idx), silent = TRUE)
                if (class(tr)[1] == "try-error")
                    ff <- get(funcname, pos = idx)
                if (is.primitive(ff)) {
                    a <- args(ff)
                    if (is.null(a))
                        return("")
                    frm <- formals(a)
                } else
                    frm <- formals(ff)
            } else {
                if (!isNamespaceLoaded(pkg))
                    loadNamespace(pkg)
                ff <- getAnywhere(funcname)
                idx <- grep(pkg, ff$where)
                if (length(idx))
                    frm <- formals(ff$objs[[idx]])
            }
        }
    }

    if (pkgname[1] != ".GlobalEnv" && extrainfo && length(frm) > 0) {
        arglist <- gbRd.args2txt(pkgname, funcname, names(frm))
        arglist <- lapply(arglist, nvim.fix.string, edq)
    }

    res <- NULL
    for (field in names(frm)) {
        type <- typeof(frm[[field]])
        if (extrainfo) {
            str1 <- paste0("{\x12word\x12: \x12", field)
            if (type == "symbol") {
                str2 <- paste0("\x12, \x12menu\x12: \x12 \x12")
            } else if (type == "character") {
                str2 <- paste0(" = \x12, \x12menu\x12: \x12\"", nvim.fix.string(frm[[field]]), "\"\x12")
            } else if (type == "logical" || type == "double" || type == "integer") {
                str2 <- paste0(" = \x12, \x12menu\x12: \x12", as.character(frm[[field]]), "\x12")
            } else if (type == "NULL") {
                str2 <- paste0(" = \x12, \x12menu\x12: \x12NULL\x12")
            } else if (type == "language") {
                str2 <- paste0(" = \x12, \x12menu\x12: \x12",
                               nvim.fix.string(deparse(frm[[field]]), FALSE), "\x12")
            } else {
                str2 <- paste0("\x12, \x12menu\x12: \x12 \x12")
            }
            if (pkgname != ".GlobalEnv" && extrainfo && length(frm) > 0) {
                res <- append(res, paste0(str1, str2, ", \x12user_data\x12: {\x12cls\x12: \x12a\x12, \x12argument\x12: \x12",
                                          arglist[[field]], "\x12}}, "))
            } else {
                res <- append(res, paste0(str1, str2, "}, "))
            }
        } else {
            if (type == "symbol") {
                res <- append(res, paste0("[\x12", field, "\x12], "))
            } else if (type == "character") {
                res <- append(res, paste0("[\x12", field, "\x12, \x12\"",
                                          nvim.fix.string(frm[[field]]), "\"\x12], "))
            } else if (type == "logical" || type == "double" || type == "integer") {
                res <- append(res, paste0("[\x12", field, "\x12, \x12", as.character(frm[[field]]), "\x12], "))
            } else if (type == "NULL") {
                res <- append(res, paste0("[\x12", field, "\x12, \x12NULL\x12], "))
            } else if (type == "language") {
                res <- append(res, paste0("[\x12", field, "\x12, \x12",
                                          nvim.fix.string(deparse(frm[[field]]), FALSE), "\x12], "))
            } else {
                res <- append(res, paste0("[\x12", field, "\x12], "))
                warning(paste0("nvim.args: ", funcname, " [", field, "]", " (typeof = ", type, ")"))
            }
        }
    }


    if (!extrainfo)
        res <- paste0(res, collapse = "")


    if (length(res) == 0 || (length(res) == 1 && res == "")) {
        res <- "[]"
    } else {
        if (is.null(pkg)) {
            info <- pkgname
            if (!is.na(funcmeth)) {
                if (info != "")
                    info <- paste0(info, ", ")
                info <- paste0(info, "function:", funcmeth, "()")
            }
            # TODO: Add the method name to the completion menu if (info != "")
        }
    }

    return(res)
}


#' Check if `pattern` is included in the vector `x`.
#' @param Pattern.
#' @param x Character vector.
nvim.grepl <- function(pattern, x) {
    res <- grep(pattern, x)
    if (length(res) == 0) {
        return(FALSE)
    } else {
        return(TRUE)
    }
}

#' Get object description from R documentation.
#' @param printenv Library name
#' @param x Object name
nvim.getInfo <- function(printenv, x) {
    info <- NULL
    als <- NvimcomEnv$pkgdescr[[printenv]]$alias[NvimcomEnv$pkgdescr[[printenv]]$alias[, "name"] == x, "alias"]
    try(info <- NvimcomEnv$pkgdescr[[printenv]]$descr[[als]], silent = TRUE)
    if (length(info) == 1)
        return(info)
    return("\006\006")
}

#' Make a single line of the `omnils_` file with information for omni or auto
#' completion of object names.
#' @param x R object
#' @param envir Current "environment" of object x. It will be
#' `package:libname`.
#' @param printenv The same as envir, but without the `package:` prefix.
#' @param curlevel Current number of levels in lists and S4 objects.
#' @param maxlevel Maximum number of levels in lists and S4 objects to parse,
#' with 0 meanin no limit.
nvim.omni.line <- function(x, envir, printenv, curlevel, maxlevel = 0) {
    if (curlevel == 0) {
        xx <- try(get(x, envir), silent = TRUE)
        if (inherits(xx, "try-error"))
            return(invisible(NULL))
    } else {
        x.clean <- gsub("$", "", x, fixed = TRUE)
        x.clean <- gsub("_", "", x.clean, fixed = TRUE)
        haspunct <- nvim.grepl("[[:punct:]]", x.clean)
        if (haspunct[1]) {
            ok <- nvim.grepl("[[:alnum:]]\\.[[:alnum:]]", x.clean)
            if (ok[1]) {
                haspunct  <- FALSE
                haspp <- nvim.grepl("[[:punct:]][[:punct:]]", x.clean)
                if (haspp[1]) haspunct <- TRUE
            }
        }

        # No support for names with spaces
        if (nvim.grepl(" ", x)) {
            haspunct <- TRUE
        }

        if (haspunct[1]) {
            xx <- NULL
        } else {
            xx <- try(eval(parse(text = x)), silent = TRUE)
            if (class(xx)[1] == "try-error") {
                xx <- NULL
            }
        }
    }

    if (is.null(xx)) {
        x.class <- ""
        x.group <- "*"
    } else {
        if (x == "break" || x == "next" || x == "for" || x == "if" || x == "repeat" || x == "while") {
            x.group <- ";"
            x.class <- "flow-control"
        } else {
            x.class <- class(xx)[1]
            if (is.function(xx)) {
                x.group <- "f"
            } else if (is.numeric(xx)) {
                x.group <- "{"
            } else if (is.factor(xx)) {
                x.group <- "!"
            } else if (is.character(xx)) {
                x.group <- "~"
            } else if (is.logical(xx)) {
                x.group <- "%"
            } else if (is.data.frame(xx)) {
                x.group <- "$"
            } else if (is.list(xx)) {
                x.group <- "["
            } else if (is.environment(xx)) {
                x.group <- ":"
            } else {
                x.group <- "*"
            }
        }
    }

    n <- nvim.fix.string(x)

    if (curlevel == maxlevel || maxlevel == 0) {
        if (x.group == "f") {
            if (curlevel == 0) {
                if (nvim.grepl("GlobalEnv", printenv)) {
                    cat(n, "\006\003\006\006", printenv, "\006",
                        nvim.args(x), "\n", sep = "")
                } else {
                    info <- nvim.getInfo(printenv, x)
                    cat(n, "\006\003\006\006", printenv, "\006",
                        nvim.args(x, pkg = printenv), info, "\006\n", sep = "")
                }
            } else {
                # some libraries have functions as list elements
                cat(n, "\006\003\006\006", printenv,
                    "\006Unknown arguments\006\006\006\n", sep = "")
            }
        } else {
            if (is.list(xx) || is.environment(xx)) {
                if (curlevel == 0) {
                    info <- nvim.getInfo(printenv, x)
                    if (is.data.frame(xx)) {
                        cat(n, "\006", x.group, "\006", x.class, "\006", printenv,
                            "\006[", nrow(xx), ", ", ncol(xx), "]", info, "\006\n", sep = "")
                    } else if (is.list(xx)) {
                        cat(n, "\006", x.group, "\006", x.class, "\006", printenv,
                            "\006", length(xx), info, "\006\n", sep = "")
                    } else {
                        cat(n, "\006", x.group, "\006", x.class, "\006", printenv,
                            "\006[]", info, "\006\n", sep = "")
                    }
                } else {
                    cat(n, "\006", x.group, "\006", x.class, "\006", printenv,
                        "\006[]\006\006\006\n", sep = "")
                }
            } else {
                info <- nvim.getInfo(printenv, x)
                if (info == "\006\006") {
                    xattr <- try(attr(xx, "label"), silent = TRUE)
                    if (!inherits(xattr, "try-error"))
                        if (!is.null(xattr) && length(xattr) == 1)
                            info <- paste0("\006\006", .Call("rd2md", xattr, PACKAGE = "nvimcom"))
                }
                cat(n, "\006", x.group, "\006", x.class, "\006", printenv,
                    "\006[]", info, "\006\n", sep = "")
            }
        }
    }

    if ((is.list(xx) || is.environment(xx)) && curlevel <= maxlevel) {
        obj.names <- names(xx)
        curlevel <- curlevel + 1
        xxl <- length(xx)
        if (!is.null(xxl) && xxl > 0) {
            for (k in obj.names) {
                nvim.omni.line(paste(x, "$", k, sep = ""), envir, printenv, curlevel, maxlevel)
            }
        }
    } else if (isS4(xx) && curlevel <= maxlevel) {
        obj.names <- slotNames(xx)
        curlevel <- curlevel + 1
        xxl <- length(xx)
        if (!is.null(xxl) && xxl > 0) {
            for (k in obj.names) {
                nvim.omni.line(paste(x, "@", k, sep = ""), envir, printenv, curlevel, maxlevel)
            }
        }
    }
}

#' Store descriptions of all functions from a library in a internal
#' environment.
#' @param pkg Library name.
GetFunDescription <- function(pkg) {
    # Code adapted from the gbRd package
    pth <- attr(packageDescription(pkg), "file")
    pth <- sub("Meta/package.rds", "", pth)
    pth <- paste0(pth, "help/")
    idx <- paste0(pth, "AnIndex")

    # Development packages might not have any written documentation yet
    if (!file.exists(idx) || !file.info(idx)$size)
        return(NULL)

    tab <- read.table(idx, sep = "\t", comment.char = "", quote = "", stringsAsFactors = FALSE)
    als <- tab$V2
    names(als) <- tab$V1
    als <- list("name" = names(als), "alias" = unname(als))
    als$name <- lapply(als$name, function(x) strsplit(x, ",")[[1]])
    for (i in seq_along(als$alias))
        als$name[[i]] <- cbind(als$alias[[i]], als$name[[i]])
    als <- do.call("rbind", als$name)
    if (nrow(als) > 1) {
        als <- als[stats::complete.cases(als), ]
        als <- als[!duplicated(als[, 2]), ]
    }
    colnames(als) <- c("alias", "name")

    if (!file.exists(paste0(pth, pkg, ".rdx")))
        return(NULL)
    pkgInfo <- tools:::fetchRdDB(paste0(pth, pkg))

    GetDescr <- function(x) {
        x <- paste0(x, collapse = "")
        ttl <- .Call("get_section", x, "title", PACKAGE = "nvimcom")
        dsc <- .Call("get_section", x, "description", PACKAGE = "nvimcom")
        x <- paste0("\006", ttl, "\006", dsc)
        x
    }
    NvimcomEnv$pkgdescr[[pkg]] <- list("descr" = sapply(pkgInfo, GetDescr),
                                       "alias" = als)
}

#' @param x
filter.objlist <- function(x) {
    x[!grepl("^[\\[\\(\\{:-@%/=+\\$<>\\|~\\*&!\\^\\-]", x) & !grepl("^\\.__", x)]
}

#' Build in Nvim-R's cache directory the `args_` file with arguments of
#' functions.
#' @param afile Full path of the `args_` file.
#' @param pkg Library name.
nvim.buildargs <- function(afile, pkg) {
    ok <- try(require(pkg, warn.conflicts = FALSE,
                      quietly = TRUE, character.only = TRUE))
    if (!ok)
        return(invisible(NULL))

    pkgenv <- paste0("package:", pkg)
    obj.list <- objects(pkgenv)
    obj.list <- filter.objlist(obj.list)

    sink(afile)
    for (obj in obj.list) {
        x <- try(get(obj, pkgenv, mode = "any"), silent = TRUE)
        if (!is.function(x))
            next
        if (inherits(x, "try-error")) {
            warning(paste0("Error while generating item completion for: ",
                           obj, " (", pkgenv, ").\n"))
            next
        }
        if (length(x) != 1) # base::letters
            next
        if (is.primitive(x)) {
            a <- args(x)
            if (is.null(a))
                next
            frm <- formals(a)
        } else {
            frm <- formals(x)
        }
        arglist <- gbRd.args2txt(pkg, obj, names(frm))
        arglist <- lapply(arglist, nvim.fix.string)
        cat(obj, "\006",
            paste(names(arglist), arglist, sep = "\005", collapse = "\006"),
            "\006", sep = "", "\n")
    }
    sink()
    return(invisible(NULL))
}

#' Build Omni List and list of functions for syntax highlighting in Nvim-R's
#' cache directory.
#' @param omnilist Full path of `omnils_` file to be built.
#' @param packlist Library name.
#' @param allnames Whether to include objects whose names begin with a dot.
nvim.bol <- function(omnilist, packlist, allnames = FALSE) {
    nvim.OutDec <- getOption("OutDec")
    on.exit(options(nvim.OutDec))
    options(OutDec = ".")

    if (!missing(packlist) && is.null(NvimcomEnv$pkgdescr[[packlist]]))
        GetFunDescription(packlist)

    loadpack <- search()
    if (missing(packlist)) {
        listpack <- loadpack[grep("^package:", loadpack)]
    } else {
        listpack <- paste0("package:", packlist)
    }

    for (curpack in listpack) {
        curlib <- sub("^package:", "", curpack)
        if (nvim.grepl(paste0(curpack, "$"), loadpack) == FALSE) {
            ok <- try(require(curlib, warn.conflicts = FALSE,
                                      quietly = TRUE, character.only = TRUE))
            if (!ok)
                next
        }

        obj.list <- objects(curpack, all.names = allnames)
        obj.list <- filter.objlist(obj.list)

        l <- length(obj.list)
        if (l > 0) {
            # Build omnils_ for both omni completion and Object Browser
            sink(omnilist, append = FALSE)
            for (obj in obj.list) {
                ol <- try(nvim.omni.line(obj, curpack, curlib, 0))
                if (inherits(ol, "try-error"))
                    warning(paste0("Error while generating omni completion line for: ",
                                   obj, " (", curpack, ", ", curlib, ").\n"))
            }
            sink()
            # Build list of functions for syntax highlight
            fl <- readLines(omnilist)
            fl <- fl[grep("\006\003\006", fl)]
            fl <- sub("\006.*", "", fl)
            fl <- fl[!grepl("[<%\\[\\+\\*&=\\$:{|@\\(\\^>/~!]", fl)]
            fl <- fl[!grepl("-", fl)]
            if (curlib == "base") {
                fl <- fl[!grepl("^array$", fl)]
                fl <- fl[!grepl("^attach$", fl)]
                fl <- fl[!grepl("^character$", fl)]
                fl <- fl[!grepl("^complex$", fl)]
                fl <- fl[!grepl("^data.frame$", fl)]
                fl <- fl[!grepl("^detach$", fl)]
                fl <- fl[!grepl("^double$", fl)]
                fl <- fl[!grepl("^function$", fl)]
                fl <- fl[!grepl("^integer$", fl)]
                fl <- fl[!grepl("^library$", fl)]
                fl <- fl[!grepl("^list$", fl)]
                fl <- fl[!grepl("^logical$", fl)]
                fl <- fl[!grepl("^matrix$", fl)]
                fl <- fl[!grepl("^numeric$", fl)]
                fl <- fl[!grepl("^require$", fl)]
                fl <- fl[!grepl("^source$", fl)]
                fl <- fl[!grepl("^vector$", fl)]
            }
            if (length(fl) > 0) {
                fl <- paste("syn keyword rFunction", fl)
                writeLines(text = fl, con = sub("omnils_", "fun_", omnilist))
            } else {
                writeLines(text = '" No functions found.', con = sub("omnils_", "fun_", omnilist))
            }
        } else {
            writeLines(text = "", con = omnilist)
            writeLines(text = '" No functions found.', con = sub("omnils_", "fun_", omnilist))
        }
    }
    return(invisible(NULL))
}

#' This function calls nvim.bol which writes two files in `~/.cache/Nvim-R`:
#'   - `fun_`    : function names for syntax highlighting
#'   - `omnils_` : data for omni completion and object browser
#' @param p Character vector with names of libraries.
nvim.buildomnils <- function(p) {
    if (length(p) > 1) {
        n <- 0
        for (pkg in p)
            n <- n + nvim.buildomnils(pkg)
        if (n > 0)
            return(invisible(1))
        return(invisible(0))
    }
    # No verbosity because running as Neovim job
    options(nvimcom.verbose = 0)

    pvi <- utils::packageDescription(p)$Version
    bdir <- paste0(Sys.getenv("NVIMR_COMPLDIR"), "/")
    odir <- dir(bdir)
    pbuilt <- odir[grep(paste0("omnils_", p, "_"), odir)]
    fbuilt <- odir[grep(paste0("fun_", p, "_"), odir)]
    abuilt <- odir[grep(paste0("args_", p, "_"), odir)]

    need_build <- FALSE

    if (length(fbuilt) == 0 || length(pbuilt) == 0) {
        # no omnils
        need_build <- TRUE
    } else {
        if (length(fbuilt) > 1 || length(pbuilt) > 1) {
            # omnils is duplicated (should never happen)
            need_build <- TRUE
        } else {
            pvb <- sub(".*_.*_", "", pbuilt)
            # omnils is either outdated or older than the README
            if (pvb != pvi ||
                file.info(paste0(bdir, "README"))$mtime > file.info(paste0(bdir, pbuilt))$mtime)
                need_build <- TRUE
        }
    }

    if (need_build) {
        msg <- paste0("echo 'Building completion list for \"", p, "\"'\x14\n")
        cat(msg)
        flush(stdout())
        unlink(c(paste0(bdir, pbuilt), paste0(bdir, fbuilt), paste0(bdir, abuilt)))
        nvim.bol(paste0(bdir, "omnils_", p, "_", pvi), p, TRUE)
        return(invisible(1))
    }
    return(invisible(0))
}
