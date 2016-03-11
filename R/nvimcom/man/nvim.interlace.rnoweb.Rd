\name{nvim.interlace.rnoweb}
\alias{nvim.interlace.rnoweb}
\title{Run either Sweave or knit and, then, pdflatex on a Rnoweb file}
\description{
  Run the R function Sweave() or knit() and, then, the application pdflatex.
}
\usage{
nvim.interlace.rnoweb(rnowebfile, rnwdir, latexcmd,
                     latexmk = TRUE, synctex = TRUE,
                     bibtex = FALSE, knit = TRUE,
                     buildpdf = TRUE, view = TRUE, ...)
}
\arguments{
  \item{rnowebfile}{The Rnoweb file to be processed.}
  \item{rnwdir}{The directory of the Rnoweb file.}
  \item{latexcmd}{The command to run on the generated .tex file.}
  \item{latexmk}{Whether to run latexmk.}
  \item{synctex}{Whether to compile the PDF with support to SyncTeX.}
  \item{bibtex}{Whether to run bibtex.}
  \item{knit}{Whether to use knitr instead of Sweave.}
  \item{buildpdf}{Whether to compile the PDF.}
  \item{view}{Logical value indicating whether to show the generated PDF document.}
  \item{\dots}{Further arguments to be passed to \code{Sweave}.}
}
