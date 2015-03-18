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
    private class Worker : Object
    {
        private int nsudokus;
        private DifficultyCategory level;
        // FIXME Require Gee.ConcurrentList and remove the mutex
        // https://bugzilla.gnome.org/show_bug.cgi?id=737507
        private Gee.List<SudokuBoard> boards_list;
        private static Mutex mutex;
        private unowned SourceFunc callback;

        public Worker (int nsudokus, DifficultyCategory level, Gee.List<SudokuBoard> boards_list, SourceFunc callback)
        {
            this.nsudokus = nsudokus;
            this.level = level;
            this.boards_list = boards_list;
            this.callback = callback;
        }

        public void run ()
        {
            // Generating a board takes a relatively long time.
            var board = SudokuGenerator.generate_board (level);
            mutex.lock ();
            boards_list.add (board);
            if (boards_list.size == nsudokus)
            {
                // We've added the final board to the list.
                // Finish the call to generate_boards_async.
                Idle.add (() => {
                    callback ();
                    return Source.REMOVE;
                });
            }
            mutex.unlock ();
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

    public async static Gee.List<SudokuBoard> generate_boards_async (int nboards, DifficultyCategory category, Cancellable? cancellable) throws ThreadError, IOError
    {
        var boards = new ArrayList<SudokuBoard> ();
        var pool = new ThreadPool<Worker>.with_owned_data ((worker) => {
            worker.run ();
        }, (int) get_num_processors (), false);

        cancellable.connect(() => {
            ThreadPool.free((owned) pool, true, false);
            generate_boards_async.callback();
        });

        for (var i = 0; i < nboards; i++)
        {
            pool.add (new Worker (nboards, category, boards, generate_boards_async.callback));
        }

        yield;

        cancellable.set_error_if_cancelled ();
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
