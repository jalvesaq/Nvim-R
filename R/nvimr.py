""" Functions for communication with Nvim-R """
import sys

def nvimr_cmd(cmd):
    """ Nvim-R executes the output of jobs """
    sys.stdout.write(cmd)
    sys.stdout.flush()

def nvimr_warn(wrn):
    """ Nvim-R echoes as warning messages the output sent by jobs to stderr """
    sys.stderr.write(wrn)
    sys.stderr.flush()
