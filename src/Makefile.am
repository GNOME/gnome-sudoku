SUBDIRS = lib

#################################################################

## Executable
bin_SCRIPTS = gnome-sudoku
EXTRA_DIST  = gnome-sudoku
CLEANFILES  = gnome-sudoku

gnome-sudoku: gnome-sudoku.in
	sed \
		-e "s|\@pyexecdir\@|$(pyexecdir)|" \
		gnome-sudoku.in > gnome-sudoku

