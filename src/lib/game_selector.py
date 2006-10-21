import gtk, gobject, time
import sudoku
import gnomeprint
from gettext import gettext as _
from timer import format_time,format_date
from defaults import *
from gtk_goodies import gconf_wrapper

class GameSelector (gconf_wrapper.GConfWrapper):

    def __init__ (self, sudoku_tracker, gconf=None):
        self.sudoku_tracker = sudoku_tracker
        if gconf:
            gconf_wrapper.GConfWrapper.__init__(self,gconf)

    def setup_dialog (self):
        self.glade = gtk.glade.XML(self.glade_file)
        self.dialog = self.glade.get_widget('dialog1')
        self.dialog.set_default_response(gtk.RESPONSE_OK)
        self.dialog.hide()
        self.tv = self.glade.get_widget('treeview1')        
        self.setup_tree()

    def setup_up_tree (self): raise NotImplementedError
    def get_puzzle (self): raise NotImplementedError
    
    def run_dialog (self):
        self.setup_dialog()
        self.dialog.show()
        ret = self.dialog.run()
        self.dialog.hide()
        return self.handle_response(ret)

    def run_swallowed_dialog (self, swallower):
        self.setup_dialog()
        response = swallower.run_dialog(self.dialog)
        return self.handle_response(response)
    
    def handle_response (self, ret):
        if ret==gtk.RESPONSE_OK:
            return self.get_puzzle()
        else:
            return None

class NewGameSelector (GameSelector):
    glade_file = os.path.join(GLADE_DIR,'new_game.glade')
    difficulty = 0

    def setup_dialog (self):
        GameSelector.setup_dialog(self)
        self.dialog.set_default_response(gtk.RESPONSE_OK)
        self.adj,self.hscale = self.setup_hscale('hscale1')
        self.adj.set_value(self.difficulty)
        
    def setup_hscale (self, scalename):
        hscale = self.glade.get_widget(scalename)
        adj = hscale.get_adjustment()
        bounds = [0.0,0.9]
        real_bounds = self.sudoku_tracker.sudoku_maker.get_difficulty_bounds()
        if real_bounds[1]>bounds[1]: bounds[1]=real_bounds[1]
        if real_bounds[0]<bounds[0]: bounds[0]=real_bounds[0]
        adj.lower,adj.upper = bounds
        adj.step_increment = (bounds[1]-bounds[0])/20
        adj.page_increment = adj.step_increment*10
        return adj,hscale

    def make_model (self):
        # puzzle [0], difficulty [1], value string [2], other string
        # [3], diff value (float) [4], game name [5]
        self.model = gtk.TreeStore(str, gobject.TYPE_PYOBJECT, str, str, float, str)

    def add_puzzle_to_model (self, p, d):
        """Add puzzle (with difficulty object d) to our treeview.
        """
        if not self.sudoku_tracker.sudoku_maker.names.has_key(p):
            self.sudoku_tracker.sudoku_maker.names[p]=self.sudoku_tracker.sudoku_maker.get_puzzle_name(
                _('Puzzle'))
        self.sudoku_tracker.sudoku_maker.names[p]
        itr = self.model.append(None,
                                [p, # puzzle
                                 d, # difficulty                                     
                                 d.value_string(),
                                 None,
                                 d.value,
                                 self.sudoku_tracker.sudoku_maker.names[p]
                                 ])
        # now we enumerate some details...
        for label,prop in [(_('Squares instantly fillable by filling: '),
                            d.instant_fill_fillable),
                           (_('Squares instantly fillable by elimination: '),
                            d.instant_elimination_fillable),
                           (_('Number of trial-and-errors necessary to solve: '),
                            len(d.guesses)),
                           (_('Difficulty value: '),
                            d.value),
                           ]:
            self.model.append(itr, [None,None,str(prop),None,0,label])

    def setup_tree (self):
        # puzzle / difficulty / diff value / name
        self.make_model()
        for puzzobj in self.sudoku_tracker.list_new_puzzles():
            self.add_puzzle_to_model(*puzzobj)
        self.setup_treeview_columns()
        
    def setup_treeview_columns (self):
        col0 = gtk.TreeViewColumn(_('Name'),gtk.CellRendererText(),text=5)
        col0.set_sort_column_id(5)
        col1 = gtk.TreeViewColumn(_("Difficulty"),gtk.CellRendererText(),text=2)
        col1.set_sort_column_id(4)
        #col2 = gtk.TreeViewColumn("Detail",gtk.CellRendererText(),text=3)
        #col2.set_sort_column_id(4)
        self.tv.append_column(col0)
        self.tv.append_column(col1)
        #self.tv.append_column(col2)
        self.tv.set_model(self.model)
        self.tv.get_selection().connect('changed',self.selection_changed_cb)

    def get_puzzle (self):
        diff = self.hscale.get_value()
        return self.sudoku_tracker.get_new_puzzle(diff)
        
    def selection_changed_cb (self, selection):
        mod,itr = selection.get_selected()
        while mod.iter_parent(itr):
            itr = mod.iter_parent(itr)
        difficulty = mod.get_value(itr,4)
        self.adj.set_value(difficulty)


class OldGameSelector (GameSelector):
    glade_file = os.path.join(GLADE_DIR,'open_game.glade')

    def setup_tree (self):
        rend = gtk.CellRendererText()
        col0 = gtk.TreeViewColumn(_('Name'),rend,text=8)
        col0.set_sort_column_id(8)
        self.tv.append_column(col0)
        col1=gtk.TreeViewColumn(_("Difficulty"),rend,text=2)
        col1.set_sort_column_id(3)
        self.tv.append_column(col1)
        self.tv.insert_column_with_data_func(1, # position
                                             _('Started'),# title
                                             gtk.CellRendererText(), # renderer,
                                             self.cell_data_func,
                                             4) # column
        self.tv.get_column(1).set_sort_column_id(4)
        self.tv.insert_column_with_data_func(2, # position
                                             _('Last Played'),# title
                                             gtk.CellRendererText(), # renderer,
                                             self.cell_data_func,
                                             5) # column
        self.tv.get_column(2).set_sort_column_id(5)
        col2 = gtk.TreeViewColumn(_("Status"),rend,text=6)
        self.tv.append_column(
            col2
            )
        col2.set_sort_column_id(7)
        self.setup_model()
        self.tv.set_model(self.model)
        self.tv.get_selection().connect('changed',self.selection_changed_cb)
        self.selection_changed_cb(self.tv.get_selection())

    def selection_changed_cb (self, selection):
        self.dialog.set_response_sensitive(gtk.RESPONSE_OK,
                                           selection.get_selected() and True or False)

    def setup_model (self):
        self.model = gtk.TreeStore(str,# game (0)
                                   gobject.TYPE_PYOBJECT,# jar (1)
                                   str,# difficulty (2)
                                   float,# diffval (3)
                                   float,# start date (4)
                                   float, # finish date (5)
                                   str,# status (6)
                                   float,# status val (7)
                                   str) # name (8)
        for game,jar in self.sudoku_tracker.playing.items():
            diff = self.sudoku_tracker.get_difficulty(game)
            if jar.has_key('printed') and jar['printed']:
                status=_('Printed %s ago')%format_time(status_val,round_at=2)
                status_val = 0
                start_time=jar['printed_at']
                finish_time=jar['printed_at']
                tot_time=None
            else:
                start_time = jar['timer.__absolute_start_time__']
                finish_time = jar.get('saved_at',time.time())
                status_val = jar['timer.tot_time']
                status = _("Played for %s")%format_time(jar['timer.tot_time'],round_at=2)
            if not self.sudoku_tracker.sudoku_maker.names.has_key(game):
                self.sudoku_tracker.sudoku_maker.names[game]=self.sudoku_tracker.sudoku_maker.get_puzzle_name(
                    _('Puzzle')
                    )
            name = self.sudoku_tracker.sudoku_maker.names[game]
            self.model.append(None,
                              [game,
                               jar,
                               diff and diff.value_string() or None,
                               diff and diff.value or 0,
                               start_time,
                               finish_time,
                               status,
                               status_val, # total time
                               name
                               ])

    def cell_data_func (self, tree_column, cell, model, titer, data_col):
        val = model.get_value(titer,data_col)
        curtime = time.time()
        # within 18 hours, return in form 4 hours 23 minutes ago or some such
        if curtime - val < 18 * 60 * 60:
            cell.set_property('text',
                              _("%s ago")%format_time(curtime-val,round_at=1))
            return
        tupl=time.localtime(val)
        if curtime - val <  7 * 24 * 60 * 60:
            cell.set_property('text',
                              time.strftime('%A %T',tupl))
            return
        else:
            cell.set_property('text',
                              time.strftime('%D %T',tupl))
            return

    def get_puzzle (self):
        mod,itr = self.tv.get_selection().get_selected()
        jar = mod.get_value(itr,1)
        return jar
    
    
class HighScores (GameSelector):
    glade_file = os.path.join(GLADE_DIR,'high_scores.glade')

    highlight_newest = False
    
    def setup_tree (self):
        self.setup_treemodel()
        rend = gtk.CellRendererText()        
        rend.connect('edited',self.player_edited_cb)
        col = gtk.TreeViewColumn(_('Player'),rend,text=0,
                                 editable=6,
                                 weight=6)
        col.set_sort_column_id(0)
        self.tv.append_column(col)
        col2 = gtk.TreeViewColumn(_('Score'),rend,text=1)
        col2.set_sort_column_id(2)
        self.tv.append_column(col2)
        col3 = gtk.TreeViewColumn(_('Date'),rend,text=3)
        col3.set_sort_column_id(4)
        self.tv.append_column(col3)
        self.tv.set_model(self.model)

    def run_swallowed_dialog (self, swallower):
        self.setup_dialog()
        swallower.swallow_dialog(self.dialog)
        swallower.set_current_page(swallower.swallowed[self.dialog])
        self.highlight()
        return self.handle_response(swallower.run_dialog(self.dialog))

    def run_dialog (self):
        self.setup_dialog()
        self.dialog.show()
        self.highlight()
        ret = self.dialog.run()
        self.dialog.hide()
        if ret==0:
            return self.get_puzzle()

    def setup_treemodel (self):
        # Name, Score, Score (float), Date, Date(float), Puzzle (str), Highlighted, Finisher (PYOBJ), Number
        self.model = gtk.TreeStore(str,str, float, str, float,str,int,gobject.TYPE_PYOBJECT)
        most_recent = (None,None)
        for game,finishers in self.sudoku_tracker.finished.items():
            for finisher in finishers:
                score=self.calculate_score(game,finisher)
                finish_time = finisher['finish_time']           
                itr=self.model.append(None,
                                  [finisher['player'],
                                   str(int(score)),
                                   score,
                                   #time.strftime("%H:%M %A ",time.localtime(finisher['finish_time'])),
                                   format_date(finisher['finish_time']),
                                   finish_time,
                                   game,
                                   0,
                                   finisher,
                                   ])
                if finish_time > most_recent[0]: most_recent = (finish_time,itr)
                for label,detail in [(_('Puzzle'), self.sudoku_tracker.sudoku_maker.names[game]),
                                     (_('Difficulty'),
                                      self.sudoku_tracker.sudoku_maker.all_puzzles[game].value_string() + \
                                      ' (' + \
                                      str(self.sudoku_tracker.sudoku_maker.all_puzzles[game].value) \
                                      + ')'
                                      ),
                                     (_('Hints'),'hints'),
                                     (_('Warnings about unfillable squares'),
                                      'impossible_hints'),
                                     (_('Auto-fills'),'auto_fills'),
                                     (_('Finished in'),format_time(finisher['time']))]:
                    if finisher.has_key(detail):
                        detail = finisher[detail]
                    self.model.append(itr,
                                      [label, detail, 0, None, 0,None,0,None])
        self.model.set_sort_column_id(2,gtk.SORT_DESCENDING)
        
        if self.highlight_newest:
            itr = most_recent[1]
            self.model.set_value(itr,6,1)
            self.highlight_path = self.model.get_path(itr)            

    def highlight (self):
        if hasattr(self,'highlight_path'):
            self.glade.get_widget('replay').hide()
            self.glade.get_widget('you_win_label').show()
            self.image = self.glade.get_widget('image')
            self.image.set_from_file(os.path.join(IMAGE_DIR,'winner.png'))
            self.image.show()
            self.tv.expand_row(self.highlight_path,True)
            def start_editing ():
                self.tv.set_cursor(self.highlight_path,
                                   focus_column=self.tv.get_column(0),
                                   start_editing=True)
            gobject.idle_add(start_editing)

    def calculate_score (self, puzzl, finisher):
        diff = self.sudoku_tracker.get_difficulty(puzzl)
        time_bonus = (60*60*3.5/(finisher['auto_fills']+1))/finisher['time']
        if time_bonus < 1: time_bonus = 1
        score = diff.value * 100
        if score <= 10: score = 5 # minimum score of 5
        score = score * time_bonus
        score = score - finisher['auto_fills']*10
        score = score - finisher['impossible_hints']*0.5
        score = score - finisher['hints']*0.5
        if score < 0: score = 0
        return score

    def player_edited_cb (self, renderer, path_string, text):
        self.model[path_string][0]=text
        self.model[path_string][7]['player']=text
        
    def get_puzzle (self):
        mod,itr = self.tv.get_selection().get_selected()
        if not itr:
            return None
        while mod.iter_parent(itr):
            itr = mod.iter_parent(itr)
            if not itr: return None
        return mod.get_value(itr,5)

class GamePrinter (NewGameSelector):

    glade_file = os.path.join(GLADE_DIR,'print_games.glade')

    initial_prefs = {'sudokus_per_page':2,
                     'print_multiple_sudokus_to_print':4,
                     'print_minimum_difficulty':0,
                     'print_maximum_difficulty':0.9}

    def __init__ (self, sudoku_tracker, gconf):
        self.gconf = gconf # we'll need gconf to store printing settings...
        GameSelector.__init__(self,sudoku_tracker,gconf)

    def setup_dialog (self):
        GameSelector.setup_dialog(self)
        widgs = ['sudokusToPrintSpinButton',
                 'sudokusPerPageSpinButton',
                 'labelGamesToggle',
                 'markAsPlayedToggle',
                 'includeOldGamesToggle']        
        for w in widgs: setattr(self,w,self.glade.get_widget(w))
        # sync up our widgets with gconf keys
        for n,t in [('mark_printed_as_played','markAsPlayedToggle'),
                    ('label_games','labelGamesToggle'),
                    ('print_already_played_games','includeOldGamesToggle')
                    ]:
            self.gconf_wrap_toggle(n,getattr(self,t))
        self.min_adj,self.min_scale = self.setup_hscale('minimumScale')
        self.max_adj,self.max_scale = self.setup_hscale('maximumScale')
        for n,a in [('print_multiple_minimum_difficulty',self.min_adj),
                    ('print_multiple_maximum_difficulty',self.max_adj),
                    ('print_multiple_sudokus_to_print',self.sudokusToPrintSpinButton.get_adjustment()),
                    ('sudokus_per_page',self.sudokusPerPageSpinButton.get_adjustment())]:
            self.gconf_wrap_adjustment(n,a)
        self.dialog.set_default_response(gtk.RESPONSE_OK)
        if self.gconf['print_already_played_games']:
            self.tv.set_model(self.model)
        else:
            self.tv.set_model(self.new_model)
        self.includeOldGamesToggle.connect('toggled',self.include_old_games_toggle_cb)
        self.max = self.max_adj.get_value()
        self.min = self.min_adj.get_value()
        self.last_adjusted = 1
        self.min_adj.connect('value-changed',self.difficulty_val_changed,0)
        self.max_adj.connect('value-changed',self.difficulty_val_changed,1)
        self.changing_spin_internally = False
        self.changing_difficulty_internally = False
        self.sudokusToPrintSpinButton.connect('focus-out-event',self.spin_changed_cb)
        self.sudokusToPrintSpinButton.get_adjustment().upper = len(self.tv.get_model())

    def spin_changed_cb (self, *args):
        #if not self.changing_spin_internally:
        self.auto_select_puzzles()

    def include_old_games_toggle_cb (self, tog, *args):
        if tog.get_active(): self.tv.set_model(self.model)
        else: self.tv.set_model(self.new_model)
        self.sudokusToPrintSpinButton.get_adjustment().upper = len(self.tv.get_model())
        self.auto_select_puzzles()

    def setup_tree (self):
        self.make_model()
        for puzzobj in self.sudoku_tracker.sudoku_maker.all_puzzles.items():
            self.add_puzzle_to_model(*puzzobj)
        fm = self.model.filter_new()
        def include_puzzle_at_itr (mod, itr):
            puz=mod.get_value(itr, 0)
            if not self.sudoku_tracker.playing.has_key(puz) and not self.sudoku_tracker.finished.has_key(puz):
                return True
        fm.set_visible_func(include_puzzle_at_itr)
        self.new_model = gtk.TreeModelSort(fm)
        self.model.set_sort_column_id(4,gtk.SORT_ASCENDING)
        self.new_model.set_sort_column_id(4,gtk.SORT_ASCENDING)
        self.setup_treeview_columns()
        self.tv.get_selection().set_mode(gtk.SELECTION_MULTIPLE)

    def run_dialog (self):
        self.setup_dialog()
        self.auto_select_puzzles()
        self.dialog.connect('response',self.response_cb)
        self.dialog.show()

    def run_swallowed_dialog (self, swallower):
        # This is broken... tell anyone who calls us not to use it!
        raise NotImplementedError
        self.setup_dialog()
        self.auto_select_puzzles()
        response = swallower.run_dialog(self.dialog)
        return self.handle_response(response)
    
    def response_cb (self, dialog, response):
        if response == gtk.RESPONSE_ACCEPT or response == gtk.RESPONSE_OK:
            mod,rr = self.tv.get_selection().get_selected_rows()
            sudokus = []
            labelp = self.labelGamesToggle.get_active() or None # None rather than False
            for path in rr:
                grid = mod[path][0]
                difficulty = mod[path][2]
                name = mod[path][5]
                label = labelp and "%s (%s)"%(name,difficulty)                
                grid = sudoku.SudokuGrid(grid)
                sudokus.append((grid,label)) # puzzle, difficulty (value string)
            from printing import SudokuPrinter
            sp = SudokuPrinter(sudokus,sudokus_per_page=self.sudokusPerPageSpinButton.get_adjustment().get_value(), dialog_parent=self.dialog)
            self.sudokus_printed = sudokus
            sp.run()
            sp.dialog.connect('response',self.print_dialog_response_cb)
        else:
            self.dialog.hide()

    def print_dialog_response_cb (self, dialog, response):
        if response == gnomeprint.ui.DIALOG_RESPONSE_CANCEL:
            #self.dialog.hide()
            pass
        elif response == gnomeprint.ui.DIALOG_RESPONSE_PREVIEW:
            pass
        elif response==gnomeprint.ui.DIALOG_RESPONSE_PRINT:
            if self.markAsPlayedToggle.get_active():
                for sud,lab in self.sudokus_printed:
                    jar = {}
                    jar['game']=sud.to_string()
                    jar['printed']=True
                    jar['printed_at']=time.time()
                    self.sudoku_tracker.playing[sud.to_string()] = jar
            self.dialog.hide()

    def difficulty_val_changed (self, adj, typ):
        self.last_adjusted = typ
        self.max = self.max_adj.get_value()
        self.min = self.min_adj.get_value()
        if not self.changing_difficulty_internally: self.auto_select_puzzles()

    def auto_select_puzzles (self,*args):
        mod = self.tv.get_model()
        lower = []
        higher = []
        possible = []
        for row in mod:
            diff = row[1]
            n = diff.value
            if self.min <= n <= self.max:
                possible.append((row,n))
            elif n < self.min:
                lower.append((row,n))
            else:
                higher.append((row,n))
        row_sorter = lambda a,b: a[1]>b[1] and 1 or a[1]<b[1] and -1 or 0
        nsudokus = self.sudokusToPrintSpinButton.get_adjustment().get_value()
        if not possible and not lower and not higher:
            return
        if len(possible) < nsudokus:
            print 'Only %d puzzles have a difficulty between %d and %d'%(len(possible), self.min, self.max)
            print "We'll have to fudge a bit..."
            choices = possible # start with everything we've got...
            lower.sort(row_sorter)
            higher.sort(row_sorter)
            higher.reverse()
            # First priority, we last nudged higher and move to the lower end
            if self.last_adjusted == 1 and lower:
                while len(choices)<nsudokus and lower:
                    choices.append(lower.pop())
            # Otherwise, try moving higher...
            if self.last_adjusted == 0 and higher:
                while len(choices)<nsudokus and higher:
                    choices.append(higher.pop())
            # If we still don't have enough, nudge as necessary in both directions...
            just_tried = 0
            while len(choices) < nsudokus and (higher or lower):
                if just_tried and lower:
                    print 'Nudging lower'
                    choices.append(lower.pop())
                    just_tried = 0
                elif higher:
                    print 'Nudging higher'
                    choices.append(higher.pop())
                    just_tried = 1
                else:
                    print 'Nudging lower'
                    choices.append(lower.pop())
        else: # len(possible) >= nsudokus
            if nsudokus ==1:
                middle = len(possible)/2
                choices = [possible[middle]]
            else:
                # get an even distribution of numbers...
                # for example, 2 of 12 items will give us 0 and 12,
                # 3 of 12 will give us 0,6,12, 4 of 12 will give us
                # 0,4,8,12, etc.
                spacer = (len(possible)-1)/float(nsudokus-1)
                indices = [n*spacer for n in range(nsudokus)]
                choices = [possible[int(n)] for n in indices]
        if choices:
            self.tv.get_selection().unselect_all()
            #print 'Selecting ',len(choices),'choices.'
        for c in choices:
            try:
                self.tv.get_selection().select_iter(c[0].iter)
            except:
                print "That's funny",c,'must be an iter(?)'
                self.tv.get_selection().select_iter(c)
                #print 'selected ',choices

    def selection_changed_cb (self, selection):
        mod,rows = selection.get_selected_rows()
        count = 0
        new_max = None
        new_min = None
        for path in rows:
            if not mod[path][0]: # if there's no puzzle...
                parent = mod[path].parent
                if parent and not parent.path in rows:
                    # then we select the parent...
                    selection.select_iter(parent)
                    # and we stop handling because we should be called
                    # again as a result of our selection
                    break
            else:
                difficulty = mod[path][4]
                if difficulty < self.min:
                    if new_min == None or difficulty < new_min:
                        new_min = difficulty
                if difficulty > self.max:
                    if new_max == None or difficulty > new_max:
                        new_max = difficulty
                count += 1
        if count > 1:
            self.dialog.set_response_sensitive(gtk.RESPONSE_OK,
                                               selection.get_selected_rows() and True or False)
            self.changing_spin_internally = True
            self.sudokusToPrintSpinButton.get_adjustment().set_value(count)
            self.changing_spin_internally = False
            if new_min != None:
                self.min_adj.set_value(new_min)
            if new_max:
                self.max_adj.set_value(new_max)

if __name__ == '__main__':
    try:
        IMAGE_DIR='/usr/share/gnome-sudoku/'
        import defaults
        from gnome_sudoku import sudoku_maker
        st = sudoku_maker.SudokuTracker(sudoku_maker.SudokuMaker(pickle_to='/tmp/foo'))
        hs=HighScores(st)
        hs.highlight_newest=True
        hs.run_dialog()
        st.save()
    except:
        import sys
        print 'path was ',sys.path
        raise
