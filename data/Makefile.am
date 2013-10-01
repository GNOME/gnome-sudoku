SUBDIRS = icons

gsettings_SCHEMAS = org.gnome.gnome-sudoku.gschema.xml
@GSETTINGS_RULES@

desktopdir = $(datadir)/applications
desktop_in_files = gnome-sudoku.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_DATA = gnome-sudoku.appdata.xml

pixmapdir = $(datadir)/gnome-sudoku/images/
pixmap_DATA = footprints.png

puzzledir = $(datadir)/gnome-sudoku/puzzles/
puzzle_DATA = \
	easy \
	medium \
	hard \
	very_hard

uidir = $(datadir)/gnome-sudoku
ui_DATA = \
	print_games.ui \
	select_game.ui \
	tracker.ui

man_MANS = gnome-sudoku.6

EXTRA_DIST = \
	$(pixmap_DATA)	\
	$(desktop_in_files) \
	$(appdata_DATA)	\
	$(puzzle_DATA)	\
	$(ui_DATA)	\
	$(gsettings_SCHEMAS) \
	$(man_MANS)

CLEANFILES = \
	$(desktop_DATA)

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
