using Gee;

/**
 * Lots of information about this comes from http://www.sudopedia.org/
 */
class LogicalSudokuSolver
{
    private SudokuBoard board;

    public LogicalSudokuSolver (ref SudokuBoard board)
    {
        this.board = board;
    }

    /**
     * Returns cells where there is only one remaining candidate for the cell
     */
    public ArrayList<Cell?> get_naked_singles ()
    {
        ArrayList<Cell?> naked_singles = new ArrayList<Cell?> ();
        HashMap<Coord?, ArrayList<int>> open_squares = board.calculate_open_squares ();

        foreach (Coord coord in open_squares.keys)
        {
            if (open_squares[coord].size == 1)
            {
                naked_singles.add(Cell(coord, open_squares[coord].get(0)));
            }
        }

        return naked_singles;
    }

    public ArrayList<HiddenSingle?> get_hidden_singles(bool ignore_naked_singles = true)
    {
        ArrayList<HiddenSingle?> hidden_singles = new ArrayList<HiddenSingle?> ();
        HashMap<Coord?, ArrayList<int>> open_squares = board.calculate_open_squares ();

        for (int row = 0; row < board.rows; row++)
        {
            for (int col = 0; col < board.cols; col++)
            {
                if (board[row, col] != 0)
                    continue;

                ArrayList<int> possibilities = open_squares[Coord(row, col)];

                if (ignore_naked_singles && possibilities.size == 1)
                    continue;

                foreach (int val in possibilities)
                {
                    bool possibility_not_present_in_row = true;
                    foreach (Coord coord in board.coords_for_row[row])
                    {
                        if (coord.row == row && coord.col == col)
                            continue;

                        if (open_squares[coord] == null)
                            continue;

                        if (open_squares[coord].contains(val))
                        {
                            possibility_not_present_in_row = false;
                            break;
                        }
                    }
                    bool possibility_not_present_in_col = true;
                    foreach (Coord coord in board.coords_for_col[col])
                    {
                        if (coord.row == row && coord.col == col)
                            continue;

                        if (open_squares[coord] == null)
                            continue;

                        if (open_squares[coord].contains(val))
                        {
                            possibility_not_present_in_col = false;
                            break;
                        }
                    }
                    bool possibility_not_present_in_block = true;
                    foreach (Coord coord in board.coords_for_block[board.get_block_for(row, col)])
                    {
                        if (coord.row == row && coord.col == col)
                            continue;

                        if (open_squares[coord] == null)
                            continue;

                        if (open_squares[coord].contains(val))
                        {
                            possibility_not_present_in_block = false;
                            break;
                        }
                    }

                    if (possibility_not_present_in_row || possibility_not_present_in_col || possibility_not_present_in_block)
                    {
                        hidden_singles.add (HiddenSingle(Cell(Coord(row, col), val), possibility_not_present_in_row, possibility_not_present_in_col, possibility_not_present_in_block));
                    }
                }
            }
        }
        return hidden_singles;
    }

    public ArrayList<Subset?> get_naked_subsets ()
    {
        ArrayList<Subset?> subsets = new ArrayList<Subset?> ();
        HashMap<Coord?, ArrayList<int>> open_squares = board.calculate_open_squares ();

        for (int col = 0; col < board.cols; col++) {
            subsets.add_all(get_naked_subsets_in (board.coords_for_col[col], House.COLUMN, open_squares));
        }

        for (int row = 0; row < board.rows; row++) {
            subsets.add_all(get_naked_subsets_in (board.coords_for_row[row], House.ROW, open_squares));
        }

        int blocks_across = board.cols / board.block_cols;
        int blocks_down = board.rows / board.block_rows;

        for (int block_down = 0; block_down < blocks_down; block_down++) {
            for (int block_across = 0; block_across < blocks_across; block_across++) {
                subsets.add_all(get_naked_subsets_in (board.coords_for_block[Coord(block_across, block_down)], House.BLOCK, open_squares));
            }
        }

        return subsets;
    }

    private ArrayList<Subset?> get_naked_subsets_in (Gee.List<Coord?> coords, House house, HashMap<Coord?, ArrayList<int>> open_squares)
    {
        ArrayList<Subset?> subsets = new ArrayList<Subset?>();

        // Try starting a subset from each coord in the list given
        foreach (Coord initial_coord in coords)
        {
            // Skip if it has a value, or has less than 2 possibilites
            if (open_squares[initial_coord] == null || open_squares[initial_coord].size < 2)
                continue;

            ArrayList<Coord?> subset_coords = new ArrayList<Coord?> ();
            subset_coords.add (initial_coord);

            int possibilities = open_squares[initial_coord].size;

            foreach (Coord coord in coords)
            {
                if (open_squares[coord] == null || open_squares[coord].size != possibilities)
                    continue;

                // If the possibilites for coord, and initial_coord are the same
                if (open_squares[initial_coord].contains_all(open_squares[coord]))
                {
                    subset_coords.add (coord);
                }

                // If this subset is complete
                if (subset_coords.size == possibilities)
                {
                    ArrayList<Cell?> eliminated_possibilities = get_eliminated_possibilities(coords, subset_coords, open_squares);
                    subsets.add(Subset(subset_coords, house, eliminated_possibilities));

                    break;
                }
            }
        }

        return subsets;
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
    public ArrayList<Coord?> coords;
    public House house;
    public ArrayList<Cell?> eliminated_possibilities;

    public Subset (ArrayList<Coord?> coords, House house, ArrayList<Cell?> eliminated_possibilities)
    {
        this.coords = coords;
        this.house = house;
        this.eliminated_possibilities = eliminated_possibilities;
    }
}

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

