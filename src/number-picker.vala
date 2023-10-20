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

using Gtk;

private class NumberPicker : Grid
{
    private SudokuBoard board;

    public signal void number_picked (int number);
    public signal void earmark_state_changed (int number, bool active);

    private Button clear_button;

    private int earmarks_active;

    public bool is_earmark;

    public NumberPicker (ref SudokuBoard board, bool earmark = false)
    {
        this.board = board;
        earmarks_active = 0;

        is_earmark = earmark;

        for (var col = 0; col < board.block_cols; col++)
        {
            for (var row = 0; row < board.block_rows; row++)
            {
                int n = col + ((board.block_rows - 1) - row) * board.block_cols + 1;

                var button = earmark ? new ToggleButton () : new Button ();
                button.focus_on_click = false;
                this.attach (button, col, row, 1, 1);

                var label = new Label ("<big>%d</big>".printf (n));
                label.use_markup = true;
                label.margin_start = earmark ? 0 : 8;
                label.margin_end = earmark ? 16 : 8;
                label.margin_top = earmark ? 0 : 4;
                label.margin_bottom = earmark ? 8 : 4;
                button.set_child (label);
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
                    });
                }

                if (n == 5)
                    button.grab_focus ();

                button.show ();
            }
        }

        clear_button = new Button ();
        clear_button.focus_on_click = false;
        this.attach (clear_button, 0, 4, 3, 1);

        var label = new Label ("<big>%s</big>".printf (_("Clear")));
        label.use_markup = true;
        clear_button.set_child (label);
        label.show ();

        clear_button.clicked.connect (() => {
            number_picked (0);
            earmark_state_changed (0, false);

            if (earmark)
            {
                for (var i = 0; i <= 8; i++)
                {
                    var button = get_button_for (i);
                    button.set_active (false);
                }
            }
        });

        this.valign = Align.CENTER;
        this.halign = Align.CENTER;
        this.margin_top = 2;
        this.margin_bottom = 2;
        this.margin_start = 2;
        this.margin_end = 2;
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

    public void set_clear_button_enabled (bool enabled)
    {
        if (enabled)
            clear_button.sensitive = true;
        else
            clear_button.sensitive = false;
    }

    public void set_earmarks (int row, int col)
    {
        for (var i = 0; i < board.max_val; i++)
            set_earmark (row, col, i, board.is_earmark_enabled (row, col, i + 1));
    }

    public void set_earmark (int row, int col, int index, bool state)
    {
        get_button_for (index).set_active (state);
    }

    private ToggleButton get_button_for (int number)
    {
        return (ToggleButton) this.get_child_at (number % board.block_cols,
            (board.block_rows - 1) - (number / board.block_rows));
    }
}
