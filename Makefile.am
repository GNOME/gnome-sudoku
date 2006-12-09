SUBDIRS =  data glade images help src

#################################################################
# Launcher
@INTLTOOL_DESKTOP_RULE@

desktopdir = $(datadir)/applications
desktop_in_files = gnome-sudoku.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
EXTRA_DIST = $(desktop_in_files)
CLEANFILES = $(desktop_DATA)
