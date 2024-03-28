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

    public bool is_earmark_picker { get; private set; }

    public NumberPicker (SudokuGame game, bool for_earmarks = false)
    {
        board = game.board;
        earmarks_active = 0;

        is_earmark_picker = for_earmarks;

        for (var col = 0; col < board.block_cols; col++)
        {
            for (var row = 0; row < board.block_rows; row++)
            {
                int n = col + ((board.block_rows - 1) - row) * board.block_cols + 1;

                var button = for_earmarks ? new ToggleButton () : new Button ();
                button.focus_on_click = false;
                this.attach (button, col, row, 1, 1);

                var label = new Label ("<big>%d</big>".printf (n));
                label.use_markup = true;
                label.margin_start = for_earmarks ? 0 : 8;
                label.margin_end = for_earmarks ? 16 : 8;
                label.margin_top = for_earmarks ? 0 : 4;
                label.margin_bottom = for_earmarks ? 8 : 4;
                button.set_child (label);

                if (!for_earmarks)
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
                    button.realize.connect (() => {
                        button.grab_focus ();
                    });
            }
        }

        clear_button = new Button ();
        clear_button.focus_on_click = false;
        this.attach (clear_button, 0, 4, 3, 1);

        var label = new Label ("<big>%s</big>".printf (_("Clear")));
        label.use_markup = true;
        clear_button.set_child (label);

        clear_button.clicked.connect (() => {
            number_picked (0);
            earmark_state_changed (0, false);

            if (for_earmarks)
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
    }

    public void set_clear_button_visibility (bool visible)
    {
        clear_button.visible = visible;
    }

    public void set_clear_button_enabled (bool enabled)
    {
        clear_button.sensitive = enabled;
    }

    public void set_earmarks (int row, int col)
        requires (is_earmark_picker)
    {
        for (var i = 0; i < board.max_val; i++)
            set_earmark (row, col, i, board.is_earmark_enabled (row, col, i + 1));
    }

    public void set_earmark (int row, int col, int index, bool state)
        requires (is_earmark_picker)
    {
        get_button_for (index).set_active (state);
    }

    private ToggleButton get_button_for (int number)
    {
        return (ToggleButton) this.get_child_at (number % board.block_cols,
            (board.block_rows - 1) - (number / board.block_rows));
    }
}
