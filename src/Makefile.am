SUBDIRS = lib

#################################################################

## Executable
bin_SCRIPTS = gnome-sudoku
EXTRA_DIST  = gnome-sudoku
CLEANFILES  = gnome-sudoku

gnome-sudoku: $(srcdir)/gnome-sudoku.in
	sed \
		-e "s|\@pyexecdir\@|$(pyexecdir)|" \
	    	$< > $@
