# -*- coding: utf-8 -*-
from gi.repository import Gtk,GObject
from . import colors

class GridDancer:

    DANCE_COLORS = [colors.color_hex_to_float(hx) for hx in
                    [
        '#cc0000', # red
        '#ef2929',
        '#f57900', # orange
        '#fcaf3e',
        '#fce94f',
        '#8ae234', # green
        '#73d216',
        '#729fcf', # blue
        '#3465a4',
        '#ad7fa8', # violet
        '#75507b', ]
                    ]

    STEPS_PER_ANIMATION = 10

    def __init__ (self, grid):
        self.animations = [self.value_dance,
                           self.box_dance,
                           self.col_dance,
                           self.row_dance,]
        self.current_animation = self.value_dance
        self.step = 0
        self.grid = grid
        self.dancing = False
        self.adjustment = 0

    def start_dancing (self):
        for box in list(self.grid.__entries__.values()):
            box.props.can_focus = False
            if box.read_only:
                box.read_only = False
                box.need_restore = True
            else:
                box.need_restore = False
        self.grid.get_toplevel().child_focus(Gtk.DirectionType.TAB_BACKWARD)
        self.dancing = True
        GObject.timeout_add(500, self.dance_grid)

    def stop_dancing (self):
        self.dancing = False
        for box in list(self.grid.__entries__.values()):
            box.props.can_focus = True
            if box.need_restore:
                box.read_only = True
        self.grid.unhighlight_cells()

    def dance_grid (self):
        if not self.dancing:
            return
        if self.step > self.STEPS_PER_ANIMATION:
            self.rotate_animation()
        #self.adjustment = (self.adjustment + 1) % 9
        try:
            self.current_animation()
        except AttributeError:
            return True
        self.step += 1
        if self.dancing:
            return True

    def rotate_animation (self):
        current_index = self.animations.index(self.current_animation)
        next_index = (current_index + 1) % len(self.animations)
        self.current_animation = self.animations[next_index]
        self.step = 0

    def next_color (self, current):
        result = (current + self.adjustment) % len(self.DANCE_COLORS)
        return self.DANCE_COLORS[result]

    def col_dance (self):
        for x in range(9):
            color = self.next_color(x)
            for y in range(9):
                self.grid.__entries__[(x, y)].set_background_color(color)

    def row_dance (self):
        for y in range(9):
            color = self.next_color(y)
            for x in range(9):
                self.grid.__entries__[(x, y)].set_background_color(color)

    def box_dance (self):
        for box in range(9):
            color = self.next_color(box)
            for x, y in self.grid.grid.box_coords[box]:
                self.grid.__entries__[(x, y)].set_background_color(color)

    def value_dance (self):
        for value in range(10):
            color = self.next_color(value)
            for x in range(9):
                for y in range(9):
                    box = self.grid.__entries__[(x, y)]
                    if box.get_value() == value:
                        box.set_background_color(color)

def test_dance_grid ():
    from . import gsudoku
    window = Gtk.Window()
    game = '''9 1 6 3 2 8 4 5 7
              5 7 4 6 1 9 2 8 3
              8 3 2 5 7 4 9 6 1
              6 8 7 2 4 1 3 9 5
              2 9 5 7 3 6 1 4 8
              3 4 1 8 9 5 7 2 6
              4 6 9 1 8 7 5 3 2
              1 2 8 9 5 3 6 7 4
              7 5 3 4 6 2 8 1 9'''
    gsd = gsudoku.SudokuGameDisplay(game)
    dancer = GridDancer(gsd)

    button = Gtk.Button('toggle')
    button.connect('clicked',
            lambda *args: dancer.stop_dancing() if dancer.dancing
                else dancer.start_dancing())

    vbox = Gtk.VBox()
    vbox.pack_start(gsd, True, True, 0)
    vbox.pack_end(button, True, True, 0)
    vbox.set_focus_child(button)

    window.add(vbox)
    window.show_all()
    window.connect('delete-event', Gtk.main_quit)
    Gtk.main()

if __name__ == '__main__':
    test_dance_grid()
