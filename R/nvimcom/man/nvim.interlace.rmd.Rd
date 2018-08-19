\name{nvim.interlace.rmd}
\alias{nvim.interlace.rmd}
\title{Convert a rmd file to PDF}
\description{
  Run the \pkg{knitr} function \code{knit()} to convert a rmd file to
  PDF.
}
\usage{
nvim.interlace.rmd(Rmdfile, outform = NULL, rmddir, ...)
}
\arguments{
  \item{Rmdfile}{The Rmd file to be processed.}
  \item{outform}{R Markdown output format to convert to.}
  \item{rmddir}{The directory of the Rnoweb file.}
  \item{\dots}{Further arguments to be passed to \code{render()}.}
}
