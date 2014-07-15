/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gtk;

private class NumberPicker : Gtk.Grid
{
    private SudokuBoard board;

    public signal void number_picked (int number);
    public signal void earmark_state_changed (int number, bool active);

    private Button clear_button;

    private static const int EARMARKS_MAX_ALLOWED = 5;
    private int earmarks_active;

    public NumberPicker (ref SudokuBoard board, bool earmark = false) {
        this.board = board;
        earmarks_active = 0;

        for (var col = 0; col < board.block_cols; col++)
        {
            for (var row = 0; row < board.block_rows; row++)
            {
                int n = col + row * board.block_cols + 1;

                var button = earmark ? new ToggleButton () : new Button ();
                button.focus_on_click = false;
                this.attach (button, col, row, 1, 1);

                var label = new Label ("<big>%d</big>".printf (n));
                label.use_markup = true;
                label.margin = 4;
                label.margin_start = 8;
                label.margin_end = 8;
                button.add (label);
                label.show ();

                if (!earmark)
                    button.clicked.connect (() => {
                        number_picked (n);
                    });
                else
                {
                    var toggle_button = (ToggleButton) button;
                    toggle_button.toggled.connect (() => {
                        var toggle_active = toggle_button.get_active ();
                        earmark_state_changed (n, toggle_active);
                        earmarks_active = toggle_active ? earmarks_active + 1 : earmarks_active - 1;
                        if (earmarks_active < EARMARKS_MAX_ALLOWED)
                            set_toggle_sensitive (true);
                        else
                            set_toggle_sensitive (false);
                    });
                }

                if (n == 5)
                    button.grab_focus ();

                button.show ();
            }
        }

        if (!earmark)
        {
            clear_button = new Button ();
            clear_button.focus_on_click = false;
            this.attach (clear_button, 0, 4, 3, 1);

            var label = new Label ("<big>%s</big>".printf (_("Clear")));
            label.use_markup = true;
            clear_button.add (label);
            label.show ();

            clear_button.clicked.connect (() => {
                number_picked(0);
            });
        }

        this.valign = Align.CENTER;
        this.halign = Align.CENTER;
        this.margin = 2;
        this.row_spacing = 3;
        this.column_spacing = 3;
        this.show ();
    }

    public void set_clear_button_visibility (bool visible)
    {
        if (visible)
            clear_button.show ();
        else
            clear_button.hide ();
    }

    public void set_earmarks (int row, int col)
    {
        for (var i = 0; i < board.max_val; i++)
            set_earmark (row, col, i, board.earmarks[row, col, i]);
    }

    public bool set_earmark (int row, int col, int index, bool state)
    {
        if (state && earmarks_active >= EARMARKS_MAX_ALLOWED)
            return false;
        var button = (ToggleButton) this.get_child_at (index % board.block_cols, index / board.block_rows);
        button.set_active (state);
        return true;
    }

    private void set_toggle_sensitive (bool state)
    {
        if (state)
            for (var i = 0; i < board.max_val; i++)
                this.get_child_at (i % board.block_cols, i / board.block_rows).sensitive = true;
        else
            for (var i = 0; i < board.max_val; i++)
            {
                var button = (ToggleButton) this.get_child_at (i % board.block_cols, i / board.block_rows);
                if (!button.active)
                    button.sensitive = false;
            }
    }
}
