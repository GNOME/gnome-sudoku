# -*- coding: utf-8 -*-
import gtk, gobject
import time
from gettext import gettext as _
from gettext import ngettext

def format_time (tim, round_at = None, friendly = False):
    """Format a time for display to the user.

    If round_at, we round all times to some number of seconds.

    If friendly, we don't bother showing the user more than two
    units. i.e. 3 days 2 hours, or 2 minutes 30 seconds, but not 3
    days, 4 hours, 2 minutes and 3 seconds...
    """
    tim = int(tim)
    time_strings = []
    units = [(int(365.25 * 24 * 60 * 60),
              lambda years: ngettext("%(n)s year", "%(n)s years", years) % {'n': years}),
             (31 * 24 * 60 * 60,
              lambda months: ngettext("%(n)s month", "%(n)s months", months) % {'n': months}),
             (7 * 24 * 60 * 60,
              lambda weeks: ngettext("%(n)s week", "%(n)s weeks", weeks) % {'n': weeks}),
             (24 * 60 * 60,
              lambda days: ngettext("%(n)s day", "%(n)s days", days) % {'n': days}),
             (60 * 60,
              lambda hours: ngettext("%(n)s hour", "%(n)s hours", hours) % {'n': hours}),
             (60,
              lambda minutes: ngettext("%(n)s minute", "%(n)s minutes", minutes) % {'n': minutes}),
             (1,
              lambda seconds: ngettext("%(n)s second", "%(n)s seconds", seconds) % {'n': seconds})]
    for divisor, unit_formatter in units:
        time_covered = tim / divisor
        if time_covered:
            if round_at and len(time_strings) + 1 >= round_at:
                time_covered = int(round(float(tim) / divisor))
                time_strings.append(unit_formatter(time_covered))
                break
            else:
                time_strings.append(unit_formatter(time_covered))
                tim = tim - time_covered * divisor
    if friendly and len(time_strings) > 2:
        time_strings = time_strings[:2]
    if len(time_strings) > 2:
        # Translators... this is a messay way of concatenating
        # lists. In English we do lists this way: 1, 2, 3, 4, 5
        # and 6. This set-up allows for the English system only.
        # You can of course make your language only use commas or
        # ands or spaces or whatever you like by translating both
        # ", " and " and " with the same string.
        return _(" and ").join([_(", ").join(time_strings[0:-1]), time_strings[-1]])
    else:
        return _(" ").join(time_strings)

class ActiveTimer (gobject.GObject):
    """A timer to keep track of how much time a window is active."""

    __gsignals__ = {
        'timing-started': (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, ()),
        'timing-stopped': (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, ())
        }

    def __init__ (self, window):
        gobject.GObject.__init__(self)
        self.window = window
        # whether we have 'start_timing'; affects total_time
        self.timer_running = False
        # whether the timer is running/paused; affects active_time
        self.is_timing = False

        self.active_time = 0
        self.total_time = 0
        self.__absolute_start_time__ = 0
        self.interval_start = 0

        self.window.connect('focus-in-event',
                lambda *args: self.resume_timing())
        self.window.connect('focus-out-event',
                lambda *args: self.pause_timing())

    def resume_timing (self):
        '''start the interval of active time
        '''
        if self.timer_running and not self.is_timing:
            self.is_timing = True
            self.interval_start = time.time()
            self.emit('timing-started')

    def pause_timing (self):
        '''end the interval of active time
        '''
        if self.timer_running and self.is_timing:
            self.is_timing = False
            interval_end = time.time()
            # active_time is composed of intervals between pausing and resuming
            self.active_time += (interval_end - self.interval_start)
            self.total_time = time.time() - self.__absolute_start_time__
            self.emit('timing-stopped')

    def start_timing (self):
        self.timer_running = True
        self.active_time = 0
        self.total_time = 0
        self.__absolute_start_time__ = time.time()
        self.resume_timing()

    def mark_timing(self):
        currently_timing = self.is_timing
        self.pause_timing()
        if self.active_time < 1:
            self.active_time = 1
        # dirty hack: never let total time be less than active time
        if self.active_time > self.total_time:
            self.total_time = self.active_time
        if currently_timing:
            self.resume_timing()

    def finish_timing (self):
        self.mark_timing()
        self.timer_running = False

    def active_time_string (self):
        return format_time(self.active_time)

    def total_time_string (self):
        return format_time(self.total_time)

if __name__ == '__main__':
    def report (timer):
        print 'active:', timer.active_time_string()
        print 'total:', timer.total_time_string()

    def test_active_timer ():
        win = gtk.Window()
        timer = ActiveTimer(win)
        timer.start_timing()
        win.connect('focus-out-event', lambda *args: report(timer))
        win.connect('delete-event', gtk.main_quit)
        win.show()
        gtk.main()

    test_active_timer()
