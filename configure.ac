AC_PREREQ([2.63])
AC_INIT([GNOME Sudoku], [3.16.0], [https://bugzilla.gnome.org/],
        [gnome-sudoku], [https://wiki.gnome.org/Apps/Sudoku])
AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE([enable])
GNOME_MAINTAINER_MODE_DEFINES

AC_PROG_CC
AC_PROG_CXX

AM_PROG_VALAC([0.25.1])
AM_PROG_CC_C_O

LT_PREREQ([2.4])
LT_INIT

GLIB_GSETTINGS

APPSTREAM_XML

AC_CONFIG_MACRO_DIR([m4])

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

GLIB_REQUIRED=2.40.0
GTK_REQUIRED=3.13.4
QQWING_REQUIRED=1.2.0

PKG_CHECK_MODULES(GNOME_SUDOKU, [
  glib-2.0 >= $GLIB_REQUIRED
  gio-2.0 >= $GLIB_REQUIRED
  gtk+-3.0 >= $GTK_REQUIRED
  gee-0.8
])

PKG_CHECK_MODULES(LIBSUDOKU, [
  glib-2.0 >= $GLIB_REQUIRED
  gio-2.0 >= $GLIB_REQUIRED
  qqwing >= $QQWING_REQUIRED
  gee-0.8
  json-glib-1.0
])

AC_SUBST([GLIB_REQUIRED])

AC_PATH_PROG([DESKTOP_FILE_VALIDATE], [desktop-file-validate], [/bin/true])

AC_CHECK_LIB([m],[floor])

dnl ###########################################################################
dnl GResources
dnl ###########################################################################

AC_PATH_PROG(GLIB_COMPILE_RESOURCES, glib-compile-resources)

dnl ###########################################################################
dnl Internationalization
dnl ###########################################################################

IT_PROG_INTLTOOL([0.50])
AC_SUBST(GETTEXT_PACKAGE, gnome-sudoku)

dnl ###########################################################################
dnl Documentation
dnl ###########################################################################

YELP_HELP_INIT

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
po/Makefile.in
data/Makefile
data/icons/Makefile
data/icons/hicolor/Makefile
data/icons/HighContrast/Makefile
lib/Makefile
help/Makefile
src/Makefile
src/gnome-sudoku.gresource.xml
])
AC_OUTPUT
