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

public class SudokuGame : Object
{
    public SudokuBoard board;
    public GLib.Timer timer;
    private uint clock_timeout;

    public signal void tick ();
    public signal void paused_changed ();

    private bool _paused = false;
    public bool paused
    {
        private set
        {
            _paused = value;
            paused_changed ();
        }
        get { return _paused; }
    }

    private struct UndoItem
    {
        public int row;
        public int col;
        public int val;
    }

    public signal void cell_changed (int row, int col, int old_val, int new_val);

    private ArrayList<UndoItem?> undostack;
    private ArrayList<UndoItem?> redostack;

    public bool is_undostack_null ()
    {
        return undostack.size == 0;
    }

    public bool is_redostack_null ()
    {
        return redostack.size == 0;
    }

    public SudokuGame (SudokuBoard board)
    {
        this.board = board;
        timer = new Timer();
        undostack = new ArrayList<UndoItem?> ();
        redostack = new ArrayList<UndoItem?> ();
        board.completed.connect (() => stop_clock ());
    }

    public void insert (int row, int col, int val)
    {
        var old_val = board[row, col];
        update_undo (row, col, old_val, val);
        board.insert (row, col, val);
        cell_changed (row, col, old_val, val);
    }

    public void remove (int row, int col)
    {
        int old_val = board[row, col];
        update_undo (row, col, old_val, 0);
        board.remove (row, col);
        cell_changed (row, col, old_val, 0);
    }

    public void undo ()
    {
        apply_stack (ref undostack, ref redostack);
    }

    public void redo ()
    {
        apply_stack (ref redostack, ref undostack);
    }

    public void reset ()
    {
        board.previous_played_time = 0;
        timer.start ();
        undostack.clear ();
        redostack.clear ();
        for (var l1 = 0; l1 < board.rows; l1++)
        {
            for (var l2 = 0; l2 < board.cols; l2++)
            {
                if (!board.is_fixed[l1, l2])
                {
                    board.remove (l1, l2);
                    cell_changed (l1, l2, board.get (l1, l2), 0);
                }
            }
        }
        board.broken_coords.clear ();
    }

    public void cell_changed_cb (int row, int col, int old_val, int new_val)
    {
        cell_changed (row, col, old_val, new_val);
    }

    public void update_undo (int row, int col, int old_val, int new_val)
    {
        add_to_stack (ref undostack, row, col, old_val);
        redostack.clear ();
    }

    private void add_to_stack (ref ArrayList<UndoItem?> stack, int r, int c, int v)
    {
        UndoItem step = { r, c, v };
        stack.add (step);
    }

    private void apply_stack (ref ArrayList<UndoItem?> from, ref ArrayList<UndoItem?> to)
    {
        if (from.size == 0)
            return;

        var top = from.remove_at (from.size - 1);
        int old_val = board [top.row, top.col];
        add_to_stack (ref to, top.row, top.col, old_val);
        board.remove (top.row, top.col);
        if (top.val != 0)
            board.insert (top.row, top.col, top.val);
        cell_changed (top.row, top.col, old_val, top.val);
    }

    public double get_total_time_played ()
    {
        return board.previous_played_time + timer.elapsed ();
    }

    private bool timeout_cb ()
    {
        /* Notify on the next tick */
        var elapsed = get_total_time_played ();
        var next = (int) (elapsed + 1.0);
        var wait = next - elapsed;
        clock_timeout = Timeout.add_seconds ((int) (wait), timeout_cb);

        tick ();

        return false;
    }

    public void start_clock ()
    {
        if (timer == null)
            timer = new Timer ();
        timer.start ();
        timeout_cb ();
    }

    public void stop_clock ()
    {
        if (timer == null)
            return;
        if (clock_timeout != 0)
            Source.remove (clock_timeout);
        paused = true;
        clock_timeout = 0;
        timer.stop ();
        tick ();
    }

    public void continue_clock ()
    {
        if (timer == null)
            timer = new Timer ();
        else
            timer.continue ();
        paused = false;
        timeout_cb ();
    }
}
