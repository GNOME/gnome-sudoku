private class NumberPicker : Gtk.Grid
{
    private SudokuBoard board;

    public signal void number_picked (int number);

    public NumberPicker (ref SudokuBoard board, bool show_clear = true) {
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

        if (show_clear)
        {
            var button = new Gtk.Button ();
            button.focus_on_click = false;
            this.attach (button, 0, 4, 3, 1);

            var label = new Gtk.Label ("<big>Clear</big>");
            label.use_markup = true;
            button.add (label);
            label.show ();

            button.clicked.connect (() => {
                number_picked(0);
            });

            button.show ();
        }

        this.show ();
    }
}
