/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

public class SudokuGenerator : Object
{
    public SudokuGenerator () {
    }

    public SudokuBoard generate (DifficultyCategory category)
    {
        stdout.printf ("Generating a puzzle of difficulty %s ...\n\n", category.to_string ());

        var board = new SudokuBoard ();
        int[] puzzle = QQwing.generate_puzzle ((int) category + 1);
        stdout.printf ("puzzle length = %d\n", puzzle.length);

//        assert (puzzle.length >= board.rows * board.cols);

        stdout.printf ("\n");
        for (var j = 0; j < 81; j++)
            stdout.printf ("%d", puzzle[j]);
        stdout.printf ("\n");

        for (var row = 0; row < board.rows; row++)
        {
            for (var col = 0; col < board.cols; col++)
            {
                var val = puzzle[(row * board.cols) + col];
                if (val != 0)
                    board.insert (row, col, val, true);
            }
        }
        board.difficulty_rating = 0;

        return board;
    }

    public void print_stats (SudokuBoard board)
    {
        var cells = board.get_cells ();
        var puzzle = new int[board.rows * board.cols];

        for (var row = 0; row < board.rows; row++)
            for (var col = 0; col < board.cols; col++)
                puzzle[(row * board.cols) + col] = cells[row, col];

        QQwing.print_stats (puzzle);
    }
}
