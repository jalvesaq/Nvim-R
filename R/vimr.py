""" Functions for communication with Vim-R """
import sys

def vimr_cmd(cmd):
    """ Vim-R executes the output of jobs """
    sys.stdout.write(cmd)
    sys.stdout.flush()

def vimr_warn(wrn):
    """ Vim-R echoes as warning messages the output sent by jobs to stderr """
    sys.stderr.write(wrn)
    sys.stderr.flush()
