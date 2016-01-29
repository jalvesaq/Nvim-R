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

[vim-plug]: https://github.com/junegunn/vim-plug
[Vundle]: https://github.com/gmarik/Vundle.vim
[Pathogen]: https://github.com/tpope/vim-pathogen
[Neovim]: https://github.com/neovim/neovim
[nvimcom]: https://github.com/jalvesaq/nvimcom
