### Nvim-R

This is the development code of Nvim-R which improves Vim's support to edit
R code.

## Installation

If you use a plugin manager, follow its instructions on how to install plugins
from github.

To install the stable version of the plugin, if using [vim-plug], put this in
your `vimrc`/`init.vim`:

```
Plug 'jalvesaq/Nvim-R', {'branch': 'stable'}
```

The `stable` branch is a copy of the last released version plus minor bug
fixes eventually found after the release. I plan to keep the stable branch
compatible with Ubuntu LTS releases, and the master branch compatible with
Ubuntu normal releases. If you need an older version, you could try either the
`oldstable` branch or one of the
[tagged versions](https://github.com/jalvesaq/Nvim-R/tags).

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

   3. When Mozambique's data.frame is created, it is automatically displayed
      in the Object Browser. Messages about unrecognized types are in magenta
      because they were sent to *stderr*, and the line *Warning messages* is in
      red because colorout recognized it as a warning.

   4. When the "label" attributes are applied to the data.frame elements, the
      labels show up in the Object Browser.

   5. The next images show results of omni completion.

   6. The last slide shows the output of `summary`.

![Nvim-R screenshots](https://raw.githubusercontent.com/jalvesaq/Nvim-R/master/Nvim-R.gif "Nvim-R screenshots")

## The communication between R and either Vim or Neovim

In addition to sending lines of code to R Console, Nvim-R and R communicate
with each other through TCP connections. The R package *nvimcom* runs a TCP
server that receives messages from Vim/Neovim, and it also sends messages
through a TCP connection to Vim/Neovim. Moreover, *nvimcom* includes the
application *nclientserver* which is never used by R itself, but is run by
Vim/Neovim, providing both a TCP client and a TCP server. The Diagram below
shows the three paths of communication between Vim/Neovim and R:

  - The black path is followed by all commands that you trigger in the editor
    and that you can see being pasted into R Console. There are three
    different ways of sending the commands to R Console:

     - When running R in a Neovim built-in terminal, the function `chansend()`
       is used to send code to R Console.

     - When running R in an external terminal emulator, Tmux is used to send
       commands to R Console.

     - On Windows operating system, Nvim-R can send a message to R (nvimcom)
       which forwards the command to R Console.

  - The blue path is followed by the few commands that you trigger, but that
    are not pasted into R Console and do not output anything in R Console;
    their results are seen in the editor itself. These are the commands to do
    omnicompletion (of names of objects and function arguments), start and
    manipulate the Object Browser (`\ro`, `\r=` and `\r-`), call R help (`\rh`
    or `:Rhelp`), insert the output of an R command (`:Rinsert`) and format
    selected text (`:Rformat`).

  - The red path is followed by R messages that tell the editor to update the
    Object Browser, update the syntax highlight to include newly loaded
    libraries and open the PDF output after knitting an Rnoweb file and
    compiling the LaTeX result.


![Neovim-R communication](https://raw.githubusercontent.com/jalvesaq/Nvim-R/master/nvimrcom.png "Neovim-R communication")

[vim-plug]: https://github.com/junegunn/vim-plug
[Neovim]: https://github.com/neovim/neovim
[southernlights]: https://github.com/jalvesaq/southernlights
[colorout]: https://github.com/jalvesaq/colorout
