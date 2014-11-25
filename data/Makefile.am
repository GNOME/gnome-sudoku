SUBDIRS = icons

gsettings_SCHEMAS = org.gnome.sudoku.gschema.xml
@GSETTINGS_RULES@

desktopdir = $(datadir)/applications
desktop_in_files = gnome-sudoku.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appstream_in_files = gnome-sudoku.appdata.xml.in
appstream_XML = $(appstream_in_files:.xml.in=.xml)
@APPSTREAM_XML_RULES@
@INTLTOOL_XML_RULE@

pixmapdir = $(datadir)/gnome-sudoku/images/
pixmap_DATA = footprints.png

dist_noinst_DATA = \
	gnome-sudoku.ui \
	gnome-sudoku-menu.ui \
	print-dialog.ui \
	gnome-sudoku.css

man_MANS = gnome-sudoku.6

EXTRA_DIST = \
	$(pixmap_DATA)	\
	$(desktop_in_files) \
	$(appstream_in_files)	\
	$(gsettings_SCHEMAS) \
	$(man_MANS)

CLEANFILES = \
	$(appstream_XML) \
	$(desktop_DATA)

check-local: $(desktop_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

DISTCHECK_CONFIGURE_FLAGS = --enable-appdata-check

-include $(top_srcdir)/git.mk
