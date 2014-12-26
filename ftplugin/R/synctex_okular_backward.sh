#!/bin/sh

# This script is required to do backward search from Okular to Neovim

echo "call SyncTeX_backward('$1', $2)" >> "$NVIMR_TMPDIR/okular_search"

