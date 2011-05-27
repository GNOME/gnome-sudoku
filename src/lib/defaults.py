# -*- coding: utf-8 -*-
#
# defaults.py.in sets many important default global variables
# used throughout the game. Note that this file is processed by
# automake to set prefix paths etc. Please keep defaults.py.in
# in sync between glchess and gnome-sudoku. 

import os
import sys
import errno
import locale
import gettext

from gi.repository import GLib

try:
    from defs import VERSION, PREFIX
except ImportError:
    PREFIX = "/usr"
    VERSION = "0.0.0"

root_dir = os.path.dirname(os.path.dirname(__file__))
if not os.path.exists(os.path.join(root_dir, "Makefile.am")):
    # Running in installed mode
    APP_DATA_DIR    = os.path.join(PREFIX, 'share')
    BASE_DIR        = os.path.join(APP_DATA_DIR, 'gnome-sudoku')
    IMAGE_DIR       = os.path.join(BASE_DIR, 'images')
    LOCALEDIR       = os.path.join(APP_DATA_DIR, 'locale')
    UI_DIR          = BASE_DIR
    PUZZLE_DIR      = os.path.join(BASE_DIR, 'puzzles')
else:
    # Running in uninstalled mode
    sys.path.insert(0, os.path.abspath(root_dir))
    APP_DATA_DIR    = os.path.join(root_dir, '../data') 
    IMAGE_DIR       = os.path.join(root_dir, '../images')
    LOCALEDIR       = os.path.join(APP_DATA_DIR, 'locale')
    UI_DIR          = os.path.join(root_dir, '../data')
    BASE_DIR        = os.path.join(root_dir, '../data')
    PUZZLE_DIR      = BASE_DIR

DOMAIN = 'gnome-games'
locale.bind_textdomain_codeset(DOMAIN, "UTF-8") # See Bug 608425
gettext.bindtextdomain(DOMAIN, LOCALEDIR)
gettext.textdomain(DOMAIN)
from gettext import gettext as _

APPNAME             = _("GNOME Sudoku")
APPNAME_SHORT       = _("Sudoku")
COPYRIGHT           = 'Copyright \xc2\xa9 2005-2008, Thomas M. Hinkle'
DESCRIPTION         = _('GNOME Sudoku is a simple Sudoku generator and player. Sudoku is a Japanese logic puzzle.\n\nGNOME Sudoku is a part of GNOME Games.')
AUTHORS             = ("Thomas M. Hinkle","John Stowers")
WEBSITE             = 'http://www.gnome.org/projects/gnome-games/'
WEBSITE_LABEL       = _('GNOME Games web site')
AUTO_SAVE           = True
MIN_NEW_PUZZLES     = 90

DATA_DIR = os.path.join(GLib.get_user_config_dir(),"gnome-sudoku/")

