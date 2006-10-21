import gtk

# Convenience library for a new kind of UI -- for e.g. this game, we
# don't really want to have dialogs. Nonetheless, it's convenient to
# design dialogs in glade and run them in the standard manner... So we
# create a new "dialog" interface via a hidden notebook.

class SwappableArea (gtk.Notebook):


    swallowed = {}
    response = None
    running = False

    
    def __init__ (self,main_area):
        gtk.Notebook.__init__(self)
        self.set_show_tabs(False)
        self.set_show_border(False)
        self.main_page = self.append_page(main_area)

    def swallow_window (self, d):
        child = d.child
        d.remove(child)
        return self.swallow_widget(child)
        
    def swallow_widget (self, w):
        w.unparent()
        return self.append_page(w)

    def swallow_dialog (self, d):
        action_widgets = d.action_area.get_children()
        actions = dict([
            (w,d.get_response_for_widget(w)) for w in action_widgets
            ])
        n = self.swallow_window(d)
        self.swallowed[d] = n
        def cb (w,*args):
            gtk.main_quit()
            self.response = actions[w]
        self.set_current_page(n)
        for w in action_widgets: w.connect('clicked',cb)

    def run_dialog (self, d):
        self.running = d
        if not self.swallowed.has_key(d):
            self.swallow_dialog(d)
        self.set_current_page(self.swallowed[d])
        try:
            gtk.main()
        except:
            print 'Error in dialog!'
            import traceback; traceback.print_exc()
            print 'forge on fearlessly...'
        self.set_current_page(self.main_page)
        self.running = None
        return self.response

        

if __name__ == '__main__':

    d = gtk.Dialog()
    d.vbox.add(gtk.Label('Foo, bar, baz'))
    d.vbox.show_all()
    d.add_button(gtk.STOCK_CLOSE,gtk.RESPONSE_CLOSE)
    import defaults
    defaults.IMAGE_DIR = defaults.BASE_DIR \
    = defaults.GLADE_DIR = defaults.BASE_DIR = '/usr/share/gnome-sudoku/'
    import os, os.path, sys; sys.path.append(os.path.realpath(os.curdir))
    sys.path.append('/usr/share/')
    w = gtk.Window()
    b = gtk.Button('show d'); b.show()
    sa = SwappableArea(b)
    sa.show()
    w.add(sa)
    b.connect('clicked', lambda *args: sa.run_dialog(d))
    w.show()
    gtk.main()
    
