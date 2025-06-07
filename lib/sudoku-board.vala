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
    // Implemented in such a way that it can be extended for other sizes ( like 2x3 sudoku or 4x4 sudoku ) instead of normal 3x3 sudoku.

    private struct Cell
    {
        int value;
        int solution;
        // Format is [number - 1]
        bool[] earmarks;
        bool fixed;
    }
    // Format is [row, col]
    private Cell[,] cells;

    private struct DigitOccurences
    {
        int[] occurrences_in_row;
        int[] occurrences_in_col;
        int[,] occurrences_in_block;
    }
    // Format is [value - 1]
    private DigitOccurences[] digits;

    private bool has_solution = false;

    // The sum of earmarks on the board
    private int n_earmarks;

    public double previous_played_time { get; set; default = 0; }

    public DifficultyCategory difficulty_category { get; set; default = DifficultyCategory.UNKNOWN; }

    // Number of rows in one block
    public int block_rows { get; private set; default = 3;}

    // Number of columns in one block
    public int block_cols { get; private set; default = 3; }

    // Number of rows on the board */
    public int rows { get; private set; default = 9; }

    // Number of columns on the board */
    public int cols { get; private set; default = 9; }

    // Maximum possible value on the board. 9 for 3x3 sudoku
    public int max_val
    {
        get { return block_rows * block_cols; }
    }

    // The sum of filled cells on the board
    public int filled { get; private set; }

    // The sum of fixed cells on the board
    public int fixed { get; private set; }

    public bool complete
    {
        get
        {
            bool broken = broken_coords.size != 0;
            return filled == cols * rows && !broken;
        }
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

    // The set of coordinates on the board which are invalid
    public Gee.Set<Coord?> broken_coords { get; private set; }

    // The list of coordinates for each col on the board
    public Gee.List<Gee.List<Coord?>> coords_for_col { get; private set; }

    // The list of coordinates for each row on the board
    public Gee.List<Gee.List<Coord?>> coords_for_row { get; private set; }

    // The map from the coordinate of a box, to the list of coordinates in that box, for each box on the board
    public Map<Coord?, Gee.List<Coord?>> coords_for_block { get; private set; }

    public SudokuBoard ()
    {
        cells = new Cell[rows, cols];
        for (int row = 0; row < rows; row++)
            for (int col = 0; col < cols; col++)
                cells[row, col].earmarks = new bool[max_val];

        digits = new DigitOccurences[max_val];
        for (int i = 0; i < max_val; i++)
        {
            digits[i].occurrences_in_row = new int[rows];
            digits[i].occurrences_in_col = new int[cols];
            digits[i].occurrences_in_block = new int[block_rows, block_cols];
        }

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
        SudokuBoard board = new SudokuBoard ();
        board.cells = cells;
        board.digits = digits;
        board.filled = filled;
        board.fixed = fixed;
        board.n_earmarks = n_earmarks;
        board.broken_coords.add_all (broken_coords);
        board.difficulty_category = difficulty_category;

        return board;
    }

    public new int get (int row, int col)
    {
        return cells[row, col].value;
    }

    public bool[] get_earmarks (int row, int col)
    {
        return cells[row, col].earmarks;
    }

    public bool get_is_fixed (int row, int col)
    {
        return cells[row, col].fixed;
    }

    public int get_solution (int row, int col)
    {
        return cells[row, col].solution;
    }

    public int[,] get_cells ()
    {
        var ret = new int[rows, cols];
        for (int row = 0; row < rows; row++)
            for (int col = 0; col < cols; col++)
                ret[row, col] = cells[row, col].value;

        return ret;
    }

    private int[,] get_fixed_cells ()
    {
        int[,] ret = new int[rows, cols];

        for (int row = 0; row < rows; row++)
        {
            for (int col = 0; col < cols; col++)
            {
                if (cells[row, col].fixed)
                    ret[row, col] = cells[row, col].value;
                else
                    ret[row, col] = 0;
            }
        }

        return ret;
    }

    public int[] get_possibilities (int row, int col)
    {
        if (cells[row, col].value != 0)
            return new int[0];

        var possibilities = new int[9];
        var count = 0;

        for (var l = 1; l <= max_val; l++)
            if (is_possible (row, col, l))
            {
                possibilities[count] = l;
                count++;
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

    public void set_all_fixed ()
    {
        for (int row = 0; row < rows; row++)
            for (int col = 0; col < cols; col++)
                if (cells[row, col].value > 0)
                {
                    cells[row, col].fixed = true;
                    fixed++;
                }
    }

    public void enable_earmark (int row, int col, int num)
        requires (cells[row, col].value == 0)
        requires (!cells[row, col].earmarks[num - 1])
    {
        cells[row, col].earmarks[num - 1] = true;
        n_earmarks++;
        earmark_changed (row, col, num, true);
    }

    public void disable_earmark (int row, int col, int num)
        requires (cells[row, col].value == 0)
        requires (cells[row, col].earmarks[num - 1])
    {
        cells[row, col].earmarks[num - 1] = false;
        n_earmarks--;
        earmark_changed (row, col, num, false);
    }

    public void disable_all_earmarks (int row, int col)
    {
        for (var num = 1; num <= max_val; num++)
            if (cells[row, col].earmarks[num - 1])
                disable_earmark (row, col, num);
    }

    public bool is_earmark_enabled (int row, int col, int num)
    {
        return cells[row, col].earmarks[num - 1];
    }

    public bool is_possible (int row, int col, int val)
    {
        var digit = digits[val - 1];
        return (digit.occurrences_in_row[row] == 0 &&
                digit.occurrences_in_col[col] == 0 &&
                digit.occurrences_in_block[row / block_rows, col / block_cols] == 0);
    }

    public void insert (int row, int col, int val, bool is_fixed = false)
        requires (val > 0 && val <= max_val)
        requires (!cells[row, col].fixed)
    {
        var old_val = cells[row, col].value;
        cells[row, col].value = val;

        cells[row, col].fixed = is_fixed;
        if (is_fixed)
            fixed++;

        if (old_val != 0)
            update_old_breakages (row, col, old_val);
        else
            filled++;

        add_to_occurrences (row, col, val, 1);
        mark_breakages (row, col, val);

        value_changed (row, col, old_val, val);

        if (complete)
            completed();
    }

    public void remove (int row, int col)
        requires (cells[row, col].value > 0)
        requires (!cells[row, col].fixed)
    {
        int old_val = cells[row, col].value;
        cells[row, col].value = 0;
        filled--;
        update_old_breakages (row, col, old_val);
        value_changed (row, col, old_val, 0);
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
        digits[val - 1].occurrences_in_row[row] += add;
        digits[val - 1].occurrences_in_col[col] += add;
        digits[val - 1].occurrences_in_block[row / block_rows, col / block_cols] += add;
    }

    private void mark_breakages (int row, int col, int val)
    {
        var digit = digits[val - 1];

        if (digit.occurrences_in_row[row] > 1)
            mark_breakages_for (coords_for_row[row], val);

        if (digit.occurrences_in_col[col] > 1)
            mark_breakages_for (coords_for_col[col], val);

        if (digit.occurrences_in_block[row / block_rows, col / block_cols] > 1)
            mark_breakages_for (coords_for_block[Coord(row / block_rows, col / block_cols)], val);
    }

    public void solve ()
    {
        int[,] fixed_cells = get_fixed_cells ();
        int[] solution_1d = convert_2d_to_1d (fixed_cells);

        if (QQwing.solve_puzzle (solution_1d))
        {
            has_solution = true;
            int i = 0;
            for (int row = 0; row < rows; row++)
                for (int col = 0; col < cols; col++)
                {
                    cells[row, col].solution = solution_1d[i];
                    i++;
                }
        }
        else
            has_solution = false;
    }

    public unowned bool solved ()
    {
        return has_solution;
    }

    public int count_solutions_limited ()
    {
        int[] cells_1d = convert_2d_to_1d (get_cells ());

        return QQwing.count_solutions_limited (cells_1d);
    }

    private void remove_breakages_for (Gee.List<Coord?> coords, int val)
    {
        var digit = digits[val - 1];
        foreach (Coord coord in coords)
            if (cells[coord.row, coord.col].value == val &&
                broken_coords.contains (coord) &&
                digit.occurrences_in_row[coord.row] <= 1 &&
                digit.occurrences_in_col[coord.col] <= 1 &&
                digit.occurrences_in_block[coord.row / block_cols, coord.col / block_rows] <= 1)
                {
                    broken_coords.remove (coord);
                }
    }

    private void mark_breakages_for (Gee.List<Coord?> coords, int val)
    {
        foreach (Coord coord in coords)
            if (cells[coord.row, coord.col].value == val)
                broken_coords.add (coord);
    }

    public string to_string ()
    {
        var board_string = "";
        for (var row = 0; row < rows; row++)
            for (var col = 0; col < cols; col++)
            {
                if (cells[row, col].fixed)
                    board_string += cells[row, col].value.to_string ();
                else
                    board_string += "0";
            }

        return board_string;
    }

    public bool is_finished ()
    {
        var board_string = this.to_string () + ".save";
        var finishgame_file = Path.build_path (Path.DIR_SEPARATOR_S, SudokuSaver.finishgame_dir, board_string);
        var file = File.new_for_path (finishgame_file);

        return file.query_exists ();
    }

    public bool has_earmarks (int row, int col)
    {
        for (int i = 0; i < 9; i++)
            if (cells[row, col].earmarks[i])
                return true;

        return false;
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
