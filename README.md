### Nvim-R

This is the development code of Nvim-R.
Stable versions of this plugin are released at
[http://www.lepem.ufc.br/jaa/NvimR.html](http://www.lepem.ufc.br/jaa/NvimR.html).

If you use a plugin manager, such as [vim-plug], [Vundle] or [Pathogen],
follow its instructions on how to install plugins from github.
The plugin manager will set the value of 'runtimepath' for you, and you can
check it with the following command:

```vim
:set runtimepath?
```

If you do not use a plugin manager, you should clone this directory wherever
you want and manually adjust [Neovim]'s **runtimepath** in your
**~/.config/nvim/init.vim** as in the example below:

    set runtimepath=~/Nvim-R,~/.config/nvim,$VIMRUNTIME,~/.config/nvim/after

To use this version, you will also need the development version of
[nvimcom].

Please, read the file *doc/Nvim-R.txt* for usage details.

[vim-plug]: https://github.com/junegunn/vim-plug
[Vundle]: https://github.com/gmarik/Vundle.vim
[Pathogen]: https://github.com/tpope/vim-pathogen
[Neovim]: https://github.com/neovim/neovim
[nvimcom]: https://github.com/jalvesaq/nvimcom
