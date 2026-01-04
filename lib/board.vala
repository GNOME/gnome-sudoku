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

    // The list of coordinates that are on the same block, row and column for each cell
    // Format is [row][col]
    public Set<Coord?> [,] aligned_coords_for_cell;

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

        aligned_coords_for_cell = new Set<Coord?> [rows, cols];
        for (int row = 0; row < rows; row++)
            for (int col = 0; col < cols; col++)
            {
                aligned_coords_for_cell[row, col] = new HashSet<Coord?>((HashDataFunc<Coord>) Coord.hash, (EqualDataFunc<Coord>) Coord.equal);

                for (int i = 0; i < 9; i++)
                {
                    aligned_coords_for_cell[row, col].add (Coord(row, i));
                    aligned_coords_for_cell[row, col].add (Coord(i, col));
                }

                int row_block = row / 3;
                int row_col = col / 3;
                for (int i = row_block * 3; i < (row_block + 1) * 3; i++)
                    for (int j = row_col * 3; j < (row_col + 1) * 3; j++)
                        aligned_coords_for_cell[row, col].add (Coord(i, j));
            }
    }

    public SudokuBoard.from_string (string s)
        throws IOError
    {
        ctor_err (s.length > 100 || s.length < 81);

        this ();
        int row = 0;
        int col = 0;
        for (int i = 0; i < s.length; i++)
        {
            char c = s[i];
            if (c == '\n')
                continue;

            if (c.isdigit ())
                cells[row, col].value = c.digit_value ();
            else if (c == '.' || c == ' ' || c == '-')
                cells[row, col].value = 0;
            else
                continue;

            if (row == 8 && col == 8)
            {
                set_all_fixed ();
                return;
            }
            else if (col == 8)
            {
                row++;
                col = 0;
                continue;
            }
            else
                col++;
        }

        ctor_err (true);
    }

    public SudokuBoard.from_short_string (string s)
        throws IOError
    {
        ctor_err (s[0] != '#');

        this ();
        ArrayList<int> sizes = new ArrayList<int>();
        for (int i = 0; i < 5; i++)
        {
            int[] sizes_array = from_printable_ascii (s[i + 1]);
            sizes.add (sizes_array[0]);
            if (i != 4)
              sizes.add (sizes_array[1]);
        }

        int string_sum = 6;
        foreach (var size in sizes)
            string_sum += size;

        ctor_err (string_sum != s.length);

        var rows_cols = s.slice (6, s.length);
        int count = 0;
        int current_number = 0;
        for (int i = 0; i < rows_cols.length; i++)
        {
            while (count >= sizes[current_number])
            {
                count = 0;
                current_number++;
            }

            int val = current_number + 1;
            var coords = from_printable_ascii (rows_cols[i]);
            int row = coords[0];
            int col = coords[1];
            cells[row, col].value = val;

            if (count < sizes[current_number])
                count++;
        }

        set_all_fixed ();
    }

    public SudokuBoard.from_json (string path)
        throws IOError
    {
        this ();
        Json.Parser parser = new Json.Parser ();
        try
        {
            parser.load_from_file (path);
        }
        catch (Error e)
        {
            throw new IOError.NOT_FOUND ("Save file doesn't exist");
        }

        Json.Node node = parser.get_root ();
        Json.Reader reader = new Json.Reader (node);
        reader.read_member ("cells");
        ctor_err (!reader.is_array());

        for (var i = 0; i < reader.count_elements (); i++)
        {
            reader.read_element (i);	// Reading a cell

            reader.read_member ("position");
            ctor_err (!reader.is_array() || reader.count_elements() != 2);
            reader.read_element (0);
            ctor_err (!reader.is_value());
            var row = (int) reader.get_int_value ();
            ctor_err (row < 0 || row > 9);
            reader.end_element ();
            reader.read_element (1);
            ctor_err (!reader.is_value());
            var col = (int) reader.get_int_value ();
            ctor_err (col < 0 || col > 9);
            reader.end_element ();
            reader.end_member ();

            reader.read_member ("value");
            ctor_err (!reader.is_value());
            var val = (int) reader.get_int_value ();
            ctor_err (val < 0 || val > 9);
            reader.end_member ();

            reader.read_member ("fixed");
            ctor_err (!reader.is_value());
            var is_fixed = reader.get_boolean_value ();
            reader.end_member ();

            if (val != 0)
                insert (row, col, val, is_fixed);

            reader.read_member ("earmarks");
            ctor_err (!reader.is_array());
            for (var k = 0; k < reader.count_elements (); k++)
            {
                reader.read_element (k);
                ctor_err (!reader.is_value());
                var earmark = (int) reader.get_int_value ();
                ctor_err (earmark < 0 || earmark > 10 || is_earmark_enabled (row, col, earmark));
                enable_earmark (row, col, earmark);
                reader.end_element ();
            }
            reader.end_member ();

            reader.end_element ();
        }
        reader.end_member ();

        reader.read_member ("time_elapsed");
        ctor_err (!reader.is_value());
        previous_played_time = reader.get_double_value ();
        ctor_err (previous_played_time < 0 && previous_played_time != -1);
        reader.end_member ();

        reader.read_member ("difficulty_category");
        ctor_err (!reader.is_value());
        difficulty_category = DifficultyCategory.from_string (reader.get_string_value());
        ctor_err (difficulty_category == DifficultyCategory.UNKNOWN);
        reader.end_member ();
    }

    private static void ctor_err (bool check)
        throws IOError
    {
        if (!check)
            return;
        else
            throw new IOError.NOT_FOUND ("Failed to construct the board");
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

    private int[] get_fixed_cells ()
    {
        int[] ret = new int[rows * cols];

        int i = 0;
        foreach (var cell in cells)
        {
            if (cell.fixed)
                ret[i] = cell.value;
            else
                ret[i] = 0;

            i++;
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
            completed ();
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
            remove_breakages_for (aligned_coords_for_cell[row, col], val);
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

    private void mark_breakages_for (Gee.List<Coord?> coords, int val)
    {
        foreach (Coord coord in coords)
            if (cells[coord.row, coord.col].value == val)
                broken_coords.add (coord);
    }

    public void solve ()
    {
        int[] fixed_cells = get_fixed_cells ();
        int difficulty;

        if (QQwing.solve_puzzle (fixed_cells, out difficulty))
        {
            has_solution = true;
            int i = 0;
            for (var row = 0; row < rows; row++)
                for (var col = 0; col < cols; col++)
                {
                    cells[row, col].solution = fixed_cells[i];
                    i++;
                }

            difficulty_category = (DifficultyCategory) difficulty;
        }
        else
            has_solution = false;
    }

    public unowned bool solved ()
    {
        return has_solution;
    }

    private void remove_breakages_for (Gee.Set<Coord?> coords, int val)
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

    public string fixed_to_string_pretty ()
    {
        var ret = "";
        for (var row = 0; row < rows; row++)
            for (var col = 0; col < cols; col++)
            {
                if (cells[row, col].fixed)
                    ret += cells[row, col].value.to_string ();

                if (ret.length >= 9)
                    return ret;
            }

        return ret;
    }

    public string to_json (double? elapsed_time)
    {
        Json.Builder builder = new Json.Builder ();

        builder.begin_object ();
        builder.set_member_name ("difficulty_category");
        builder.add_string_value (difficulty_category.to_untranslated_string ());

        builder.set_member_name ("time_elapsed");
        if (elapsed_time != null)
            builder.add_double_value (elapsed_time);
        else
            builder.add_double_value (-1);

        builder.set_member_name ("cells");
        builder.begin_array ();
        for (var i = 0; i < rows; i++)
        {
            for (var j = 0; j < cols; j++)
            {
                int[] earmarks = {};
                for (var k = 1; k <= max_val; k++)
                    if (is_earmark_enabled(i, j, k))
                        earmarks += k;

                if (cells[i, j].value == 0 && earmarks.length == 0)
                    continue;

                builder.begin_object ();

                builder.set_member_name ("position");
                builder.begin_array ();
                builder.add_int_value (i);
                builder.add_int_value (j);
                builder.end_array ();

                builder.set_member_name ("value");
                builder.add_int_value (cells[i, j].value);

                builder.set_member_name ("fixed");
                builder.add_boolean_value (get_is_fixed (i, j));

                builder.set_member_name ("earmarks");
                builder.begin_array ();
                foreach (int k in earmarks)
                {
                    builder.add_int_value (k);
                }
                builder.end_array ();

                builder.end_object ();
            }
        }
        builder.end_array ();
        builder.end_object ();

        Json.Generator generator = new Json.Generator ();
        generator.set_pretty (true);
        Json.Node root = builder.get_root ();
        generator.set_root (root);

        return generator.to_data (null);
    }

    public string to_string ()
    {
        var ret = "";
        for (var row = 0; row < rows; row++)
            for (var col = 0; col < cols; col++)
            {
                if (cells[row, col].fixed)
                    ret += cells[row, col].value.to_string ();
                else
                    ret += "0";
            }

        return ret;
    }

    public string to_string_pretty ()
    {
        var ret = "";
        for (var row = 0; row < rows; row++)
        {
            for (var col = 0; col < cols; col++)
            {
                if (cells[row, col].fixed)
                    ret += cells[row, col].value.to_string ();
                else
                    ret += ".";
            }
            ret += "\n";
        }

        return ret;
    }

    public string fixed_to_short_string ()
    {
        var ret = "#";
        ArrayList<int>[] array = new ArrayList<int>[9];
        for (int i = 0; i < 9; i++)
            array[i] = new ArrayList<int>();

        for (int row = 0; row < 9; row++)
            for (int col = 0; col < 9; col++)
            {
                var cell = cells[row, col];
                if (cell.value != 0 && cell.fixed == true)
                    array[cell.value - 1].add (to_printable_ascii (row, col));
            }

        for (int i = 0; i < 5; i++)
        {
            int size1 = array[i * 2].size;
            int size2 = 0;
            if (i != 4)
                size2 = array[i * 2 + 1].size;

            char c = (char) to_printable_ascii (size1, size2);
            ret += c.to_string ();
        }

        foreach (var list in array)
            foreach (var row_col in list)
            {
                char c = (char) row_col;
                ret += c.to_string ();
            }

        return ret;
    }

    private int to_printable_ascii (int val1, int val2)
    {
        return val1 + 33 + val2 * 9;
    }

    private int[] from_printable_ascii (int val)
    {
        var ret = new int[2];
        ret[0] = (val - 33) % 9;
        ret[1] = (val - 33) / 9;
        return ret;
    }

    public bool has_earmarks (int row, int col)
    {
        for (int i = 0; i < 9; i++)
            if (cells[row, col].earmarks[i])
                return true;

        return false;
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
                warning ("Custom difficulty is no longer supported");
                return _("Unknown Difficulty");
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
                warning ("Custom difficulty is no longer supported");
                return "Unknown Difficulty";
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
                warning ("Custom difficulty is no longer supported");
                return UNKNOWN;
            default:
                warning ("Difficulty is not valid");
                return UNKNOWN;
        }
    }
}
