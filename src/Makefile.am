bin_PROGRAMS = gnome-sudoku

BUILT_SOURCES = gnome-sudoku-resources.c

gnome_sudoku_SOURCES = \
	config.vapi \
	gnome-sudoku.vala \
	sudoku-board.vala \
	sudoku-game.vala \
	sudoku-generator.vala \
	sudoku-store.vala \
	sudoku-solver.vala \
	sudoku-view.vala \
	number-picker.vala \
	sudoku-printer.vala \
	sudoku-saver.vala \
	$(BUILT_SOURCES)

gnome_sudoku_CFLAGS = \
	-DPKGDATADIR=\"@datadir@/gnome-sudoku\" \
	-DLOCALEDIR=\"@localedir@\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-w \
	$(GNOME_SUDOKU_CFLAGS)

gnome_sudoku_LDADD = \
	$(GNOME_SUDOKU_LIBS) \
	-lm

gnome_sudoku_VALAFLAGS = \
	--pkg posix \
	--pkg gio-2.0 \
	--pkg gtk+-3.0 \
	--pkg gee-0.8 \
	--pkg json-glib-1.0

gnome-sudoku-resources.c: gnome-sudoku.gresource.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies gnome-sudoku.gresource.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(srcdir) --generate-source $<

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

DISTCLEANFILES = gnome-sudoku.gresource.xml

-include $(top_srcdir)/git.mk
