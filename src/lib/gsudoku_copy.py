# GUI to Sudoku
from gettext import gettext as _
import gtk, sudoku, math, gobject
import pango, random
from simple_debug import simple_debug
from SuperEntry import SuperEntry, get_fontsize_for_y, get_font_height

entry_color = "#fff"
ro_color = "#ddd"

NO_NOTES_TO_NOTES_RATIO = 2.125

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
            if k in self[i]: self[i].remove(k)
            if not self[i]:
                dict.__delitem__(self,i)

class Fonts:
    read_only_font = pango.FontDescription()
    read_only_font.set_weight(pango.WEIGHT_ULTRABOLD)
    read_only_font.set_size(int(pango.SCALE * 9.25))
    read_only_color = "#333"
    normal_font = pango.FontDescription()
    normal_font.set_weight(pango.WEIGHT_NORMAL)
    normal_font.set_size(int(pango.SCALE * 9.25))
    error_color = "#FF0000"
    normal_color = "#000"
    colors = ["#%02x%02x%02x"%(r,b,g) for r,b,g in [(0,0,255), #blue
                                                    (0,255,0), # green
                                                    (255,0,255),#purple
                                                    (255,128,0),#orange
                                                    #(0,255,128),#turquoise-ish
                                                    (128,0,255),#dark purple
                                                    (128,128,128),#grey
                                                    (165,25,25),#maroon-ish
                                                    (0,128,0), #dark green
                                                    (0,0,128), #dark blue
                                                    (139,105,20),#muddy
                                                    ]
              ]

def change_font_size (size):
    size = int(size)
    Fonts.normal_font.set_size(size)
    Fonts.read_only_font.set_size(size)
    
class NumberEntry (gtk.Entry):
    conversions = {10:'A',
                   11:'B',
                   12:'C',
                   13:'D',
                   14:'E',
                   15:'F',
                   16:'G',
                   }
    def __init__ (self, upper=9, base_color=(entry_color,ro_color)):
        self.color = None
        self.base_color = base_color[0]
        self.base_color_RO = base_color[1]
        self.read_only=False
        gtk.Entry.__init__(self)
        if base_color:
            self.modify_base_color(base_color)
        for k,v in self.conversions.items(): self.conversions[v]=k        
        self.upper = upper
        self.set_width_chars(2)
        self.set_alignment(0.5)
        self.set_max_length(1)
        self.modify_font(Fonts.normal_font)
        self.__internal_change__ = False
        self.connect('focus-out-event',self.focus_out_cb)
        self.connect('key-press-event',self.keypress_cb)
        self.connect('changed',self.changed_cb)
        self.unset_color()
        self.show()

    def modify_base_color (self, base_color):
        if base_color==None:
            base_color = (None,None)
        self.base_color,self.base_color_RO = base_color
        if type(self.base_color)==str:
            self.base_color=gtk.gdk.color_parse(self.base_color)
        if type(self.base_color_RO)==str:
            self.base_color_RO=gtk.gdk.color_parse(self.base_color_RO)
        else:
            self.base_color_RO=self.get_style().base[gtk.STATE_INSENSITIVE]
        if self.read_only:
            self.modify_bg(gtk.STATE_NORMAL,self.base_color_RO)
            self.modify_base(gtk.STATE_NORMAL,self.base_color_RO)
            self.modify_fg(gtk.STATE_NORMAL,self.base_color_RO)
        else:
            self.modify_bg(gtk.STATE_NORMAL,self.base_color)
            self.modify_base(gtk.STATE_NORMAL,self.base_color)
            self.modify_fg(gtk.STATE_NORMAL,self.base_color) 

    def changed_cb (self, *args):
        if self.__internal_change__:
            self.emit_stop_by_name('changed')
            return True

    def set_read_only (self, val):
        self.set_editable(not val)
        #self.set_sensitive(not val)
        self.read_only = val
        if val:
            self.modify_font(Fonts.read_only_font)
            self.modify_base_color((self.base_color,self.base_color_RO))
            if not self.color: self._set_color_(Fonts.read_only_color)
        else:
            self.modify_font(Fonts.normal_font)
            self.modify_base_color((self.base_color,self.base_color_RO))
            if not self.color: self._set_color_(Fonts.normal_color)

    def _set_color_ (self, color):
        color = self.get_colormap().alloc_color(color)
        self.modify_text(gtk.STATE_NORMAL,color)

    @simple_debug
    def set_color (self, color):
        self.color = color
        self._set_color_(color)

    def unset_color (self):
        self.color = None
        if self.read_only: self._set_color_(Fonts.read_only_color)
        else: self._set_color_(Fonts.normal_color)

    def set_error_highlight (self, val):
        if val:
            self._set_color_(Fonts.error_color)
            #self.set_sensitive(True)
        else:
            #if self.read_only: self.set_sensitive(False)
            if self.color:
                self._set_color_(self.color)
            else:
                self.unset_color()

    def set_value (self, val):
        try: self.x,self.y
        except: pass
        if val > self.upper:
            raise ValueError("Too large a number!")
        if val >= 10:
            self.__internal_change__ = True
            self.set_text(self.conversions[val])
            self.__internal_change__ = False
        else:
            self.__internal_change__ = True
            if val: self.set_text(str(val))
            else: self.set_text("")
            self.__internal_change__ = False            
            
    def get_value (self):
        txt = self.get_text()
        if self.conversions.has_key(txt.capitalize()):
            val = self.conversions[txt.capitalize()]
        else:
            try:
                val = int(txt)
            except:
                val = None
        if val > self.upper:
            self.set_text("")
            raise ValueError("Too large a number!")
        return val

    def set_impossible (self, val):
        if val:
            try:
                self.__internal_change__=True
                self.set_text('X')
                self.__internal_change__=False
            except: pass
        else:
            if self.get_text()=='X':
                self.__internal_change__=True
                self.set_text('')
                self.__internal_change__=False
        self.impossible = val
        self.set_error_highlight(val)


    def focus_out_cb (self, widget, event):
        widget.select_region(0,0)

    def keypress_cb (self, widget, event):
        name = gtk.gdk.keyval_name(event.keyval)
        parent = widget.get_parent()
        while parent and not isinstance(parent,gtk.Window) :
            parent = parent.get_parent()
        if name in ['Left','KP_Left']:
            parent.emit('move-focus',gtk.DIR_LEFT)
            return True
        elif name in ['Right','KP_Right']:
            parent.emit('move-focus',gtk.DIR_RIGHT)
            return True


class SuperNumberEntry (SuperEntry,NumberEntry):

    # Attributes for which we just provide a proxy to main_entry's
    # attribute
    pass_through_attnames = ['x','y']

    def __init__ (self,*args,**kwargs):
        self.args,self.kwargs = args,kwargs
        SuperEntry.__init__(self)
        self.connect = self.main_entry.connect
        self.set_text = self.main_entry.set_text
        self.get_text = self.main_entry.get_text
        self.set_value = self.main_entry.set_value
        self.get_value = self.main_entry.get_value
        self.set_error_highlight = self.main_entry.set_error_highlight
        self.set_color = self.main_entry.set_color
        self._set_color_ = self.main_entry._set_color_
        #self.modify_font = self.main_entry.modify_font

    def set_entry_sizes (self, size):
        if self.top_entry.get_property('visible'):
            SuperEntry.set_entry_sizes(self,size)
        else:
            self.move(self.main_entry,0,0)
            self.main_entry.set_property('width-request',size)
            self.main_entry.set_property('height-request',size)

    def __setattr__ (self, attr, val):
        if attr in pass_through_attnames:
            return setattr(self.main_entry,attr,val)
        else:
            return SuperEntry.__setattr__(self,attr,val)

    def __getattr__ (self, attr):
        if attr in self.pass_through_attnames:
            return getattr(self.main_entry,attr)
        else:
            try:
                return SuperEntry.__getattr__(self,attr)
            except:
                raise AttributeError, attr

    def hide_notes (self):
        self.top_entry.hide()
        self.sub_entry.hide()
        self.set_entry_sizes(self.size)

    def show_notes (self):
        self.top_entry.show()
        self.sub_entry.show()
        self.set_entry_sizes(self.size)

    def setup_main_entry (self):
        self.main_entry = NumberEntry(*self.args,**self.kwargs)
        self.main_entry.set_width_chars(4)
        self.main_entry.set_alignment(0.5)
        self.main_entry.set_max_length(1)        

    #def __getattr__ (self, attname):
    #    # This should raise an attribute error if it fails, which will
    #    # automatically get us normal behavior
    #    try:
    #        print 'getting ',attname,'from',self.main_entry
    #        return getattr(self.main_entry,attname)
    #    except:
    #        print 'fallback'
    #        raise AttributeError

    def __setattr__ (self, attname, val):
        if attname=='x': self.main_entry.x = val
        elif attname=='y': self.main_entry.y = val
        SuperEntry.__setattr__(self,attname,val)

    def change_square_size (self, side=48, big_font_size=None, small_font_size=None):
        if self.sub_entry.get_property('visible'):
            SuperEntry.change_square_size(self,side,
                                          big_font_size=big_font_size,
                                          small_font_size=small_font_size)
        else:
            if not big_font_size:
                big_font_size = get_fontsize_for_y(side,self.main_font)
            SuperEntry.change_square_size(self,side,big_font_size=big_font_size,small_font_size=small_font_size)
            #self.main_font.set_size(big_font_size)
            #self.main_entry.modify_font(self.main_font)
        #self.side = side

class EntryGrid (gtk.Table):
    
    def __init__ (self, group_size=9,entry_color=(entry_color,ro_color)):
        gtk.Table.__init__(self,rows=group_size,columns=group_size,homogeneous=True,
                           )
        self.group_size = group_size
        self.change_spacing(3)
        self.__entries__ = {}
        for x in range(self.group_size):
            for y in range(self.group_size):
                e = SuperNumberEntry(upper=self.group_size,base_color=entry_color)
                e.x = x
                e.y = y
                self.attach(e,x,x+1,y,y+1,
                            xoptions=gtk.FILL,
                            yoptions=gtk.FILL,
                            xpadding=0,
                            ypadding=0)
                self.__entries__[(x,y)]=e
        self.show_all()
        self.showing_notes = True

    def get_focused_entry (self):
        for e in self.__entries__.values():
            if e.is_focus(): return e
            else:
                if True in [ec.is_focus() for ec in e.get_children()]:
                    return e

    def get_font_size (self, size=None):
        size = Fonts.normal_font.get_size() or (pango.SCALE * 18)
        return size

    def change_font_size (self, size=None, multiplier=None):
        print 'Use of change_font_size deprecated'
        import traceback; traceback.print_exc()
        if not size and not multiplier:
            raise "No size given you dumbass"
        elif size:
            multiplier = size / float(s)
        old_side = self.__entries__.values()[0].side
        new_side = int(old_side * multiplier)
        print 'side from',old_side,'->',new_side
        self.change_square_sizes(new_side)
        print 'new_side ->',self.__entries__.values()[0].side

    def change_square_sizes (self, y):
        main_size,small_size = None,None
        self.square_size = y
        for e in self.__entries__.values():
            if not main_size:
                e.change_square_size(y)
                main_size = e.main_font.get_size()
                small_size = e.sub_font.get_size()
            else:
                e.change_square_size(y,main_size,small_size)
            #if e.read_only: e.modify_font(Fonts.read_only_font)
            #else: e.modify_font(Fonts.normal_font)
        spacing = int(y/15) or 1
        self.change_spacing(spacing)
            
    def change_spacing (self, small_spacing):
        self.small_spacing = small_spacing
        self.big_spacing = small_spacing*3
        self.set_row_spacings(small_spacing)
        self.set_col_spacings(small_spacing)
        box_side = int(math.sqrt(self.group_size))
        for n in range(1,box_side):
            self.set_row_spacing(box_side*n-1,self.big_spacing)
            self.set_col_spacing(box_side*n-1,self.big_spacing)

    def show_notes (self):
        if self.showing_notes: return
        self.showing_notes = True
        #self.change_font_size(multiplier=float(1/NO_NOTES_TO_NOTES_RATIO))
        for e in self.__entries__.values(): e.show_notes()
        if hasattr(self,'square_size'):
            self.change_square_sizes(self.square_size)

    def hide_notes (self):
        if not self.showing_notes: return
        self.showing_notes = False
        #self.change_font_size(multiplier=NO_NOTES_TO_NOTES_RATIO)
        for e in self.__entries__.values():
            e.hide_notes()
        if hasattr(self,'square_size'):
            self.change_square_sizes(self.square_size)
            

class SudokuGridDisplay (EntryGrid, gobject.GObject):

    __gsignals__ = {
        'puzzle-finished':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,())
        }
    
    @simple_debug
    def __init__ (self,grid=None,group_size=9,
                  show_impossible_implications=False):
        group_size=int(group_size)
        self.hints = 0
        self.auto_fills = 0
        self.show_impossible_implications = show_impossible_implications
        self.impossible_hints = 0
        self.impossibilities = []
        self.trackers = {}
        self.__trackers_tracking__ = {}
        self.__colors_used__ = [Fonts.error_color, Fonts.normal_color]
        gobject.GObject.__init__(self)
        EntryGrid.__init__(self,group_size=group_size)
        self.setup_grid(grid,group_size)
        for e in self.__entries__.values():
            e.show()
            e.connect('changed',self.entry_callback)
            e.connect('focus-in-event',self.focus_callback)
            #e.connect('clicked',self.focus_callback)

    @simple_debug
    def focus_callback (self, e, event):
        if hasattr(self,'hint_in_label') and self.hint_in_label: self.hint_in_label.set_text('')
        self.focused = e
        if hasattr(self,'label'):
            self.show_hint(self.label)

    @simple_debug
    def show_hint (self, label):
        self.hints += 1
        self.hint_in_label = label
        entry = self.focused
        if entry.read_only:
            label.set_text('')
        else:
            vals=self.grid.possible_values(entry.x,entry.y)
            vals = list(vals)
            vals.sort()
            if vals:
                label.set_text(_("Possible values ") + ",".join(self.num_to_str(v) for v in vals))
            elif not entry.get_text():
                label.set_text(_("No values are possible!"))
            else:
                label.set_text("")

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
                    val = self.grid._get_(x,y)
                    if val:
                        removed.append((x,y,val,self.trackers_for_point(x,y,val)))
                        self.remove(x,y)
                        self.grid.remove(x,y)
        return removed
    
    @simple_debug
    def blank_grid (self):
        for x in range(self.group_size):
            for y in range(self.group_size):
                self.remove(x,y)                
                e=self.__entries__[(x,y)]
                e.set_read_only(False)                
        self.grid = None

    @simple_debug
    def change_grid (self, grid, group_size):
        self.blank_grid()
        self.setup_grid(grid,group_size)
        self.auto_fills = 0
        self.hints = 0
        self.impossible_hints = 0
        self.trackers = {}
        self.__trackers_tracking__ = {}
        self.__colors_used__ = [Fonts.error_color, Fonts.normal_color]

    @simple_debug
    def load_game (self, game):
        """Load a game.

        A game is simply a two lined string where the first line represents our
        virgin self and line two represents our game-in-progress.
        """
        self.blank_grid()
        virgin,in_prog = game.split('\n')
        group_size=int(math.sqrt(len(virgin.split())))
        self.change_grid(virgin,group_size=group_size)
        # This int() will break if we go to 16x16 grids...
        values = [int(c) for c in in_prog.split()]
        for row in range(group_size):
            for col in range(group_size):
                index = row * 9 + col
                if values[index] and not self.grid._get_(col,row):
                    self.add(col,row,values[index])

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
                if val: self.add(x,y,val)
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

    @simple_debug
    def entry_validate (self, widget, *args):
        val = widget.get_value()
        try:
            self.add(widget.x,widget.y,val)
            if self.grid.check_for_completeness():
                self.emit('puzzle-finished')
        except sudoku.ConflictError, err:
            conflicts=self.grid.find_conflicts(err.x,err.y,err.value)
            for conflict in conflicts:
                widget.set_error_highlight(True)
                self.__entries__[conflict].set_error_highlight(True)
            self.__error_pairs__[(err.x,err.y)]=conflicts

    @simple_debug
    def add (self, x, y, val, trackers=[]):
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

    @simple_debug
    def remove (self, x, y, do_removal=False):
        """Remove x,y from our visible grid.

        If do_removal, remove it from our underlying grid as well.
        """        
        e=self.__entries__[(x,y)]
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
                        self.add(linked_entry.x,linked_entry.y,linked_entry.get_value()) 
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
        if do_removal and self.grid:
            self.grid.remove(x,y)

    @simple_debug
    def auto_fill (self):
        changed=self.grid.auto_fill()
        #changed=self.grid.fill_must_fills        
        #changed=self.grid.fill_deterministically()
        retval = []
        for coords,val in changed:
            self.add(coords[0],coords[1],val)            
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
        filled = self.grid.auto_fill_for_xy(e.x,e.y)
        if filled and filled!=-1:
            self.add(filled[0][0],filled[0][1],filled[1])
    
    @simple_debug
    def mark_impossible_implications (self, x, y):
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
        if len(Fonts.colors)>identifier:
            return Fonts.colors[identifier]
        else:
            Fonts.colors.append("#%02x%02x%02x"%(random.randint(0,255),random.randint(0,255),random.randint(0,255)))
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
        
class GridHull (gtk.Alignment):
    def __init__ (self, bg_color, *args, **kwargs):
        self.gsd = SudokuGridDisplay(*args,**kwargs)
        self.eb = gtk.EventBox()
        gtk.Alignment.__init__(self)
        self.inner_align = gtk.Alignment()
        self.eb.add(self.inner_align)
        self.inner_align.add(self.gsd)
        self.add(self.eb)
        self.set_property('xalign',0.5)
        self.set_property('yalign',0.5)
        self.set_border_padding(self.gsd.big_spacing)
        if bg_color: self.set_bg_color(bg_color)
        self.gsd.show()
        self.eb.show()
        self.inner_align.show()

    def set_bg_color (self, color):
        if type(color)==str:
            try: color = gtk.gdk.color_parse(color)
            except: return
        if not color:
            self.eb.modify_bg(gtk.STATE_NORMAL,color)
            for e in self.gsd.__entries__.values():
                e.modify_base_color(None)
        else:
            self.eb.modify_bg(gtk.STATE_NORMAL,color)
            for e in self.gsd.__entries__.values():
                e.modify_base_color((entry_color,ro_color))

    def set_border_padding (self, n):
        self.inner_align.set_padding(n,n,n,n)

    def change_font_size (self, size=None, multiplier=None):
        self.gsd.change_font_size(size=size,multiplier=multiplier)
        self.set_border_padding(self.gsd.big_spacing)

if gtk.pygtk_version[1]<8: gobject.type_register(SudokuGridDisplay)

if __name__ == '__main__':
    #eg = EntryGrid()
    size = 9
    af = gtk.AspectFrame(ratio=1,obey_child=False)
    gh = GridHull(
        'black',
        grid=sudoku.fiendish_sudoku,
        #grid=sudoku.hard_hex_sudoku,
        group_size=size,
        ); gh.show()
    sg = gh.gsd
    w = gtk.Window()
    vb = gtk.VBox(); vb.show()
    #vb.add(sg)
    af.add(gh); af.show()
    vb.add(af)
    #vb.pack_start(sw,fill=True,expand=True)
    hint = gtk.Label(); hint.show()
    vb.add(hint)
    b = gtk.ToggleButton("Notes"); b.show()
    b.set_active(True)
    db = gtk.SpinButton(); db.show()
    adj=db.get_adjustment()
    adj.lower=0
    adj.upper=25
    adj.step_increment=1
    adj.page_increment=10
    def new_sudoku (*args):
        v=db.get_value()
        sgen = sudoku.SudokuGenerator(group_size=size,
                                      clues=int((size*0.608)**2)
                                      )
        pp=sgen.generate_puzzles(25)
        if len(pp) > v: puz,d=pp[int(v)]
        else: puz,d = pp[-1]
        sg.blank_grid()
        sg.setup_grid(puz.grid,9)
    def test_filler_up (*args):
        sg.blank_grid()
        sg.doing_initial_setup=True
        sg.add(1,2,3)
        sg.add(2,3,4)
        sg.add(3,4,5)
        sg.add(4,5,6)
        sg.doing_initial_setup=False
    sg.label = hint
    b3 = gtk.Button('test'); b3.show()
    b3.connect('clicked',test_filler_up)
    def toggle_notes (but,*args):
        if but.get_active(): sg.show_notes()
        else: sg.hide_notes()
    b.connect('clicked',toggle_notes); b.show()
    w.add(vb)
    vb.add(db)
    vb.add(b)
    vb.add(b3)
    #sg.change_font_size(multiplier=3)
    hb = gtk.HBox(); hb.show()
    vb.add(hb)
    zib = gtk.Button(stock=gtk.STOCK_ZOOM_IN); zib.show()
    zib.connect('clicked',lambda *args: sg.change_font_size(multiplier=1.1))
    zob = gtk.Button(stock=gtk.STOCK_ZOOM_OUT); zob.show()
    zob.connect('clicked',lambda *args: sg.change_font_size(multiplier=0.9))
    hb.add(zib)
    hb.add(zob)
    w.show()
    w.connect('delete-event',lambda *args: gtk.main_quit())
    gtk.main()
