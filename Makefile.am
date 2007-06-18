SUBDIRS =  data glade images help src

#################################################################
# Launcher
@INTLTOOL_DESKTOP_RULE@

desktopdir = $(datadir)/applications
desktop_in_files = gnome-sudoku.desktop.in.in
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)

CLEANFILES = $(desktop_DATA)
