# Nvim-R

This is the development code of Nvim-R which improves Vim's support to edit
R scripts.

## Installation

If you use a plugin manager, follow its instructions on how to install plugins
from GitHub. Users of [lazy.nvim](https://github.com/folke/lazy.nvim) who
opted for `defaults.lazy=true` have to configure Nvim-R with `lazy=false`.

The `stable` branch is a copy of the last released version plus minor bug
fixes eventually found after the release.

James Eapen maintains an online version of the plugin's
[documentation](https://github.com/jamespeapen/Nvim-R/wiki).
Please, read the section
[Installation](https://github.com/jamespeapen/Nvim-R/wiki/Installation)
for details.

## Usage

Please read the plugin's
[documentation](https://github.com/jamespeapen/Nvim-R/wiki) for instructions on
[usage](https://github.com/jamespeapen/Nvim-R/wiki/Use).



## Screenshots

The animated GIF below shows R running in a Neovim terminal buffer. We can note:

   1. The editor has some code to load Afrobarometer data on Mozambique, R is
      running below the editor and the Object Browser is on the right side. On
      the R Console, we can see messages inform some packages were loaded. The
      messages are in magenta because they were colorized by the package
      [colorout].

   2. When the command `library("foreign")` is sent to R, the string *read.spss*
      turns blue because it is immediately recognized as a loaded function
      (the Vim color scheme used is [southernlights]).

   3. When Mozambique's `data.frame` is created, it is automatically displayed
      in the Object Browser. Messages about unrecognized types are in magenta
      because they were sent to *stderr*, and the line *Warning messages* is in
      red because colorout recognized it as a warning.

   4. When the "label" attributes are applied to the `data.frame` elements, the
      labels show up in the Object Browser.

   5. The next images show results of omni completion.

   6. The last slide shows the output of `summary`.

![Nvim-R screenshots](https://raw.githubusercontent.com/jalvesaq/Nvim-R/master/Nvim-R.gif "Nvim-R screenshots")

## The communication between R and either Vim or Neovim

The diagram below shows how the communication between Vim/Neovim and R works.
![Neovim-R communication](https://raw.githubusercontent.com/jalvesaq/Nvim-R/master/nvimrcom.png "Neovim-R communication")

The black arrow represents all commands that you trigger in the editor and
that you can see being pasted into R Console.
There are three different ways of sending the commands to R Console:

  - When running R in a Neovim built-in terminal, the function `chansend()`
    is used to send code to R Console.

  - When running R in an external terminal emulator, Tmux is used to send
    commands to R Console.

  - On the Windows operating system, Nvim-R can send a message to R (nvimcom)
    which forwards the command to R Console.

The R package *nvimcom* includes the application *nvimrserver* which is never
used by R itself, but is run as a Vim/Neovim's job. That is, the communication
between the *nvimrserver* and Vim/Neovim is through the *nvimrserver* standard
input and output (green arrows). The *nvimrserver* application runs a TCP
server. When *nvimcom* is loaded, it immediately starts a TCP client that
connects to *nvimrserver* (red arrows).

Some commands that you trigger are not pasted into R Console and do not output
anything in R Console; their results are seen in the editor itself. These are
the commands to do omnicompletion (of names of objects and function
arguments), start and manipulate the Object Browser (`\ro`, `\r=` and `\r-`),
call R help (`\rh` or `:Rhelp`), insert the output of an R command
(`:Rinsert`) and format selected text (`:Rformat`).

When new objects are created or new libraries are loaded, nvimcom sends
messages that tell the editor to update the Object Browser, update the syntax
highlight to include newly loaded libraries and open the PDF output after
knitting an Rnoweb file and compiling the LaTeX result. Most of the
information is transmitted through the TCP connection to the *nvimrserver*,
but temporary files are used in a few cases.


## See also:

   - [cmp-nvim-r](https://github.com/jalvesaq/cmp-nvim-r): [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source using Nvim-R as backend.

   - [languageserver](https://cran.r-project.org/web/packages/languageserver/index.html): a language server for R.

   - [colorout](https://github.com/jalvesaq/colorout): a package to colorize R's output.

   - [R-Vim-runtime](https://github.com/jalvesaq/R-Vim-runtime): development version of some Vim runtime files for R,
     including `ftplugin/quarto.vim` and `syntax/quarto.vim`.

[vim-plug]: https://github.com/junegunn/vim-plug
[Neovim]: https://github.com/neovim/neovim
[southernlights]: https://github.com/jalvesaq/southernlights
[colorout]: https://github.com/jalvesaq/colorout
