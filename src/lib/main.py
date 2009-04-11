# -*- coding: utf-8 -*-
try:
    import pygtk
    pygtk.require('2.0')
except ImportError, err:
    print ("PyGTK not found. Please make sure it is installed properly and referenced in your PYTHONPATH environment variable.")

import gtk, gobject
import os, os.path
from gtk_goodies import gconf_wrapper, Undo, dialog_extras
import gsudoku, saver, sudoku_maker, printing, sudoku_generator_gui
import game_selector
import threading
from gettext import gettext as _
from gettext import ngettext
from defaults import *
from timer import ActiveTimer
from simple_debug import simple_debug,options
from dialog_swallower import SwappableArea

icon_factory = gtk.IconFactory()
STOCK_PIXBUFS = {}
for filename,stock_id in [('footprints.png','tracks'),]:
    try:
        pb = gtk.gdk.pixbuf_new_from_file(os.path.join(IMAGE_DIR,filename))
    except gobject.GError, e:
        print 'Failed to load pixbuf: %s' % e
        continue
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
            '/MenuBar/Game/Print',
            # undo/redo is handled elsewhere as it can't simply be turned on/off.
            '/MenuBar/Edit/Clear',
            '/MenuBar/Edit/ClearNotes',
            '/MenuBar/View/ToggleToolbar',
            '/MenuBar/Tools/ShowPossible',
            '/MenuBar/Tools/AutofillCurrentSquare',
            '/MenuBar/Tools/Autofill',
            '/MenuBar/Tools/AlwaysShowPossible',
            '/MenuBar/Tools/ShowImpossibleImplications',
            '/MenuBar/Tools/Tracker',
            '/MenuBar/Game/PuzzleInfo',
            ]
        for p in paths:
            action = ui.uimanager.get_action(p)
            if not action: action = ui.uimanager.get_widget(p)
            if not action: print 'No action at path',p
            else: action.set_sensitive(False)
        ret = fun(ui,*args,**kwargs)
        for p in paths:
            action = ui.uimanager.get_action(p)
            if not action: action = ui.uimanager.get_widget(p)
            if not action: print 'No action at path',p
            else: action.set_sensitive(True)
        return ret
    return _

class UI (gconf_wrapper.GConfWrapper):
    ui='''<ui>
    <menubar name="MenuBar">
      <menu name="Game" action="Game">
        <menuitem action="New"/>
        <separator/>
        <menuitem action="PuzzleInfo"/>
        <separator/>
        <menuitem action="Print"/>
        <menuitem action="PrintMany"/>
        <separator/>
        <menuitem action="Close"/>
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
        <menuitem action="Generator"/>
        <menuitem action="BackgroundGenerator"/>
        <separator/>
        <menuitem action="Tracker"/>
        </menu>
      <menu action="Help">
        <menuitem action="ShowHelp"/>
        <menuitem action="About"/>
      </menu>
    </menubar>
    <toolbar name="Toolbar">
      <toolitem action="New"/>
      <toolitem action="Print"/>
      <separator/>
      <toolitem action="Undo"/>
      <toolitem action="Redo"/>
      <separator/>
      <toolitem action="ShowPossible"/>
      <toolitem action="AutofillCurrentSquare"/>
      <separator/>
      <toolitem action="ToggleHighlight"/>
      <toolitem action="Tracker"/>
    </toolbar>
    </ui>'''

    initial_prefs = {'group_size':9,
                     'always_show_hints':0,
                     'player':os.environ.get('USERNAME',''),
                     'difficulty':0.0,
                     'minimum_number_of_new_puzzles':MIN_NEW_PUZZLES,
                     'highlight':0,
                     'bg_black':1,
                     'bg_custom_color':'',
                     'show_tracker':False,
                     'width': 700,
                     'height': 675,
                     'auto_save_interval':60 # auto-save interval in seconds...
                     }

    @simple_debug
    def __init__ (self, run_selector=True):
        """run_selector means that we start our regular game.

        For testing purposes, it will be convenient to hand a
        run_selector=False to this method to avoid running the dialog
        and allow a tester to set up a game programmatically.
        """
        gconf_wrapper.GConfWrapper.__init__(self,
                                            gconf_wrapper.GConf('gnome-sudoku')
                                            )
        self.setup_gui()
        self.timer = ActiveTimer(self.w)
        self.won = False
        # add the accelerator group to our toplevel window
        self.worker_connections=[]
        # setup sudoku maker...
        self.sudoku_maker = sudoku_maker.SudokuMaker()
        self.sudoku_tracker = saver.SudokuTracker()
        # generate puzzles while our use is working...
        self.show()
        if run_selector:
            self.do_stop()
            if self.select_game():
                # If this return True, the user closed...
                self.quit = True
            else:
                self.quit = False
                # Generate puzzles in background...
                if self.gconf['generate_puzzles_in_background']:
                    gobject.timeout_add_seconds(1,lambda *args: self.start_worker_thread() and True)


    @inactivate_new_game_etc
    def select_game (self):
        self.tb.hide()
        self.update_statusbar()
        choice = game_selector.NewOrSavedGameSelector().run_swallowed_dialog(self.swallower)
        if not choice:
            return True
        self.timer.start_timing()
        if choice[0] == game_selector.NewOrSavedGameSelector.NEW_GAME:
            self.gsd.change_grid(choice[1],9)
            self.update_statusbar()
        if choice[0] == game_selector.NewOrSavedGameSelector.SAVED_GAME:
            saver.open_game(self,choice[1])
            self.update_statusbar()
        if self.gconf['show_toolbar']:
            self.tb.show()
        if self.gconf['always_show_hints']:
            self.gsd.update_all_hints()
        if self.gconf['highlight']:
            self.gsd.toggle_highlight(True)


    def show (self):
        self.gsd.show()
        self.w.show()

    def setup_gui (self):
        self.initialize_prefs()
        self.setup_main_window()
        self.gsd = gsudoku.SudokuGameDisplay()
        self.gsd.connect('puzzle-finished',self.you_win_callback)
        self.setup_color()
        self.setup_actions()
        self.setup_undo()
        self.setup_autosave()
        self.w.add_accel_group(self.uimanager.get_accel_group())
        self.setup_main_boxes()
        self.setup_tracker_interface()
        self.setup_toggles()

    def setup_main_window (self):
        gtk.window_set_default_icon_name('gnome-sudoku')
        self.w = gtk.Window()
        self.w.set_default_size(self.gconf['width'], self.gconf['height'])
        self.w.set_title(APPNAME_SHORT)
        self.w.connect('configure-event',self.resize_cb)
        self.w.connect('delete-event',self.quit_cb)
        self.uimanager = gtk.UIManager()

    def setup_actions (self):
        self.main_actions = gtk.ActionGroup('MainActions')
        self.main_actions.add_actions([
            ('Game',None,_('_Game')),
            ('New',gtk.STOCK_NEW,None,
             '<Control>n',_('New game'),self.new_cb),
            ('Print',gtk.STOCK_PRINT,None,
             None,_('Print current game'),self.print_game),
            ('PrintMany',gtk.STOCK_PRINT,_('Print _Multiple Sudokus'),
             None,_('Print more than one sudoku at a time.'),self.print_multiple_games),
            ('Close',gtk.STOCK_CLOSE,None,'<Control>w',
             _('Close Sudoku'),self.quit_cb),
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
            ('ToggleToolbar',None,_('Show _Toolbar'),None,None,self.toggle_toolbar_cb,True),
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
             ('Undo',gtk.STOCK_UNDO,_('_Undo'),'<Control>z',_('Undo last action'), self.stop_dancer),
             ('Redo',gtk.STOCK_REDO,_('_Redo'),'<Shift><Control>z',_('Redo last action')),
             ('Clear',gtk.STOCK_CLEAR,_('_Clear'),'<Control>b',_("Clear entries you've filled in"),self.clear_cb),
             ('ClearNotes',None,_('Clear _Notes'),None,_("Clear notes and hints"),self.clear_notes_cb),
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

    def setup_undo (self):
        self.cleared = [] # used for Undo memory
        self.cleared_notes = [] # used for Undo memory
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

    def setup_color (self):
        # setup background colors
        if self.gconf['bg_custom_color']:
            bgcol = self.gconf['bg_custom_color']
        elif self.gconf['bg_black']:
            bgcol = 'black'
        else:
            bgcol = None
        if bgcol: self.gsd.set_bg_color(bgcol)

    def setup_autosave (self):
        gobject.timeout_add_seconds(self.gconf['auto_save_interval'] or 60, # in seconds...
                            self.autosave)

    def setup_main_boxes (self):
        self.vb = gtk.VBox()
        # Add menu bar and toolbar...
        mb = self.uimanager.get_widget('/MenuBar'); mb.show()
        self.vb.pack_start(mb,fill=False,expand=False)
        self.tb = self.uimanager.get_widget('/Toolbar')
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
        self.game_box.show()
        self.main_area.pack_start(self.game_box,False,padding=12)
        self.statusbar = gtk.Statusbar(); self.statusbar.show()
        self.vb.pack_end(self.statusbar,fill=False,expand=False)
        self.w.add(self.vb)

    def setup_toggles (self):
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
             ('highlight',
              self.main_actions.get_action('ToggleHighlight')),
             ('show_tracker',
              self.main_actions.get_action('Tracker')),
             ])

    @simple_debug
    def start_worker_thread (self, *args):
        n_new_puzzles = self.sudoku_maker.n_puzzles(new=True)
        if n_new_puzzles < self.gconf['minimum_number_of_new_puzzles']:
            self.worker = threading.Thread(target=lambda *args: self.sudoku_maker.work(limit=5))
            self.worker_connections = [
                self.timer.connect('timing-started',self.sudoku_maker.resume),
                self.timer.connect('timing-stopped',self.sudoku_maker.pause)
                ]
            self.worker.start()
        return True

    @simple_debug
    def stop_worker_thread (self, *args):
        if hasattr(self,'worker'):
            self.sudoku_maker.stop()
            for c in self.worker_connections:
                self.timer.disconnect(c)

    def stop_dancer (self, *args):
        if hasattr(self, 'dancer'):
             self.dancer.stop_dancing()
             delattr(self, 'dancer')

    @simple_debug
    def you_win_callback (self,grid):
        if hasattr(self, 'dancer'):
            return
        self.won = True
        # increase difficulty for next time.
        self.gconf['difficulty']=self.gconf['difficulty']+0.1
        self.timer.finish_timing()
        self.sudoku_tracker.finish_game(self)
        sublabel = _("You completed the puzzle in %(totalTime)s (%(activeTime)s active)")%{'totalTime': self.timer.total_time_string(),
        'activeTime': self.timer.active_time_string()
                }
        sublabel += "\n"
        sublabel += ngettext("You got %(n)s hint","You got %(n)s hints",self.gsd.hints)%{'n':self.gsd.hints}
        sublabel += "\n"
        if self.gsd.impossible_hints:
            sublabel += ngettext("You had %(n)s impossibility pointed out.",
                                 "You had %(n)s impossibilities pointed out.",
                                 self.gsd.impossible_hints)%{'n':self.gsd.impossible_hints}
            sublabel += "\n"
        if self.gsd.auto_fills:
            sublabel += ngettext("You used the auto-fill %(n)s time",
                                 "You used the auto-fill %(n)s times",
                                 self.gsd.auto_fills)%{'n':self.gsd.auto_fills}
        from gsudoku import GridDancer
        self.dancer = GridDancer(self.gsd)
        self.dancer.start_dancing()
        dialog_extras.show_message(_("You win!"),label=_("You win!"),
                                   sublabel=sublabel
                                   )

    @simple_debug
    def initialize_prefs (self):
        for k,v in self.initial_prefs.items():
            try:
                self.gconf[k]
            except:
                self.gconf[k]=v
        self.player = self.gconf['player']

    @simple_debug
    @inactivate_new_game_etc
    def new_cb (self,*args):
        if (self.gsd.grid and self.gsd.grid.is_changed() and not self.won):
            try:
                if dialog_extras.getBoolean(
                    label=_("Save this game before starting new one?"),
                    custom_yes=_("_Save game for later"),
                    custom_no=_("_Abandon game"),
                    ):
                    self.save_game()
                else:
                    self.sudoku_tracker.abandon_game(self)
            except dialog_extras.UserCancelledError:
                # User cancelled new game
                return
        self.do_stop()
        self.select_game()


    @simple_debug
    def stop_game (self):
       if (self.gsd.grid
            and self.gsd.grid.is_changed()
            and (not self.won)):
            try:
                if dialog_extras.getBoolean(label=_("Save game before closing?")):
                    self.save_game(self)
            except dialog_extras.UserCancelledError:
                return
            self.do_stop()

    def do_stop (self):
        self.stop_dancer()
        self.gsd.grid = None
        self.tracker_ui.reset()
        self.history.clear()
        self.won = False

    @simple_debug
    def resize_cb (self, widget, event):
        self.gconf['width'] = event.width
        self.gconf['height'] = event.height

    @simple_debug
    def quit_cb (self, *args):
        self.w.hide()
        if (self.gsd.grid
            and self.gsd.grid.is_changed()
            and (not self.won)):
            self.save_game(self)
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
        # make sure we really go away before doing our saving --
        # otherwise we appear sluggish.
        while gtk.events_pending():
            gtk.main_iteration()
        if self.won:
            self.gconf['current_game']=''
        if not self.won:
            if not self.gsd.grid:
                self.gconf['current_game']=''
        self.stop_worker_thread()
        # allow KeyboardInterrupts, which calls quit_cb outside the main loop
        try:
            gtk.main_quit()
        except RuntimeError, e:
            pass

    @simple_debug
    def save_game (self, *args):
        self.sudoku_tracker.save_game(self)

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
            self.do_clear, #action
            self.undo_clear, #inverse
            self.history #history
            )
        clearer.perform()

    # add a check to stop the dancer if she is dancing
    def do_clear (self, *args):
        self.cleared.append(self.gsd.reset_grid())
        self.stop_dancer()

    # add a check for finish in the undo to clear
    def undo_clear (self, *args):
        for entry in self.cleared.pop():
            self.gsd.add_value(*entry)
        if self.gsd.grid.check_for_completeness():
            self.gsd.emit('puzzle-finished')

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
                self.do_auto_fill,
                self.undo_auto_fill,
                self.history
                )
        self.autofiller.perform()

    def do_auto_fill (self, *args):
        self.autofilled.append(self.gsd.auto_fill())
        if self.gconf['always_show_hints']:
            self.gsd.update_all_hints()

    def undo_auto_fill (self, *args):
        for entry in self.autofilled.pop():
            self.gsd.remove(entry[0],entry[1],do_removal=True)
        if self.gconf['always_show_hints']:
            self.gsd.update_all_hints()

    @simple_debug
    def auto_fill_current_square_cb (self, *args):
        self.gsd.auto_fill_current_entry()

    @simple_debug
    def setup_tracker_interface (self):
        self.trackers = {}
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
            self.tracker_ui.show_all()
        else:
            self.tracker_ui.hide()

    @simple_debug
    def toggle_toolbar_cb (self, widg):
        if widg.get_active(): self.tb.show()
        else: self.tb.hide()

    def set_statusbar_value (self, status):
        if not hasattr(self,'sbid'):
            self.sbid = self.statusbar.get_context_id('game_info')
        self.statusbar.pop(self.sbid)
        self.statusbar.push(self.sbid, status)


    def update_statusbar (self, *args):
        if not self.gsd.grid:
            self.set_statusbar_value(" ")
            return True

        puzzle = self.gsd.grid.virgin.to_string()
        puzzle_diff = self.sudoku_maker.get_difficulty(puzzle)

        tot_string = _("Playing %(difficulty)s puzzle.")%{'difficulty':puzzle_diff.value_string()}
        tot_string += " " + "(%1.2f)"%puzzle_diff.value

        self.set_statusbar_value(tot_string)
        return True

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
        diff = self.sudoku_maker.get_difficulty(puzzle)
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
        dialog_extras.show_message(parent=self.w,
                                   title=_("Puzzle Statistics"),
                                   label=_("Puzzle Statistics"),
                                   sublabel=information)

    @simple_debug
    def toggle_generator_cb (self, toggle):
        if toggle.get_active():
            self.start_worker_thread()
        else:
            self.stop_worker_thread()

    @simple_debug
    def autosave (self):
        # this is called on a regular loop and will autosave if we
        # have reason to...
        if self.gsd.grid and self.gsd.grid.is_changed() and not self.won:
            self.sudoku_tracker.save_game(self)
        return True

    @simple_debug
    def show_about (self, *args):
        about = gtk.AboutDialog()
        about.set_transient_for(self.w)
        about.set_name(APPNAME)
        about.set_version(VERSION)
        about.set_copyright(COPYRIGHT)
        about.set_license(LICENSE[0] + '\n\n' + LICENSE[1] + '\n\n' +LICENSE[2])
        about.set_wrap_license(True)
        about.set_comments(DESCRIPTION)
        about.set_authors(AUTHORS)
        about.set_website(WEBSITE)
        about.set_website_label(WEBSITE_LABEL)
        about.set_logo_icon_name("gnome-sudoku")
        about.set_translator_credits(_("translator-credits"))
        about.connect("response", lambda d, r: d.destroy())
        about.show()

    @simple_debug
    def show_help (self, *args):
        try:
            gtk.show_uri(self.w.get_screen(), "ghelp:gnome-sudoku", gtk.get_current_event_time())
        except gobject.GError, e:
            # FIXME: This should create a pop-up dialog
            print _('Unable to display help: %s') % str(e)

    @simple_debug
    def print_game (self, *args):
        printing.print_sudokus([self.gsd], self.w)

    @simple_debug
    def print_multiple_games (self, *args):
        gp=printing.GamePrinter(self.sudoku_maker, self.gconf)
        gp.run_dialog()

    @simple_debug
    def generate_puzzle_gui (self, *args):
        sudoku_generator_gui.GameGenerator(self,self.gconf)

class TrackerBox (gtk.VBox):

    @simple_debug
    def __init__ (self, main_ui):

        gtk.VBox.__init__(self)
        self.builder = gtk.Builder()
        self.builder.add_from_file(os.path.join(UI_DIR,'tracker.ui'))
        self.main_ui = main_ui
        self.vb = self.builder.get_object('vbox1')
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
        self.tracker_tree = self.builder.get_object('treeview1')
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
            a.connect_proxy(self.builder.get_object(widget_name))
        self.builder.get_object('AddTrackerButton').connect('clicked',
                                                          self.add_tracker)
        # Default to insensitive (they only become sensitive once a tracker is added)
        self.tracker_actions.set_sensitive(False)

    @simple_debug
    def add_tracker (self,*args):
        tracker_id = self.main_ui.gsd.create_tracker()
        pb = self.pixbuf_transform_color(
            STOCK_PIXBUFS['tracks'],
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
    def pixbuf_transform_color (self, pb, tc):
        """Return new pixbuf with color changed to tc"""
        pb_str = pb.get_pixels()
        pb_str_new = ""

        for alpha in pb_str[3::4]:
            pb_str_new += chr(int(tc[0]*255))
            pb_str_new += chr(int(tc[1]*255))
            pb_str_new += chr(int(tc[2]*255))
            pb_str_new += alpha

        return gtk.gdk.pixbuf_new_from_data(pb_str_new, gtk.gdk.COLORSPACE_RGB, True, 8, pb.get_width(), pb.get_height(), pb.get_rowstride())

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
    if not u.quit:
        try:
            gtk.main()
        except KeyboardInterrupt:
            # properly quit on a keyboard interrupt...
            u.quit_cb()

def profile_me ():
    print 'Profiling GNOME Sudoku'
    import tempfile, hotshot, hotshot.stats
    pname = os.path.join(tempfile.gettempdir(),'GNOME_SUDOKU_HOTSHOT_PROFILE')
    prof = hotshot.Profile(pname)
    prof.runcall(start_game)
    stats = hotshot.stats.load(pname)
    stats.strip_dirs()
    stats.sort_stats('time','calls').print_stats()

