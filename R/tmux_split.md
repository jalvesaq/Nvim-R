# Integration with Tmux

Before Neovim's built-in terminal emulator was developed, the best way of
running R was inside a Tmux session, and as an alternative to running R in a
Tmux split pane, you could try the Tilix terminal emulator, and put in your
`vimrc`:

```vim
let R_in_buffer = 0
let R_term_cmd = 'tilix -a session-add-right -e'
```

Anyway, it is still possible to run R in a Tmux split pane, as explained in
this section, but I no longer use this feature and it is no longer supported.
This means that I will not add new features to tmux-split and will not test if
it still works after changes are introduced in other parts of the plugin.
However, I may fix simple bugs if they are reported, and I will drop the
integration in the future only if it becomes too buggy.

If someone wants to maintain the code, then, the steps are:

  - Create a new repository.

  - Copy both tmux_split.vim and tmux_split.md (renamed as README.md) to the
    new repository.

  - Tell me the link to the repository, so I can add the link to the "R_source"
    section of the Nvim-R documentation.

Currently, if you do want to try it, you should either use this development
version of Nvim-R or download `tmux_split.vim` from
<https://raw.githubusercontent.com/jalvesaq/Nvim-R/master/R/tmux_split.vim>
and, then, put in your `vimrc`:

```vim
let R_source = '/path/to/tmux_split.vim'
```


Then, start Tmux before starting Vim:

```sh
tmux
vim filename.R
exit
```

In this case, when you start R, the terminal window is split into two regions:
one for Vim and the other for Tmux. Then, it's useful to know some Tmux
commands. After you finished editing the file, you have to type `exit` to quit
the Tmux session.

**Note:** the old way of enabling Tmux split by setting the value of
`R_tmux_split` no longer works.

## Tmux configuration

You have to create your `~/.tmux.conf` if it does not exist yet. You may put
the lines below in your `~/.tmux.conf` as a starting point to your own
configuration file:

```tmux.conf
# Use <C-a> instead of the default <C-b> as Tmux prefix
set-option -g prefix C-a
unbind-key C-b
bind-key C-a send-prefix

# Options to enable mouse support in Tmux
set -g terminal-overrides 'xterm*:smcup@:rmcup@'
# For Tmux < 2.1
set -g mode-mouse on
set -g mouse-select-pane on
set -g mouse-resize-pane on
# For Tmux >= 2.1
set -g mouse on

# Escape time for libtermkey
# (see https://github.com/neovim/neovim/issues/2035):
set -sg escape-time 10

# Act more like vi:
set-window-option -g mode-keys vi
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
unbind p
bind p paste-buffer
bind -t vi-copy v begin-selection
bind -t vi-copy y copy-selection

# If environment variables that you need are not becoming available for R,
# export them in your ~/.bashrc and uncomment and edit this line:
# set -g update-environment "R_LIBS_USER R_LIBS R_PAPERSIZE"
```

Tmux automatically renames window titles to the command currently running.
Nvim-R sets the title of the window where Vim and R are running to "NvimR".
This title will be visible only if Tmux status bar is "on", and it is useful
only if you have created new windows with the
<kbd>Ctrl</kbd>+<kbd>a</kbd>+<kbd>c</kbd> command. You can change the value of
R_tmux_title to either set a different title or let Tmux set the title
automatically. Examples:

```vim
let R_tmux_title = 'Nvim-R'
let R_tmux_title = 'automatic'
```

When R quits, Tmux will automatically close its pane. If you want that the
pane remains open, see <https://github.com/jalvesaq/Nvim-R/issues/229>


## Key bindings and mouse support

The Tmux configuration file suggested above configures Tmux to use vi key
bindings. It also configures Tmux to react to mouse clicks. You should be able
to switch the active pane by clicking on an inactive pane, to resize the panes
by clicking on the border line and dragging it, and to scroll the R Console
with the mouse wheel. When you use the mouse wheel, Tmux enters in its
copy/scroll back mode (see below).

The configuration script also sets <kbd>Ctrl</kbd>+<kbd>a</kbd> as the Tmux
escape character (the default is <kbd>Ctrl</kbd>+<kbd>b</kbd>), that is, you have
to type <kbd>Ctrl</kbd>+<kbd>a</kbd> before typing a Tmux command. Below are the
most useful key bindings for Tmux with the tmux.conf shown above:

- <kbd>Ctrl</kbd>+<kbd>a</kbd>arrow keys: Move the cursor to the Tmux panel
  above, below, at the right or at the left of the current one.

- <kbd>Ctrl</kbd>+<kbd>a</kbd>+<kbd>Ctrl</kbd>+<kbd>Up</kbd>: Move the panel
  division upward one line, that is, resize the panels. Repeat
  <kbd>Ctrl</kbd>+<kbd>Up</kbd> to move more. <kbd>Ctrl</kbd>+<kbd>Down</kbd>
  will move the division downward one line. If you are using the vertical
  split, you should use <kbd>Ctrl</kbd>+<kbd>Left</kbd> and
  <kbd>Ctrl</kbd>+<kbd>Right</kbd> to resize the panels.

- <kbd>Ctrl</kbd>+<kbd>a</kbd>+<kbd>[</kbd>:Enter the copy/scroll back mode.
  You can use <kbd>PgUp</kbd>, <kbd>PgDown</kbd> and vi key bindings to move
  the cursor around the panel. Press q to quit copy mode.

- <kbd>Ctrl</kbd>+<kbd>a</kbd>+<kbd>]</kbd>: Paste the content of Tmux paste
  buffer.

- <kbd>Ctrl</kbd>+<kbd>a</kbd>+<kbd>z</kbd>: Hide/show all panes except the
  current one. Note: If you mistakenly press
  <kbd>Ctrl</kbd>+<kbd>a</kbd>+<kbd>Ctrl</kbd>+<kbd>z</kbd>, you have to type
  `fg` to get Tmux back to the foreground.

While in the copy and scroll back mode, the following key bindings are useful:

- <kbd>q</kbd>: Quit the copy and scroll mode.

- <kbd>Space</kbd>: Start text selection.

- <kbd>v</kbd>+<kbd>Space</kbd>: Start rectangular text selection.

- <kbd>Enter</kbd>: Copy the selection to Tmux paste buffer.

Please, read the manual page of Tmux if you want to change the Tmux
configuration and learn more commands. To read the Tmux manual, type in the
terminal emulator:

```sh
man tmux
```

Note: Because <kbd>Ctrl</kbd>+<kbd>a</kbd> was configured as the Tmux escape
character, it will not be passed to applications running under Tmux. To send
<kbd>Ctrl</kbd>+<kbd>a</kbd> to either R or Vim you have to type
<kbd>Ctrl</kbd>+<kbd>a</kbd>+<kbd>Ctrl</kbd>+<kbd>a</kbd>.


## Copying and pasting

You do not need to copy code from Vim to R because you can use the plugin's
shortcuts to send the code. For pasting the output of R commands into Vim's
buffer, you can use the command `:Rinsert`. If you want to copy text from an
application running inside the Tmux to another application also running in
Tmux, as explained in the previous subsection, you can enter Tmux copy/scroll
mode, select the text, copy it, switch to the other application pane and,
then, paste.

However, if you want to copy something from either Vim or R to another
application not running inside Tmux, Tmux may prevent the X server from
capturing the text selected by the mouse. This can be prevented by pressing
the <kbd>Shift</kbd> key, as it suspends the capturing of mouse events by
tmux. If you keep <kbd>Shift</kbd> pressed while selecting text with the
mouse, it will be available in the X server clipboard and can be inserted into
other windows using the middle mouse button. It can also be inserted into a
tmux window using <kbd>Shift</kbd> and the middle mouse button.
