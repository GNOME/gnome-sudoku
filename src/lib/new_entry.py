import gtk,pango,cairo

import sys

import gobject
import pango
import gtk
from gtk import gdk

if gtk.pygtk_version < (2, 8):
    print "PyGtk 2.8 or later required for this example"
    raise SystemExit

try:
    import cairo
except ImportError:
    raise SystemExit("cairo required for this example")

TEXT = '1'
BORDER_WIDTH = 5.0
BORDER_LINE_WIDTH = 2

# A quite simple gtk.Widget subclass which demonstrates how to subclass
# and do realizing, sizing and drawing.

BASE_SIZE = 35

class SudokuNumber (gtk.Widget):

    _layout = None
    _note_layout = None
    
    def __init__ (self, text):
        gtk.Widget.__init__(self)
        self.set_text(text)
        self.set_property('can-focus',True)
        self.set_property('events',gtk.gdk.ALL_EVENTS_MASK)
        self.connect('button-press-event',self.button_press_cb)
        self.connect('key-release-event',self.key_press_cb)

    def button_press_cb (self, w, e):
        print 'button press!'
        self.grab_focus()

    def key_press_cb (self, w, e):
        txt = gtk.gdk.keyval_name(e.keyval)
        if txt in [str(n) for n in range(1,10)]:
            print 'set_text(%s)'%txt
            self.set_text(txt)
            self.queue_draw()

    def set_text (self, text):
        self._layout = self.create_pango_layout(text)
        self._layout.set_font_description(pango.FontDescription("Sans Serif 12"))

    def set_note_text (self, text):
        self._note_layout = self.create_pango_layout(text)
        self._note_layout.set_font_description(pango.FontDescription("Sans Serif 6"))

    def do_realize (self):
        # The do_realize method is responsible for creating GDK (windowing system)
        # resources. In this example we will create a new gdk.Window which we
        # then draw on

        # First set an internal flag telling that we're realized
        self.set_flags(self.flags() | gtk.REALIZED)

        # Create a new gdk.Window which we can draw on.
        # Also say that we want to receive exposure events by setting
        # the event_mask
        self.window = gdk.Window(
            self.get_parent_window(),
            width=self.allocation.width,
            height=self.allocation.height,
            window_type=gdk.WINDOW_CHILD,
            wclass=gdk.INPUT_OUTPUT,
            event_mask=self.get_events() | gdk.EXPOSURE_MASK)

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
        # text is, plus a little border around it.
        width, height = self._layout.get_size()
        #print 'width/height = ',width,height,width/pango.SCALE,height/pango.SCALE
        requisition.width = (width / pango.SCALE)+(BORDER_LINE_WIDTH+BORDER_WIDTH)*2
        requisition.height = height / pango.SCALE+(BORDER_LINE_WIDTH+BORDER_WIDTH)*2

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
            #print 'scale = ',scale
        else:
            scale = w/float(BASE_SIZE)
        cr.scale(scale,scale)

        # Draw background color
        cr.set_source_rgb(1.0,1.0,1.0)
        cr.rectangle(
            0,0,BASE_SIZE,BASE_SIZE
            )
        cr.fill()

        cr.set_source_rgb(1.0,.75,0.25)
        if self.is_focus():
            if w > h:
                side = h
            else:
                side = w
            cr.rectangle(
                # left-top
                BORDER_LINE_WIDTH,
                BORDER_LINE_WIDTH,
                # bottom-right
                BASE_SIZE-(2*BORDER_LINE_WIDTH),
                BASE_SIZE-(2*BORDER_LINE_WIDTH),
                )
            cr.set_line_width(BORDER_LINE_WIDTH)
            cr.set_line_join(cairo.LINE_JOIN_MITER)
            cr.stroke()

        cr.set_source_color(self.style.fg[self.state])        
        # And draw the text in the middle of the allocated space
        if self._layout:
            fontw, fonth = self._layout.get_pixel_size()
            cr.move_to(
                (BASE_SIZE/2)-(fontw/2),
                (BASE_SIZE/2) - (fonth/2),
                )
            cr.update_layout(self._layout)
            cr.show_layout(self._layout)

        # And draw any note text...
        if self._note_layout:
            fontw, fonth = self._note_layout.get_pixel_size()
            cr.move_to(
                0+BORDER_LINE_WIDTH+BORDER_WIDTH,
                0,
                )
            cr.update_layout(self._note_layout)
            cr.show_layout(self._note_layout)
            

gobject.type_register(SudokuNumber)

def main(args):
    win = gtk.Window()
    win.set_border_width(5)
    win.set_title('Widget test')
    win.connect('delete-event', gtk.main_quit)

    def on_allocate (widg, rect):
        height = rect.height
        width = rect.width
        if height > width:
            spacing = width / 12
        else:
            spacing = height / 12
        if hasattr(widg,'spacing') and widg.spacing != spacing:
            widg.set_col_spacings(spacing)
            widg.set_row_spacings(spacing)
            widg.spacing = spacing

    
    tb = gtk.Table()
    tb.connect('size-allocate',on_allocate)
    for x in range(3):
        for y in range(3):
            sn = SudokuNumber('%s'%(x*3+(y+1)))
            if y==2:
                sn.set_note_text('Foo')
            tb.attach(sn,
                      x,x+1,y,y+1
                      )
    tb.set_row_spacings(6)
    tb.set_col_spacings(6)    
    vb = gtk.VBox()
    hb = gtk.HBox()
    vb.pack_start(hb,fill=False,expand=False)
    hb.pack_start(tb,fill=False,expand=False)
    win.add(vb)
    win.show_all()

    gtk.main()

if __name__ == '__main__':
    sys.exit(main(sys.argv))
