# nvimcom

This is the development version of the R package *nvimcom*, which creates a
server on R to allow the communication with either
[Neovim](https://github.com/neovim/neovim) or [Vim](http://www.vim.org) through the
[Nvim-R](https://github.com/jalvesaq/Nvim-R) plugin. The package is necessary
to update the highlighting of the names of R functions, open R documentation
in editor's buffer, run the Object Browser, run either `Sweave()` or `knit()`
on the document being edited. It also has some functions called by editor such
as `nvim.plot()`, `nvim.print()`, and `nvim.bol()`. This last one is required
to build the data base used in omnicompletion. The nvimcom code necessary to
automatically update both the Object Browser and the list of functions for
syntax highlight calls non-API entry points and cannot be on CRAN.

## How to install

### Development version

You need to install the development version of nvimcom if you are using the
development version of Nvim-R. In this case, the easiest way to install
nvimcom is to use the
[devtools](http://cran.r-project.org/web/packages/devtools/index.html)
package.

```s
devtools::install_github("jalvesaq/nvimcom")
```

To manually download and install nvimcom, do the following in a terminal
emulator:

```sh
git clone https://github.com/jalvesaq/nvimcom.git
R CMD INSTALL nvimcom
```

### Released version

You can also download a released version and install it as in the example
below:

```r
install.packages("nvimcom_0.9-8.tar.gz", type = "source", repos = NULL)
```

**Note**: On Windows, you need
[Rtools](http://cran.r-project.org/bin/windows/Rtools/) (and, perhaps, either
[MiKTeX](http://miktex.org/) or [TexLive](http://www.tug.org/texlive/))
installed and in your path (see [qfin](http://statmath.wu.ac.at/software/R/qfin/)
and [Rwinpack](http://www.biostat.wisc.edu/~kbroman/Rintro/Rwinpack.html) for
further instructions).

If you are using Windows and cannot build the package yourself, you may want
to try the binary package built on R-3.2.2 (md5sum
84c9b32e3c707e65d5eaa4a06b50570a):

```r
detach("package:nvimcom", unload = TRUE)
install.packages("nvimcom_0.9-8.zip", type = "win.binary", repos = NULL)
```
