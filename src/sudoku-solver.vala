/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gee;

protected errordomain SudokuError {
    UNSOLVABLE_PUZZLE,
    CONFLICT_ERROR,
    ALREADY_SET_ERROR
}

public class SudokuSolver
{
    protected SudokuBoard board;

    private ParallelDict conflicts;
    protected GuessList guesses;
    public BreadcrumbTrail breadcrumbs;
    protected int backtraces = 0;
    private Guess current_guess;

    private bool count_solutions = false;
    private int break_at = 100;

    private ArrayList<Guess> trail = new ArrayList<Guess> ();
    private ArrayList<string> trailDetails = new ArrayList<string> ();

    private int debug_indent = 0;

    protected bool solved;

    public SudokuSolver (ref SudokuBoard board)
    {
        this.board = board;
        this.conflicts = new ParallelDict();
        this.guesses = new GuessList();
        this.breadcrumbs = new BreadcrumbTrail();
        this.solved = false;
    }

    /* Check if current SudokuBoard has at least one solution or not */
    public bool quick_has_solution ()
    {
        int solutions = 0;
        count_solutions = false;
        quick_solve (-1, -1, -1, -1, ref solutions);
        return (solutions > 0);
    }

    public bool quick_has_unique_solution ()
    /*Check if current SudokuBoard has unique solution or not*/
    {
        int solutions = 0;
        count_solutions = false;
        quick_solve (-1, -1, -1, -1, ref solutions);
        return (solutions == 1);
    }

    /* Check if current SudokuBoard has more than one solution or not */
    public bool quick_has_many_solution ()
    {
        int solutions = 0;
        count_solutions = false;
        quick_solve (-1, -1, -1, -1, ref solutions);
        return (solutions > 1);
    }

    /* Check if current SudokuBoard has more than one solution or not */
    public int quick_count_solutions (int break_at = 100)
    {
        int solutions = 0;
        count_solutions = true;
        this.break_at = break_at;
        quick_solve (-1, -1, -1, -1, ref solutions);
        return solutions;
    }

    private void quick_solve (int row, int col, int no, int filled, ref int solution)
    {
        if (filled == -1)
            filled = board.filled;

        if (filled == board.rows * board.cols)
        {
            solution++;
            return;
        }

        if (row == -1 || col == -1)
        {
            for (var l1 = 0; l1 < board.rows; l1++)
            {
                for (var l2 = 0;l2 < board.cols; l2++)
                {
                    if (board[l1, l2] == 0)
                    {
                        quick_solve (l1, l2, no, filled, ref solution);
                        return;
                    }
                }
            }
        }

        if (no == -1)
        {
            for (var l1 = 1; l1 <= board.max_val; l1++)
            {
                if (board.is_possible (row, col, l1))
                {
                    quick_solve (row, col, l1, filled, ref solution);
                    /* Break at solutions == 2 as we don't need exact count of possible solutions */
                    if ((!count_solutions && solution > 1) || (solution > break_at))
                        return;
                }
            }
            return;
        }

        board.insert (row, col, no);
        quick_solve (-1, -1, -1, filled + 1, ref solution);
        board.remove (row, col);
    }



    public Iterator iterator ()
    {
        return new Iterator(this);
    }

    public bool has_unique_solution ()
    {
        Iterator sf = iterator ();

        if (sf.next() == true && sf.next() == false)
            return true;
        else
            return false;
    }

    public class Iterator {
        private SudokuSolver solver;
        private SudokuBoard solution;

        public Iterator(SudokuSolver solver) {
            this.solver = solver;
        }

        public bool next() {
            if (!solver.solved)
            {
                solver.auto_fill ();
                try
                {
                    while (!solver.guess_least_open_square());
                }
                catch (SudokuError e)
                {
                    solution = null;
                    return false;
                }

                solver.solved = true;
                solution = solver.board;

                return true;
            } else {
                while (solver.breadcrumbs.size != 0)
                {
                    solver.unwrap_guess(solver.breadcrumbs[solver.breadcrumbs.size -1]);
                    try
                    {
                        while (!solver.guess_least_open_square());
                    }
                    catch (SudokuError e)
                    {
                        solution = null;
                        return false;
                    }
                    solution = solver.board;
                    return true;
                }

                return false;
            }
        }

        public SudokuBoard? get() {
            return solution;
        }
    }

    /*
     * Fills the board looking at the possibilities, then starts guessing using guess_least_open_square
     */
    public SudokuBoard solve () {
        auto_fill();
        try {
           while (!guess_least_open_square());
        } catch (SudokuError e) {

        }
        solved = true;
        return board;
    }

    /*
     * This method uses fill_must_fills, then fill_deterministically to fill the board
     */
    private ArrayList<Cell?> auto_fill () {
        ArrayList<Cell?> changed = new ArrayList<Cell?> ();
        try {
            changed.add_all (fill_must_fills ());
        } catch ( SudokuError e ) {
            return changed;
        }
        changed.add_all (fill_deterministically ());
        return changed;
    }

    /*
     * This method looks at each cell on the board, and if it has one possible value, inserts it
     */
    protected ArrayList<Cell?> fill_deterministically () {
        HashMap<Coord?, ArrayList<int>> poss = board.calculate_open_squares ();

        ArrayList<Cell?> changed = new ArrayList<Cell?> ();
        foreach (Coord coord in poss.keys) {
            ArrayList<int> choices = poss[coord];

            if (choices.size != 1)
                continue;

            int val = choices[0];

            insert (coord.row, coord.col, val);
            changed.add ( Cell(coord, val));
        }
        return changed;
    }

    /*
     * This method looks at each set of cells on the board, and then calls fill_must_fills_for on them, it returns the changes it has made as an array
     */
    protected ArrayList<Cell?> fill_must_fills () throws SudokuError {
        ArrayList<Cell?> changed = new ArrayList<Cell?> ();

        for (int col = 0; col < board.cols; col++) {
            changed.add_all(fill_must_fills_for(board.coords_for_col.get(col)));
        }

        for (int row = 0; row < board.rows; row++) {
            changed.add_all(fill_must_fills_for(board.coords_for_row.get (row)));
        }

        int blocks_across = board.cols / board.block_cols;
        int blocks_down = board.rows / board.block_rows;

        for (int block_down = 0; block_down < blocks_down; block_down++) {
            for (int block_across = 0; block_across < blocks_across; block_across++) {
                changed.add_all(fill_must_fills_for(board.coords_for_block.get (Coord(block_across, block_down))));
            }
        }
        return changed;
    }

    /*
     * This method looks at the list of coords its been given, it returns the changes it has made as an array
     */
    private ArrayList<Cell?> fill_must_fills_for (Gee.List<Coord?> coords) throws SudokuError {
        bool skip_set = false;
        foreach (Coord coord in coords) {
            if (conflicts.contains(coord)) {
                skip_set = true;
                break;
            }
        }

        if (skip_set)
            return new ArrayList<Cell?> ();

        // This list holds the changes that are made to the board
        ArrayList<Cell?> changed = new ArrayList<Cell?> ((EqualDataFunc<Coord>) Coord.equal);

        // Maps the number needed to a cell that can hold it
        var needs = new HashMap<int, Coord?> (null, null, (EqualDataFunc<Coord>) Coord.equal);
        for (int i=1; i <= board.max_val; i++)
            needs[i] = null;

        // Look at each of the coords in the list
        foreach (Coord coord in coords) {

            int val = board[coord.row, coord.col];
            if (val != 0) { // If it contains a value
                if (needs.has_key(val)) { // If the value that it contains is still down as being needed
                    needs.unset(val); // Remove it
                }
            } else { // If its empty
                // Find out what can go in it
                int[] possibilities = board.get_possibilities(coord.row, coord.col);

                // For each value it can hold
                foreach (int possibility in possibilities) {
                    // If its needed
                    if (needs.has_key(possibility)) {
                        if (needs[possibility] == null) { // If it has no candidate, put the current coord in
                            needs[possibility] = coord;
                        } else { // Else, as this value can go in two cells (either coord or needs[possibility]),
                                 // we cant deal with it, so remove it
                            needs.unset(possibility);
                        }
                    }
                }
            }
        }

        if (needs.size != 0) { // If this block needs any values
            foreach (int n in needs.keys) { // Foreach value n, that this block needs
                if (needs[n] == null) { // If n is needed, but there is no candidate, panic?!?
                    //stdout.printf("but its null, oh noes\n");
                    throw new SudokuError.UNSOLVABLE_PUZZLE("Missing a %d in\n", n);
                }
                else
                {
                    int val = board[needs[n].row, needs[n].col]; // Get the value currently in the cell
                    // FIXME: Not sure why the val == n is here, the python code is a bit flakey with the exceptions in add here...
                    if (val == 0 || val == n) { // If this cell is empty
                        insert(needs[n].row, needs[n].col, n); // Insert the value
                        changed.add (Cell(needs[n], n));
                    } else { // Else, we need val in here, but its already occupied?!?
                        //stdout.printf("%d, %d must be two values at once! %d and %d\n", needs[n].col, needs[n].row, val, n);
                        throw new SudokuError.UNSOLVABLE_PUZZLE("%d, %d must be two values at once! %d and %d", needs[n].col, needs[n].row, val, n);
                    }
                }
            }
        }

        return changed;
    }

    /*
     * Guesses the least open cell (cell with the smallest number of possibilitites) on the board.
     * It returns true if there are no open squares, or false ...
     */
    protected virtual bool guess_least_open_square () throws SudokuError
    {
        HashMap<Coord?, ArrayList<int>> poss = board.calculate_open_squares ();

        // if there are no open squares, we're done!
        if (poss.keys.size == 0) {
            return true;
        }

        // Find the square with the least possibilties
        MapIterator<Coord?, ArrayList<int>> iter = poss.map_iterator ();

        iter.next ();
        Coord least_coord = iter.get_key ();
        ArrayList<int> least_coord_possibilties = iter.get_value ();

        foreach (Coord coord in poss.keys) {
            if (poss[coord].size > least_coord_possibilties.size)
            {
                continue;
            }
            else if (poss[coord].size < least_coord_possibilties.size)
            {
                least_coord = coord;
                least_coord_possibilties = poss[coord];
            }
            else if (coord.col < least_coord.col)
            {
                least_coord = coord;
                least_coord_possibilties = poss[coord];
            }
            else if (coord.col == least_coord.col && coord.row < least_coord.row)
            {
                least_coord = coord;
                least_coord_possibilties = poss[coord];
            }
        }

        ArrayList<int> possible_values = new ArrayList<int> ();
        Guess[] guesses_for_coord = guesses.guesses_for (least_coord.row, least_coord.col);

        // Remove all possibilties already guessed
        foreach (int possibility in least_coord_possibilties)
        {
            bool found = false;
            foreach (Guess guess in guesses_for_coord)
            {
                if (guess.val == possibility)
                {
                    found = true;
                    break;
                }
            }
            if (!found)
                possible_values.add (possibility);
        }

        if (possible_values.size == 0)
        {
            if (breadcrumbs.size != 0)
            {
                backtraces += 1;
                unwrap_guess( breadcrumbs.get (breadcrumbs.size - 1) );
                debug_indent++;
                return guess_least_open_square();
            }
            else
            {
                throw new SudokuError.UNSOLVABLE_PUZZLE ("Unsolvable");
            }
        }

        // Pick a random number to guess (from the list of possible numbers)
        int guess = possible_values.get (Random.int_range (0, possible_values.size));

        Guess guess_obj = new Guess(least_coord.row, least_coord.col, guess);

        if (breadcrumbs.size != 0) {
            breadcrumbs.get (breadcrumbs.size -1).children.add (guess_obj);
        }

        current_guess = null; // reset (we're tracked via guess.get_child())

        insert (least_coord.row, least_coord.col, guess);
        current_guess = guess_obj; // (All deterministic additions
                                   // get added to our
                                   // consequences)
        guesses.add (guess_obj);

        trail.add (guess_obj);
        trailDetails.add ("+");

        breadcrumbs.add (guess_obj);
        ArrayList<Cell?> fills = auto_fill ();

        bool contains_empty = false;

        Collection<ArrayList<int>> possibilties_left = board.calculate_open_squares().values;
        foreach (ArrayList<int> i in possibilties_left) {
            if (i.size == 0)
                contains_empty = true;
        }

        if (contains_empty) {
            trailDetails.add ("Guess leaves us with impossible squares.");
            unwrap_guess (guess_obj);
            debug_indent++;
            return guess_least_open_square();
        }

        return false;
    }

    private void unwrap_guess (Guess guess)
    {
        trail.add (guess);
        trailDetails.add ("-");

        if (board[guess.row, guess.col] != 0) {
            board.remove (guess.row, guess.col);
        }
        foreach (Coord coord in guess.consequences.keys) {
            if (board[coord.row, coord.col] != 0) {
                board.remove (coord.row, coord.col);
            }
        }

        foreach (Guess child in guess.children) {
            unwrap_guess (child);
            if (child in guesses)
                guesses.remove (child);
        }

        if (guess in breadcrumbs) {
            breadcrumbs.remove (guess);
        }
    }

    protected virtual void insert (int row, int col, int val)
    {
        if (current_guess != null)
            current_guess.add_consequence(row, col, val);
        board.insert (row, col, val);
    }
}

class SudokuRater : SudokuSolver {

    private bool guessing;
    private bool fake_add;
    private ArrayList<Cell?> fake_additions;
    private ArrayList<Cell?> add_me_queue;
    private HashSet<Cell?> filled;
    private HashMap<int, HashSet<Cell?>> fill_must_fillables;
    private HashMap<int, HashSet<Cell?>> elimination_fillables;
    private int tier;

    public SudokuRater (ref SudokuBoard board) {
        base(ref board);
        guessing = false;
        fake_add = false;
        fake_additions = new ArrayList<Cell?> ();
        filled = new HashSet<Cell?> ((HashDataFunc<Coord>) Cell.hash, (EqualDataFunc<Coord>) Cell.equal);
        fill_must_fillables = new HashMap<int, HashSet<Cell?>> ();
        elimination_fillables = new HashMap<int, HashSet<Cell?>> ();
        tier = 0;
    }

    protected override void insert (int row, int col, int val)
    {
        if (!fake_add) {
            if (!guessing) {
                scan_fillables();
                foreach (Cell delayed_cell in add_me_queue)
                {
                    if (board[delayed_cell.coord.row, delayed_cell.coord.col] == 0) {
                        base.insert(delayed_cell.coord.row, delayed_cell.coord.col, delayed_cell.val);
                    }
                }
                if (board[row, col] == 0)
                    base.insert(row, col, val);
                tier += 1;
            }
            else
            {
                base.insert(row, col, val);
            }
        }
        else
        {
            fake_additions.add (Cell(Coord(row, col), val));
        }
    }

    private void scan_fillables () {
        fake_add = true;
        // this will now tell us how many squares at current
        // difficulty could be filled at this moment.
        fake_additions = new ArrayList<Cell?> ();
        try {
            fill_must_fills();
        } catch (SudokuError e) {
        }
        fill_must_fillables[tier] = new HashSet<Cell?> ((HashDataFunc<Coord>) Cell.hash, (EqualDataFunc<Coord>) Cell.equal);
        foreach (Cell cell in fake_additions) {
            if (!filled.contains(cell))
                fill_must_fillables[tier].add (cell);
        }

        add_me_queue = fake_additions;
        fake_additions = new ArrayList<Cell?> ();

        try {
            fill_deterministically();
        } catch (SudokuError e) {
        }

        elimination_fillables[tier] = new HashSet<Cell?> ((HashDataFunc<Coord>) Cell.hash, (EqualDataFunc<Coord>) Cell.equal);
        foreach (Cell cell in fake_additions) {
            if (!filled.contains(cell))
                elimination_fillables[tier].add (cell);
        }

        filled.add_all(fill_must_fillables[tier]);
        filled.add_all(elimination_fillables[tier]);

        add_me_queue.add_all(fake_additions);
        fake_add = false;
    }

    protected override bool guess_least_open_square () throws SudokuError
    {
        guessing = true;
        return base.guess_least_open_square();
    }

    public DifficultyRating get_difficulty () {
        if (!solved)
            solve();
        int clues = 0;
        for (int row = 0; row<board.rows; row++)
            for (int col = 0; col<board.cols; col++)
                if (board.is_fixed[row,col])
                    clues++;

        int numbers_added = (board.rows * board.cols) - clues;

        DifficultyRating rating = new DifficultyRating(fill_must_fillables,
                                                   elimination_fillables,
                                                   guesses,
                                                   backtraces,
                                                   numbers_added);
        return rating;
    }

    public static void gen_python_test () {
        stdout.printf("import sudoku\n\n");

        for (int repeat = 0; repeat < 20; repeat++)
        {
            SudokuGenerator gen = new SudokuGenerator();
            gen.clues = Random.int_range(17, 60);

            SudokuBoard board = gen.make_symmetric_puzzle (Random.int_range(0, 4));

            stdout.printf("diff = sudoku.SudokuRater(");
            board.get_string ();
            stdout.printf(").difficulty()\n");

            SudokuRater rater = new SudokuRater(ref board);
            DifficultyRating diff = rater.get_difficulty ();

            stdout.printf("print diff.value, %f\n\n", diff.rating);
        }
    }
}

public class Guess {
    private int _row;
    public int row
    {
        get { return _row; }
    }

    private int _col;
    public int col
    {
        get { return _col; }
    }

    private int _val;
    public int val
    {
        get { return _val; }
    }

    public ArrayList<Guess> children;

    public HashMap<Coord?, int> consequences;

    public Guess(int row, int col, int val) {
        _row = row;
        _col = col;
        _val = val;
        consequences = new HashMap<Coord?, int> ((HashDataFunc<Coord>) Coord.hash, (EqualDataFunc<Coord>) Coord.equal);
        children = new ArrayList<Guess> ();
    }

    public void add_consequence (int row, int col, int val)
    {
        consequences.set (Coord(row, col), val);
    }
}

public class GuessList : ArrayList<Guess> {

    public Guess[] guesses_for (int row, int col) {
        Guess[] guesses = {};

        foreach (Guess guess in this) {
            if (guess.row == row && guess.col == col) {
                guesses += guess;
            }
        }

        return guesses;
    }

    public Guess[] remove_children (Guess guess) {
        Guess[] removed = {};

        foreach (Guess g in guess.children) {
            if (this.contains(g)) {
                removed += g;
                this.remove(g);
            }
        }

        return removed;
    }

    public Guess[] remove_guesses_for ( int row, int col) {
        Guess[] removed = {};

        foreach (Guess guess in this) {
            if (guess.row == row && guess.col == col) {
                removed += guess;
                this.remove(guess);
            }
        }

        return removed;
    }
}

public class BreadcrumbTrail : GuessList {

    public new void append(Guess guess) {
        if (guesses_for(guess.row, guess.col).length != 0) {
            // "We already have crumbs on %s, %s" % (guess.x, guess.y))
        } else {
            add(guess);
        }
    }
}

public class ParallelDict {
    private HashMap<Coord?, HashSet<Coord?>> map = new HashMap<Coord?, HashSet<Coord?>> ();

    public void set (Coord k, HashSet<Coord?> v)
    {
        map.set (k, v);
        foreach (Coord i in v)
        {
            if (i == k)
                continue;
            if (map.has_key(i)) {
                map[k].add (i);
            } else {
                HashSet<Coord?> kSet = new HashSet<Coord?> ();
                kSet.add (k);
                map.set (i, kSet);
            }
        }
    }

    public void unset (Coord k)
    {
        HashSet<Coord?> v = map[k];
        map.unset (k);
        foreach (Coord i in v)
        {
            if (i == k)
                continue;
            if (map.has_key(i))
            {
                if (k in map[i])
                    map[i].remove(k);
                if (map[i].size == 0)
                    map.unset (i);
                    // If k was the last value in the list of values
                    // for i, then we delete i from our dictionary
            }
        }
    }

    public bool contains (Coord key)
    {
        return map.has_key (key);
    }
}

public enum DifficultyCatagory {
    EASY,
    MEDIUM,
    HARD,
    VERY_HARD;

    public string to_string ()
    {
        switch (this)
        {
            case EASY:
                return _("Easy");
            case MEDIUM:
                return _("Medium");
            case HARD:
                return _("Hard");
            case VERY_HARD:
                return _("Very Hard");
            default:
                return _("Undefined");
        }
    }
}

public class DifficultyRating {

    public const float[] VERY_HARD_RANGE = { 0.75f, 10 };
    public const float[] HARD_RANGE = { 0.6f, 0.75f };
    public const float[] MEDIUM_RANGE = { 0.45f, 0.6f };
    public const float[] EASY_RANGE = { -10, 0.45f };

    HashMap<int, HashSet<Cell?>> fill_must_fillables;
    HashMap<int, HashSet<Cell?>> elimination_fillables;
    GuessList guesses;
    int backtraces;
    int squares_filled;

    float elimination_ease;
    float fillable_ease;

    float instant_fill_fillable;
    float instant_elimination_fillable;
    float proportion_instant_elimination_fillable;
    float proportion_instant_fill_fillable;

    public float rating;

    public DifficultyRating (HashMap<int, HashSet<Cell?>> fill_must_fillables, HashMap<int, HashSet<Cell?>> elimination_fillables, GuessList guesses, int backtraces, int squares_filled  )
    {
        this.fill_must_fillables = fill_must_fillables;
        this.elimination_fillables = elimination_fillables;

        this.guesses = guesses;
        this.backtraces = backtraces;
        this.squares_filled = squares_filled;

        if (fill_must_fillables.size != 0)
            instant_fill_fillable = (float) fill_must_fillables[0].size;
        else
            instant_fill_fillable = 0.0f;

        if (elimination_fillables.size != 0)
            instant_elimination_fillable = (float) elimination_fillables[0].size;
        else
            instant_elimination_fillable = 0.0f;

        proportion_instant_elimination_fillable = instant_elimination_fillable / squares_filled;
        // some more numbers that may be crazy...
        proportion_instant_fill_fillable = instant_fill_fillable / squares_filled;
        elimination_ease = add_with_diminishing_importance(count_values(elimination_fillables));
        fillable_ease = add_with_diminishing_importance(count_values(fill_must_fillables));
        rating = calculate();
    }

    private int[] count_values (HashMap<int, HashSet<Cell?>> map) {
        TreeMap<int, HashSet<Cell?>> sortedMap = new TreeMap<int, HashSet<Cell?>> ();
        foreach (int key in map.keys) {
            sortedMap[key] = map[key];
        }
        int[] array = new int[map.size];
        int p = 0;
        foreach (int i in sortedMap.keys) {
            array[p] = sortedMap[i].size;
            p++;
        }
        return array;
    }

    private float calculate () {
        return 1 - (((float)fillable_ease) / squares_filled) - (((float)elimination_ease / squares_filled)) + (guesses.size / squares_filled) + (backtraces / squares_filled);
    }

    delegate int DiminshBy(int a);

    private static int diminsh_by_one (int a) {
        return a + 1;
    }

    public bool in_range (float[] range) {
        return rating >= range[0] && rating < range[1];
    }

    public DifficultyCatagory get_catagory ()
    {
        if (in_range(EASY_RANGE))
            return DifficultyCatagory.EASY;
        else if (in_range(MEDIUM_RANGE))
            return DifficultyCatagory.MEDIUM;
        else if (in_range(HARD_RANGE))
            return DifficultyCatagory.HARD;
        else if (in_range(VERY_HARD_RANGE))
            return DifficultyCatagory.VERY_HARD;
        else
            assert_not_reached();
    }

    static float add_with_diminishing_importance (int[] array, DiminshBy diminish_by = diminsh_by_one) {
        float sum = 0;
        for (int i = 0; i < array.length; i++)
        {
            sum += ((float) array[i]) / diminish_by(i);
        }
        return sum;
    }

    public string to_string () {
        string result = "";
        result += "Number of moves instantly fillable by elimination: %f\n".printf (instant_elimination_fillable);
        result += "Percentage of moves instantly fillable by elimination: %f\n".printf (proportion_instant_elimination_fillable * 100);
        result += "Number of moves instantly fillable by filling: %f\n".printf (instant_fill_fillable);
        result += "Percentage of moves instantly fillable by filling: %f\n".printf (proportion_instant_fill_fillable * 100);
        result += "Number of guesses made: %d\n".printf (guesses.size);
        result += "Number of backtraces: %d\n".printf (backtraces);
        result += "Ease by filling: %f\n".printf (fillable_ease);
        result += "Ease by elimination: %f\n".printf (elimination_ease);
        result += "Calculated difficulty: %f".printf (rating);
        return result;
    }
}
