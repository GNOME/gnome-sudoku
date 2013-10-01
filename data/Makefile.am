SUBDIRS = icons

gsettings_in_file = org.gnome.gnome-sudoku.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
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
	$(gsettings_in_file) \
	$(man_MANS)

CLEANFILES = \
	$(desktop_DATA) \
	$(gsettings_SCHEMAS)

DISTCLEANFILES = \
	$(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
