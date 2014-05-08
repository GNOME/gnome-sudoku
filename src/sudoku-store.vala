/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gee;

public class SudokuStore
{
    private ArrayList<SudokuBoard> easy_boards = new ArrayList<SudokuBoard> ();
    private ArrayList<SudokuBoard> medium_boards = new ArrayList<SudokuBoard> ();
    private ArrayList<SudokuBoard> hard_boards = new ArrayList<SudokuBoard> ();
    private ArrayList<SudokuBoard> very_hard_boards = new ArrayList<SudokuBoard> ();

    public SudokuStore () {
        try {
            { // Easy boards
                var file = File.new_for_uri ("resource:///org/gnome/gnome-sudoku/puzzles/easy");

                var dis = new DataInputStream (file.read ());

                string line;
                // Read lines until end of file (null) is reached
                while ((line = dis.read_line (null)) != null) {
                    SudokuBoard board = new SudokuBoard();
                    board.set_from_string(line, " ");

                    easy_boards.add(board);
                }
            }

            { // Medium boards
                var file = File.new_for_uri ("resource:///org/gnome/gnome-sudoku/puzzles/medium");

                var dis = new DataInputStream (file.read ());

                string line;
                // Read lines until end of file (null) is reached
                while ((line = dis.read_line (null)) != null) {
                    SudokuBoard board = new SudokuBoard();
                    board.set_from_string(line, " ");

                    medium_boards.add(board);
                }
            }

            { // Hard boards
                var file = File.new_for_uri ("resource:///org/gnome/gnome-sudoku/puzzles/hard");

                var dis = new DataInputStream (file.read ());

                string line;
                // Read lines until end of file (null) is reached
                while ((line = dis.read_line (null)) != null) {
                    SudokuBoard board = new SudokuBoard();
                    board.set_from_string(line, " ");

                    hard_boards.add(board);
                }
            }

            { // Very hard boards
                var file = File.new_for_uri ("resource:///org/gnome/gnome-sudoku/puzzles/very_hard");

                var dis = new DataInputStream (file.read ());

                string line;
                // Read lines until end of file (null) is reached
                while ((line = dis.read_line (null)) != null) {
                    SudokuBoard board = new SudokuBoard();
                    board.set_from_string(line, " ");

                    very_hard_boards.add(board);
                }
            }
        } catch (Error e) {
            error ("%s", e.message);
        }
    }

    public SudokuBoard get_random_easy_board()
    {
        return easy_boards[Random.int_range(0, easy_boards.size)];
    }

    public SudokuBoard get_random_medium_board()
    {
        return medium_boards[Random.int_range(0, medium_boards.size)];
    }

    public SudokuBoard get_random_hard_board()
    {
        return hard_boards[Random.int_range(0, hard_boards.size)];
    }

    public SudokuBoard get_random_very_hard_board()
    {
        return very_hard_boards[Random.int_range(0, very_hard_boards.size)];
    }

    public SudokuBoard get_random_board(DifficultyCatagory catagory)
    {
        if (catagory == DifficultyCatagory.EASY)
            return get_random_easy_board();
        else if (catagory == DifficultyCatagory.MEDIUM)
            return get_random_medium_board();
        else if (catagory == DifficultyCatagory.HARD)
            return get_random_hard_board();
        else if (catagory == DifficultyCatagory.VERY_HARD)
            return get_random_very_hard_board();
        else
            assert_not_reached();
    }

    public ArrayList<SudokuBoard> get_assorted_boards(int n, owned DifficultyCatagory[] levels, bool exclude_finished = false)
    {
        var boards = new ArrayList<SudokuBoard> ();
        int i = 0;

        if (levels.length == 0)
            levels = {DifficultyCatagory.EASY, DifficultyCatagory.MEDIUM, DifficultyCatagory.HARD, DifficultyCatagory.VERY_HARD};

        while (i < n)
        {
            var board = get_random_board ((DifficultyCatagory) levels[i % levels.length]);
            if (exclude_finished && board.is_finished ())
                continue;
            boards.add (board);
            i++;
        }

        CompareDataFunc<SudokuBoard> CompareDifficultyRatings = (a, b) => {
            if (a.difficulty_rating > b.difficulty_rating)
                return 1;
            if (a.difficulty_rating == b.difficulty_rating)
                return 0;
            return -1;
        };

        boards.sort (CompareDifficultyRatings);
        return boards;
    }
}
