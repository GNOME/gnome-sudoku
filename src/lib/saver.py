import pickle, types, os, os.path, sudoku, errno
from defaults import *
from gtk_goodies.dialog_extras import show_message
from gettext import gettext as _

SAVE_ATTRIBUTES = [('gsd.hints'),
                   ('gsd.impossible_hints'),
                   ('gsd.auto_fills'),
                   ('timer.__absolute_start_time__'),
                   ('timer.tot_time'),
                   ]

def super_getattr (obj, attr):
    """getattr, following the dots."""
    attrs=attr.split('.')
    for a in attrs:
        obj = getattr(obj,a)
    return obj

def super_setattr (obj, attr, val):
    """setattr, following the dots."""
    attrs = attr.split('.')
    if len(attrs) > 1:
        sub_attrs = attrs[0:-1]
        attr = attrs[-1]
        for a in sub_attrs:
            obj = getattr(obj,a)
    setattr(obj,attr,val)

def jar_game (ui):
    jar = {} # what we will pickle
    #jar['undo_history']=ui.history
    ui.timer.resume_timing()
    ui.timer.toggle_timing(False) # Save time...
    jar['game']=ui.gsd.grid.to_string()
    jar['trackers']=ui.gsd.trackers
    jar['tracking']=ui.gsd.__trackers_tracking__
    jar['notes']=[]
    for e in ui.gsd.__entries__.values():
        top,bot = e.get_note_text()
        if top or bot:
            jar['notes'].append((e.x,e.y,top,bot))
    for attr in SAVE_ATTRIBUTES:
        jar[attr]=super_getattr(ui,attr)
    return jar

def open_game (ui, jar):
    #ui.history = jar['undo_history']
    ui.gsd.load_game(jar['game'])
    # this is a bit easily breakable... we take advantage of the fact
    # that we create tracker IDs sequentially and that {}.items()
    # sorts by keys by default
    for tracker,tracked in jar.get('trackers',{}).items():
        # add 1 tracker per existing tracker...
        ui.tracker_ui.add_tracker()
        #ui.tracker_ui.show() # Leave this to the toggle setting
        for x,y,val in tracked:
            ui.gsd.add_tracker(x,y,tracker,val=val)
    for tracker,tracking in jar.get('tracking',{}).items():
        if tracking:
            ui.tracker_ui.select_tracker(tracker)
    for attr in SAVE_ATTRIBUTES:
        super_setattr(ui,attr,jar.get(attr,None))
    if jar.has_key('notes') and jar['notes']:
        for x,y,top,bot in jar['notes']:
            ui.gsd.__entries__[(x,y)].set_note_text(top,bot)
        
def pickle_game (ui, target):
    close_me = False
    if type(target) in types.StringTypes:
        target = file(target,'w')
        close_me = True
    to_dump = jar_game(ui)
    pickle.dump(to_dump,target)
    if close_me: target.close()
    
def unpickle_game (ui, target):
    close_me = False
    if type(target)==str:
        target = file(target, 'r')
        close_me = True
    open_game(ui,pickle.load(target))
    if close_me: target.close()

class SudokuTracker:

    """A class to track games in progress and games completed.
    """

    def __init__ (self):
        self.save_path = os.path.expanduser('~/.sudoku/saved')
        self.finished_path = os.path.expanduser('~/.sudoku/finished')
        self.create_dir_safely(self.save_path)
        self.create_dir_safely(self.finished_path)

    def create_dir_safely (self, path):
        if not os.path.exists(path):
            try:
                os.makedirs(path)
            except OSError, e:                
                if e.errno == errno.ENOSPC:
                    show_message(
                        title=_('No Space'),
                        label=_('No space left on disk'),
                        message_type=gtk.MESSAGE_ERROR,
                        sublabel=_('Sudoku is unable to created data folder %(path)s.')%locals() +\
                                 _('There is no disk space left!')
                        )
                else:
                    show_message(
                        title='Error creating directory',
                        label='Error creating directory',
                        sublabel=_('Sudoku was unable to create data folder %(path)s.')%locals() +\
                        _('Error %(errno)s: %(error)s')%{'errno':e.errno,
                                                         'error':e.strerror}
                        )

    def are_finished_games (self):
        if os.listdir(self.finished_path): return True
        else: return False

    def game_from_ui (self, ui):
        return ui.gsd.grid.virgin.to_string()

    def get_filename (self, gamestring):
        return gamestring.split('\n')[0].replace(' ','')

    def save_game (self, ui):
        game = self.game_from_ui(ui)
        jar = jar_game(ui)
        #jar['saved_at'] = time.time()
        filename = os.path.join(self.save_path,self.get_filename(jar['game']))
        try:
            outfi = file(filename,'w')
            pickle.dump(jar,outfi)
            outfi.close()
        except (OSError, IOError), e:
            show_message(
                title=_('Sudoku unable to save game.'),
                label=_('Sudoku unable to save game.'),
                message_type=gtk.MESSAGE_ERROR,
                sublabel=(_('Unable to save file %(filename)s.')%locals()
                          + '\n' +
                          _('Error %(errno)s: %(error)s')%{
                'errno':e.errno,
                'error':e.strerror
                })
                )

    def finish_game (self, ui):
        game = self.game_from_ui(ui)
        jar  = jar_game(ui)
        self.finish_jar(jar)

    def finish_jar (self, jar):
        self.remove_from_saved_games(jar) # 
        try:
            filename = os.path.join(self.finished_path,
                                    self.get_filename(jar['game']))
            outfi = file(filename,'w')
            pickle.dump(jar,outfi)
            outfi.close()
        except (OSError, IOError), e:
            show_message(
                title=_('Sudoku unable to mark game as finished.'),
                label=_('Sudoku unable to mark game as finished.'),
                message_type=gtk.MESSAGE_ERROR,
                sublabel=(_('Unable to save file %(filename)s.'%locals) + '\n' +
                          _('Error %(errno)s: %(error)s')%{
                'errno':e.errno,
                'error':e.strerror
                })
                )
        try:
            filename = list_of_finished_games = os.path.join(
                os.path.join(DATA_DIR,'puzzles'),'finished'
                )
            ofi = open(list_of_finished_games,'a')
            ofi.write(jar['game'].split('\n')[0]+'\n')
            ofi.close()
        except (OSError, IOError), e:
            show_message(
                title=_('Sudoku unable to mark game as finished.'),
                label=_('Sudoku unable to mark game as finished.'),
                message_type=gtk.MESSAGE_ERROR,
                sublabel=(_('Unable to save file %(filename)s.'%locals) + '\n' +
                          _('Error %(errno)s: %(error)s')%{
                'errno':e.errno,
                'error':e.strerror
                })
                )

    def remove_from_saved_games (self, jar):
        previously_saved_game = os.path.join(
            self.save_path,self.get_filename(jar['game'])
            )
        if os.path.exists(previously_saved_game):
            os.remove(os.path.join(previously_saved_game))

    def abandon_game (self, ui):
        game = self.game_from_ui(ui)
        jar  = jar_game(ui)
        self.remove_from_saved_games(jar)
        
    def list_saved_games (self):
        files = os.listdir(self.save_path)
        games = []
        for f in files:
            f = os.path.join(self.save_path,f)
            try:
                jar = pickle.load(file(f,'r'))
            except:
                print 'Warning: could not read file',f
            else:
                jar['saved_at']=os.stat(f)[8]
                games.append(jar)
        return games
        

