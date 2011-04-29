# -*- coding: utf-8 -*-
from gi.repository import Gtk,GObject
import xml.sax.saxutils
from gettext import gettext as _
H_PADDING=12
Y_PADDING=12

class UserCancelledError (Exception):
    pass

class ModalDialog (Gtk.Dialog):
    def __init__ (self, default=None, title="", okay=True, label=False, sublabel=False, parent=None, cancel=True, modal=True, expander=None, image=None):
        """Our basic class. We allow for a label. Possibly an expander
        with extra information, and a simple Okay button.  The
        expander is are only fancy option. It should be a list ['Name
        of expander', CONTENTS]. CONTENTS can be a string (to be put
        in a label), a widget (to be packed in the expander), or a
        list of strings and widgets to be packed in order."""
        self.widget_that_grabs_focus = None
        self.setup_dialog(title=title, parent=parent)
        self.connect('destroy',self.cancelcb)
        self.set_border_width(15)
        self.default = default
        self.ret = default
        self.responses = {Gtk.ResponseType.OK:self.okcb,
                          Gtk.ResponseType.CANCEL:self.cancelcb,
                          Gtk.ResponseType.NONE:self.cancelcb,
                          Gtk.ResponseType.CLOSE:self.cancelcb,
                          Gtk.ResponseType.DELETE_EVENT:self.cancelcb}
        if modal:
            self.set_modal(True)
        if label:
            self.setup_label(label)
        if sublabel:
            self.setup_sublabel(sublabel)
        if expander:
            # if we have an expander, our window
            # should be resizable (just in case
            # the user wants to do more resizing)
            self.set_resizable(True)
            self.setup_expander(expander)
        if cancel or okay:
            self.setup_buttons(cancel, okay)

        self.show_all()

    def setup_dialog (self, *args, **kwargs):
        GObject.GObject.__init__(self, *args, **kwargs)

    def setup_label (self, label):
        # we're going to add pango markup to our
        # label to make it bigger as per GNOME HIG
        label = '<span weight="bold" size="larger">%s</span>'%label
        label = Gtk.Label()
        label.set_line_wrap(True)
        label.set_selectable(True)
        label.set_padding(H_PADDING,Y_PADDING)
        label.set_alignment(0,0)
        label.set_justify(Gtk.Justification.LEFT)
        label.set_markup(label)
        label.show()

        self.get_content_area().pack_start(label,expand=False)
        
    def setup_sublabel (self,sublabel):
        sublabel = Gtk.Label()
        sublabel.set_selectable(True)
        sublabel.set_padding(H_PADDING,Y_PADDING)
        sublabel.set_alignment(0,0)
        sublabel.set_justify(Gtk.Justification.LEFT)
        sublabel.set_markup(sublabel)
        sublabel.set_line_wrap(True)
        sublabel.show()

        self.get_content_area().pack_start(sublabel, False, True, 0)

    def setup_buttons (self, cancel, okay):
        if cancel:
            self.add_button(Gtk.STOCK_CANCEL,Gtk.ResponseType.CANCEL)
        if okay:
            self.add_button(Gtk.STOCK_OK,Gtk.ResponseType.OK)
        self.connect('response',self.response_cb)

    def response_cb (self, dialog, response, *params):
        if self.responses.has_key(response):
            self.responses[response]()
        else:
            print 'WARNING, no response for ',response
            
    def setup_expander (self, expander):
        label,body = expander
        expander = Gtk.Expander(label)
        expander.set_use_underline(True)
        expander_vbox = Gtk.VBox()
        expander.add(self.expander_vbox)
        self._add_expander_item(expander_vbox, body)
        expander.show_all()

        self.get_content_area().add(expander)
            
    def _add_expander_item (self, expander_vbox, item):
        if type(item) == type(""):
            l = Gtk.Label(label=item)
            l.set_selectable(True)
            l.set_line_wrap(True)
            expander_vbox.pack_start(l, expand=False, fill=False)
        elif type(item) == [] or type(item) == ():
            map(self._add_expander_item, expander_vbox, item)
        else:
            expander_vbox.pack_start(item, True, True, 0)
            
    def run (self):
        self.show()
        if self.widget_that_grabs_focus:
            self.widget_that_grabs_focus.grab_focus()
        if self.props.modal:
            Gtk.main()
        return self.ret

    def okcb (self, *args):
        self.hide()
        if self.props.modal:
            Gtk.main_quit()

    def cancelcb (self, *args):
        self.hide()
        self.ret=None
        if self.props.modal:
            Gtk.main_quit()

class MessageDialog (Gtk.MessageDialog, ModalDialog):

    """A simple class for displaying messages to our users."""
    
    def __init__ (self, title="", default=None, okay=True, cancel=False, label=False, sublabel=False,
                  expander=None, message_type=Gtk.MessageType.INFO, icon=None, parent=None):
        self.message_type=message_type
        self.icon = icon
        ModalDialog.__init__(self, title=title, default=default, okay=okay, cancel=cancel, label=label, sublabel=sublabel, parent=parent, expander=expander)

    def setup_dialog (self, *args, **kwargs):
        kwargs['type']=self.message_type
        if kwargs.has_key('title'):
            del kwargs['title']
        GObject.GObject.__init__(self, *args, **kwargs)
        if self.icon:
            if type(self.icon)==str:
                self.image.set_from_file(self.icon)
            else:
                self.image.set_from_pixbuf(self.icon)
        print "123"

    def setup_label (self, label):
        label = '<span weight="bold" size="larger">%s</span>'%xml.sax.saxutils.escape(label)
        self.set_markup(label)

    def setup_sublabel (self, sublabel):
        self.format_secondary_text(sublabel)


class BooleanDialog (MessageDialog):
    def __init__ (self, title="", default=True, label=_("Do you really want to do this?"),
                  sublabel=False, cancel=True,
                  parent=None, custom_yes=None, custom_no=None, expander=None,
                  dont_ask_cb=None, dont_ask_custom_text=None,
                  cancel_returns=None, message_type=Gtk.MessageType.QUESTION
                  ):
        """Setup a BooleanDialog which returns True or False.
        parent is our parent window.
        custom_yes is custom text for the button that returns true or a dictionary
                   to be handed to Gtk.Button as keyword args.
        custom_no is custom text for the button that returns False or a dictionary
                   to be handed to Gtk.Button as keyword args
        expander is a list whose first item is a label and second is a widget to be packed
        into an expander widget with more information.
        if dont_ask_variable is set, a Don't ask me again check
        button will be displayed which the user can check to avoid this kind
        of question again. (NOTE: if dont_ask_variable==None, this won't work!)
        dont_ask_custom_text is custom don't ask text."""
        self.cancel_returns = cancel_returns
        self.yes,self.no = custom_yes,custom_no        
        if not self.yes: self.yes = Gtk.STOCK_YES
        if not self.no: self.no = Gtk.STOCK_NO
        MessageDialog.__init__(self,title=title,okay=False,label=label, cancel=cancel, sublabel=sublabel,parent=parent, expander=expander, message_type=message_type)
        self.responses[Gtk.ResponseType.YES]=self.yescb
        self.responses[Gtk.ResponseType.NO]=self.nocb
        if not cancel:
            # if there's no cancel, all cancel-like actions
            # are the equivalent of a NO response
            self.responses[Gtk.ResponseType.NONE]=self.nocb
            self.responses[Gtk.ResponseType.CANCEL]=self.nocb
            self.responses[Gtk.ResponseType.CLOSE]=self.nocb
            self.responses[Gtk.ResponseType.DELETE_EVENT]=self.nocb
        if dont_ask_cb:
            if not dont_ask_custom_text:
                dont_ask_custom_text=_("Don't ask me this again.")
            self.dont_ask = Gtk.CheckButton(dont_ask_custom_text)
            self.dont_ask.connect('toggled',dont_ask_cb)
            self.get_content_area().add(self.dont_ask)
            self.dont_ask.show()

    def setup_buttons (self, cancel, okay):
        MessageDialog.setup_buttons(self,cancel,None)
        self.add_button(self.no,Gtk.ResponseType.NO)
        self.add_button(self.yes,Gtk.ResponseType.YES)

    def yescb (self, *args):
        self.ret=True
        self.okcb()

    def cancelcb (self, *args):
        if self.cancel_returns != None:
            self.ret = self.cancel_returns
            self.okcb()
        else:
            self.hide()
            if self.props.modal:
                Gtk.main_quit()

    def nocb (self, *args):
        self.ret=False
        self.okcb()

def show_message_dialog (*args, **kwargs):
    d = MessageDialog(*args, **kwargs)
    return d.run()

def show_boolean_dialog (*args,**kwargs):
    """Run BooleanDialog, passing along all args, waiting on input and
    passing along the results."""
    d = BooleanDialog(*args,**kwargs)
    retval = d.run()
    if retval == None:
        raise UserCancelledError("show_boolean_dialog dialog cancelled!")
    else:
        return retval
