# -*- coding: utf-8 -*-
import gtk, cairo
import sudoku, gsudoku
from gettext import gettext as _
from gettext import ngettext

def fit_squares_in_rectangle (width, height, n, margin=0):
    """Optimally fit squares into a rectangle.

    Return number of columns, number of rows, and square size
    for the best fit of n squares into a rectangle of given width and height.

    Optionally include a margin along edges and between squares.
    """
    best_square_size = 0
    best_fit = None
    for n_across in range(1,int(n)+1):
        # if there's a remainder, we need to add an extra row...
        # i.e. 5 / 2 = 2 remainder 1, which means with two rows we
        # would need three columns, not two.
        n_down = n / n_across + (n % n_across and 1 or 0)
        across_size = width - ((n_across+1) * margin)
        across_size = across_size / n_across
        down_size = height - ((n_down+1) * margin)
        down_size = down_size / n_down
        if across_size < down_size:
            square_size = across_size
        else:
            square_size = down_size
        if square_size > best_square_size:
            best_square_size = square_size
            best_fit = n_across,n_down
    if best_fit:
        return best_fit,best_square_size

class SudokuPrinter:
    def __init__ (self,
                  sudokus,
                  main_window,
                  margin=50,
                  sudokus_per_page=1,
                  ):
        self.drawn = False
        self.margin = margin
        self.sudokus_per_page=sudokus_per_page
        self.n_sudokus = len(sudokus)
        self.sudokus = sudokus
        self.print_op = gtk.PrintOperation()
        self.print_op.connect( "begin-print", self.begin_print)
        self.print_op.connect("draw-page", self.draw_page)
        self.main_window = main_window

    def begin_print(self, operation, context):
        import math
        pages = int(math.ceil(self.n_sudokus / self.sudokus_per_page))
        operation.set_n_pages(pages)

    def draw_page(self, operation, context, page_nr):
        import pango
        import sudoku_thumber

        margin = 25
        cr = context.get_cairo_context()
        width = context.get_width()
        height = context.get_height()

        best_fit,best_square_size = fit_squares_in_rectangle(width, height, self.sudokus_per_page, margin)

        start = int(page_nr*self.sudokus_per_page)
        sudokus_on_page = self.sudokus[start : start+int(self.sudokus_per_page)]

        left = margin
        top = margin
        pos = [1,1]
        for sudoku in sudokus_on_page:
            if type(sudoku)==tuple:
                label = sudoku[1]
                sudoku = sudoku[0]
            else:
                label = ""

            cr.set_font_size(12)
            cr.select_font_face("", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
            cr.set_source_rgb(0,0,0)    
            xbearing, ybearing, width, height, xadvance, yadvance = cr.text_extents(label)
            cr.move_to(left, top-height/2)
            cr.show_text(label)

            if isinstance(sudoku, gsudoku.SudokuGameDisplay):
                sudoku = sudoku.grid

            sudoku_thumber.draw_sudoku (cr, sudoku.grid, None, best_square_size, left, top)
            if pos[0] < best_fit[0]:
                left = left + best_square_size + margin
                pos[0] += 1
            else:
                top = top + best_square_size + margin
                left = margin
                pos[0] = 1
                pos[1] += 1


def print_sudokus(*args,**kwargs):
    sp = SudokuPrinter(*args,**kwargs)
    res = sp.print_op.run(gtk.PRINT_OPERATION_ACTION_PRINT_DIALOG, sp.main_window)
    if res == gtk.PRINT_OPERATION_RESULT_ERROR:
        error_dialog = gtk.MessageDialog(main_window,
                                      gtk.DIALOG_DESTROY_WITH_PARENT,
                                      gtk.MESSAGE_ERROR,
                                      gtk.BUTTONS_CLOSE,
                                      "Error printing file:\n")
        error_dialog.connect("response", lambda w,id: w.destroy())
        error_dialog.show()

