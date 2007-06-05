try:
    import pygtk
    pygtk.require('2.0')
except ImportError, err:
    print ("PyGTK not found. Please make sure it is installed properly and referenced in your PYTHONPATH environment variable.")

import gtk, gobject, gtk.glade
import gnome, gnome.ui, pango
import os, os.path
from gtk_goodies import gconf_wrapper, Undo, dialog_extras, image_extras
import gsudoku, sudoku, saver, sudoku_maker, printing, sudoku_generator_gui
import game_selector
import time, threading
from gettext import gettext as _
from gettext import ngettext
from defaults import *
from timer import ActiveTimer
from simple_debug import simple_debug,options
from dialog_swallower import SwappableArea

icon_factory = gtk.IconFactory()
STOCK_PIXBUFS = {}
for filename,stock_id in [('footprints.png','tracks'),]:
    pb = gtk.gdk.pixbuf_new_from_file(os.path.join(IMAGE_DIR,filename))
    STOCK_PIXBUFS[stock_id]=pb
    iconset = gtk.IconSet(pb)
    icon_factory.add(stock_id,iconset)
    icon_factory.add_default()

gtk.stock_add([('tracks',
                _('Track moves'),
                0,0,""),])

try:
    STOCK_FULLSCREEN = gtk.STOCK_FULLSCREEN
except:
    STOCK_FULLSCREEN = _('Full Screen')

def inactivate_new_game_etc (fun):
    def _ (ui, *args, **kwargs):
        paths = [
            '/MenuBar/Game/New',
            #'/MenuBar/Game/Open',
            #'/MenuBar/Game/ByHand',
            '/MenuBar/Game/Print',
            '/MenuBar/Edit/Undo',
            '/MenuBar/Edit/Redo',
            '/MenuBar/Edit/Clear',
            '/MenuBar/Edit/ClearNotes',
            '/MenuBar/Tools/ShowPossible',
            '/MenuBar/Tools/AutofillCurrentSquare',
            '/MenuBar/Tools/Autofill',
            '/MenuBar/Tools/AlwaysShowPossible',
            '/MenuBar/Tools/ShowImpossibleImplications',
            '/MenuBar/Tools/Tracker',
            '/MenuBar/Tools/PuzzleInfo',
            '/MenuBar/Tools/HighScores',
            ]
        for p in paths:
            action = ui.uimanager.get_action(p)
            if not action: action = ui.uimanager.get_widget(p)
            if not action: print 'No action at path',p
            else: action.set_sensitive(False)
        fun(ui,*args,**kwargs)
        for p in paths:
            action = ui.uimanager.get_action(p)
            if not action: action = ui.uimanager.get_widget(p)
            if not action: print 'No action at path',p
            else: action.set_sensitive(True)
    return _

class UI (gconf_wrapper.GConfWrapper):
    ui='''<ui>
    <menubar name="MenuBar">
      <menu name="Game" action="Game">
        <menuitem action="New"/>
        <!--<menuitem action="Open"/>-->
        <!--<menuitem action="ByHand"/>-->
        <separator/>
        <menuitem action="Print"/>
        <menuitem action="PrintMany"/>
        <separator/>
        <!--<menuitem action="Save"/>-->
        <separator/>
        <menuitem action="Generator"/>
        <menuitem action="BackgroundGenerator"/>
        <separator/>
        <menuitem action="Close"/>
        <!--<menuitem action="Quit"/>-->
      </menu>
      <menu action="Edit">
        <menuitem action="Undo"/>
        <menuitem action="Redo"/>
        <separator/>
        <menuitem action="Clear"/>
        <menuitem action="ClearNotes"/>        
      </menu>
      <menu action="View">
        <menuitem action="FullScreen"/>
        <separator/>
        <menuitem action="ToggleToolbar"/>
        <menuitem action="ToggleBackground"/>
        <menuitem action="ToggleHighlight"/>        
      </menu>
      <menu action="Tools">
         <menuitem action="ShowPossible"/>
          <menuitem action="AutofillCurrentSquare"/>
          <menuitem action="Autofill"/>
          <separator/>
          <menuitem action="AlwaysShowPossible"/>
          <menuitem action="ShowImpossibleImplications"/>
        <separator/>
        <menuitem action="Tracker"/>
        <separator/>
        <menuitem action="PuzzleInfo"/>
        <separator/>
        <menuitem action="HighScores"/>
       </menu>
       <menu action="Help">
         <menuitem action="ShowHelp"/>
         <menuitem action="About"/>
       </menu>
     </menubar>
     <toolbar name="Toolbar">
      <!--<toolitem action="Quit"/>-->
      <toolitem action="New"/>
      <!--<toolitem action="Open"/>-->
      <!--<toolitem action="Print"/>-->
      <!--<toolitem action="Save"/>-->
      <separator/>
      <toolitem action="Clear"/>      
      <toolitem action="ClearNotes"/>
      <!--<separator/>
      <toolitem action="Undo"/>
      <toolitem action="Redo"/>-->
      <separator/>
      <toolitem action="ShowPossible"/>
      <!--<toolitem action="AlwaysShowPossible"/>-->
      <toolitem action="AutofillCurrentSquare"/>      
      <separator/>
      <toolitem action="ToggleHighlight"/>
      <!--<toolitem action="AlwaysShowPossible"/>-->
      
      <toolitem action="Tracker"/>
     </toolbar>
     </ui>'''

    initial_prefs = {'group_size':9,
                     'font_zoom':0,
                     'zoom_on_resize':1,
                     'always_show_hints':0,
                     'player':os.environ.get('USERNAME',''),
                     'difficulty':0.0,
                     'minimum_number_of_new_puzzles':MIN_NEW_PUZZLES,
                     'bg_black':1,
                     'bg_custom_color':'',
                     'show_tracker':False,
                     'width': 700,
                     'height': 675
                     #'show_notes':0
                     }    

    @simple_debug
    def __init__ (self):
        gtk.window_set_default_icon_name('gnome-sudoku')
        self.w = gtk.Window()
        self.timer = ActiveTimer(self.w)
        self.won = False
        gconf_wrapper.GConfWrapper.__init__(self,
                                            gconf_wrapper.GConf('gnome-sudoku')
                                            )
        self.initialize_prefs()
        self.player = self.gconf['player']

        self.cleared = [] # used for Undo memory
        self.cleared_notes = [] # used for Undo memory
        gnome.program_init('gnome-sudoku',VERSION, properties={gnome.PARAM_APP_DATADIR:APP_DATA_DIR})
        self.w.set_default_size(self.gconf['width'], self.gconf['height'])
        self.w.set_title(APPNAME_SHORT)
        self.w.connect('configure-event',self.resize_cb)
        self.w.connect('delete-event',self.quit_cb)
        self.vb = gtk.VBox()
        self.uimanager = gtk.UIManager()
        if self.gconf['bg_custom_color']:
            bgcol = self.gconf['bg_custom_color']
        elif self.gconf['bg_black']:
            bgcol = 'black'
        else:
            bgcol = None
        self.gsd = gsudoku.SudokuGameDisplay()
        if bgcol: self.gsd.set_bg_color(bgcol)
        self.gsd.connect('puzzle-finished',self.you_win_callback)
        self.main_actions = gtk.ActionGroup('MainActions')        
        self.main_actions.add_actions([
            ('Game',None,_('_Game')),
            ('New',gtk.STOCK_NEW,None,
             '<Control>n',_('New game'),self.new_cb),
            ('Print',gtk.STOCK_PRINT,None,
             None,_('Print current game'),self.print_game),
            ('PrintMany',gtk.STOCK_PRINT,_('Print _Multiple Sudokus'),
             None,_('Print more than one sudoku at a time.'),self.print_multiple_games),
            #('Quit',gtk.STOCK_QUIT,None,'<Control>q',
            # 'Quit Sudoku game',self.quit_cb),
            ('Close',gtk.STOCK_CLOSE,None,'<Control>w',
             _('Close Sudoku'),self.quit_cb),
            #('Save',gtk.STOCK_SAVE,_('_Save'),
            # '<Control>s','Save game to play later.',
            # self.save_game),
            #('ByHand',gtk.STOCK_EDIT,_('_Enter custom game'),
            # None,_('Enter new puzzle by hand (use this to copy a puzzle from another source).'),
            # self.enter_game_by_hand),
            #('Open',gtk.STOCK_OPEN,_('_Resume old game'),
            # '<Control>r',_('Resume a previous saved game.'),
            # self.open_game),
            ('Tools',None,_('_Tools')),
            ('View',None,_('_View')),
            ('ShowPossible',gtk.STOCK_DIALOG_INFO,_('_Hint'),
             '<Control>h',
             _('Show which numbers could go in the current square.'),
             self.show_hint_cb),
            ('AutofillCurrentSquare',gtk.STOCK_APPLY,_('_Fill'),'<Control>f',
             _('Automatically fill in the current square if possible.'),
             self.auto_fill_current_square_cb),
            ('Autofill',gtk.STOCK_REFRESH,_('Fill _all squares'),'<Control>a',
             _('Automatically fill in all squares for which there is only one valid value.'),
             self.auto_fill_cb),
            #('ZoomIn',gtk.STOCK_ZOOM_IN,'_Increase size',
            # '<Control>plus','Increase the size of numbers and squares',
            # self.zoom_in_cb),
            #('ZoomOut',gtk.STOCK_ZOOM_OUT,'_Decrease size',
            # '<Control>minus','Decrease the size of numbers and squares.',
            # self.zoom_out_cb),
            ('FullScreen',STOCK_FULLSCREEN,None,
             'F11',None,self.full_screen_cb),
            ('PuzzleInfo',gtk.STOCK_ABOUT,_('Puzzle _Statistics'),
             None,_('Show statistics about current puzzle'),
             self.show_info_cb),
            ('Help',None,_('_Help'),
             None,None,None),
            ('About',gtk.STOCK_ABOUT,None,
             None,None,self.show_about),
            ('ShowHelp',gtk.STOCK_HELP, _('_Contents'),
             'F1',None,self.show_help),
            ('HighScores',None,_('High _Scores'),
             None,_('Show high scores or replay old games.'),
             self.show_high_scores_cb),
            ])
        self.main_actions.add_toggle_actions([
            ('AlwaysShowPossible',
             None,
             _('_Always show hint'),
             None,
             _('Always show possible numbers in a square'),
             self.auto_hint_cb),
            ('ShowImpossibleImplications',
             None,
             _('Warn about _unfillable squares'),
             None,
             _('Warn about squares made unfillable by a move'),
             self.impossible_implication_cb),
            ('Tracker','tracks',_('_Track additions'),
             '<Control>T',
             _('Mark new additions in a separate color so you can keep track of them.'),
             self.tracker_toggle_cb,False),
            #('ZoomOnResize',None,_('_Adjust size of grid when resizing window'),
            # None,_('Automatically change the size of numbers and squares to fit the window.'),
            # ),
            ('ToggleToolbar',None,_('Show _Toolbar'),None,None,self.toggle_toolbar_cb,True),
            #('ToggleNotes',None,_('Show _Notes'),'<Control>O',
            # _('Include room for notes at the top and bottom of squares.'),self.toggle_notes_cb),
            ('ToggleBackground',None,_('_Black background'),
             None,_("Background of game is black; otherwise, the background will follow your theme colors."),
             self.toggle_background_cb,True),
            ('ToggleHighlight',gtk.STOCK_SELECT_COLOR,_('_Highlighter'),
             None,_('Highlight the current row, column and box'),self.toggle_highlight_cb,False),
            ('BackgroundGenerator',None,_('Generate new puzzles _while you play'),
             None,
             _('Generate new puzzles in the background while you play. This will automatically pause when the game goes into the background.'),
             self.toggle_generator_cb, True),
            ])
        
        self.edit_actions = gtk.ActionGroup('EditActions')
        self.edit_actions.add_actions(
            [('Edit',None,_('_Edit')),
             ('Undo',gtk.STOCK_UNDO,_('_Undo'),'<Control>z',_('Undo last action')),
             ('Redo',gtk.STOCK_REDO,_('_Redo'),'<Shift><Control>z',_('Redo last action')),
             ('Clear',gtk.STOCK_CLEAR,_('_Clear'),'<Control>b',_("Clear entries you've filled in"),self.clear_cb),
             ('ClearNotes',gtk.STOCK_CLEAR,_('Clear _Notes'),None,_("Clear notes and hints"),self.clear_notes_cb),             
             # Trackers...
             ('Tracker%s',None,_('No Tracker'),'<Control>0',None,lambda *args: self.set_tracker(-1)),
             ('Generator',None,_('_Generate new puzzles'),None,_('Generate new puzzles.'),
              self.generate_puzzle_gui,),
             ])
        self.edit_actions.add_actions(
            [('Tracker%s'%n,None,'Tracker _%s'%n,'<Control>%s'%n,None,lambda *args: self.set_tracker(n-1)) for
             n in range(1,9)])
        self.uimanager.insert_action_group(self.main_actions,0)
        self.uimanager.insert_action_group(self.edit_actions,0)
        self.uimanager.add_ui_from_string(self.ui)

        # Set up our UNDO stuff
        undo_widg = self.edit_actions.get_action('Undo')
        redo_widg = self.edit_actions.get_action('Redo')
        self.history = Undo.UndoHistoryList(undo_widg,redo_widg)
        for e in self.gsd.__entries__.values():
            Undo.UndoableGenericWidget(e,self.history,
                                       set_method='set_value_from_undo',
                                       pre_change_signal='value-about-to-change'
                                       )
            Undo.UndoableGenericWidget(e,self.history,
                                       set_method='set_notes',
                                       get_method='get_note_text',
                                       signal='notes-changed',
                                       pre_change_signal='value-about-to-change',
                                       )
        # add the accelerator group to our toplevel window
        self.w.add_accel_group(self.uimanager.get_accel_group())
        mb = self.uimanager.get_widget('/MenuBar')
        mb.show()
        self.vb.pack_start(mb,fill=False,expand=False)
        self.tb = self.uimanager.get_widget('/Toolbar')
        #self.tb.show()
        self.vb.pack_start(self.tb,fill=False,expand=False)
        self.main_area = gtk.HBox()
        self.swallower = SwappableArea(self.main_area)
        self.swallower.show()
        self.vb.pack_start(self.swallower,True,padding=12)

        self.main_area.pack_start(self.gsd,padding=6)
        self.main_actions.set_visible(True)
        self.game_box = gtk.VBox()
        self.main_area.show()
        self.vb.show()
        # Set up area for by-hand editing...
        self.by_hand_label = gtk.Label()
        self.by_hand_label.set_alignment(0,0)
        self.by_hand_label.set_markup('<i>%s</i>'%_('Entering custom grid...'))
        self.game_box.pack_start(self.by_hand_label,False,)#padding=12)        
        self.by_hand_buttonbox = gtk.HButtonBox()
        self.by_hand_buttonbox.set_spacing(12)
        self.by_hand_save_button = gtk.Button(_('_Play game'))
        self.by_hand_save_button.connect('clicked',self.save_handmade_grid)
        self.by_hand_cancel_button = gtk.Button(stock=gtk.STOCK_CANCEL)
        self.by_hand_cancel_button.connect('clicked',self.cancel_handmade_grid)
        self.by_hand_buttonbox.add(self.by_hand_cancel_button)
        self.by_hand_buttonbox.add(self.by_hand_save_button)
        self.game_box.pack_start(self.by_hand_buttonbox,False,padding=18)
        self.game_box.show()
        self.by_hand_widgets = [self.by_hand_label,self.by_hand_buttonbox]
        self.main_area.pack_start(self.game_box,False,padding=12)
        # Set up trackers
        self.trackers = {}
        self.setup_tracker_interface()
        self.w.add(self.vb)
        self.statusbar = gtk.Statusbar(); self.statusbar.show()
        gobject.timeout_add(500,self.update_statusbar_cb)
        self.vb.pack_end(self.statusbar,fill=False,expand=False)
        self.worker_connections=[]
        mb.show()
        # sync up toggles with gconf values...
        map(lambda tpl: self.gconf_wrap_toggle(*tpl),
            [('always_show_hints',
              self.main_actions.get_action('AlwaysShowPossible')),
             ('show_impossible_implications',
              self.main_actions.get_action('ShowImpossibleImplications')),
             ('generate_puzzles_in_background',
              self.main_actions.get_action('BackgroundGenerator')),
             ('show_toolbar',
              self.main_actions.get_action('ToggleToolbar')),
             ('bg_black',
              self.main_actions.get_action('ToggleBackground')),
             ('show_tracker',
              self.main_actions.get_action('Tracker')),
             ])
        self.timer.start_timing()
        # setup sudoku maker...
        self.sudoku_maker = sudoku_maker.SudokuMaker()
        self.sudoku_tracker = sudoku_maker.SudokuTracker(self.sudoku_maker)
        #if not self.sudoku_tracker.playing:
        #    self.main_actions.get_action('Open').set_sensitive(False)
        #else:
        #    self.main_actions.get_action('Open').set_sensitive(True)

        if not self.sudoku_tracker.finished:
            self.main_actions.get_action('HighScores').set_sensitive(False)
        # auto-load
        try:
            game = self.gconf['current_game']                
        except:
            self.gconf['current_game']=""
            game = ""
        '''if game:
            try:
                self.sudoku_tracker.open_game(self, game)
            except:
                #print 'We appear to have lost ',game
                try:
                    self.gsd.load_game(game)
                except:
                    puz,d=self.sudoku_tracker.get_new_puzzle(self.gconf['difficulty'])
        else:
        '''
        # select an easy puzzle...
        puz,d=self.sudoku_tracker.get_new_puzzle(self.gconf['difficulty'])
        #print 'Default to ',puz
        self.gsd.change_grid(puz, 9)
        # generate puzzles while our use is working...
        if self.gconf['generate_puzzles_in_background']:
            gobject.timeout_add(1000,lambda *args: self.start_worker_thread() and True)
        self.gsd.show()
        
        self.w.show()

    @simple_debug
    def start_worker_thread (self, *args):
        n_new_puzzles = len(self.sudoku_tracker.list_new_puzzles())
        if n_new_puzzles < self.gconf['minimum_number_of_new_puzzles']:
            self.worker = threading.Thread(target=lambda *args: self.sudoku_maker.work(limit=5))
            self.worker_connections = [
                self.timer.connect('timing-started',self.sudoku_maker.resume),
                self.timer.connect('timing-stopped',self.sudoku_maker.pause)
                ]
            self.worker.start()
        #else:
        #    print 'We already have ',n_new_puzzles,'!'

    @simple_debug
    def stop_worker_thread (self, *args):
        if hasattr(self,'worker'):
            self.sudoku_maker.stop()
            for c in self.worker_connections:
                self.timer.disconnect(c)

    @simple_debug
    def you_win_callback (self,grid):
        self.won = True
        # increase difficulty for next time.
        self.gconf['difficulty']=self.gconf['difficulty']+0.1
        self.timer.finish_timing()
        self.sudoku_tracker.finish_game(self)
        #time_string = "%s (%s active)"%(self.timer.total_time_string(),
        #                                self.timer.active_time_string()
        #                                )
        #sublabel = _("You completed the puzzle in %s")%time_string
        #sublabel += "\n"
        #sublabel += ngettext("You got %(n)s hint","You got %(n)s hints",self.gsd.hints)%{'n':self.gsd.hints}
        #sublabel += "\n"
        #if self.gsd.impossible_hints:
        #    sublabel += ngettext("You had %(n)s impossibility pointed out.",
        #                         "You had %(n)s impossibilities pointed out.",
        #                         self.gsd.impossible_hints)%{'c':self.gsd.impossible_hints}
        #if self.gsd.auto_fills:
        #    sublabel += ngettext("You used the auto-fill %(n)s time",
        #                         "You used the auto-fill %(n)s times",
        #                         self.gsd.auto_fills)%{'n':self.gsd.auto_fills}
        #dialog_extras.show_message("You win!",label="You win!",
        #                           icon=os.path.join(IMAGE_DIR,'winner2.png'),
        #                           sublabel=sublabel
        #                           )
        hs = game_selector.HighScores(self.sudoku_tracker)
        hs.highlight_newest=True
        #hs.run_swallowed_dialog(self.swallower)
        hs.run_dialog()
        self.main_actions.get_action('HighScores').set_sensitive(True)
        #self.gsd.blank_grid()
        self.stop_game()
        self.new_cb()

    @simple_debug
    def initialize_prefs (self):
        for k,v in self.initial_prefs.items():
            try:
                self.gconf[k]
            except:
                self.gconf[k]=v

    @simple_debug
    @inactivate_new_game_etc
    def new_cb (self,*args):
        gs = game_selector.NewGameSelector(self.sudoku_tracker)
        gs.difficulty = self.gconf['difficulty']
        ret =  gs.run_swallowed_dialog(self.swallower)
        if ret:
            puz,d = ret
            self.gconf['difficulty']=d.value
            self.stop_game()
            self.gsd.change_grid(puz,9)
            self.history.clear()
            
    @simple_debug
    def stop_game (self):
        #if self.gsd.grid and self.gsd.grid.is_changed():
        #    self.sudoku_tracker.save_game(self)
        #    self.main_actions.get_action('Open').set_sensitive(True)
        self.tracker_ui.reset()
        self.timer.reset_timer()
        self.timer.start_timing()
        self.won = False
        
    @simple_debug
    def resize_cb (self, widget, event):
        self.gconf['width'] = event.width
        self.gconf['height'] = event.height

    @simple_debug
    def quit_cb (self, *args):
        if gtk.main_level() > 1:
            # If we are in an embedded mainloop, that means that one
            # of our "swallowed" dialogs is active, in which case we
            # have to quit that mainloop before we can quit
            # properly.
            if self.swallower.running:
                d = self.swallower.running
                d.response(gtk.RESPONSE_DELETE_EVENT)
            gtk.main_quit() # Quit the embedded mainloop
            gobject.idle_add(self.quit_cb,100) # Call ourselves again
                                               # to quit the main
                                               # mainloop
            return
            #buttons = d.action_area.get_children()
            #for b in buttons:
            #    if d.get_response_for_widget(b) in [gtk.RESPONSE_CLOSE,gtk.RESPONSE_CANCEL]:
            #        print 'clicking button',b
            #        b.emit('clicked')
            #        while gtk.events_pending():
            #            print 'Take care of iters...'
            #            gtk.main_iteration()
            #        break
        self.w.hide()
        # make sure we really go away before doing our saving --
        # otherwise we appear sluggish.
        while gtk.events_pending():
            gtk.main_iteration()
        if self.won:
            self.gconf['current_game']=''
        if not self.won:
            if not self.gsd.grid:
                self.gconf['current_game']=''
            #else: #always save the game
            #    self.gconf['current_game']=self.sudoku_tracker.save_game(self)
        self.stop_worker_thread()
        #self.sudoku_tracker.save()
        gtk.main_quit()

    @simple_debug
    @inactivate_new_game_etc
    def enter_game_by_hand (self, *args):
        self.stop_game()
        self.gsd.change_grid(sudoku.InteractiveSudoku(),9)
        for w in self.by_hand_widgets: w.show_all()
        
    @simple_debug
    def save_handmade_grid (self, *args):
        for w in self.by_hand_widgets: w.hide()
        # this should make our active grid into our virgin grid
        self.won = False
        self.gsd.change_grid(self.gsd.grid,9)
        self.sudoku_maker.names[self.gsd.grid.to_string()]=self.sudoku_maker.get_puzzle_name('Custom Puzzle')
        self.history.clear()

    @simple_debug
    def cancel_handmade_grid (self, *args):
        for w in self.by_hand_widgets: w.hide()

    @simple_debug
    @inactivate_new_game_etc    
    def open_game (self, *args):

	#disabled!
	return;
	
        #game_file = dialog_extras.getFileOpen(_("Load saved game"),
        #                        default_file=os.path.join(DATA_DIR,'games/')
        #                        )        
        #saver.unpickle_game(self, game_file)
        #ifi = file(game_file,'r')
        #self.gsd.load_game(ifi.read())
        #ifi.close()
        puzzl=game_selector.OldGameSelector(self.sudoku_tracker).run_swallowed_dialog(self.swallower)
        if puzzl:
            self.stop_game()
            saver.open_game(self,puzzl)
            self.history.clear()

    @simple_debug
    def save_game (self, *args):
        save_to_dir=os.path.join(DATA_DIR,'games/')
        if not os.path.exists(save_to_dir):
            os.makedirs(save_to_dir)
        game_number = 1
        while os.path.exists(
            os.path.join(save_to_dir,"game%s"%game_number)
            ):
            game_number+=1
        game_loc = os.path.join(save_to_dir,
                             "game%s"%game_number)
        saver.pickle_game(self, game_loc)
        return game_loc
    
    @simple_debug
    def zoom_in_cb (self,*args):
        self.gh.change_font_size(multiplier=1.1)
        self.zoom = self.zoom * 1.1        

    @simple_debug
    def zoom_out_cb (self,*args):
        self.gh.change_font_size(multiplier=0.9)
        self.zoom = self.zoom * 0.9

    def full_screen_cb (self, *args):
        if not hasattr(self,'is_fullscreen'): self.is_fullscreen = False
        if self.is_fullscreen:
            self.w.unfullscreen()
            self.is_fullscreen = False
        else:
            self.w.fullscreen()
            self.is_fullscreen = True
        
    @simple_debug
    def clear_cb (self,*args):        
        clearer=Undo.UndoableObject(
            lambda *args: self.cleared.append(self.gsd.reset_grid()), #action
            lambda *args: [self.gsd.add_value_to_ui(*entry) for entry in self.cleared.pop()], #inverse
            self.history #history
            )
        clearer.perform()

    def clear_notes_cb (self, *args):
        clearer = Undo.UndoableObject(
            lambda *args: self.cleared_notes.append(self.gsd.clear_notes()), #action
            # clear_notes returns a list of tuples indicating the cleared notes...
            # (x,y,(top,bottom)) -- this is what we need for undoing
            lambda *args: [self.gsd.__entries__[t[0],t[1]].set_notes(t[2]) for t in self.cleared_notes.pop()], #inverse
            self.history
            )
        clearer.perform()

    @simple_debug
    def show_hint_cb (self, *args):
        self.gsd.show_hint()

    @simple_debug
    def auto_hint_cb (self, action):
        if action.get_active():
            self.gsd.always_show_hints = True
            self.gsd.update_all_hints()
        else:
            self.gsd.always_show_hints = False            
            self.gsd.clear_hints()

    @simple_debug
    def impossible_implication_cb (self, action):
        if action.get_active():
            self.gsd.show_impossible_implications = True
        else:
            self.gsd.show_impossible_implications = False

    @simple_debug
    def auto_fill_cb (self, *args):
        if not hasattr(self,'autofilled'): self.autofilled=[]
        if not hasattr(self,'autofiller'):
            self.autofiller = Undo.UndoableObject(
                lambda *args: self.autofilled.append(self.gsd.auto_fill()),
                lambda *args: [self.gsd.remove(entry[0],entry[1],do_removal=True) for entry in self.autofilled.pop()],
                self.history
                )
        self.autofiller.perform()

    @simple_debug
    def auto_fill_current_square_cb (self, *args):
        self.gsd.auto_fill_current_entry()

    @simple_debug
    def setup_tracker_interface (self):
        self.tracker_ui = TrackerBox(self)
        self.tracker_ui.show_all()
        self.tracker_ui.hide()
        self.game_box.add(self.tracker_ui)

    @simple_debug
    def set_tracker (self, n):
        if self.gsd.trackers.has_key(n):
            self.tracker_ui.select_tracker(n)
            e = self.gsd.get_focused_entry()
            if e:
                if n==-1:
                    for tid in self.gsd.trackers_for_point(e.x,e.y):
                        self.gsd.remove_tracker(e.x,e.y,tid)
                else:
                    self.gsd.add_tracker(e.x,e.y,n)
        else:
            print 'No tracker ',n,'yet'
        
    @simple_debug
    def tracker_toggle_cb (self, widg):
        if widg.get_active():
            #if len(self.tracker_ui.tracker_model)<=1:
            #    self.tracker_ui.add_tracker()
            self.tracker_ui.show_all()
        else:
            self.tracker_ui.hide()

    @simple_debug
    def toggle_toolbar_cb (self, widg):
        if widg.get_active(): self.tb.show()
        else: self.tb.hide()

    def update_statusbar_cb (self, *args):
        if not self.gsd.grid: return
        puzz = self.gsd.grid.virgin.to_string()
        if (not hasattr(self,'current_puzzle_string') or
            self.current_puzzle_string != puzz):
            if not self.sudoku_tracker.sudoku_maker.names.has_key(puzz):
                self.sudoku_tracker.sudoku_maker.names[puzz] = self.sudoku_tracker.sudoku_maker.get_puzzle_name(puzz)
            self.current_puzzle_string = puzz
            self.current_puzzle_name = self.sudoku_tracker.sudoku_maker.names[puzz]
            if len(self.current_puzzle_name)>18: self.current_puzzle_name = self.current_puzzle_name[:17]+u'\u2026'
            self.current_puzzle_diff = self.sudoku_tracker.get_difficulty(puzz)
        tot_string = _("Playing ") + self.current_puzzle_name
        tot_string += " - " + "%s"%self.current_puzzle_diff.value_string()
        tot_string += " " + "(%1.2f)"%self.current_puzzle_diff.value
        #if self.timer.tot_time or self.timer.tot_time_complete:
        #    time_string = _("%s (%s active)")%(
        #        self.timer.total_time_string(),
        #        self.timer.active_time_string()
        #        )
        #    if not self.timer.__timing__:
        #        time_string += " %s"%_('paused')
        #    tot_string += " - " + time_string
        #if self.gsd.hints and not self.gconf['always_show_hints']:
        #    tot_string += " -  " +ngettext("%(n)s hint","%(n)s hints",
        #                           self.gsd.hints)%{'n':self.gsd.hints}
        #if self.gsd.auto_fills:
        #    tot_string += "  " +ngettext("%(n)s auto-fill","%(n)s auto-fills",
        #                            self.gsd.auto_fills)%{'n':self.gsd.auto_fills}
        if not hasattr(self,'sbid'):
            self.sbid = self.statusbar.get_context_id('game_info')
        self.statusbar.pop(self.sbid)
        self.statusbar.push(self.sbid,
                            tot_string)
        return True

    @simple_debug
    def toggle_background_cb (self, widg):
        if widg.get_active():
            self.gsd.set_bg_color('black')
        else:
            self.gsd.set_bg_color(None)

    def toggle_highlight_cb (self, widg):
        if widg.get_active():
            self.gsd.toggle_highlight(True)
        else:
            self.gsd.toggle_highlight(False)

    @simple_debug
    def show_info_cb (self, *args):
        if not self.gsd.grid:
            dialog_extras.show_message(parent=self.w,
                                       title=_("Puzzle Information"),
                                       label=_("There is no current puzzle.")
                                       )
            return
        puzzle = self.gsd.grid.virgin.to_string()
        diff = self.sudoku_tracker.get_difficulty(puzzle)
        information = _("Calculated difficulty: ")
        information += diff.value_string()
        information += " (%1.2f)"%diff.value
        information += "\n"
        information += _("Number of moves instantly fillable by elimination: ")
        information += str(int(diff.instant_elimination_fillable))
        information += "\n"
        information += _("Number of moves instantly fillable by filling: ")
        information += str(int(diff.instant_fill_fillable))
        information += "\n"
        information += _("Amount of trial-and-error required to solve: ")
        information += str(len(diff.guesses))
        if not self.sudoku_tracker.sudoku_maker.names.has_key(puzzle):
            self.sudoku_tracker.sudoku_maker.names[puzzle]=self.sudoku_tracker.sudoku_maker.get_puzzle_name(
                _('Puzzle'))
        name = self.sudoku_tracker.sudoku_maker.names[puzzle]
        dialog_extras.show_message(parent=self.w,
                                   title=_("Puzzle Information"),
                                   label=_("Statistics for %s")%name,
                                   sublabel=information)
        

    @simple_debug
    def toggle_generator_cb (self, toggle):
        if toggle.get_active():
            self.start_worker_thread()
        else:
            self.stop_worker_thread()

    @simple_debug
    def show_high_scores_cb (self, *args):
        hs=game_selector.HighScores(self.sudoku_tracker)
        replay_game = hs.run_dialog()
        if replay_game:
            self.stop_game()
            self.gsd.change_grid(replay_game,9)

    @simple_debug
    def show_about (self, *args):
        about = gtk.AboutDialog()
        about.set_name(APPNAME)
        about.set_version(VERSION)
        about.set_copyright(COPYRIGHT)
	about.set_license(LICENSE[0] + '\n\n' + LICENSE[1] + '\n\n' +LICENSE[2])
	about.set_wrap_license(True)
        about.set_comments(DESCRIPTION)
        about.set_authors(AUTHORS)
        about.set_website("http://www.gnome.org/projects/gnome-games/")
        about.set_logo_icon_name("gnome-sudoku")
        about.set_translator_credits(_("translator-credits"))
        about.connect("response", lambda d, r: d.destroy())
        about.show()

    @simple_debug
    def show_help (self, *args):
        #dialog_extras.show_faq(faq_file=os.path.join(BASE_DIR,_('FAQ')))
        try:
            gnome.help_display('gnome-sudoku')
        except gobject.GError, e:
            # FIXME: This should create a pop-up dialog
            print _('Unable to display help: %s') % str(e)

    @simple_debug
    def print_game (self, *args):
        printing.print_sudokus([self.gsd])

    @simple_debug
    def print_multiple_games (self, *args):
        gp=game_selector.GamePrinter(self.sudoku_tracker, self.gconf)
        gp.run_dialog()

    @simple_debug
    def generate_puzzle_gui (self, *args):
        sudoku_generator_gui.GameGenerator(self,self.gconf)

class TrackerBox (gtk.VBox):

    @simple_debug
    def __init__ (self, main_ui):
        
        gtk.VBox.__init__(self)
        self.glade = gtk.glade.XML(os.path.join(GLADE_DIR,'tracker.glade'))
        self.main_ui = main_ui
        self.vb = self.glade.get_widget('vbox1')
        self.vb.unparent()
        self.pack_start(self.vb,expand=True,fill=True)
        self.setup_actions()
        self.setup_tree()
        self.show_all()

    @simple_debug
    def reset (self):
        
        for tree in self.tracker_model:
            if tree[0]>-1:
                self.tracker_model.remove(tree.iter)

    @simple_debug
    def setup_tree (self):
        self.tracker_tree = self.glade.get_widget('treeview1')
        self.tracker_model = gtk.ListStore(int,gtk.gdk.Pixbuf,str)
        self.tracker_tree.set_model(self.tracker_model)
        col1 = gtk.TreeViewColumn("",gtk.CellRendererPixbuf(),pixbuf=1)
        col2 = gtk.TreeViewColumn("",gtk.CellRendererText(),text=2)
        self.tracker_tree.append_column(col2)
        self.tracker_tree.append_column(col1)
        # Our initial row...
        self.tracker_model.append([-1,None,_('No Tracker')])
        self.tracker_tree.get_selection().connect('changed',self.selection_changed_cb)

    @simple_debug
    def setup_actions (self):
        self.tracker_actions = gtk.ActionGroup('tracker_actions')        
        self.tracker_actions.add_actions(
            [('Clear',
              gtk.STOCK_CLEAR,
              _('_Clear Tracker'),
              None,_('Clear all moves tracked by selected tracker.'),
              self.clear_cb
              ),
             ('Keep',None,
              _('_Clear Others'),
              None,
              _('Clear all moves not tracked by selected tracker.'),
              self.keep_cb),
             ]
            )
        for action,widget_name in [('Clear','ClearTrackerButton'),
                                   ('Keep','KeepTrackerButton'),
                                   ]:
            a=self.tracker_actions.get_action(action)
            a.connect_proxy(self.glade.get_widget(widget_name))
        self.glade.get_widget('AddTrackerButton').connect('clicked',
                                                          self.add_tracker)
        # Default to insensitive (they only become sensitive once a tracker is added)
        self.tracker_actions.set_sensitive(False)

    @simple_debug
    def add_tracker (self,*args):
        #print 'Adding tracker!'
        tracker_id = self.main_ui.gsd.create_tracker()
        #print 'tracker_id = ',tracker_id
        pb=image_extras.pixbuf_transform_color(
            STOCK_PIXBUFS['tracks'],
            (0,0,0),#white
            self.main_ui.gsd.get_tracker_color(tracker_id),
            )
        # select our new tracker
        self.tracker_tree.get_selection().select_iter(
            self.tracker_model.append([tracker_id,
                                  pb,
                                  _("Tracker %s")%(tracker_id+1)]
                                  )
            )
        
    @simple_debug
    def select_tracker (self, tracker_id):
        for row in self.tracker_model:
            if row[0]==tracker_id:
                self.tracker_tree.get_selection().select_iter(row.iter)

    @simple_debug
    def selection_changed_cb (self, selection):
        mod,itr = selection.get_selected()
        if itr: selected_tracker_id = mod.get_value(itr,0)
        else: selected_tracker_id=-1
        # This should be cheap since we don't expect many trackers...
        # We cycle through each row and toggle it off if it's not
        # selected; on if it is selected
        for row in self.tracker_model:
            tid = row[0]
            if tid != -1: # -1 == no tracker
                self.main_ui.gsd.toggle_tracker(tid,tid==selected_tracker_id)
        self.tracker_actions.set_sensitive(selected_tracker_id != -1)

    @simple_debug
    def clear_cb (self, action):
        mod,itr=self.tracker_tree.get_selection().get_selected()
        # This should only be called if there is an itr, but we'll
        # double-check just in case.
        if itr:
            selected_tracker_id=mod.get_value(itr,0)
            self.tracker_delete_tracks(selected_tracker_id)

    @simple_debug
    def keep_cb (self, action):
        mod,itr=self.tracker_tree.get_selection().get_selected()
        selected_tracker_id=mod.get_value(itr,0)
        self.tracker_keep_tracks(selected_tracker_id)

    @simple_debug
    def tracker_delete_tracks (self, tracker_id):
        clearer=Undo.UndoableObject(
            lambda *args: self.main_ui.cleared.append(self.main_ui.gsd.delete_by_tracker(tracker_id)),
            lambda *args: [self.main_ui.gsd.add_value(*entry) for entry in self.main_ui.cleared.pop()],
            self.main_ui.history)
        clearer.perform()

    @simple_debug
    def tracker_keep_tracks (self, tracker_id):
        clearer=Undo.UndoableObject(
            lambda *args: self.main_ui.cleared.append(self.main_ui.gsd.delete_except_for_tracker(tracker_id)),
            lambda *args: [self.main_ui.gsd.add_value(*entry) for entry in self.main_ui.cleared.pop()],
            self.main_ui.history)
        clearer.perform()


class GamesTracker (sudoku_maker.SudokuTracker):

    @simple_debug
    def __init__ (self, sudoku_maker):
        SudokuTracker.__init__(self, sudoku_maker)

    @simple_debug
    def build_model (self):
        # puzzle / difficulty / % completed / game started / game finished
        self.model = gtk.TreeModel(str, str )

def start_game ():
    if options.debug: print 'Starting GNOME Sudoku in debug mode'

    ##  You must call g_thread_init() before executing any other GLib
    ##  functions in a threaded GLib program.
    gobject.threads_init()

    if options.profile:
        options.profile = False
        profile_me()
        return

    u = UI()

    try:
        gtk.main()        
    except KeyboardInterrupt:
        # properly quit on a keyboard interrupt...
        u.quit_cb()

def profile_me ():
    print 'Profiling GNOME Sudoku'
    import tempfile,os.path
    import hotshot, hotshot.stats
    pname = os.path.join(tempfile.gettempdir(),'GNOME_SUDOKU_HOTSHOT_PROFILE')
    prof = hotshot.Profile(pname)
    prof.runcall(start_game)
    stats = hotshot.stats.load(pname)
    stats.strip_dirs()
    stats.sort_stats('time','calls').print_stats()    

    
        
        
if __name__ == '__main__':
    import defaults
    defaults.DATA_DIR == '/tmp/'; DATA_DIR=='/tmp/'
    
    
