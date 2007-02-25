import gtk, gobject, gtk.glade
import os, os.path
import time
from gettext import gettext as _
from gettext import ngettext
from defaults import *

def format_time (time, round_at=None):
    time = int(time)
    time_strings = []
    units = [(int(365.25*24*60*60),
              lambda years: ngettext("%s year","%s years",years)%years),
             (31*24*60*60,
              lambda months: ngettext("%s month","%s months",months)%months),
             (7*24*60*60,
              lambda weeks: ngettext("%s week","%s weeks",weeks)%weeks),
             (24*60*60,
              lambda days: ngettext("%s day","%s days",days)%days),
             (60*60,
              lambda hours: ngettext("%s hour","%s hours",hours)%hours),
             (60,
              lambda minutes: ngettext("%s minute","%s minutes",minutes)%minutes),
             (1,
              lambda seconds: ngettext("%s second","%s seconds",seconds)%seconds)]
    for divisor,unit_formatter in units:
        time_covered = time / divisor
        if time_covered:
            if round_at and len(time_strings)+1>=round_at:
                time_covered = int(round(float(time)/divisor))
                time_strings.append(unit_formatter(time_covered))
                break
            else:
                time_strings.append(unit_formatter(time_covered))
                time = time - time_covered * divisor
    if len(time_strings)>2:
        # Translators... this is a messay way of concatenating
        # lists. In English we do lists this way: 1, 2, 3, 4, 5
        # and 6. This set-up allows for the English system only.
        # You can of course make your language only use commas or
        # ands or spaces or whatever you like by translating both
        # ", " and " and " with the same string.
        return _(" and ").join([_(", ").join(time_strings[0:-1]),time_strings[-1]])
    else:
        return _(" and ").join(time_strings)

def format_date (tim):
    lt = time.localtime(tim)
    hours = int(time.strftime("%H",lt))
    minutes = int(time.strftime("%M",lt))
    diff = time.time() - tim
    to_yesterday = hours*60*60+minutes*60
    if diff < to_yesterday:
        # then we're today
        return time.strftime(_('Today') + " %R %p",lt)
    elif diff < (to_yesterday + 60*60*24):
        return time.strftime(_('Yesterday') + " %R %p",lt)
    elif diff < (60*60*24*7): # less than a week
        return time.strftime("%A %H:%M",lt) # Day, Hour:Minutes
    else:
        return time.strftime("%A %B %d %R %p",lt)


class ActiveTimer (gobject.GObject):
    """A timer to keep track of how much time a window is active."""

    __gsignals__ = {
        'timing-started':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,()),
        'timing-stopped':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,())
        }
    
    def __init__ (self, window):
        gobject.GObject.__init__(self)
        self.window = window
        self.__timing__ = False
        self.__absolute_start_time__ = 0
        self.__paused__ = False
        self.tot_time = 0
        self.tot_time_complete = 0
        self.window.connect('window-state-event',self.window_state_event_cb)
        self.window.connect('state-changed',self.window_state_event_cb)
        self.window.connect('visibility-notify-event',self.window_state_event_cb)
        self.window.connect('expose-event',self.window_state_event_cb)        
        self.window.connect('no-expose-event',self.window_state_event_cb)        

    def window_state_event_cb (self, *args):
        if self.window.is_active():
            self.toggle_timing(True)
        else:
            self.toggle_timing(False)

    def toggle_timing (self, on):
        if not self.__absolute_start_time__:
            self.reset_timer()
        if self.__paused__: return False
        if on and not self.__timing__:            
            self.timing_started_at = time.time()
            self.__timing__ = True
            self.emit('timing-started')
            #print 'timing!'
        if not on and self.__timing__:
            end_time = time.time()
            self.__timing__ = False
            self.tot_time += (end_time - self.timing_started_at)
            self.tot_time_complete = end_time - self.__absolute_start_time__
            #print 'Stopped timing...',self.tot_time
            self.emit('timing-stopped')
        #print on,'represents no change'

    def finish_timing (self):
        self.toggle_timing(False)
        if not self.tot_time_complete:
            self.tot_time_complete = time.time() - self.__absolute_start_time__
        #print 'tot_time ',self.tot_time
        #print 'tot_time_complete ',self.tot_time_complete
        
    def active_time_string (self):
        if self.__timing__ and not self.__paused__:
            return format_time(self.tot_time+time.time()-self.timing_started_at)
        else:
            return format_time(self.tot_time)
    
    def total_time_string (self):
        if self.__timing__:
            return format_time(time.time()-self.__absolute_start_time__)
        else:
            return format_time(self.tot_time_complete)

    def reset_timer (self):
        self.__absolute_start_time__ = time.time()
        self.tot_time = 0
        self.toggle_timing(False)

    def start_timing (self):
        self.__absolute_start_time__ = time.time()
        self.toggle_timing(True)

    def pause_timing (self):
        self.toggle_timing(False)
        self.__paused__ = True

    def resume_timing (self):
        self.__paused = False
        self.toggle_timing(True)

if gtk.pygtk_version[1]<8: gobject.type_register(ActiveTimer)

