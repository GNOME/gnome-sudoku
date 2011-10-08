# -*- coding: utf-8 -*-
from gi.repository import Gtk,Gdk,GObject
import colors
import math
import random
import logging
from simple_debug import simple_debug
import sudoku
import number_box
import tracker_info

def gtkcolor_to_rgb (color):
    return (color.red   / float(2**16),
            color.green / float(2**16),
            color.blue  / float(2**16))

class SudokuNumberGrid (Gtk.AspectFrame):

    def __init__ (self, group_size = 9):
        self.table = Gtk.Table(rows = group_size, columns = group_size, homogeneous = True)
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
        GObject.GObject.__init__(self, obey_child = False)
        self.set_shadow_type(Gtk.ShadowType.NONE)
        self.eb = Gtk.EventBox()
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
        try:
            if type(color) == str:
                color = Gdk.color_parse(color)
                color = Gdk.RGBA(color.red/65535.0, color.green/65535.0, color.blue/65535.0)
            else:
                color = Gdk.RGBA(*color)
        except:
            logging.critical("set_bg_color handed Bad color: %s" % color, exc_info=True)
            return

        self.eb.override_color(Gtk.StateFlags.NORMAL, color)
        self.eb.override_background_color(Gtk.StateFlags.NORMAL, color)
        self.table.override_color(Gtk.StateFlags.NORMAL, color)
        self.table.override_background_color(Gtk.StateFlags.NORMAL, color)

        for e in self.__entries__.values():
            e.override_background_color(Gtk.StateFlags.NORMAL, color)

class SudokuGameDisplay (SudokuNumberGrid, GObject.GObject):

    __gsignals__ = {
        'focus-changed':(GObject.SignalFlags.RUN_LAST, None, ()),
        'puzzle-finished':(GObject.SignalFlags.RUN_LAST, None, ())
        }

    do_highlight_cells = False

    @simple_debug
    def __init__ (self, grid = None, group_size = 9,
                  show_impossible_implications = False):
        group_size = int(group_size)
        self.hints = 0
        self.hint_square = None
        self.always_show_hints = False
        self.show_impossible_implications = show_impossible_implications
        self.impossible_hints = 0
        self.impossibilities = []
        self.trackers = {}
        self.tinfo = tracker_info.TrackerInfo()
        GObject.GObject.__init__(self)
        SudokuNumberGrid.__init__(self, group_size = group_size)
        self.setup_grid(grid, group_size)
        for e in self.__entries__.values():
            e.show()
            e.connect('undo-change', self.entry_callback, 'undo-change')
            e.connect('changed', self.entry_callback)
            e.connect('focus-in-event', self.focus_callback)
            e.connect('key-press-event', self.key_press_cb)
        self.connect('focus-changed', self.highlight_cells)

    def key_press_cb (self, widget, event):
        key = Gdk.keyval_name(event.keyval)
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
        bg = self.get_style_context().get_background_color(Gtk.StateFlags.SELECTED)
        default_color = (bg.red, bg.green, bg.blue)
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

    def animate_hint (self):
        if self.hint_animate_count % 2 == 0:
            color = (1.0, 0.0, 0.0)
        else:
            color = None
        self.hint_square.set_border_color(color)
        self.hint_animate_count += 1

        if self.hint_animate_count == 4:
            self.hint_square = None
            return False

        return True;

    def set_hint_square (self, square):
        if self.hint_square is not None:
            self.hint_square.set_border_color(None)
            GObject.source_remove(self.hint_timer)
            self.hint_timer = None

        if square is None:
            self.hint_square = None
        else:
            self.hint_square = self.__entries__[square]
            self.hint_animate_count = 0
            self.animate_hint()
            self.hint_timer = GObject.timeout_add(150, self.animate_hint)

    @simple_debug
    def show_hint (self):
        min_options = 10;
        squares = []
        for x in xrange(9):
            for y in xrange(9):
                if self.grid._get_(x, y) != 0:
                    continue
                n_options = len(self.grid.possible_values(x, y))
                if n_options < min_options:
                    squares = [(x, y)]
                    min_options = n_options
                elif n_options == min_options:
                    squares.append((x, y))

        if len(squares) != 0:
            self.set_hint_square(random.choice(squares))
            self.hints += 1

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
                set_method(bottom_text = txt, for_hint = True)
        elif not entry.get_text():
            if entry.get_text() != 'X':
                set_method(bottom_text = 'X', for_hint = True)
        else:
            set_method(bottom_text = "", for_hint = True)

    @simple_debug
    def reset_grid (self):
        '''Remove all untracked values from the grid

        This method is used to clear all untracked values from the grid for
        the undo processing.  The tracked values and notes are handled higher
        up by the caller.
        '''
        removed = []
        for x in range(self.group_size):
            for y in range(self.group_size):
                if not self.grid.virgin._get_(x, y):
                    e = self.__entries__[(x, y)]
                    val = e.get_value()
                    track = e.tracker_id
                    if val and track == tracker_info.NO_TRACKER:
                        removed.append((x, y, val))
                    self.remove(x, y)
        return removed

    def clear_notes (self, side = 'Both', tracker = None):
        '''Remove notes

        The list of notes removed by this function are returned in a list.
        The notes are returned in the format (x, y, (side, pos, tid, note)) where:
        x and y are the cell's coordinates
        side is either 'Top' or 'Bottom'
        pos is the index of the note within the notelist
        tid is the tracker id for the note
        note is the value of the note

        The side argument determines what notes get cleared as well as what
        notes get returned.
        'Both' - Clears both the top and bottom notes(default)
        'Top' - Clear only the top notes
        'Bottom' - Clear only the bottom notes
        'AutoHint' - Clear all bottom notes for all trackers
        'All' - Reset all notes

        For 'Top', 'Bottom', and 'Both', the tracker argument can be supplied
        to clear for a specific tracker.  Set tracker to None(default) to
        operate on just what is currently displayed.
        '''
        # Storage for removed notes
        removed = []
        for x in range(self.group_size):
            for y in range(self.group_size):
                e = self.__entries__[(x, y)]
                if side in ['Top', 'Both']:
                    if tracker == None:
                        top_display_list = e.get_note_display(e.top_note_list)[0]
                    else:
                        top_display_list = e.get_note_display(e.top_note_list, tracker, False)[0]
                    for offset, (notelist_index, tracker_id, note) in enumerate(top_display_list):
                        removed.append((x, y, ('Top', notelist_index, tracker_id, note)))
                        del e.top_note_list[notelist_index - offset]
                if side in ['Bottom', 'Both']:
                    if tracker == None:
                        bottom_display_list = e.get_note_display(e.bottom_note_list)[0]
                    else:
                        bottom_display_list = e.get_note_display(e.bottom_note_list, tracker, False)[0]
                    for offset, (notelist_index, tracker_id, note) in enumerate(bottom_display_list):
                        removed.append((x, y, ('Bottom', notelist_index, tracker_id, note)))
                        del e.bottom_note_list[notelist_index - offset]
                if side == 'All':
                    for notelist_index, (tracker_id, note) in enumerate(e.top_note_list):
                        removed.append((x, y, ('Top', notelist_index, tracker_id, note)))
                    e.top_note_list = []
                if side in ['All', 'AutoHint']:
                    for notelist_index, (tracker_id, note) in enumerate(e.bottom_note_list):
                        removed.append((x, y, ('Bottom', notelist_index, tracker_id, note)))
                    e.bottom_note_list = []
        # Redraw the notes
        self.update_all_notes()
        return removed

    def apply_notelist(self, notelist, apply_tracker = False):
        '''Re-apply notes

        Re-apply notes that have been removed with the clear_notes() function.
        The apply_tracker argument is used for the "Apply Tracker" button
        functionality, which requires the history to be updated.
        '''
        for x, y, (side, notelist_index, tracker_id, note) in notelist:
            cell = self.__entries__[x, y]
            if apply_tracker:
                use_tracker = tracker_info.NO_TRACKER
                cell.emit('notes-about-to-change')
            else:
                use_tracker = tracker_id
            if side == 'Top':
                cell.top_note_list.insert(notelist_index, (use_tracker, note))
            if side == 'Bottom':
                cell.bottom_note_list.insert(notelist_index, (use_tracker, note))
            if apply_tracker:
                cell.emit('notes-changed')
                # When applying a tracker - update the notes to remove
                # duplicates from other trackers.
                if side == 'Top':
                    cell.trim_untracked_notes(cell.top_note_list)
                else:
                    cell.trim_untracked_notes(cell.bottom_note_list)
        # Redraw the notes
        self.update_all_notes()

    @simple_debug
    def blank_grid (self):
        '''Wipe out everything on the grid.

        This blanks all values, notes, tracked values, virgin values.  You end
        up with a blank grid ready for a new puzzle.
        '''
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
        self.clear_notes('All')
        self.tinfo.reset()

    @simple_debug
    def change_grid (self, grid, group_size):
        self.hints = 0
        self.impossible_hints = 0
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
            self.remove(widget.x, widget.y, *args)
            # Trackers need to be redisplayed on an undo
            if args and args[0] == 'undo-change':
                self.show_track()
        else:
            self.entry_validate(widget, *args)

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

    def update_all_notes (self):
        '''Display the notes for all the cells

        The notes are context sensitive to the trackers.  This method displays
        all of the notes for the currently viewed selection.
        '''
        for x in range(self.group_size):
            for y in range(self.group_size):
                self.__entries__[(x, y)].show_note_text()

    @simple_debug
    def entry_validate (self, widget, *args):
        val = widget.get_value()
        if (args and args[0] == 'undo-change'):
            # When undoing from one value to another - remove the errors from
            # the previous value and add the new value to the proper tracker
            self.remove_error_highlight()
            self.add_value(widget.x, widget.y, val, widget.tracker_id)
        else:
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

    def set_value(self, x, y, val):
        '''Sets value for position x, y to val.

        Calls set_text_interactive so the history list is updated.
        '''
        self.__entries__[(x, y)].set_text_interactive(str(val))

    @simple_debug
    def add_value (self, x, y, val, tracker = None):
        """Add value val at position x, y.

        If tracker is set, we track the value with it.  Otherwise,
        the current tracker is used(default).
        """
        # If the cell already has a value - remove it first.
        e = self.__entries__[(x, y)]
        if e.get_value():
            self.remove(x, y)
        # Explicitly specified tracker
        if tracker:
            # Only add it to the display when it's tracker is visible
            if tracker == tracker_info.NO_TRACKER or tracker == self.tinfo.showing_tracker:
                self.__entries__[(x, y)].set_value(val, tracker)
            # If the tracker isn't showing at the moment - add it as a trace
            if tracker != tracker_info.NO_TRACKER:
                self.tinfo.add_trace(x, y, val, tracker)
        else:
            # Add a trace(tracked value) if a tracker is selected
            if self.tinfo.current_tracker != tracker_info.NO_TRACKER:
                self.tinfo.add_trace(x, y, val)
            # Remove all tracked values(all traces) for the cell if the player
            # adds an untracked value
            else:
                self.tinfo.remove_trace(x, y)
            self.__entries__[(x, y)].set_value(val, self.tinfo.current_tracker)
            if self.doing_initial_setup:
                self.__entries__[(x, y)].set_read_only(True)
            else:
                self.__entries__[(x, y)].recolor(self.tinfo.current_tracker)
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
    def remove (self, x, y, *args):
        """Remove x, y from our visible grid.

        *args is passed from the undo mechanism
        """
        e = self.__entries__[(x, y)]
        # Always call the grid's remove() for proper conflict resolution
        if self.grid:
            self.grid.remove(x, y)
            self.remove_error_highlight()
        # Remove it from the tracker.  When removing via undo, the trace
        # manipulation is handled at a higher level
        if not args or args[0] != 'undo-change':
            if e.tracker_id != tracker_info.NO_TRACKER:
                self.tinfo.remove_trace(x, y, e.tracker_id)
        # Reset the value and tracker id
        e.set_value(0, tracker_info.NO_TRACKER)
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

    def delete_by_tracker (self):
        '''Delete all cells tracked by the current tracker

        The values are deleted from the tracker as well as the visible grid.
        '''
        ret = []
        tracker = self.tinfo.get_tracker(self.tinfo.showing_tracker)
        if not tracker:
            return ret
        for (x, y), value in tracker.items():
            ret.append((x, y, value, self.tinfo.showing_tracker))
            self.remove(x, y)
            if self.grid and self.grid._get_(x, y):
                self.grid.remove(x, y)
        return ret

    def cover_track(self, hide = False):
        '''Hide the current tracker

        All tracked values are deleted from the display, but kept by the
        tracker.  Setting hide to True changes prevents anything but untracked
        values to be shown after the call.
        '''
        track = self.tinfo.get_tracker(self.tinfo.showing_tracker)
        if track:
            for coord in track.keys():
                self.__entries__[coord].set_value(0, tracker_info.NO_TRACKER)
                self.grid.remove(*coord)
                self.remove_error_highlight()
                self.mark_impossible_implications(*coord)
        if hide:
            self.tinfo.hide_tracker()
        # Update all hints if we need to
        if self.always_show_hints and not self.doing_initial_setup:
            self.update_all_hints()

    def show_track(self):
        '''Displays the current tracker items

        The values and notes for the currently showing tracker will be
        displayed
        '''
        track = self.tinfo.get_tracker(self.tinfo.showing_tracker)
        if not track:
            return
        for (x, y), value in track.items():
            self.__entries__[(x, y)].set_value(value, self.tinfo.showing_tracker)
            self.__entries__[(x, y)].recolor(self.tinfo.showing_tracker)
            # Add it to the underlying grid
            self.grid.add(x, y, value, True)
            # Highlight any conflicts that the new value creates
            self.highlight_conflicts(x, y)
            # Draw our entry
            self.__entries__[(x, y)].queue_draw()
            self.mark_impossible_implications(x, y)
        # Update all hints if we need to
        if self.always_show_hints and not self.doing_initial_setup:
            self.update_all_hints()

if __name__ == '__main__':
    window = Gtk.Window()
    window.connect('delete-event', Gtk.main_quit)

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
        vb = Gtk.VBox()
        hb = Gtk.HBox()
        swallower = SwappableArea(hb)
        tb = Gtk.Toolbar()
        b = Gtk.ToolButton(stock_id = Gtk.STOCK_QUIT)
        b.connect('clicked', lambda x: window.hide() or Gtk.main_quit())
        tb.add(b)
        def run_swallowed_dialog (*args):
            md = MessageDialog(title = "Bar", label = "Bar", sublabel = "Baz "*12)
            swallower.run_dialog(md)
        b2 = Gtk.ToolButton(label = 'Dialog')
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
    Gtk.main()
