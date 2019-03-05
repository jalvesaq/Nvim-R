\name{NvimR.source}
\alias{NvimR.source}
\alias{NvimR.selection}
\alias{NvimR.paragraph}
\alias{NvimR.function}
\alias{NvimR.chunk}
\alias{NvimR.block}
\title{Wrapper to base::source}
\description{
  Call base::source with the arguments print.eval=TRUE and spaced=FALSE.
}
\usage{
  NvimR.source(..., print.eval = TRUE, spaced = FALSE)
  NvimR.selection(..., local = parent.frame())
  NvimR.paragraph(..., local = parent.frame())
  NvimR.function(..., local = parent.frame())
  NvimR.chunk(..., local = parent.frame())
  NvimR.block(..., local = parent.frame())
}
\arguments{
  \item{print.eval}{See base::source.}
  \item{spaced}{See base::source.}
  \item{local}{See base::source.}
  \item{...}{Further arguments passed to base::source.}
}
