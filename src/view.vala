/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2014 Parin Porecha
 * Copyright © 2014 Michael Catanzaro
 * Copyright © 2023 Jamie Murphy <jmurphy@gnome.org>
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
using Gdk;

public class SudokuGameView : Adw.Bin
{
    private EventControllerKey key_controller;
    private EventControllerFocus focus_controller;
    private SudokuCell[,] cells;
    private SudokuFrame frame;
    private Overlay overlay;
    private Label paused_label;

    public SudokuNumberPicker number_picker;
    public SudokuGame game;

    public double value_zoom_multiplier { get; private set; }

    public int selected_row { get; private set; default = 0; }
    public int selected_col { get; private set; default = 0; }

    private SudokuCell selected_cell
    {
        get { return cells[selected_row, selected_col]; }
    }

    public signal void selection_changed (int old_row, int old_col, int new_row, int new_col);

    public SudokuGameView (SudokuBoard board)
    {
        game = new SudokuGame (board);

        Sudoku.app.notify["show-warnings"].connect (warnings_cb);
        Sudoku.app.notify["earmark-warnings"].connect (warnings_cb);
        Sudoku.app.notify["solution-warnings"].connect (warnings_cb);
        Sudoku.app.notify["highlighter"].connect (highlighter_cb);
        Sudoku.app.notify["zoom-level"].connect (update_zoom);

        Sudoku.app.notify["show-possibilities"].connect (show_possibilities_cb);
        if (Sudoku.app.show_possibilities && game.board.previous_played_time == 0.0
            && game.mode != GameMode.CREATE)
        {
            game.enable_all_earmark_possibilities ();
        }

        this.vexpand = true;
        this.focusable = true;

        overlay = new Overlay ();
        frame = new SudokuFrame (overlay);
        this.set_child (frame);

        paused_label = new Label (_("Paused"));
        number_picker = new SudokuNumberPicker (game);

        var grid = new Grid () {
            row_spacing = 2,
            column_spacing = 2,
            column_homogeneous = true,
            row_homogeneous = true,
            vexpand = true,
            hexpand = true
        };
        grid.add_css_class ("board");
        overlay.set_child (grid);

        var blocks = new Grid[game.board.block_rows, game.board.block_cols];
        for (var block_row = 0; block_row < game.board.block_rows; block_row++)
        {
            for (var block_col = 0; block_col < game.board.block_cols; block_col++)
            {
                var block_grid = new Grid ();
                block_grid.row_spacing = 1;
                block_grid.column_spacing = 1;
                block_grid.column_homogeneous = true;
                block_grid.row_homogeneous = true;
                block_grid.add_css_class ("block");
                grid.attach (block_grid, block_col, block_row, 1, 1);

                blocks[block_row, block_col] = block_grid;
            }
        }

        cells = new SudokuCell[game.board.rows, game.board.cols];
        for (var row = 0; row < game.board.rows; row++)
        {
            for (var col = 0; col < game.board.cols; col++)
            {
                var cell = new SudokuCell (row, col, this);
                blocks[row / game.board.block_rows, col / game.board.block_cols].attach (cell, col % game.board.block_cols, row % game.board.block_rows);
                cells[row, col] = cell;
            }
        }

        this.game.board.value_changed.connect (value_changed_cb);
        this.game.board.earmark_changed.connect (earmark_changed_cb);
        this.selection_changed.connect (selection_changed_cb);
        game.notify["paused"].connect(paused_cb);
        game.notify["board"].connect(board_changed_cb);

        key_controller = new EventControllerKey ();
        key_controller.key_pressed.connect (key_pressed_cb);
        add_controller (key_controller);

        focus_controller = new EventControllerFocus ();
        focus_controller.leave.connect (() => {
            Window window = get_root () as Window;
            if (window.is_active)
                has_selection = false;
        });
        add_controller (focus_controller);

        update_zoom ();
        update_warnings ();
    }

    public bool move_cell_focus (DirectionType direction)
    {
        switch (direction)
        {
            case DirectionType.TAB_FORWARD:
                //this lets us control the focus when it comes from the headerbar
                if (!focus_controller.contains_focus)
                {
                    cells[0, 0].grab_focus ();
                    return EVENT_STOP;
                }
                else if (selected_col == 8)
                {
                    //propagate the event so that the focus moves to the headerbar
                    if (selected_row == 8)
                        return EVENT_PROPAGATE;

                    cells[selected_row + 1, 0].grab_focus ();
                }
                else
                    cells[selected_row, selected_col + 1].grab_focus ();
                return EVENT_STOP;

            case DirectionType.TAB_BACKWARD:
                if (!focus_controller.contains_focus)
                {
                    cells[8, 8].grab_focus ();
                    return EVENT_STOP;
                }
                else if (selected_col == 0)
                {
                    if (selected_row == 0)
                        return EVENT_PROPAGATE;

                    cells[selected_row - 1, 8].grab_focus ();
                }
                else
                    cells[selected_row, selected_col - 1].grab_focus ();
                return EVENT_STOP;

            case DirectionType.UP:
                if (selected_row == 0)
                    cells[8, selected_col].grab_focus ();
                else
                    cells[selected_row - 1, selected_col].grab_focus ();
                return EVENT_STOP;

            case DirectionType.DOWN:
                if (selected_row == 8)
                    cells[0, selected_col].grab_focus ();
                else
                    cells[selected_row + 1, selected_col].grab_focus ();
                return EVENT_STOP;

            case DirectionType.LEFT:
                if (selected_col == 0)
                    cells[selected_row, 8].grab_focus ();
                else
                    cells[selected_row, selected_col - 1].grab_focus ();
                return EVENT_STOP;

            case DirectionType.RIGHT:
                if (selected_col == 8)
                    cells[selected_row, 0].grab_focus ();
                else
                    cells[selected_row, selected_col + 1].grab_focus ();
                return EVENT_STOP;
        }

        return EVENT_STOP;
    }

    private bool key_pressed_cb (uint         keyval,
                                 uint         keycode,
                                 ModifierType state)
    {
        if (game.paused)
            return EVENT_PROPAGATE;

        if (state != ModifierType.CONTROL_MASK)
            switch (keyval)
            {
                case Key.w :
                    return move_cell_focus (DirectionType.UP);

                case Key.s :
                    return move_cell_focus (DirectionType.DOWN);

                case Key.a :
                    return move_cell_focus (DirectionType.LEFT);

                case Key.d :
                    return move_cell_focus (DirectionType.RIGHT);

                default:
                    break;
            }

        if (selected_cell.is_fixed)
            return EVENT_PROPAGATE;

        switch (keyval)
        {
            case Key.@0: case Key.KP_0: case Key.BackSpace : case Key.Delete:
                if (state == ModifierType.CONTROL_MASK)
                    return EVENT_PROPAGATE;
                else
                {
                    selected_cell.value = 0;
                    return EVENT_STOP;
                }
            case Gdk.Key.@1: case Gdk.Key.KP_1:
                insert_key  (1, state);
                return EVENT_STOP;
            case Gdk.Key.@2: case Gdk.Key.KP_2:
                insert_key  (2, state);
                return EVENT_STOP;
            case Gdk.Key.@3: case Gdk.Key.KP_3:
                insert_key  (3, state);
                return EVENT_STOP;
            case Gdk.Key.@4: case Gdk.Key.KP_4:
                insert_key  (4, state);
                return EVENT_STOP;
            case Gdk.Key.@5: case Gdk.Key.KP_5:
                insert_key  (5, state);
                return EVENT_STOP;
            case Gdk.Key.@6: case Gdk.Key.KP_6:
                insert_key  (6, state);
                return EVENT_STOP;
            case Gdk.Key.@7: case Gdk.Key.KP_7:
                insert_key  (7, state);
                return EVENT_STOP;
            case Gdk.Key.@8: case Gdk.Key.KP_8:
                insert_key  (8, state);
                return EVENT_STOP;
            case Gdk.Key.@9: case Gdk.Key.KP_9:
                insert_key  (9, state);
                return EVENT_STOP;

            case Key.Escape:
                number_picker.popdown ();
                return EVENT_STOP;

            case Key.space : case Key.Return : case Key.KP_Enter:
                bool wants_value = state != ModifierType.CONTROL_MASK;
                wants_value = wants_value ^ Sudoku.app.earmark_mode;

                if (wants_value)
                    number_picker.show_value_picker (selected_cell);
                else
                    number_picker.show_earmark_picker (selected_cell);

                return EVENT_STOP;

            default:
                return EVENT_PROPAGATE;
        }
    }

    private void selection_changed_cb (int old_row, int old_col, int new_row, int new_col)
    {
        number_picker.popdown ();
        update_highlighter (old_row, old_col);
    }

    private void value_changed_cb (int row, int col, int old_val, int new_val)
    {
        var action = game.get_current_stack_action ();
        if (action.is_single_value_change ())
            cells[row, col].grab_focus ();

        cells[row, col].update_content_visibility ();

        update_warnings ();
        update_value_highlighter (row, col, old_val, new_val);
    }

    private void earmark_changed_cb (int row, int col, int num, bool enabled)
    {
        var action = game.get_current_stack_action ();
        if (action.is_single_earmarks_change ())
            cells[row, col].grab_focus ();

        cells[row, col].update_earmark_visibility (num);
        if (Sudoku.app.earmark_warnings)
            cells[row, col].add_earmark_warnings (num);
    }

    private void paused_cb ()
    {
        // Set Font Size
        var attr_list = paused_label.get_attributes ();
        if (attr_list == null)
            attr_list = new Pango.AttrList ();

        attr_list.change (
            Pango.AttrSize.new_absolute ((int) (this.get_width () * 0.125) * Pango.SCALE)
        );

        paused_label.set_attributes (attr_list);
        paused_label.set_visible (this.game.paused);

        has_selection = !game.paused;

        if (game.paused)
        {
            overlay.add_overlay (paused_label);
            overlay.add_css_class ("paused");
            number_picker.popdown ();
        }
        else
        {
            overlay.remove_overlay (paused_label);
            overlay.remove_css_class ("paused");
        }
    }

    public void set_selected (int cell_row, int cell_col)
    {
        if (cells[cell_row, cell_col].selected == true)
            return;

        selected_cell.selected = false;

        var old_row = selected_row;
        var old_col = selected_col;

        selected_row = cell_row;
        selected_col = cell_col;
        selected_cell.selected = true;

        selection_changed(old_row, old_col, selected_row, selected_col);
    }

    private bool _has_selection = true;
    public bool has_selection
    {
        get { return _has_selection; }
        set {
            _has_selection = value;
            selected_cell.selected = has_selection;
            if (has_selection)
                selected_cell.grab_focus ();
            else
                number_picker.popdown ();

            if (Sudoku.app.highlighter)
                set_cell_highlighter (selected_row, selected_col, has_selection);
        }
    }

    private void set_cell_highlighter (int row, int col, bool enabled)
    {
        var target_cell = cells[row, col];

        foreach (var cell in cells)
        {
            if (cell == target_cell)
                continue;

            if (target_cell.value > 0 && Sudoku.app.highlight_numbers)
            {
                if (target_cell.value == cell.value)
                    cell.highlight_number = enabled;
                else if (cell.value == 0)
                    cell.set_earmark_highlight (target_cell.value, enabled);
            }

            if (!cell.is_fixed &&
               ((Sudoku.app.highlight_row_column && (cell.row == row || cell.col == col)) ||
               (Sudoku.app.highlight_block &&
               cell.row / game.board.block_cols == row / game.board.block_cols &&
               cell.col / game.board.block_rows == col / game.board.block_rows)))
            {
                cell.highlight_coord = enabled;
            }
        }
    }

    private void show_possibilities_cb ()
    {
        if (Sudoku.app.show_possibilities && game.mode != GameMode.CREATE)
            game.enable_all_earmark_possibilities ();

        else if (game.get_current_stack_action () == StackAction.ENABLE_ALL_EARMARK_POSSIBILITIES)
            game.undo ();
    }

    private void highlighter_cb ()
    {
        if (!Sudoku.app.highlighter)
            set_cell_highlighter (selected_row, selected_col, false);
        else if (has_selection)
            set_cell_highlighter (selected_row, selected_col, true);
    }

    private void warnings_cb ()
    {
        if (Sudoku.app.show_warnings)
            foreach (var cell in cells)
            {
                cell.add_value_warnings ();
                cell.update_all_earmark_warnings ();
            }
        else
            foreach (var cell in cells)
                cell.clear_warnings ();
    }

    public void board_changed_cb ()
    {
        update_warnings ();
        game.board.value_changed.connect (value_changed_cb);
        game.board.earmark_changed.connect (earmark_changed_cb);
        foreach (var cell in cells)
        {
            cell.update_content_visibility ();
            cell.update_fixed_css ();
        }
    }

    private void update_highlighter (int old_row, int old_col)
    {
        if (Sudoku.app.highlighter)
        {
            set_cell_highlighter (old_row, old_col, false);
            set_cell_highlighter (selected_row, selected_col, true);
        }
    }

    private void update_value_highlighter (int row, int col, int old_val, int new_val)
    {
        if (!Sudoku.app.highlighter || !Sudoku.app.highlight_numbers)
            return;

        if (row != selected_row || col != selected_col)
        {
            if (old_val == selected_cell.value)
                cells[row, col].highlight_number = false;
            else if (new_val == selected_cell.value && new_val != 0)
                cells[row, col].highlight_number = true;
            return;
        }

        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
        {
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
            {
                var cell_tmp = cells[row_tmp, col_tmp];

                if (selected_cell == cell_tmp)
                    continue;

                if (cell_tmp.value == 0)
                {
                    if (old_val > 0)
                        cell_tmp.set_earmark_highlight (old_val, false);
                    if (new_val > 0)
                        cell_tmp.set_earmark_highlight (new_val, true);
                }
                else if (new_val == cell_tmp.value)
                    cell_tmp.highlight_number = true;
                else if (old_val == cell_tmp.value)
                    cell_tmp.highlight_number = false;
            }
        }
    }

    private void update_warnings ()
    {
        if (Sudoku.app.show_warnings)
            foreach (var cell in cells)
            {
                cell.add_value_warnings ();
                cell.update_all_earmark_warnings ();
            }
    }

    private void update_zoom ()
    {
        switch (Sudoku.app.zoom_level)
        {
            case SMALL:
                value_zoom_multiplier = 0.4;
                break;
            case MEDIUM:
                value_zoom_multiplier = 0.5;
                break;
            case LARGE:
                value_zoom_multiplier = 0.6;
                break;
            default:
                assert_not_reached ();
        }

        foreach (var cell in cells)
            cell.queue_allocate ();
    }

    private void insert_key (int key, ModifierType state)
    {
        number_picker.popdown ();
        bool wants_value = state != ModifierType.CONTROL_MASK;
        wants_value = wants_value ^ Sudoku.app.earmark_mode;

        if (wants_value)
        {
            selected_cell.value = key;
        }
        else if (game.mode == GameMode.PLAY && selected_cell.value == 0)
        {
            var enabled = game.board.is_earmark_enabled (selected_row, selected_col, key);
            if (!enabled)
                game.enable_earmark (selected_row, selected_col, key);
            else
                game.disable_earmark (selected_row, selected_col, key);
        }
    }

    public void dismiss_picker ()
    {
        number_picker.popdown ();
    }

    public override void dispose ()
    {
        if (!game.paused)
            game.stop_clock ();

        frame.unparent ();
        number_picker.unparent ();
        base.dispose ();
    }
}

public enum ZoomLevel
{
    NONE = 0,
    SMALL = 1,
    MEDIUM = 2,
    LARGE = 3;

    public bool is_fully_zoomed_out ()
    {
        switch (this)
        {
            case SMALL:
                return true;
            default:
                return false;
        }
    }

    public bool is_fully_zoomed_in ()
    {
        switch (this)
        {
            case LARGE:
                return true;
            default:
                return false;
        }
    }

    public ZoomLevel zoom_in ()
    {
        switch (this)
        {
            case SMALL:
                return MEDIUM;
            case MEDIUM:
                return LARGE;
            case LARGE:
            {
                warning ("ZOOM already at maximum");
                return LARGE;
            }
            default:
                assert_not_reached ();
        }
    }

    public ZoomLevel zoom_out ()
    {
        switch (this)
        {
            case LARGE:
                return MEDIUM;
            case MEDIUM:
                return SMALL;
            case SMALL:
            {
                warning ("ZOOM already at minimum");
                return SMALL;
            }
            default:
                assert_not_reached ();
        }
    }
}
