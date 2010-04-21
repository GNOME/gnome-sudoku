# -*- coding: utf-8 -*-
import gtk, gobject
import os.path
import sudoku, saver, sudoku_maker
import sudoku_thumber
from gettext import gettext as _
from timer import format_time, format_friendly_date
import defaults
from simple_debug import simple_debug
from colors import color_hex_to_float

def color_from_difficulty (diff):
    DR = sudoku.DifficultyRating
    if diff < DR.easy_range[1]:
        if diff < DR.easy_range[1] / 3:
            c = '#8ae234' # green
        elif diff < 2 * DR.easy_range[1] / 3:
            c = '#73d216'
        else:
            c = '#4e9a06'
    elif diff < DR.medium_range[1]:
        span = DR.medium_range[1] - DR.easy_range[1]
        if diff < DR.medium_range[0] + (span / 3):
            c = '#204a87' # sky blue
        elif diff < DR.medium_range[0] + (2 * (span / 3)):
            c = '#3465a4'
        else:
            c = '#729fcf'
    elif diff < DR.hard_range[1]:
        span = DR.hard_range[1] - DR.medium_range[1]
        if diff < DR.hard_range[0] + span / 3:
            c = '#fcaf3e' # orange
        elif diff < DR.hard_range[0] + span * 2 / 3:
            c = '#f57900'
        else:
            c = '#ce5c00'
    else:
        span = DR.very_hard_range[1] - DR.hard_range[1]
        if diff < DR.very_hard_range[0] + span / 3:
            c = '#ef2929' # scarlet red
        elif diff < DR.very_hard_range[0]+ span * 2 / 3:
            c = '#cc0000'
        else:
            c = '#a40000'
    return color_hex_to_float(c)

class NewOrSavedGameSelector:

    NEW_GAME = 0
    SAVED_GAME = 1

    ui_file = os.path.join(defaults.UI_DIR, 'select_game.ui')

    @simple_debug
    def __init__ (self):
        self.sudoku_maker = sudoku_maker.SudokuMaker()
        self.dialog = None
        self.puzzle = None
        self.new_game_model = None
        self.saved_game_model = None
        self.saved_games = None

    def setup_dialog (self):
        builder = gtk.Builder()
        builder.set_translation_domain(defaults.DOMAIN)
        builder.add_from_file(self.ui_file)
        self.dialog = builder.get_object('dialog1')
        self.dialog.set_default_response(gtk.RESPONSE_CANCEL)
        self.dialog.connect('close', self.close)
        self.dialog.hide()
        saved_game_frame = builder.get_object('savedGameFrame')
        saved_game_view = builder.get_object('savedGameIconView')
        saved_game_widgets = [
            saved_game_frame,
            saved_game_view,
            builder.get_object('savedGameLabel')
            ]
        builder.get_object('savedGameLabel').set_mnemonic_widget(
            saved_game_view
            )
        new_game_frame = builder.get_object('newGameFrame')
        new_game_frame.show()
        new_game_view = builder.get_object('newGameIconView')
        builder.get_object('newGameLabel').set_mnemonic_widget(
            new_game_view
            )
        self.saved_games = saver.SudokuTracker().list_saved_games()
        self.make_new_game_model()
        new_game_view.set_model(self.new_game_model)
        new_game_view.set_markup_column(0)
        new_game_view.set_pixbuf_column(1)
        self.make_saved_game_model()
        if len(self.saved_game_model) == 0:
            for w in saved_game_widgets:
                w.hide()
        else:
            saved_game_frame.show()
            self.saved_game_model.set_sort_column_id(2, gtk.SORT_DESCENDING)
            saved_game_view.set_model(self.saved_game_model)
            saved_game_view.set_markup_column(0)
            saved_game_view.set_pixbuf_column(1)
        for view in saved_game_view, new_game_view:
            view.set_item_width(150)
            view.set_columns(4)
            view.set_spacing(12)
            view.set_selection_mode(gtk.SELECTION_SINGLE)
        saved_game_view.connect('item-activated', self.saved_item_activated_cb)
        new_game_view.connect('item-activated', self.new_item_activated_cb)

    @simple_debug
    def make_new_game_model (self):
        # Description, Pixbuf, Puzzle (str)
        self.new_game_model = gtk.ListStore(str, gtk.gdk.Pixbuf, str)
        saved_games_to_exclude = [
            g['game'].split('\n')[0] for g in self.saved_games
            ]
        for cat in sudoku.DifficultyRating.ordered_categories:
            label = sudoku.DifficultyRating.label_by_cat[cat]
            puzzles = self.sudoku_maker.get_puzzles(1, [cat], new = True,
                                                    exclude = saved_games_to_exclude
                                                    )
            if puzzles:
                puzzle, diff_val = puzzles[0]
            else:
                print 'WARNING: Repeating puzzle for difficulty %s -- generate more puzzles to avoid this.' % cat
                puzzles = self.sudoku_maker.get_puzzles(1, [cat], new = False)
                if puzzles:
                    puzzle, diff_val = puzzles[0]
                    lpuz = list(puzzle)
                    lpuz.reverse() # we reverse the puzzle so it at least looks different :-)
                    puzzle = ''
                    for n in lpuz:
                        puzzle += n
                else:
                    print 'WARNING: No puzzle for difficulty', cat
                    continue
            grid = sudoku.sudoku_grid_from_string(puzzle).grid
            self.new_game_model.append(('<b><i>' + label + '</i></b>',
                                        sudoku_thumber.make_pixbuf(grid,
                                                                   None,
                                                                   color_from_difficulty(diff_val)
                                                                   ),
                                        puzzle
                                        ))

    @simple_debug
    def make_saved_game_model (self):
        # Description, Image, Last-Access time (for sorting), Puzzle (jar)
        self.saved_game_model = gtk.ListStore(str, gtk.gdk.Pixbuf, int, gobject.TYPE_PYOBJECT)
        for g in self.saved_games:
            game = g['game'].split('\n')[0]
            grid = sudoku.sudoku_grid_from_string(game)
            sr = sudoku.SudokuRater(grid.grid)
            sdifficulty = sr.difficulty()
            lastPlayedText = _("Last Played %(timeAgo)s") % {'timeAgo': format_friendly_date(g['saved_at'])}
            levelText =  _("%(level)s puzzle") % {'level': sdifficulty.value_string()}
            durationText = _("Played for %(duration)s") % {
                    'duration': format_time(g['timer.active_time'], round_at = 15, friendly = True)}
            desc = "<b><i>%s</i></b>\n<span size='small'><i>%s</i>\n<i>%s.</i></span>" % (
                levelText,
                lastPlayedText,
                durationText,
                )
            self.saved_game_model.append((
                desc,
                sudoku_thumber.make_pixbuf(grid.grid,
                                           sudoku.sudoku_grid_from_string(g['game'].split('\n')[1].replace(' ', '')).grid,
                                           color_from_difficulty(sdifficulty.value)
                                           ),
                g['saved_at'],
                g
                ))

    @simple_debug
    def new_item_activated_cb (self, iconview, path):
        self.play_game(iconview.get_model()[path][2])

    @simple_debug
    def saved_item_activated_cb (self, iconview, path):
        self.resume_game(iconview.get_model()[path][3])

    @simple_debug
    def resume_game (self, jar):
        self.puzzle = (self.SAVED_GAME, jar)
        self.dialog.emit('response', gtk.RESPONSE_OK)

    @simple_debug
    def play_game (self, puzzle):
        self.puzzle = (self.NEW_GAME, puzzle)
        self.dialog.emit('response', gtk.RESPONSE_OK)

    @simple_debug
    def close (self):
        self.dialog.emit('response', gtk.RESPONSE_CLOSE)

    @simple_debug
    def handle_response (self, response):
        if response == gtk.RESPONSE_OK:
            return self.puzzle
        else:
            return None

    def run_swallowed_dialog (self, swallower):
        self.setup_dialog()
        return self.handle_response(
            swallower.run_dialog(self.dialog)
            )

    def run_dialog (self):
        self.setup_dialog()
        return self.handle_response(self.dialog.run())

if __name__ == '__main__':
    selector = NewOrSavedGameSelector()
    import pprint
    pprint.pprint (selector.run_dialog())
