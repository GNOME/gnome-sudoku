# -*- coding: utf-8 -*-
import gtk, gobject
import colors
import math
import random
from simple_debug import simple_debug
import sudoku
import number_box

TRACKER_COLORS = [
    # Use tango colors recommended here:
    # http://tango.freedesktop.org/Tango_Icon_Theme_Guidelines
    tuple([x / 255.0 for x in cols]) for cols in
    [(32, 74, 135), # Sky Blue 3
     (78, 154, 6), # Chameleon 3
     (206, 92, 0), # Orange 3
     (143, 89, 2), # Chocolate 3
     (92, 53, 102), # Plum 3
     (85, 87, 83), # Aluminium 5
     (196, 160, 0), # Butter 3
     ]
    ]

def gtkcolor_to_rgb (color):
    return (color.red   / float(2**16),
            color.green / float(2**16),
            color.blue  / float(2**16))

SPACING_FACTOR = 40 # The size of a box compared (roughly) to the size
                    # of padding -- the larger this is, the smaller
                    # the spaces
SMALL_TO_BIG_FACTOR = 3.5 # The number of times wider than a small line a big line is.

class SudokuNumberGrid (gtk.AspectFrame):

    def __init__ (self, group_size = 9):
        self.table = gtk.Table(rows = group_size, columns = group_size, homogeneous = True)
        self.group_size = group_size
        self.__entries__ = {}
        for x in range(self.group_size):
            for y in range(self.group_size):
                e = number_box.SudokuNumberBox(upper = self.group_size)
                e.x = x
                e.y = y
                self.table.attach(e, x, x+1, y, y+1,
                                  )
                self.__entries__[(x, y)] = e
        gtk.AspectFrame.__init__(self, obey_child = False)
        self.set_shadow_type(gtk.SHADOW_NONE)
        self.eb = gtk.EventBox()
        self.eb.add(self.table)
        self.add(self.eb)
        self.connect('size-allocate', self.allocate_cb)
        self.show_all()

    def allocate_cb (self, w, rect):
        if rect.width > rect.height:
            side = rect.height
        else: side = rect.width
        # we want our small spacing to be 1/15th the size of a box
        spacing = float(side) / (self.group_size * SPACING_FACTOR)
        if spacing == 0:
            spacing = 1
        if hasattr(self, 'small_spacing') and spacing == self.small_spacing:
            return
        else:
            self.change_spacing(spacing)

    def change_spacing (self, small_spacing):
        self.small_spacing = small_spacing
        self.big_spacing = int(small_spacing*SMALL_TO_BIG_FACTOR)
        self.table.set_row_spacings(int(small_spacing))
        self.table.set_col_spacings(int(small_spacing))
        box_side = int(math.sqrt(self.group_size))
        for n in range(1, box_side):
            self.table.set_row_spacing(box_side*n-1, self.big_spacing)
            self.table.set_col_spacing(box_side*n-1, self.big_spacing)
        self.table.set_border_width(self.big_spacing)

    def get_focused_entry (self):
        return self.table.focus_child

    def set_bg_color (self, color):
        if type(color) == str:
            try:
                color = gtk.gdk.color_parse(color)
            except:
                print 'set_bg_color handed Bad color', color
                return
        self.eb.modify_bg(gtk.STATE_NORMAL, color)
        self.eb.modify_base(gtk.STATE_NORMAL, color)
        self.eb.modify_fg(gtk.STATE_NORMAL, color)
        self.table.modify_bg(gtk.STATE_NORMAL, color)
        self.table.modify_base(gtk.STATE_NORMAL, color)
        self.table.modify_fg(gtk.STATE_NORMAL, color)
        for e in self.__entries__.values():
            e.modify_bg(gtk.STATE_NORMAL, color)

class ParallelDict (dict):
    """A handy new sort of dictionary for tracking conflicts.

    pd = ParallelDict()
    pd[1] = [2, 3, 4] # 1 is linked with 2, 3 and 4
    pd -> {1:[2, 3, 4], 2:[1], 3:[1], 4:[1]}
    pd[2] = [1, 3, 4] # 2 is linked with 3 and 4 as well as 1
    pd -> {1: [2, 3, 4], 2:[3, 4], 3:[1, 2], 4:[1, 2]}
    Now for the cool part...
    del pd[1]
    pd -> {2: [2, 3], 3:[2], 4:[2]}

    Pretty neat, no?
    """
    def __init__ (self, *args):
        dict.__init__(self, *args)

    def __setitem__ (self, k, v):
        dict.__setitem__(self, k, set(v))
        for i in v:
            if i == k:
                continue
            if self.has_key(i):
                self[i].add(k)
            else:
                dict.__setitem__(self, i, set([k]))

    def __delitem__ (self, k):
        v = self[k]
        dict.__delitem__(self, k)
        for i in v:
            if i == k:
                continue
            if self.has_key(i):
                # Make sure we have a reference to i. If we don't
                # something has gone wrong... but according to bug
                # 385937 this has gone wrong at least once, so we'd
                # better check for it.
                if k in self[i]:
                    self[i].remove(k)
                if not self[i]:
                    # If k was the last value in the list of values
                    # for i, then we delete i from our dictionary
                    dict.__delitem__(self, i)

class SudokuGameDisplay (SudokuNumberGrid, gobject.GObject):

    __gsignals__ = {
        'focus-changed':(gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, ()),
        'puzzle-finished':(gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, ())
        }

    do_highlight_cells = False

    @simple_debug
    def __init__ (self, grid = None, group_size = 9,
                  show_impossible_implications = False):
        group_size = int(group_size)
        self.hints = 0
        self.always_show_hints = False
        self.auto_fills = 0
        self.show_impossible_implications = show_impossible_implications
        self.impossible_hints = 0
        self.impossibilities = []
        self.trackers = {}
        self.__trackers_tracking__ = {}
        gobject.GObject.__init__(self)
        SudokuNumberGrid.__init__(self, group_size = group_size)
        self.setup_grid(grid, group_size)
        for e in self.__entries__.values():
            e.show()
            e.connect('undo-change', self.entry_callback)
            e.connect('changed', self.entry_callback)
            e.connect('focus-in-event', self.focus_callback)
            e.connect('key-press-event', self.key_press_cb)
        self.connect('focus-changed', self.highlight_cells)

    def key_press_cb (self, widget, event):
        key = gtk.gdk.keyval_name(event.keyval)
        dest = self.go_around(widget.x, widget.y, key)
        if dest:
            self.table.set_focus_child(self.__entries__[dest])

    def go_around (self, x, y, direction):
        '''return the coordinate if we should go to the other side of the grid.
        Or else return None.'''
        (limit_min, limit_max) = (0, self.group_size -1)
        if   (y, direction) == (limit_min, 'Up'):
            dest = (x, limit_max)
        elif (y, direction) == (limit_max, 'Down'):
            dest = (x, limit_min)
        elif (x, direction) == (limit_min, 'Left'):
            dest = (limit_max, y)
        elif (x, direction) == (limit_max, 'Right'):
            dest = (limit_min, y)
        else:
            return None
        return dest

    @simple_debug
    def focus_callback (self, e, event):
        self.focused = e
        self.emit('focus-changed')

    def get_highlight_colors (self):
        entry = self.__entries__.values()[0]
        default_color = gtkcolor_to_rgb(entry.style.bg[gtk.STATE_SELECTED])
        hsv = colors.rgb_to_hsv(*default_color)
        box_s = hsv[1]
        box_v = hsv[2]
        if box_v < 0.5:
            box_v = box_v * 2
        if box_s > 0.75:
            box_s = box_s * 0.5
        else:
            box_s = box_s * 1.5
            if box_s > 1:
                box_s = 1.0
        self.box_color = colors.hsv_to_rgb(hsv[0], box_s, box_v)
        self.box_and_row_color = colors.rotate_hue_rgb(*self.box_color, **{'rotate_by': 0.33 / 2})
        self.row_color = colors.rotate_hue_rgb(*self.box_color, **{'rotate_by': 0.33})
        self.col_color = colors.rotate_hue_rgb(*self.box_color, **{'rotate_by': 0.66})
        self.box_and_col_color = colors.rotate_hue_rgb(*self.box_color, **{'rotate_by': 1.0 - (0.33 / 2)})

    def toggle_highlight (self, val):
        self.do_highlight_cells = val
        self.unhighlight_cells()
        if hasattr(self, 'focused') and self.focused:
            self.highlight_cells()

    def unhighlight_cells (self, *args):
        for e in self.__entries__.values():
            e.set_background_color(None)

    def highlight_cells (self, *args):
        if not self.do_highlight_cells:
            return
        self.unhighlight_cells()
        if not hasattr(self, 'box_color'):
            self.get_highlight_colors()
        my_x, my_y = self.focused.x, self.focused.y

        # col_coords can sometimes be null.
        if not hasattr(self.grid, 'col_coords'):
            return

        for x, y in self.grid.col_coords[my_x]:
            if (x, y) != (my_x, my_y):
                self.__entries__[(x, y)].set_background_color(self.col_color)
        for x, y in self.grid.row_coords[my_y]:
            if (x, y) != (my_x, my_y):
                self.__entries__[(x, y)].set_background_color(self.row_color)
        for x, y in self.grid.box_coords[self.grid.box_by_coords[(my_x, my_y)]]:
            if (x, y) != (my_x, my_y):
                e = self.__entries__[(x, y)]
                if x == my_x:
                    e.set_background_color(self.box_and_col_color)
                elif y == my_y:
                    e.set_background_color(self.box_and_row_color)
                else:
                    e.set_background_color(self.box_color)


    @simple_debug
    def show_hint (self):
        if hasattr(self, 'focused'):
            entry = self.focused
            if entry.read_only or entry.get_text():
                pass
            else:
                self.show_hint_for_entry(entry, interactive = True)

    def show_hint_for_entry (self, entry, interactive = False):
        if interactive:
            set_method = entry.set_note_text_interactive
        else:
            set_method = entry.set_note_text
        vals = self.grid.possible_values(entry.x, entry.y)
        vals = list(vals)
        vals.sort()
        if vals:
            ''.join([str(v) for v in vals])
            txt = ''.join([str(v) for v in vals])
            if txt != entry.get_text():
                set_method(bottom_text = txt)
                self.hints += 1
        elif not entry.get_text():
            if entry.get_text() != 'X':
                self.hints += 1
                set_method(bottom_text = 'X')
        else:
            set_method(bottom_text = "")

    @simple_debug
    def reset_grid (self):
        """Reset grid to its original setup.

        Return a list of items we removed so that callers can handle
        e.g. Undo properly"""
        removed = []
        for x in range(self.group_size):
            for y in range(self.group_size):
                if not self.grid.virgin._get_(x, y):
                    val = self.__entries__[(x, y)].get_value() # get the value from the user-visible grid,
                    if val:
                        removed.append((x, y, val, self.trackers_for_point(x, y, val)))
                        self.remove(x, y, do_removal = True)
        return removed

    def clear_notes (self, clear_args = {'top_text':'', 'bottom_text':''}):
        """Remove all notes."""
        self.removed = []
        for x in range(self.group_size):
            for y in range(self.group_size):
                e = self.__entries__[(x, y)]
                top, bottom = e.get_note_text()
                if top or bottom:
                    self.removed.append((x, y, (top, bottom)))
                    e.set_note_text(**clear_args)
                    e.queue_draw()
        return self.removed

    def clear_hints (self):
        self.clear_notes(clear_args = {'bottom_text':''})

    @simple_debug
    def blank_grid (self):
        for x in range(self.group_size):
            for y in range(self.group_size):
                e = self.__entries__[(x, y)]
                if e.get_value():
                    self.remove(x, y)
                e.set_read_only(False)
        self.grid = None
        self.clear_notes()

    @simple_debug
    def change_grid (self, grid, group_size):
        self.auto_fills = 0
        self.hints = 0
        self.impossible_hints = 0
        self.trackers = {}
        self.__trackers_tracking__ = {}
        self.blank_grid()
        self.setup_grid(grid, group_size)

    @simple_debug
    def load_game (self, game):
        """Load a game.

        A game is simply a two lined string where the first line represents our
        virgin self and line two represents our game-in-progress.
        """
        self.blank_grid()
        if '\n' in game:
            virgin, in_prog = game.split('\n')
        else:
            virgin, in_prog = game, ''
        group_size = int(math.sqrt(len(virgin.split())))
        self.change_grid(virgin, group_size = group_size)
        # This int() will break if we go to 16x16 grids...
        if in_prog:
            values = [int(c) for c in in_prog.split()]
            for row in range(group_size):
                for col in range(group_size):
                    index = row * 9 + col
                    if values[index] and not self.grid._get_(col, row):
                        self.add_value(col, row, values[index])

    @simple_debug
    def setup_grid (self, grid, group_size):
        self.doing_initial_setup = True
        self.__error_pairs__ = ParallelDict()
        if isinstance(grid, sudoku.SudokuGrid):
            self.grid = sudoku.InteractiveSudoku(grid.grid, group_size = grid.group_size)
        else:
            self.grid = sudoku.InteractiveSudoku(grid, group_size = group_size)
        for x in range(group_size):
            for y in range(group_size):
                val = self.grid._get_(x, y)
                if val:
                    self.add_value(x, y, val)
        self.doing_initial_setup = False

    @simple_debug
    def entry_callback (self, widget, *args):
        if not widget.get_text():
            if self.grid and self.grid._get_(widget.x, widget.y):
                self.grid.remove(widget.x, widget.y)
            self.remove(widget.x, widget.y)
        else:
            self.entry_validate(widget)
        if self.show_impossible_implications:
            self.mark_impossible_implications(widget.x, widget.y)
        if self.always_show_hints:
            self.update_all_hints()

    def update_all_hints (self):
        for x in range(self.group_size):
            for y in range(self.group_size):
                e = self.__entries__[(x, y)]
                if e.read_only:
                    pass
                elif e.get_text():
                    e.set_note_text(bottom_text = '')
                else:
                    self.show_hint_for_entry(e)

    @simple_debug
    def entry_validate (self, widget, *args):
        val = widget.get_value()
        self.add_value(widget.x, widget.y, val)
        if self.grid.check_for_completeness():
            self.emit('puzzle-finished')

    def complain_conflicts (self, x, y, value):
        '''set error highlights on [x, y] and all related box.

        We think the error is caused by `value`. But the box at [x, y] could
        have a different value.'''
        self.__entries__[x, y].set_error_highlight(True)
        conflicts = self.grid.find_conflicts(x, y, value)
        for conflict in conflicts:
            self.__entries__[conflict].set_error_highlight(True)
        self.__error_pairs__[(x, y)] = conflicts

    @simple_debug
    def add_value (self, x, y, val, trackers = []):
        """Add value val at position x, y.

        If tracker is True, we track it with tracker ID tracker.

        Otherwise, we use any currently tracking trackers to track our addition.

        Providing the tracker arg is mostly useful for e.g. undo/redo
        or removed items.

        To specify NO trackers, use trackers = [-1]
        """
        # Add the value to the UI to display
        self.__entries__[(x, y)].set_value(val)
        if self.doing_initial_setup:
            self.__entries__[(x, y)].set_read_only(True)
        # Handle any trackers.
        if trackers:
            # Explicitly specified tracker
            for tracker in trackers:
                if tracker == -1:
                    pass
                self.__entries__[(x, y)].set_color(self.get_tracker_color(tracker))
                self.trackers[tracker].append((x, y, val))
        elif True in self.__trackers_tracking__.values():
            for k, v in self.__trackers_tracking__.items():
                if v:
                    self.__entries__[(x, y)].set_color(self.get_tracker_color(k))
                    self.trackers[k].append((x, y, val))
        # Add value to our underlying sudoku grid -- this will raise
        # an error if the value is out of bounds with the current
        # rules.
        try:
            self.grid.add(x, y, val, True)
        except sudoku.ConflictError, err:
            self.complain_conflicts(err.x, err.y, err.value)
        # Draw our entry
        self.__entries__[(x, y)].queue_draw()

    @simple_debug
    def remove (self, x, y, do_removal = False):
        """Remove x, y from our visible grid.

        If do_removal, remove it from our underlying grid as well.
        """
        e = self.__entries__[(x, y)]
        if do_removal and self.grid and self.grid._get_(x, y):
            self.grid.remove(x, y)
        self.remove_error_highlight(x, y)
        # remove trackers
        for t in self.trackers_for_point(x, y):
            remove = []
            for crumb in self.trackers[t]:
                if crumb[0] == x and crumb[1] == y:
                    remove.append(crumb)
            for r in remove:
                self.trackers[t].remove(r)
        if e.get_text():
            e.set_value(0)
        e.unset_color()

    def remove_error_highlight (self, x, y):
        '''remove error highlight from [x, y] and also all errors caused by it'''
        if self.__error_pairs__.has_key((x, y)):
            entry = self.__entries__[(x, y)]
            entry.set_error_highlight(False)
            errors_removed = self.__error_pairs__[(x, y)]
            del self.__error_pairs__[(x, y)]
            for coord in errors_removed:
                # If we're not an error by some other pairing...
                if not self.__error_pairs__.has_key(coord):
                    linked_entry = self.__entries__[coord]
                    linked_entry.set_error_highlight(False)

    @simple_debug
    def auto_fill (self):
        changed = self.grid.auto_fill()
        retval = []
        for coords, val in changed:
            self.add_value(coords[0], coords[1], val)
            retval.append((coords[0], coords[1], val))
            if self.show_impossible_implications:
                self.mark_impossible_implications(*coords)
        if retval:
            self.auto_fills += 1
        if self.grid.check_for_completeness():
            self.emit('puzzle-finished')
        return retval

    @simple_debug
    def auto_fill_current_entry (self):
        e = self.get_focused_entry()
        if not e:
            return
        filled = self.grid.auto_fill_for_xy(e.x, e.y)
        if filled and filled != -1:
            e.set_text_interactive('')
            e.set_text_interactive(str(filled[1]))

    @simple_debug
    def mark_impossible_implications (self, x, y):
        if not self.grid:
            return
        implications = self.grid.find_impossible_implications(x, y)
        if implications:
            for x, y in implications:
                self.__entries__[(x, y)].set_impossible(True)
                if not (x, y) in self.impossibilities:
                    self.impossible_hints += 1
        for x, y in self.impossibilities:
            if not (x, y) in implications:
                self.__entries__[(x, y)].set_impossible(False)
        self.impossibilities = implications

    @simple_debug
    def create_tracker (self, identifier = 0):
        if not identifier:
            identifier = 0
        while self.trackers.has_key(identifier):
            identifier += 1
        self.trackers[identifier] = []
        return identifier

    def trackers_for_point (self, x, y, val = None):
        if val:
            # if we have a value we can do this a simpler way...
            track_for_point = filter(
                lambda t: (x, y, val) in t[1],
                self.trackers.items()
                )
        else:
            track_for_point = filter(
                lambda tkr: True in [t[0] == x and t[1] == y for t in tkr[1]],
                self.trackers.items())
        return [t[0] for t in track_for_point]

    def get_tracker_color (self, identifier):
        if len(TRACKER_COLORS)>identifier:
            return TRACKER_COLORS[identifier]
        else:
            random_color = TRACKER_COLORS[0]
            while random_color in TRACKER_COLORS:
                # If we have generated all possible colors, this will
                # enter an infinite loop
                random_color = (random.randint(0, 100)/100.0,
                                random.randint(0, 100)/100.0,
                                random.randint(0, 100)/100.0)
            TRACKER_COLORS.append(random_color)
            return self.get_tracker_color(identifier)

    @simple_debug
    def toggle_tracker (self, identifier, value):
        """Toggle tracking for tracker identified by identifier."""
        self.__trackers_tracking__[identifier] = value

    def delete_by_tracker (self, identifier):
        """Delete all cells tracked by tracker ID identifer."""
        ret = []
        while self.trackers[identifier]:
            x, y, v = self.trackers[identifier][0]
            ret.append((x, y, v, self.trackers_for_point(x, y, v)))
            self.remove(x, y)
            if self.grid and self.grid._get_(x, y):
                self.grid.remove(x, y)
        return ret

    def delete_except_for_tracker (self, identifier):
        tracks = self.trackers[identifier]
        removed = []
        for x in range(self.group_size):
            for y in range(self.group_size):
                val = self.grid._get_(x, y)
                if (val
                    and (x, y, val) not in tracks
                    and not self.grid.virgin._get_(x, y)
                    ):
                    removed.append((x, y, val, self.trackers_for_point(x, y, val)))
                    self.remove(x, y)
                    if self.grid and self.grid._get_(x, y):
                        self.grid.remove(x, y)

        return removed

    def add_tracker (self, x, y, tracker, val = None):
        self.__entries__[(x, y)].set_color(self.get_tracker_color(tracker))
        if not val:
            val = self.grid._get_(x, y)
        self.trackers[tracker].append((x, y, val))

    def remove_tracker (self, x, y, tracker, val = None):
        if not val:
            val = self.grid._get_(x, y)
        self.trackers[tracker].remove((x, y, val))

if __name__ == '__main__':
    window = gtk.Window()
    window.connect('delete-event', gtk.main_quit)

    def test_number_grid ():
        t = SudokuNumberGrid(4)
        window.add(t)
        t.__entries__[(0, 1)].set_color((0.0, 1.0, 0.0))
        t.__entries__[(0, 1)].set_value(4)
        t.__entries__[(1, 1)].set_error_highlight(True)
        t.__entries__[(1, 1)].set_value(1)
        t.__entries__[(2, 1)].set_color((0.0, 0.0, 1.0))
        t.__entries__[(2, 1)].set_error_highlight(True)
        t.__entries__[(2, 1)].set_value(2)
        t.__entries__[(3, 1)].set_color((0.0, 0.0, 1.0))
        t.__entries__[(3, 1)].set_error_highlight(True)
        t.__entries__[(3, 1)].set_error_highlight(False)
        t.__entries__[(3, 1)].set_value(3)
        t.__entries__[(3, 1)].set_note_text('234', '12')

    def reproduce_foobared_rendering ():
        from dialog_swallower import SwappableArea
        sgd = SudokuGameDisplay()
        sgd.set_bg_color('black')
        vb = gtk.VBox()
        hb = gtk.HBox()
        swallower = SwappableArea(hb)
        tb = gtk.Toolbar()
        b = gtk.ToolButton(stock_id = gtk.STOCK_QUIT)
        b.connect('clicked', lambda x: window.hide() or gtk.main_quit())
        tb.add(b)
        def run_swallowed_dialog (*args):
            md = MessageDialog(title = "Bar", label = "Bar", sublabel = "Baz "*12)
            swallower.run_dialog(md)
        b2 = gtk.ToolButton(label = 'Dialog')
        b2.connect('clicked', run_swallowed_dialog)
        tb.add(b2)
        vb.pack_start(tb, fill = False, expand = False)
        vb.pack_start(swallower, padding = 12)
        window.add(vb)
        window.show_all()
        from gtk_goodies.dialog_extras import MessageDialog
        md = MessageDialog(title = "Foo", label = "Foo", sublabel = "Bar "*12)
        swallower.run_dialog(md)
        hb.pack_start(sgd, padding = 6)
        game = '''1 8 4 2 0 0 0 0 0
                  0 6 0 0 0 9 1 2 0
                  0 2 0 0 8 0 0 0 0
                  0 1 8 0 5 0 0 0 0
                  9 0 0 0 0 0 0 0 3
                  0 0 0 0 1 0 6 5 0
                  0 0 0 0 9 0 0 8 0
                  0 5 7 1 0 0 0 9 0
                  0 0 0 0 0 3 5 4 7'''
        sgd.change_grid(game, 9)

    def test_sudoku_game ():
        game = '''1 8 4 2 0 0 0 0 0
                  0 6 0 0 0 9 1 2 0
                  0 2 0 0 8 0 0 0 0
                  0 1 8 0 5 0 0 0 0
                  9 0 0 0 0 0 0 0 3
                  0 0 0 0 1 0 6 5 0
                  0 0 0 0 9 0 0 8 0
                  0 5 7 1 0 0 0 9 0
                  0 0 0 0 0 3 5 4 7'''
        sgd = SudokuGameDisplay(game)
        sgd.set_bg_color('black')
        window.add(sgd)
        window.show_all()

#    test_number_grid()
#    reproduce_foobared_rendering()
    test_sudoku_game()
    window.show_all()
    gtk.main()
