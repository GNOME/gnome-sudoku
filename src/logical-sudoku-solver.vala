using Gee;

/**
 * Lots of information about this comes from http://www.sudopedia.org/
 */
class LogicalSudokuSolver
{
    private SudokuBoard board;

    public ArrayList<Cell?> naked_singles = new ArrayList<Cell?> ();
    public ArrayList<HiddenSingle?> hidden_singles = new ArrayList<HiddenSingle?> ();
    public ArrayList<Subset?> naked_subsets = new ArrayList<Subset?> ();
    public ArrayList<Subset?> hidden_subsets = new ArrayList<Subset?> ();

    /**
     * An array of coordinates, row_possibilities[1, 1] is the
     * list of places where 1 can go in this row.
     */
    private ArrayList<Coord?>[,] row_possibilities;

    /**
     * An array of coordinates, row_possibilities[1, 1] is the
     * list of places where 1 can go in this row.
     */
    private ArrayList<Coord?>[,] col_possibilities;

    /**
     * An array of coordinates, row_possibilities[1, 1] is the
     * list of places where 1 can go in this row.
     */
    private Map<Coord?, ArrayList<ArrayList<Coord?>>> block_possibilities;

    HashMap<Coord?, ArrayList<int>> open_squares;

    public LogicalSudokuSolver (ref SudokuBoard board)
    {
        this.board = board;

        // Get the open squares, along with the possibilities for these squares
        open_squares = board.calculate_open_squares ();

        fill_possibility_arrays ();

        // Interate over them
        foreach (Coord? open_square in open_squares.keys) {

            // If there is only one candidate left, this is a naked single
            if (open_squares[open_square].size == 1)
            {
                naked_singles.add(Cell(open_square, open_squares[open_square].get(0)));
                continue;
            }

            // For each possibility in the square
            foreach (var possibility in open_squares[open_square]) {
                bool unique_in_row = row_possibilities[open_square.row, possibility].size == 1;
                bool unique_in_col = col_possibilities[open_square.col, possibility].size == 1;
                bool unique_in_block = block_possibilities[board.get_block_for(open_square.row, open_square.col)][possibility].size == 1;

                if (unique_in_row || unique_in_col || unique_in_block) {
                    hidden_singles.add (HiddenSingle(Cell(open_square, possibility), unique_in_row, unique_in_col, unique_in_block));
                    continue;
                }
            }
        }
    }

    private void fill_possibility_arrays () {
        row_possibilities = new ArrayList<Coord?>[board.rows, board.max_val + 1];
        col_possibilities = new ArrayList<Coord?>[board.cols, board.max_val + 1];
        block_possibilities = new HashMap<Coord?, ArrayList<ArrayList<Coord?>>> ((GLib.HashFunc) Coord.hash, (GLib.EqualFunc) Coord.equal);

        for (int row = 0; row < board.rows; row++) {
            for (int col = 0; col < board.cols; col++) {
                for (int val = 1; val <= board.max_val; val++) {
                    row_possibilities[row, val] = new ArrayList<Coord?> ();
                    col_possibilities[col, val] = new ArrayList<Coord?> ();
                }
            }
        }

        for (int row = 0; row < board.block_rows; row++) {
            for (int col = 0; col < board.block_cols; col++) {
                block_possibilities[Coord(row, col)] = new ArrayList<ArrayList<Coord?>> ();
                block_possibilities[Coord(row, col)].add(null);
                for (int val = 1; val <= board.max_val; val++) {
                    block_possibilities[Coord(row, col)].add(new ArrayList<Coord?> ());
                }
            }
        }

        foreach (Coord? open_square in open_squares.keys) {
            foreach (int val in open_squares[open_square]) {
                row_possibilities[open_square.row, val].add(open_square);
                col_possibilities[open_square.col, val].add(open_square);
                block_possibilities[board.get_block_for(open_square.row, open_square.col)][val].add(open_square);
            }
        }
    }

    /**
     * Returns all subsets, with 2 or more elements
     */
    private Set<Set<int>> powerset(ArrayList<int> elements) {
        HashSet<HashSet<int>> powerset = new HashSet<HashSet<int>> ();
        uint subset_count = 1 << elements.size;

        // Start at 3, because 0, 1 and 2 will be subsets smaller than 2
        for (uint subset = 3; subset < subset_count; subset++) {
            HashSet<int> one_set = new HashSet<int> ();

            var element = 0;
            for (var bits = subset; bits != 0; bits >>= 1) {
                if ((bits & 1) != 0)
                    one_set.add(elements[element]);
                element++;
            }

            if (one_set.size > 1)
                powerset.add(one_set);
        }

        return powerset;
    }

    public ArrayList<Subset?> get_naked_subsets ()
    {
        HashMap<Coord?, ArrayList<int>> open_squares = board.calculate_open_squares ();

        for (int col = 0; col < board.cols; col++) {
            get_naked_subsets_in (board.coords_for_col[col], House.COLUMN, open_squares);
        }

        for (int row = 0; row < board.rows; row++) {
            get_naked_subsets_in (board.coords_for_row[row], House.ROW, open_squares);
        }

        int blocks_across = board.cols / board.block_cols;
        int blocks_down = board.rows / board.block_rows;

        for (int block_down = 0; block_down < blocks_down; block_down++) {
            for (int block_across = 0; block_across < blocks_across; block_across++) {
                get_naked_subsets_in (board.coords_for_block[Coord(block_across, block_down)], House.BLOCK, open_squares);
            }
        }

        return naked_subsets;
    }

    private void get_naked_subsets_in (Gee.List<Coord?> coords, House house, HashMap<Coord?, ArrayList<int>> open_squares)
    {
        // Try starting a subset from each coord in the list given
        foreach (Coord initial_coord in coords)
        {
            // Skip if it has a value, or has less than 2 possibilites
            if (open_squares[initial_coord] == null || open_squares[initial_coord].size < 2)
                continue;

            ArrayList<Coord?> subset_coords = new ArrayList<Coord?> ((GLib.EqualFunc) Coord.equal);
            subset_coords.add (initial_coord);

            int subset_size = open_squares[initial_coord].size;

            foreach (Coord coord in coords)
            {
                if (open_squares[coord] == null || open_squares[coord].size != subset_size || (coord == initial_coord))
                    continue;

                // If the possibilites for coord, and initial_coord are the same
                if (open_squares[initial_coord].contains_all(open_squares[coord]) && open_squares[coord].contains_all(open_squares[initial_coord]))
                {
                    subset_coords.add (coord);
                }

                // If this subset is complete
                if (subset_coords.size == subset_size)
                {
                    ArrayList<Cell?> eliminated_possibilities = get_eliminated_possibilities(coords, subset_coords, open_squares);

                    bool equivilent_subset_found = false;
                    foreach (Subset subset in naked_subsets) {
                        if (subset_coords.contains_all(subset.coords) && subset.coords.contains_all(subset_coords)) {
                            subset.eliminated_possibilities.add_all(eliminated_possibilities);
                            equivilent_subset_found = true;
                            break;
                        }
                    }

                    if (!equivilent_subset_found) {
                        naked_subsets.add(Subset(open_squares[initial_coord], subset_coords, eliminated_possibilities));
                    }

                    break;
                }
            }
        }
    }

    /*
     *
     */
    private ArrayList<Cell?> get_eliminated_possibilities(Gee.List<Coord?> coords, ArrayList<Coord?> filled_coords, HashMap<Coord?, ArrayList<int>> open_squares)
    {
        ArrayList<Cell?> eliminated_possibilities = new ArrayList<Cell?> ();
        ArrayList<int> possibilities_eliminated = new ArrayList<int> ();

        // Work out what numbers would be eliminated from this house if the filled_coords are filled
        foreach (Coord filled_coord in filled_coords)
        {
            possibilities_eliminated.add_all(open_squares[filled_coord]);
        }

        // For each coord in the house
        foreach (Coord coord in coords)
        {
            // Skip if its one of the ones we are filling, or already filled
            if (filled_coords.contains(coord) || open_squares[coord] == null)
                continue;

            // For each possibility in the cell
            foreach (int possibility in open_squares[coord])
            {
                // If its one that we are eliminating, add it
                if (possibilities_eliminated.contains(possibility))
                    eliminated_possibilities.add(Cell(coord, possibility));
            }
        }

        return eliminated_possibilities;
    }


}

/*
 * A subset describes a set of techniques use to eliminate possibilities from cells
 * The coords list contains the coords that are part of the subset
 *
 *
 */
public struct Subset
{
    public ArrayList<int> values;
    public ArrayList<Coord?> coords;
    public ArrayList<Cell?> eliminated_possibilities;

    public Subset (ArrayList<int> values, ArrayList<Coord?> coords, ArrayList<Cell?> eliminated_possibilities)
    {
        this.values = values;
        this.coords = coords;
        this.eliminated_possibilities = eliminated_possibilities;
    }
}

/**
 * Used to describe the presence of a hidden single.
 *
 * The cell denotes the position and value, the row, column and block
 * denote the houses which this value is the single candidate in.
 */
public struct HiddenSingle
{
    public Cell cell;
    public bool row;
    public bool col;
    public bool block;

    public HiddenSingle (Cell cell, bool row, bool col, bool block)
    {
        this.cell = cell;
        this.row = row;
        this.col = col;
        this.block = block;
    }
}
