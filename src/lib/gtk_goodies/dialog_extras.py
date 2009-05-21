# -*- coding: utf-8 -*-
import gtk
import xml.sax.saxutils
from gettext import gettext as _
H_PADDING=12
Y_PADDING=12

class UserCancelledError (Exception):
    pass

class ModalDialog (gtk.Dialog):
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
        self.responses = {gtk.RESPONSE_OK:self.okcb,
                          gtk.RESPONSE_CANCEL:self.cancelcb,
                          gtk.RESPONSE_NONE:self.cancelcb,
                          gtk.RESPONSE_CLOSE:self.cancelcb,
                          gtk.RESPONSE_DELETE_EVENT:self.cancelcb}
        if modal: self.set_modal(True)
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
        self.vbox.show_all()

    def setup_dialog (self, *args, **kwargs):
        gtk.Dialog.__init__(self, *args, **kwargs)

    def setup_label (self, label):
        # we're going to add pango markup to our
        # label to make it bigger as per GNOME HIG
        label = '<span weight="bold" size="larger">%s</span>'%label
        self.label = gtk.Label(label)
        self.label.set_line_wrap(True)
        self.label.set_selectable(True)
        self.vbox.pack_start(self.label,expand=False)
        self.label.set_padding(H_PADDING,Y_PADDING)
        self.label.set_alignment(0,0)
        self.label.set_justify(gtk.JUSTIFY_LEFT)
        self.label.set_use_markup(True)
        self.label.show()
        
    def setup_sublabel (self,sublabel):
        self.sublabel = gtk.Label(sublabel)
        self.sublabel.set_selectable(True)
        self.vbox.pack_start(self.sublabel, expand=False)
        self.sublabel.set_padding(H_PADDING,Y_PADDING)
        self.sublabel.set_alignment(0,0)
        self.sublabel.set_justify(gtk.JUSTIFY_LEFT)
        self.sublabel.set_use_markup(True)
        self.sublabel.set_line_wrap(True)
        self.sublabel.show()

    def setup_buttons (self, cancel, okay):
        if cancel:
            self.add_button(gtk.STOCK_CANCEL,gtk.RESPONSE_CANCEL)
        if okay:
            self.add_button(gtk.STOCK_OK,gtk.RESPONSE_OK)
        self.connect('response',self.response_cb)

    def response_cb (self, dialog, response, *params):
        #print 'response CB ',dialog,response,params
        if self.responses.has_key(response):
            #print 'we have a response!'
            self.responses[response]()
        else:
            print 'WARNING, no response for ',response
            
    def setup_expander (self, expander):
            label=expander[0]
            body = expander[1]
            self.expander = gtk.Expander(label)
            self.expander.set_use_underline(True)
            self.expander_vbox = gtk.VBox()
            self.expander.add(self.expander_vbox)
            self._add_expander_item(body)
            self.expander.show()
            self.expander_vbox.show_all()
            self.vbox.add(self.expander)
            
    def _add_expander_item (self, item):
        if type(item)==type(""):
            l=gtk.Label(item)
            l.set_selectable(True)
            l.set_line_wrap(True)
            self.expander_vbox.pack_start(l,
                                          expand=False,
                                          fill=False)
        elif type(item)==[] or type(item)==():
            map(self._add_expander_item,item)
        else:
            self.expander_vbox.pack_start(item)
            
    def run (self):
        self.show()
        if self.widget_that_grabs_focus: self.widget_that_grabs_focus.grab_focus()
        if self.modal: gtk.main()
        return self.ret

    def okcb (self, *args):
        self.hide()
        if self.modal: gtk.main_quit()

    def cancelcb (self, *args):
        self.hide()
        self.ret=None
        if self.modal: gtk.main_quit()

class MessageDialog (gtk.MessageDialog, ModalDialog):

    """A simple class for displaying messages to our users."""
    
    def __init__ (self, title="", default=None, okay=True, cancel=False, label=False, sublabel=False,
                  expander=None, message_type=gtk.MESSAGE_INFO, icon=None, parent=None):
        self.message_type=message_type
        self.icon = icon
        ModalDialog.__init__(self, title=title, default=default, okay=okay, cancel=cancel, label=label, sublabel=sublabel, parent=parent, expander=expander)

    def setup_dialog (self, *args, **kwargs):
        kwargs['type']=self.message_type
        if kwargs.has_key('title'):
            del kwargs['title']
        gtk.MessageDialog.__init__(self, *args, **kwargs)
        if self.icon:
            if type(self.icon)==str:
                self.image.set_from_file(self.icon)
            else:
                self.image.set_from_pixbuf(self.icon)

    def setup_label (self, label):
        label = '<span weight="bold" size="larger">%s</span>'%xml.sax.saxutils.escape(label)
        self.label.set_text(label)
        self.label.set_use_markup(True)

    def setup_sublabel (self, sublabel):
        self.format_secondary_text(sublabel)


class BooleanDialog (MessageDialog):
    def __init__ (self, title="", default=True, label=_("Do you really want to do this?"),
                  sublabel=False, cancel=True,
                  parent=None, custom_yes=None, custom_no=None, expander=None,
                  dont_ask_cb=None, dont_ask_custom_text=None,
                  cancel_returns=None, message_type=gtk.MESSAGE_QUESTION
                  ):
        """Setup a BooleanDialog which returns True or False.
        parent is our parent window.
        custom_yes is custom text for the button that returns true or a dictionary
                   to be handed to gtk.Button as keyword args.
        custom_no is custom text for the button that returns False or a dictionary
                   to be handed to gtk.Button as keyword args
        expander is a list whose first item is a label and second is a widget to be packed
        into an expander widget with more information.
        if dont_ask_variable is set, a Don't ask me again check
        button will be displayed which the user can check to avoid this kind
        of question again. (NOTE: if dont_ask_variable==None, this won't work!)
        dont_ask_custom_text is custom don't ask text."""
        self.cancel_returns = cancel_returns
        self.yes,self.no = custom_yes,custom_no        
        if not self.yes: self.yes = gtk.STOCK_YES
        if not self.no: self.no = gtk.STOCK_NO
        MessageDialog.__init__(self,title=title,okay=False,label=label, cancel=cancel, sublabel=sublabel,parent=parent, expander=expander, message_type=message_type)
        self.responses[gtk.RESPONSE_YES]=self.yescb
        self.responses[gtk.RESPONSE_NO]=self.nocb
        if not cancel:
            # if there's no cancel, all cancel-like actions
            # are the equivalent of a NO response
            self.responses[gtk.RESPONSE_NONE]=self.nocb
            self.responses[gtk.RESPONSE_CANCEL]=self.nocb
            self.responses[gtk.RESPONSE_CLOSE]=self.nocb
            self.responses[gtk.RESPONSE_DELETE_EVENT]=self.nocb
        if dont_ask_cb:
            if not dont_ask_custom_text:
                dont_ask_custom_text=_("Don't ask me this again.")
            self.dont_ask = gtk.CheckButton(dont_ask_custom_text)            
            self.dont_ask.connect('toggled',dont_ask_cb)
            self.vbox.add(self.dont_ask)
            self.dont_ask.show()

    def setup_buttons (self, cancel, okay):
        MessageDialog.setup_buttons(self,cancel,None)
        self.add_button(self.no,gtk.RESPONSE_NO)
        self.add_button(self.yes,gtk.RESPONSE_YES)

    def yescb (self, *args):
        self.ret=True
        self.okcb()

    def cancelcb (self, *args):
        if self.cancel_returns != None:
            self.ret = self.cancel_returns
            self.okcb()
        else:
            self.hide()
            if self.modal: gtk.main_quit()

    def nocb (self, *args):
        self.ret=False
        self.okcb()

def show_message (*args, **kwargs):
    d = MessageDialog(*args, **kwargs)
    return d.run()

def getBoolean (*args,**kwargs):
    """Run BooleanDialog, passing along all args, waiting on input and
    passing along the results."""
    d = BooleanDialog(*args,**kwargs)
    retval = d.run()
    if retval==None:
        raise UserCancelledError("getBoolean dialog cancelled!")
    else:
        return retval
