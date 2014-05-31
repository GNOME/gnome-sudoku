/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

public class SudokuGenerator
{
    public int clues = 40;

    public SudokuBoard start_board = new SudokuBoard(3, 3);
    private SudokuBoard temp_start_board = new SudokuBoard(3, 3);

    public struct RatedSudoku {

        public SudokuBoard board;
        public DifficultyRating diff;

        public RatedSudoku(SudokuBoard board, DifficultyRating diff)
        {
            this.board = board;
            this.diff = diff;
        }
    }

    public SudokuGenerator() {
        int solution = 0;
        generate_start_board(-1, -1, -1, -1, ref solution);
    }

    public static void gen_stats ()
    {
        for (int i = 22; i < 77; i++)
        {
            stdout.printf("%d, ", i);
            for (int repeat = 0; repeat < 50; repeat++)
            {
                stdout.printf("repeat %d\n", repeat);
                SudokuGenerator gen = new SudokuGenerator();
                gen.clues = i;


                RatedSudoku? rated_sudoku = gen.make_unique_puzzle(Random.int_range(0, 4), true);
                while (true) {
                    if (rated_sudoku == null)
                        gen.make_unique_puzzle(Random.int_range(0, 4), true);
                    else
                        break;
                }

                /*SudokuBoard board = gen.make_symmetric_puzzle (Random.int_range(0, 4));
                while (true)
                {
                    SudokuBoard test_board = board.clone ();

                    SudokuSolver test_solver = new SudokuSolver(ref test_board);
                    if (test_solver.quick_has_unique_solution ())
                        break;
                }*/

                stdout.printf("%f, ", rated_sudoku.diff.rating);
            }
            stdout.printf("\n");
        }
    }

    public SudokuBoard generate (float[] difficulty_range, bool symmetric = true)
    {
        int count = 0;

        do {
            float skew = 0.0f;

            clues = get_cells_for ((float) Random.double_range((double) difficulty_range[0], (double) difficulty_range[1]));

            if (clues < 17)
                clues = 17;

            if (clues > 60)
                clues = 60;

            if (count >= 10 && count % 10 == 0)
            {
                int solution = 0;
                generate_start_board(-1, -1, -1, -1, ref solution);
            }

            //stdout.printf("Generating with %d clues\n", clues);

            SudokuBoard puzzle;

            if (symmetric) {
                RatedSudoku rated_sudoku = make_unique_puzzle (GLib.Random.int_range(0, 3));

                if (rated_sudoku.board != null && rated_sudoku.diff.in_range(difficulty_range))
                    return rated_sudoku.board;
            } else {
                puzzle = make_puzzle_by_boxes (skew);
            }

            count++;
        } while (count < 100);

        stdout.printf ("Puzzle not found..\n");

        return new SudokuBoard(3, 3);
    }

    private int get_cells_for (float difficulty)
    {
        return (int) ((-22.3275863216 * difficulty) + 44.9652207631);
    }

    private void generate_start_board (int row, int col, int no, int filled, ref int solution)
    {
        if (filled == -1)
            filled = temp_start_board.filled;

        if (filled == temp_start_board.rows * temp_start_board.cols)
        {
            solution++;
            for (var y = 0; y < 9; y++)
            {
                for (var x = 0; x < 9; x++)
                {
                    start_board.insert (x, y, temp_start_board[x, y]);
                }
            }
            return;
        }

        if (row == -1 || col == -1)
        {
            for (var l1 = 0; l1 < temp_start_board.rows; l1++)
            {
                for (var l2 = 0;l2 < temp_start_board.cols; l2++)
                {
                    if (temp_start_board[l1, l2] == 0)
                    {
                        generate_start_board (l1, l2, no, filled, ref solution);
                        return;
                    }
                }
            }
        }

        if (no == -1)
        {
            bool[] values_tried = new bool[temp_start_board.max_val];
            int values_tried_count = 0;
            while (values_tried_count < temp_start_board.max_val)
            {
                // Find a value that has not been tried yet
                int l1 = -1;
                do {
                    l1 = GLib.Random.int_range(0, temp_start_board.max_val) + 1;
                } while (values_tried[l1]);

                values_tried_count++;

                if (temp_start_board.is_possible (row, col, l1))
                {
                    generate_start_board (row, col, l1, filled, ref solution);

                    if (solution > 0)
                        return;
                }
            }
            return;
        }

        temp_start_board.insert (row, col, no);
        generate_start_board (-1, -1, -1, filled + 1, ref solution);
        temp_start_board.remove (row, col);
    }

    public SudokuBoard make_symmetric_puzzle (int line)
    {
        SudokuBoard new_puzzle = new SudokuBoard(3, 3);

        while (new_puzzle.filled < clues) {
            int row = GLib.Random.int_range(0, 9);
            int col = GLib.Random.int_range(0, 9);

            if (!new_puzzle.is_fixed[row, col]) {

                Coord reflection = reflect(row, col, line);

                new_puzzle.insert(row, col, start_board[row, col], true);

                if (reflection.row == row && reflection.col == col)
                    continue; // Skip as the reflection is itself

                new_puzzle.insert(reflection.row, reflection.col, start_board[reflection.row, reflection.col], true);
            }

        }
        return new_puzzle;
    }

    private Coord reflect(int row, int col, int line)
    {
        if (line == 0) // Vertical, through the middle
        {
            return Coord(row, 8 - col);
        }
        else if (line == 1) // From bottom right to top left
        {
            return Coord(8 - col, 8 - row);
        }
        else if (line == 2) // Horizontal through the middle
        {
            return Coord(8 - row, col);
        }
        else if (line == 3) // From top left to bottom right
        {
            return Coord(8 - row, 8 - col);
        }
        else
        {
            return Coord(row, col);
        }
    }

    /*  Make a puzzle paying attention to evenness of clue
        distribution.

        If skew_by is 0, we distribute our clues as evenly as possible
        across boxes.  If skew by is 1.0, we make the distribution of
        clues as uneven as possible. In other words, if we had 27
        boxes for a 9x9 grid, a skew_by of 0 would put exactly 3 clues
        in each 3x3 grid whereas a skew_by of 1.0 would completely
        fill 3 3x3 grids with clues.

        We believe this skewing may have something to do with how
        difficult a puzzle is to solve. By toying with the ratios,
        this method may make it considerably easier to generate
        difficult or easy puzzles.
    */
    public SudokuBoard make_puzzle_by_boxes (float skew_by = 0.0f) {
        SudokuBoard new_puzzle = new SudokuBoard(3, 3);

        // Number of total boxes
        int nboxes = 9; // TODO: Fix
        // If no max is given, we calculate one based on our skew_by --
        // a skew_by of 1 will always produce full squares, 0 will
        // produce the minimum fullness, and between between in
        // proportion to its betweenness.
        int max_squares = clues / nboxes;
        max_squares += (int) ((nboxes - max_squares) * skew_by);
        int clued = 0;
        // nclues will be a list of the number of clues we want per
        // box, counting from the top left, along, and wraping.
        //  _ _ _
        // |0|1|2|
        // |3|4|5|
        // |6|7|8|
        //  - - -

        int[] nclues = new int[nboxes];
        for (int n = 0; n < nboxes; n++) {
            // Make sure we'll have enough clues to fill our target
            // number, regardless of our calculation of the current max

            // TODO: The following code (directly translated from python) does nothing?
            // int minimum = (this.clues - clued) / (nboxes - n);
            //if (max_squares < minimum) {
            //    cls = minimum
            //} else {
            //    cls = int(max_squares)
            //}
            int clues = max_squares;
            if (clues > (this.clues - clued)) {
                clues = this.clues - clued;
            }
            nclues[n] = clues;

            clued += clues;
            if (skew_by != 0) {
                // Reduce our number of squares proportionally to
                // skewiness.
                max_squares = (int) GLib.Math.round(max_squares * skew_by);
            }
        }

        // shuffle ourselves... probably badly (TODO)
        for (int i=0; i<nboxes; i++) {
            int from = GLib.Random.int_range(0, nboxes);
            int to = GLib.Random.int_range(0, nboxes);

            int temp = nclues[to];
            nclues[to] = nclues[from];
            nclues[from] = temp;
        }

        for (int i = 0; i < nboxes; i++) {
            while (nclues[i] > 0) {
                int base_x = (i % new_puzzle.block_cols) * new_puzzle.block_cols;
                int base_y = (i / new_puzzle.block_rows) * new_puzzle.block_rows;

                int x = GLib.Random.int_range(base_x, base_x + new_puzzle.block_rows);
                int y = GLib.Random.int_range(base_y, base_y + new_puzzle.block_cols);

                if (!new_puzzle.is_fixed[x, y]) {
                    new_puzzle.insert(x, y, start_board[x, y], true);
                    nclues[i]--;
                }
            }
        }
        return new_puzzle;
    }

    public RatedSudoku? make_unique_puzzle (int line = -1, bool strict_number_of_clues = false)
    {
        SudokuBoard board;
        DifficultyRating diff;

        if (line != -1)
        {
            int old_clues = clues;
            clues = 4;
            board = make_symmetric_puzzle (line);
            clues = old_clues;
            //stdout.printf("made a board with %d clues\n", board.filled);
        }
        else
        {
            board = make_puzzle_by_boxes ();
        }

        while (true)
        {
            SudokuBoard solved_board = board.clone ();
            SudokuRater solver = new SudokuRater(ref solved_board);
            if (solver.has_unique_solution())
            {
                //stdout.printf("unique solution found\n");
                diff = solver.get_difficulty();
                break;
            }
            //stdout.printf("no unique solution found\n");

            //board.print ();

            //stdout.printf("possible solutions\n");

            /*SudokuBoard solved_board_two = board.clone ();
            SudokuRater solver_two = new SudokuRater(ref solved_board_two);

            int solutions = solver_two.quick_count_solutions ();
            if (solutions < 5)
            {
                foreach (SudokuBoard solution in solver_two)
                {
                    solution.print ();
                    stdout.printf("\n");
                }
            }
            else
            {
                stdout.printf("have %d solutions\n", solutions);
            }*/

            for (int i = 0; i < solver.breadcrumbs.size; i++)
            {
                Guess guess = solver.breadcrumbs[i];
                //stdout.printf("crumb (%d, %d) %d\n", guess.col, guess.row, guess.val);
            }

            // Otherwise...
            Guess crumb = solver.breadcrumbs[solver.breadcrumbs.size - 1];
            // stdout.printf("got crumb (%d, %d) %d\n", crumb.col, crumb.row, crumb.val);

            board.insert (crumb.row, crumb.col, start_board[crumb.row, crumb.col], true);

            Coord reflection = reflect(crumb.row, crumb.col, line);

            board.insert (reflection.row, reflection.col, start_board[reflection.row, reflection.col], true);

            //stdout.printf("Not unique, filling in (%d, %d) and (%d, %d)\n", crumb.row, crumb.col, reflection.row, reflection.col);

            if (strict_number_of_clues && board.filled > clues)
            {
                //stdout.printf("failed to get the number of clues, instead got %d\n", board.filled);
                return null;
            }
            //stdout.printf("trying again\n");
        }

        // make sure we have the proper number of clues
        if (strict_number_of_clues)
        {
            //stdout.printf("checking the number of clues\n");
            bool changed = false;
            while (board.filled < clues)
            {
                int row = -1;
                int col = -1;
                do
                {
                    row = Random.int_range(0, 9);
                    col = Random.int_range(0, 9);
                }
                while (board[row, col] == 0);

                board.insert (row, col, start_board[row, col], true);

                Coord reflection = reflect(row, col, line);
                board.insert (reflection.row, reflection.col, start_board[reflection.row, reflection.col], true);

                changed = true;
            }
            if (changed)
                diff = new SudokuRater(ref board).get_difficulty();
        }
        //stdout.printf("returning rated puzzle\n");
        return RatedSudoku(board, diff);
    }
}
