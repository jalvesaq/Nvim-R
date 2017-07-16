#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  A copy of the GNU General Public License is available at
#  http://www.r-project.org/Licenses/

### Jakson Alves de Aquino


###############################################################################
# The code of the next four functions were copied from the gbRd package
# version 0.4-11 (released on 2012-01-04) and adapted to nvimcom.
# The gbRd package was developed by Georgi N. Boshnakov.

gbRd.set_sectag <- function(s,sectag,eltag){
    attr( s, "Rd_tag") <- eltag  # using `structure' would be more elegant...
    res <- list(s)
    attr( res, "Rd_tag") <- sectag
    res
}

gbRd.fun <- function(x){
    rdo <- NULL # prepare the "Rd" object rdo
    x <- do.call("help", list(x, help_type = "text",
                               verbose = FALSE,
                               try.all.packages = FALSE))
    if(length(x) == 0)
        return(NULL)

    # If more matches are found will `paths' have length > 1?
    f <- as.character(x[1]) # removes attributes of x.

    path <- dirname(f)
    dirpath <- dirname(path)
    pkgname <- basename(dirpath)
    RdDB <- file.path(path, pkgname)

    if(file.exists(paste(RdDB, "rdx", sep="."))) {
        rdo <- tools:::fetchRdDB(RdDB, basename(f))
    }
    if(is.null(rdo))
        return(NULL)

    tags <- tools:::RdTags(rdo)
    keep_tags <- unique(c("\\title","\\name", "\\arguments"))
    rdo[which(!(tags %in% keep_tags))] <-  NULL

    rdo
}

gbRd.get_args <- function(rdo, arg){
    tags <- tools:::RdTags(rdo)
    wtags <- which(tags=="\\arguments")

    if(length(wtags) != 1)
        return(NULL)

    rdargs <- rdo[[wtags]] # use of [[]] assumes only one element here
    f <- function(x){
        wrk0 <- as.character(x[[1]])
        for(w in wrk0)
            if(w %in% arg)
                return(TRUE)

        wrk <- strsplit(wrk0,",[ ]*")
        if(!is.character(wrk[[1]])){
            warning("wrk[[1]] is not a character vector! ", wrk)
            return(FALSE)
        }
        wrk <- any( wrk[[1]] %in% arg )
        wrk
    }
    sel <- !sapply(rdargs, f)

    ## deal with "..." arg
    if("..." %in% arg || "\\dots" %in% arg){  # since formals() represents ... by "..."
        f2 <- function(x){
            if(is.list(x[[1]]) && length(x[[1]])>0 &&
               attr(x[[1]][[1]],"Rd_tag") == "\\dots")
                TRUE
            else
                FALSE
        }
        i2 <- sapply(rdargs, f2)
        sel[i2] <- FALSE
    }

    rdargs[sel] <- NULL   # keeps attributes (even if 0 or 1 elem remain).
    rdargs
}

gbRd.args2txt <- function(rdo, arglist){
    rdo <- gbRd.fun(rdo)

    if(is.null(rdo))
        return(list())

    argl <- list()
    for(a in arglist){
        x <- list()
        class(x) <- "Rd"
        x[[1]] <- gbRd.set_sectag("Dummy name", sectag="\\name", eltag="VERB")
        x[[2]] <- gbRd.set_sectag("Dummy title", sectag="\\title", eltag="TEXT")
        x[[3]] <- gbRd.get_args(rdo, a)

        tags <- tools:::RdTags(x)
        keep_tags <- c("\\title","\\name", "\\arguments")
        x[which(!(tags %in% keep_tags))] <-  NULL

        temp <- tools::Rd2txt(x, out=tempfile("Rtxt"), package="",
                              outputEncoding = "UTF-8")

        res <- readLines(temp) # note: temp is a (temporary) file name.
        unlink(temp)

        # Omit \\title and sec header
        res <- res[-c(1, 2, 3, 4)]

        res <- paste(res, collapse="\\N")
        res <- sub("\\\\N$", "", res)
        res <- paste0("\x08", res)
        argl[[a]] <- res
    }
    argl
}

###############################################################################


nvim.primitive.args <- function(x)
{
    fun <- get(x)
    f <- capture.output(args(x))
    f <- sub(") $", "", sub("^function \\(", "", f[1]))
    f <- strsplit(f, ",")[[1]]
    f <- sub("^ ", "", f)
    f <- sub(" = ", "\x07", f)
    paste(f, collapse = "\x09")
}

# Adapted from: https://stat.ethz.ch/pipermail/ess-help/2011-March/006791.html
nvim.args <- function(funcname, txt, pkg = NULL, objclass, firstLibArg = FALSE, extrainfo = FALSE)
{
    # First argument of either library() or require():
    if(firstLibArg){
        p <- dir(.libPaths())
        p <- p[grep(paste0("^", txt), p)]
        return(paste(p,
                     sapply(p, function(x) packageDescription(x)$Title),
                     sep = "\x07", collapse = "\x09"))
    }

    frm <- NA
    funcmeth <- NA
    if(!missing(objclass) && nvim.grepl("[[:punct:]]", funcname) == FALSE){
        mlen <- try(length(methods(funcname)), silent = TRUE)
        if(class(mlen) == "integer" && mlen > 0){
            for(i in 1:length(objclass)){
                funcmeth <- paste(funcname, ".", objclass[i], sep = "")
                if(existsFunction(funcmeth)){
                    funcname <- funcmeth
                    frm <- formals(funcmeth)
                    break
                }
            }
        }
    }

    if(is.null(pkg))
        pkgname <- find(funcname, mode = "function")
    else
        pkgname <- pkg

    if(is.na(frm[1])){
        if(is.null(pkg)){
            deffun <- paste(funcname, ".default", sep = "")
            if (existsFunction(deffun) && pkgname[1] != ".GlobalEnv") {
                funcname <- deffun
                funcmeth <- deffun
            } else if(!existsFunction(funcname)) {
                return("NOT_EXISTS")
            }
            if(is.primitive(get(funcname)))
                return(nvim.primitive.args(funcname))
            else
                frm <- formals(get(funcname, envir = globalenv()))
        } else {
            idx <- grep(paste0(":", pkg, "$"), search())
            if(length(idx)){
                ff <- "NULL"
                tr <- try(ff <- get(paste(funcname, ".default", sep = ""), pos = idx), silent = TRUE)
                if(class(tr)[1] == "try-error")
                    ff <- get(funcname, pos = idx)
                frm <- formals(ff)
            } else {
                if(!isNamespaceLoaded(pkg))
                    loadNamespace(pkg)
                ff <- getAnywhere(funcname)
                idx <- grep(pkg, ff$where)
                if(length(idx))
                    frm <- formals(ff$objs[[idx]])
            }
        }
    }

    if(pkgname[1] == ".GlobalEnv")
        extrainfo <- FALSE

    if(extrainfo && length(frm) > 0)
        arglist <- gbRd.args2txt(funcname, names(frm))

    res <- NULL
    for(field in names(frm)){
        type <- typeof(frm[[field]])
        info <- ""
        if(extrainfo)
            info <- arglist[[field]]
        if (type == 'symbol') {
            res <- append(res, paste('\x09', field, info, sep = ''))
        } else if (type == 'character') {
            res <- append(res, paste('\x09', field, '\x07"', gsub("\n", "\\\\n", frm[[field]]), '"', info, sep = ''))
        } else if (type == 'logical' || type == 'double' || type == 'integer') {
            res <- append(res, paste('\x09', field, '\x07', as.character(frm[[field]]), info, sep = ''))
        } else if (type == 'NULL') {
            res <- append(res, paste('\x09', field, '\x07', 'NULL', info, sep = ''))
        } else if (type == 'language') {
            res <- append(res, paste('\x09', field, '\x07', deparse(frm[[field]]), info, sep = ''))
        } else {
            warning(paste0("nvim.args: typeof = ", type))
        }
    }
    idx <- grep(paste("^\x09", txt, sep = ""), res)
    res <- res[idx]
    res <- paste(res, sep = '', collapse='')
    res <- sub("^\x09", "", res)

    if(length(res) == 0 || res == ""){
        res <- "NO_ARGS"
    } else {
        if(is.null(pkg)){
            info <- ""
            if(length(pkgname) > 1)
                info <- pkgname[1]
            if(!is.na(funcmeth)){
                if(info != "")
                    info <- paste(info, ", ", sep = "")
                info <- paste(info, "function:", funcmeth, "()", sep = "")
            }
            if(info != "")
                res <- paste(res, "\x04", info, sep = "")
        }
    }

    return(res)
}


nvim.list.args <- function(ff){
    mm <- try(methods(ff), silent = TRUE)
    if(class(mm) == "MethodsFunction" && length(mm) > 0){
        for(i in 1:length(mm)){
            if(exists(mm[i])){
                cat(ff, "[method ", mm[i], "]:\n", sep="")
                print(args(mm[i]))
                cat("\n")
            }
        }
        return(invisible(NULL))
    }
    print(args(ff))
}


nvim.plot <- function(x)
{
    xname <- deparse(substitute(x))
    if(length(grep("numeric", class(x))) > 0 || length(grep("integer", class(x))) > 0){
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

nvim.names <- function(x)
{
    if(isS4(x))
        slotNames(x)
    else
        names(x)
}

nvim.getclass <- function(x)
{
    if(getOption("nvimcom.verbose") < 3){
        saved.warn <- getOption("warn")
        options(warn = -1)
        on.exit(options(warn = saved.warn))
        tr <- try(obj <- eval(expression(x)), silent = TRUE)
    } else {
        tr <- try(obj <- eval(expression(x)))
    }
    if(class(tr)[1] == "try-error"){
        return("Error evaluating the object")
    } else {
        return(class(obj)[1])
    }
}
