import sys
import os
import os.path
import sudoku
import random
import pickle
import time
import pausable
import threading
import saver
from gettext import gettext as _
from defaults import *

class SudokuGenerator:

    """A class to generate new Sudoku Puzzles."""

    def __init__ (self, start_grid=None, clues=2, group_size=9):
        self.generated = []
        self.clues = clues
        self.all_coords = []
        self.group_size = group_size
        for x in range(self.group_size):
            for y in range(self.group_size):
                self.all_coords.append((x,y))
        if start_grid:
            self.start_grid = sudoku.SudokuGrid(start_grid)
        else:
            try:
                self.start_grid = self.generate_grid()
            except:
                self.start_grid = self.generate_grid()
        self.puzzles = []
        self.rated_puzzles = []

    def average_difficulty (self):
        difficulties = [i[1].value for i in self.rated_puzzles]
        if difficulties:
            return sum(difficulties)/len(difficulties)

    def generate_grid (self):
        self.start_grid = sudoku.SudokuSolver(verbose=False,group_size=self.group_size)
        self.start_grid.solve()
        return self.start_grid

    def reflect (self, x, y, axis=1):
        #downward sloping
        upper = self.group_size - 1
        # reflect once...
        x,y = upper - y,upper-x
        # reflect twice...
        return y, x
            
    def make_symmetric_puzzle (self):
        nclues = self.clues/2
        buckshot = set(random.sample(self.all_coords,nclues))
        new_puzzle = sudoku.SudokuGrid(verbose=False,group_size=self.group_size)
        reflections = set()
        for x,y in buckshot:
            reflection = self.reflect(x,y)
            if reflection:
                nclues += 1
                reflections.add(reflection)
        buckshot = buckshot | reflections # unite our sets
        remaining_coords = set(self.all_coords) - set(buckshot)
        while len(buckshot) < self.clues:
            coord = random.sample(remaining_coords,1)[0]
            buckshot.add(coord)
            reflection = self.reflect(*coord)
            if reflection:
                buckshot.add(reflection)
            remaining_coords = remaining_coords - buckshot
        return self.make_puzzle_from_coords(buckshot)

    def make_puzzle (self):
        buckshot = random.sample(self.all_coords,self.clues)
        while buckshot in self.generated:
            buckshot = random.sample(self.all_coords,self.clues)
        return self.make_puzzle_from_coords(buckshot)

    def make_puzzle_from_coords (self, buckshot):
        new_puzzle = sudoku.SudokuGrid(verbose=False,group_size=self.group_size)
        self.generated.append(set(buckshot))
        for x,y in buckshot:
            new_puzzle.add(x,y,self.start_grid._get_(x,y))
        self.puzzles.append(new_puzzle)
        return new_puzzle
    
    def make_puzzle_by_boxes (self,
                              skew_by=0.0,
                              max_squares=None,):
        """Make a puzzle paying attention to evenness of clue
        distribution.

        If skew_by is 0, we distribute our clues as evenly as possible
        across boxes.  If skew by is 1.0, we make the distribution of
        clues as uneven as possible. In other words, if we had 27
        boxes for a 9x9 grid, a skew_by of 0 would put exactly 3 clues
        in each 3x3 grid whereas a skew_by of 1.0 would completely
        fill 3 3x3 grids with clues.

        We believe this skewing may have something to do with how
        difficult a puzzle is to solve. By toying with the ratios,
        this method may make it considerably easier to generate
        difficult or easy puzzles.
        """
        # Number of total boxes
        nboxes = len(self.start_grid.boxes)
        # If no max is given, we calculate one based on our skew_by --
        # a skew_by of 1 will always produce full squares, 0 will
        # produce the minimum fullness, and between between in
        # proportion to its betweenness.
        if not max_squares:
            max_squares = self.clues / nboxes
            max_squares += int((nboxes-max_squares)*skew_by)
        clued = 0
        # nclues will be a list of the number of clues we want per
        # box.
        nclues = []
        for n in range(nboxes):
            # Make sure we'll have enough clues to fill our target
            # number, regardless of our calculation of the current max
            minimum = (self.clues-clued)/(nboxes-n)
            if max_squares < minimum:
                cls = minimum
            else:
                cls = int(max_squares)
            clues = max_squares
            if clues > (self.clues - clued):
                clues = self.clues - clued
            nclues.append(int(clues))
            clued += clues
            if skew_by:
                # Reduce our number of squares proportionally to
                # skewiness. 
                max_squares = round(max_squares * skew_by)
        # shuffle ourselves...
        random.shuffle(nclues)
        buckshot = []
        for i in range(nboxes):
            if nclues[i]:
                buckshot.extend(
                    random.sample(self.start_grid.box_coords[i],
                                  nclues[i])
                    )
        return self.make_puzzle_from_coords(buckshot)

    def assess_difficulty (self, sudoku_grid):
        try:
            solver = sudoku.SudokuRater(sudoku_grid,verbose=False,group_size=self.group_size)
            d = solver.difficulty()
            self.rated_puzzles.append((sudoku_grid,d))
            return d
        except:
            print 'Impossible!'
            print 'Puzzle was:'
            print solver.virgin
            print 'Solution: ',
            print self.start_grid
            print 'Puzzle foobared in following state:',
            print solver
            raise

    def is_unique (self, sudoku_grid):
        """If puzzle is unique, return its difficulty.

        Otherwise, return None."""
        solver = sudoku.SudokuRater(sudoku_grid,verbose=False,group_size=self.group_size)
        if solver.has_unique_solution():
            return solver.difficulty()
        else:
            return None
        
    def generate_puzzle_for_difficulty (self,
                                        lower_target=0.3,
                                        upper_target=0.5,
                                        max_tries = 100,
                                        by_box=False,
                                        by_box_kwargs={}):
        for i in range(max_tries):
            if by_box:
                puz = self.make_puzzle_by_boxes(**by_box_kwargs)
            else:
                puz = self.make_puzzle()
            d = self.assess_difficulty(puz.grid)
            if (d and (not lower_target or d.value > lower_target) and\
               (not upper_target or
                d.value < upper_target)):
                return puz,d
        else: return None,None

    def make_unique_puzzle (self, symmetrical=True, strict_number_of_clues=False):
        if symmetrical:
            puz = self.make_symmetric_puzzle()
        else:
            puz = make_puzzle()
        diff = False
        if self.clues > 10:
            clues = self.clues - 8
        else:
            clues = 2
        while 1:
            solver = sudoku.SudokuRater(puz.grid,verbose=False,group_size=self.group_size)
            if solver.has_unique_solution():
                diff = solver.difficulty()
                #raw_input('Unique puzzle!')
                break
            # Otherwise...
            crumb = solver.breadcrumbs[-1]
            fill_in = [(crumb.x,crumb.y)]
            reflection = self.reflect(crumb.x,crumb.y)
            if reflection: fill_in.append(reflection)
            for x,y in fill_in:
                solver.virgin._set_(x,y,self.start_grid._get_(x,y))
            puz = sudoku.SudokuGrid(solver.virgin.grid, verbose=False)
            #print 'Not unique, adding ',fill_in
            clues += len(fill_in)
            if strict_number_of_clues==True and clues > self.clues: return None
            #print clues, "clues..."
            #raw_input('Continue: ')
        # make sure we have the proper number of clues
        if strict_number_of_clues:
            changed=False
            while clues < self.clues:
                x,y=random.randint(0,8),random.randint(0,8)
                while puz._get_(x,y): x,y=random.randint(0,8),random.randint(0,8)
                puz._set_(x,y,self.start_grid._get_(x,y))
                clues += 1
                reflection = self.reflect(x,y)
                if reflection:
                    puz._set_(x,y,self.start_grid._get_(x,y))
                    clues += 1
                changed=True
            if changed: diff = sudoku.SudokuRater(puz.grid,
                                                  verbose=False,
                                                  group_size=self.group_size).difficulty()
        return puz,diff

    def make_unique_puzzles (self, n=10, ugargs={}):
        ug = self.unique_generator(**ugargs)
        ret = []
        for i in range(n):
            #print 'Working on puzzle ',i
            ret.append(ug.next())
            #print 'Got one!'
        return ret

    def unique_generator (self,
                          symmetrical=True,
                          strict_number_of_clues=False,
                          by_box=False,
                          by_box_kwargs={}):
        while 1:
            result = self.make_unique_puzzle(
                symmetrical=symmetrical,
                strict_number_of_clues=strict_number_of_clues)
            if result: yield result

    def generate_puzzles (self, n=10,
                          symmetrical=True,
                          by_box=False,
                          by_box_kwargs={}):
        ret = []
        for i in range(n):
            #print 'Generating puzzle ',i
            if symmetrical:
                puz = self.make_symmetric_puzzle()
            elif by_box:
                puz = self.make_puzzle_by_boxes(**by_box_kwargs)
            else:
                puz = self.make_puzzle()
            #print 'Assessing puzzle ',puz
            try:
                d=self.assess_difficulty(puz.grid)
            except:
                raise
            if d:
                ret.append((puz,d))
        ret.sort(lambda a,b: a[1].value>b[1].value and 1 or a[1].value<b[1].value and -1 or 0)
        return ret


class InterruptibleSudokuGenerator (SudokuGenerator):
    def __init__ (self,*args,**kwargs):
        self.paused = False
        self.terminated = False
        SudokuGenerator.__init__(self,*args,**kwargs)
    def work (self,*args,**kwargs):
        self.unterminate()
        SudokuGenerator(self,*args,**kwargs)

pausable.make_pausable(InterruptibleSudokuGenerator)


class SudokuMaker:

    """A class to create unique, symmetrical sudoku puzzles."""

    def __init__ (self,
                  generator_args={'clues':27,
                                  'group_size':9},
                  puzzle_maker_args={'symmetrical':True},
                  batch_size = 5,
                  pickle_to = os.path.join(DATA_DIR,'generated_puzzles')):

        self.new_puzzles=[]
        self.pickle_to = pickle_to
        self.paused = False
        self.terminated = False
        self.generator_args = generator_args
        self.puzzle_maker_args = puzzle_maker_args
        self.batch_size = batch_size
        self.load()
        self.all_puzzles = {}
        # names to help our users keep track of the different puzzles!
        self.names = {}
        # and a dictionary of how high we've counted with our
        # different names (this may be getting absurdly complicated,
        # but what can you do...)
        self.top_name = {}
        
        self.solutions_by_puzzle = {}
        for solution,puzzles in self.puzzles_by_solution.items():
            for p,d in puzzles:
                self.all_puzzles[p]=d
                self.solutions_by_puzzle[p]=solution
                if not self.names.has_key(p):
                    self.names[p]=self.get_puzzle_name(_('Puzzle'))


        
    def load_initial_batch (self):
        ifi = open(os.path.join(BASE_DIR,'starter_puzzles'))
        try:
            self.puzzles_by_solution = pickle.load(ifi)
        except:
            (type, value, traceback) = sys.exc_info()
            print 'Unable to load puzzles: %s: %s' % (str(type), str(value))
            self.puzzles_by_solution = {}
        ifi.close()

    def make_batch (self, diff_min=None, diff_max=None):
        self.new_generator = InterruptibleSudokuGenerator(**self.generator_args)
        key = self.new_generator.start_grid.to_string()        
        while self.puzzles_by_solution.has_key(key):
            self.new_generator = InterruptibleSudokuGenerator(**self.generator_args)
            key = self.new_generator.start_grid.to_string()
        #print 'We have our solution grid'
        self.puzzles_by_solution[key]=[]
        ug = self.new_generator.unique_generator(**self.puzzle_maker_args)
        for n in range(self.batch_size):
            puz,diff = ug.next()
            if ((not diff_min or diff.value >= diff_min)
                and
                (not diff_max or diff.value <= diff_max)):
                puzstring = puz.to_string()
                self.puzzles_by_solution[key].append((puzstring,diff))
                self.solutions_by_puzzle[puzstring]=key
                self.all_puzzles[puzstring] = diff
                self.names[puzstring] = self.get_puzzle_name(_('Puzzle'))
                self.new_puzzles.append((puzstring,diff))

    def pause (self, *args):
        if hasattr(self,'new_generator'): self.new_generator.pause()
        self.paused = True

    def resume (self, *args):
        if hasattr(self,'new_generator'): self.new_generator.resume()
        self.paused = False

    def stop (self, *args):
        if hasattr(self,'new_generator'): self.new_generator.terminate()
        self.terminated = True

    def hesitate (self):
        while self.paused:
            if self.terminated: break
            time.sleep(1)

    def work (self, limit = None, diff_min=None, diff_max=None):
        """Intended to be called as a worker thread, make puzzles!"""
        self.terminated = False
        if hasattr(self,'new_generator'): self.new_generator.termintaed = False
        self.paused = False
        self.new_puzzles = []
        generated = 0
        while not limit or generated < limit:
            if self.terminated:
                break
            if self.paused:
                self.hesitate()
            try:
                self.make_batch(diff_min=diff_min,
                                diff_max=diff_max)
            except:
                raise
            else:
                generated += 1

    def load (self):
        ifi = None
        try:
            ifi = file(self.pickle_to,'r')
            loaded = pickle.load(ifi)
        except:
            (type, value, traceback) = sys.exc_info()
            print 'Unable to load puzzles: %s: %s' % (str(type), str(value))
            if ifi:
                ifi.close()
            self.load_initial_batch()
        else:
            ifi.close()
            self.puzzles_by_solution= loaded['by_solution']
            self.names = loaded['names']
            self.top_name = loaded['metaname']

    def save (self):
        directory =  os.path.split(self.pickle_to)[0]
        if not os.path.exists(directory):
            os.makedirs(directory)
        ofi = file(self.pickle_to,'w')
	try:
	    sys.setcheckinterval(pow(2, 31)-1)
	    # Statements in this block are assured to run atomically. 
	    # The following statement has been known to create thread 
	    # race conditions where several threads modify the object
	    # being pickled, resulting in a crash.          - Andreas  
            pickle.dump({'by_solution':self.puzzles_by_solution,
                         'names':self.names,
                         'metaname':self.top_name},
                         ofi)
	finally:
	    sys.setcheckinterval(100)
        ofi.close()

    def list_difficulties (self):
        ret = self.all_puzzles.values()
        ret.sort(lambda a,b: a.value>b.value and 1 or a.value<b.value and -1 or 0)
        return ret

    def get_difficulty_bounds (self):
        """Return minimum and maximum difficulty puzzles"""
        diffs=self.list_difficulties()
        return diffs[0].value,diffs[-1].value

    def get_puzzle (self,
                    difficulty,
                    puzzle_list=None):
        closest = None
        ret = None
        if not puzzle_list: puzzle_list = self.all_puzzles
        for p,d in puzzle_list:
            diff = abs(d.value-difficulty)
            if closest == None or diff < closest:
                ret = p,d
                closest = diff
        return ret

    def get_puzzle_name (self, base_name=_("Puzzle")):
        if not self.top_name.has_key(base_name):
            self.top_name[base_name]=1
        n=self.top_name[base_name]
        self.top_name[base_name]=n+1
        return unicode("%s %i" % (base_name, n))
        
class SudokuTracker:

    """A class to track games.

    We keep track of games that have been started and abandoned, games
    that have been completed, and games that have yet to be played.
    """
    
    def __init__ (self, sudoku_maker,
                  pickle_to=os.path.join(DATA_DIR,'games_in_progress')
                  ):
        self.sudoku_maker = sudoku_maker
        self.playing = {}
        self.finished = {}
        self.pickle_to = pickle_to
        self.load()

    def save (self):
        self.sudoku_maker.save()
        ofi = file(self.pickle_to,'w')
        pickle.dump({'playing':self.playing,
                     'finished':self.finished},
                   ofi)
        ofi.close()

    def load (self):
        if os.path.exists(self.pickle_to):
            ifi = file(self.pickle_to,'r')
            loaded = pickle.load(ifi)
            ifi.close()
            for attr in 'playing','finished': setattr(self,attr,loaded[attr])

    def game_from_ui (self, ui): return ui.gsd.grid.virgin.to_string()

    def save_game (self, ui):
        game = self.game_from_ui(ui)
        jar=saver.jar_game(ui)
        jar['solution']=self.sudoku_maker.solutions_by_puzzle.get(game,'')
        jar['saved_at']=time.time()
        self.playing[game]=jar
        return game

    def open_game (self, ui, game):
        saver.open_game(ui,self.playing[game])

    def get_difficulty (self, game):
        if not self.sudoku_maker.all_puzzles.has_key(game):
            self.sudoku_maker.all_puzzles[game]=sudoku.SudokuRater(game).difficulty()
        return self.sudoku_maker.all_puzzles[game]

    def finish_game (self, ui):
        game = self.game_from_ui(ui)
        if not self.finished.has_key(game):
            self.finished[game]=[]
        self.finished[game].append(
            {'player':ui.player,
             'hints':ui.gsd.hints,
             'impossible_hints':ui.gsd.impossible_hints,
             'auto_fills':ui.gsd.auto_fills,
             'time':ui.timer.tot_time,
             'finish_time':time.time()
             })
        if self.playing.has_key(game):
            del self.playing[game]

    def get_new_puzzle (self, difficulty, repeat_solutions=False):
        return self.sudoku_maker.get_puzzle(
            difficulty,
            puzzle_list=self.list_new_puzzles(repeat_solutions=repeat_solutions)
            )

    def list_new_puzzles (self,
                          repeat_solutions=False):
        """List new puzzles and difficulties.
        """
        if not repeat_solutions:
            keys = filter(lambda x: (not self.playing.has_key(x)
                                     and not self.finished.has_key(x)),
                          self.sudoku_maker.all_puzzles.keys())
        else:
            keys = []
            solved = [self.solutions_by_puzzle[p] for p in self.finished.keys()]
            solved.extend(
                [jar['solution'] for jar in self.playing.values()]
                )
            for solution,puzzles in self.sudoku_maker.puzzles_by_solution.items():
                if solution in solved: continue
                else: keys.extend(puzzles)
        return [(k,self.sudoku_maker.all_puzzles[k]) for k in keys]
    
if __name__ == '__main__':
    import time
    for n in range(20):
        start = time.time()
        sg = SudokuGenerator(16)
        result = sg.make_unique_puzzle()
        if result: print result
        else: print 'Failed...'
        finish = time.time() - start
        print finish
    #puzzles=sg.generate_puzzles(30)
    #
    #print sg.make_symmetric_puzzle()
    #unique_maker = sg.unique_generator()
    #unique = []
    #for n in range(10):
    #    unique.append(unique_maker.next())
    #    print 'Generated Unique...'
    #unique_puzzles=filter(lambda x: sudoku.SudokuSolver(x[0].grid,verbose=False).has_unique_solution(),puzzles)
    #sm = SudokuMaker()
    #st = SudokuTracker(sm)

    usage="""Commands are:
    run: Run sudoku-maker
    len: \# of puzzles generated
    pause: pause
    resume: resume
    terminate: kill thread
    quit: to quit
    """
    print usage
    while 1:
        inp = raw_input('choose:')
        if inp=='run':
            t=threading.Thread(target=sm.make_batch)
            t.start()
        elif inp=='show':
            print sm.puzzles
        elif inp=='len':
            print len(sm.puzzles)
        elif inp=='pause':
            sm.new_generator.pause()
        elif inp=='resume':
            sm.new_generator.resume()
        elif inp=='terminate':
            sm.new_generator.terminate()
        elif inp=='quit':
            sm.new_generator.terminate()
            break
        else:
            try:
                getattr(sm,inp)()
            except:
                print usage
        
