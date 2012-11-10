# -*- coding: utf-8 -*-
#!/usr/bin/python

import random
import copy

NO_TRACKER = -1 # Tracker id for untracked values

class TrackerInfo(object):
    '''Tracker state machine(singleton)

    The singleton instance of this class is used to manipulate tracker
    selection and tracked values, as well as interrogate tracker colors.

    _tracks - dictionary for tracked values.  The tracker id is used as the
        key.  A tracker is a dictionary that stored tracked values keyed by
        its coordinates(x, y).  _tracks[tracker_id][(x, y)] == tracked value

    current_tracker - The tracker id for the currently selected tracker
    showing_tracker - The tracker id for the tracker that is currently being
        viewed.  The point to this member is to store off the tracker when
        the player switches to "Untracked" so that the last tracker they were
        working on stays in view after the switch.
    '''
    __single = None
    _tracks = {}
    _colors = {}
    current_tracker = NO_TRACKER
    showing_tracker = NO_TRACKER

    def __new__(cls, *args, **kwargs):
        '''Overridden to implement as a singleton
        '''
        # Check to see if a __single exists already for this class
        # Compare class types instead of just looking for None so
        # that subclasses will create their own __single objects
        if cls != type(cls.__single):
            cls.__single = object.__new__(cls, *args, **kwargs)
        return cls.__single

    def __init__(self):
        # Only initialize the colors once
        if self._colors:
            return
        # Use tango colors recommended here:
        # http://tango.freedesktop.org/Tango_Icon_Theme_Guidelines
        for tracker_id, cols in enumerate(
        [(32, 74, 135), # Sky Blue 3
         (78, 154, 6), # Chameleon 3
         (206, 92, 0), # Orange 3
         (143, 89, 2), # Chocolate 3
         (92, 53, 102), # Plum 3
         (85, 87, 83), # Aluminium 5
         (196, 160, 0) # Butter 3
        ]):
            self._colors[tracker_id] = tuple([x / 255.0 for x in cols])

    def load(self, pickle):
        self.current_tracker, self.showing_tracker, self._tracks = pickle

    def save(self):
        return (self.current_tracker, self.showing_tracker, self.get_trackers())

    def create_tracker (self, tracker_id = 0):
        '''Create storage for a new tracker

        tracker_id can be passed in to attempt creation of a specific id, but
        if the tracker_id already exists then the passed number will be
        incremented until a suitable key can be allocated.
        '''
        if not tracker_id:
            tracker_id = 0
        while tracker_id in self._tracks:
            tracker_id += 1
        self._tracks[tracker_id] = {}
        return tracker_id

    def get_tracker(self, tracker_id):
        if tracker_id in self._tracks:
            return self._tracks[tracker_id]

    def delete_tracker(self, tracker_id):
        if tracker_id in self._tracks:
            del self._tracks[tracker_id]

    def reset (self):
        ''' Reset the tracker information
        '''
        self._tracks = {}
        self.current_tracker = NO_TRACKER
        self.showing_tracker = NO_TRACKER

    def use_trackers (self, trackers):
        self._tracks = trackers

    def get_trackers(self):
        return copy.deepcopy(self._tracks)

    def set_tracker(self, tracker_id):
        self.current_tracker = tracker_id
        if tracker_id != NO_TRACKER:
            self.showing_tracker = tracker_id

    def hide_tracker(self):
        self.showing_tracker = NO_TRACKER

    def get_tracker_view(self):
        return((self.current_tracker, self.showing_tracker))

    def set_tracker_view(self, tview):
        self.current_tracker, self.showing_tracker = tview

    def get_color (self, tracker_id):
        # Untracked items don't get specially colored
        if tracker_id == NO_TRACKER:
            return None
        # Create a random color for new trackers that are beyond the defaults
        if tracker_id not in self._colors:
            random_color = self._colors[0]
            while random_color in list(self._colors.values()):
                # If we have generated all possible colors, this will
                # enter an infinite loop
                random_color = (random.randint(0, 100)/100.0,
                                random.randint(0, 100)/100.0,
                                random.randint(0, 100)/100.0)
            self._colors[tracker_id] = random_color
        return self._colors[tracker_id]

    def get_color_markup(self, tracker_id):
        color_tuple = self.get_color (tracker_id)
        if not color_tuple:
            return None
        color_markup = '#'
        color_markup += str(hex(int(color_tuple[0]*255))[2:]).zfill(2)
        color_markup += str(hex(int(color_tuple[1]*255))[2:]).zfill(2)
        color_markup += str(hex(int(color_tuple[2]*255))[2:]).zfill(2)
        return color_markup.upper()

    def get_current_color(self):
        return self.get_color(self.current_tracker)

    def get_showing_color(self):
        return self.get_color(self.showing_tracker)

    def add_trace(self, x, y, value, tracker_id = None):
        '''Add a tracked value

        By default(tracker_id set to None) this method adds a value to the
        current tracker.  tracker_id can be passed in to add it to a specific
        tracker.
        '''
        if tracker_id == None:
            to_tracker = self.current_tracker
        else:
            to_tracker =  tracker_id
        # Need a tracker
        if to_tracker == NO_TRACKER:
            return
        # Make sure the dictionary is available for the tracker.
        if to_tracker not in self._tracks:
            self._tracks[to_tracker] = {}
        # Add it
        self._tracks[to_tracker][(x, y)] = value

    def remove_trace(self, x, y, from_tracker = None):
        '''Remove a tracked value

        By default(from_tracker set to None) this method removes all tracked
        values for a particular cell(x, y coords).  from_tracker can be passed
        to remove tracked values from a particular tracker only.
        '''
        if from_tracker == None:
            from_tracks = list(self._tracks.keys())
        else:
            from_tracks = [from_tracker]
        # Delete them
        for tracker in from_tracks:
            if tracker in self._tracks and (x, y) in self._tracks[tracker]:
                del self._tracks[tracker][(x, y)]

    def get_trackers_for_cell(self, x, y):
        '''Return all trackers for a cell

        This function is used for the undo mechanism.  A list in the format
        (tracker, value) is returned so that it may later be reinstated with
        reset_trackers_for_cell().
        '''
        ret = []
        for tracker, track in list(self._tracks.items()):
            if (x, y) in track:
                ret.append((tracker, track[(x, y)]))
        return ret

    def reset_trackers_for_cell(self, x, y, old_trackers):
        '''Reset all trackers to a previous state for a cell

        This function is used for the undo mechanism.  It reinstates the
        tracked values the list created by get_trackers_for_cell().
        '''
        # Remove all the current traces
        for tracker, track in list(self._tracks.items()):
            if (x, y) in track:
                del self._tracks[tracker][(x, y)]
        # Add the old ones back
        for tracker, value in old_trackers:
            self._tracks[tracker][(x, y)] = value


