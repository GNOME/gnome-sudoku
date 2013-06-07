using Gee;

class SudokuStore
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
                    board.set_from_string(line[0:161], " ");

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
                    board.set_from_string(line[0:161], " ");

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
                    board.set_from_string(line[0:161], " ");

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
                    board.set_from_string(line[0:161], " ");

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
}
