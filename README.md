# Nvim-R (superseded by R.nvim)

> [!Note]
> For Neovim users, this plugin is superseded by [R.nvim](https://github.com/R-nvim/R.nvim).

Nvim-R improves Vim's support to edit R scripts.

## Installation and use

Please, read sections _Instalation_ and _Use_ of the
[documentation](https://github.com/jalvesaq/Nvim-R/blob/master/doc/Nvim-R.txt).

## The communication between R and either Vim or Neovim

The diagram below shows how the communication between Vim/Neovim and R works.
![Neovim-R communication](https://raw.githubusercontent.com/jalvesaq/Nvim-R/master/nvimrcom.svg "Neovim-R communication")

The black arrows represent all commands that you trigger in the editor and
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

[Neovim]: https://github.com/neovim/neovim
[southernlights]: https://github.com/jalvesaq/southernlights
[colorout]: https://github.com/jalvesaq/colorout
