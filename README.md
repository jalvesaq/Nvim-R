### Nvim-R

This is the development code of Nvim-R which improves Vim's support to edit
R code. It started as a copy of the
[Vim-R-plugin](https://github.com/jcfaria/Vim-R-plugin) adapted to Neovim, but
now also supports Vim.

The R package *nvimcom* is included in the source code and is automatically
installed and updated whenever necessary. The Nvim-R plugin sets the
environment variable `R_DEFAULT_PACKAGES`, including `nvimcom` in the list of
packages to be loaded on R startup.

## Installation

If you use a plugin manager, such as [vim-plug], [Vundle] or [Pathogen],
follow its instructions on how to install plugins from github.

To install a stable version of the plugin, either download the Vim package from
[Nvim-R/releases](https://github.com/jalvesaq/Nvim-R/releases)
or the Vimball from
[vim.org](http://www.vim.org/scripts/script.php?script_id=2628).

Please, read the section *Installation* from the
[plugin's documentation](https://raw.githubusercontent.com/jalvesaq/Nvim-R/master/doc/Nvim-R.txt)
for details.

Please, read the plugin's documentation for instructions on usage.


## Screenshots

The animated GIF below shows R running in a Neovim terminal buffer. We can note:

   1. The editor has some code to load Afrobarometer data on Mozambique, R is
      running below the editor and the Object Browser is on the right side. On
      the R Console, we can see messages inform some packages were loaded. The
      messages are in blue because they were colorized by the package
      [colorout].

   2. When the command `library("foreign")` is sent to R, the string *read.spss*
      turns blue because it is immediately recognized as a loaded function
      (the Vim color scheme used is [southernlights]).

   3. When Mozambique's data.frame is created, it is automatically displayed
      in the Object Browser. Messages about unrecognized types are in blue
      because they were sent to *stderr*, and the line *Warning messages* is in
      red because colorout recognized it as a warning.

   4. When the "label" attributes are applied to the data.frame elements, the
      labels show up in the Object Browser.

   5. The last slide shows the output of `summary`. It also features omni
      completion in action: we can see the elements of *m* that start with "D".

![Nvim-R screenshots](https://raw.githubusercontent.com/jalvesaq/Nvim-R/master/Nvim-R.gif "Nvim-R screenshots")

## The communication between R and either Vim or Neovim

In addition to sending lines of code to R Console, Nvim-R and R communicate
with each other through TCP connections. The R package *nvimcom* runs a TCP
server that receives messages from either Vim/Neovim, and it also sends messages through
a TCP connection to Vim/Neovim. Moreover, *nvimcom* includes the application
*nclientserver* which is never used by R itself, but is run by Vim/Neovim,
providing both a TCP client and a TCP server. The Diagram below shows the
three paths of communication between Vim/Neovim and R:

  - The black path is followed by all commands that you trigger in the editor
    and that you can see being pasted into R Console. There are three
    different ways of sending the commands to R Console:

     - When running R in a Neovim built-in terminal, the function `jobsend()`
       is used to send code to R Console.

     - When running R in an external terminal emulator, Tmux is used to send
       commands to R Console.

     - On Windows operating system, Nvim-R sends a message to R (nvimcom)
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
    libraries and open the PDF output after weaving an Rnoweb file and
    compiling the LaTeX result.


![Neovim-R communication](https://raw.githubusercontent.com/jalvesaq/Nvim-R/master/nvimrcom.png "Neovim-R communication")

[vim-plug]: https://github.com/junegunn/vim-plug
[Vundle]: https://github.com/gmarik/Vundle.vim
[Pathogen]: https://github.com/tpope/vim-pathogen
[Neovim]: https://github.com/neovim/neovim
[southernlights]: https://github.com/jalvesaq/southernlights
[colorout]: https://github.com/jalvesaq/colorout
