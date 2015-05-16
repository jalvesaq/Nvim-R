#!/bin/sh

# This script is required to do backward search from Okular to Neovim because
# there is no command line argument to configure Okular's backward search.

nvimclient $NVIMR_PORT $NVIMR_SECRET"call SyncTeX_backward('$1', $2)"
