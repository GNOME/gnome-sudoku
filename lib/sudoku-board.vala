/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2014 Parin Porecha
 * Copyright © 2014 Michael Catanzaro
 *
 * This file is part of GNOME Sudoku.
 *
 * GNOME Sudoku is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
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

    //format is [row, colum]
    private int[,] cells;                       /* stores the value of the cells */
    private int[,] solution;                    /* stores the solution, if any, null otherwise */
    private bool[,] is_fixed;                   /* if the value at location is fixed or not */

    //format is [*, value - 1]
    private int[,] occurrences_in_row;           /* counts of the value's occurrences */
    private int[,] occurrences_in_col;           /* if any count is superior to 1 there's a breakage */
    private int[,,] occurrences_in_block;

    //format is [row, column, number - 1]
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

    public void set_all_is_fixed ()
    {
        for (var r = 0; r < rows; r++)
            for (var c = 0; c < cols; c++)
                if (cells[r, c] > 0)
                {
                    is_fixed[r, c] = true;
                    fixed++;
                }
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
    public signal void earmark_changed (int row, int col, int num, bool enabled);
    public signal void value_changed (int row, int col, int old_val, int new_val);

    /* The set of coordinates on the board which are invalid */
    public Gee.Set<Coord?> broken_coords { get; private set; }

    /* The list of coordinates for each column on the board */
    public Gee.List<Gee.List<Coord?>> coords_for_col { get; private set; }

    /* The list of coordinates for each row on the board */
    public Gee.List<Gee.List<Coord?>> coords_for_row { get; private set; }

    /* The map from the coordinate of a box, to the list of coordinates in that box, for each box on the board */
    public Map<Coord?, Gee.List<Coord?>> coords_for_block { get; private set; }

    public SudokuBoard (int block_rows = 3, int block_cols = 3)
    {
        rows = cols = block_rows * block_cols;
        this.block_rows = block_rows;
        this.block_cols = block_cols;
        cells = new int[rows, cols];
        is_fixed = new bool[rows, cols];
        occurrences_in_row = new int[rows, cols];
        occurrences_in_col = new int[cols, rows];
        occurrences_in_block = new int[block_rows, block_cols, block_rows * block_cols];
        earmarks = new bool[rows, cols, max_val];

        for (var l1 = 0; l1 < rows; l1++)
        {
            for (var l2 = 0; l2 < cols; l2++)
            {
                cells[l1, l2] = 0;
                is_fixed[l1, l2] = false;
                occurrences_in_row[l1, l2] = 0;
                occurrences_in_col[l2, l1] = 0;
            }
        }
        for (var l1 = 0; l1 < block_rows; l1++)
            for (var l2 = 0; l2 < block_cols; l2++)
                for (var l3 = 0; l3 < max_val; l3++)
                    occurrences_in_block[l1, l2, l3] = 0;

        broken_coords = new HashSet<Coord?>((HashDataFunc<Coord>) Coord.hash, (EqualDataFunc<Coord>) Coord.equal);

        coords_for_col = new ArrayList<ArrayList<Coord?>> ();
        for (int col = 0; col < cols; col++)
        {
            coords_for_col.add (new ArrayList<Coord?> ((EqualDataFunc<Coord>) Coord.equal));
            for (int row = 0; row < rows; row++)
                coords_for_col.get (col).add (Coord(row, col));

            coords_for_col[col] = coords_for_col[col].read_only_view;
        }
        coords_for_col = coords_for_col.read_only_view;

        coords_for_row = new ArrayList<ArrayList<Coord?>> ();
        for (int row = 0; row < rows; row++)
        {
            coords_for_row.add (new ArrayList<Coord?> ((EqualDataFunc<Coord>) Coord.equal));
            for (int col = 0; col < cols; col++)
                coords_for_row.get (row).add (Coord(row, col));

            coords_for_row[row] = coords_for_row[row].read_only_view;
        }
        coords_for_row = coords_for_row.read_only_view;

        coords_for_block = new HashMap<Coord?, Gee.List<Coord?>> ((HashDataFunc<Coord>) Coord.hash, (EqualDataFunc<Coord>) Coord.equal);
        for (int col = 0; col < block_cols; col++)
            for (int row = 0; row < block_rows; row++)
                coords_for_block.set (Coord(row, col), new ArrayList<Coord?> ((EqualDataFunc<Coord>) Coord.equal));

        for (int col = 0; col < cols; col++)
            for (int row = 0; row < rows; row++)
                coords_for_block.get(Coord(row / block_rows, col / block_cols)).add(Coord(row, col));

        for (int col = 0; col < block_cols; col++)
            for (int row = 0; row < block_rows; row++)
                coords_for_block[Coord(row, col)] = coords_for_block[Coord(row, col)].read_only_view;

        coords_for_block = coords_for_block.read_only_view;
    }

    public SudokuBoard clone ()
    {
        SudokuBoard board = new SudokuBoard (block_rows , block_cols);
        board.cells = cells;
        board.solution = solution;
        board.is_fixed = is_fixed;
        board.occurrences_in_row = occurrences_in_row;
        board.occurrences_in_col = occurrences_in_col;
        board.occurrences_in_block = occurrences_in_block;
        board.filled = filled;
        board.fixed = fixed;
        board.n_earmarks = n_earmarks;
        board.broken_coords.add_all (broken_coords);
        board.earmarks = earmarks;
        board.difficulty_category = difficulty_category;

        return board;
    }

    public bool get_is_fixed (int row, int column)
    {
        return is_fixed[row, column];
    }

    public void set_is_fixed (int row, int column, bool _value)
    {
        is_fixed[row, column] = _value;
    }

    public void enable_earmark (int row, int column, int num)
        requires (cells[row, column] == 0)
        requires (!earmarks[row, column, num-1])
    {
        earmarks[row, column, num-1] = true;
        n_earmarks++;
        earmark_changed (row, column, num, true);
    }

    public void disable_earmark (int row, int column, int num)
        requires (cells[row, column] == 0)
        requires (earmarks[row, column, num-1])
    {
        earmarks[row, column, num-1] = false;
        n_earmarks--;
        earmark_changed (row, column, num, false);
    }

    public void disable_all_earmarks (int row, int column)
    {
        for (var i = 1; i <= max_val; i++)
            if (earmarks[row, column, i-1])
                disable_earmark (row, column, i);
    }

    public bool is_earmark_enabled (int row, int column, int num)
    {
        return earmarks[row, column, num-1];
    }

    public bool is_possible (int row, int col, int val)
    {
        return (occurrences_in_row[row, val - 1] == 0
                && occurrences_in_col[col, val - 1] == 0
                && occurrences_in_block[row / block_cols, col / block_rows, val - 1] == 0);
    }

    public int[] get_possibilities (int row, int col)
    {
        if (cells [row, col] != 0)
            return new int[0];

        var possibilities = new int[9];
        var count = 0;

        for (var l = 1; l <= max_val; l++)
        {
            if (is_possible (row, col, l))
            {
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
            possibilities[l - 1] = is_possible (row, col, l);

        return possibilities;
    }

    public void insert (int row, int col, int val, bool is_fixed = false)
        requires (val > 0 && val <= max_val)
        requires (!this.is_fixed[row, col])
    {
        var old_val = cells[row, col];
        cells[row, col] = val;

        this.is_fixed[row, col] = is_fixed;
        if (is_fixed)
            fixed++;

        if (old_val != 0)
            update_old_breakages (row, col, old_val);
        else
            filled++;

        mark_breakages (row, col, val);
        add_to_occurrences (row, col, val, 1);

        if (complete)
            completed();
        value_changed (row, col, old_val, val);
    }

    public void remove (int row, int col)
        requires (cells[row, col] > 0)
        requires (!this.is_fixed[row, col])
    {
        int old_val = cells[row, col];
        cells[row, col] = 0;
        filled--;
        update_old_breakages (row, col, old_val);
        value_changed (row, col, old_val, 0);
    }

    public new int get (int row, int col)
    {
        return cells[row, col];
    }

    public new void set (int row, int col, int val)
    {
        var old_val = get (row, col);
        if (old_val == 0)
            disable_all_earmarks (row, col);

        if (old_val == val)
            return;

        if (val == 0)
            remove (row, col);
        else
            insert (row, col, val);
    }

    private void update_old_breakages (int row, int col, int val)
    {
        add_to_occurrences (row, col, val, -1);

        if (broken_coords.contains (Coord(row, col)))
        {
            broken_coords.remove (Coord(row, col));
            //remove all the related breakages in the related sets of cells
            remove_breakages_for (coords_for_row[row], val);
            remove_breakages_for (coords_for_col[col], val);
            remove_breakages_for (coords_for_block[Coord(row / block_rows, col / block_cols)], val);
        }
    }

    private void add_to_occurrences (int row, int col, int val, int add)
    {
        occurrences_in_row[row, val - 1] += add;
        occurrences_in_col[col, val - 1] += add;
        occurrences_in_block[row / block_cols, col / block_rows, val - 1] += add;
    }

    private void mark_breakages (int row, int col, int val)
    {
        if (occurrences_in_row[row, val - 1] > 0)
            mark_breakages_for (coords_for_row[row], val);

        if (occurrences_in_col[col, val - 1] > 0)
            mark_breakages_for (coords_for_col[col], val);

        if (occurrences_in_block[row / block_rows, col / block_cols, val - 1] > 0)
            mark_breakages_for (coords_for_block[Coord(row / block_rows, col / block_cols)], val);
    }

    public void set_solution (int row, int col, int val)
        requires (solution != null)
    {
        solution[row, col] = val;
    }

    public int get_solution (int row, int col)
    {
        return solution == null ? 0 : solution[row, col];
    }

    private int[,] fixed_cells_only ()
    {
        int[,] result = new int[rows, cols];

        for (int row = 0; row < rows; row++)
        {
            for (int col = 0; col < cols; col++)
            {
                if (is_fixed[row, col])
                    result[row, col] = cells[row, col];
                else
                    result[row, col] = 0;
            }
        }

        return result;
    }

    public void solve ()
    {
        int[,] fixed_cells = fixed_cells_only ();
        int[] solution_1d = convert_2d_to_1d (fixed_cells);

        if (QQwing.solve_puzzle (solution_1d))
            solution = convert_1d_to_2d (solution_1d);
        else
            solution = null;
    }

    public bool solved ()
    {
        return solution != null;
    }

    public int count_solutions_limited ()
    {
        int[] cells_1d = convert_2d_to_1d (cells);

        return QQwing.count_solutions_limited (cells_1d);
    }

    public Set<Coord?> get_occurrences(Gee.List<Coord?> coords, int val)
    {
        Set<Coord?> occurrences = new HashSet<Coord?>((HashDataFunc<Coord>) Coord.hash, (EqualDataFunc<Coord>) Coord.equal);
        foreach (Coord coord in coords)
            if (cells[coord.row, coord.col] == val)
                occurrences.add (coord);

        return occurrences;
    }

    private void remove_breakages_for (Gee.List<Coord?> coords, int val)
    {
        foreach (Coord coord in coords)
            if (cells[coord.row, coord.col] == val
                && broken_coords.contains (coord)
                && occurrences_in_row[coord.row, val - 1] <= 1
                && occurrences_in_col[coord.col, val - 1] <= 1
                && occurrences_in_block[coord.row / block_cols, coord.col / block_rows, val - 1] <= 1)
                {
                    broken_coords.remove (coord);
                }
    }

    /* returns if val is possible in coords */
    private void mark_breakages_for (Gee.List<Coord?> coords, int val)
    {
        Set<Coord?> occurrences = get_occurrences (coords, val);
        if (occurrences.size != 1)
            broken_coords.add_all (occurrences);
    }

    public void print (int indent = 0)
    {
        for (var l1 = 0; l1 < 9; l1++)
        {
            for (int i = 0; i < indent; i++)
                stdout.printf(" ");
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

    public void get_string ()
    {
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

    public int[,] get_cells ()
    {
        return cells;
    }

    public HashMap<Coord?, Gee.List<int>> calculate_open_squares ()
    {
        var possibilities = new HashMap<Coord?, Gee.List<int>> ((HashDataFunc<Coord>) Coord.hash, (EqualDataFunc<Coord>) Coord.equal);
        for (var l1 = 0; l1 < rows; l1++)
        {
            for (var l2 = 0; l2 < cols; l2++)
            {
                if (cells[l1, l2] == 0)
                {
                    Gee.List<int> possArrayList = new ArrayList<int> ();
                    int[] possArray = get_possibilities (l1, l2);
                    foreach (int i in possArray)
                        possArrayList.add (i);
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

    public bool[] get_earmarks (int row, int col)
    {
        bool[] the_earmarks = new bool[max_val];
        for (var i = 1; i <= max_val; i++)
            the_earmarks[i-1] = earmarks[row, col, i-1];
        return the_earmarks;
    }

    public bool has_earmarks (int row, int col)
    {
        bool[] current_earmarks = this.get_earmarks (row, col);
        bool has_earmarks = false;
        for (int i = 0; i < 9; i++)
            if (current_earmarks [i])
            {
                has_earmarks = true;
                break;
            }
        return has_earmarks;
    }

    public string get_earmarks_string (int row, int col)
    {
        string s = "";
        for (var i = 1; i <= max_val; i++)
            if (earmarks[row, col, i-1])
                s += i.to_string ();

        return s;
    }

    // Convert a 2D array to a 1D array. The 2D array is assumed to have
    // dimensions rows, cols.
    private int[] convert_2d_to_1d(int[,] ints_2d)
    {
        int[] ints_1d = new int[rows * cols];
        int i = 0;
        for (int row = 0; row < rows; row++)
            for (int col = 0; col < cols; col++)
                ints_1d[i++] = ints_2d[row, col];
        return ints_1d;
    }

    // Convert a 1D array to a 2D array. The 1D array is assumed to have
    // length rows * cols.
    private int[,] convert_1d_to_2d(int[] ints_1d)
    {
        int[,] ints_2d = new int[rows, cols];
        int i = 0;
        for (int row = 0; row < rows; row++)
            for (int col = 0; col < cols; col++)
                ints_2d[row, col] = ints_1d[i++];
        return ints_2d;
    }
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

    public static int hash (Coord coord)
    {
        return (coord.row * 33) ^ coord.col;
    }

    public static bool equal (Coord a, Coord b)
    {
        return ((a.row == b.row) && (a.col == b.col));
    }
}

public enum DifficultyCategory
{
    UNKNOWN = 0,
    EASY = 1,
    MEDIUM = 2,
    HARD = 3,
    VERY_HARD = 4,
    CUSTOM = 5;

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
