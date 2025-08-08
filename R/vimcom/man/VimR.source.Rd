\name{VimR.source}
\alias{VimR.source}
\alias{VimR.selection}
\alias{VimR.paragraph}
\alias{VimR.function}
\alias{VimR.chunk}
\alias{VimR.block}
\title{Wrapper to base::source}
\description{
  Call base::source with the arguments \code{print.eval=TRUE} and
  \code{spaced=FALSE}.
}
\usage{
  VimR.source(..., print.eval = TRUE, spaced = FALSE)
  VimR.selection(..., local = parent.frame())
  VimR.paragraph(..., local = parent.frame())
  VimR.function(..., local = parent.frame())
  VimR.chunk(..., local = parent.frame())
  VimR.block(..., local = parent.frame())
}
\arguments{
  \item{print.eval}{See base::source.}
  \item{spaced}{See base::source.}
  \item{local}{See base::source.}
  \item{...}{Further arguments passed to base::source.}
}
