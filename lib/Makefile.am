noinst_LTLIBRARIES = libsudoku.la

libsudoku_la_SOURCES = \
	sudoku-board.vala \
	sudoku-game.vala \
	sudoku-saver.vala

libsudoku_la_CFLAGS = -w

libsudoku_la_CPPFLAGS = \
	-DPKGDATADIR=\"$(datadir)/gnome-sudoku\" \
	-DLOCALEDIR=\"$(localedir)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	$(LIBSUDOKU_CFLAGS)

libsudoku_la_LIBADD = \
	$(LIBSUDOKU_LIBS)

libsudoku_la_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg json-glib-1.0 \
	--pkg posix \
	--header=libsudoku.h \
	--vapi=libsudoku.vapi

EXTRA_DIST = \
	libsudoku.h \
	libsudoku.vapi

MAINTAINERCLEANFILES = \
	libsudoku.h \
	libsudoku.vapi

-include $(top_srcdir)/git.mk
