SUBDIRS = lib

#################################################################

## Executable
bin_SCRIPTS = gnome-sudoku
EXTRA_DIST  = gnome-sudoku gnome-sudoku.in
CLEANFILES  = gnome-sudoku

gnome-sudoku: $(srcdir)/gnome-sudoku.in
	sed \
		-e "s|\@pyexecdir\@|$(pyexecdir)|" \
	    	$< > $@
	if test -f $@; then chmod u+x $@; fi
