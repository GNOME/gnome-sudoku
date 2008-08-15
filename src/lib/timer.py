import gtk, gobject, gtk.glade
import os, os.path
import time
from gettext import gettext as _
from gettext import ngettext
from defaults import *

def format_time (time, round_at=None, friendly=False):
    """Format a time for display to the user.

    If round_at, we round all times to some number of seconds.

    If friendly, we don't bother showing the user more than two
    units. i.e. 3 days 2 hours, or 2 minutes 30 seconds, but not 3
    days, 4 hours, 2 minutes and 3 seconds...
    """
    time = int(time)
    time_strings = []
    units = [(int(365.25*24*60*60),
              lambda years: ngettext("%(n)s year","%(n)s years",years)%{'n':years}),
             (31*24*60*60,
              lambda months: ngettext("%(n)s month","%(n)s months",months)%{'n':months}),
             (7*24*60*60,
              lambda weeks: ngettext("%(n)s week","%(n)s weeks",weeks)%{'n':weeks}),
             (24*60*60,
              lambda days: ngettext("%(n)s day","%(n)s days",days)%{'n':days}),
             (60*60,
              lambda hours: ngettext("%(n)s hour","%(n)s hours",hours)%{'n':hours}),
             (60,
              lambda minutes: ngettext("%(n)s minute","%(n)s minutes",minutes)%{'n':minutes}),
             (1,
              lambda seconds: ngettext("%(n)s second","%(n)s seconds",seconds)%{'n':seconds})]
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
    if friendly and len(time_strings)>2:
        time_stings = time_strings[:2]
    if len(time_strings)>2:
        # Translators... this is a messay way of concatenating
        # lists. In English we do lists this way: 1, 2, 3, 4, 5
        # and 6. This set-up allows for the English system only.
        # You can of course make your language only use commas or
        # ands or spaces or whatever you like by translating both
        # ", " and " and " with the same string.
        return _(" and ").join([_(", ").join(time_strings[0:-1]),time_strings[-1]])
    else:
        return _(" ").join(time_strings)

def format_time_compact (tim):
    tim = int(tim)
    hours = tim / (60*60)
    minutes = (tim % (60*60)) / 60
    seconds = ((tim % (60*60)) % 60)
    return "%d:%02d:%02d"%(hours,minutes,seconds)

def format_date (tim):
    lt = time.localtime(tim)
    hours = int(time.strftime("%H",lt))
    minutes = int(time.strftime("%M",lt))
    diff = time.time() - tim
    to_yesterday = hours*60*60+minutes*60
    if diff < to_yesterday:
        # then we're today
        # Translators, see strftime manual in order to translate %? format strings
        return time.strftime(_('Today %R %p'),lt)
    elif diff < (to_yesterday + 60*60*24):
        # Translators, see strftime manual in order to translate %? format strings
        return time.strftime(_('Yesterday %R %p'),lt)
    elif diff < (60*60*24*7): # less than a week
        # Translators, see strftime manual in order to translate %? format strings
        return time.strftime(_("%A %H:%M"),lt) # Day, Hour:Minutes
    else:
        # Translators, see strftime manual in order to translate %? format strings
        return time.strftime(_("%A %B %d %R %p"),lt)

def format_friendly_date (tim):
    lt = time.localtime(tim)
    hours = int(time.strftime("%H",lt))
    minutes = int(time.strftime("%M",lt))
    diff = time.time() - tim
    ct = time.localtime(); chour=ct[3]; cmin=ct[4]
    to_yesterday = chour*60*60+cmin*60
    if diff < to_yesterday:
        # Then we're today
        if diff < (60*60): # within the hour...
            if (int(diff) / 60):
                m = (diff / 60)
                return ngettext("%(n)s minute ago",
                                "%(n)s minutes ago",m)%{'n':int(m)}
            else: # within the minute
                return ngettext("%(n)s second ago",
                                "%(n)s seconds ago",
                                int(diff))%{'n':int(diff)}
        else:
            # Translators, see strftime manual in order to translate %? format strings
            return time.strftime(_("at %I:%M %p"),lt)
    elif diff < to_yesterday + (60*60*24):
        # Translators, see strftime manual in order to translate %? format strings
        return time.strftime(_("yesterday at %I:%M %p"),lt)
    elif diff < to_yesterday + (60*60*24)*6:
        # Translators, see strftime manual in order to translate %? format strings
        return time.strftime(_("%A %I:%M %p"),lt)
    else:
        # Translators, see strftime manual in order to translate %? format strings
        return time.strftime(_("%B%e"),lt)

class ActiveTimer (gobject.GObject):
    """A timer to keep track of how much time a window is active."""

    __gsignals__ = {
        'timing-started':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,()),
        'timing-stopped':(gobject.SIGNAL_RUN_LAST,gobject.TYPE_NONE,())
        }
    
    def __init__ (self, window):
        gobject.GObject.__init__(self)
        self.window = window
        self.timing_running = False
        self.__absolute_start_time__ = 0
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
            return

        if on and not self.timing_running:            
            self.timing_started_at = time.time()
            self.timing_running = True
            self.emit('timing-started')

        if not on and self.timing_running:
            end_time = time.time()
            self.timing_running = False
            self.tot_time += (end_time - self.timing_started_at)
            self.tot_time_complete = end_time - self.__absolute_start_time__
            self.emit('timing-stopped')

    def start_timing (self):
        self.timing_running = False
        self.__absolute_start_time__ = 0
        self.tot_time = 0
        self.tot_time_complete = 0
        self.__absolute_start_time__ = time.time()
        self.toggle_timing(True)

    def finish_timing (self):
        self.toggle_timing(False)
        if self.tot_time < 1:
            self.tot_time = 1;
        # dirty hack: never let total time be less than active time
        if self.tot_time > self.tot_time_complete:
            self.tot_time_complete = self.tot_time;
        self.__absolute_start_time__ = 0

    # make sure to call finish_timing before using this function
    def active_time_string (self):
        return format_time(self.tot_time)
    
    # make sure to call finish_timing before using this function
    def total_time_string (self):
        return format_time(self.tot_time_complete)

if gtk.pygtk_version[1]<8: gobject.type_register(ActiveTimer)

