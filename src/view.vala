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

public class SudokuView : Adw.Bin
{
    private GLib.Settings settings;
    private EventControllerKey key_controller;
    private SudokuGame game;
    private SudokuCell[,] cells;
    private SudokuFrame frame;
    private Label paused_label;

    public bool earmark_mode = false;
    public bool autoclean_earmarks;
    public bool number_picker_second_click;
    public bool highlight_row_column;
    public bool highlight_block;
    public bool highlight_numbers;
    public double value_zoom_multiplier;
    public ZoomLevel zoom_level;

    public SudokuNumberPicker number_picker;

    public int selected_row { get; private set; default = 0; }
    public int selected_col { get; private set; default = 0; }

    private SudokuCell selected_cell
    {
        get { return cells[selected_row, selected_col]; }
    }

    public signal void selection_changed (int old_row, int old_col, int new_row, int new_col);

    public SudokuView (SudokuGame game, GLib.Settings settings)
    {
        this.game = game;
        this.settings = settings;

        if (game.mode == GameMode.CREATE)
            this._show_warnings = true;
        else
            this._show_warnings = settings.get_boolean ("show-warnings");
        this._show_possibilities = settings.get_boolean ("show-possibilities");
        this._solution_warnings = settings.get_boolean ("solution-warnings");
        this._show_earmark_warnings = settings.get_boolean ("show-earmark-warnings");
        this._highlighter = settings.get_boolean ("highlighter");
        this.number_picker_second_click = settings.get_boolean ("number-picker-second-click");
        this.autoclean_earmarks = settings.get_boolean ("autoclean-earmarks");
        this.highlight_row_column = settings.get_boolean ("highlight-row-column");
        this.highlight_block = settings.get_boolean ("highlight-block");
        this.highlight_numbers = settings.get_boolean ("highlight-numbers");
        this.zoom_level = (ZoomLevel) settings.get_enum ("zoom-level");
        this.vexpand = true;
        this.focusable = true;

        this.update_zoom ();

        var overlay = new Overlay ();
        frame = new SudokuFrame (overlay);
        this.set_child (frame);

        paused_label = new Label (_("Paused"));
        paused_label.set_visible (false);
        overlay.add_overlay (paused_label);
        overlay.add_css_class ("paused");

        number_picker = new SudokuNumberPicker (game);

        this.game.paused_changed.connect(() => {
            // Set Font Size
            var attr_list = paused_label.get_attributes ();
            if (attr_list == null)
                attr_list = new Pango.AttrList ();

            attr_list.change (
                Pango.AttrSize.new_absolute ((int) (this.get_width () * 0.125) * Pango.SCALE)
            );

            paused_label.set_attributes (attr_list);
            paused_label.set_visible (this.game.paused);

            if (this.game.paused)
            {
                mask_view ();
                clear_all_warnings ();
            }
            else
            {
                unmask_view ();
                update_warnings ();
            }

            has_selection = !this.game.paused;
        });

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
                var cell = new SudokuCell (row, col, game, this);
                cell.get_visible_earmarks ();
                blocks[row / game.board.block_rows, col / game.board.block_cols].attach (cell, col % game.board.block_cols, row % game.board.block_rows);
                cells[row, col] = cell;
            }
        }

        this.game.board.value_changed.connect (value_changed_cb);
        this.game.board.earmark_changed.connect (earmark_changed_cb);
        this.selection_changed.connect (selection_changed_cb);

        key_controller = new EventControllerKey ();
        key_controller.key_pressed.connect (key_pressed_cb);
        add_controller (key_controller);

        if (show_possibilities && game.mode != GameMode.CREATE && game.board.previous_played_time == 0.0)
            game.enable_all_earmark_possibilities ();

        update_warnings ();
    }

    private bool key_pressed_cb (uint         keyval,
                                 uint         keycode,
                                 ModifierType state)
    {
        if (game.paused)
            return EVENT_PROPAGATE;

        switch (keyval)
        {
            case Key.Up : case Key.w : case Key.KP_Up:
                if (selected_row == 0)
                    cells[8, selected_col].grab_focus ();
                else
                    cells[selected_row - 1, selected_col].grab_focus ();
                return EVENT_STOP;

            case Key.Down : case Key.s : case Key.KP_Down:
                if (selected_row == 8)
                    cells[0, selected_col].grab_focus ();
                else
                    cells[selected_row + 1, selected_col].grab_focus ();
                return EVENT_STOP;

            case Key.Left : case Key.a : case Key.KP_Left:
                if (selected_col == 0)
                    cells[selected_row, 8].grab_focus ();
                else
                    cells[selected_row, selected_col - 1].grab_focus ();
                return EVENT_STOP;

            case Key.Right : case Key.d : case Key.KP_Right:
                if (selected_col == 8)
                    cells[selected_row, 0].grab_focus ();
                else
                    cells[selected_row, selected_col + 1].grab_focus ();
                return EVENT_STOP;

            default:
                break;
        }

        if (selected_cell.is_fixed)
            return EVENT_PROPAGATE;

        switch (keyval)
        {
            case Key.@0: case Key.KP_0: case Key.BackSpace : case Key.Delete:
                selected_cell.value = 0;
                return EVENT_STOP;
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
                wants_value = wants_value ^ earmark_mode;

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
        set_cell_highlighter (old_row, old_col, false);
        set_cell_highlighter (new_row, new_col, true);
        number_picker.popdown ();
    }

    private void value_changed_cb (int row, int col, int old_val, int new_val)
    {
        var action = game.get_current_stack_action ();

        cells[row, col].update_value ();
        update_warnings ();

        if (action.is_single_value_change ())
            cells[row, col].grab_focus ();

        //makes sure the highlighter works correctly with clear board
        if (row == selected_row && col == selected_col)
        {
            set_selected_value_highlighter (old_val, false);
            set_selected_value_highlighter (new_val, true);
            selected_cell.highlight_number = false;
        }
        else
        {
            set_unselected_value_highlighter (row, col, old_val, false);
            set_unselected_value_highlighter (row, col, new_val, true);
        }
    }

    private void earmark_changed_cb (int row, int col, int num, bool enabled)
    {
        var action = game.get_current_stack_action ();
        if (action.is_single_earmarks_change ())
            cells[row, col].grab_focus ();

        cells[row, col].get_visible_earmark (num);
        if (show_warnings && enabled)
            cells[row, col].check_earmark_warnings (num);
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

        selection_changed(old_row, old_col, selected_row, selected_col);

        selected_cell.selected = true;
    }

    private void set_cell_highlighter (int row, int col, bool enabled)
    {
        if (!highlighter)
            return;

        var cell = cells[row, col];

        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
        {
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
            {
                var cell_tmp = cells[row_tmp, col_tmp];

                if (cell == cell_tmp)
                    continue;

                if (cell.value > 0 && highlight_numbers)
                {
                    if (cell.value == cell_tmp.value)
                        cell_tmp.highlight_number = enabled;
                    else if (cell_tmp.value == 0)
                        cell_tmp.set_earmark_highlight (cell.value, enabled);
                }

                if (!cell_tmp.is_fixed &&
                   ((highlight_row_column && (row_tmp == row || col_tmp == col)) ||
                   (highlight_block &&
                   row_tmp / game.board.block_cols == row / game.board.block_cols &&
                   col_tmp / game.board.block_rows == col / game.board.block_rows)))
                {
                    cell_tmp.highlight_coord = enabled;
                }
            }
        }
    }

    private void set_selected_value_highlighter (int val, bool enabled)
    {
        if (!highlighter || val == 0 || !highlight_numbers)
            return;

        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
        {
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
            {
                var cell_tmp = cells[row_tmp, col_tmp];

                if (selected_cell == cell_tmp)
                    continue;

                if (val == cell_tmp.value)
                    cell_tmp.highlight_number = enabled;
                else if (cell_tmp.value == 0)
                    cell_tmp.set_earmark_highlight (val, enabled);
            }
        }
    }

    private void set_unselected_value_highlighter (int row, int col, int val, bool enabled)
    {
        if (!highlighter || val == 0 || !highlight_numbers)
            return;

        if (val != selected_cell.value)
            return;

        var changed_cell = cells[row, col];
        changed_cell.highlight_number = enabled;
    }

    public void update_zoom (ZoomLevel level = zoom_level)
    {
        zoom_level = level;
        switch (level)
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
        }
        foreach (var cell in cells)
            cell.queue_allocate ();
    }

    private void update_warnings ()
    {
        if (!show_warnings)
            return;

        for (var col = 0; col < game.board.cols; col++)
            for (var row = 0; row < game.board.rows; row++)
            {
                cells[row, col].check_value_warnings ();
                cells[row, col].check_earmarks_warnings ();
            }
    }

    private void clear_all_warnings ()
    {
        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
                cells[row_tmp, col_tmp].clear_warnings ();
    }

    private void mask_view ()
    {
        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
                cells[row_tmp, col_tmp].paused = true;
    }

    private void unmask_view ()
    {
        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
                cells[row_tmp, col_tmp].paused = false;
    }

    private bool _show_warnings;
    public bool show_warnings
    {
        get { return _show_warnings; }
        set {
            _show_warnings = value;

            if (show_warnings)
                update_warnings ();
            else
                clear_all_warnings ();
            //refresh css rules
            set_cell_highlighter (selected_row, selected_col, true);
         }
    }

    private bool _show_earmark_warnings;
    public bool show_earmark_warnings
    {
        get { return _show_earmark_warnings; }
        set {
            _show_earmark_warnings = value;
            show_warnings = show_warnings; //call the setter
        }
    }

    private bool _solution_warnings;
    public bool solution_warnings
    {
        get { return _solution_warnings; }
        set {
            _solution_warnings = value;
            show_warnings = show_warnings; //call the setter
        }
    }

    private bool _show_possibilities;
    public bool show_possibilities
    {
        get { return _show_possibilities; }
        set {
            _show_possibilities = value;
            if (show_possibilities && game.mode != GameMode.CREATE)
                game.enable_all_earmark_possibilities ();
            else if (game.get_current_stack_action () == StackAction.ENABLE_ALL_EARMARK_POSSIBILITIES)
                game.undo ();
        }
    }

    private bool _highlighter;
    public bool highlighter
    {
        get { return _highlighter; }
        set {
            set_cell_highlighter (selected_row, selected_col, false);
            _highlighter = value;
            set_cell_highlighter (selected_row, selected_col, true);
        }
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

            set_cell_highlighter (selected_row, selected_col, has_selection);
        }
    }

    private void insert_key (int key, ModifierType state)
    {
        number_picker.popdown ();
        bool wants_value = state != ModifierType.CONTROL_MASK;
        wants_value = wants_value ^ earmark_mode;

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
        frame.unparent ();
        number_picker.unparent ();
        base.dispose ();
    }
}

public enum ZoomLevel
{
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
