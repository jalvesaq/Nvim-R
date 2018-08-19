\name{nvim.interlace.rnoweb}
\alias{nvim.interlace.rnoweb}
\title{Run either Sweave or knit and, then, pdflatex on a Rnoweb file}
\description{
  Run the R function Sweave() or knit() and, then, the application pdflatex.
}
\usage{
nvim.interlace.rnoweb(rnwf, rnwdir, latexcmd = "latexmk",
                      latexargs,
                      synctex = TRUE, bibtex = FALSE,  knit = TRUE,
                      buildpdf = TRUE, view = TRUE, builddir, ...)
}
\arguments{
  \item{rnwf}{The Rnoweb file to be processed.}
  \item{rnwdir}{The directory of the Rnoweb file.}
  \item{latexcmd}{The command to run on the generated .tex file.}
  \item{latexargs}{Arguments to pass to the LaTeX command.}
  \item{synctex}{Whether to compile the PDF with support to SyncTeX.}
  \item{bibtex}{Whether to run bibtex.}
  \item{knit}{Whether to use knitr instead of Sweave.}
  \item{buildpdf}{Whether to compile the PDF.}
  \item{view}{Logical value indicating whether to show the generated PDF document.}
  \item{builddir}{Directory where latexmk will output files.}
  \item{\dots}{Further arguments to be passed to \code{Sweave}.}
}
