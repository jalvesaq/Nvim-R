#!/bin/sh

# This script is required to do backward search from both Skim and Okular to
# Neovim because there is no command line argument to configure their backward
# search.

nvimrclient $NVIMR_PORT $NVIMR_SECRET "$1" $2
