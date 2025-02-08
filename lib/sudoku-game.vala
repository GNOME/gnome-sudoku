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
    public SudokuBoard board { get; private set; }
    public GameMode mode { get; set; }
    private GLib.Timer timer;
    private uint clock_timeout;

    public signal void tick ();
    public signal void paused_changed ();
    public signal void action_completed (StackAction action);

    private bool _paused = false;
    public bool paused
    {
        public set
        {
            _paused = value;
            paused_changed ();
        }
        get { return _paused; }
    }

    private struct earmark_change
    {
        public int row;
        public int col;
        public int number;
        public bool enabled;
    }

    private struct value_change
    {
        public int row;
        public int col;
        public int old_val;
        public int new_val;
    }

    private class stack_item
    {
        public Gee.ArrayList<earmark_change?> earmarks;
        public Gee.ArrayList<value_change?> values;
        public StackAction action;
        public stack_item (StackAction _action)
        {
            this.action = _action;
            earmarks = new ArrayList<earmark_change?>();
            values = new ArrayList<value_change?>();
        }
    }

    private ArrayList<stack_item?> stack;
    private int stack_head_index = -1;

    public bool is_undostack_null ()
    {
        return stack_head_index == -1;
    }

    public bool is_redostack_null ()
    {
        return stack_head_index == stack.size - 1;
    }

    public SudokuGame (SudokuBoard board)
    {
        this.board = board;
        this.mode = GameMode.NONE;
        timer = new Timer();
        stack = new ArrayList<stack_item?>();
    }

    public void enable_earmark (int row, int col, int num)
    {
        var new_stack_item = new stack_item (StackAction.ENABLE_EARMARK);
        add_to_stack (new_stack_item);

        add_earmark_step (new_stack_item, row, col, num, true);
        board.enable_earmark (row, col, num);

        action_completed (new_stack_item.action);
    }

    public void disable_earmark (int row, int col, int num)
    {
        var new_stack_item = new stack_item (StackAction.DISABLE_EARMARK);
        add_to_stack (new_stack_item);

        add_earmark_step (new_stack_item, row, col, num, false);
        board.disable_earmark (row, col, num);

        action_completed (new_stack_item.action);
    }

    public void disable_all_earmarks (int row, int col)
    {
        var new_stack_item = new stack_item (StackAction.DISABLE_ALL_EARMARKS);
        add_to_stack (new_stack_item);

        add_disable_earmarks_step (new_stack_item, row, col);
        board.disable_all_earmarks (row, col);

        action_completed (new_stack_item.action);
    }

    public void insert (int row, int col, int val)
    {
        var old_val = board[row, col];

        var new_stack_item = new stack_item (StackAction.INSERT);
        add_to_stack (new_stack_item);

        if (board.has_earmarks (row, col))
        {
            add_disable_earmarks_step (new_stack_item, row, col);
            board.disable_all_earmarks (row, col);
        }

        add_value_step (new_stack_item, row, col, old_val, val);
        board.insert (row, col, val);

        action_completed (new_stack_item.action);
    }

    public void remove (int row, int col)
    {
        var old_val = board[row, col];

        var new_stack_item = new stack_item (StackAction.REMOVE);
        add_to_stack (new_stack_item);

        add_value_step (new_stack_item, row, col, old_val, 0);
        board.remove (row, col);

        action_completed (new_stack_item.action);
    }

    public void insert_and_disable_related_earmarks (int row, int col, int val){
        var old_val = board[row, col];
        var new_stack_item = new stack_item (StackAction.INSERT_AND_DISABLE_RELATED_EARMARKS);
        add_to_stack (new_stack_item);

        for (var col_tmp = 0; col_tmp < board.cols; col_tmp++)
            for (var row_tmp = 0; row_tmp < board.rows; row_tmp++)
            {
                if (row_tmp == row && col_tmp == col)
                    continue;

                if ((row_tmp == row || col_tmp == col ||
                   (row_tmp / board.block_cols == row / board.block_cols &&
                   col_tmp / board.block_rows == col / board.block_rows)) &&
                   board.is_earmark_enabled (row_tmp, col_tmp, val))
                {
                    add_earmark_step (new_stack_item, row_tmp, col_tmp, val, false);
                    board.disable_earmark (row_tmp, col_tmp, val);
                }
            }

        if (new_stack_item.earmarks.size == 0)
            new_stack_item.action = StackAction.INSERT;

        if (board.has_earmarks (row, col))
        {
            add_disable_earmarks_step (new_stack_item, row, col);
            board.disable_all_earmarks (row, col);
        }

        add_value_step (new_stack_item, row, col, old_val, val);
        board.insert (row, col, val);

        action_completed (new_stack_item.action);
    }

    public StackAction get_current_stack_action ()
    {
        return (stack_head_index == -1) ? StackAction.NONE : stack[stack_head_index].action;
    }

    private void add_to_stack (stack_item item)
    {
        stack_slice ();
        stack.add (item);
        stack_head_index = stack.size - 1;
    }

    public bool is_empty ()
    {
        return board.is_empty ();
    }

    public void reset ()
    {
        var cells = board.get_cells ();
        var new_stack_item = new stack_item (StackAction.CLEAR_BOARD);
        add_to_stack (new_stack_item);
        for (var row = 0; row < board.rows; row++)
            for (var col = 0; col < board.cols; col++)
            {
                if (board.get_is_fixed (row, col))
                    continue;

                if (cells[row, col] > 0)
                    add_value_step (new_stack_item, row, col, cells[row, col], 0);
                else if (board.has_earmarks (row, col))
                    add_disable_earmarks_step (new_stack_item, row, col);
                board.set (row, col, 0);
            }

        action_completed (new_stack_item.action);
    }

    private void add_earmark_step (stack_item item, int row, int col, int number, bool enabled)
    {
        earmark_change step = {row, col, number, enabled};
        item.earmarks.add (step);
    }

    private void add_disable_earmarks_step (stack_item item, int row, int col)
    {
        var marks = board.get_earmarks (row, col);
        for (var num = 1; num <= 9; num++)
            if (marks[num - 1])
            {
                earmark_change step = {row, col, num, false};
                item.earmarks.add (step);
            }
    }

    private void add_value_step (stack_item item, int row, int col, int old_val, int val)
    {
        value_change step = {row, col, old_val, val};
        item.values.add (step);
    }

    public void undo ()
    {
        var changes = stack[stack_head_index];

        var value_iterator = changes.values.list_iterator ();
        for (var has_next = value_iterator.next (); has_next; has_next = value_iterator.next ())
        {
            var val = value_iterator.get ();
            board.set (val.row, val.col, val.old_val);
        }

        var earmark_iterator = changes.earmarks.list_iterator ();
        for (var has_next = earmark_iterator.next (); has_next; has_next = earmark_iterator.next ())
        {
            var earmark = earmark_iterator.get ();
            if (earmark.enabled)
                board.disable_earmark (earmark.row, earmark.col, earmark.number);
            else
                board.enable_earmark (earmark.row, earmark.col, earmark.number);
        }

        stack_head_index--;
        action_completed (stack[stack_head_index + 1].action);
    }

    public void redo ()
    {
        stack_head_index++;

        var changes = stack.get (stack_head_index);

        var earmark_iterator = changes.earmarks.list_iterator ();
        for (var has_next = earmark_iterator.next (); has_next; has_next = earmark_iterator.next ())
        {
            var earmark = earmark_iterator.get ();
            if (earmark.enabled)
                board.enable_earmark (earmark.row, earmark.col, earmark.number);
            else
                board.disable_earmark (earmark.row, earmark.col, earmark.number);
        }

        var value_iterator = changes.values.list_iterator ();
        for (var has_next = value_iterator.next (); has_next; has_next = value_iterator.next ())
        {
            var val = value_iterator.get ();
            board.set (val.row, val.col, val.new_val);
        }

        action_completed (stack[stack_head_index].action);
    }

    public void enable_all_earmark_possibilities ()
    {
        var cells = board.get_cells ();
        var new_stack_item = new stack_item (StackAction.ENABLE_ALL_EARMARK_POSSIBILITIES);
        var head_backup = stack_head_index;
        var stack_backup = stack;
        add_to_stack (new_stack_item);

        for (var row = 0; row < board.rows; row++)
            for (var col = 0; col < board.cols; col++)
            {
                if (cells[row, col] != 0)
                    continue;

                var marks = board.get_possibilities_as_bool_array (row, col);
                for (int num = 1; num <= 9; num++)
                {
                    if (marks[num - 1] && !board.is_earmark_enabled (row, col, num))
                    {
                        add_earmark_step (new_stack_item, row, col, num, true);
                        board.enable_earmark (row, col, num);
                    }
                }
            }

        if (new_stack_item.earmarks.size == 0)
        {
            stack = stack_backup;
            stack_head_index = head_backup;
        }
        else
            action_completed (new_stack_item.action);
    }

    //creates a new stack branch, to use when the head is detached and changes occur
    public void stack_slice ()
    {
        if (stack_head_index == stack.size - 1)
            return;

        if (stack_head_index == -1)
            stack.clear ();
        else
            stack = (ArrayList) stack.slice (0, stack_head_index + 1);
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
        timer.stop ();
        tick ();
    }

    public void resume_clock ()
        requires (timer != null && clock_timeout == 0)
    {
        timer.continue ();
        timeout_cb ();
    }
}

public enum GameMode
{
    NONE,
    PLAY,
    CREATE;
}

public enum StackAction
{
    NONE,
    INSERT,
    REMOVE,
    ENABLE_EARMARK,
    DISABLE_EARMARK,
    DISABLE_ALL_EARMARKS,
    INSERT_AND_DISABLE_RELATED_EARMARKS,
    ENABLE_ALL_EARMARK_POSSIBILITIES,
    CLEAR_BOARD;

    public bool is_single_value_change ()
    {
        switch (this)
        {
            case INSERT:
            case REMOVE:
            case INSERT_AND_DISABLE_RELATED_EARMARKS:
                return true;
            default:
                return false;
        }
    }

    public bool is_single_earmarks_change ()
    {
         switch (this)
        {
            case ENABLE_EARMARK:
            case DISABLE_EARMARK:
            case DISABLE_ALL_EARMARKS:
                return true;
            default:
                return false;
        }
    }
}
