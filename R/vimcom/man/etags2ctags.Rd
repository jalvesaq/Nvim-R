\name{etags2ctags}
\alias{etags2ctags}
\title{
Convert an Emacs tags file into the CTags file format.
}
\description{
Convert an Emacs tags file into the CTags file format.
}
\usage{
etags2ctags(etagsfile, ctagsfile)
}
\arguments{
  \item{etagsfile}{Path to Emacs tags file.}
  \item{ctagsfile}{Path to the CTags file to be created.}
}
\author{Jakson Alves de Aquino <jalvesaq@gmail.com>}
\examples{
\dontrun{
rtags(path = "/path/to/R/source/code", recursive = TRUE, ofile = "RTAGS")
etags2ctags("RTAGS", "Rtags")
}
}
