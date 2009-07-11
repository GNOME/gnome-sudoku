puzzledir = $(datadir)/gnome-sudoku/puzzles/
puzzle_DATA = \
	easy \
	medium \
	hard \
	very_hard

uidir = $(datadir)/gnome-sudoku
ui_DATA = \
	print_games.ui \
	puzzle_generator.ui \
	select_game.ui \
	tracker.ui

schema_in_files = gnome-sudoku.schemas.in
if HAVE_GNOME
schemadir = $(GCONF_SCHEMA_FILE_DIR)
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
endif

@INTLTOOL_SCHEMAS_RULE@	

EXTRA_DIST = $(puzzle_DATA) $(ui_DATA)

