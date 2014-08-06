/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gee;

public class SudokuStore : Object
{
    private ArrayList<SudokuBoard> simple_boards = new ArrayList<SudokuBoard> ();
    private ArrayList<SudokuBoard> easy_boards = new ArrayList<SudokuBoard> ();
    private ArrayList<SudokuBoard> intermediate_boards = new ArrayList<SudokuBoard> ();
    private ArrayList<SudokuBoard> expert_boards = new ArrayList<SudokuBoard> ();

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

                    simple_boards.add(board);
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

                    easy_boards.add(board);
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

                    intermediate_boards.add(board);
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

                    expert_boards.add(board);
                }
            }
        } catch (Error e) {
            error ("%s", e.message);
        }
    }

    public SudokuBoard get_random_simple_board()
    {
        return simple_boards[Random.int_range(0, simple_boards.size)];
    }

    public SudokuBoard get_random_easy_board()
    {
        return easy_boards[Random.int_range(0, easy_boards.size)];
    }

    public SudokuBoard get_random_intermediate_board()
    {
        return intermediate_boards[Random.int_range(0, intermediate_boards.size)];
    }

    public SudokuBoard get_random_expert_board()
    {
        return expert_boards[Random.int_range(0, expert_boards.size)];
    }

    public SudokuBoard get_random_board(DifficultyCategory category)
    {
        if (category == DifficultyCategory.SIMPLE)
            return get_random_simple_board();
        else if (category == DifficultyCategory.EASY)
            return get_random_easy_board();
        else if (category == DifficultyCategory.INTERMEDIATE)
            return get_random_intermediate_board();
        else if (category == DifficultyCategory.EXPERT)
            return get_random_expert_board();
        else
            assert_not_reached();
    }

    // Get boards sorted ascending based on difficulty rating
    // i.e. - the first board returned will be the easiest, and boards will become increasingly harder
    public SudokuBoard[] get_boards_sorted (int number_of_boards, DifficultyCategory level, bool exclude_finished = false)
    {
        var boards = new ArrayList<SudokuBoard> ();
        SudokuBoard[] boards_array = {};

        while (boards.size < number_of_boards)
        {
            var board = get_random_board (level);
            if (exclude_finished && board.is_finished ())
                continue;
            boards.add (board);
        }

        foreach (SudokuBoard board in boards)
            boards_array += board;

        return boards_array;
    }
}
