AC_PREREQ([2.63])
AC_INIT([GNOME Sudoku], [3.12.3], [https://bugzilla.gnome.org/],
        [gnome-sudoku], [https://wiki.gnome.org/Apps/Sudoku])
AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE([enable])
GNOME_MAINTAINER_MODE_DEFINES

GLIB_GSETTINGS

AM_PATH_PYTHON([3.2],,AC_MSG_ERROR([Python not found]))

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

PYGOBJECT_REQUIRED=3.11

PKG_CHECK_MODULES(PYGOBJECT, [
    pygobject-3.0 >= $PYGOBJECT_REQUIRED
])

AC_PATH_PROG([APPDATA_VALIDATE], [appdata-validate], [/bin/true])
AC_PATH_PROG([DESKTOP_FILE_VALIDATE], [desktop-file-validate], [/bin/true])

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
help/Makefile
src/Makefile
src/lib/Makefile
src/lib/defs.py
src/lib/gtk_goodies/Makefile
])
AC_OUTPUT
