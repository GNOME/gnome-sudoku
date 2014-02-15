# -*- coding: utf-8 -*-
from __future__ import print_function
import functools
import random
import math
import re
from gettext import gettext as _
from . import defaults

GROUP_SIZE = 9

TYPE_ROW = 0
TYPE_COLUMN = 1
TYPE_BOX = 2

digit_set = list(range(1, GROUP_SIZE + 1))
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

class ParallelDict (dict):
    """A handy new sort of dictionary for tracking conflicts.

    pd = ParallelDict()
    pd[1] = [2, 3, 4] # 1 is linked with 2, 3 and 4
    pd -> {1:[2, 3, 4], 2:[1], 3:[1], 4:[1]}
    pd[2] = [1, 3, 4] # 2 is linked with 3 and 4 as well as 1
    pd -> {1: [2, 3, 4], 2:[3, 4], 3:[1, 2], 4:[1, 2]}
    Now for the cool part...
    del pd[1]
    pd -> {2: [2, 3], 3:[2], 4:[2]}

    Pretty neat, no?
    """
    def __init__ (self, *args):
        dict.__init__(self, *args)

    def __setitem__ (self, k, v):
        dict.__setitem__(self, k, set(v))
        for i in v:
            if i == k:
                continue
            if i in self:
                self[i].add(k)
            else:
                dict.__setitem__(self, i, set([k]))

    def __delitem__ (self, k):
        v = self[k]
        dict.__delitem__(self, k)
        for i in v:
            if i == k:
                continue
            if i in self:
                # Make sure we have a reference to i. If we don't
                # something has gone wrong... but according to bug
                # 385937 this has gone wrong at least once, so we'd
                # better check for it.
                if k in self[i]:
                    self[i].remove(k)
                if not self[i]:
                    # If k was the last value in the list of values
                    # for i, then we delete i from our dictionary
                    dict.__delitem__(self, i)

class SudokuGrid(object):
    def __init__ (self, grid = False, verbose = False, group_size = 9):
        self.grid = []
        self.cols = []
        self.rows = []
        self.boxes = []
        self.conflicts = ParallelDict()
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
            if isinstance(grid, str):
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
                    print('Strange: problem with add(', x, y, val, force, ')')
                    import traceback
                    traceback.print_exc()
            else:
                #FIXME:  This is called when the fill button
                #is clicked multiple times, which causes this exception:
                #raise AlreadySetError
                return
        # Always store the value in the underlying grid
        self._set_(x, y, val)
        # But don't add it to the solution hints(rows/cols/boxes) if there is
        # a conflict
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

    def remove (self, x, y):
        val = self._get_(x, y)
        self.rows[y].discard(val)
        self.cols[x].discard(val)
        self.boxes[self.box_by_coords[(x, y)]].discard(val)
        self._set_(x, y, 0)

    def _get_ (self, x, y):
        return self.grid[y][x]

    def _set_ (self, x, y, val):
        self.grid[y][x] = val

    def possible_values (self, x, y):
        return self.gen_set - self.rows[y] - self.cols[x] - self.boxes[self.box_by_coords[(x, y)]]

    def pretty_print (self):
        print('SUDOKU')
        for r in self.grid:
            for i in r:
                print(i, end=' ')
            print()
        print()

    def populate_from_grid (self, grid):
        for y, row in enumerate(grid):
            for x, cell in enumerate(row):
                if cell:
                    try:
                        self.add(x, y, cell)
                    except ConflictError:
                        pass

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
        self.solving = False
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
            for n, coord_set in list(coord_dic.items()):
                skip_set = False
                for coord in coord_set:
                    if coord in self.conflicts:
                        skip_set = True
                        break
                if skip_set:
                    continue
                needs = dict([(n, False) for n in range(1, self.group_size + 1)])
                for coord in coord_set:
                    val = self._get_(*coord)
                    if val:
                        # We already have this value set...
                        if val in needs:
                            del needs[val]
                    else:
                        # Otherwise, register ourselves as possible
                        # for each number we could be
                        for v in self.possible_values(*coord):
                            # if we don't yet have a possible number, plug ourselves in
                            if v in needs:
                                if not needs[v]:
                                    needs[v] = coord
                                else:
                                    del needs[v]
                for n, coords in list(needs.items()):
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
        poss = list(self.calculate_open_squares().items())
        one_choice = [x for x in poss if len(x[1]) == 1]
        retval = []
        for coords, choices in one_choice:
            if self.verbose:
                print('Deterministically adding ', coords, choices)
            val = choices.pop()
            self.add(coords[0], coords[1], val)
            retval.append([(coords[0], coords[1]), val])
        if self.verbose:
            print('deterministically returning ', retval)
        return retval

    def solve (self):
        if self.solving:
            return
        self.solving = True
        self.auto_fill()
        while not self.guess_least_open_square():
            pass
        if self.verbose:
            print('Solved!\n', self)
        self.solving = False
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
        next(sf)
        if next(sf):
            return False
        else:
            return True

    def guess_least_open_square (self):
        # get open squares and check them
        poss = list(self.calculate_open_squares().items())
        # if there are no open squares, we're done!
        if not poss:
            if self.verbose:
                print('Solved!')
            return True
        # otherwise, find the possibility with the least possibilities
        poss.sort(key=functools.cmp_to_key(lambda a, b: len(a[1]) > len(b[1]) \
                                  and 1 or len(a[1]) < len(b[1]) and -1 or \
                                  a[0] > b[0] and 1 or a[1] < b[1] and -1 or 0))
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
        self.current_guess = None #reset (we're tracked via guess.get_child())
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
        if set([]) in list(self.calculate_open_squares().values()):
            self.trail.append('Guess leaves us with impossible squares.')
            self.unwrap_guess(guess_obj)
            return self.guess_least_open_square()

    def unwrap_guess (self, guess):
        self.trail.append(('-', guess))
        if self._get_(guess.x, guess.y):
            self.remove(guess.x, guess.y)
        for consequence in list(guess.consequences.keys()):
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
        self.cleared_conflicts = []

    def to_string (self):
        return self.virgin.to_string() + '\n' + SudokuSolver.to_string(self)

    def find_impossible_implications (self, x, y):
        """Return a set of impossibilities implied by the users actions."""
        row_cells = self.row_coords[y]
        col_cells = self.col_coords[x]
        box = self.box_by_coords[(x, y)]
        box_cells = self.box_coords[box]
        broken = set()
        for coord_set in [row_cells, col_cells, box_cells]:
            # just work on the open squares
            coord_set = [coords for coords in coord_set if not self._get_(*coords)]
            for coords in coord_set:
                if not self.possible_values(*coords):
                    broken.add(coords)
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

    def add (self, x, y, val, force = False):
        '''Add a value to the grid.

        The main feature of this method is conflict resolution.  When conflicts
        are found they are stored in the conflicts ParallelDict.  A cell that
        is in conflict is stored in the underlying grid(SudokuGrid.grid), but
        it has all of its solution hints cleared(SudokuGrid.rows/cols/boxes).
        Care must be taken so that solution hints from the original
        grid(SudokuSolver.virgin) are not cleared.
        '''
        # First just add it to SudokuGrid
        no_exception = True
        try:
            super(InteractiveSudoku, self).add(x, y, val, force)
        except ConflictError:
            no_exception = False

        # Find any cells that conflict with the new value for this cell
        coords = set([])
        coords.update(self.row_coords[y])
        coords.update(self.col_coords[x])
        coords.update(self.box_coords[self.box_by_coords[(x, y)]])
        coords.discard((x, y))
        conflicting_coordinates = []
        for xx, yy in coords:
            if self._get_(xx, yy) == val:
                conflicting_coordinates.append((xx, yy))
        # Store the conflicts for access
        if conflicting_coordinates:
            self.conflicts[(x, y)] = conflicting_coordinates
        # Resume when there are no conflicts
        else:
            return
        # But when we do have conflicts, the values from cols/rows/boxes need
        # to be removed so the hinting doesn't consider them. We must be
        # chaste with the virgin though.
        try:
            if no_exception and not self.virgin._get_(x, y):
                self.rows[y].discard(val)
                self.cols[x].discard(val)
                self.boxes[self.box_by_coords[(x, y)]].discard(val)
            for xx, yy in conflicting_coordinates:
                if self.virgin._get_(xx, yy):
                    continue
                if not val in self.virgin.rows[yy]:
                    self.rows[yy].discard(val)
                if not val in self.virgin.cols[xx]:
                    self.cols[xx].discard(val)
                if not val in self.virgin.box_coords[self.box_by_coords[(xx, yy)]]:
                    self.boxes[self.box_by_coords[(xx, yy)]].discard(val)
        # This class can be used before the virgin is created.  Pass through
        # for the initialization phase
        except AttributeError:
            pass

    def remove (self, x, y):
        '''Remove a value from the grid.

        The main feature of this method is conflict resolution.  All
        conflicting cells are checked to see if they are actually
        conflict-free.  A list of conflict-free cells are stored in
        InteractiveSudoku.cleared_conflicts.  The cleared_conflicts list is
        cleared for each meaningful call to remove(), so it must be processed
        before another remove() call.
        All solution hints(SudokuGrid.rows/cols/boxes) are reinstated for
        conflict-free cells.
        '''
        # Grab the value that we're clearing.  Skip out if its nothing
        val = self._get_(x, y)
        if not val:
            return
        # Pop the conflicts resolved by this removal
        self.cleared_conflicts = []
        errors_removed = []
        if (x, y) in self.conflicts:
            errors_removed = self.conflicts[(x, y)]
            del self.conflicts[(x, y)]
        # If there are no conflicts for this cell then just remove it in from
        # the grid
        else :
            super(InteractiveSudoku, self).remove(x, y)
            return
        # Grid clearance flags
        if val in self.rows[y]:
            clear_row = True
        else:
            clear_row = False
        if val in self.cols[x]:
            clear_col = True
        else:
            clear_col = False
        if val in self.boxes[self.box_by_coords[(x, y)]]:
            clear_box = True
        else:
            clear_box = False
        # Scroll through the conflicts
        for coord in errors_removed:
            # If it is not an error by some other pairing, append it to a list
            # of conflicts that were actually cleared by this removal.
            if coord not in self.conflicts:
                self.cleared_conflicts.append(coord)
            # When a conflict remains, we need to correct the rows, cols, and
            # boxes arrays properly
            else:
                if clear_row and coord in self.row_coords[y]:
                    clear_row = False
                if clear_col and coord in self.col_coords[x]:
                    clear_col = False
                if clear_box and coord in self.box_coords[self.box_by_coords[(x, y)]]:
                    clear_box = False

        # Clear the rows, cols, and boxes if we need to.
        if clear_row:
            self.rows[y].remove(val)
        if clear_col:
            self.cols[x].remove(val)
        if clear_box:
            self.boxes[self.box_by_coords[(x, y)]].remove(val)
        # Clear the cell
        self._set_(x, y, 0)

        # Scroll through the cleared conflicts and commit them to ensure they
        # are represented in the grid properly.  It is possible for add() to do
        # subsequent remove()s, so hold onto the cleared conflict list for the
        # caller.
        hold_conflicts = self.cleared_conflicts
        for xx, yy in self.cleared_conflicts:
            self.add(xx, yy, val, True)
        self.cleared_conflicts = hold_conflicts


class DifficultyRating:
    very_hard_range = (0.75, 10)
    hard_range = (0.6, 0.75)
    medium_range = (0.45, 0.6)
    easy_range = (-10, 0.45)

    categories = {'very hard':very_hard_range,
                  'hard':hard_range,
                  'medium':medium_range,
                  'easy':easy_range}

    ordered_categories = ['easy', 'medium', 'hard', 'very hard']

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
        kk = list(dct.keys())
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
            print(name, ': ', stat)

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

def get_difficulty_category (diff_float):
    for category, range in list(DifficultyRating.categories.items()):
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
        list(map(lambda r: [setattr(self, 'clues', self.clues.__add__(i and 1 or 0)) for i in r],
            self.virgin.grid))
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
        return set([guess.val for guess in [guess for guess in self if guess.x == x and guess.y == y]])

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
            s += ", ".join(["%s->%s" % (k, v) for k, v in list(self.consequences.items())])
        s += ">"
        return s


def add_with_diminishing_importance (lst, diminish_by = lambda x: x + 1):
    sum = 0
    for i, n in enumerate(lst):
        sum += float(n) / diminish_by(i)
    return sum

