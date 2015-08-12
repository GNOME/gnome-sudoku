bin_PROGRAMS = gnome-sudoku

BUILT_SOURCES = gnome-sudoku-resources.c

gnome_sudoku_SOURCES = \
	config.vapi \
	gnome-sudoku.vala \
	print-dialog.vala \
	sudoku-view.vala \
	number-picker.vala \
	sudoku-printer.vala \
	$(BUILT_SOURCES)

# Force linking with a C++ linker.
nodist_EXTRA_gnome_sudoku_SOURCES = dummy.cxx

gnome_sudoku_CFLAGS = -w

gnome_sudoku_CPPFLAGS = \
	-DPKGDATADIR=\"$(datadir)/gnome-sudoku\" \
	-DLOCALEDIR=\"$(localedir)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-I$(top_srcdir)/lib \
	-I$(top_builddir)/lib \
	$(GNOME_SUDOKU_CFLAGS)

gnome_sudoku_LDADD = \
	$(GNOME_SUDOKU_LIBS) \
	$(top_builddir)/lib/libsudoku.la

gnome_sudoku_VALAFLAGS = \
	--pkg posix \
	--pkg gio-2.0 \
	--pkg gtk+-3.0 \
	--pkg gee-0.8 \
	--target-glib=$(GLIB_REQUIRED) \
	--gresources=$(abs_top_srcdir)/data/gnome-sudoku.gresource.xml \
	$(abs_top_srcdir)/lib/libsudoku.vapi

gnome-sudoku-resources.c: $(top_srcdir)/data/gnome-sudoku.gresource.xml $(shell $(GLIB_COMPILE_RESOURCES) --sourcedir=$(top_srcdir)/data --generate-dependencies $(top_srcdir)/data/gnome-sudoku.gresource.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(top_srcdir)/data --generate-source $<

CLEANFILES = \
	gnome-sudoku-resources.c

-include $(top_srcdir)/git.mk
