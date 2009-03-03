# -*- coding: utf-8 -*-
import sys
import os, shutil
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
                  pickle_to = os.path.join(DATA_DIR,'puzzles')):
        self.pickle_to = pickle_to
        self.paused = False
        self.terminated = False
        self.generator_args = generator_args
        self.puzzle_maker_args = puzzle_maker_args
        self.batch_size = batch_size
        self.load()
        self.all_puzzles = {}
        self.played = self.get_pregenerated('finished')
        self.n_available_sudokus = {'easy':None,'medium':None,'hard':None,'very hard':None}

    def load (self):
        try:
            os.makedirs(self.pickle_to)
        except os.error, e:
            if e.errno != errno.EEXIST:
                return
        for cat in sudoku.DifficultyRating.categories:
            source = os.path.join(os.path.join(PUZZLE_DIR),cat.replace(' ','_'))
            target = os.path.join(self.pickle_to, cat.replace(' ','_'))
            if not os.path.exists(target):
                try:
                    shutil.copy(source, target)
                except:
                    print 'Problem copying base puzzles'
                    print 'Attempted to copy from %s to %s' % (source, target)
                
    def get_pregenerated (self, difficulty):
        fname = os.path.join(self.pickle_to, difficulty.replace(' ','_'))
        try:
            lines = file(fname).readlines()
        except IOError, e:
            if e.errno != errno.ENOENT:
                print 'Error reading pregenerated puzzles for difficulty \'%s\': %s' % (difficulty, e.strerror)
            return []
        else:
            return [line.strip() for line in lines]
        
    def get_new_puzzle (self, difficulty, new=True):
        """Return puzzle with difficulty near difficulty.

        If new is True, we return only unplayed puzzles.
        Return a tuple containing a new puzzle and difficulty object.
        """
        val_cat = sudoku.get_difficulty_category(difficulty)
        if not val_cat:
            print 'WARNING, no val cat for difficulty:',difficulty
            if val_cat > 1: val_cat = 'very hard'
            else: val_cat = 'easy'
        puzzles = []

        lines = self.get_pregenerated(val_cat)
        closest = 10000000000000,None
        for l in lines:
            if len(l) == 0:
                print 'Warning: file %s contains an empty line'%fname
                continue
            if not l.find('\t')>=0:
                print 'Warning: line "%s" of file %s has no tab character.'%(l,fname)
                continue
            puzzle,diff = l.split('\t')
            if new and (puzzle in self.played): continue
            if not sudoku.is_valid_puzzle(puzzle):
                print 'WARNING: invalid puzzle %s in file %s'%(puzzle,fname)
                continue
            diff = float(diff)
            closeness_to_target = abs(diff - difficulty)
            if closest[0] > closeness_to_target:
                closest = diff,puzzle
        return closest[1],sudoku.SudokuRater(
            sudoku.sudoku_grid_from_string(closest[1]).grid
            ).difficulty()

    def n_puzzles (self, difficulty_category=None, new=True):
        if not difficulty_category:
            return sum([self.n_puzzles(c,new=new) for c in sudoku.DifficultyRating.categories])
        else:
            if self.n_available_sudokus[difficulty_category]:
                return self.n_available_sudokus[difficulty_category]
            lines = self.get_pregenerated(difficulty_category)
            count = 0
            for line in lines:
                if (not new) or line.split('\t')[0] not in self.played:
                    count+=1
            self.n_available_sudokus[difficulty_category] = count
            return self.n_available_sudokus[difficulty_category]

    def list_puzzles (self, difficulty_category=None, new=True):
        """Return a list of all puzzles we have generated.
        """
        puzzle_list = []
        if not difficulty_category:
            for c in sudoku.DifficultyRating.categories:
                puzzle_list.extend(self.list_puzzles(c,new=new))
        else:
            lines = self.get_pregenerated(difficulty_category)
            for l in lines:
                puzzle = l.split('\t')[0]
                if (not new) or puzzle not in self.played:
                    puzzle_list.append(puzzle)
        return puzzle_list

    def get_puzzles_random (self, n, levels, new=True, exclude=[]):
        """Return a list of n puzzles and difficulty values (as floats).

        The puzzles will correspond as closely as possible to levels.
        If new, we only return puzzles not yet played.
        """
        if not n: return []
        assert(levels)
        puzzles = []
        # Open files to read puzzles...
        puzzles_by_level = {}; files = {}
        for l in levels:
            puzzles_by_level[l] = self.get_pregenerated(l)
            random.shuffle(puzzles_by_level[l])
        i = 0; il = 0
        n_per_level = {}
        finished = []
        while i < n and len(finished) < len(levels):
            if il >= len(levels): il = 0
            lev = levels[il]
            # skip any levels that we've exhausted
            if lev in finished:
                il += 1
                continue
            try:
                line = puzzles_by_level[lev].pop()
            except IndexError:
                finished.append(lev)
            else:
                try:
                    p,d = line.split('\t')
                except ValueError:
                    print 'WARNING: invalid line %s in file %s'%(line,files[lev])
                    continue
                if sudoku.is_valid_puzzle(p):
                    if (p not in exclude) and (not new or p not in self.played):
                        puzzles.append((p,float(d)))
                        i += 1
                else:
                    print 'WARNING: invalid puzzle %s in file %s'%(p,files[lev])
            il += 1
        if i < n:
            print 'WARNING: Not able to provide %s puzzles in levels %s'%(n,levels)
            print 'WARNING: Generate more puzzles if you really need this many puzzles!'
        return puzzles    

    def get_puzzles (self, n, levels, new=True, randomize=True,
                     exclude=[]):
        """Return a list of n puzzles and difficulty values (as floats).

        The puzzles will correspond as closely as possible to levels.
        If new, we only return puzzles not yet played.
        """
        if randomize: return self.get_puzzles_random(n,levels,new=new,exclude=exclude)
        if not n: return []
        assert(levels)
        puzzles = []
        
        # Open files to read puzzles...
        files = {}
        for l in levels:
            files[l] = self.get_pregenerated(l)

        i = 0; il = 0
        n_per_level = {}
        finished = []
        while i < n and len(finished) < len(levels):
            if il >= len(levels): il = 0
            lev = levels[il]
            # skip any levels that we've exhausted
            if lev in finished:
                il += 1
                continue
            
            if len(files[lev]) == 0:
                finished.append(lev)
            else:
                line = files[lev][0]
                files[lev] = files[lev][1:]
                try:
                    p,d = line.split('\t')
                except ValueError:
                    print 'WARNING: invalid line %s in file %s'%(line,files[lev])
                    continue
                if sudoku.is_valid_puzzle(p):
                    if (p not in exclude) and (not new or p not in self.played):
                        puzzles.append((p,float(d)))
                        i += 1
                else:
                    print 'WARNING: invalid puzzle %s in file %s'%(p,files[lev])
            il += 1
        if i < n:
            print 'WARNING: Not able to provide %s puzzles in levels %s'%(n,levels)
            print 'WARNING: Generate more puzzles if you really need this many puzzles!'

        return puzzles    

    # End convenience methods for accessing puzzles we've created

    # Methods for creating new puzzles

    def make_batch (self, diff_min=None, diff_max=None):
        self.new_generator = InterruptibleSudokuGenerator(**self.generator_args)
        key = self.new_generator.start_grid.to_string()        
        #while 
        #    self.new_generator = InterruptibleSudokuGenerator(**self.generator_args)
        #    key = self.new_generator.start_grid.to_string()
        #print 'We have our solution grid'
        #self.puzzles_by_solution[key]=[]
        ug = self.new_generator.unique_generator(**self.puzzle_maker_args)
        open_files = {}
        for n in range(self.batch_size):
            #print 'start next item...',n
            puz,diff = ug.next()
            #print "GENERATED ",puz,diff
            if ((not diff_min or diff.value >= diff_min)
                and
                (not diff_max or diff.value <= diff_max)):
                puzstring = puz.to_string()
                # self.puzzles_by_solution[key].append((puzstring,diff))
                # self.solutions_by_puzzle[puzstring]=key
                # self.all_puzzles[puzstring] = diff
                # self.names[puzstring] = self.get_puzzle_name(_('Puzzle'))
                outpath = os.path.join(self.pickle_to,
                                       diff.value_category().replace(' ','_'))
                # Read through the existing file and make sure we're
                # not a duplicate puzzle
                existing = self.get_pregenerated(diff.value_category())
                if not puzstring in existing:
                    try:
                        outfi = file(outpath,'a')
                        outfi.write(puzstring+'\t'+str(diff.value)+'\n')
                        outfi.close()
                        self.n_available_sudokus[diff.value_category()]+=1
                    except IOError, e:
                        print 'Error appending pregenerated puzzle: %s' % e.strerror

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

    def get_difficulty (self, puz):
        return sudoku.SudokuRater(puz).difficulty()

        
if __name__ == '__main__':
    import time
    #puzzles=sg.generate_puzzles(30)
    #
    #print sg.make_symmetric_puzzle()
    #unique_maker = sg.unique_generator()
    #unique = []
    #for n in range(10):
    #    unique.append(unique_maker.next())
    #    print 'Generated Unique...'
    #unique_puzzles=filter(lambda x: sudoku.SudokuSolver(x[0].grid,verbose=False).has_unique_solution(),puzzles)
    sm = SudokuMaker()
    #st = SudokuTracker(sm)
elif False:    
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
        
