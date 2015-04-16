/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2014 Parin Porecha
 * Copyright © 2014 Michael Catanzaro
 *
 * This file is part of GNOME Sudoku.
 *
 * GNOME Sudoku is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * GNOME Sudoku is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNOME Sudoku. If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;

public class SudokuBoard : Object
{
    /* Implemented in such a way that it can be extended for other sizes ( like 2x3 sudoku or 4x4 sudoku ) instead of normal 3x3 sudoku. */

    protected int[,] cells;                     /* stores the value of the cells */
    public bool[,] is_fixed;                    /* if the value at location is fixed or not */
    private bool[,] possible_in_row;            /* if specific value is possible in specific row */
    private bool[,] possible_in_col;            /* if specific value is possible in specific col */
    private bool[,,] possible_in_block;         /* if specific value is possible in specific block */

    private bool[,,] earmarks;                  /* Earmarks set by the user */
    private int n_earmarks;                     /* The number of earmarks on the board */

    public double previous_played_time { set; get; default = 0; }

    public DifficultyCategory difficulty_category { set; get; default = DifficultyCategory.UNKNOWN; }

    /* Number of rows in one block */
    public int block_rows { get; private set; }

    /* Number of columns in one block */
    public int block_cols { get; private set; }

    /* Number of rows in board */
    public int rows { get; private set; }

    /* Number of columns in board */
    public int cols { get; private set; }

    /* Maximum possible val on board. 9 for 3x3 sudoku*/
    public int max_val
    {
        get { return block_rows * block_cols; }
    }

    public bool broken
    {
        get { return broken_coords.size != 0; }
    }

    /* the number of filled squares on the board */
    public int filled { get; private set; }

    /* the number of fixed squares on the board */
    public int fixed { get; private set; }

    public int size
    {
        get { return rows * cols; }
    }

    public bool complete
    {
        get { return filled == cols * rows && !broken; }
    }

    public bool is_empty ()
    {
        return filled == fixed && n_earmarks == 0;
    }

    public bool is_fully_filled ()
    {
        return filled == cols * rows;
    }

    public signal void completed ();

    /* The set of coordinates on the board which are invalid */
    public Gee.Set<Coord?> broken_coords;

    /* The list of coordinates for each column on the board */
    public Gee.List<Gee.List<Coord?>> coords_for_col;

    /* The list of coordinates for each row on the board */
    public Gee.List<Gee.List<Coord?>> coords_for_row;

    /* The map from the coordinate of a box, to the list of coordinates in that box, for each box on the board */
    public Map<Coord?, Gee.List<Coord?>> coords_for_block;

    public SudokuBoard (int block_rows = 3, int block_cols = 3)
    {
        rows = cols = block_rows * block_cols;
        this.block_rows = block_rows;
        this.block_cols = block_cols;
        cells = new int[rows, cols];
        is_fixed = new bool[rows, cols];
        possible_in_row = new bool[rows, cols];
        possible_in_col = new bool[cols, rows];
        possible_in_block = new bool[block_rows, block_cols, block_rows * block_cols];
        earmarks = new bool[rows, cols, max_val];

        for (var l1 = 0; l1 < rows; l1++)
        {
            for (var l2 = 0; l2 < cols; l2++)
            {
                cells[l1, l2] = 0;
                is_fixed[l1, l2] = false;
                possible_in_row[l1, l2] = true;
                possible_in_col[l2, l1] = true;
            }
        }
        for (var l1 = 0; l1 < block_rows; l1++)
        {
            for (var l2 = 0; l2 < block_cols; l2++)
            {
                for (var l3 = 0; l3 < max_val; l3++)
                    possible_in_block[l1, l2, l3] = true;
            }
        }

        broken_coords = new HashSet<Coord?>((HashDataFunc<Coord>) Coord.hash, (EqualDataFunc<Coord>) Coord.equal);

        coords_for_col = new ArrayList<ArrayList<Coord?>> ();
        for (int col = 0; col < cols; col++)
        {
            coords_for_col.add (new ArrayList<Coord?> ((EqualDataFunc<Coord>) Coord.equal));
            for (int row = 0; row < rows; row++)
            {
                coords_for_col.get (col).add (Coord(row, col));
            }
            coords_for_col[col] = coords_for_col[col].read_only_view;
        }
        coords_for_col = coords_for_col.read_only_view;

        coords_for_row = new ArrayList<ArrayList<Coord?>> ();
        for (int row = 0; row < rows; row++)
        {
            coords_for_row.add (new ArrayList<Coord?> ((EqualDataFunc<Coord>) Coord.equal));
            for (int col = 0; col < cols; col++)
            {
                coords_for_row.get (row).add (Coord(row, col));
            }
            coords_for_row[row] = coords_for_row[row].read_only_view;
        }
        coords_for_row = coords_for_row.read_only_view;

        coords_for_block = new HashMap<Coord?, Gee.List<Coord?>> ((HashDataFunc<Coord>) Coord.hash, (EqualDataFunc<Coord>) Coord.equal);
        for (int col = 0; col < block_cols; col++)
        {
            for (int row = 0; row < block_rows; row++)
            {
                coords_for_block.set (Coord(row, col), new ArrayList<Coord?> ((EqualDataFunc<Coord>) Coord.equal));
            }
        }
        for (int col = 0; col < cols; col++)
        {
            for (int row = 0; row < rows; row++)
            {
                coords_for_block.get(Coord(row / block_rows, col / block_cols)).add(Coord(row, col));
            }
        }
        for (int col = 0; col < block_cols; col++)
        {
            for (int row = 0; row < block_rows; row++)
            {
                coords_for_block[Coord(row, col)] = coords_for_block[Coord(row, col)].read_only_view;
            }
        }
        coords_for_block = coords_for_block.read_only_view;
    }

    public SudokuBoard clone ()
    {
        SudokuBoard board = new SudokuBoard (block_rows , block_cols);
        board.cells = cells;
        board.is_fixed = is_fixed;
        board.possible_in_row = possible_in_row;
        board.possible_in_col = possible_in_col;
        board.possible_in_block = possible_in_block;
        board.filled = filled;
        board.fixed = fixed;
        board.n_earmarks = n_earmarks;
        board.broken_coords.add_all (broken_coords);
        board.earmarks = earmarks;
        board.difficulty_category = difficulty_category;

        return board;
    }

    public void enable_earmark (int row, int column, int digit)
        ensures (n_earmarks > 0)
    {
        if (!earmarks[row, column, digit-1])
        {
            earmarks[row, column, digit-1] = true;
            n_earmarks++;
        }
    }

    public void disable_earmark (int row, int column, int digit)
        ensures (n_earmarks >= 0)
    {
        if (earmarks[row, column, digit-1])
        {
            earmarks[row, column, digit-1] = false;
            n_earmarks--;
        }
    }

    public void disable_all_earmarks (int row, int column)
        ensures (n_earmarks >= 0)
    {
        for (var i = 1; i <= max_val; i++)
            if (earmarks[row, column, i-1])
                disable_earmark (row, column, i);
    }

    public bool is_earmark_enabled (int row, int column, int digit)
    {
        return earmarks[row, column, digit-1];
    }

    public bool is_possible (int row, int col, int val)
    {
        val--;
        return (possible_in_row[row, val] && possible_in_col[col, val] && possible_in_block [row / block_cols, col / block_rows, val]);
    }

    public int count_possibilities (int row, int col)
    {
        return get_possibilities(row, col).length;
    }

    public int[] get_possibilities (int row, int col)
    {
        if (cells [row, col] != 0)
            return new int[0];

        var possibilities = new int[9];
        var count = 0;

        for (var l = 1; l <= max_val; l++)
        {
            if (is_possible (row, col, l)) {
                possibilities[count] = l;
                count++;
            }
        }
        return possibilities[0:count];
    }

    public bool[] get_possibilities_as_bool_array (int row, int col)
    {
        var possibilities = new bool[max_val];

        for (var l = 1; l <= max_val; l++)
        {
            possibilities[l - 1] = is_possible (row, col, l);
        }

        return possibilities;
    }

    public Coord get_block_for(int row, int col)
    {
        return Coord(row / block_rows, col / block_cols);
    }

    public void insert (int row, int col, int val, bool is_fixed = false)
    {
        /* This should not happen when coded properly ;) */
        assert (val > 0);
        assert (val <= max_val);

        /* Cant insert in to a fixed cell, unless you know what you are doing */
        if (!is_fixed)
            assert (!this.is_fixed[row, col]);

        // If the cell has a previous value, remove it before continuing
        if (cells[row, col] != 0)
            remove(row, col, is_fixed);

        cells[row, col] = val;
        this.is_fixed[row, col] = is_fixed;
        filled++;
        if (is_fixed)
            fixed++;

        if (!possible_in_row[row, val - 1]) // If val was not possible in this row
        {
            mark_breakages_for(coords_for_row[row], val); // Mark the breakages
        }

        if (!possible_in_col[col, val - 1]) // If val was not possible in this col
        {
            mark_breakages_for(coords_for_col[col], val); // Mark the breakages
        }

        if (!possible_in_block[row / block_cols, col / block_rows, val - 1]) // If val was not possible in this block
        {
            mark_breakages_for(coords_for_block[Coord(row / block_cols, col / block_rows)], val); // Mark the breakages
        }

        // Then just mark it as not possible
        val--;
        possible_in_row[row, val] = false;
        possible_in_col[col, val] = false;
        possible_in_block[row / block_cols, col / block_rows, val] = false;

        if (complete)
            completed();
    }

    public new void set (int row, int col, int val)
    {
        if (val == 0)
        {
            remove (row, col);
        }
        else if (val > 0 && val <= max_val)
        {
            insert (row, col, val);
        }
        else
        {
            assert_not_reached();
        }
    }

    public new int get (int row, int col)
    {
        return cells[row, col];
    }

    public void remove (int row, int col, bool is_fixed = false)
    {
        /* You can't remove an empty cell */
        if (cells[row, col] == 0)
            return;

        /* You can't remove an fixed cell */
        if (!is_fixed)
            assert (!this.is_fixed[row, col]);

        int previous_val = cells[row, col];
        cells[row, col] = 0;

        if (broken_coords.contains(Coord(row, col))) // If this cell was broken
        {
            // Remove all the related breakages in the related sets of cells
            remove_breakages_for(coords_for_row[row], previous_val);
            remove_breakages_for(coords_for_col[col], previous_val);
            remove_breakages_for(coords_for_block[Coord(row / block_rows, col / block_cols)], previous_val);
            broken_coords.remove(Coord(row, col));

            // Re-mark all the breakages,
            mark_breakages_for(coords_for_row[row], previous_val);
            mark_breakages_for(coords_for_col[col], previous_val);
            mark_breakages_for(coords_for_block[Coord(row / block_rows, col / block_cols)], previous_val);

            // and update the possibilities accordingly
            possible_in_row[row, previous_val - 1] = get_occurances(coords_for_row[row], previous_val).size == 0;
            possible_in_col[col, previous_val - 1] = get_occurances(coords_for_col[col], previous_val).size == 0;
            possible_in_block[row / block_cols, col / block_rows, previous_val - 1] = get_occurances(coords_for_block[Coord(row / block_rows, col / block_cols)], previous_val).size == 0;
        }
        else // Not previously broken, so just mark as a possible value
        {
            previous_val--;

            possible_in_row[row, previous_val] = true;
            possible_in_col[col, previous_val] = true;
            possible_in_block[row / block_cols, col / block_rows, previous_val] = true;
        }

        filled--;

        if (is_fixed)
            fixed--;
    }

    public Set<Coord?> get_occurances(Gee.List<Coord?> coords, int val)
    {
        Set<Coord?> occurances = new HashSet<Coord?>((HashDataFunc<Coord>) Coord.hash, (EqualDataFunc<Coord>) Coord.equal);
        foreach (Coord coord in coords)
        {
            if (cells[coord.row, coord.col] == val) {
                occurances.add (coord);
            }
        }
        return occurances;
    }

    public bool row_contains(int row, int val)
    {
        return get_occurances(coords_for_row[row], val).size != 0;
    }

    public bool col_contains(int col, int val)
    {
        return get_occurances(coords_for_col[col], val).size != 0;
    }

    public bool block_contains(Coord block, int val)
    {
        return get_occurances(coords_for_block[block], val).size != 0;
    }

    private void remove_breakages_for(Gee.List<Coord?> coords, int val)
    {
        foreach (Coord coord in coords)
        {
            if (cells[coord.row, coord.col] == val && broken_coords.contains(coord)) {
                broken_coords.remove(coord);
            }
        }
    }

    /* returns if val is possible in coords */
    private void mark_breakages_for(Gee.List<Coord?> coords, int val)
    {
        Set<Coord?> occurances = get_occurances(coords, val);
        if (occurances.size != 1)
        {
            broken_coords.add_all(occurances);
        }
    }

    public void to_initial_state ()
    {
        for (var l1 = 0; l1 < rows; l1++)
        {
            for (var l2 = 0; l2 < cols; l2++)
            {
                if (!is_fixed[l1, l2])
                    remove (l1, l2);
            }
        }
    }

    public void print (int indent = 0) {
        for (var l1 = 0; l1 < 9; l1++)
        {
            for (int i = 0; i < indent; i++)
            {
                stdout.printf(" ");
            }
            for (var l2 = 0; l2 < 9; l2++)
            {
                if (cells[l1,l2] != 0)
                    stdout.printf ("%d ", cells[l1,l2]);
                else
                    stdout.printf ("  ");
            }
            stdout.printf ("\n");
        }
        stdout.flush ();
    }

    public void get_string () {
        stdout.printf ("[ ");
        for (var l1 = 0; l1 < 9; l1++)
        {
            stdout.printf ("[ ");
            for (var l2 = 0; l2 < 9; l2++)
            {
                stdout.printf ("%d", cells[l1,l2]);
                if (l2 != 8)
                    stdout.printf (",");
            }
            stdout.printf (" ]");
            if (l1 != 8)
                stdout.printf (",");
        }
        stdout.printf (" ]");
    }

    public string to_string (bool get_original_state = false)
    {
        var board_string = "";
        for (var i = 0; i < rows; i++)
        {
            for (var j = 0; j < cols; j++)
            {
                if (is_fixed[i, j])
                    board_string += cells[i, j].to_string ();
                else
                    board_string += get_original_state ? "0" : cells[i, j].to_string ();
            }
        }
        return board_string;
    }

    public int[,] get_cells()
    {
        return cells;
    }

    public HashMap<Coord?, Gee.List<int>> calculate_open_squares () {
        var possibilities = new HashMap<Coord?, Gee.List<int>> ((HashDataFunc<Coord>) Coord.hash, (EqualDataFunc<Coord>) Coord.equal);
        for (var l1 = 0; l1 < rows; l1++)
        {
            for (var l2 = 0; l2 < cols; l2++)
            {
                if (cells[l1, l2] == 0)
                {
                    Gee.List<int> possArrayList = new ArrayList<int> ();
                    int[] possArray = get_possibilities (l1, l2);
                    foreach (int i in possArray) {
                        possArrayList.add (i);
                    }
                    possibilities[Coord(l1, l2)] = possArrayList;
                }
            }
        }
        return possibilities;
    }

    public bool is_finished ()
    {
        var board_string = this.to_string (true) + ".save";
        var finishgame_file = Path.build_path (Path.DIR_SEPARATOR_S, SudokuSaver.finishgame_dir, board_string);
        var file = File.new_for_path (finishgame_file);

        return file.query_exists ();
    }

    public string get_earmarks_string (int row, int col)
    {
        string s = "";
        for (var i = 1; i <= max_val; i++)
            if (earmarks[row, col, i-1])
                s += i.to_string ();

        return s;
    }
}

public enum House {
    ROW,
    COLUMN,
    BLOCK
}

public struct Coord
{
    public int row;
    public int col;

    public Coord(int row, int col)
    {
        this.row = row;
        this.col = col;
    }

    public static int hash (Coord coord) {
        return (coord.row * 33) ^ coord.col;
    }

    public static bool equal (Coord a, Coord b) {
        return ((a.row == b.row) && (a.col == b.col));
    }
}

public struct Cell
{
    public Coord coord;
    public int val;

    public Cell(Coord coord, int val)
    {
        this.coord = coord;
        this.val = val;
    }

    public static int hash (Cell cell) {
        return (Coord.hash(cell.coord) * 33) ^ cell.val;
    }

    public static bool equal (Cell a, Cell b) {
        return (Coord.equal(a.coord, b.coord) && (a.val == b.val));
    }
}

public enum DifficultyCategory {
    UNKNOWN,
    EASY,
    MEDIUM,
    HARD,
    VERY_HARD,
    CUSTOM;

    public string to_string ()
    {
        switch (this)
        {
            case UNKNOWN:
                return _("Unknown Difficulty");
            case EASY:
                return _("Easy Difficulty");
            case MEDIUM:
                return _("Medium Difficulty");
            case HARD:
                return _("Hard Difficulty");
            case VERY_HARD:
                return _("Very Hard Difficulty");
            case CUSTOM:
                return _("Custom Puzzle");
            default:
                assert_not_reached ();
        }
    }

    public string to_untranslated_string ()
    {
        switch (this)
        {
            case UNKNOWN:
                return "Unknown Difficulty";
            case EASY:
                return "Easy Difficulty";
            case MEDIUM:
                return "Medium Difficulty";
            case HARD:
                return "Hard Difficulty";
            case VERY_HARD:
                return "Very Hard Difficulty";
            case CUSTOM:
                return "Custom Puzzle";
            default:
                assert_not_reached ();
        }
    }

    public static DifficultyCategory from_string (string input)
    {
        switch (input)
        {
            case "Unknown Difficulty":
                return UNKNOWN;
            case "Easy Difficulty":
                return EASY;
            case "Medium Difficulty":
                return MEDIUM;
            case "Hard Difficulty":
                return HARD;
            case "Very Hard Difficulty":
                return VERY_HARD;
            case "Custom Puzzle":
                return CUSTOM;
            default:
                warning ("Could not parse difficulty level. Falling back to Easy difficulty");
                return EASY;
        }
    }
}
