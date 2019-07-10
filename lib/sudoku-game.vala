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

public class SudokuGame : Object
{
    public SudokuBoard board;
    public GameMode mode;
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
        public bool[] earmarks;
    }

    public signal void cell_changed (int row, int col, int old_val, int new_val);

    private Gee.List<UndoItem?> undostack;
    private Gee.List<UndoItem?> redostack;

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
        this.mode = GameMode.PLAY;
        timer = new Timer();
        undostack = new ArrayList<UndoItem?> ();
        redostack = new ArrayList<UndoItem?> ();
    }

    public void enable_earmark (int row, int col, int k_no)
    {
        var old_val = board[row, col];
        var old_earmarks = board.get_earmarks (row, col);
        update_undo (row, col, old_val, old_earmarks);

        board.enable_earmark (row, col, k_no);
    }

    public void disable_earmark (int row, int col, int k_no)
    {
        var old_val = board[row, col];
        var old_earmarks = board.get_earmarks (row, col);
        update_undo (row, col, old_val, old_earmarks);

        board.disable_earmark (row, col, k_no);
    }

    public void insert (int row, int col, int val)
    {
        var old_val = board[row, col];
        var old_earmarks = board.get_earmarks (row, col);
        update_undo (row, col, old_val, old_earmarks);

        if (mode == GameMode.CREATE)
        {
            board.insert (row, col, val, true);
            board.is_fixed[row, col] = true;
        }
        else
            board.insert (row, col, val);

        cell_changed (row, col, old_val, val);
    }

    public void remove (int row, int col)
    {
        var old_val = board[row, col];
        var old_earmarks = board.get_earmarks (row, col);
        update_undo (row, col, old_val, old_earmarks);

        if (mode == GameMode.CREATE)
        {
            board.remove (row, col, true);
            board.is_fixed[row, col] = false;
        }
        else
            board.remove (row, col);

        cell_changed (row, col, old_val, 0);
    }

    public bool is_empty ()
    {
        if (mode == GameMode.CREATE)
            return board.filled == 0;
        else
            return board.is_empty ();
    }

    public void undo ()
    {
        apply_stack (undostack, redostack);
    }

    public void redo ()
    {
        apply_stack (redostack, undostack);
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
                if (mode == GameMode.PLAY && board.is_fixed[l1, l2])
                    continue;

                board.remove (l1, l2, board.is_fixed[l1, l2]);
                board.is_fixed[l1, l2] = false;
                cell_changed (l1, l2, board.get (l1, l2), 0);
            }
        }
        board.broken_coords.clear ();
    }

    public void cell_changed_cb (int row, int col, int old_val, int new_val)
    {
        cell_changed (row, col, old_val, new_val);
    }

    public void update_undo (int row, int col, int old_val, bool[] old_earmarks)
    {
        add_to_stack (undostack, row, col, old_val, old_earmarks);
        redostack.clear ();
    }

    private void add_to_stack (Gee.List<UndoItem?> stack, int r, int c, int v, bool[] e)
    {
        UndoItem step = { r, c, v, e };
        stack.add (step);
    }

    private void apply_stack (Gee.List<UndoItem?> from, Gee.List<UndoItem?> to)
    {
        if (from.size == 0)
            return;

        var top = from.remove_at (from.size - 1);
        int old_val = board [top.row, top.col];
        bool[] old_earmarks = board.get_earmarks (top.row, top.col);
        add_to_stack (to, top.row, top.col, old_val, old_earmarks);

        if (mode == GameMode.CREATE)
        {
            board.remove (top.row, top.col, board.is_fixed[top.row, top.col]);
            board.is_fixed[top.row, top.col] = false;
        }
        else
            board.remove (top.row, top.col);

        if (top.val != 0)
        {
            if (mode == GameMode.CREATE)
            {
                board.insert (top.row, top.col, top.val, board.is_fixed[top.row, top.col]);
                board.is_fixed[top.row, top.col] = true;
            }
            else
                board.insert (top.row, top.col, top.val);
        }

        for (var i = 1; i <= top.earmarks.length; i++)
        {
            if (top.earmarks[i-1])
                board.enable_earmark (top.row, top.col, i);
            else
                board.disable_earmark (top.row, top.col, i);
        }

        cell_changed (top.row, top.col, old_val, top.val);
    }

    public double get_total_time_played ()
    {
        return board.previous_played_time + timer.elapsed ();
    }

    private bool timeout_cb ()
    {
        clock_timeout = Timeout.add_seconds (1, timeout_cb);
        Source.set_name_by_id (clock_timeout, "[gnome-sudoku] timeout_cb");
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
        requires (timer != null)
    {
        if (clock_timeout != 0)
            Source.remove (clock_timeout);
        clock_timeout = 0;
        paused = true;
        timer.stop ();
        tick ();
    }

    public void resume_clock ()
        requires (timer != null && clock_timeout == 0)
    {
        timer.continue ();
        paused = false;
        timeout_cb ();
    }
}

public enum GameMode
{
    PLAY,
    CREATE;
}
