# -*- coding: utf-8 -*-
from gi.repository import GObject
import time

class ActiveTimer (GObject.GObject):
    """A timer to keep track of how much time a window is active."""

    __gsignals__ = {
        'timing-started': (GObject.SignalFlags.RUN_LAST, None, ()),
        'timing-stopped': (GObject.SignalFlags.RUN_LAST, None, ())
        }

    def __init__ (self, window):
        GObject.GObject.__init__(self)
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

if __name__ == '__main__':
    from gi.repository import Gtk

    def report (timer):
        pass

    def test_active_timer ():
        win = Gtk.Window()
        timer = ActiveTimer(win)
        timer.start_timing()
        win.connect('focus-out-event', lambda *args: report(timer))
        win.connect('delete-event', Gtk.main_quit)
        win.show()
        Gtk.main()

    test_active_timer()
