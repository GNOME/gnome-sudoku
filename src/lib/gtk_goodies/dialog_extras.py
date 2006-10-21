import gtk, gobject, os.path
import re
import xml.sax.saxutils
from gettext import gettext as _
H_PADDING=12
Y_PADDING=12

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
        #curtext = self.label.get_text()
        #curtext += "\n%s"%sublabel
        #self.label.set_text(xml.sax.saxutils.escape(curtext))
        self.format_secondary_text(sublabel)
                  
class NumberDialog (ModalDialog):

    """A dialog to get a number from our user."""

    def __init__(self,default=None,label=False,sublabel=False,step_incr=1,page_incr=10,digits=0,
                 min=0,max=10000, parent=None):
        ModalDialog.__init__(self,default=default, parent=parent)
        self.hbox=gtk.HBox()
        self.vbox.add(self.hbox)
        #self.spinButton=gtk.SpinButton(climb_rate=climb_rate,digits=digits)
        if not default:
            val = 0
        else:
            val = float(default)
        self.adjustment=gtk.Adjustment(val,
                                       lower=min,
                                       upper=max,
                                       step_incr=step_incr,
                                       page_incr=page_incr)
        self.spinButton=gtk.SpinButton(self.adjustment,digits=digits)
        if default:
            self.spinButton.set_value(default)
        if label:
            self.label=gtk.Label(label)
            self.label.set_selectable(True)
            self.label.set_line_wrap(True)
            self.label.set_padding(H_PADDING, Y_PADDING)
            self.hbox.add(self.label)
            self.label.show()
        self.hbox.add(self.spinButton)
        self.spinButton.get_adjustment().connect("value_changed",self.update_value)
        self.spinButton.show()
        self.hbox.show()                
        
    def update_value (self, *args):
        self.ret=self.spinButton.get_value()

class EntryDialog (ModalDialog):

    """A dialog to get some text from an Entry from our user."""
    
    def __init__ (self, default=None,
                  label=None,
                  sublabel=None,
                  entryLabel=False,
                  entryTip=None,
                  parent=None,
                  visibility=True,
                  default_value=None,
                  default_character_width=None):
        ModalDialog.__init__(self,default=default,parent=parent, label=label, sublabel=sublabel)
        self.hbox=gtk.HBox()
        self.vbox.add(self.hbox)
        if entryLabel:
            self.elabel=gtk.Label(entryLabel)
            self.elabel.set_line_wrap(True)
            self.elabel.set_selectable(True)
            self.elabel.set_alignment(0,0)
            self.hbox.add(self.label)
            self.elabel.show()
            self.elabel.set_padding(H_PADDING,Y_PADDING)
        self.entry = gtk.Entry()
        self.entry.set_visibility(visibility)
        if default_character_width:
            if hasattr(self.entry,'set_width_chars'):
                self.entry.set_width_chars(default_character_width)
            if hasattr(self,'label') and hasattr(self.label,'set_width_chars'):
                self.label.set_width_chars(default_character_width)
            if hasattr(self,'sublabel') and hasattr(self.sublabel,'set_width_chars'):
                self.sublabel.set_width_chars(default_character_width)
        if default_value: self.entry.set_text(default_value)
        self.hbox.add(self.entry)
        self.entry.set_flags(gtk.CAN_DEFAULT)
        self.entry.grab_default()
        self.hbox.show()
        if default:
            self.entry.set_text(default)
        if entryTip:
            self.tt = gtk.Tooltips()
            self.tt.set_tip(self.entry,entryTip)
        self.entry.connect("changed",self.update_value)
        self.entry.show_all()
        self.entry.show()
        self.widget_that_grabs_focus = self.entry

    def update_value (self, *args):
        self.ret = self.entry.get_text()

class RadioDialog (ModalDialog):

    """A dialog to offer our user a choice between a few options."""

    def __init__ (self, default=None, label="Select Option", sublabel=None, options=[],
                  parent=None,expander=None,cancel=True):
        ModalDialog.__init__(self, okay=True, label=label, sublabel=sublabel, parent=parent, expander=expander, cancel=cancel)
        # defaults value is first value...
        if options:
            self.ret = options[0][1]
        self.setup_radio_buttons(options)

    def setup_radio_buttons (self,options):
        previous_radio = None
        self.buttons = []
        for label,value in options:
            rb = gtk.RadioButton(group=previous_radio, label=label, use_underline=True)
            self.vbox.add(rb)
            rb.show()
            rb.connect('toggled',self.toggle_cb,value)
            self.buttons.append(rb)
            previous_radio=rb
        self.buttons[0].set_active(True)
        self.widget_that_grabs_focus = self.buttons[0]

    def toggle_cb (self, widget, value):
        if widget.get_active():
            self.ret = value


class ProgressDialog (ModalDialog):

    """A dialog to show a progress bar"""
    
    def __init__ (self, title="", okay=True, label="", sublabel=False, parent=None,
                  cancel=False, stop=True, pause=True,modal=False):
        """stop,cancel,and pause will be given as callbacks to their prospective buttons."""
        self.custom_pausecb=pause
        self.custom_cancelcb=cancel
        self.custom_pause_handlers = []
        self.custom_stop_handlers = []
        self.custom_stopcb=stop
        ModalDialog.__init__(self, title, okay=okay, label=label, sublabel=sublabel, parent=parent,
                         cancel=cancel,modal=modal)
        self.set_title(label)
        self.progress_bar = gtk.ProgressBar()
        self.vbox.add(self.progress_bar)
        self.detail_label = gtk.Label()
        self.vbox.add(self.detail_label)
        self.detail_label.set_use_markup(True)
        self.detail_label.set_padding(H_PADDING,Y_PADDING)
        self.detail_label.set_line_wrap(True)
        self.vbox.show_all()
        if okay: self.set_response_sensitive(gtk.RESPONSE_OK,False) # we're false by default!

    def reset_label (self, label):
        self.set_title(label)
        self.label.set_text('<span weight="bold" size="larger">%s</span>'%label)
        self.label.set_use_markup(True)

    def reassign_buttons (self, pausecb=None, stopcb=None):
        while self.custom_pause_handlers:
            h=self.custom_pause_handlers.pop()
            if self.pause.handler_is_connected(h):
                self.pause.disconnect(h)
        if pausecb:
            self.pause.connect('toggled',pausecb)
            self.pause.set_property('visible',True)
        else:
            self.pause.set_property('visible',False)
        while self.custom_stop_handlers:
            h=self.custom_stop_handlers.pop()
            if self.stop.handler_is_connected(h):
                self.stop.disconnect(h)
        if stopcb:
            self.stop.connect('clicked',stopcb)
            #self.stop.connect('clicked',self.cancelcb)
            self.stop.set_property('visible',True)
        else:
            self.stop.set_property('visible',False)
            
    def setup_buttons (self, cancel, okay):                        
        # setup pause button 
        self.pause = gtk.ToggleButton(_('_Pause'),True)        
        self.action_area.pack_end(self.pause)
        # only show it/connect it if we want to...
        if self.custom_pausecb:
            # we keep a list of handlers for possible disconnection later
            self.custom_pause_handlers.append(self.pause.connect('toggled',self.custom_pausecb))
            self.pause.set_property('visible',True)
        else: self.pause.set_property('visible',False)
        # setup stop button
        self.stop = gtk.Button(_('_Stop'))        
        self.action_area.pack_end(self.stop)
        if self.custom_stopcb:
            self.stop.set_property('visible',True)
            # we keep a list of handlers for possible disconnection later
            self.custom_stop_handlers.append(self.stop.connect('clicked',self.custom_stopcb))
            #self.custom_stop_handlers.append(self.stop.connect('clicked',self.cancelcb))
        else:
            self.stop.set_property('visible',False)
        ModalDialog.setup_buttons(self,cancel,okay)
        if self.custom_cancelcb:
            self.cancelcb = self.custom_cancelcb
            #self.cancel.connect('clicked',self.custom_cancelcb)            
    
        
        
class BooleanDialog (MessageDialog):
    def __init__ (self, title="", default=True, label=_("Do you really want to do this"),
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

    def nocb (self, *args):
        self.ret=False
        self.okcb()

class SimpleFaqDialog (ModalDialog):
    """A dialog to view a plain old text FAQ in an attractive way"""

    INDEX_MATCHER = re.compile("^[0-9]+[.][A-Za-z0-9.]* .*")

    # We except one level of nesting in our headers.
    # NESTED_MATCHER should match nested headers
    NESTED_MATCHER = re.compile("^[0-9][.][A-Za-z0-9.]+ .*")

    def __init__ (self,
                  faq_file='/home/tom/Projects/grm-0.8/FAQ',
                  title="Frequently Asked Questions",
                  jump_to = None,
                  parent=None,
                  modal=True):
        print faq_file
        ModalDialog.__init__(self,title=title,parent=parent,modal=modal,cancel=False)
        self.set_default_size(950,500)        
        self.textview = gtk.TextView()
        self.textview.set_editable(False)
        self.textview.set_wrap_mode(gtk.WRAP_WORD)
        self.textview.set_left_margin(18)
        self.textview.set_right_margin(18)
        self.textbuf = self.textview.get_buffer()
        self.boldtag = self.textbuf.create_tag()
        from pango import WEIGHT_BOLD
        self.boldtag.set_property('weight',WEIGHT_BOLD)
        self.textwin = gtk.ScrolledWindow()
        self.textwin.set_policy(gtk.POLICY_AUTOMATIC,gtk.POLICY_AUTOMATIC)
        self.textwin.add(self.textview)
        self.parse_faq(faq_file)
        if self.index_lines:
            self.hp = gtk.HPaned()
            self.indexView = gtk.TreeView()
            self.indexWin = gtk.ScrolledWindow()
            self.indexWin.set_policy(gtk.POLICY_AUTOMATIC,gtk.POLICY_AUTOMATIC)
            self.indexWin.add(self.indexView)
            self.setup_index()
            self.hp.add1(self.indexWin)
            self.hp.add2(self.textwin)
            self.vbox.add(self.hp)
            self.vbox.show_all()
            self.hp.set_position(325)
        else:
            self.vbox.add(textwin)
            self.vbox.show_all()
        if jump_to: self.jump_to_header(jump_to)

    def jump_to_header (self, text):
        """Jump to the header/index items that contains text.
        """
        text = text.lower()
        for l in self.index_lines:
            if l.lower().find(text) > 0:
                itr=self.index_iter_dic[l]
                # select our iter...
                # as a side effect, we will jump to the right part of the text
                self.indexView.get_selection().select_iter(itr)
                # expand our iter
                mod = self.indexView.get_model()
                self.indexView.expand_row(mod.get_path(itr),True)
                return

    def parse_faq (self, infile):
        """Parse file infile as our FAQ to display.

        infile can be a filename or a file-like object.
        We parse index lines according to self.INDEX_MATCHER
        """
        CLOSE=False
        if type(infile)==str:
            infile=open(infile)            
            CLOSE=True
        self.index_lines = []
        self.index_dic={}
        self.text = ""
        for l in infile.readlines():
            if self.INDEX_MATCHER.match(l):
                self.index_lines.append(l.strip())
                curiter = self.textbuf.get_iter_at_mark(self.textbuf.get_insert())
                self.index_dic[l.strip()]=self.textbuf.create_mark(None,curiter,left_gravity=True)
                self.textbuf.insert_with_tags(
                    curiter,
                    l.strip()+" ",
                    self.boldtag)
            # we unwrap lines (paragraphs in our source are
            # separated by blank lines
            elif l.strip():
                self.textbuf.insert_at_cursor(l.strip()+" ")
            else:
                self.textbuf.insert_at_cursor("\n\n")
        if CLOSE: infile.close()

    def setup_index (self):
        """Set up a clickable index view"""
        self.imodel = gtk.TreeStore(str)
        self.index_iter_dic={}
        last_parent = None
        for l in self.index_lines:
            if self.NESTED_MATCHER.match(l):
                itr=self.imodel.append(last_parent,[l])
            else:
                itr=self.imodel.append(None,[l])
                last_parent=itr
            self.index_iter_dic[l]=itr
        # setup our lone column
        self.indexView.append_column(
            gtk.TreeViewColumn("",
                               gtk.CellRendererText(),
                               text=0)
            )
        self.indexView.set_model(self.imodel)
        self.indexView.set_headers_visible(False)
        self.indexView.connect('row-activated',self.index_activated_cb)
        self.indexView.get_selection().connect('changed',self.index_selected_cb)

    def index_activated_cb (self, *args):
        """Toggle expanded state of rows."""
        mod,itr = self.indexView.get_selection().get_selected()
        path=mod.get_path(itr)
        if self.indexView.row_expanded(path):
            self.indexView.collapse_row(path)
        else:
            self.indexView.expand_row(path, True)

    def index_selected_cb (self,*args):
        mod,itr = self.indexView.get_selection().get_selected()
        val=self.indexView.get_model().get_value(itr,0)
        #self.jump_to_text(val)
        self.textview.scroll_to_mark(self.index_dic[val],False,use_align=True,yalign=0.0)

    def jump_to_text (self, txt, itr=None):
        if not itr:
            itr = self.textbuf.get_iter_at_offset(0)
        match_start,match_end=itr.forward_search(txt,gtk.TEXT_SEARCH_VISIBLE_ONLY)
        print 'match_start = ',match_start
        self.textview.scroll_to_iter(match_start,False,use_align=True,yalign=0.1)

def show_message (*args, **kwargs):
    d = MessageDialog(*args, **kwargs)
    return d.run()

def getNumber (*args, **kwargs):
    """Run NumberDialog, passing along all args, waiting on input and passing along
    the results."""
    d = NumberDialog(*args, **kwargs)
    return d.run()

def getEntry (*args, **kwargs):
    """Run EntryDialog, passing along all args, waiting on input and passing along
    the results."""    
    d = EntryDialog(*args, **kwargs)
    return d.run()

def getBoolean (*args,**kwargs):
    """Run BooleanDialog, passing along all args, waiting on input and
    passing along the results."""
    d = BooleanDialog(*args,**kwargs)
    retval = d.run()
    if retval==None:
        raise "getBoolean dialog cancelled!"
    else:
        return retval

def getOption (*args,**kwargs):
    d=OptionDialog(*args,**kwargs)
    return d.run()

def getRadio (*args,**kwargs):
    d=RadioDialog(*args,**kwargs)
    return d.run()

def show_faq (*args,**kwargs):
    d=SimpleFaqDialog(*args,**kwargs)
    return d.run()

def get_ratings_conversion (*args,**kwargs):
    d=RatingsConversionDialog(*args,**kwargs)
    return d.run()

def getFile (*args, **kwargs):
    default_file = None
    if kwargs.has_key('default_file'):
        default_file = kwargs['default_file']
        del kwargs['default_file']    
    fsd = gtk.FileChooserDialog(*args,**kwargs)
    fsd.set_default_response(gtk.RESPONSE_OK)
    if default_file:
        path,name = os.path.split(default_file)
        fsd.set_current_folder(path)
        fsd.set_current_name(name)
    if fsd.run() == gtk.RESPONSE_OK:
        fsd.hide()
        return fsd.get_filename()
    else:
        fsd.hide()
        return None

def getFileSaveAs (*args, **kwargs):
    if not kwargs.has_key('buttons'):
        kwargs['buttons']=(gtk.STOCK_CANCEL,gtk.RESPONSE_CANCEL,
                           gtk.STOCK_OK,gtk.RESPONSE_OK)
    kwargs['action']=gtk.FILE_CHOOSER_ACTION_SAVE
    return getFile(*args,**kwargs)

def getFileOpen (*args, **kwargs):
    if not kwargs.has_key('buttons'):
        kwargs['buttons']=(gtk.STOCK_CANCEL,gtk.RESPONSE_CANCEL,
                           gtk.STOCK_OPEN,gtk.RESPONSE_OK)
    kwargs['action']=gtk.FILE_CHOOSER_ACTION_OPEN
    return getFile(*args, **kwargs)

    
if __name__ == '__main__':
    #show_message("You win!",label="You win",
    #             icon='/home/tom/Projects/gnome-sudoku/images/winner2.png',
    #             sublabel="You completed the puzzle in %s"%'1 hour 25 minutes')
    print getFileSaveAs()
    gtk.main()
