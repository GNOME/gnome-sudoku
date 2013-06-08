bin_PROGRAMS = gnome-sudoku

BUILT_SOURCES = gnome-sudoku-resources.c

gnome_sudoku_SOURCES = \
	config.vapi \
	main.vala \
	gnome-sudoku.vala \
	sudoku-board.vala \
	sudoku-game.vala \
	sudoku-generator.vala \
	sudoku-store.vala \
	sudoku-solver.vala \
	logical-sudoku-solver.vala \
	sudoku-view.vala \
	number-picker.vala \
	$(BUILT_SOURCES)

gnome_sudoku_CFLAGS = \
	-DPKGDATADIR=\"@datadir@/gnome-sudoku\" \
	-DLOCALEDIR=\"@localedir@\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	$(GNOME_SUDOKU_CFLAGS)

gnome_sudoku_LDADD = \
	$(GNOME_SUDOKU_LIBS)

gnome_sudoku_VALAFLAGS = \
	--pkg posix \
	--pkg gio-2.0 \
	--pkg gtk+-3.0 \
	--pkg gee-1.0

gnome-sudoku-resources.c: gnome-sudoku.gresource.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies gnome-sudoku.gresource.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(srcdir) --generate-source $<

EXTRA_DIST = \
	gnome_sudoku.gresource.xml

DISTCLEANFILES = \
	Makefile.in
