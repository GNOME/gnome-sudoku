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

    public SudokuBoard get_random_board(DifficultyCategory category)
    {
        if (category == DifficultyCategory.EASY)
            return get_random_easy_board();
        else if (category == DifficultyCategory.MEDIUM)
            return get_random_medium_board();
        else if (category == DifficultyCategory.HARD)
            return get_random_hard_board();
        else if (category == DifficultyCategory.VERY_HARD)
            return get_random_very_hard_board();
        else
            assert_not_reached();
    }

    // Get boards sorted ascending based on difficulty rating
    // i.e. - the first board returned will be the easiest, and boards will become increasingly harder
    public SudokuBoard[] get_boards_sorted (int number_of_boards, DifficultyCategory level, bool exclude_finished = false)
    {
        var boards = new ArrayList<SudokuBoard> ();
        SudokuBoard[] sorted_boards = {};

        while (boards.size < number_of_boards)
        {
            var board = get_random_board (level);
            if (exclude_finished && board.is_finished ())
                continue;
            boards.add (board);
        }

        boards.sort ((a, b) => {
            if (a.difficulty_rating > b.difficulty_rating)
                return 1;
            if (a.difficulty_rating == b.difficulty_rating)
                return 0;
            return -1;
        });

        foreach (SudokuBoard board in boards)
            sorted_boards += board;

        return sorted_boards;
    }
}
