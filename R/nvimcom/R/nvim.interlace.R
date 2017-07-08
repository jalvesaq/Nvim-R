SyncTeX_readconc <- function(texf, concf)
{
    texidx <- 1
    rnwidx <- 1
    ntexln <- length(readLines(texf))
    lstexln <- 1:ntexln
    lsrnwf <- lsrnwl <- rep(NA, ntexln)
    conc <- readLines(concf)
    idx <- 1
    maxidx <- length(conc) + 1
    while(idx < maxidx && texidx < ntexln && length(grep("Sconcordance", conc[idx])) > 0){
        curline <- sub("\\\\Sconcordance\\{concordance:", "", conc[idx])
        texf <- sub('([^:]*):.*', '\\1', curline)
        rnwf <- sub('[^:]*:([^:]*):.*', '\\1', curline)
        idx <- idx + 1
        concnum <- ""
        while(idx < maxidx && length(grep("Sconcordance", conc[idx])) == 0){
            concnum <- paste0(concnum, conc[idx])
            idx <- idx + 1
        }
        concnum <- gsub('%', '', concnum)
        concnum <- sub('\\}', '', concnum)
        concl <- strsplit(concnum, " ")
        concl <- as.numeric(concl[[1]])
        ii <- 1
        maxii <- length(concl) - 1
        rnwl <- concl[1]
        lsrnwl[texidx] <- rnwl
        lsrnwf[texidx] <- rnwf
        texidx <- texidx + 1
        while(ii < maxii && texidx < ntexln){
            ii <- ii + 1
            lnrange <- 1:concl[ii]
            ii <- ii + 1
            for(iii in lnrange){
                if(texidx >= ntexln)
                    break
                rnwl <- rnwl + concl[ii]
                lsrnwl[texidx] <- rnwl
                lsrnwf[texidx] <- rnwf
                texidx <- texidx + 1
            }
        }
    }
    return(data.frame(texlnum = lstexln, rnwfile = lsrnwf, rnwline = lsrnwl, stringsAsFactors = FALSE))
}

GetRnwLines <- function(texf, concf, l)
{
    conc <- SyncTeX_readconc(texf, concf)
    for(ii in 1:length(l)){
        if(length(grep("line [0-9]", l[ii])) > 0){
            texln <- as.numeric(sub(".*line ([0-9]*)", "\\1", l[ii]))
            idx <- 1
            while(idx < nrow(conc) && texln > conc$texlnum[idx]){
                idx <- idx + 1
                if(conc$texlnum[idx] >= texln){
                    l[ii] <- sub("(.*) line ([0-9]*)",
                                 paste0("\\1 line \\2 [",
                                        conc$rnwfile[idx], ": ",
                                        conc$rnwline[idx], "]"), l[ii])
                    break
                }
            }
        } else if(length(grep("lines [0-9]*--[0-9]*", l[ii])) > 0){
            texln1 <- as.numeric(sub(".*lines ([0-9]*)--.*", "\\1", l[ii]))
            texln2 <- as.numeric(sub(".*lines [0-9]*--([0-9]*).*", "\\1", l[ii]))
            rnwIdx1 <- NA
            rnwIdx2 <- NA
            idx <- 1
            while(idx < nrow(conc) && texln1 > conc$texlnum[idx]){
                idx <- idx + 1
                if(conc$texlnum[idx] >= texln1){
                    rnwIdx1 <- idx
                    break
                }
            }
            idx <- 1
            while(idx < nrow(conc) && texln2 > conc$texlnum[idx]){
                idx <- idx + 1
                if(conc$texlnum[idx] >= texln2){
                    rnwIdx2 <- idx
                    break
                }
            }
            if(!is.na(rnwIdx1) && !is.na(rnwIdx2)){
                l[ii] <- sub("(.*) lines ([0-9]*)--([0-9]*)",
                             paste0("\\1 lines \\2--\\3 [",
                                    conc$rnwfile[rnwIdx1], ": ",
                                    conc$rnwline[rnwIdx1], "--",
                                    conc$rnwline[rnwIdx2], "]"), l[ii])
            }
        }
    }
    l
}

ShowTexErrors <- function(texf, logf)
{
    if(!file.exists(logf))
        stop(paste0(logf, ' not found.'))
    l <- readLines(logf, encoding = "latin1")
    if(length(grep(sub("log$", "tex", logf), l)) == 0){ # XeLaTeX uses UTF-8
        l8 <- readLines(logf, encoding = "utf-8")
        if(length(grep(sub("log$", "tex", logf), l8)) > 0){
            l <- l8
        }
    }

    llen <- length(l)
    lf <- character(llen)
    lev <- 1
    levfile <- "Unknown" # From what tex source are the errors coming from?
    fname <- NA
    idx <- 1
    while(idx < llen){
        if(grepl("^(Over|Under)full \\\\(h|v)box ", l[idx])){
            while(l[idx] != "" && idx < llen){
                lf[idx] <- levfile[lev]
                idx <- idx + 1
            }
        } else {
            # Get the result of number of '(' minus number of ')'
            pb <- length(grep(28, charToRaw(l[idx]))) - length(grep(29, charToRaw(l[idx])))
            if(pb > 0){
                lev <- lev + pb
                fname <- sub(".*\\(", "", l[idx])
                levfile[lev] <- fname
            } else if(pb < 0){
                lev <- lev + pb
            }
        }
        lf[idx] <- levfile[lev]
        idx <- idx + 1
    }

    idx <- rep(FALSE, length(l))
    idx[grepl("^(Over|Under)full \\\\(h|v)box ", l, useBytes = TRUE)] <- TRUE
    idx[grepl("^(Package|Class) \\w+ (Error|Warning):", l, useBytes = TRUE)] <- TRUE
    idx[grepl("^LaTeX (Error|Warning):", l, useBytes = TRUE)] <- TRUE
    idx[grepl("^No pages of output", l, useBytes = TRUE)] <- TRUE
    if(sum(grepl("pdfTeX (error|warning)", l, useBytes = TRUE)) > 0)
        has.pdfTeX.errors <- TRUE
    else
        has.pdfTeX.errors <- FALSE

    if(sum(idx) > 0){
        l <- l[idx]
        lf <- lf[idx]
        concf <- sub("\\.tex$", "-concordance.tex", texf)
        # We are interested only the errors located at our master LaTeX file
        ismaster <- grep(paste0("./", texf), lf)
        if(length(ismaster) > 0 && file.exists(concf)){
            l[ismaster] <- GetRnwLines(texf, concf, l[ismaster])
        }
        msg <- paste0('\nSelected lines of "', logf, '":\n\n', paste(lf, l, sep = ": ", collapse = "\n"), "\n")
        if(has.pdfTeX.errors)
            msg <- paste0(msg, 'There are pdfTeX errors or warnings. See "', logf, '" for details.\n')
        cat(msg)
    }
}

OpenPDF <- function(fullpath)
{
    if(!file.exists(fullpath))
        stop(paste0('File "', fullpath, '" does not exist.'))
    .C("nvimcom_msg_to_nvim", paste0("ROpenPDF('", fullpath, "')"), PACKAGE="nvimcom")
    return(invisible(NULL))
}

nvim.interlace.rnoweb <- function(rnowebfile, rnwdir, latexcmd, latexmk = TRUE, synctex = TRUE, bibtex = FALSE,
                                  knit = TRUE, buildpdf = TRUE, view = TRUE, ...)
{
    oldwd <- getwd()
    on.exit(setwd(oldwd))
    setwd(rnwdir)

    Sres <- NA

    # Check whether the .tex was already compiled
    twofiles <- c(rnowebfile, sub("\\....$", ".tex", rnowebfile))
    if(sum(file.exists(twofiles)) == 2){
        fi <- file.info(twofiles)$mtime
        if(fi[1] < fi[2])
            Sres <- twofiles[2]
    }

    # Compile the .tex file
    if(is.na(Sres) || !buildpdf){
        if(knit){
            if(!require(knitr))
                stop("Please, install the 'knitr' package.")
            if(synctex)
                knitr::opts_knit$set(concordance = TRUE)
            Sres <- knit(rnowebfile, envir = globalenv())
        } else {
            Sres <- Sweave(rnowebfile, ...)
        }
    }

    if(!buildpdf)
        return(invisible(NULL))

    # Compile the .pdf
    if(exists('Sres')){
        # From RStudio: Check for spaces in path (Sweave chokes on these)
        # if(length(grep(" ", Sres)) > 0)
        #     stop(paste("Invalid filename: '", Sres, "' (TeX does not understand paths with spaces).", sep=""))
        if(missing(latexcmd)){
            if(latexmk){
                if(synctex)
                    latexcmd = 'latexmk -pdflatex="pdflatex -file-line-error -synctex=1" -pdf'
                else
                    latexcmd = 'latexmk -pdflatex="pdflatex -file-line-error" -pdf'
            } else {
                if(synctex)
                    latexcmd = "pdflatex -file-line-error -synctex=1"
                else
                    latexcmd = "pdflatex -file-line-error"
            }
        }
        try(sout <- system(paste(latexcmd, gsub(" ", "\\\\ ", Sres)), intern = TRUE))
        if(is.null(attr(sout, "status"))){
            haserror <- FALSE
        } else {
            haserror <- TRUE
        }

        if(!haserror && bibtex){
            haserror <- system(paste("bibtex", sub("\\.tex$", ".aux", Sres)))
            if(!haserror){
                haserror <- system(paste(latexcmd, Sres))
                if(!haserror)
                    haserror <- system(paste(latexcmd, Sres))
            }
        }
        if(!haserror){
            if(view){
                idx <- grep("Latexmk: All targets .* are up-to-date", sout)
                if(length(idx)){
                    pdff <- sub("Latexmk: All targets \\((.*)\\) are up-to-date", "\\1", sout[idx])
                } else {
                    idx <- grep("Output written on .*\\.pdf .*", sout)
                    if(length(idx)){
                        pdff <- sub("Output written on (.*\\.pdf) .*", "\\1", sout[idx])
                    } else {
                        pdff <- sub("\\.tex$", ".pdf", Sres)
                    }
                }
                if(!grepl("^/", pdff))
                    pdff <- paste0(getwd(), "/", pdff)
                OpenPDF(pdff)
            }
            if(getOption("nvimcom.texerrs")){
                idx <- grep("Transcript written on ", sout)
                if(length(idx)){
                    logf <- sub("Transcript written on (.*)\\.", "\\1", sout[idx])
                    logf <- gsub('"', '', logf)
                    ShowTexErrors(Sres, logf)
                }
            }
        }
    }
    return(invisible(NULL))
}

nvim.interlace.rrst <- function(Rrstfile, rrstdir, view = TRUE,
                               compiler = "rst2pdf", ...)
{
    if(!require(knitr))
        stop("Please, install the 'knitr' package.")

    oldwd <- getwd()
    on.exit(setwd(oldwd))
    setwd(rrstdir)

    knitr::knit2pdf(Rrstfile, compiler = compiler, ...)
    if (view) {
        Sys.sleep(0.2)
        pdffile = sub('\\.Rrst$', ".pdf", Rrstfile, ignore.case = TRUE)
        OpenPDF(pdffile)
    }
}

nvim.interlace.rmd <- function(Rmdfile, outform = NULL, rmddir, view = TRUE, ...)
{
    if(!require(rmarkdown))
        stop("Please, install the 'rmarkdown' package.")

    oldwd <- getwd()
    on.exit(setwd(oldwd))
    setwd(rmddir)

    if(!is.null(outform)){
        if(outform == "odt"){
            res <- rmarkdown::render(Rmdfile, "html_document", ...)
            system(paste('soffice --invisible --convert-to odt', res))
        } else {
            res <- rmarkdown::render(Rmdfile, outform, ...)
        }
    } else {
        res <- rmarkdown::render(Rmdfile, ...)
    }

    if(view){
        if(!is.null(outform) && outform == "odt")
            system(paste0("lowriter '", sub("\\.html$", ".odt'", res)))
        else
            if(regexpr("\\.html$", res) > 0)
                browseURL(res)
            else
                if(regexpr("\\.pdf", res) > 0)
                    OpenPDF(sub(".*/", "", res))
    }
}

