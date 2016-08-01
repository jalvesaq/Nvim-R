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
nvim.args <- function(funcname, txt, pkg = NULL, objclass, firstLibArg = FALSE)
{
    # First argument of either library() or require():
    if(firstLibArg){
        p <- dir(.libPaths())
        p <- p[grep(paste0("^", txt), p)]
        return(paste0(p, collapse = "\x09"))
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

    if(is.na(frm[1])){
        if(is.null(pkg)){
            deffun <- paste(funcname, ".default", sep = "")
            if (existsFunction(deffun)) {
                funcname <- deffun
                funcmeth <- deffun
            } else if(!existsFunction(funcname)) {
                return("NOT_EXISTS")
            }
            if(is.primitive(get(funcname)))
                return(nvim.primitive.args(funcname))
            else
                frm <- formals(funcname)
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

    res <- NULL
    for (field in names(frm)) {
        type <- typeof(frm[[field]])
        if (type == 'symbol') {
            res <- append(res, paste('\x09', field, sep = ''))
        } else if (type == 'character') {
            res <- append(res, paste('\x09', field, '\x07"', frm[[field]], '"', sep = ''))
        } else if (type == 'logical') {
            res <- append(res, paste('\x09', field, '\x07', as.character(frm[[field]]), sep = ''))
        } else if (type == 'double') {
            res <- append(res, paste('\x09', field, '\x07', as.character(frm[[field]]), sep = ''))
        } else if (type == 'NULL') {
            res <- append(res, paste('\x09', field, '\x07', 'NULL', sep = ''))
        } else if (type == 'language') {
            res <- append(res, paste('\x09', field, '\x07', deparse(frm[[field]]), sep = ''))
        }
    }
    idx <- grep(paste("^\x09", txt, sep = ""), res)
    res <- res[idx]
    res <- paste(res, sep = '', collapse='')
    res <- sub("^\x09", "", res)
    res <- gsub("\n", "\\\\n", res)

    if(length(res) == 0 || res == ""){
        res <- "NO_ARGS"
    } else {
        if(is.null(pkg)){
            info <- ""
            pkgname <- find(funcname, mode = "function")
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
