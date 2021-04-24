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
### Tue, January 18, 2011

# This function writes two files: one with the names of all functions in all
# packages (either loaded or installed); the other file lists all objects,
# including function arguments. These files are used by Vim to highlight
# functions and to complete the names of objects and the arguments of
# functions.

nvim.grepl <- function(pattern, x) {
    res <- grep(pattern, x)
    if(length(res) == 0){
        return(FALSE)
    } else {
        return(TRUE)
    }
}

nvim.getInfo <- function(printenv, x)
{
    info <- "\006\006"
    als <- NvimcomEnv$pkgdescr[[printenv]]$alias[NvimcomEnv$pkgdescr[[printenv]]$alias[, "name"] == x, "alias"]
    try(info <- NvimcomEnv$pkgdescr[[printenv]]$descr[[als]], silent = TRUE)
    return(info)
}

nvim.omni.line <- function(x, envir, printenv, curlevel, maxlevel = 0) {
    if(curlevel == 0){
        xx <- try(get(x, envir), silent = TRUE)
        if(inherits(xx, "try-error"))
            return(invisible(NULL))
    } else {
        x.clean <- gsub("$", "", x, fixed = TRUE)
        x.clean <- gsub("_", "", x.clean, fixed = TRUE)
        haspunct <- nvim.grepl("[[:punct:]]", x.clean)
        if(haspunct[1]){
            ok <- nvim.grepl("[[:alnum:]]\\.[[:alnum:]]", x.clean)
            if(ok[1]){
                haspunct  <- FALSE
                haspp <- nvim.grepl("[[:punct:]][[:punct:]]", x.clean)
                if(haspp[1]) haspunct <- TRUE
            }
        }

        # No support for names with spaces
        if(nvim.grepl(" ", x)){
            haspunct <- TRUE
        }

        if(haspunct[1]){
            xx <- NULL
        } else {
            xx <- try(eval(parse(text=x)), silent = TRUE)
            if(class(xx)[1] == "try-error"){
                xx <- NULL
            }
        }
    }

    if(is.null(xx)){
        x.class <- ""
        x.group <- "*"
    } else {
        if(x == "break" || x == "next" || x == "for" || x == "if" || x == "repeat" || x == "while"){
            x.group <- ";"
            x.class <- "flow-control"
        } else {
            x.class <- class(xx)[1]
            if(is.function(xx)) x.group <- "f"
            else if(is.numeric(xx)) x.group <- "{"
            else if(is.factor(xx)) x.group <- "!"
            else if(is.character(xx)) x.group <- "~"
            else if(is.logical(xx)) x.group <- "%"
            else if(is.data.frame(xx)) x.group <- "$"
            else if(is.list(xx)) x.group <- "["
            else if(is.environment(xx)) x.group <- ":"
            else x.group <- "*"
        }
    }

    if(curlevel == maxlevel || maxlevel == 0){
        if(x.group == "f"){
            if(curlevel == 0){
                if(nvim.grepl("GlobalEnv", printenv)){
                    cat(x, "\006\003\006\006", printenv, "\006",
                        nvim.args(x), "\n", sep = "")
                } else {
                    info <- nvim.getInfo(printenv, x)
                    cat(x, "\006\003\006\006", printenv, "\006",
                        nvim.args(x, pkg = printenv), info, "\006\n", sep = "")
                }
            } else {
                # some libraries have functions as list elements
                cat(x, "\006\003\006\006", printenv, "\006Unknown arguments\006\006\006\n", sep="")
            }
        } else {
            if(is.list(xx) || is.environment(xx)){
                if(curlevel == 0){
                    info <- nvim.getInfo(printenv, x)
                    if(is.data.frame(xx))
                        cat(x, "\006", x.group, "\006", x.class, "\006", printenv, "\006[", nrow(xx), ", ", ncol(xx), "]", info, "\006\n", sep="")
                    else if(is.list(xx))
                        cat(x, "\006", x.group, "\006", x.class, "\006", printenv, "\006", length(xx), info, "\006\n", sep="")
                    else
                        cat(x, "\006", x.group, "\006", x.class, "\006", printenv, "\006[]", info, "\006\n", sep="")
                } else {
                    cat(x, "\006", x.group, "\006", x.class, "\006", printenv, "\006[]\006\006\006\n", sep="")
                }
            } else {
                info <- nvim.getInfo(printenv, x)
                if(info == "\006\006"){
                    xattr <- try(attr(xx, "label"), silent = TRUE)
                    if(!inherits(xattr, "try-error"))
                        info <- paste0("\006\006", CleanOmniLine(xattr))
                }
                cat(x, "\006", x.group, "\006", x.class, "\006", printenv, "\006[]", info, "\006\n", sep="")
            }
        }
    }

    if((is.list(xx) || is.environment(xx)) && curlevel <= maxlevel){
        obj.names <- names(xx)
        curlevel <- curlevel + 1
        xxl <- length(xx)
        if(!is.null(xxl) && xxl > 0){
            for(k in obj.names){
                nvim.omni.line(paste(x, "$", k, sep=""), envir, printenv, curlevel, maxlevel)
            }
        }
    } else if(isS4(xx) && curlevel <= maxlevel){
        obj.names <- slotNames(xx)
        curlevel <- curlevel + 1
        xxl <- length(xx)
        if(!is.null(xxl) && xxl > 0){
            for(k in obj.names){
                nvim.omni.line(paste(x, "@", k, sep=""), envir, printenv, curlevel, maxlevel)
            }
        }
    }
}

# NOTE: This function takes only about 15% of the time to build an omnls_
# file, but it would be better to rewrite it in C to fix a bug affecting
# nested commands such as \strong{aaa \href{www}{www}} because the current
# code finds the next brace and not the matching brace. However, this cannot
# be a priority because the bug affects only about 0.01% of all omnils_ lines).
CleanOmniLine <- function(x)
{
    if(length(x) == 0)
        return(x)
    x <- gsub("\n", " ", x)
    x <- gsub("  *", " ", x)
    if(!NvimcomEnv$isAscii){
        # Only the symbols found in a sample of omnls_ files
        x <- gsub("\\\\Sigma\\b", "\u03a3", x)
        x <- gsub("\\\\alpha\\b", "\u03b1", x)
        x <- gsub("\\\\beta\\b", "\u03b2", x)
        x <- gsub("\\\\gamma\\b", "\u03b3", x)
        x <- gsub("\\\\eta\\b", "\u03b7", x)
        x <- gsub("\\\\mu\\b", "\u03bc", x)
        x <- gsub("\\\\omega\\b", "\u03bf", x)
        x <- gsub("\\\\phi\\b", "\u03c6", x)
        x <- gsub("\\\\le\\b", "\u2264", x)
        x <- gsub("\\\\ge\\b", "\u2265", x)
        x <- gsub("\\\\sqrt\\{(.*?)\\}", "\u221a\\1", x)
    }
    x <- gsub("\\\\R\\b", "R", x)
    x <- gsub("\\\\link\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\email\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\link\\[.+?\\]\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\code\\{(.+?)\\}", "\u2018\\1\u2019", x)
    x <- gsub("\\\\samp\\{(.+?)\\}", "\u2018\\1\u2019", x)
    x <- gsub("\\\\acronym\\{(.*?)\\}", "\\1", x)
    x <- gsub("\\\\option\\{(.*?)\\}", "\\1", x)
    x <- gsub("\\\\env\\{(.*?)\\}", "\\1", x)
    x <- gsub("\\\\var\\{(.*?)\\}", "\\1", x)
    x <- gsub("\\\\strong\\{(.*?)\\}", "\\1", x)
    x <- gsub("\\\\special\\{(.*?)\\}", "\\1", x)
    x <- gsub("\\\\file\\{(.+?)\\}", "\u2018\\1\u2019", x)
    x <- gsub("\\\\sQuote\\{(.+?)\\}", "\u2018\\1\u2019", x)
    x <- gsub("\\\\dQuote\\{(.+?)\\}", "\u201c\\1\u201d", x)
    x <- gsub("\\\\emph\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\bold\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\pkg\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\eqn\\{.+?\\}\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\eqn\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\deqn\\{(.*?)\\}\\{(.*?)\\}", "\\2", x)
    x <- gsub("\\\\cite\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\url\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\linkS4class\\{(.+?)\\}", "\\1", x)
    x <- gsub("\\\\command\\{(.+?)\\}", "`\\1`", x)
    x <- gsub("\\\\href\\{(.+?)\\}\\{(.+?)\\}", "\u2018\\2\u2019 <\\1>", x)
    x <- gsub("\\\\ldots", "...", x)
    x <- gsub("\\\\dots", "...", x)
    x <- gsub("\\\\preformatted\\{(.+?)\\}", " \\1 ", x)
    x <- gsub("\\\\verb\\{(.*?)\\}", "\\1", x)
    x <- gsub("\\\\out\\{(.*?)\\}", "\\1", x)
    x <- gsub("\\\\if\\{html\\}\\{.+?\\}", "", x)
    x <- gsub("\\\\ifelse\\{\\{latex\\}\\{.*?\\}\\{(.*?)\\}\\}", "\\1", x)
    x <- gsub("\\\\ifelse\\{\\{html\\}\\{.*?\\}\\{(.*?)\\}\\}", "\\1", x)
    x <- gsub("\\\\figure\\{.*?\\}\\{(.*?)\\}", "\\1", x)
    x <- gsub("\\\\figure\\{(.*?)\\}", "\\1", x)
    x <- gsub("\\\\tabular\\{.*?\\}\\{(.*?)\\}", "\\1\002", x)
    x <- gsub("\\\\tab ", "\t", x)
    x <- gsub("\\\\item\\{(.+?)\\}", "\002\\1", x)
    x <- gsub("\\\\item ", "\002\\\\item ", x)
    x <- gsub("\\\\item ", " \u2022 ", x)
    x <- gsub("\\\\itemize\\{(.+?)\\}", "\\1\002", x)
    x <- gsub("\\\\cr\\b", "\002", x)
    if(grepl("\\\\describe\\{", x)){
        x <- sub("\\\\describe\\{(.*)}", "\\1", x)
        x <- sub("\\\\describe\\{(.*)}", "\\1", x)
    }
    if(NvimcomEnv$isAscii){
        x <- gsub("\u2018", "\004", x)
        x <- gsub("\u2019", "\004", x)
        x <- gsub("\u201c", '"', x)
        x <- gsub("\u201d", '"', x)
        x <- gsub("\u2022", '-', x)
    }
    x <- gsub("'", "\004", x)
    x
}


# Code adapted from the gbRd package
GetFunDescription <- function(pkg)
{
    pth <- attr(packageDescription(pkg), "file")
    pth <- sub("Meta/package.rds", "", pth)
    pth <- paste0(pth, "help/")
    idx <- paste0(pth, "AnIndex")

    # Development packages might not have any written documentation yet
    if(!file.exists(idx) || !file.info(idx)$size)
        return(NULL)

    tab <- read.table(idx, sep = "\t", comment.char = "", quote = "", stringsAsFactors = FALSE)
    als <- tab$V2
    names(als) <- tab$V1
    als <- list("name" = names(als), "alias" = unname(als))
    als$name <- lapply(als$name, function(x) strsplit(x, ",")[[1]])
    for(i in 1:length(als$alias))
        als$name[[i]] <- cbind(als$alias[[i]], als$name[[i]])
    als <- do.call("rbind", als$name)
    if(nrow(als) > 1){
        als <- als[complete.cases(als), ]
        als <- als[!duplicated(als[, 2]), ]
    }
    colnames(als) <- c("alias", "name")

    if(!file.exists(paste0(pth, pkg, ".rdx")))
        return(NULL)
    pkgInfo <- tools:::fetchRdDB(paste0(pth, pkg))

    GetDescr <- function(x)
    {
        x <- paste0(x, collapse = "")
        x <- sub("\\\\usage\\{.*", "", x)
        x <- sub("\\\\details\\{.*", "", x)
        x <- CleanOmniLine(x)
        ttl <- sub(".*\\\\title\\{(.*?)\\}.*", "\\1", x)
        x <- sub(".*\\\\description\\{", "", x)

        # Get the matching bracket
        xc <- charToRaw(x)
        k <- 1
        i <- 1
        l <- length(xc)
        while(i <= l)
        {
            if(xc[i] == 123){
                k <- k + 1
            }
            if(xc[i] == 125){
                k <- k - 1
            }
            if(k == 0){
                x <- rawToChar(xc[1:i-1])
                break
            }
            i <- i + 1
        }

        x <- sub("^\\s*", "", sub("\\s*$", "", x))
        x <- gsub("\n\\s*", " ", x)
        x <- paste0("\006", ttl, "\006", x)
        x
    }
    NvimcomEnv$pkgdescr[[pkg]] <- list("descr" = sapply(pkgInfo, GetDescr),
                                       "alias" = als)
}

# Build Omni List
nvim.bol <- function(omnilist, packlist, allnames = FALSE) {
    nvim.OutDec <- getOption("OutDec")
    on.exit(options(nvim.OutDec))
    options(OutDec = ".")

    if(!missing(packlist) && is.null(NvimcomEnv$pkgdescr[[packlist]]))
        GetFunDescription(packlist)

    if(getOption("nvimcom.verbose") > 3)
        cat("Building files with lists of objects in loaded packages for",
            "omni completion and Object Browser...\n")

    loadpack <- search()
    if(missing(packlist))
        listpack <- loadpack[grep("^package:", loadpack)]
    else
        listpack <- paste0("package:", packlist)

    needunload <- FALSE
    for(curpack in listpack){
        curlib <- sub("^package:", "", curpack)
        if(nvim.grepl(curlib, loadpack) == FALSE){
            cat("Loading   '", curlib, "'...\n", sep = "")
            needunload <- try(require(curlib, character.only = TRUE))
            if(needunload != TRUE){
                needunload <- FALSE
                next
            }
        }

        # Save title of package in pack_descriptions:
        if(file.exists(paste0(Sys.getenv("NVIMR_COMPLDIR"), "/pack_descriptions")))
            pack_descriptions <- readLines(paste0(Sys.getenv("NVIMR_COMPLDIR"),
                                                  "/pack_descriptions"))
        else
            pack_descriptions <- character()
        pack_descriptions <- c(paste(curlib,
                           gsub("[\t\n\r ]+", " ", packageDescription(curlib)$Title),
                           gsub("[\t\n\r ]+", " ", packageDescription(curlib)$Description),
                           sep = "\t"), pack_descriptions)
        pack_descriptions <- sort(pack_descriptions[!duplicated(pack_descriptions)])
        writeLines(pack_descriptions,
                   paste0(Sys.getenv("NVIMR_COMPLDIR"), "/pack_descriptions"))

        obj.list <- objects(curpack, all.names = allnames)
        l <- length(obj.list)
        if(l > 0){
            sink(omnilist, append = FALSE)
            for(obj in obj.list){
                ol <- try(nvim.omni.line(obj, curpack, curlib, 0))
                if(inherits(ol, "try-error"))
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
            if(curlib == "base"){
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
            if(length(fl) > 0){
                fl <- paste("syn keyword rFunction", fl)
                writeLines(text = fl, con = sub("omnils_", "fun_", omnilist))
            } else {
                writeLines(text = '" No functions found.', con = sub("omnils_", "fun_", omnilist))
            }
        } else {
            writeLines(text = '', con = omnilist)
            writeLines(text = '" No functions found.', con = sub("omnils_", "fun_", omnilist))
        }
        if(needunload){
            cat("Detaching '", curlib, "'...\n", sep = "")
            try(detach(curpack, unload = TRUE, character.only = TRUE), silent = TRUE)
            needunload <- FALSE
        }
    }
    writeLines(text = "Finished",
               con = paste0(Sys.getenv("NVIMR_TMPDIR"), "/nvimbol_finished"))
    return(invisible(NULL))
}

nvim.buildomnils <- function(p){
    pvi <- utils::packageDescription(p)$Version
    bdir <- paste0(Sys.getenv("NVIMR_COMPLDIR"), "/")
    odir <- dir(bdir)
    pbuilt <- odir[grep(paste0("omnils_", p, "_"), odir)]
    fbuilt <- odir[grep(paste0("fun_", p, "_"), odir)]

    # This option might not have been set if R is running remotely
    if(is.null(getOption("nvimcom.verbose")))
        options(nvimcom.verbose = 0)

    if(length(pbuilt) > 0){
        pvb <- sub(".*_.*_", "", pbuilt)
        if(pvb == pvi){
            if(file.info(paste0(bdir, "/README"))$mtime > file.info(paste0(bdir, pbuilt))$mtime){
                unlink(c(paste0(bdir, pbuilt), paste0(bdir, fbuilt)))
                nvim.bol(paste0(bdir, "omnils_", p, "_", pvi), p, TRUE)
                if(getOption("nvimcom.verbose") > 3)
                    cat("nvimcom R: omnils is older than the README\n")
            } else{
                if(getOption("nvimcom.verbose") > 3)
                    cat("nvimcom R: omnils version is up to date:", p, pvi, "\n")
            }
        } else {
            if(getOption("nvimcom.verbose") > 3)
                cat("nvimcom R: omnils is outdated: ", p, " (", pvb, " x ", pvi, ")\n", sep = "")
            unlink(c(paste0(bdir, pbuilt), paste0(bdir, fbuilt)))
            nvim.bol(paste0(bdir, "omnils_", p, "_", pvi), p, TRUE)
        }
    } else {
        if(getOption("nvimcom.verbose") > 3)
            cat("nvimcom R: omnils does not exist:", p, "\n")
        nvim.bol(paste0(bdir, "omnils_", p, "_", pvi), p, TRUE)
    }
}
