# -*- coding: utf-8 -*-
import gtk, cairo
import sudoku, gsudoku
from defaults import *
from sudoku import DifficultyRating as DR
from gtk_goodies import gconf_wrapper
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

class GamePrinter (gconf_wrapper.GConfWrapper):

    ui_file = os.path.join(GLADE_DIR,'print_games.ui')

    initial_prefs = {'sudokus_per_page':2,
                     'print_multiple_sudokus_to_print':4,
                     'print_minimum_difficulty':0,
                     'print_maximum_difficulty':0.9,
                     'print_easy':True,
                     'print_medium':True,
                     'print_hard':True,
                     'print_very_hard':True,
                     }

    def __init__ (self, sudoku_maker, gconf):
        gconf_wrapper.GConfWrapper.__init__(self,gconf)
        self.sudoku_maker = sudoku_maker
        self.builder = gtk.Builder()
        self.builder.add_from_file(self.ui_file)
        # Set up toggles...
        for key,wname in [('mark_printed_as_played','markAsPlayedToggle'),
                          ('print_already_played_games','includeOldGamesToggle'),
                          ('print_easy','easyCheckButton'),
                          ('print_medium','mediumCheckButton'),
                          ('print_hard','hardCheckButton'),
                          ('print_very_hard','very_hardCheckButton'),                          
                          ]:
            setattr(self,wname,self.builder.get_object(wname))
            try: assert(getattr(self,wname))
            except: raise AssertionError('Widget %s does not exist'%wname)
            self.gconf_wrap_toggle(key,getattr(self,wname))
        self.sudokusToPrintSpinButton = self.builder.get_object('sudokusToPrintSpinButton')
        self.sudokusPerPageSpinButton = self.builder.get_object('sudokusPerPageSpinButton')
        for key,widg in [('print_multiple_sudokus_to_print',self.sudokusToPrintSpinButton.get_adjustment()),
                         ('sudokus_per_page',self.sudokusPerPageSpinButton.get_adjustment())
                         ]:
            self.gconf_wrap_adjustment(key,widg)
        self.dialog = self.builder.get_object('dialog')
        self.dialog.set_default_response(gtk.RESPONSE_OK)
        self.dialog.connect('response',self.response_cb)

    def response_cb (self, dialog, response):
        if response not in (gtk.RESPONSE_ACCEPT, gtk.RESPONSE_OK):
            self.dialog.hide()
            return
        # Otherwise, we're printing!
        levels = []
        for cat in DR.categories:
            if getattr(self,
                       cat.replace(' ','_')+'CheckButton'
                       ).get_active():
                levels.append(cat)
        if not levels:
            levels = DR.categories.keys()
        nsudokus = self.sudokusToPrintSpinButton.get_adjustment().get_value()
        sudokus = self.sudoku_maker.get_puzzles(
            nsudokus,
            levels,
            new=not self.includeOldGamesToggle.get_active()
            )
        # Convert floating point difficulty into a label string
        sudokus.sort(cmp=lambda a,b: cmp(a[1],b[1]))
        sudokus = [(sudoku.sudoku_grid_from_string(puzzle),
                    "%s (%.2f)"%(sudoku.get_difficulty_category_name(d),d)
                    ) for puzzle,d in sudokus]
        from printing import SudokuPrinter
        sp = SudokuPrinter(sudokus,
                           self.dialog,
                           sudokus_per_page=self.sudokusPerPageSpinButton.get_adjustment().get_value())

        self.sudokus_printed = sudokus
        response = sp.print_op.run(gtk.PRINT_OPERATION_ACTION_PRINT_DIALOG, sp.main_window)

        if response   == gtk.PRINT_OPERATION_RESULT_ERROR:
            pass
        elif response == gtk.PRINT_OPERATION_RESULT_APPLY:
            if self.markAsPlayedToggle.get_active():
                for sud,lab in self.sudokus_printed:
                    jar = {}
                    jar['game']=sud.to_string()
                    jar['printed']=True
                    jar['printed_at']=time.time()
                    tracker = saver.SudokuTracker()
                    tracker.finish_jar(jar)
            self.dialog.hide()

    def run_dialog (self):
        self.dialog.show()


