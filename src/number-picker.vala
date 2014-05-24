/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

private class NumberPicker : Gtk.Grid
{
    private SudokuBoard board;

    public signal void number_picked (int number);

    private Gtk.Button clear_button;

    public NumberPicker (ref SudokuBoard board) {
        this.board = board;

        for (var col = 0; col < board.block_cols; col++)
        {
            for (var row = 0; row < board.block_rows; row++)
            {
                int n = col + row * board.block_cols + 1;

                var button = new Gtk.Button ();
                button.focus_on_click = false;
                this.attach (button, col, row, 1, 1);

                var label = new Gtk.Label ("<big>%d</big>".printf (n));
                label.use_markup = true;
                button.add (label);
                label.show ();

                button.clicked.connect (() => {
                    number_picked(n);
                });

                if (n == 5)
                    button.grab_focus ();

                button.show ();
            }
        }

        clear_button = new Gtk.Button ();
        clear_button.focus_on_click = false;
        this.attach (clear_button, 0, 4, 3, 1);

        var label = new Gtk.Label ("<big>Clear</big>");
        label.use_markup = true;
        clear_button.add (label);
        label.show ();

        clear_button.clicked.connect (() => {
            number_picked(0);
        });

        this.show ();
    }

    public void set_clear_button_visibility (bool visible)
    {
        if (visible)
            clear_button.show ();
        else
            clear_button.hide ();
    }
}
