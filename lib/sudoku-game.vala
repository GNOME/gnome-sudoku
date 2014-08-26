/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gee;

public class SudokuGame : Object
{
    public SudokuBoard board;
    public GLib.Timer timer;

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
        timer.reset();
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
        board.earmarks = new bool[board.rows, board.cols, board.max_val];
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
}
