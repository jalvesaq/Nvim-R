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
  NvimR.selection(...)
  NvimR.paragraph(...)
  NvimR.function(...)
  NvimR.chunk(...)
  NvimR.block(...)
}
\arguments{
  \item{print.eval}{See base::source.}
  \item{spaced}{See base::source.}
  \item{...}{Further arguments passed to base::source.}
}
