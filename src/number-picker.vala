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
    private SudokuGame game;

    private Button clear_button;
    private Button[] value_buttons;
    private ToggleButton[] earmark_buttons;
    private SudokuCell cell;

    public bool is_earmark_picker { get; private set; }

    public NumberPicker (SudokuGame game, bool for_earmarks = false)
    {
        this.game = game;
        is_earmark_picker = for_earmarks;

        if (is_earmark_picker)
            earmark_buttons = new ToggleButton [game.board.block_cols * game.board.block_rows];
        else
            value_buttons = new Button [game.board.block_cols * game.board.block_rows];

        for (var col = 0; col < game.board.block_cols; col++)
        {
            for (var row = 0; row < game.board.block_rows; row++)
            {
                int n = col + ((game.board.block_rows - 1) - row) * game.board.block_cols + 1;

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
                    value_buttons[n - 1].clicked.connect (value_picked_cb);
                }
                else
                {
                    earmark_buttons[n - 1] = (ToggleButton) button;
                    earmark_buttons[n - 1].toggled.connect (earmark_picked_cb);
                }

           }
        }

        clear_button = new Button ();
        clear_button.focus_on_click = false;
        this.attach (clear_button, 0, 4, 3, 1);

        var label = new Label ("<big>%s</big>".printf (_("Clear")));
        label.use_markup = true;
        clear_button.set_child (label);

        game.board.value_changed.connect (value_changed_cb);
        game.board.earmark_changed.connect (earmark_changed_cb);
        clear_button.clicked.connect ((this_button) => {
            cell.value = 0;
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

    public void set_cell (SudokuCell cell)
    {
        this.cell = cell;
        if (!is_earmark_picker)
            set_clear_button_visibility (cell.value > 0 || game.board.has_earmarks (cell.row, cell.col));
        else
        {
            set_earmark_buttons (cell.row, cell.col);
            set_clear_button_visibility (true);
            set_earmark_buttons_sensitive (cell.value == 0);
            bool clear_button_enabled = cell.value != 0 || game.board.has_earmarks (cell.row, cell.col);
            set_clear_button_enabled (clear_button_enabled);
        }
    }

    private void value_picked_cb (Button button)
    {
        int val = button.get_data<int> ("number-contained");
        if (val == 0)
            set_clear_button_visibility (false);
        else
            ((Popover)parent).popdown ();

        cell.value = val;
    }

    private void earmark_picked_cb (ToggleButton button)
    {
        int number_picked = button.get_data<int> ("number-contained");
        if (button.get_active())
        {
            if (!game.board.is_earmark_enabled (cell.row, cell.col, number_picked))
                game.enable_earmark (cell.row, cell.col, number_picked);
        }
        else if (game.board.is_earmark_enabled (cell.row, cell.col, number_picked))
        {
            game.disable_earmark (cell.row, cell.col, number_picked);
        }
    }

    private void value_changed_cb (int row, int col, int old_val, int new_val)
    {
        if (cell != null && row == cell.row && col == cell.col)
            set_clear_button_visibility (new_val != 0);
    }


    private void earmark_changed_cb (int row, int col, int num, bool enabled)
    {
        if (cell != null && row == cell.row && col == cell.col)
        {
            set_clear_button_enabled (game.board.has_earmarks (cell.row, cell.col));
            earmark_buttons[num - 1].set_active (enabled);
        }
    }

    public void set_clear_button_visibility (bool visible)
    {
        clear_button.visible = visible;
    }

    public void set_clear_button_enabled (bool enabled)
    {
        clear_button.sensitive = enabled;
    }

    public void set_earmark_buttons_sensitive (bool enabled)
    {
        foreach (var button in earmark_buttons)
            button.set_sensitive (enabled);
    }

    public void set_earmark_buttons (int row, int col)
        requires (is_earmark_picker)
    {
        for (var i = 1; i <= game.board.max_val; i++)
            set_earmark_button (i, game.board.is_earmark_enabled (row, col, i));
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
