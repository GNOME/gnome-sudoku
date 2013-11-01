SUBDIRS = icons

gsettings_SCHEMAS = org.gnome.gnome-sudoku.gschema.xml
@GSETTINGS_RULES@

desktopdir = $(datadir)/applications
desktop_in_files = gnome-sudoku.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_in_files = gnome-sudoku.appdata.xml.in
appdata_DATA = $(appdata_in_files:.xml.in=.xml)
@INTLTOOL_XML_RULE@

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
	$(appdata_in_files)	\
	$(puzzle_DATA)	\
	$(ui_DATA)	\
	$(gsettings_SCHEMAS) \
	$(man_MANS)

CLEANFILES = \
	$(appdata_DATA) \
	$(desktop_DATA)

check-local: $(appdata_DATA) $(desktop_DATA)
if VALIDATE_APPDATA
	$(APPDATA_VALIDATE) $(appdata_DATA)
endif
if VALIDATE_DESKTOP_FILE
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)
endif

-include $(top_srcdir)/git.mk
