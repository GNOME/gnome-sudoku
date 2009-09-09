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

install-schemas-local: $(schema_DATA)
if GCONF_SCHEMAS_INSTALL
	if test -z "$(DESTDIR)" ; then \
		for p in $^ ; do \
			GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $$p 2>&1 > /dev/null; \
		done \
	fi
endif

install-data-local: install-schemas-local

man_MANS = gnome-sudoku.6

EXTRA_DIST = \
	$(puzzle_DATA)	\
	$(ui_DATA)	\
	$(schema_in_files) \
	$(man_MANS)

CLEANFILES = \
	$(schema_DATA)

DISTCLEANFILES = \
	$(schema_DATA)

@INTLTOOL_SCHEMAS_RULE@
