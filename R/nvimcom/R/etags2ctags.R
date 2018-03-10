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
### Sat, July 17, 2010

# Note: Emacs TAGS file can be read by Vim if the feature
# +emacs_tags was enabled while compiling Vim. If your Vim does
# not have this feature, you can try the function below:

# Function to convert from Emacs' TAGS file into Vim's tags file.
# See http://en.wikipedia.org/wiki/Ctags on the web and ":help
# ctags" in Vim for details on the two file formats.
# Note: This function only works with a tags file created by the R
# function rtags().
# Arguments:
#   etagsfile = character string with path to original TAGS
#   ctagsfile = character string with path to destination tags
# Example:
#   setwd("/path/to/R-2.11.1/src/library/base/R")
#   rtags(ofile = "TAGS")
#   etags2ctags("TAGS", "tags")
# After the above commands you should be able to jump from on file
# to another with Vim by hitting CTRL-] over function names.
etags2ctags <- function(etagsfile, ctagsfile){
    elines <- readLines(etagsfile)
    filelen <- length(elines)
    nfread <- sum(elines == "\x0c")
    nnames <- filelen - (2 * nfread)
    clines <- vector(mode = "character", length = nnames)
    i <- 1
    k <- 1
    while (i < filelen) {
        if(elines[i] == "\x0c"){
            i <- i + 1
            curfile <- sub(",.*", "", elines[i])
            i <- i + 1
            curflines <- readLines(curfile)
            while(elines[i] != "\x0c" && i <= filelen){
                curname <- sub(".\x7f(.*)\x01.*", "\\1", elines[i])
                curlnum <- as.numeric(sub(".*\x01(.*),.*", "\\1", elines[i]))
                curaddr <- curflines[as.numeric(curlnum)]
                curaddr <- gsub("\\\\", "\\\\\\\\", curaddr)
                curaddr <- gsub("\t", "\\\\t", curaddr)
                curaddr <- gsub("/", "\\\\/", curaddr)
                curaddr <- paste("/^", curaddr, "$/;\"", sep = "")
                clines[k] <- paste(curname, curfile, curaddr, sep = "\t")
                i <- i + 1
                k <- k + 1
            }
        } else {
            stop("Error while trying to interpret line ", i,
                 " of '", etagsfile, "'.\n")
        }
    }
    curcollate <- Sys.getlocale(category = "LC_COLLATE")
    invisible(Sys.setlocale(category = "LC_COLLATE", locale = "C"))
    clines <- sort(clines)
    invisible(Sys.setlocale(category = "LC_COLLATE", locale = curcollate))
    writeLines(clines, ctagsfile)
}
