SUBDIRS = lib

#################################################################

## Executable
bin_SCRIPTS = gnome-sudoku
CLEANFILES  = gnome-sudoku gnome-sudoku.in

gnome-sudoku: gnome-sudoku.in
	cp gnome-sudoku.in $@
	if test -f $@; then chmod u+x $@; fi
