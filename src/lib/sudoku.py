# -*- coding: utf-8 -*-
import random
import math
import re
from gettext import gettext as _
import defaults

GROUP_SIZE = 9

TYPE_ROW = 0
TYPE_COLUMN = 1
TYPE_BOX = 2

digit_set = range(1, GROUP_SIZE + 1)
sets = [digit_set] * 9

def is_set (row):
    if len(row) == len(set(row)):
        return True

def is_sudoku (rows):
    # check rows
    for r in rows:
        if not is_set(r):
            return False
    for i in range(len(rows[0])):
        rw = [r[i] for r in rows]
        if not is_set(rw):
            return False
    # check boxes
    width = int(math.sqrt(len(rows)))
    # there should be 3x3 boxes, or 4x4 if we got funky, etc.
    # boxes will be indices
    box_coordinates = [[n * width,
                        (n + 1) * width] for n in range(width)]
    for x in box_coordinates:
        for y in box_coordinates:
            box = []
            for xrow in [rows[ri] for ri in range(*y)]:
                for i in range(*x):
                    box.append(xrow[i])
            if not is_set(box):
                return False
    return True

class UnsolvablePuzzle (TypeError):
    pass


class ConflictError (ValueError):

    def __init__ (self, conflict_type, coordinates, value):
        self.args = conflict_type, coordinates, value
        self.type = conflict_type
        self.coordinates = coordinates
        self.x = coordinates[0]
        self.y = coordinates[1]
        self.value = value

class AlreadySetError (ValueError):
    pass

class SudokuGrid:
    def __init__ (self, grid = False, verbose = False, group_size = 9):
        self.grid = []
        self.cols = []
        self.rows = []
        self.boxes = []
        self.group_size = int(group_size)
        self.verbose = False
        self.gen_set = set(range(1, self.group_size + 1))
        for n in range(self.group_size):
            self.cols.append(set())
            self.rows.append(set())
            self.boxes.append(set())
            self.grid.append([0] * self.group_size)
        self.box_by_coords = {}
        self.box_coords = {}
        self.calculate_box_coords() # sets box_coords and box_by_coords
        self.row_coords = {}
        for n, row in enumerate([[(x, y) for x in range(self.group_size)] for y in range(self.group_size)]):
            self.row_coords[n] = row
        self.col_coords = {}
        for n, col in enumerate([[(x, y) for y in range(self.group_size)] for x in range(self.group_size)]):
            self.col_coords[n] = col
        if grid:
            if type(grid) == str:
                g = re.split("\s+", grid)
                side = int(math.sqrt(len(g)))
                grid = []
                for row in range(side):
                    start = row * int(side)
                    grid.append([int(i) for i in g[start:start + side]])
            self.populate_from_grid(grid)
        self.verbose = verbose

    def calculate_box_coords (self):
        width = int(math.sqrt(self.group_size))
        box_coordinates = [[n * width,
                            (n + 1) * width] for n in range(width)]
        box_num = 0
        for xx in box_coordinates:
            for yy in box_coordinates:
                self.box_coords[box_num] = []
                for x in range(*xx):
                    for y in range(*yy):
                        self.box_by_coords[(x, y)] = box_num
                        self.box_coords[box_num].append((x, y))
                box_num += 1

    def add (self, x, y, val, force = False):
        if not val:
            pass
        if self._get_(x, y):
            if force:
                try:
                    self.remove(x, y)
                except:
                    print 'Strange: problem with add(', x, y, val, force, ')'
                    import traceback
                    traceback.print_exc()
            else:
                #FIXME:  This is called when the fill button
                #is clicked multiple times, which causes this exception:
                #raise AlreadySetError
                return
        if val in self.rows[y]:
            raise ConflictError(TYPE_ROW, (x, y), val)
        if val in self.cols[x]:
            raise ConflictError(TYPE_COLUMN, (x, y), val)
        box = self.box_by_coords[(x, y)]
        if val in self.boxes[box]:
            raise ConflictError(TYPE_BOX, (x, y), val)
        # do the actual adding
        self.rows[y].add(val)
        self.cols[x].add(val)
        self.boxes[box].add(val)
        self._set_(x, y, val)

    def remove (self, x, y):
        val = self._get_(x, y)
        self.rows[y].remove(val)
        self.cols[x].remove(val)
        self.boxes[self.box_by_coords[(x, y)]].remove(val)
        self._set_(x, y, 0)

    def _get_ (self, x, y):
        return self.grid[y][x]

    def _set_ (self, x, y, val):
        self.grid[y][x] = val

    def possible_values (self, x, y):
        return self.gen_set - self.rows[y] - self.cols[x] - self.boxes[self.box_by_coords[(x, y)]]

    def pretty_print (self):
        print 'SUDOKU'
        for r in self.grid:
            for i in r:
                print i,
            print
        print

    def populate_from_grid (self, grid):
        for y, row in enumerate(grid):
            for x, cell in enumerate(row):
                if cell:
                    self.add(x, y, cell)

    def __repr__ (self):
        s = "<Grid\n       "
        grid = []
        for r in self.grid:
            grid.append(" ".join([str(i) for i in r]))
        s += "\n       ".join(grid)
        return s

    def calculate_open_squares (self):
        possibilities = {}
        for x in range(self.group_size):
            for y in range(self.group_size):
                if not self._get_(x, y):
                    possibilities[(x, y)] = self.possible_values(x, y)
        return possibilities

    def find_conflicts (self, x, y, val, conflict_type = None):
        '''Find all squares that conflict with value val at position x,y.

        If conflict_type is specified, we only find conflicts of given
        type (ROW, COLUMN OR BOX).
        '''
        if conflict_type == TYPE_ROW:
            coords = self.row_coords[y]
        elif conflict_type == TYPE_COLUMN:
            coords = self.col_coords[x]
        elif conflict_type == TYPE_BOX:
            coords = self.box_coords[self.box_by_coords[(x, y)]]
        else:
            coords = (self.row_coords[y]
                      + self.col_coords[x]
                      + self.box_coords[self.box_by_coords[(x, y)]]
                      )
        conflicting_coordinates = []
        for x, y in coords:
            if self._get_(x, y) == val:
                conflicting_coordinates.append((x, y))
        return conflicting_coordinates

    def to_string (self):
        """Output our grid as a string."""
        return " ".join([" ".join([str(x) for x in row]) for row in self.grid])

def is_valid_puzzle (p):
    """Check puzzle for basic validity.

    This does not check for solvability or ensure a unique
    solution -- it merely checks well-formedness. This should
    provide some protection again file corruption, etc. (i.e. if
    we use this function to check puzzles before handing them out
    to the rest of the app, we'll prevent tracebacks related to
    corrupted puzzles).
    """
    try:
        p = p.replace(' ', '')
        assert(len(p.replace(' ', '')) == 81)
        [int(c) for c in p.replace(' ', '')]
    except:
        #import traceback; traceback.print_exc()
        return False
    else:
        return True

def sudoku_grid_from_string (s):
    """Given an 81 character string, return a grid."""
    s = s.replace(' ', '')
    assert(len(s)<=GROUP_SIZE ** 2)
    grid = []
    i = 0
    for x in range(GROUP_SIZE):
        row = []
        for y in range(GROUP_SIZE):
            if len(s) <= i:
                n = 0
            else:
                n = s[i]
            try:
                n = int(n)
            except:
                n = n or 0
            if n in digit_set:
                row.append(n)
            else:
                row.append(0)
            i += 1
        grid.append(row)
    return SudokuGrid(grid)


class SudokuSolver (SudokuGrid):
    """A SudokuGrid that can solve itself."""
    def __init__ (self, grid = False, verbose = False, group_size = 9):
        self.current_guess = None
        self.initialized = False
        SudokuGrid.__init__(self, grid, verbose = verbose, group_size = group_size)
        self.virgin = SudokuGrid(grid)
        self.guesses = GuessList()
        self.breadcrumbs = BreadcrumbTrail()
        self.backtraces = 0
        self.initialized = True
        self.solved = False
        self.trail = []

    def auto_fill_for_xy (self, x, y):
        """Fill the square x,y if possible."""
        possible = self.gen_set - self.rows[y] - self.cols[x] - self.boxes[self.box_by_coords[(x, y)]]
        if len(possible) == 1:
            val = possible.pop()
            self.add(x, y, val)
            return ((x, y), val)
        if len(possible) == 0:
            return -1
        # check our column...
        for coord_set, filled_set in [(self.col_coords[x], self.cols[x]),
                                     (self.row_coords[y], self.rows[y]),
                                     (self.box_coords[self.box_by_coords[(x, y)]],
                                      self.boxes[self.box_by_coords[(x, y)]])
                                     ]:
            needed_set = self.gen_set - filled_set
            for coord in coord_set:
                if self._get_(*coord):
                    continue
                elif (x, y) != coord:
                    needed_set = needed_set - self.possible_values(*coord)
            if needed_set and len(needed_set) == 1:
                val = needed_set.pop()
                if val in possible:
                    self.add(x, y, val)
                    return ((x, y), val)
                else:
                    return -1
            if len(needed_set)>1:
                return -1

    def auto_fill (self):
        changed = []
        try:
            changed = self.fill_must_fills()
        except UnsolvablePuzzle:
            return changed
        try:
            changed.extend(self.fill_deterministically())
        finally:
            return changed

    def fill_must_fills (self):
        changed = []
        for label, coord_dic, filled_dic in [('Column', self.col_coords, self.cols),
                                           ('Row', self.row_coords, self.rows),
                                           ('Box', self.box_coords, self.boxes)]:
            for n, coord_set in coord_dic.items():
                needs = dict([(n, False) for n in range(1, self.group_size + 1)])
                for coord in coord_set:
                    val = self._get_(*coord)
                    if val:
                        # We already have this value set...
                        del needs[val]
                    else:
                        # Otherwise, register ourselves as possible
                        # for each number we could be
                        for v in self.possible_values(*coord):
                            # if we don't yet have a possible number, plug ourselves in
                            if needs.has_key(v):
                                if not needs[v]:
                                    needs[v] = coord
                                else:
                                    del needs[v]
                for n, coords in needs.items():
                    if not coords:
                        raise UnsolvablePuzzle('Missing a %s in %s' % (n, label))
                    else:
                        try:
                            self.add(coords[0], coords[1], n)
                            changed.append((coords, n))
                        except AlreadySetError:
                            raise UnsolvablePuzzle(
                                "%s,%s must be two values at once!" % (coords)
                                )
        return changed

    def fill_deterministically (self):
        poss = self.calculate_open_squares().items()
        one_choice = filter(lambda x: len(x[1]) == 1, poss)
        retval = []
        for coords, choices in one_choice:
            if self.verbose:
                print 'Deterministically adding ', coords, choices
            val = choices.pop()
            self.add(coords[0], coords[1], val)
            retval.append([(coords[0], coords[1]), val])
        if self.verbose:
            print 'deterministically returning ', retval
        return retval

    def solve (self):
        self.auto_fill()
        while not self.guess_least_open_square():
            pass
        if self.verbose:
            print 'Solved!\n', self
        self.solved = True

    def solution_finder (self):
        self.auto_fill()
        while not self.guess_least_open_square():
            pass
        self.solved = True
        yield tuple([tuple(r) for r in self.grid[0:]])
        while self.breadcrumbs:
            self.unwrap_guess(self.breadcrumbs[-1])
            try:
                while not self.guess_least_open_square():
                    pass
            except UnsolvablePuzzle:
                break
            else:
                yield tuple([tuple(r) for r in self.grid[0:]])
        yield None

    def has_unique_solution (self):
        sf = self.solution_finder()
        sf.next()
        if sf.next():
            return False
        else:
            return True

    def guess_least_open_square (self):
        # get open squares and check them
        poss = self.calculate_open_squares().items()
        # if there are no open squares, we're done!
        if not poss:
            if self.verbose:
                print 'Solved!'
            return True
        # otherwise, find the possibility with the least possibilities
        poss.sort(lambda a, b: len(a[1]) > len(b[1]) and 1 or len(a[1]) < len(b[1]) and -1 or \
                  a[0] > b[0] and 1 or a[1] < b[1] and -1 or 0)
        least = poss[0]
        # remove anything we've already guessed
        possible_values = least[1] - self.guesses.guesses_for_coord(*least[0])
        if not possible_values:
            if self.breadcrumbs:
                self.backtraces += 1
                self.unwrap_guess(self.breadcrumbs[-1])
                return self.guess_least_open_square()
            else:
                raise UnsolvablePuzzle("Unsolvable %s.\n \
                Out of guesses for %s. Already guessed\n \
                %s (other guesses are %s)" % (self,
                                            least[0],
                                            self.guesses.guesses_for_coord(*least[0]),
                                            self.guesses))
        guess = random.choice(list(possible_values))
        # Create guess object
        guess_obj = Guess(least[0][0], least[0][1], guess)
        if self.breadcrumbs:
            self.breadcrumbs[-1].children.append(guess_obj)
        self.current_guess = None #reset (we're tracked via guess.child)
        self.add(least[0][0], least[0][1], guess)
        self.current_guess = guess_obj # (All deterministic additions
                                       # get added to our
                                       # consequences)
        self.guesses.append(guess_obj)
        self.trail.append(('+', guess_obj))
        self.breadcrumbs.append(guess_obj)
        try:
            self.auto_fill()
        except NotImplementedError:
            self.trail.append('Problem filling coordinates after guess')
            self.unwrap_guess(guess_obj)
            return self.guess_least_open_square()
        if set([]) in self.calculate_open_squares().values():
            self.trail.append('Guess leaves us with impossible squares.')
            self.unwrap_guess(guess_obj)
            return self.guess_least_open_square()

    def unwrap_guess (self, guess):
        self.trail.append(('-', guess))
        if self._get_(guess.x, guess.y):
            self.remove(guess.x, guess.y)
        for consequence in guess.consequences.keys():
            if self._get_(*consequence):
                self.remove(*consequence)
        for child in guess.children:
            self.unwrap_guess(child)
            if child in self.guesses:
                self.guesses.remove(child)
        if guess in self.breadcrumbs:
            self.breadcrumbs.remove(guess)

    def pad (self, n, pad_to):
        n = str(n)
        padding = int(pad_to) - len(n)
        second_half = padding / 2
        first_half = second_half + padding % 2
        return " " * first_half + n + " " * second_half

    def add (self, x, y, val, *args, **kwargs):
        if self.current_guess:
            self.current_guess.add_consequence(x, y, val)
        SudokuGrid.add(self, x, y, val, *args, **kwargs)


class InteractiveSudoku (SudokuSolver):
    """A subclass of SudokuSolver that provides some convenience
    functions for helping along a human.who is in the midst of
    solving."""
    def __init__ (self, grid = False, verbose = False, group_size = 9):
        SudokuSolver.__init__(self, grid, verbose, group_size)

    def to_string (self):
        return self.virgin.to_string() + '\n' + SudokuSolver.to_string(self)

    def find_impossible_implications (self, x, y):
        """Return a list of impossibilities implied by the users actions."""
        row_cells = self.row_coords[y]
        col_cells = self.col_coords[x]
        box = self.box_by_coords[(x, y)]
        box_cells = self.box_coords[box]
        for coord_set in [row_cells, col_cells, box_cells]:
            broken = []
            # just work on the open squares
            coord_set = filter(lambda coords: not self._get_(*coords), coord_set)
            for coords in coord_set:
                if not self.possible_values(*coords):
                    broken.append(coords)
        return broken

    def check_for_completeness (self):
        for r in self.rows:
            if len(r) != self.group_size:
                return False
        for c in self.cols:
            if len(c) != self.group_size:
                return False
        return True

    def is_changed (self):
        return (self.grid != self.virgin.grid)

class DifficultyRating:

    very_hard = _('Very Hard')
    hard = _('Hard')
    medium = _('Medium')
    easy = _('Easy')

    very_hard_range = (0.75, 10)
    hard_range = (0.6, 0.75)
    medium_range = (0.45, 0.6)
    easy_range = (-10, 0.45)

    categories = {'very hard':very_hard_range,
                  'hard':hard_range,
                  'medium':medium_range,
                  'easy':easy_range}

    ordered_categories = ['easy', 'medium', 'hard', 'very hard']
    label_by_cat = {'easy':easy,
                    'medium':medium,
                    'hard':hard,
                    'very hard':very_hard}

    def __init__ (self,
                  fill_must_fillables,
                  elimination_fillables,
                  guesses,
                  backtraces,
                  squares_filled):
        self.fill_must_fillables = fill_must_fillables
        self.elimination_fillables = elimination_fillables
        self.guesses = guesses
        self.backtraces = backtraces
        self.squares_filled = squares_filled
        if self.fill_must_fillables:
            self.instant_fill_fillable = float(len(self.fill_must_fillables[0]))
        else:
            self.instant_fill_fillable = 0.0
        if self.elimination_fillables:
            self.instant_elimination_fillable = float(len(self.elimination_fillables[0]))
        else:
            self.instant_elimination_fillable = 0.0

        self.proportion_instant_elimination_fillable = self.instant_elimination_fillable / self.squares_filled
        # some more numbers that may be crazy...
        self.proportion_instant_fill_fillable = self.instant_fill_fillable / self.squares_filled
        self.elimination_ease = add_with_diminishing_importance(
            self.count_values(self.elimination_fillables)
            )
        self.fillable_ease = add_with_diminishing_importance(
            self.count_values(self.fill_must_fillables)
            )
        self.value = self.calculate()

    def count_values (self, dct):
        kk = dct.keys()
        kk.sort()
        return [len(dct[k]) for k in kk]

    def calculate (self):
        return 1 - float(self.fillable_ease) / self.squares_filled \
                 - float(self.elimination_ease) / self.squares_filled \
                 + len(self.guesses) / self.squares_filled \
                 + self.backtraces / self.squares_filled

    def __repr__ (self):
        return '<DifficultyRating %s>' % self.value

    def pretty_print (self):
        for name, stat in [('Number of moves instantly fillable by elimination',
                           self.instant_elimination_fillable),
                          ('Percentage of moves instantly fillable by elimination',
                           self.proportion_instant_elimination_fillable * 100),
                          ('Number of moves instantly fillable by filling',
                           self.instant_fill_fillable),
                          ('Percentage of moves instantly fillable by filling',
                           self.proportion_instant_fill_fillable * 100),
                          ('Number of guesses made',
                           len(self.guesses)),
                          ('Number of backtraces', self.backtraces),
                          ('Ease by filling', self.fillable_ease),
                          ('Ease by elimination', self.elimination_ease),
                          ('Calculated difficulty', self.value)
                          ]:
            print name, ': ', stat

    def value_string (self):
        if self.value > self.very_hard_range[0]:
            return _(self.very_hard)
        elif self.value > self.hard_range[0]:
            return _(self.hard)
        elif self.value > self.medium_range[0]:
            return _(self.medium)
        else:
            return _(self.easy)

    def value_category (self):
        """Get category string, without i18n or capitalization

        For use in categorizing category.
        """
        if self.value > self.very_hard_range[0]:
            return 'very hard'
        elif self.value > self.hard_range[0]:
            return 'hard'
        elif self.value > self.medium_range[0]:
            return 'medium'
        else:
            return 'easy'

def get_difficulty_category_name (diff_float):
    return DifficultyRating.label_by_cat.get(
        get_difficulty_category(diff_float),
        '?'
        )

def get_difficulty_category (diff_float):
    for category, range in DifficultyRating.categories.items():
        if range[0] <= diff_float < range[1]:
            return category

class SudokuRater (SudokuSolver):

    def __init__ (self, grid = False, verbose = False, group_size = 9):
        self.initialized = False
        self.guessing = False
        self.fake_add = False
        self.fake_additions = []
        self.filled = set([])
        self.fill_must_fillables = {}
        self.elimination_fillables = {}
        self.tier = 0
        SudokuSolver.__init__(self, grid, verbose, group_size)

    def add (self, *args, **kwargs):
        if not self.fake_add:
            if self.initialized and not self.guessing:
                self.scan_fillables()
                for delayed_args in self.add_me_queue:
                    coords = (delayed_args[0], delayed_args[1])
                    if not self._get_(*coords):
                        SudokuSolver.add(self, *delayed_args)
                if not self._get_(args[0], args[1]):
                    SudokuSolver.add(self, *args)
                self.tier += 1
            else:
                SudokuSolver.add(self, *args, **kwargs)
        else:
            self.fake_additions.append(args)

    def scan_fillables (self):
        self.fake_add = True
        # this will now tell us how many squares at current
        # difficulty could be filled at this moment.
        self.fake_additions = []
        try:
            self.fill_must_fills()
        except:
            pass
        self.fill_must_fillables[self.tier] = set(self.fake_additions[:]) - self.filled
        self.add_me_queue = self.fake_additions[:]
        self.fake_additions = []
        try:
            self.fill_deterministically()
        except:
            pass
        self.elimination_fillables[self.tier] = set(self.fake_additions[:]) - self.filled
        self.filled = self.filled | self.fill_must_fillables[self.tier] | self.elimination_fillables[self.tier]
        self.add_me_queue.extend(self.fake_additions[:])
        self.fake_add = False

    def guess_least_open_square (self):
        self.guessing = True
        return SudokuSolver.guess_least_open_square(self)

    def difficulty (self):
        if not self.solved:
            self.solve()
        self.clues = 0
        # Add up the number of our initial clues through some nifty mapping calls
        map(lambda r: map(lambda i: setattr(self, 'clues', self.clues.__add__(i and 1 or 0)),
                          r),
            self.virgin.grid)
        self.numbers_added = self.group_size ** 2 - self.clues
        rating = DifficultyRating(self.fill_must_fillables,
                                  self.elimination_fillables,
                                  self.guesses,
                                  self.backtraces,
                                  self.numbers_added)
        return rating


class GuessList (list):
    def __init__ (self, *guesses):
        list.__init__(self, *guesses)


    def guesses_for_coord (self, x, y):
        return set([guess.val for guess in filter(lambda guess: guess.x == x and guess.y == y, self)])

    def remove_children (self, guess):
        removed = []
        for g in guess.children:
            if g in self:
                removed.append(g)
                self.remove(g)
        return removed

    def remove_guesses_for_coord (self, x, y):
        nuking = False
        nuked = []
        for i in range(len(self) - 1):
            g = self[i - len(nuked)]
            if g.x == x and g.y == y:
                nuking = True
            if nuking:
                self.remove(g)
                nuked += [g]
        return nuked

class BreadcrumbTrail (GuessList):
    def append (self, guess):
        # Raise an error if we add something to ourselves twice
        if self.guesses_for_coord(guess.x, guess.y):
            raise ValueError("We already have crumbs on %s, %s" % (guess.x, guess.y))
        else:
            list.append(self, guess)

class Guess:
    def __init__ (self, x, y, val):
        self.x = x
        self.y = y
        self.children = []
        self.val = val
        self.consequences = {}

    def add_consequence (self, x, y, val):
        self.consequences[(x, y)] = val

    def __repr__ (self):
        s =  "<Guess (%s, %s)=%s" % (self.x, self.y, self.val)
        if self.consequences:
            s +=   " implies: "
            s += ", ".join(["%s->%s" % (k, v) for k, v in self.consequences.items()])
        s += ">"
        return s


def add_with_diminishing_importance (lst, diminish_by = lambda x: x + 1):
    sum = 0
    for i, n in enumerate(lst):
        sum += float(n) / diminish_by(i)
    return sum

