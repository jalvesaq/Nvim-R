\name{nvim.print}
\alias{nvim.print}
\title{
  Print an object.
}
\description{
  Print an object. If the object is a function, search for a method for the
  \code{classfor} expression. The function is supposed to be called by Nvim-R.
}
\usage{
nvim.print(object, objclass)
}
\arguments{
  \item{object}{An R object.}
  \item{objclass}{The class of the R object following the parenthesis, if any.}
}
