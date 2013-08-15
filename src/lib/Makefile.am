SUBDIRS = gtk_goodies

# Don't distribute generated defaults.py. If you know a simpler way that works
# e.g. nodist_gnomesudoku_PYTHON=defaults.py then please fix this
dist-hook:
	rm $(distdir)/defs.py

gnomesudokudir = $(pythondir)/gnome_sudoku
gnomesudoku_PYTHON = \
	colors.py	\
	dancer.py	\
	defs.py	\
	defaults.py	\
	dialog_swallower.py	\
	game_selector.py	\
	gnome_sudoku.py	\
	gsudoku.py	\
	__init__.py	\
	main.py 	\
	number_box.py 	\
	pausable.py	\
	printing.py	\
	saver.py	\
	simple_debug.py	\
	sudoku_maker.py	\
	sudoku_thumber.py \
	sudoku.py	\
	timer.py	\
	tracker_info.py

CLEANFILES = *.pyc

-include $(top_srcdir)/git.mk
