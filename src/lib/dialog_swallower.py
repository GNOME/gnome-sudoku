# -*- coding: utf-8 -*-
from gi.repository import Gtk,GObject

# Convenience library for a new kind of UI -- for e.g. this game, we
# don't really want to have dialogs. Nonetheless, it's convenient to
# design dialogs in gtkbuilder and run them in the standard manner... So we
# create a new "dialog" interface via a hidden notebook.

class SwappableArea (Gtk.Notebook):


    swallowed = {}
    response = None
    running = False


    def __init__ (self, main_area):
        GObject.GObject.__init__(self)
        self.set_show_tabs(False)
        self.set_show_border(False)
        self.main_page = self.append_page(main_area, None)

    def swallow_window (self, d):
        child = d.get_child()
        d.remove(child)
        return self.swallow_widget(child)

    def swallow_widget (self, w):
        w.unparent()
        return self.append_page(w, None)

    def response_cb (self, w, response, data=None):
        Gtk.main_quit()
        self.response = response

    def swallow_dialog (self, d):
        n = self.swallow_window(d)
        self.swallowed[d] = n
        self.set_current_page(n)
        d.connect('response', self.response_cb)

    def run_dialog (self, d):
        self.running = d
        if d not in self.swallowed:
            self.swallow_dialog(d)
        self.set_current_page(self.swallowed[d])
        try:
            Gtk.main()
        except:
            print('Error in dialog!')
            import traceback
            traceback.print_exc()
            print('forge on fearlessly...')
        self.set_current_page(self.main_page)
        self.running = None
        tmp_response = self.response
        self.response = None
        return tmp_response



if __name__ == '__main__':

    d = Gtk.Dialog()
    d.vbox.add(Gtk.Label('Foo, bar, baz'))
    d.vbox.show_all()
    d.add_button(Gtk.STOCK_CLOSE, Gtk.ResponseType.CLOSE)
    w = Gtk.Window()
    b = Gtk.Button('show d')
    b.show()
    sa = SwappableArea(b)
    sa.show()
    w.add(sa)
    b.connect_object('clicked', sa.run_dialog, d)
    w.show()
    Gtk.main()
    
