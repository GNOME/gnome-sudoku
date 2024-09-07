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

public class NumberPicker : Popover
{
    private ValuePicker value_picker;
    private EarmarkPicker earmark_picker;

    public NumberPickerState state;

    public NumberPicker (SudokuGame game)
    {
        value_picker = new ValuePicker(game, this);
        earmark_picker = new EarmarkPicker(game, this);
        set_autohide (false);
        can_focus = false;
    }

    public void show_earmark_picker (SudokuCell cell)
    {
        if (visible)
        {
            NumberPickerState old_state = state;
            popdown ();
            if (old_state == NumberPickerState.EARMARK_PICKER)
                return;
        }

        state = NumberPickerState.EARMARK_PICKER;
        earmark_picker.connect_picker (cell);

        if (parent == null)
            set_parent (cell);

        set_child (earmark_picker);
        popup ();
    }

    public void show_value_picker (SudokuCell cell)
    {
        if (visible)
        {
            NumberPickerState old_state = state;
            popdown ();
            if (old_state == NumberPickerState.VALUE_PICKER)
                return;
        }
        state = NumberPickerState.VALUE_PICKER;
        value_picker.connect_picker (cell);

        if (parent == null)
            set_parent (cell);

        set_child (value_picker);
        popup ();
    }

    public override void closed ()
    {
        if (state == NumberPickerState.VALUE_PICKER)
            value_picker.disconnect_picker ();
        else if (state == NumberPickerState.EARMARK_PICKER)
            earmark_picker.disconnect_picker ();
        state = NumberPickerState.NONE;
        unparent ();
        child = null;
    }
}

public abstract class Picker : Grid
{
    protected unowned NumberPicker number_picker;

    protected SudokuCell cell;
    protected SudokuGame game;

    protected Button clear_button;

    Picker (SudokuGame game, NumberPicker number_picker)
    {
        this.game = game;
        this.number_picker = number_picker;

        clear_button = new Button ();
        clear_button.clicked.connect (() => {
            cell.value = 0;
        });
        attach (clear_button, 0, 4, 3, 1);

        var label = new Label ("<big>%s</big>".printf (_("Clear")));
        label.use_markup = true;
        clear_button.set_child (label);

        valign = Align.CENTER;
        halign = Align.CENTER;
        margin_top = 2;
        margin_bottom = 2;
        margin_start = 2;
        margin_end = 2;
        row_spacing = 3;
        column_spacing = 3;
    }

    public override void dispose ()
    {
        base.dispose ();
        clear_button.unparent ();
    }

    protected abstract void value_changed_cb (int row, int col, int old_val, int new_val);
    protected abstract void earmark_changed_cb (int row, int col, int num, bool enabled);
    public virtual void connect_picker (SudokuCell cell)
    {
        this.cell = cell;
        game.board.earmark_changed.connect (earmark_changed_cb);
        game.board.value_changed.connect (value_changed_cb);
    }

    public virtual void disconnect_picker ()
    {
        cell = null;
        game.board.earmark_changed.disconnect (earmark_changed_cb);
        game.board.value_changed.disconnect (value_changed_cb);
    }
}

private class ValuePicker : Picker
{
    private Button[] value_buttons;

    public ValuePicker (SudokuGame game, NumberPicker number_picker)
    {
        base (game, number_picker);
        value_buttons = new Button [game.board.block_cols * game.board.block_rows];

        for (var col = 0; col < game.board.block_cols; col++)
        {
            for (var row = 0; row < game.board.block_rows; row++)
            {
                int n = col + ((game.board.block_rows - 1) - row) * game.board.block_cols + 1;

                var button = new Button ();
                attach (button, col, row, 1, 1);

                var label = new Label ("<big>%d</big>".printf (n));
                label.use_markup = true;
                label.margin_start = 8;
                label.margin_end = 8;
                label.margin_top = 4;
                label.margin_bottom = 4;
                button.set_child (label);

                //workaround to avoid lambda capture and memory leak
                button.set_data<int> ("number-contained", n);

                value_buttons[n - 1] = button;
                value_buttons[n - 1].clicked.connect (value_picked_cb);
            }
        }
    }

    public override void connect_picker (SudokuCell cell)
    {
        base.connect_picker (cell);
        clear_button.visible = cell.value > 0 || game.board.has_earmarks (cell.row, cell.col);
        clear_button.set_sensitive (game.board.has_earmarks (cell.row, cell.col) || cell.value > 0);
    }

    private void value_picked_cb (Button button)
    {
        int val = button.get_data<int> ("number-contained");
        cell.value = val;
        if (val == 0)
            clear_button.visible = false;
        else
            number_picker.popdown ();
    }

    protected override void value_changed_cb (int row, int col, int old_val, int new_val)
    {
        clear_button.visible =  new_val != 0;
        number_picker.present ();
    }

    protected override void earmark_changed_cb (int row, int col, int num, bool enabled)
    {
        clear_button.set_sensitive (game.board.has_earmarks (cell.row, cell.col));
        clear_button.visible = cell.value > 0 || game.board.has_earmarks (cell.row, cell.col);
        number_picker.present ();
    }

    public override void dispose ()
    {
        base.dispose ();
        foreach (var button in value_buttons)
            button.unparent ();
    }
}

private class EarmarkPicker : Picker
{
    private ToggleButton[] earmark_buttons;

    public EarmarkPicker (SudokuGame game, NumberPicker number_picker)
    {
        base (game, number_picker);
        earmark_buttons = new ToggleButton [game.board.block_cols * game.board.block_rows];

        for (var col = 0; col < game.board.block_cols; col++)
        {
            for (var row = 0; row < game.board.block_rows; row++)
            {
                int n = col + ((game.board.block_rows - 1) - row) * game.board.block_cols + 1;

                var button = new ToggleButton ();
                attach (button, col, row, 1, 1);

                var label = new Label ("<big>%d</big>".printf (n));
                label.use_markup = true;
                label.margin_start = 0;
                label.margin_end = 16;
                label.margin_top = 0;
                label.margin_bottom = 8;
                button.set_child (label);

                //workaround to avoid lambda capture and memory leak
                button.set_data<int> ("number-contained", n);

                earmark_buttons[n - 1] = (ToggleButton) button;
           }
        }
    }

    public override void connect_picker (SudokuCell cell)
    {
        base.connect_picker (cell);
        set_buttons_active (cell.row, cell.col);
        clear_button.visible = true;
        set_buttons_sensitive (cell.value == 0);
        clear_button.sensitive = cell.value != 0 || game.board.has_earmarks (cell.row, cell.col);
        foreach (var button in earmark_buttons)
            button.toggled.connect (earmark_picked_cb);
    }

    public override void disconnect_picker ()
    {
        base.disconnect_picker ();
        foreach (var button in earmark_buttons)
            button.toggled.disconnect (earmark_picked_cb);
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

    protected override void value_changed_cb (int row, int col, int old_val, int new_val)
    {
        set_buttons_sensitive (cell.value == 0);
        clear_button.set_sensitive (cell.value != 0);
    }

    protected override void earmark_changed_cb (int row, int col, int num, bool enabled)
    {
        clear_button.set_sensitive (game.board.has_earmarks (cell.row, cell.col));
        earmark_buttons[num - 1].set_active (enabled);
    }

    private void set_buttons_sensitive (bool enabled)
    {
        foreach (var button in earmark_buttons)
            button.set_sensitive (enabled);
    }

    private void set_buttons_active (int row, int col)
    {
        for (var i = 1; i <= game.board.max_val; i++)
            earmark_buttons[i - 1].set_active (game.board.is_earmark_enabled (row, col, i));
    }

    public override void dispose ()
    {
        base.dispose ();
        foreach (var button in earmark_buttons)
            button.unparent ();
    }
}

public enum NumberPickerState
{
    NONE,
    VALUE_PICKER,
    EARMARK_PICKER;
}
