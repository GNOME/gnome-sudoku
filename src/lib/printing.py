import gtk, gnomeprint, gnomeprint.ui, math
import sudoku, gsudoku
from gettext import gettext as _
from gettext import ngettext

class GridDrawer:

    X = 0
    Y = 1

    def __init__ (self,
                  gpc,
                  grid_size=9,
                  grid_side_size=500,
                  start_at=(800,50),
                  default_color=(0,0,0),
                  label=None,
                  label_font=('Arial','12'),
                  ):
        self.gpc = gpc
        self.grid_size = grid_size
        self.label = label
        self.label_font=gnomeprint.font_find_closest(*label_font)
        self.grid_side_size = grid_side_size
        self.start_at = start_at
        self.increment = float(grid_side_size) / grid_size
        self.left_upper = start_at
        self.right_lower = self.left_upper[0]+self.grid_side_size,self.left_upper[1]-self.grid_side_size
        self.box_size = math.sqrt(grid_size)
        #print 'beginpage 1'
        #self.gpc.beginpage("1")
        # get the right font size for our increment...
        self.increment * 0.7
        # start with our maximum font...
        max_size=36
        self.font = gnomeprint.font_find_closest('Sans Bold',max_size)
        self.default_color = default_color
        while self.font.get_width_utf8('1')> (self.increment * 0.4) and\
                  self.font.get_ascender()> (self.increment * 0.4):
            max_size = max_size - 1
            self.font = gnomeprint.font_find_closest('Helvetica',
                                                     max_size)
        self.THICK_WIDTH = 1 + float(max_size) / 8
        #print 'FONT SIZE ',max_size, 'BORDER SIZE: ',self.THICK_WIDTH
        self.gpc.setfont(
            self.font
            )
        self.gpc.setrgbcolor(*self.default_color)

    def finish (self):
        self.gpc.showpage()

    def draw_label (self, x, y, label, font=None, color=None):
        if label:
            if type(label)!=str: print 'Funny... label ',label,'is a ',type(label)
            self.gpc.moveto(x,y)
            self.gpc.setfont(self.label_font)
            self.gpc.show(label)
            self.gpc.setfont(self.font) #reset

    def draw_number (self, x, y, val, font=None, color=None):
        if not font: font = self.font
        self.gpc.setfont(font)
        if color: self.gpc.setrgbcolor(*color)
        move_to = list(self.left_upper)
        char_w=font.get_width_utf8(str(val))
        char_h = font.get_ascender()
        #print 'Center by ',(self.increment - char_w)/2
        move_to[self.X] += (self.increment * x + (self.increment - char_w)/2)
        move_to[self.Y] = move_to[self.Y] - (((y+1) * self.increment) - (self.increment - char_h)/2)
        #print 'Printing ',x,y,val,' at ',move_to
        self.gpc.moveto(*move_to)
        self.gpc.show(str(val))
        if color: self.gpc.setrgbcolor(*self.default_color) #unset color

    def draw_grid (self):
        for direction in self.X,self.Y:
            opposite = int(not direction)
            for n in range(self.grid_size+1):                
                start_pos = list(self.left_upper)                                  
                if direction==self.Y:
                    start_pos[direction]=self.left_upper[direction]-self.increment*n
                else:
                    start_pos[direction]=self.left_upper[direction]+self.increment*n
                # double the thickness of our borders and box borders...
                # e.g. 0, 3, 6, 9
                length_adjustment = 0
                if n % self.box_size == 0:
                    self.gpc.setlinewidth(self.THICK_WIDTH)
                    # correct start position to take into account our
                    # width so that corners don't look funny.
                    if True or n==0 or n==self.box_size:
                        length_adjustment = self.THICK_WIDTH/2
                        if direction==self.X:
                            start_pos[direction] = start_pos[direction]+length_adjustment
                        else:
                            start_pos[direction] = start_pos[direction]-length_adjustment
                # get in position...
                self.gpc.moveto(*start_pos)
                # draw our line...
                dest_pos = start_pos
                if direction==self.Y:
                    dest_pos[opposite]=dest_pos[opposite]+self.grid_side_size+length_adjustment*2
                else:
                    dest_pos[opposite]=dest_pos[opposite]-self.grid_side_size-length_adjustment*2
                self.gpc.lineto(*dest_pos)
                #print 'Printing line ',direction,':',n
                #print dest_pos,':',start_pos
                self.gpc.stroke()
                # Reset our width to normal if need be...
                if n % self.box_size == 0: self.gpc.setlinewidth(1)                

class SudokuDrawer (GridDrawer):
    def __init__ (self,
                  sudoku_grid, # A SudokuGrid, a InteractiveSudoku/SudokuSolver, or a SudokuGridDisplay
                  gpc,
                  grid_size=9,
                  grid_side_size=500,
                  start_at=(800,50),
                  label=None,
                  label_font=('Arial',12),
                  ):
        """Draw a sudoku grid.

        If we're labelling, we put our label above the start_at
        """
        if isinstance(sudoku_grid,gsudoku.SudokuGameDisplay):
            self.sudoku_grid = sudoku_grid.grid
            self.sgd = sudoku_grid
        else:
            self.sudoku_grid = sudoku_grid
            self.sgd = None
        GridDrawer.__init__(self,
                            gpc,
                            grid_size=grid_size,
                            grid_side_size=grid_side_size,
                            start_at=start_at,
                            label=label,
                            label_font=label_font,
                            )
        self.alt_font = gnomeprint.font_find_closest('Sans Italic',
                                                     self.font.get_size()*0.85
                                                     )
        
        self.alt_color = .4,.4,.4
        
    def draw_sudoku (self):
        if self.label: self.draw_label(self.start_at[0],
                                       self.start_at[1]+self.label_font.get_ascender(),
                                       self.label,)
        for x in range(self.grid_size):
            for y in range(self.grid_size):
                if isinstance(self.sudoku_grid,sudoku.SudokuSolver):
                    val = self.sudoku_grid.virgin._get_(x,y)
                    if val: self.draw_number(x,y,val)
                    elif self.sudoku_grid._get_(x,y):
                        if not self.sgd:
                            color=self.alt_color
                        else:
                            trackers=self.sgd.trackers_for_point(x,y)
                            if trackers:
                                tracker=trackers[0]
                                color=self.sgd.get_tracker_color(tracker)
                            else:
                                color = self.alt_color
                        self.draw_number(
                            x,y,
                            self.sudoku_grid._get_(x,y),
                            self.alt_font,
                            color,
                            )
                else:
                    val = self.sudoku_grid._get_(x,y)
                    if val: self.draw_number(x,y,val)

MINIMUM_SQUARE_SIZE=135

class SudokuPrinter:
    def __init__ (self,
                  sudokus,
                  margin=50,
                  sudokus_per_page=None,
                  dialog_parent=None
                  ):
        self.drawn = False
        self.margin = margin
        self.sudokus_per_page=sudokus_per_page
        self.dialog_parent = dialog_parent
        try:
            self.nsudokus = len(sudokus) # number of sudokus we're printing
        except TypeError,AttributeError:
            sudokus = [sudokus] # assume they passed us one sudoku by
            self.nsudokus = 1        # mistake and be nice
        self.sudokus = sudokus
        #print 'Getting default config'
        self.job = gnomeprint.Job(gnomeprint.config_default())

    def run (self):
        self.dialog = gnomeprint.ui.Dialog(self.job,
                                      ngettext("Print Sudoku","Print Sudokus",
                                               self.nsudokus),
                                      0)
        if self.dialog_parent: self.dialog.set_transient_for(self.dialog_parent)
        self.dialog.connect('response',self.response_cb)
        self.dialog.show()

    def response_cb (self, dialog, response):
        #print 'Ran dialog.'
        if response == gnomeprint.ui.DIALOG_RESPONSE_CANCEL:
            dialog.hide()            
        elif response == gnomeprint.ui.DIALOG_RESPONSE_PREVIEW:
            if not self.drawn: self.draw_sudokus()
            w=gnomeprint.ui.JobPreview(self.job,_('Print Preview'))
            w.set_transient_for(dialog)
            #w.present()
            w.set_property('allow-grow',1)
            w.set_property('allow-shrink',1)
            w.show_all()
            w.present()
            #self.dialog.emit_stop_by_name('response')
        elif response == gnomeprint.ui.DIALOG_RESPONSE_PRINT:
            if not self.drawn: self.draw_sudokus()
            self.job.print_()
            dialog.hide()

            
    def draw_sudokus (self):
        #print 'getting context'
        self.gpc = self.job.get_context()    
        width,height = gnomeprint.job_get_page_size_from_config(self.job.get_config())
        self.margin = 50
        top = height-self.margin
        bottom = self.margin
        left = self.margin
        right = width
        if not self.sudokus_per_page:
            self.sudokus_per_page = self.nsudokus
            dimensions, square_size = fit_squares_in_rectangle(width,height,self.sudokus_per_page,self.margin)
            while square_size < MINIMUM_SQUARE_SIZE:
                self.sudokus_per_page = self.sudokus_per_page - 1
                dimensions, square_size = fit_squares_in_rectangle(width,height,self.sudokus_per_page,self.margin)
        else:
            dimensions,square_size =  fit_squares_in_rectangle(width,height,self.sudokus_per_page,self.margin)
        #print 'SQUARE_SIZE=',square_size
        count = 0
        for sudoku in self.sudokus:
            if type(sudoku)==tuple:
                label = sudoku[1]
                sudoku = sudoku[0]
            else:
                label = None
            if count % self.sudokus_per_page == 0:
                if count: self.gpc.showpage()
                self.gpc.beginpage('%s'%(count/self.sudokus_per_page+1))
                pos = [1,1]
                left_start,top_start=self.margin,top
            else:
                # move from left to right, top to bottom
                if pos[0] < dimensions[0]:
                    left_start = left_start + square_size + self.margin
                    pos[0] += 1
                else:
                    top_start = top_start - square_size - self.margin # down ...
                    left_start = self.margin                          # ...and to the left
                    pos[0] = 1
                    pos[1] += 1
            drawer = SudokuDrawer(sudoku,
                                  self.gpc,
                                  start_at=(left_start,top_start),
                                  grid_side_size=square_size,
                                  label=label
                                  )
            drawer.draw_grid()
            drawer.draw_sudoku()
            count += 1
        self.gpc.showpage()
        self.job.close()
        self.drawn = True
        

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
        #print n_across,'x',n_down,'=>',square_size,'x',square_size,'squares.'
        if square_size > best_square_size:
            best_square_size = square_size
            best_fit = n_across,n_down
    if best_fit:
        return best_fit,best_square_size
        
def print_sudokus(*args,**kwargs):
    sp = SudokuPrinter(*args,**kwargs)
    sp.run()

    
def my_print ():
    sud=sudoku.SudokuSolver(sudoku.easy_sudoku)
    sud.fill_deterministically()
    sud2 = sudoku.SudokuSolver(sudoku.fiendish_sudoku)
    sud2.fill_deterministically()
    sud3 = sudoku.SudokuSolver(sudoku.hard_open_sudoku)
    #print_sudokus([sud,sud2,sud3,sud,sud2,sud3,sud,sud2,sud3],
    #              )
    sp = SudokuPrinter([sud,sud2,sud3,sud,sud2,sud3,sud,sud2,sud3])
    #sp.run()
    print 'and...\n...\nreturns',sp.run(),'!'

