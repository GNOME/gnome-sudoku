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

    public signal void value_picked (int val);
    public signal void earmark_state_changed (int num, bool active);

    private Button clear_button;
    private Button[] value_buttons;
    private ToggleButton[] earmark_buttons;

    public bool is_earmark_picker { get; private set; }

    public NumberPicker (SudokuGame game, bool for_earmarks = false)
    {
        board = game.board;
        is_earmark_picker = for_earmarks;

        if (is_earmark_picker)
            earmark_buttons = new ToggleButton [board.block_cols * board.block_rows];
        else
            value_buttons = new Button [board.block_cols * board.block_rows];

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

                //workaround to avoid lambda capture and memory leak
                button.set_data<int> ("number-contained", n);

                if (!for_earmarks)
                {
                    value_buttons[n - 1] = button;
                    button.clicked.connect ((this_button) => {
                        value_picked (this_button.get_data<int> ("number-contained"));
                    });
                }
                else
                {
                    earmark_buttons[n - 1] = (ToggleButton) button;
                    earmark_buttons[n - 1].toggled.connect ((this_button) => {
                        int number_contained = this_button.get_data<int> ("number-contained");
                        var toggle_active = this_button.get_active ();
                        earmark_state_changed (number_contained, toggle_active);
                    });
                }

                if (n == 5)
                    button.realize.connect ((this_button) => {
                        this_button.grab_focus ();
                    });
            }
        }

        clear_button = new Button ();
        clear_button.focus_on_click = false;
        this.attach (clear_button, 0, 4, 3, 1);

        var label = new Label ("<big>%s</big>".printf (_("Clear")));
        label.use_markup = true;
        clear_button.set_child (label);

        clear_button.clicked.connect ((this_button) => {
            value_picked (0);

            if (is_earmark_picker)
            {
                for (var i = 0; i < 9; i++)
                    earmark_buttons[i].set_active (false);
                this.set_clear_button_enabled (false);
            }
            else
                this.set_clear_button_visibility (false);

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

    public void set_earmark_buttons (int row, int col)
        requires (is_earmark_picker)
    {
        for (var i = 1; i <= board.max_val; i++)
            set_earmark_button (i, board.is_earmark_enabled (row, col, i));
    }

    public void set_earmark_button (int num, bool state)
        requires (is_earmark_picker)
    {
        earmark_buttons[num - 1].set_active (state);
    }

    public override void dispose ()
    {
        clear_button.unparent ();
        foreach (var button in earmark_buttons)
            button.unparent ();
        foreach (var button in value_buttons)
            button.unparent ();
    }
}
