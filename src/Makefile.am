SUBDIRS = lib

#################################################################

## Executable
bin_SCRIPTS = gnome-sudoku
CLEANFILES  = gnome-sudoku gnome-sudoku.in

gnome-sudoku: gnome-sudoku.in
	$(AM_V_GEN) cp gnome-sudoku.in $@ && chmod u+x $@
