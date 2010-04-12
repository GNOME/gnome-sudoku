# -*- coding: utf-8 -*-
#!/usr/bin/python

import gtk, gobject, pango, cairo
import math
import timer
from gettext import gettext as _

ERROR_HIGHLIGHT_COLOR = (1.0, 0, 0)

BASE_SIZE = 35 # The "normal" size of a box (in pixels)

# And the standard font-sizes -- these should fit nicely with the
# BASE_SIZE
BASE_FONT_SIZE = pango.SCALE * 13
NOTE_FONT_SIZE = pango.SCALE * 6

BORDER_WIDTH = 9.0 # The size of space we leave for a box
BORDER_LINE_WIDTH = 4 # The size of the line we draw around a selected box
NORMAL_LINE_WIDTH = 1 # The size of the line we draw around a box

class NumberSelector (gtk.EventBox):

    __gsignals__ = {
        'changed':(gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, ()),
        }

    def __init__ (self, default = None, upper = 9):
        self.value = default
        gtk.EventBox.__init__(self)
        self.table = gtk.Table()
        self.add(self.table)
        side = int(math.sqrt(upper))
        n = 1
        for y in range(side):
            for x in range(side):
                b = gtk.Button()
                l = gtk.Label()
                if n == self.value:
                    l.set_markup('<b><span size="x-small">%s</span></b>'%n)
                else:
                    l.set_markup('<span size="x-small">%s</span>'%n)
                b.add(l)
                b.set_relief(gtk.RELIEF_HALF)
                l = b.get_children()[0]
                b.set_border_width(0)
                l.set_padding(0, 0)
                l.get_alignment()
                b.connect('clicked', self.number_clicked, n)
                self.table.attach(b, x, x+1, y, y+1)
                n += 1
        if self.value:
            db = gtk.Button()
            l = gtk.Label()
            l.set_markup_with_mnemonic('<span size="x-small">'+_('_Clear')+'</span>')
            db.add(l)
            l.show()
            db.connect('clicked', self.number_clicked, 0)
            self.table.attach(db, 0, side, side + 1, side + 2)
        self.show_all()

    def number_clicked (self, button, n):
        self.value = n
        self.emit('changed')

    def get_value (self):
        return self.value

    def set_value (self, n):
        self.value = n

class NumberBox (gtk.Widget):

    text = ''
    top_note_text = ''
    bottom_note_text = ''
    read_only = False
    _layout = None
    _top_note_layout = None
    _bottom_note_layout = None
    text_color = None
    highlight_color = None
    custom_background_color = None

    __gsignals__ = {
        'value-about-to-change':(gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, ()),
        'changed':(gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, ()),
        # undo-change - A hacky way to handle the fact that we want to
        # respond to undo's changes but we don't want undo to respond
        # to itself...
        'undo-change':(gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, ()),
        'notes-changed':(gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, ()),
        }

    base_state = gtk.STATE_NORMAL
    npicker = None
    draw_boxes = False

    def __init__ (self, upper = 9, text = ''):
        gtk.Widget.__init__(self)
        self.upper = upper
        self.parent_win = None
        self.timer = None
        self.font = self.style.font_desc
        self.font.set_size(BASE_FONT_SIZE)
        self.note_font = self.font.copy()
        self.note_font.set_size(NOTE_FONT_SIZE)
        self.set_property('can-focus', True)
        self.set_property('events', gtk.gdk.ALL_EVENTS_MASK)
        self.connect('button-press-event', self.button_press_cb)
        self.connect('key-release-event', self.key_press_cb)
        self.connect('enter-notify-event', self.pointer_enter_cb)
        self.connect('leave-notify-event', self.pointer_leave_cb)
        self.connect('focus-in-event', self.focus_in_cb)
        self.connect('focus-out-event', self.focus_out_cb)
        self.connect('motion-notify-event', self.motion_notify_cb)
        self.set_text(text)

    def set_parent_win(self, new_parent):
        self.parent_win = new_parent

    def set_timer(self, new_timer):
        self.timer = new_timer

    def pointer_enter_cb (self, *args):
        if not self.is_focus():
            self.set_state(gtk.STATE_PRELIGHT)

    def pointer_leave_cb (self, *args):
        self.set_state(self.base_state)
        self._toggle_box_drawing_(False)

    def focus_in_cb (self, *args):
        self.set_state(gtk.STATE_SELECTED)
        self.base_state = gtk.STATE_SELECTED

    def focus_out_cb (self, *args):
        self.set_state(gtk.STATE_NORMAL)
        self.base_state = gtk.STATE_NORMAL
        self.destroy_npicker()

    def destroy_npicker (self):
        if self.npicker:
            self.npicker.destroy()
            self.npicker = None

    def motion_notify_cb (self, *args):
        if self.is_focus() and not self.read_only:
            self._toggle_box_drawing_(True)
        else:
            self._toggle_box_drawing_(False)

    def _toggle_box_drawing_ (self, val):
        if val and not self.draw_boxes:
            self.draw_boxes = True
            self.queue_draw()
        if (not val) and self.draw_boxes:
            self.draw_boxes = False
            self.queue_draw()

    def button_press_cb (self, w, e):
        if self.read_only:
            return
        if e.type == gtk.gdk._2BUTTON_PRESS:
            # ignore second click (this makes a double click in the
            # middle of a cell get us a display of the numbers, rather
            # than selecting a number.
            return
        if self.is_focus():
            x, y = e.get_coords()
            alloc = self.get_allocation()
            my_w = alloc.width
            my_h = alloc.height
            border_height = float(BORDER_WIDTH)/BASE_SIZE

            if float(y)/my_h < border_height:
                self.show_note_editor(top = True)
            elif float(y)/my_h > (1-border_height):
                self.show_note_editor(top = False)
            elif not self.npicker:
                # In this case we're a normal old click...
                # makes sure there is only one numer selector
                self.show_number_picker()
        else:
            self.grab_focus()

    def key_press_cb (self, w, e):
        if self.read_only:
            return
        if self.npicker: # kill number picker no matter what is pressed
            self.destroy_npicker()
        txt = gtk.gdk.keyval_name(e.keyval)
        if type(txt) == type(None):
            # Make sure we don't trigger on unplugging the A/C charger etc
            return
        txt = txt.replace('KP_', '')
        if self.get_text() == txt:
            # If there's no change, do nothing
            return
        if txt in ['0', 'Delete', 'BackSpace']:
            self.set_text_interactive('')
        elif txt in ['n', 'N']:
            self.show_note_editor(top = True)
        elif txt in ['m', 'M']:
            self.show_note_editor(top = False)
        # And then add the new value if need be
        elif txt in [str(n) for n in range(1, self.upper+1)]:
            # First do a removal event -- this is something of a
            # kludge, but it works nicely with old code that was based
            # on entries, which also behave this way (they generate 2
            # events for replacing a number with a new number - a
            # removal event and an addition event)
            if self.get_text():
                self.set_text_interactive('')
            # Then add
            self.set_text_interactive(txt)

    def note_changed_cb (self, w, top = False):
        if top:
            self.set_note_text_interactive(top_text = w.get_text())
        else:
            self.set_note_text_interactive(bottom_text = w.get_text())

    def note_focus_in(self, win, evt):
        if (self.timer):
            self.timer.resume_timing()

    def note_focus_out(self, wgt, evt):
        if (self.timer):
            self.timer.pause_timing()

    def show_note_editor (self, top = True):
        alloc = self.get_allocation()
        w = gtk.Window()
        w.set_property('skip-pager-hint', True)
        w.set_property('skip-taskbar-hint', True)
        w.set_decorated(False)
        w.set_position(gtk.WIN_POS_MOUSE)
        w.set_size_request(alloc.width, alloc.height/2)
        if self.parent_win:
            w.set_transient_for(self.parent_win)
        f = gtk.Frame()
        e = gtk.Entry()
        f.add(e)
        if top:
            e.set_text(self.top_note_text)
        else:
            e.set_text(self.bottom_note_text)
        w.add(f)
        e.connect('changed', self.note_changed_cb, top)
        e.connect('focus-in-event', self.note_focus_in)
        e.connect('focus-out-event', lambda e, ev, w: w.destroy(), w)
        e.connect('focus-out-event', self.note_focus_out)
        e.connect('activate', lambda e, w: w.destroy(), w)
        x, y = self.window.get_origin()
        if top:
            w.move(x, y)
        else:
            w.move(x, y+int(alloc.height*0.6))
        w.show_all()
        e.grab_focus()

    def number_changed_cb (self, num_selector):
        self.destroy_npicker()
        self.set_text_interactive('')
        newval = num_selector.get_value()
        if newval:
            self.set_text_interactive(str(newval))

    def show_number_picker (self):
        w = gtk.Window(type = gtk.WINDOW_POPUP)
        ns = NumberSelector(upper = self.upper, default = self.get_value())
        ns.connect('changed', self.number_changed_cb)
        w.grab_focus()
        w.add(ns)
        r = w.get_allocation()
        my_origin = self.window.get_origin()
        x, y = self.window.get_size()
        popupx, popupy = w.get_size()
        overlapx = popupx-x
        overlapy = popupy-y
        w.move(my_origin[0]-(overlapx/2), my_origin[1]-(overlapy/2))
        w.show()
        self.npicker = w

    def set_text_interactive (self, text):
        self.emit('value-about-to-change')
        self.set_text(text)
        self.queue_draw()
        self.emit('changed')

    def set_font (self, font):
        if type(font) == str:
            font = pango.FontDescription(font)
        self.font = font
        if self.text:
            self.set_text(self.text)
        self.queue_draw()

    def set_note_font (self, font):
        if type(font) == str:
            font = pango.FontDescription(font)
        self.note_font = font
        if self.top_note_text or self.bottom_note_text:
            self.set_note_text(self.top_note_text,
                               self.bottom_note_text)
        self.queue_draw()

    def set_text (self, text):
        self.text = text
        self._layout = self.create_pango_layout(text)
        self._layout.set_font_description(self.font)

    def set_notes (self, notes):
        """Hackish method to allow easy use of Undo API.

        Undo API requires a set method that is called with one
        argument (the result of a get method)"""
        self.set_note_text(top_text = notes[0],
                           bottom_text = notes[1])
        self.queue_draw()

    def set_note_text (self, top_text = None, bottom_text = None):
        if top_text is not None:
            self.top_note_text = top_text
            self._top_note_layout = self.create_pango_layout(top_text)
            self._top_note_layout.set_font_description(self.note_font)
        if bottom_text is not None:
            self.bottom_note_text = bottom_text
            self._bottom_note_layout = self.create_pango_layout(bottom_text)
            self._bottom_note_layout.set_font_description(self.note_font)
        self.queue_draw()

    def set_note_text_interactive (self, *args, **kwargs):
        self.emit('value-about-to-change')
        self.set_note_text(*args, **kwargs)
        self.emit('notes-changed')

    def do_realize (self):
        # The do_realize method is responsible for creating GDK (windowing system)
        # resources. In this example we will create a new gdk.Window which we
        # then draw on

        # First set an internal flag telling that we're realized
        self.set_flags(self.flags() | gtk.REALIZED)

        # Create a new gdk.Window which we can draw on.
        # Also say that we want to receive exposure events by setting
        # the event_mask
        self.window = gtk.gdk.Window(
            self.get_parent_window(),
            width = self.allocation.width,
            height = self.allocation.height,
            window_type = gtk.gdk.WINDOW_CHILD,
            wclass = gtk.gdk.INPUT_OUTPUT,
            event_mask = self.get_events() | gtk.gdk.EXPOSURE_MASK)

        # Associate the gdk.Window with ourselves, Gtk+ needs a reference
        # between the widget and the gdk window
        self.window.set_user_data(self)

        # Attach the style to the gdk.Window, a style contains colors and
        # GC contextes used for drawing
        self.style.attach(self.window)

        # The default color of the background should be what
        # the style (theme engine) tells us.
        self.style.set_background(self.window, gtk.STATE_NORMAL)
        self.window.move_resize(*self.allocation)

    def do_unrealize (self):
        # The do_unrealized method is responsible for freeing the GDK resources

        # De-associate the window we created in do_realize with ourselves
        self.window.set_user_data(None)

    def do_size_request (self, requisition):
        # The do_size_request method Gtk+ is calling on a widget to ask
        # it the widget how large it wishes to be. It's not guaranteed
        # that gtk+ will actually give this size to the widget

        # In this case, we say that we want to be as big as the
        # text is, and a square
        width, height = self._layout.get_size()
        if width > height:
            side = width/pango.SCALE
        else:
            side = height/pango.SCALE
        (requisition.width, requisition.height) = (side, side)

    def do_size_allocate(self, allocation):
        # The do_size_allocate is called by when the actual size is known
        # and the widget is told how much space could actually be allocated

        # Save the allocated space
        self.allocation = allocation

        # If we're realized, move and resize the window to the
        # requested coordinates/positions
        if self.flags() & gtk.REALIZED:
            self.window.move_resize(*allocation)

    def do_expose_event(self, event):
        # The do_expose_event is called when the widget is asked to draw itself
        # Remember that this will be called a lot of times, so it's usually
        # a good idea to write this code as optimized as it can be, don't
        # Create any resources in here.
        x, y, w, h = self.allocation
        cr = self.window.cairo_create()
        if h < w:
            scale = h/float(BASE_SIZE)
        else:
            scale = w/float(BASE_SIZE)
        cr.scale(scale, scale)
        self.draw_background_color(cr)
        if self.is_focus():
            self.draw_highlight_box(cr)
        self.draw_normal_box(cr)
        self.draw_text(cr)
        if self.draw_boxes and self.is_focus():
            self.draw_note_area_highlight_box(cr)


    def draw_background_color (self, cr):
        if self.read_only:
            if self.custom_background_color:
                r, g, b = self.custom_background_color
                cr.set_source_rgb(
                    r*0.6, g*0.6, b*0.6
                    )
            else:
                cr.set_source_color(self.style.base[gtk.STATE_INSENSITIVE])
        elif self.is_focus():
            cr.set_source_color(self.style.base[gtk.STATE_SELECTED])
        elif self.custom_background_color:
            cr.set_source_rgb(*self.custom_background_color)
        else:
            cr.set_source_color(
                self.style.base[self.state]
                )
        cr.rectangle(
            0, 0, BASE_SIZE, BASE_SIZE
            )
        cr.fill()

    def draw_normal_box (self, cr):
        state = self.state
        if state == gtk.STATE_SELECTED:
            # When the widget is selected, we still want the outer box to look normal
            state = gtk.STATE_NORMAL
        cr.set_source_color(
            self.style.mid[state]
            )
        cr.rectangle(
            NORMAL_LINE_WIDTH*0.5,
            NORMAL_LINE_WIDTH*0.5,
            BASE_SIZE-NORMAL_LINE_WIDTH,
            BASE_SIZE-NORMAL_LINE_WIDTH,
            )
        cr.set_line_width(NORMAL_LINE_WIDTH)
        cr.set_line_join(cairo.LINE_JOIN_ROUND)
        cr.stroke()
        # And now draw a thinner line around the very outside...
        cr.set_source_color(
            self.style.dark[state]
            )
        cr.rectangle(
            NORMAL_LINE_WIDTH*0.25,
            NORMAL_LINE_WIDTH*0.25,
            BASE_SIZE-NORMAL_LINE_WIDTH*0.5,
            BASE_SIZE-NORMAL_LINE_WIDTH*0.5,
            )
        cr.set_line_width(NORMAL_LINE_WIDTH*0.5)
        cr.set_line_join(cairo.LINE_JOIN_MITER)
        cr.stroke()

    def draw_highlight_box (self, cr):
        cr.set_source_color(
            self.style.base[gtk.STATE_SELECTED]
            )
        cr.rectangle(
            # left-top
            BORDER_LINE_WIDTH*0.5,
            BORDER_LINE_WIDTH*0.5,
            # bottom-right
            BASE_SIZE-(BORDER_LINE_WIDTH),
            BASE_SIZE-(BORDER_LINE_WIDTH),
            )
        cr.set_line_width(BORDER_LINE_WIDTH)
        cr.set_line_join(cairo.LINE_JOIN_ROUND)
        cr.stroke()

    def draw_note_area_highlight_box (self, cr):
        # set up our paint brush...
        cr.set_source_color(
            self.style.mid[self.state]
            )
        cr.set_line_width(NORMAL_LINE_WIDTH)
        cr.set_line_join(cairo.LINE_JOIN_ROUND)
        # top rectangle
        cr.rectangle(NORMAL_LINE_WIDTH*0.5,
                     NORMAL_LINE_WIDTH*0.5,
                     BASE_SIZE-NORMAL_LINE_WIDTH,
                     BORDER_WIDTH-NORMAL_LINE_WIDTH)
        cr.stroke()
        # bottom rectangle
        cr.rectangle(NORMAL_LINE_WIDTH*0.5, #x
                     BASE_SIZE - BORDER_WIDTH-(NORMAL_LINE_WIDTH*0.5), #y
                     BASE_SIZE-NORMAL_LINE_WIDTH, #x2
                     BASE_SIZE-NORMAL_LINE_WIDTH #y2
                     )
        cr.stroke()

    def draw_text (self, cr):
        if self.text_color:
            cr.set_source_rgb(*self.text_color)
        elif self.read_only:
            cr.set_source_color(self.style.text[gtk.STATE_NORMAL])
        else:
            cr.set_source_color(self.style.text[self.state])
        # And draw the text in the middle of the allocated space
        if self._layout:
            fontw, fonth = self._layout.get_pixel_size()
            cr.move_to(
                (BASE_SIZE/2)-(fontw/2),
                (BASE_SIZE/2) - (fonth/2),
                )
            cr.update_layout(self._layout)
            cr.show_layout(self._layout)
        cr.set_source_color(self.style.text[self.state])
        # And draw any note text...
        if self._top_note_layout:
            fontw, fonth = self._top_note_layout.get_pixel_size()
            cr.move_to(
                NORMAL_LINE_WIDTH,
                0,
                )
            cr.update_layout(self._top_note_layout)
            cr.show_layout(self._top_note_layout)
        if self._bottom_note_layout:
            fontw, fonth = self._bottom_note_layout.get_pixel_size()
            cr.move_to(
                NORMAL_LINE_WIDTH,
                BASE_SIZE-fonth,
                )
            cr.update_layout(self._bottom_note_layout)
            cr.show_layout(self._bottom_note_layout)

    def set_text_color (self, color):
        self.text_color = color
        self.queue_draw()

    def set_background_color (self, color):
        self.custom_background_color = color
        self.queue_draw()

    def hide_notes (self):
        pass

    def show_notes (self):
        pass

    def set_value_from_undo (self, v):
        self.set_value(v)
        self.emit('undo_change')

    def set_value (self, v):
        if 0 < v <= self.upper:
            self.set_text(str(v))
        else:
            self.set_text('')
        self.queue_draw()

    def get_value (self):
        try:
            return int(self.text)
        except:
            return None

    def get_text (self):
        return self.text

    def get_note_text (self):
        return self.top_note_text, self.bottom_note_text

class SudokuNumberBox (NumberBox):

    normal_color = None
    highlight_color = ERROR_HIGHLIGHT_COLOR

    def set_color (self, color):
        self.normal_color = color
        self.set_text_color(self.normal_color)

    def unset_color (self):
        self.set_color(None)

    def set_error_highlight (self, val):
        if val:
            self.set_text_color((1.0, 0, 0))
        else:
            self.set_text_color(self.normal_color)

    def set_read_only (self, val):
        self.read_only = val
        if not hasattr(self, 'bold_font'):
            self.normal_font = self.font
            self.bold_font = self.font.copy()
            self.bold_font.set_weight(pango.WEIGHT_BOLD)
        if self.read_only:
            self.set_font(self.bold_font)
        else:
            self.set_font(self.normal_font)
        self.queue_draw()

    def set_impossible (self, val):
        if val:
            self.set_text('X')
        else: self.set_text('')


gobject.type_register(NumberBox)

if __name__ == '__main__':
    window = gtk.Window()
    window.connect('delete-event', gtk.main_quit)

    def test_number_selector ():
        nselector = NumberSelector(default = 3)
        def tell_me (b):
            print 'value->', b.get_value()
        nselector.connect('changed', tell_me)
        window.add(nselector)

    def test_number_box ():
        window.set_size_request(100, 100)
        nbox = NumberBox()
        window.add(nbox)

#    test_number_selector()
    test_number_box()
    window.show_all()
    gtk.main()
