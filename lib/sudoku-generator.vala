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

public class SudokuGenerator : Object
{
    public class GeneratorThread : Object
    {
        private int nsudokus;
        private DifficultyCategory level;
        private Gee.List<SudokuBoard> boards_list;
        private unowned SourceFunc callback;

        public GeneratorThread (int nsudokus, DifficultyCategory level, Gee.List<SudokuBoard> boards_list, SourceFunc callback)
        {
            this.nsudokus = nsudokus;
            this.level = level;
            this.boards_list = boards_list;
            this.callback = callback;
        }

        public void* run ()
        {
            for (var i = 0; i < nsudokus; i++)
                boards_list.add (SudokuGenerator.generate_board (level));

            Idle.add(() => {
                callback ();
                return Source.REMOVE;
            });

            return null;
        }
    }

    private SudokuGenerator () {
    }

    private static SudokuBoard generate_board (DifficultyCategory category)
    {
        var board = new SudokuBoard ();
        int[] puzzle = QQwing.generate_puzzle ((int) category);

        for (var row = 0; row < board.rows; row++)
            for (var col = 0; col < board.cols; col++)
            {
                var val = puzzle[(row * board.cols) + col];
                if (val != 0)
                    board.insert (row, col, val, true);
            }
        board.difficulty_category = category;

        return board;
    }

    public async static SudokuBoard[] generate_boards_async (int nboards, DifficultyCategory category) throws ThreadError
    {
        var boards_list = new ArrayList<SudokuBoard> ();
        var boards = new SudokuBoard[nboards];
        var threads = new ArrayList<Thread<void*>> ();

        var ncpu_usable = int.max (1, (int) get_num_processors () - 1);
        var nthreads = int.min (ncpu_usable, nboards);
        var base_nsudokus_each = nboards / nthreads;
        var remainder = nboards % nthreads;
        var nsudokus_per_thread = base_nsudokus_each;

        for (var i = 0; i < nthreads; i++)
        {
            if (i > (nthreads - remainder - 1))
                nsudokus_per_thread = base_nsudokus_each + 1;
            var gen_thread = new GeneratorThread (nsudokus_per_thread, category, boards_list, generate_boards_async.callback);
            threads.add (new Thread<void*> ("Generator thread", gen_thread.run));
        }

        // Relinquish the CPU, so that the generated threads can run
        for (var i = 0; i < nthreads; i++)
        {
            yield;
            threads.get(i).join ();
        }

        for (var i = 0; i < boards_list.size; i++)
            boards[i] = boards_list[i];
        return boards;
    }

    public static void print_stats (SudokuBoard board)
    {
        var cells = board.get_cells ();
        var puzzle = new int[board.rows * board.cols];

        for (var row = 0; row < board.rows; row++)
            for (var col = 0; col < board.cols; col++)
                puzzle[(row * board.cols) + col] = cells[row, col];

        QQwing.print_stats (puzzle);
    }

    public static string qqwing_version ()
    {
        return QQwing.get_version ();
    }
}
