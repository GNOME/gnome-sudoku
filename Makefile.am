SUBDIRS =  data glade images help src

# Source files
EXTRA_DIST =
CLEAN_DIST =
CLEANFILES =

EXTRA_DIST += intltool-extract.in intltool-merge.in intltool-update.in
DISTCLEANFILES = intltool-extract intltool-merge intltool-update

#################################################################
# Launcher
@INTLTOOL_DESKTOP_RULE@

desktopdir = $(datadir)/applications
desktop_in_files = gnome-sudoku.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
EXTRA_DIST += $(desktop_in_files)
CLEANFILES += $(desktop_DATA)

#################################################################

## Executable
bin_SCRIPTS = src/gnome-sudoku
EXTRA_DIST += src/gnome-sudoku
