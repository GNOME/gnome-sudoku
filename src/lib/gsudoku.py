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
        self.table.set_row_spacings(1)
        self.table.set_col_spacings(1)
        box_side = int(math.sqrt(self.group_size))
        for n in range(1, box_side):
            self.table.set_row_spacing(box_side*n-1, 2)
            self.table.set_col_spacing(box_side*n-1, 2)
        self.table.set_border_width(2)
        self.show_all()

    def set_parent_for(self, parent):
        for entry in self.__entries__.values():
            entry.set_parent_win(parent)

    def set_timer(self, timer):
        for entry in self.__entries__.values():
            entry.set_timer(timer)

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
        for imp_cell in self.impossibilities:
            self.__entries__[imp_cell].set_text('')
        self.impossibilities = []
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

    def highlight_conflicts (self, x, y):
        '''highlight any squares that conflict with position x,y.

        Conflict resolution is taken care of completely within
        the InteractiveGrid class.  A list of conflicting cells
        are stored in InteractiveGrid.conflicts
        '''
        # Return if there are no conflicts for this cell
        if not self.grid.conflicts.has_key((x, y)):
            return
        # Highlight the current cell
        self.__entries__[(x, y)].set_error_highlight(True)
        # Then highlight any cells that conflict with it
        for coord in self.grid.conflicts[(x, y)]:
            self.__entries__[coord].set_error_highlight(True)

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
        # Add it to the underlying grid
        self.grid.add(x, y, val, True)
        # Highlight any conflicts that the new value creates
        self.highlight_conflicts(x, y)
        # Draw our entry
        self.__entries__[(x, y)].queue_draw()
        # Update all hints if we need to
        if self.always_show_hints and not self.doing_initial_setup:
            self.update_all_hints()
        if not self.doing_initial_setup:
            self.mark_impossible_implications(x, y)

    @simple_debug
    def remove (self, x, y, do_removal = False):
        """Remove x, y from our visible grid.

        If do_removal, remove it from our underlying grid as well.
        """
        e = self.__entries__[(x, y)]
        # Always call the grid's remove() for proper conflict resolution
        if self.grid:
            self.grid.remove(x, y)
            self.remove_error_highlight()
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
        # Update all hints if we need to
        if self.grid and self.always_show_hints and not self.doing_initial_setup:
            self.update_all_hints()
        if not self.doing_initial_setup:
            self.mark_impossible_implications(x, y)

    def remove_error_highlight (self):
        '''remove error highlight from [x, y] and also all errors caused by it

        Conflict resolution is now handled within the InteractiveSudoku class.
        If any conflicts were cleared on the last remove() then they are
        stored in grid.cleared_conflicts
        '''
        if not self.grid.cleared_conflicts:
            return
        for coord in self.grid.cleared_conflicts:
            linked_entry = self.__entries__[coord]
            linked_entry.set_error_highlight(False)

    @simple_debug
    def auto_fill (self):
        changed = self.grid.auto_fill()
        retval = []
        for coords, val in changed:
            self.add_value(coords[0], coords[1], val)
            retval.append((coords[0], coords[1], val))
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

    def __set_impossible (self, coords, setting):
        '''Call set_impossible() on a grid entry

        This function is a helper for the 'Warn about unfillable squares'
        feature.  It only calls set_impossible() if the option is on to prevent
        a check against the show_impossible_implications flag elsewhere.  The
        return from this function indicates whether or not the cell "may"
        have been modified, which is basically the value of the option setting.
        '''
        if self.show_impossible_implications:
            self.__entries__[coords].set_impossible(setting)
        return self.show_impossible_implications

    def display_impossible_implications (self):
        '''Start X-marking cells that have no possible values
        '''
        self.show_impossible_implications = True
        for imp_cell in self.impossibilities:
            self.__set_impossible(imp_cell, True)
            self.impossible_hints += 1
        if self.always_show_hints:
            self.update_all_hints()

    def hide_impossible_implications (self):
        '''Stop X-marking cells that have no possible values
        '''
        for imp_cell in self.impossibilities:
            self.__set_impossible(imp_cell, False)
        self.show_impossible_implications = False
        if self.always_show_hints:
            self.update_all_hints()

    @simple_debug
    def mark_impossible_implications (self, x, y, check_conflicts = True):
        '''Mark cells with X if they have no possible values

        The hint this method provides can be turned on and off from the
        menu Tools->'Warn about unfillable squares' option.

        The check_conflicts parameter is for internal use only.  It is used as
        a one level recursion on conflicts that the original target is involved
        with.

        Impossibilities are tracked regardless of the user's option setting.
        This was done to allow the user to toggle the option mid-game and still
        behave properly.  Conditional X-marking of cells happens in the
        __set_impossible() function.
        '''
        # Make sure we have a grid to work with
        if not self.grid:
            return
        # Flag whether or not we need to update hints
        grid_modified = False
        # Find any new impossible cells based on calling cell
        implications = self.grid.find_impossible_implications(x, y)
        if implications:
            for imp_cell in implications:
                grid_modified = self.__set_impossible(imp_cell, True)
                # Add them to the list if they aren't there already...
                if not imp_cell in self.impossibilities:
                    self.impossibilities.append(imp_cell)
                    # But don't score it unless the option is on
                    if self.show_impossible_implications:
                        self.impossible_hints += 1
        # Reset the list of impossible cells ignoring the called cell. Use a
        # copy to iterate over, so items can be removed while looping.
        if self.impossibilities:
            for imp_cell in self.impossibilities[:]:
                if imp_cell == (x, y):
                    continue
                if self.grid.possible_values(*imp_cell):
                    self.impossibilities.remove(imp_cell)
                    grid_modified = self.__set_impossible(imp_cell, False)
                else:
                    grid_modified = self.__set_impossible(imp_cell, True)
        # If any conflicts have been cleared or created, mark any impossible
        # cells they may have caused or removed
        if check_conflicts:
            for xx, yy in self.grid.cleared_conflicts:
                self.mark_impossible_implications(xx, yy, False)
            if self.grid.conflicts.has_key((x, y)):
                for xx, yy in self.grid.conflicts[(x, y)]:
                    self.mark_impossible_implications(xx, yy, False)
        # Update the hints if we need to
        if grid_modified and self.always_show_hints:
            self.update_all_hints()

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
        # Highlight the conflicts when opening a saved game
        if self.grid.conflicts.has_key((x, y)):
            self.__entries__[(x, y)].set_error_highlight(True)
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
