import gtk, cairo, pango, gobject
import colors
import math
from simple_debug import simple_debug
from gettext import gettext as _
import sudoku

TRACKER_COLORS = [
    # Use tango colors recommended here:
    # http://tango.freedesktop.org/Tango_Icon_Theme_Guidelines
    tuple([x/255.0 for x in cols]) for cols in
    [(32,74,135), # Sky Blue 3
     (78,154,6), # Chameleon 3
     (206,92,0), # Orange 3
     (143,89,2), # Chocolate 3
     (92,53,102), # Plum 3
     (85,87,83), # Aluminium 5
     (196,160,0), # Butter 3

     ]
    ]

def gtkcolor_to_rgb (c):
    return c.red/float(2**16),c.green/float(2**16),c.blue/float(2**16)

def overlay (color_1, color_2, method=1):
    return color_1[0]+color_2[0]*method,color_1[1]+color_2[1]*method,color_1[2]+color_2[2]*method

ERROR_HIGHLIGHT_COLOR = (1.0,0,0)

BASE_SIZE = 35 # The "normal" size of a box (in pixels)

# And the standard font-sizes -- these should fit nicely with the
# BASE_SIZE
BASE_FONT_SIZE = pango.SCALE * 13 
NOTE_FONT_SIZE = pango.SCALE * 6

BORDER_WIDTH = 9.0 # The size of space we leave for a box

BORDER_LINE_WIDTH = 4 # The size of the line we draw around a selected box

LITTLE_LINE_WIDTH = 0.25
NORMAL_LINE_WIDTH = 1 # The size of the line we draw around a box

SPACING_FACTOR = 40 # The size of a box compared (roughly) to the size
                    # of padding -- the larger this is, the smaller
                    # the spaces
SMALL_TO_BIG_FACTOR = 3 # The number of times wider than a small line a big line is.

class NumberSelector (gtk.EventBox):

    __gsignals__ = {
        'changed':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,()),
        }
    
    def __init__ (self,default=None,upper=9):
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
                if n==self.value:
                    l.set_markup('<b><span size="x-small">%s</span></b>'%n)
                else:
                    l.set_markup('<span size="x-small">%s</span>'%n)
                b.add(l)
                b.set_relief(gtk.RELIEF_HALF)
                l = b.get_children()[0]
                b.set_border_width(0)
                l.set_padding(0,0)
                l.get_alignment()
                b.connect('clicked',self.number_clicked,n)
                self.table.attach(b,x,x+1,y,y+1)
                n+=1
        if self.value:
            db = gtk.Button()
            l = gtk.Label()
            l.set_markup_with_mnemonic('<span size="x-small">'+_('_Clear')+'</span>')
            db.add(l); l.show()
            db.connect('clicked',self.number_clicked,0)
            self.table.attach(db,0,side,y+1,y+2)
        self.connect('key-release-event',self.key_press_cb)
        self.show_all()

    def key_press_cb (self, w, e):
        txt = gtk.gdk.keyval_name(e.keyval)
        if txt == 'Escape':
            self.emit('changed')
        elif txt in ['0','Delete','BackSpace']:
            self.value = None
            self.emit('changed')
        else:
            try:
                self.value = int(txt)
            except:
                print "Can't make sense of %s"%txt
            else:
                self.emit('changed')

    def number_clicked (self, button, n):
        self.value = n
        self.emit('changed')

    def get_value (self):
        return self.value

    def set_value (self,n):
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
        'value-about-to-change':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,()),
        'changed':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,()),
        # undo-change - A hacky way to handle the fact that we want to
        # respond to undo's changes but we don't want undo to respond
        # to itself...
        'undo-change':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,()), 
        'notes-changed':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,()),
        }

    base_state = gtk.STATE_NORMAL
    number_picker_mode = False
    draw_boxes = False
    
    def __init__ (self, upper=9, text=''):
        gtk.Widget.__init__(self)
        self.upper = upper
        self.font = self.style.font_desc
        self.font.set_size(BASE_FONT_SIZE)
        self.note_font = self.font.copy()
        self.note_font.set_size(NOTE_FONT_SIZE)
        self.set_property('can-focus',True)
        self.set_property('events',gtk.gdk.ALL_EVENTS_MASK)
        self.connect('button-press-event',self.button_press_cb)
        self.connect('key-release-event',self.key_press_cb)
        self.connect('enter-notify-event',self.pointer_enter_cb)
        self.connect('leave-notify-event',self.pointer_leave_cb)
        self.connect('focus-in-event',self.focus_in_cb)
        self.connect('focus-out-event',self.focus_out_cb)
        self.connect('motion-notify-event',self.motion_notify_cb)
        self.set_text(text)

    def pointer_enter_cb (self, *args):
        if not self.is_focus(): self.set_state(gtk.STATE_PRELIGHT)
    def pointer_leave_cb (self, *args):
        self.set_state(self.base_state)
        self._toggle_box_drawing_(False)

    def focus_in_cb (self, *args):
        self.set_state(gtk.STATE_SELECTED)
        self.base_state = gtk.STATE_SELECTED

    def focus_out_cb (self, *args):
        self.set_state(gtk.STATE_NORMAL)
        self.base_state = gtk.STATE_NORMAL
        self.number_picker_mode = False

    def motion_notify_cb (self, *args):
        if self.is_focus():
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
        if e.type == gtk.gdk._2BUTTON_PRESS:
            # ignore second click (this makes a double click in the
            # middle of a cell get us a display of the numbers, rather
            # than selecting a number.
            return
        if self.is_focus():
            x,y = e.get_coords()        
            alloc = self.get_allocation()
            my_w = alloc.width
            my_h = alloc.height
            if self.number_picker_mode:
                # If we are a number picker...
                xperc = float(x)/my_w
                yperc = float(y)/my_h
                if xperc > 0.75:
                    # If we're in the right quadrant, we get out of number picker mode
                    self.set_text_interactive('')
                    self.number_picker_mode = False
                    self.queue_draw()
                    return
                else:
                    if xperc > 0.5: xval = 3
                    elif xperc > 0.25: xval = 2
                    else: xval = 1
                    if yperc > 0.66: yval = 6
                    elif yperc > 0.33: yval = 3
                    else: yval = 0
                    self.number_picker_mode = False
                    self.set_text_interactive('')
                    self.set_text_interactive(str(xval+yval))
            else:
                border_height = float(BORDER_WIDTH)/BASE_SIZE
                if float(y)/my_h < border_height:
                    self.show_note_editor(top=True)
                elif float(y)/my_h > (1-border_height):
                    self.show_note_editor(top=False)
                else:
                    # In this case we're a normal old click...
                    self.show_number_picker()
        else:
            self.grab_focus()

    def key_press_cb (self, w, e):
        if self.read_only: return
        txt = gtk.gdk.keyval_name(e.keyval)
        if type(txt) == type(None):
            # Make sure we don't trigger on unplugging the A/C charger etc
            return        
        txt = txt.replace('KP_', '')
        if self.get_text() == txt:
            # If there's no change, do nothing
            return
        if txt in ['0','Delete','BackSpace']:
            self.set_text_interactive('')
        elif txt in ['n','N']:
            self.show_note_editor(top=True)
        elif txt in ['m','M']:
            self.show_note_editor(top=False)
        # And then add the new value if need be
        elif txt in [str(n) for n in range(1,self.upper+1)]:
            # First do a removal event -- this is something of a
            # kludge, but it works nicely with old code that was based
            # on entries, which also behave this way (they generate 2
            # events for replacing a number with a new number - a
            # removal event and an addition event)
            if self.get_text(): self.set_text_interactive('')
            # Then add
            self.set_text_interactive(txt)

    def show_note_editor (self, top=True):
        alloc = self.get_allocation()
        w = gtk.Window()
        w.set_type_hint(gtk.WINDOW_POPUP)
        w.set_decorated(False)
        w.set_position(gtk.WIN_POS_MOUSE)
        w.set_size_request(alloc.width,alloc.height/2)
        f = gtk.Frame()
        e = gtk.Entry()
        f.add(e)
        if top: e.set_text(self.top_note_text)
        else: e.set_text(self.bottom_note_text)
        w.add(f)
        if top:
            e.connect('changed',lambda *args: self.set_note_text_interactive(top_text=e.get_text()))
        else:
            e.connect('changed',lambda *args: self.set_note_text_interactive(bottom_text=e.get_text()))
        e.connect('focus-out-event',lambda *args: w.destroy())
        e.connect('activate',lambda *args: w.destroy())
        x,y = self.window.get_origin()
        if top:
            w.move(x,y)
        else:
            w.move(x,y+int(alloc.height*0.6))
        w.show_all()
        e.grab_focus()

    def show_number_picker (self):
        #self.number_picker_mode = True
        #return
        w = gtk.Window()
        w.set_app_paintable(True)
        w.set_type_hint(gtk.WINDOW_POPUP)
        w.set_decorated(False)
        ns = NumberSelector(upper=self.upper,default=self.get_value())
        def number_changed_cb (b):
            w.destroy()
            self.set_text_interactive('')
            self.set_text_interactive(str(b.get_value()))
        ns.connect('changed',number_changed_cb)
        w.grab_focus()
        w.connect('focus-out-event',lambda *args: w.destroy())
        w.add(ns)
        w.show()
        r = w.get_allocation()
        my_origin = self.window.get_origin()
        x,y = self.window.get_size()
        w.show()
        popupx,popupy = w.get_size()
        overlapx = popupx-x
        overlapy = popupy-y
        #print 'origin is ',my_origin
        #print 'widget size is',x,y
        #print 'popup size is',popupx,popupy
        #print 'overlaps are ',overlapx,overlapy
        w.move(my_origin[0]-(overlapx/2),my_origin[1]-(overlapy/2))
        self.npicker = w

    def set_text_interactive (self,text):
        self.emit('value-about-to-change')
        self.set_text(text)
        self.queue_draw()
        self.emit('changed')        

    def set_font (self, font):
        if type(font)==str:
            font = pango.FontDescription(font)
        self.font = font
        if self.text: self.set_text(self.text)
        self.queue_draw()

    def set_note_font (self, font):
        if type(font)==str:
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
        self.set_note_text(top_text=notes[0],
                           bottom_text=notes[1])
        self.queue_draw()

    def set_note_text (self, top_text=None,bottom_text=None):
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
        self.set_note_text(*args,**kwargs)
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
            width=self.allocation.width,
            height=self.allocation.height,
            window_type=gtk.gdk.WINDOW_CHILD,
            wclass=gtk.gdk.INPUT_OUTPUT,
            event_mask=self.get_events() | gtk.gdk.EXPOSURE_MASK)

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
        requisition.width = side; requisition.height = side

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
        if h<w:
            scale = h/float(BASE_SIZE)
        else:
            scale = w/float(BASE_SIZE)
        cr.scale(scale,scale)
        self.draw_background_color(cr)
        if self.number_picker_mode:
            self.draw_numbers(cr)
            return
        if self.is_focus():
            self.draw_highlight_box(cr)
        self.draw_normal_box(cr)
        self.draw_text(cr)
        if self.draw_boxes and self.is_focus():
            self.draw_note_area_highlight_box(cr)

    def draw_background_color (self, cr):        
        if self.read_only:
            if self.custom_background_color:
                #h,s,v = colors.rgb_to_hsv(*self.custom_background_color)
                #s = s*0.5 # Halve our saturation
                #v = v*0.5 # Halve our brightness
                r,g,b = self.custom_background_color
                cr.set_source_rgb(
                    r*0.6,g*0.6,b*0.6
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
            0,0,BASE_SIZE,BASE_SIZE
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
            #self.style.dark[gtk.STATE_NORMAL]
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

    def draw_highlight_box (self,cr):
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
        cr.rectangle(NORMAL_LINE_WIDTH*0.5,#x
                     BASE_SIZE - BORDER_WIDTH-(NORMAL_LINE_WIDTH*0.5),#y
                     BASE_SIZE-NORMAL_LINE_WIDTH,#x2
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

    def draw_numbers (self, cr):        
        if not hasattr(self,'number_text'):
            self.small_digit_height = 1
            self.small_digit_width = 1
            self.number_text = []
            for n in range(self.upper): # + ['X']:
                if type(n)==int:
                    n = str(n+1)
                txt = self.create_pango_layout(n)
                txt.set_font_description(self.note_font)
                if not hasattr(self,'bold_note_font'):
                    self.bold_note_font = self.note_font.copy()
                    self.bold_note_font.set_weight(pango.WEIGHT_BOLD)
                bold_txt = self.create_pango_layout(n)
                bold_txt.set_font_description(self.bold_note_font)
                self.number_text.append((txt,bold_txt))
                w,h = bold_txt.get_pixel_size()
                if w > self.small_digit_width: self.small_digit_width = w*1.2
                if h > self.small_digit_height: self.small_digit_height = h
        val = self.get_value()
        cols = (BASE_SIZE-NORMAL_LINE_WIDTH*2) / self.small_digit_width
        rows = (BASE_SIZE-NORMAL_LINE_WIDTH*2) / self.small_digit_height
        #if cols > 4: cols=4
        #if rows > 4: rows=4
        cols = 3; rows=3
        row_size = BASE_SIZE/rows
        col_size = BASE_SIZE/cols
        n = 0
        for y in range(rows):
            for x in range(cols):
                if y < 2 and x > 2: continue
                if n >= len(self.number_text):
                    break
                txt = self.number_text[n]
                if val==(n+1):
                    layout = txt[1] # grab bold layout
                else:
                    layout = txt[0] # grab normal layout
                w,h = layout.get_pixel_size()
                xpadding = (col_size - w)/2
                ypadding = (row_size - h)/2
                # draw little boxes...
                cr.set_source_color(gtk.gdk.Color(2**16,0,0))
                cr.set_line_width(LITTLE_LINE_WIDTH)
                cr.rectangle(LITTLE_LINE_WIDTH*0.5+NORMAL_LINE_WIDTH*0.5+(x*col_size),
                             LITTLE_LINE_WIDTH*0.5+NORMAL_LINE_WIDTH*0.5+(y*row_size),
                             LITTLE_LINE_WIDTH*0.5+NORMAL_LINE_WIDTH*0.5+((x+1)*col_size),
                             LITTLE_LINE_WIDTH*0.5+NORMAL_LINE_WIDTH*0.5+((y+1)*row_size),
                             )
                cr.stroke()
                cr.set_source_color(self.style.text[self.state])
                cr.move_to(NORMAL_LINE_WIDTH+(x*col_size)+xpadding,
                             NORMAL_LINE_WIDTH+(y*row_size)+ypadding)
                cr.update_layout(layout)
                cr.show_layout(layout)
                n+=1

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

    def set_value (self,v):
        if 0 < v <= self.upper:
            self.set_text(str(v))
        else:
            self.set_text('')
        self.queue_draw()

    def get_value (self):
        try: return int(self.text)
        except: return None

    def get_text (self): return self.text
    def get_note_text (self): return self.top_note_text,self.bottom_note_text

class SudokuNumberBox (NumberBox):

    normal_color = None
    highlight_color = ERROR_HIGHLIGHT_COLOR

    def set_color (self, color):
        self.normal_color = color
        self.set_text_color(self.normal_color)

    def unset_color (self): self.set_color(None)

    def set_error_highlight (self, val):
        if val:
            self.set_text_color((1.0,0,0))
        else:
            self.set_text_color(self.normal_color)

    def set_read_only (self, val):
        self.read_only = val
        if not hasattr(self,'bold_font'):
            self.normal_font = self.font
            self.bold_font = self.font.copy()
            self.bold_font.set_weight(pango.WEIGHT_BOLD)
        if self.read_only:
            self.set_font(self.bold_font)
        else:
            self.set_font(self.normal_font)
        self.queue_draw()

    def set_impossible (self, val):
        if val: self.set_text('X')
        else: self.set_text('')

    
gobject.type_register(NumberBox)

class SudokuNumberGrid (gtk.AspectFrame):

    def __init__ (self, group_size=9):
        self.table = gtk.Table(rows=group_size,columns=group_size,homogeneous=True)
        self.group_size = group_size        
        self.__entries__ = {}
        for x in range(self.group_size):
            for y in range(self.group_size):
                e = SudokuNumberBox(upper=self.group_size)
                e.x = x
                e.y = y
                self.table.attach(e,x,x+1,y,y+1,
                                  #xpadding=2,
                                  #ypadding=2)
                                  )
                self.__entries__[(x,y)] = e
        gtk.AspectFrame.__init__(self,obey_child=False)
        self.set_shadow_type(gtk.SHADOW_NONE)
        self.eb = gtk.EventBox()
        #self.alignment = gtk.Alignment()
        #self.alignment.add(self.eb)
        self.eb.add(self.table)
        #self.add(self.alignment)
        self.add(self.eb)
        self.connect('size-allocate',self.allocate_cb)
        self.show_all()

    def allocate_cb (self, w, rect):
        if rect.width > rect.height: side = rect.height
        else: side = rect.width
        # we want our small spacing to be 1/15th the size of a box
        spacing = int(rect.width / (self.group_size * SPACING_FACTOR))
        if spacing == 0: spacing = 1
        if hasattr(self,'small_spacing') and spacing == self.small_spacing:
            return
        else:
            self.change_spacing(spacing)

    def change_spacing (self, small_spacing):
        self.small_spacing = small_spacing
        self.big_spacing = small_spacing*SMALL_TO_BIG_FACTOR
        self.table.set_row_spacings(small_spacing)
        self.table.set_col_spacings(small_spacing)
        box_side = int(math.sqrt(self.group_size))
        for n in range(1,box_side):
            self.table.set_row_spacing(box_side*n-1,self.big_spacing)
            self.table.set_col_spacing(box_side*n-1,self.big_spacing)
        self.table.set_border_width(self.big_spacing)
        
    def get_focused_entry (self):
        for e in self.__entries__.values():
            if e.is_focus():
                return e

    def set_bg_color (self, color):
        if type(color)==str:
            try: color = gtk.gdk.color_parse(color)
            except:
                print 'set_bg_color handed Bad color',color
                return
        self.eb.modify_bg(gtk.STATE_NORMAL,color)
        self.eb.modify_base(gtk.STATE_NORMAL,color)
        self.eb.modify_fg(gtk.STATE_NORMAL,color)
        self.table.modify_bg(gtk.STATE_NORMAL,color)
        self.table.modify_base(gtk.STATE_NORMAL,color)
        self.table.modify_fg(gtk.STATE_NORMAL,color)
        for e in self.__entries__.values():
            e.modify_bg(gtk.STATE_NORMAL,color)

class ParallelDict (dict):
    """A handy new sort of dictionary for tracking conflicts.

    pd = ParallelDict()
    pd[1] = [2,3,4] # 1 is linked with 2,3 and 4
    pd -> {1:[2,3,4],2:[1],3:[1],4:[1]}
    pd[2] = [1,3,4] # 2 is linked with 3 and 4 as well as 1
    pd -> {1: [2,3,4],2:[3,4],3:[1,2],4:[1,2]}
    Now for the cool part...
    del pd[1]
    pd -> {2: [2,3],3:[2],4:[2]}
    
    Pretty neat, no?
    """
    def __init__ (self, *args):
        dict.__init__(self,*args)

    def __setitem__ (self, k, v):
        dict.__setitem__(self,k,set(v))
        for i in v:
            if i == k: continue
            if self.has_key(i):
                self[i].add(k)
            else:
                dict.__setitem__(self,i,set([k]))

    def __delitem__ (self, k):
        v=self[k]
        dict.__delitem__(self,k)
        for i in v:
            if i==k: continue
            if self.has_key(i):
                # Make sure we have a reference to i. If we don't
                # something has gone wrong... but according to bug
                # 385937 this has gone wrong at least once, so we'd
                # better check for it.
                if k in self[i]: self[i].remove(k)
                if not self[i]:
                    # If k was the last value in the list of values
                    # for i, then we delete i from our dictionary
                    dict.__delitem__(self,i)

class SudokuGameDisplay (SudokuNumberGrid, gobject.GObject):

    __gsignals__ = {
        'focus-changed':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,()),
        'puzzle-finished':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,())
        }

    do_highlight_cells = False
    
    @simple_debug
    def __init__ (self,grid=None,group_size=9,
                  show_impossible_implications=False):
        group_size=int(group_size)
        self.hints = 0
        self.always_show_hints = False
        self.auto_fills = 0
        self.show_impossible_implications = show_impossible_implications
        self.impossible_hints = 0
        self.impossibilities = []
        self.trackers = {}
        self.__trackers_tracking__ = {}
        self.__colors_used__ = [None,ERROR_HIGHLIGHT_COLOR]
        gobject.GObject.__init__(self)
        SudokuNumberGrid.__init__(self,group_size=group_size)
        self.setup_grid(grid,group_size)
        for e in self.__entries__.values():
            e.show()
            e.connect('undo-change',self.entry_callback)
            e.connect('changed',self.entry_callback)
            e.connect('focus-in-event',self.focus_callback)
        self.connect('focus-changed',self.highlight_cells)

    @simple_debug
    def focus_callback (self, e, event):
        self.focused = e
        self.emit('focus-changed')

    def get_highlight_colors (self):
        entry = self.__entries__.values()[0]
        default_color = gtkcolor_to_rgb(entry.style.bg[gtk.STATE_SELECTED])
        hsv = colors.rgb_to_hsv(*default_color)
        #print 'default rgb = ',default_color
        #print 'default hsv = ',hsv
        #print 'halve saturation'
        box_s = hsv[1]
        box_v = hsv[2]
        if box_v < 0.5: box_v = box_v*2
        if box_s > 0.75:
            box_s = box_s*0.5
        else:
            box_s = box_s*1.5
            if box_s > 1: box_s = 1.0
        #if box_s < 0.25: box_s = box_s*2
        #else: box_s = box_s*0.5
        self.box_color = colors.hsv_to_rgb(
            hsv[0],box_s,box_v
            )
        self.box_and_row_color = colors.rotate_hue_rgb(*self.box_color,**{'rotate_by':0.33/2})
        self.row_color = colors.rotate_hue_rgb(*self.box_color,**{'rotate_by':0.33})
        self.col_color = colors.rotate_hue_rgb(*self.box_color,**{'rotate_by':0.66})
        self.box_and_col_color = colors.rotate_hue_rgb(*self.box_color,**{'rotate_by':1.0-(0.33/2)})
        #print 'Default color = ',default_color
        #for att in ['box_color','row_color','box_and_col_color','col_color','box_and_row_color']:
        #    print att,'=',getattr(self,att)

    def toggle_highlight (self, val):
        self.do_highlight_cells = val
        self.unhighlight_cells()
        if hasattr(self,'focused') and self.focused: self.highlight_cells()

    def unhighlight_cells (self, *args):
        for e in self.__entries__.values(): e.set_background_color(None)

    def highlight_cells (self, *args):
        if not self.do_highlight_cells: return
        self.unhighlight_cells()
        if not hasattr(self,'box_color'): self.get_highlight_colors()
        my_x,my_y = self.focused.x,self.focused.y        
        for x,y in self.grid.col_coords[my_x]:
            if (x,y) != (my_x,my_y):
                self.__entries__[(x,y)].set_background_color(self.col_color)
        for x,y in self.grid.row_coords[my_y]:
            if (x,y) != (my_x,my_y):
                self.__entries__[(x,y)].set_background_color(self.row_color)
        for x,y in self.grid.box_coords[self.grid.box_by_coords[(my_x,my_y)]]:
            if (x,y) != (my_x,my_y):
                e = self.__entries__[(x,y)]
                if x==my_x:
                    e.set_background_color(self.box_and_col_color)
                elif y==my_y:
                    e.set_background_color(self.box_and_row_color)
                else:
                    e.set_background_color(self.box_color)
        

    @simple_debug
    def show_hint (self):        
        if hasattr(self,'focused'):
            entry = self.focused
            if entry.read_only or entry.get_text():
                pass
            else:
                self.show_hint_for_entry(entry,interactive=True)

    def show_hint_for_entry (self, entry, interactive=False):
        if interactive:
            set_method = entry.set_note_text_interactive
        else:
            set_method = entry.set_note_text
        vals=self.grid.possible_values(entry.x,entry.y)
        vals = list(vals)
        vals.sort()
        if vals:
            ''.join([str(v) for v in vals])
            txt = ''.join([str(v) for v in vals])
            if txt != entry.get_text():
                set_method(bottom_text=txt)
                self.hints += 1
        elif not entry.get_text():
            if entry.get_text() != 'X':
                self.hints += 1
                set_method(bottom_text='X')
        else:
            set_method(bottom_text="")

    @simple_debug
    def num_to_str (self, n):
        if n >= 10: return SuperNumberEntry.conversions[n]
        else: return str(n)

    @simple_debug
    def reset_grid (self):
        """Reset grid to its original setup.

        Return a list of items we removed so that callers can handle
        e.g. Undo properly"""
        removed = []
        for x in range(self.group_size):
            for y in range(self.group_size):
                if not self.grid.virgin._get_(x,y):
                    val = self.__entries__[(x,y)].get_value() # get the value from the user-visible grid, 
                    if val:
                        removed.append((x,y,val,self.trackers_for_point(x,y,val)))
                        self.remove(x,y,do_removal=True)
        return removed

    def clear_notes (self, clear_args={'top_text':'','bottom_text':''}):
        """Remove all notes."""
        self.removed = []
        for x in range(self.group_size):
            for y in range(self.group_size):
                e = self.__entries__[(x,y)]
                top,bottom = e.get_note_text()
                if top or bottom:
                    self.removed.append((x,y,(top,bottom)))
                    e.set_note_text(**clear_args)
                    e.queue_draw()
        return self.removed

    def clear_hints (self):
        self.clear_notes(clear_args={'bottom_text':''})
    
    @simple_debug
    def blank_grid (self):
        for x in range(self.group_size):
            for y in range(self.group_size):
                self.remove(x,y)
                e=self.__entries__[(x,y)]
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
        self.__colors_used__ = [None,ERROR_HIGHLIGHT_COLOR]
        self.blank_grid()
        self.setup_grid(grid,group_size)        

    @simple_debug
    def load_game (self, game):
        """Load a game.

        A game is simply a two lined string where the first line represents our
        virgin self and line two represents our game-in-progress.
        """
        self.blank_grid()
        if '\n' in game:
            virgin,in_prog = game.split('\n')
        else:
            virgin = game; in_prog = ''
        group_size=int(math.sqrt(len(virgin.split())))
        self.change_grid(virgin,group_size=group_size)
        # This int() will break if we go to 16x16 grids...
        if in_prog:
            values = [int(c) for c in in_prog.split()]
            for row in range(group_size):
                for col in range(group_size):
                    index = row * 9 + col
                    if values[index] and not self.grid._get_(col,row):
                        self.add_value(col,row,values[index])

    @simple_debug
    def setup_grid (self, grid, group_size):
        self.doing_initial_setup = True
        self.__error_pairs__ = ParallelDict()
        if isinstance(grid,sudoku.SudokuGrid):
            self.grid = sudoku.InteractiveSudoku(grid.grid,group_size=grid.group_size)
        else:
            self.grid = sudoku.InteractiveSudoku(grid,group_size=group_size)
        for x in range(group_size):
            for y in range(group_size):
                val=self.grid._get_(x,y)
                if val: self.add_value(x,y,val)
        self.doing_initial_setup = False

    @simple_debug
    def entry_callback (self, widget, *args):        
        if not widget.get_text():
            if self.grid and self.grid._get_(widget.x,widget.y):
                self.grid.remove(widget.x,widget.y)
            self.remove(widget.x,widget.y)
        else:
            self.entry_validate(widget)
        if self.show_impossible_implications:
            self.mark_impossible_implications(widget.x,widget.y)
        if self.always_show_hints:
            self.update_all_hints()

    def update_all_hints (self):
        for x in range(self.group_size):
            for y in range(self.group_size):
                e = self.__entries__[(x,y)]
                if e.read_only:
                    pass
                elif e.get_text():
                    e.set_note_text(bottom_text='')
                else:
                    self.show_hint_for_entry(e)

    @simple_debug
    def entry_validate (self, widget, *args):
        val = widget.get_value()
        try:
            self.add_value(widget.x,widget.y,val)
            if self.grid.check_for_completeness():
                self.emit('puzzle-finished')
        except sudoku.ConflictError, err:
            conflicts=self.grid.find_conflicts(err.x,err.y,err.value)
            for conflict in conflicts:
                widget.set_error_highlight(True)
                self.__entries__[conflict].set_error_highlight(True)
            self.__error_pairs__[(err.x,err.y)]=conflicts

    def add_value_to_ui (self, x, y, val, trackers=[]):
        """Add our value back to our grid come hell or high water.

        We add our value -- if there is an error, we make the value
        appear as if the user had typed it; i.e. it will show up with
        error highlighting."""
        try:
            self.add_value(x, y, val, trackers=[])
        except sudoku.ConflictError:
            self.entry_validate(self.__entries__[(x,y)])

    @simple_debug
    def add_value (self, x, y, val, trackers=[]):
        """Add value val at position x,y.

        If tracker is True, we track it with tracker ID tracker.

        Otherwise, we use any currently tracking trackers to track our addition.

        Providing the tracker arg is mostly useful for e.g. undo/redo
        or removed items.

        To specify NO trackers, use trackers=[-1]
        """
        self.__entries__[(x,y)].set_value(val)
        if self.doing_initial_setup:
            self.__entries__[(x,y)].set_read_only(True)
        self.grid.add(x,y,val,True)
        if trackers:
            for tracker in trackers:
                if tracker==-1: pass
                self.__entries__[(x,y)].set_color(self.get_tracker_color(tracker))
                self.trackers[tracker].append((x,y,val))
        elif True in self.__trackers_tracking__.values():        
            for k,v in self.__trackers_tracking__.items():
                if v:
                    self.__entries__[(x,y)].set_color(self.get_tracker_color(k))
                    self.trackers[k].append((x,y,val))
        self.__entries__[(x,y)].queue_draw()

    @simple_debug
    def remove (self, x, y, do_removal=False):
        """Remove x,y from our visible grid.

        If do_removal, remove it from our underlying grid as well.
        """        
        e=self.__entries__[(x,y)]
        if do_removal and self.grid and self.grid._get_(x,y):
            self.grid.remove(x,y)
        if self.__error_pairs__.has_key((x,y)):
            e.set_error_highlight(False)
            errors_removed = self.__error_pairs__[(x,y)]
            del self.__error_pairs__[(x,y)]
            for coord in errors_removed:
                # If we're not an error by some other pairing...
                if not self.__error_pairs__.has_key(coord):
                    linked_entry = self.__entries__[coord]
                    linked_entry.set_error_highlight(False)
                    # Its possible this highlighted error was never
                    # added to our internal grid, in which case we'd
                    # better make sure it is...
                    if not self.grid._get_(linked_entry.x,linked_entry.y):
                        # entry_validate will add the value to our
                        # internal grid if there are no other
                        # conflicts
                        self.entry_validate(linked_entry)
        # remove trackers
        for t in self.trackers_for_point(x,y):
            remove = []
            for crumb in self.trackers[t]:
                if crumb[0]==x and crumb[1]==y:
                    remove.append(crumb)
            for r in remove:
                self.trackers[t].remove(r)
        if e.get_text(): e.set_value(0)
        e.unset_color()

    @simple_debug
    def auto_fill (self):
        changed=self.grid.auto_fill()
        #changed=self.grid.fill_must_fills        
        #changed=self.grid.fill_deterministically()
        retval = []
        for coords,val in changed:
            self.add_value(coords[0],coords[1],val)
            retval.append((coords[0],coords[1],val))
            if self.show_impossible_implications:
                self.mark_impossible_implications(*coords)
        if retval: self.auto_fills += 1
        if self.grid.check_for_completeness():
            self.emit('puzzle-finished')
        return retval

    @simple_debug
    def auto_fill_current_entry (self):
        e = self.get_focused_entry()
        if not e: return
	filled = self.grid.auto_fill_for_xy(e.x,e.y)
        if filled and filled!=-1:
            self.add_value(filled[0][0],filled[0][1],filled[1])
    
    @simple_debug
    def mark_impossible_implications (self, x, y):
        if not self.grid: return
        implications = self.grid.find_impossible_implications(x,y)
        if implications:
            for x,y in implications:
                self.__entries__[(x,y)].set_impossible(True)
                if not (x,y) in self.impossibilities:
                    self.impossible_hints += 1
        for x,y in self.impossibilities:
            if not (x,y) in implications:
                self.__entries__[(x,y)].set_impossible(False)
        self.impossibilities = implications

    @simple_debug
    def create_tracker (self, identifier=0):
        if not identifier: identifier = 0
        while self.trackers.has_key(identifier): identifier+=1
        self.trackers[identifier]=[]
        #self.__trackers_tracking__[identifier]=True
        return identifier

    def trackers_for_point (self, x, y, val=None):
        if val:
            # if we have a value we can do this a simpler way...
            track_for_point = filter(
                lambda t: (x,y,val) in t[1],
                self.trackers.items()
                )
        else:
            track_for_point = filter(
                lambda tkr: True in [t[0]==x and t[1]==y for t in tkr[1]],
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
                random_color = (random.randint(0,100)/100.0,
                                random.randint(0,100)/100.0,
                                random.randint(0,100)/100.0)
            TRACKER_COLORS.append(random_color)
            return self.get_tracker_color(identifier)

    @simple_debug
    def toggle_tracker (self, identifier, value):
        """Toggle tracking for tracker identified by identifier."""
        self.__trackers_tracking__[identifier]=value

    def delete_by_tracker (self, identifier):
        """Delete all cells tracked by tracker ID identifer."""
        ret = []
        while self.trackers[identifier]:
            x,y,v = self.trackers[identifier][0]
            ret.append((x,y,v,self.trackers_for_point(x,y,v)))
            self.remove(x,y)
            self.grid.remove(x,y)
        return ret

    def delete_except_for_tracker (self, identifier):
        tracks = self.trackers[identifier]
        removed = []
        for x in range(self.group_size):
            for y in range(self.group_size):
                val = self.grid._get_(x,y)
                if (val
                    and (x,y,val) not in tracks 
                    and not self.grid.virgin._get_(x,y)
                    ):
                    removed.append((x,y,val,self.trackers_for_point(x,y,val)))
                    self.remove(x,y)
                    self.grid.remove(x,y)
        return removed

    def add_tracker (self, x, y, tracker, val=None):
        self.__entries__[(x,y)].set_color(self.get_tracker_color(tracker))
        if not val: val = self.grid._get_(x,y)
        self.trackers[tracker].append((x,y,val))

    def remove_tracker (self, x, y, tracker, val=None):
        if not val: val = self.grid._get_(x,y)
        self.trackers[tracker].remove((x,y,val))

if __name__ == '__main__':
    def test_sng ():
        w = gtk.Window()
        w.connect('delete-event', gtk.main_quit)    
        t = SudokuNumberGrid(4)
        w.add(t)
        t.__entries__[(0,1)].set_color((0.0,1.0,0.0))
        t.__entries__[(0,1)].set_value(4)
        t.__entries__[(1,1)].set_error_highlight(True)
        t.__entries__[(1,1)].set_value(1)
        t.__entries__[(2,1)].set_color((0.0,0.0,1.0))
        t.__entries__[(2,1)].set_error_highlight(True)
        t.__entries__[(2,1)].set_value(2)
        t.__entries__[(3,1)].set_color((0.0,0.0,1.0))
        t.__entries__[(3,1)].set_error_highlight(True)
        t.__entries__[(3,1)].set_error_highlight(False)
        t.__entries__[(3,1)].set_value(3)
        t.__entries__[(3,1)].set_note_text('2,3,4','1,2')
        #t.__entries__[(4,4)].set_value(5)
        #t.__entries__[(4,4)].set_note_text('2,7,8')
        w.show_all()
        gtk.main()

    def test_sudoku_game ():
        from sudoku import SudokuGrid, sample_open_sudoku
        sgd = SudokuGameDisplay(grid=SudokuGrid(sample_open_sudoku))
        sgd.set_bg_color('black')
        w = gtk.Window()
        w.connect('delete-event', gtk.main_quit)
        w.add(sgd)
        w.show_all()
        gtk.main()
        
    def test_number_selector ():
        w = gtk.Window()
        w.connect('delete-event',gtk.main_quit)
        ns = NumberSelector(default=3)
        def tell_me (b): print 'value->',b.get_value()
        ns.connect('changed',tell_me)
        w.add(ns)
        w.show_all()
        gtk.main()
        

    #test_number_selector()
    #test_sng()
    test_sudoku_game()

        
            
    
