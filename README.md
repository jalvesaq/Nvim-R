### Nvim-R

This is the development code of Nvim-R which improves Neovim's support to edit
R code (it does not support Vim). It started as a copy of the
[Vim-R-plugin](https://github.com/jcfaria/Vim-R-plugin).

## Installation

If you use a plugin manager, such as [vim-plug], [Vundle] or [Pathogen],
follow its instructions on how to install plugins from github.
To use this version, you will also need the development version of
[nvimcom].

To install a stable version of the plugin, download the Vimball file
`Nvim-R.vmb` from
[Nvim-R/releases](https://github.com/jalvesaq/Nvim-R/releases),
open it with `nvim` and do:</p>

```
:so %
```

Then, press the space bar a few time to ensure the installation of all
files. You also have to install the R package [nvimcom].

Please, read the plugin's documentation for instructions on usage.

Below is a sample `init.vim`:

```vim
syntax on
filetype plugin indent on

"------------------------------------
" Behavior
"------------------------------------
let maplocalleader = ","
let mapleader = ";"

"------------------------------------
" Appearance
"------------------------------------
" www.vim.org/scripts/script.php?script_id=3292
colorscheme southernlights

"------------------------------------
" Search
"------------------------------------
set infercase
set hlsearch
set incsearch

"------------------------------------
" Nvim-R
"------------------------------------
if has("gui_running")
    inoremap <C-Space> <C-x><C-o>
else
    inoremap <Nul> <C-x><C-o>
endif
vmap <Space> <Plug>RDSendSelection
nmap <Space> <Plug>RDSendLine
```

Please, read the file *doc/Nvim-R.txt* for usage details.

## Screenshots

The animated GIF below shows R running in a Neovim terminal buffer. We can note:

   1. The editor has some code to load Afrobarometer data on Mozambique, R is
      running below the editor and the Object Browser is on the right side. On
      the R Console, we can see messages inform the packages [setwidth] and
      [nvimcom] were loaded. The messages are in blue because they were
      colorized by the package [colorout].

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

![Nvim-R screenshot](https://dadoseteorias.files.wordpress.com/2016/01/nvim-r.gif "Nvim-R screenshot")

## The communication between Neovim and R

The Diagram below shows the three paths of communication between
Neovim and R:

  - The black path is followed by all commands that you trigger in the
    editor and that you can see being pasted into R Console. There are
    three different ways of sending the commands to R Console:

     - When running R in a Neovim built-in terminal, the function
       `jobsend()` is used to send code to R Console.

     - When running R in an external terminal emulator, Tmux is
         used to send commands to R Console.

     - On Windows operating system, the nvimclient application
         uses the Windows API to copy the text into the clipboard and
         then paste it into the R Console.

  - The blue path is followed by the few commands that you trigger, but that
    are not pasted into R Console and do not output anything in R Console;
    their results are seen in the editor itself. These are the commands to
    do omnicompletion (of names of objects and function arguments), start
    and manipulate the Object Browser (`\ro`, `\r=` and `\r-`), call R help
    (`\rh` or `:Rhelp`), insert the output of an R command (`:Rinsert`) and
    format selected text (`:Rformat`).

  - The red path is followed by R messages that tell the editor to
    update the Object Browser, update the syntax highlight to include
    newly loaded libraries and open the PDF output after weaving an Rnoweb
    file and compiling the LaTeX result.


![Neovim-R communication](https://dadoseteorias.files.wordpress.com/2016/01/nvimrcom.png "Neovim-R communication")

[vim-plug]: https://github.com/junegunn/vim-plug
[Vundle]: https://github.com/gmarik/Vundle.vim
[Pathogen]: https://github.com/tpope/vim-pathogen
[Neovim]: https://github.com/neovim/neovim
[nvimcom]: https://github.com/jalvesaq/nvimcom
[setwidth]: https://cran.r-project.org/web/packages/setwidth/index.html
[southernlights]: https://github.com/jalvesaq/southernlights
[colorout]: https://github.com/jalvesaq/colorout
