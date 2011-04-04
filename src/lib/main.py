# -*- coding: utf-8 -*-
import os.path
import threading

import gi
gi.require_version("Gtk", "3.0")

from gi.repository import Gtk,GdkPixbuf,GObject,Pango
from gettext import gettext as _
from gettext import ngettext

import dialog_swallower
import game_selector
import gsudoku
import printing
import saver
import sudoku_maker
import timer
import tracker_info
from defaults import (APPNAME, APPNAME_SHORT, AUTHORS, COPYRIGHT, DESCRIPTION, DOMAIN, 
        IMAGE_DIR, LICENSE, MIN_NEW_PUZZLES, UI_DIR, VERSION, WEBSITE, WEBSITE_LABEL)
from gtk_goodies import gconf_wrapper, Undo, dialog_extras
from simple_debug import simple_debug, options

ICON_FACTORY = Gtk.IconFactory()
STOCK_PIXBUFS = {}
for filename, stock_id in [('footprints.png', 'tracks'), ]:
    try:
        pb = GdkPixbuf.Pixbuf.new_from_file(os.path.join(IMAGE_DIR, filename))
    except GObject.GError, e:
        print 'Failed to load pixbuf: %s' % e
        continue
    STOCK_PIXBUFS[stock_id] = pb
    iconset = Gtk.IconSet(pb)
    ICON_FACTORY.add(stock_id, iconset)
    ICON_FACTORY.add_default()

Gtk.stock_add([('tracks',
                _('Track moves'),
                0, 0, ""), ])

def inactivate_new_game_etc (fun):
    def inactivate_new_game_etc_ (ui, *args, **kwargs):
        paths = [
            '/MenuBar/Game/New',
            '/MenuBar/Game/Reset',
            '/MenuBar/Game/PuzzleInfo',
            '/MenuBar/Game/Print',
            # undo/redo is handled elsewhere as it can't simply be turned on/off.
            '/MenuBar/Settings/ToggleToolbar',
            '/MenuBar/Settings/ToggleHighlight',
            '/MenuBar/Settings/AlwaysShowPossible',
            '/MenuBar/Settings/ShowImpossibleImplications',
            '/MenuBar/Tools/ShowPossible',
            '/MenuBar/Tools/ClearTopNotes',
            '/MenuBar/Tools/ClearBottomNotes',
            '/MenuBar/Tools/Tracker',
            ]
        for p in paths:
            action = ui.uimanager.get_action(p)
            if not action:
                action = ui.uimanager.get_widget(p)
            if not action:
                print 'No action at path', p
            else:
                action.set_sensitive(False)
        ret = fun(ui, *args, **kwargs)
        for p in paths:
            action = ui.uimanager.get_action(p)
            if not action:
                action = ui.uimanager.get_widget(p)
            if not action:
                print 'No action at path', p
            else:
                action.set_sensitive(True)
        return ret
    return inactivate_new_game_etc_

class UI (gconf_wrapper.GConfWrapper):
    ui = '''<ui>
    <menubar name="MenuBar">
      <menu name="Game" action="Game">
        <menuitem action="New"/>
        <menuitem action="Reset"/>
        <separator/>
        <menuitem action="Undo"/>
        <menuitem action="Redo"/>
        <separator/>
        <menuitem action="PuzzleInfo"/>
        <separator/>
        <menuitem action="Print"/>
        <menuitem action="PrintMany"/>
        <separator/>
        <menuitem action="Close"/>
      </menu>
      <menu action="Settings">
        <menuitem action="FullScreen"/>
        <menuitem action="ToggleToolbar"/>
        <separator/>
        <menuitem action="ToggleHighlight"/>
        <menuitem action="AlwaysShowPossible"/>
        <menuitem action="ShowImpossibleImplications"/>
      </menu>
      <menu action="Tools">
        <menuitem action="ShowPossible"/>
        <separator/>
        <menuitem action="ClearTopNotes"/>
        <menuitem action="ClearBottomNotes"/>
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
      <separator/>
      <toolitem action="Undo"/>
      <toolitem action="Redo"/>
      <separator/>
      <toolitem action="ShowPossible"/>
      <separator/>
      <toolitem action="Tracker"/>
    </toolbar>
    </ui>'''

    initial_prefs = {'group_size':9,
                     'always_show_hints':False,
                     'difficulty':0.0,
                     'minimum_number_of_new_puzzles':MIN_NEW_PUZZLES,
                     'highlight':False,
                     'bg_color':'black',
                     'show_tracker':False,
                     'width': 700,
                     'height': 675,
                     'auto_save_interval':60 # auto-save interval in seconds...
                     }

    @simple_debug
    def __init__ (self, run_selector = True):
        """run_selector means that we start our regular game.

        For testing purposes, it will be convenient to hand a
        run_selector=False to this method to avoid running the dialog
        and allow a tester to set up a game programmatically.
        """
        gconf_wrapper.GConfWrapper.__init__(self,
                                            gconf_wrapper.GConfWrap('gnome-sudoku')
                                            )
        self.setup_gui()
        self.timer = timer.ActiveTimer(self.w)
        self.gsd.set_timer(self.timer)
        self.won = False
        # add the accelerator group to our toplevel window
        self.worker_connections = []
        self.is_fullscreen = False

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
        GObject.timeout_add_seconds(1, lambda *args: self.start_worker_thread() and True)

    @inactivate_new_game_etc
    def select_game (self):
        self.tb.hide()
        choice = game_selector.NewOrSavedGameSelector().run_swallowed_dialog(self.swallower)
        if not choice:
            return True
        self.timer.start_timing()
        if choice[0] == game_selector.NewOrSavedGameSelector.NEW_GAME:
            self.gsd.change_grid(choice[1], 9)
        if choice[0] == game_selector.NewOrSavedGameSelector.SAVED_GAME:
            saver.open_game(self, choice[1])
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
        self.gsd.set_parent_for(self.w)
        self.gsd.connect('puzzle-finished', self.you_win_callback)
        self.setup_color()
        self.setup_actions()
        self.setup_undo()
        self.setup_autosave()
        self.w.add_accel_group(self.uimanager.get_accel_group())
        self.setup_main_boxes()
        self.setup_tracker_interface()
        self.setup_toggles()

    def setup_main_window (self):
        Gtk.Window.set_default_icon_name('gnome-sudoku')
        self.w = Gtk.Window()
        self.w.set_default_size(self.gconf['width'], self.gconf['height'])
        self.w.set_title(APPNAME_SHORT)
        self.w.connect('configure-event', self.resize_cb)
        self.w.connect('delete-event', self.quit_cb)
        self.uimanager = Gtk.UIManager()

    def setup_actions (self):
        self.main_actions = Gtk.ActionGroup('MainActions')
        self.main_actions.add_actions([
            ('Game', None, _('_Game')),
            ('New', Gtk.STOCK_NEW, None, '<Control>n', _('New game'), self.new_cb),
            ('Reset', Gtk.STOCK_CLEAR, _('_Reset'), '<Control>b',
             None, self.game_reset_cb),
            ('Undo', Gtk.STOCK_UNDO, _('_Undo'), '<Control>z',
             _('Undo last action'), self.stop_dancer),
            ('Redo', Gtk.STOCK_REDO, _('_Redo'), '<Shift><Control>z',
             _('Redo last action')),
            ('PuzzleInfo', Gtk.STOCK_ABOUT, _('Puzzle _Statistics...'), None,
             None, self.show_info_cb),
            ('Print', Gtk.STOCK_PRINT, _('_Print...'), '<Control>p', None, self.print_game),
            ('PrintMany', Gtk.STOCK_PRINT, _('Print _Multiple Sudokus...'), None,
             None, self.print_multiple_games),
            ('Close', Gtk.STOCK_CLOSE, None, '<Control>w', None, self.quit_cb),
            ('Settings', None, _('_Settings')),
            ('FullScreen', Gtk.STOCK_FULLSCREEN, None, 'F11', None, self.full_screen_cb),
            ('Tools', None, _('_Tools')),
            ('ShowPossible', Gtk.STOCK_DIALOG_INFO, _('_Hint'), '<Control>h',
             _('Show a square that is easy to fill.'), self.show_hint_cb),
            ('ClearTopNotes', None, _('Clear _Top Notes'), '<Control>j',
             None, self.clear_top_notes_cb),
            ('ClearBottomNotes', None, _('Clear _Bottom Notes'), '<Control>k',
             None, self.clear_bottom_notes_cb),
            ('Help', None, _('_Help'), None, None, None),
            ('ShowHelp', Gtk.STOCK_HELP, _('_Contents'), 'F1', None, self.show_help),
            ('About', Gtk.STOCK_ABOUT, None, None, None, self.show_about),
            ])
        self.main_actions.add_toggle_actions([
            ('AlwaysShowPossible',
             None,
             _('Show _Possible Numbers'),
             None,
             _('Always show possible numbers in a square'),
             self.auto_hint_cb),
            ('ShowImpossibleImplications',
             None,
             _('Warn About _Unfillable Squares'),
             None,
             _('Warn about squares made unfillable by a move'),
             self.impossible_implication_cb),
            ('Tracker', 'tracks', _('_Track Additions'),
             '<Control>T',
             _('Mark new additions in a separate color so you can keep track of them.'),
             self.tracker_toggle_cb, False),
            ('ToggleToolbar', None, _('Show _Toolbar'), None, None, self.toggle_toolbar_cb, True),
            ('ToggleHighlight', Gtk.STOCK_SELECT_COLOR, _('_Highlighter'),
             None, _('Highlight the current row, column and box'), self.toggle_highlight_cb, False)
            ])

        self.main_actions.get_action('Undo').set_is_important(True)
        self.main_actions.get_action('Redo').set_is_important(True)
        self.main_actions.get_action('ShowPossible').set_is_important(True)
        self.main_actions.get_action('Tracker').set_is_important(True)

        self.uimanager.insert_action_group(self.main_actions, 0)
        self.uimanager.add_ui_from_string(self.ui)

    def setup_undo (self):
        self.cleared = [] # used for Undo memory
        self.cleared_notes = [] # used for Undo memory
        # Set up our UNDO stuff
        undo_widg = self.main_actions.get_action('Undo')
        redo_widg = self.main_actions.get_action('Redo')
        self.history = Undo.UndoHistoryList(undo_widg, redo_widg)
        for entry in self.gsd.__entries__.values():
            Undo.UndoableGenericWidget(entry, self.history,
                                       set_method = 'set_value_for_undo',
                                       get_method = 'get_value_for_undo',
                                       pre_change_signal = 'value-about-to-change'
                                       )
            Undo.UndoableGenericWidget(entry, self.history,
                                       set_method = 'set_notes_for_undo',
                                       get_method = 'get_notes_for_undo',
                                       signal = 'notes-changed',
                                       pre_change_signal = 'notes-about-to-change',
                                       )

    def setup_color (self):
        # setup background colors
        bgcol = self.gconf['bg_color']
        if bgcol != '':
            self.gsd.set_bg_color(bgcol)

    def setup_autosave (self):
        GObject.timeout_add_seconds(self.gconf['auto_save_interval'] or 60, # in seconds...
                            self.autosave)

    def setup_main_boxes (self):
        self.vb = Gtk.VBox()
        # Add menu bar and toolbar...
        mb = self.uimanager.get_widget('/MenuBar')
        mb.show()
        self.vb.pack_start(mb, fill = False, expand = False)
        self.tb = self.uimanager.get_widget('/Toolbar')
        self.vb.pack_start(self.tb, fill = False, expand = False)
        self.main_area = Gtk.HBox()
        self.swallower = dialog_swallower.SwappableArea(self.main_area)
        self.swallower.show()
        self.vb.pack_start(self.swallower, True, padding = 12)
        self.main_area.pack_start(self.gsd, padding = 6)
        self.main_actions.set_visible(True)
        self.game_box = Gtk.VBox()
        self.main_area.show()
        self.vb.show()
        self.game_box.show()
        self.main_area.pack_start(self.game_box, False, padding = 12)
        self.w.add(self.vb)

    def setup_toggles (self):
        # sync up toggles with gconf values...
        map(lambda tpl: self.gconf_wrap_toggle(*tpl),
            [('always_show_hints',
              self.main_actions.get_action('AlwaysShowPossible')),
             ('show_impossible_implications',
              self.main_actions.get_action('ShowImpossibleImplications')),
             ('show_toolbar',
              self.main_actions.get_action('ToggleToolbar')),
             ('highlight',
              self.main_actions.get_action('ToggleHighlight')),
             ('show_tracker',
              self.main_actions.get_action('Tracker')),
             ])

    @simple_debug
    def start_worker_thread (self, *args):
        n_new_puzzles = self.sudoku_maker.n_puzzles(new = True)
        try:
            if n_new_puzzles < self.gconf['minimum_number_of_new_puzzles']:
                self.worker = threading.Thread(target = lambda *args: self.sudoku_maker.work(limit = 5))
                self.worker_connections = [
                    self.timer.connect('timing-started', self.sudoku_maker.resume),
                    self.timer.connect('timing-stopped', self.sudoku_maker.pause)
                    ]
                self.worker.start()
        except gconf_wrapper.GConfError:
            pass # assume we have enough new puzzles
        return True

    @simple_debug
    def stop_worker_thread (self, *args):
        if hasattr(self, 'worker'):
            self.sudoku_maker.stop()
            for c in self.worker_connections:
                self.timer.disconnect(c)

    def stop_dancer (self, *args):
        if hasattr(self, 'dancer'):
            self.dancer.stop_dancing()
            delattr(self, 'dancer')

    def start_dancer (self):
        import dancer
        self.dancer = dancer.GridDancer(self.gsd)
        self.dancer.start_dancing()

    @simple_debug
    def you_win_callback (self, grid):
        if hasattr(self, 'dancer'):
            return
        self.won = True
        # increase difficulty for next time.
        self.gconf['difficulty'] = self.gconf['difficulty'] + 0.1
        self.timer.finish_timing()
        self.sudoku_tracker.finish_game(self)
        if self.timer.active_time < 60:
            seconds = int(self.timer.active_time)
            sublabel = ngettext("You completed the puzzle in %d second",
                                "You completed the puzzle in %d seconds", seconds) % seconds
        elif self.timer.active_time < 3600:
            minutes = int(self.timer.active_time / 60)
            seconds = int(self.timer.active_time - minutes*60)
            minute_string = ngettext("%d minute", "%d minutes", minutes) % minutes
            second_string = ngettext("%d second", "%d seconds", seconds) % seconds
            sublabel = _("You completed the puzzle in %(minute)s and %(second)s") % {'minute': minute_string, 'second': second_string}
        else:
            hours = int(self.timer.active_time / 3600)
            minutes = int((self.timer.active_time - hours*3600) / 60)
            seconds = int(self.timer.active_time - hours*3600 - minutes*60)
            hour_string = ngettext("%d hour", "%d hours", hours) % hours
            minute_string = ngettext("%d minute", "%d minutes", minutes) % minutes
            second_string = ngettext("%d second", "%d seconds", seconds) % seconds
            sublabel = _("You completed the puzzle in %(hour)s, %(minute)s and %(second)s") % {'hour': hour_string, 'minute': minute_string, 'second': second_string}
        sublabel += "\n"
        sublabel += ngettext("You got %(n)s hint.", "You got %(n)s hints.", self.gsd.hints) % {'n':self.gsd.hints}
        sublabel += "\n"
        if self.gsd.impossible_hints:
            sublabel += ngettext("You had %(n)s impossibility pointed out.",
                                 "You had %(n)s impossibilities pointed out.",
                                 self.gsd.impossible_hints) % {'n':self.gsd.impossible_hints}
            sublabel += "\n"
        self.start_dancer()
        dialog_extras.show_message(_("You win!"), label = _("You win!"),
                                   sublabel = sublabel
                                   )

    @simple_debug
    def initialize_prefs (self):
        for k, v in self.initial_prefs.items():
            try:
                self.gconf[k]
            except:
                self.gconf[k] = v

    @simple_debug
    @inactivate_new_game_etc
    def new_cb (self, *args):
        if (self.gsd.grid and self.gsd.grid.is_changed() and not self.won):
            try:
                if dialog_extras.getBoolean(
                    label = _("Save this game before starting new one?"),
                    custom_yes = _("_Save game for later"),
                    custom_no = _("_Abandon game"),
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
                if dialog_extras.getBoolean(label = _("Save game before closing?")):
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
        self.old_tracker_view = None

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
        if Gtk.main_level() > 1:
            # If we are in an embedded mainloop, that means that one
            # of our "swallowed" dialogs is active, in which case we
            # have to quit that mainloop before we can quit
            # properly.
            if self.swallower.running:
                d = self.swallower.running
                d.response(Gtk.ResponseType.DELETE_EVENT)
            Gtk.main_quit() # Quit the embedded mainloop
            GObject.idle_add(self.quit_cb, 100) # Call ourselves again
                                               # to quit the main
                                               # mainloop
            return
        # make sure we really go away before doing our saving --
        # otherwise we appear sluggish.
        while Gtk.events_pending():
            Gtk.main_iteration()
        self.stop_worker_thread()
        # allow KeyboardInterrupts, which calls quit_cb outside the main loop
        try:
            Gtk.main_quit()
        except RuntimeError:
            pass

    @simple_debug
    def save_game (self, *args):
        self.sudoku_tracker.save_game(self)

    def full_screen_cb (self, *args):
        if self.is_fullscreen:
            self.w.unfullscreen()
            self.is_fullscreen = False
        else:
            self.w.fullscreen()
            self.is_fullscreen = True

    @simple_debug
    def game_reset_cb (self, *args):
        clearer = Undo.UndoableObject(
            self.do_game_reset, #action
            self.undo_game_reset, #inverse
            self.history #history
            )
        clearer.perform()

    def do_game_reset (self, *args):
        self.gsd.cover_track()
        self.cleared.append(self.tinfo.save())
        self.cleared.append(self.gsd.reset_grid())
        self.cleared_notes.append((tracker_info.NO_TRACKER, self.gsd.clear_notes('All')))
        self.tinfo.reset()
        self.stop_dancer()

    def undo_game_reset (self, *args):
        self.tracker_ui.select_tracker(tracker_info.NO_TRACKER)
        for entry in self.cleared.pop():
            self.gsd.add_value(*entry)
        self.tinfo.load(self.cleared.pop())
        self.tracker_ui.select_tracker(self.tinfo.current_tracker)
        self.gsd.show_track()
        self.undo_clear_notes()

    def clear_top_notes_cb (self, *args):
        clearer = Undo.UndoableObject(
            lambda *args: self.do_clear_notes('Top'), #action
            self.undo_clear_notes, #inverse
            self.history
            )
        clearer.perform()

    def clear_bottom_notes_cb (self, *args):
        clearer = Undo.UndoableObject(
            lambda *args: self.do_clear_notes('Bottom'), #action
            self.undo_clear_notes, #inverse
            self.history
            )
        clearer.perform()

    def do_clear_notes(self, side):
        ''' Clear top, bottom, or all notes - in undoable fashion

        The side argument is used to specify which notes are to be cleared.
        'Top' - Clear only the top notes
        'Bottom' - Clear only the bottom notes
        '''
        self.cleared_notes.append((self.tinfo.current_tracker, self.gsd.clear_notes(side)))
        # Turn off auto-hint if the player clears the bottom notes
        if side == 'Bottom' and self.gconf['always_show_hints']:
            always_show_hint_wdgt = self.main_actions.get_action('AlwaysShowPossible')
            always_show_hint_wdgt.activate()
        # Update the hints...in case we're redoing a clear of them
        if self.gconf['always_show_hints']:
            self.gsd.update_all_hints()

    def undo_clear_notes(self):
        ''' Undo previously cleared notes

        Clearing notes fills the cleared_notes list of notes that were cleared.
        '''
        cleared_tracker, cleared_notes = self.cleared_notes.pop()
        # Change the tracker selection if it was tracking during the clear
        if cleared_tracker != tracker_info.NO_TRACKER:
            self.tracker_ui.select_tracker(cleared_tracker)
        self.gsd.apply_notelist(cleared_notes)
        # Update the hints...in case we're undoing over top of them
        if self.gconf['always_show_hints']:
            self.gsd.update_all_hints()
        # Redraw the notes
        self.gsd.update_all_notes()
        # Make sure we're still dancing if we undo after win
        if self.gsd.grid.check_for_completeness():
            self.start_dancer()

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
            self.gsd.clear_notes('AutoHint')

    @simple_debug
    def impossible_implication_cb (self, action):
        if action.get_active():
            self.gsd.display_impossible_implications()
        else:
            self.gsd.hide_impossible_implications()

    @simple_debug
    def setup_tracker_interface (self):
        self.tracker_ui = TrackerBox(self)
        self.tracker_ui.show_all()
        self.tracker_ui.hide()
        self.tinfo = tracker_info.TrackerInfo()
        self.old_tracker_view = None
        self.game_box.add(self.tracker_ui)

    @simple_debug
    def tracker_toggle_cb (self, widg):
        if widg.get_active():
            if self.old_tracker_view:
                self.tinfo.set_tracker_view(self.old_tracker_view)
                self.tracker_ui.select_tracker(self.tinfo.current_tracker)
                self.gsd.show_track()
            self.tracker_ui.show_all()
        else:
            self.old_tracker_view = self.tinfo.get_tracker_view()
            self.tracker_ui.hide_tracker_cb(None)
            self.tracker_ui.hide()

    @simple_debug
    def toggle_toolbar_cb (self, widg):
        if widg.get_active():
            self.tb.show()
        else:
            self.tb.hide()

    def toggle_highlight_cb (self, widg):
        if widg.get_active():
            self.gsd.toggle_highlight(True)
        else:
            self.gsd.toggle_highlight(False)

    @simple_debug
    def show_info_cb (self, *args):
        if not self.gsd.grid:
            dialog_extras.show_message(parent = self.w,
                                       title = _("Puzzle Information"),
                                       label = _("There is no current puzzle.")
                                       )
            return
        puzzle = self.gsd.grid.virgin.to_string()
        diff = self.sudoku_maker.get_difficulty(puzzle)
        information = _("Calculated difficulty: ")
        try:
            information += {'easy': _('Easy'),
                            'medium': _('Medium'),
                            'hard': _('Hard'),
                            'very hard': _('Very Hard')}[diff.value_category()]
        except KeyError:
            information += diff.value_category()
        information += " (%1.2f)" % diff.value
        information += "\n"
        information += _("Number of moves instantly fillable by elimination: ")
        information += str(int(diff.instant_elimination_fillable))
        information += "\n"
        information += _("Number of moves instantly fillable by filling: ")
        information += str(int(diff.instant_fill_fillable))
        information += "\n"
        information += _("Amount of trial-and-error required to solve: ")
        information += str(len(diff.guesses))
        dialog_extras.show_message(parent = self.w,
                                   title = _("Puzzle Statistics"),
                                   label = _("Puzzle Statistics"),
                                   sublabel = information)

    @simple_debug
    def autosave (self):
        # this is called on a regular loop and will autosave if we
        # have reason to...
        if self.gsd.grid and self.gsd.grid.is_changed() and not self.won:
            self.sudoku_tracker.save_game(self)
        return True

    @simple_debug
    def show_about (self, *args):
        about = Gtk.AboutDialog()
        about.set_transient_for(self.w)
        about.set_name(APPNAME)
        about.set_version(VERSION)
        about.set_copyright(COPYRIGHT)
        about.set_license(LICENSE[0] + '\n\n' + LICENSE[1] + '\n\n'  + LICENSE[2])
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
            Gtk.show_uri(self.w.get_screen(), "ghelp:gnome-sudoku", Gtk.get_current_event_time())
        except GObject.GError, error:
            # FIXME: This should create a pop-up dialog
            print _('Unable to display help: %s') % str(error)

    @simple_debug
    def print_game (self, *args):
        printing.print_sudokus([self.gsd], self.w)

    @simple_debug
    def print_multiple_games (self, *args):
        gp = printing.GamePrinter(self.sudoku_maker, self.gconf)
        gp.run_dialog()

class TrackerBox (Gtk.VBox):

    @simple_debug
    def __init__ (self, main_ui):

        GObject.GObject.__init__(self)
        self.builder = Gtk.Builder()
        self.builder.set_translation_domain(DOMAIN)
        self.builder.add_from_file(os.path.join(UI_DIR, 'tracker.ui'))
        self.main_ui = main_ui
        self.tinfo = tracker_info.TrackerInfo()
        self.tinfo.ui = self
        self.vb = self.builder.get_object('vbox1')
        self.vb.unparent()
        self.pack_start(self.vb, expand = True, fill = True)
        self.setup_actions()
        self.setup_tree()
        self.show_all()

    @simple_debug
    def reset (self):

        for tree in self.tracker_model:
            if tree[0] > -1:
                self.tracker_model.remove(tree.iter)
        self.tinfo.reset()
        self.tracker_actions.set_sensitive(False)

    @simple_debug
    def setup_tree (self):
        self.tracker_tree = self.builder.get_object('TrackerTreeView')
        self.tracker_model = Gtk.ListStore(int, GdkPixbuf.Pixbuf, str)
        self.tracker_model.set_sort_column_id(0, Gtk.SortType.ASCENDING)
        self.tracker_tree.set_model(self.tracker_model)
        col1 = Gtk.TreeViewColumn("", Gtk.CellRendererPixbuf(), pixbuf = 1)
        rend = Gtk.CellRendererText()
        col2 = Gtk.TreeViewColumn("", rend, text = 2)
        col2.set_cell_data_func(rend, self.draw_tracker_name)
        self.tracker_tree.append_column(col2)
        self.tracker_tree.append_column(col1)
        # Our initial row...
        pixbuf = self.pixbuf_transform_color(
            STOCK_PIXBUFS['tracks'],
            (0, 0, 0)
            )
        self.tracker_model.append([-1, pixbuf, _('Untracked')])
        self.tracker_tree.get_selection().connect('changed', self.selection_changed_cb)

    @simple_debug
    def setup_actions (self):
        self.tracker_actions = Gtk.ActionGroup('tracker_actions')
        self.tracker_actions.add_actions(
            [('Remove',
              Gtk.STOCK_CLEAR,
              _('_Remove'),
              None, _('Delete selected tracker.'),
              self.remove_tracker_cb
              ),
             ('Hide',
              Gtk.STOCK_CLEAR,
              _('H_ide'),
              None, _('Hide current tracker entries.'),
              self.hide_tracker_cb
              ),
             ('Apply',
              Gtk.STOCK_APPLY,
              _('A_pply'),
              None, _('Apply all tracked values and remove the tracker.'),
              self.apply_tracker_cb
              ),
             ]
            )
        a = self.tracker_actions.get_action('Remove')
        a.connect_proxy(self.builder.get_object('RemoveTrackerButton'))
        a = self.tracker_actions.get_action('Hide')
        a.connect_proxy(self.builder.get_object('HideTrackerButton'))
        a = self.tracker_actions.get_action('Apply')
        a.connect_proxy(self.builder.get_object('ApplyTrackerButton'))
        self.builder.get_object('AddTrackerButton').connect('clicked',
                                                          self.add_tracker)
        # Default to insensitive (they only become sensitive once a tracker is added)
        self.tracker_actions.set_sensitive(False)

    def draw_tracker_name(self, column, cell, model, iter):
        if model.get_value(iter, 0) == self.tinfo.showing_tracker:
            cell.set_property('weight', Pango.Weight.BOLD)
        else:
            cell.set_property('weight', Pango.Weight.NORMAL)

    @simple_debug
    def add_tracker (self, *args, **keys):
        if keys and keys.has_key('tracker_id'):
            tracker_id = self.tinfo.create_tracker(keys['tracker_id'])
        else:
            tracker_id = self.tinfo.create_tracker()
        pixbuf = self.pixbuf_transform_color(
            STOCK_PIXBUFS['tracks'],
            self.tinfo.get_color(tracker_id)
            )
        # select our new tracker
        self.tracker_tree.get_selection().select_iter(
            self.tracker_model.append([tracker_id,
                                  pixbuf,
                                  _("Tracker %s") % (tracker_id + 1)]
                                  )
            )
        self.tinfo.set_tracker(tracker_id)

    @simple_debug
    def pixbuf_transform_color (self, pixbuf, color):
        """Return new pixbuf with color changed to color"""
        pixbuf_str = pixbuf.get_pixels()
        pixbuf_str_new = ""

        for alpha in pixbuf_str[3::4]:
            pixbuf_str_new += chr(int(color[0]*255))
            pixbuf_str_new += chr(int(color[1]*255))
            pixbuf_str_new += chr(int(color[2]*255))
            pixbuf_str_new += alpha

        return GdkPixbuf.Pixbuf.new_from_data(pixbuf_str_new, GdkPixbuf.Colorspace.RGB, True, 8,
                                            pixbuf.get_width(), pixbuf.get_height(), pixbuf.get_rowstride())

    @simple_debug
    def find_tracker (self, tracker_id):
        for row in self.tracker_model:
            if row[0] == tracker_id:
                return row
        return None

    @simple_debug
    def select_tracker (self, tracker_id):
        track_row = self.find_tracker(tracker_id)
        if track_row:
            self.tracker_tree.get_selection().select_iter(track_row.iter)
            self.tinfo.set_tracker(tracker_id)

    def redraw_row(self, tracker_id):
        track_row = self.find_tracker(tracker_id)
        if track_row:
            self.tracker_model.row_changed(self.tracker_model.get_path(track_row.iter), track_row.iter)

    def set_tracker_action_sense(self, enabled):
        self.tracker_actions.set_sensitive(True)
        for action in self.tracker_actions.list_actions():
            action.set_sensitive(self.tinfo.showing_tracker != tracker_info.NO_TRACKER)

    @simple_debug
    def selection_changed_cb (self, selection):
        mod, itr = selection.get_selected()
        if itr:
            selected_tracker_id = mod.get_value(itr, 0)
        else:
            selected_tracker_id = tracker_info.NO_TRACKER
        if selected_tracker_id != tracker_info.NO_TRACKER:
            self.main_ui.gsd.cover_track()
        # Remove the underline on the showing_tracker
        self.redraw_row(self.tinfo.showing_tracker)
        self.tinfo.set_tracker(selected_tracker_id)
        self.set_tracker_action_sense(self.tinfo.showing_tracker != tracker_info.NO_TRACKER)
        # Show the tracker
        if selected_tracker_id != tracker_info.NO_TRACKER:
            self.main_ui.gsd.show_track()
        self.main_ui.gsd.update_all_notes()
        if self.main_ui.gconf['always_show_hints']:
            self.main_ui.gsd.update_all_hints()

    @simple_debug
    def remove_tracker_cb (self, action):
        mod, itr = self.tracker_tree.get_selection().get_selected()
        # This should only be called if there is an itr, but we'll
        # double-check just in case.
        if itr:
            clearer = Undo.UndoableObject(
                self.do_delete_tracker,
                self.undo_delete_tracker,
                self.main_ui.history
                )
            clearer.perform()

    @simple_debug
    def hide_tracker_cb (self, action):
        hiding_tracker = self.tinfo.showing_tracker
        self.select_tracker(tracker_info.NO_TRACKER)
        self.main_ui.gsd.cover_track(True)
        self.main_ui.gsd.update_all_notes()
        self.set_tracker_action_sense(False)
        self.redraw_row(hiding_tracker)
        self.redraw_row(tracker_info.NO_TRACKER)

    @simple_debug
    def apply_tracker_cb (self, action):
        '''Apply Tracker button action
        '''
        # Shouldn't be here if no tracker is showing
        if self.tinfo.showing_tracker == tracker_info.NO_TRACKER:
            return
        # Apply the tracker in undo-able fashion
        applyer = Undo.UndoableObject(
            self.do_apply_tracker,
            self.undo_apply_tracker,
            self.main_ui.history
            )
        applyer.perform()

    def do_apply_tracker(self):
        '''Apply the showing tracker to untracked

        All of the values and notes will be transferred to untracked and
        the tracker is deleted.
        '''
        track_row = self.find_tracker(self.tinfo.showing_tracker)
        if not track_row:
            return
        # Delete the tracker
        cleared_values, cleared_notes = self.do_delete_tracker(True)
        # Apply the values
        for x, y, val, tid in cleared_values:
            self.main_ui.gsd.set_value(x, y, val)
        # Then apply the notes
        self.main_ui.gsd.apply_notelist(cleared_notes, True)
        # Store the undo counts
        self.main_ui.cleared.append(len(cleared_values))
        self.main_ui.cleared_notes.append(len(cleared_notes))

    def undo_apply_tracker(self):
        '''Undo a previous tracker apply

        The number of cleared values and notes are stored during the apply.
        The undo is called for each of them, then the tracker delete is
        undone.
        '''
        # Undo all of the applied values and notes
        value_count = self.main_ui.cleared.pop()
        note_count = self.main_ui.cleared_notes.pop()
        count = 0
        while count < (value_count + note_count):
            self.main_ui.history.undo()
            count += 1
        # Undo the tracker delete
        self.undo_delete_tracker()

    def do_delete_tracker(self, for_apply = False):
        '''Delete the current tracker
        '''
        track_row = self.find_tracker(self.tinfo.showing_tracker)
        if not track_row:
            return
        ui_row = [track_row[0], track_row[1], track_row[2]]
        # For the values, store it like (tracker_id, list_of_cleared_values)
        cleared_values = self.main_ui.gsd.delete_by_tracker()
        self.main_ui.cleared.append((self.tinfo.showing_tracker, ui_row, cleared_values))
        # The notes already have tracker info in them, so just store the list
        cleared_notes = self.main_ui.gsd.clear_notes(tracker = self.tinfo.showing_tracker)
        self.main_ui.cleared_notes.append(cleared_notes)
        # Delete it from tracker_info
        self.hide_tracker_cb(None)
        self.tracker_model.remove(track_row.iter)
        self.tinfo.delete_tracker(ui_row[0])
        # Return all of the data for "Apply Tracker" button
        if for_apply:
            return (cleared_values, cleared_notes)

    def undo_delete_tracker(self):
        '''Undo a tracker delete
        '''
        # Values are stored like (tracker_id, list_of_cleared_values)
        tracker_id, ui_row, cleared_values = self.main_ui.cleared.pop()
        # Recreate it in tracker_info
        self.tinfo.create_tracker(tracker_id)
        # Add it to the tree
        self.tracker_tree.get_selection().select_iter(self.tracker_model.append(ui_row))
        # Add all the values
        for value in cleared_values:
            self.main_ui.gsd.add_value(*value)
        # The notes already have tracker info in them, so just store the list
        self.main_ui.gsd.apply_notelist(self.main_ui.cleared_notes.pop())

def start_game ():
    if options.debug:
        print 'Starting GNOME Sudoku in debug mode'

    ##  You must call g_thread_init() before executing any other GLib
    ##  functions in a threaded GLib program.
    GObject.threads_init()

    if options.profile:
        options.profile = False
        profile_me()
        return

    u = UI()
    if not u.quit:
        try:
            Gtk.main()
        except KeyboardInterrupt:
            # properly quit on a keyboard interrupt...
            u.quit_cb()

def profile_me ():
    print 'Profiling GNOME Sudoku'
    import tempfile, hotshot, hotshot.stats
    pname = os.path.join(tempfile.gettempdir(), 'GNOME_SUDOKU_HOTSHOT_PROFILE')
    prof = hotshot.Profile(pname)
    prof.runcall(start_game)
    stats = hotshot.stats.load(pname)
    stats.strip_dirs()
    stats.sort_stats('time', 'calls').print_stats()

