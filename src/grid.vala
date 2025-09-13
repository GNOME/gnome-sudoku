/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2025 Johan Gay
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

public class SudokuGrid : Grid
{
    private SudokuCell[,] cells;

    private const Coord START = {4, 4};

    public int selected_row { get; private set; default = START.row; }
    public int selected_col { get; private set; default = START.col; }

    private double zoom_value_multiplier;
    private double zoom_earmark_multiplier;

    private GestureClick button_controller;
    private SudokuGame game;
    private EventControllerFocus focus_controller;

    public SudokuNumberPicker number_picker;

    private SimpleActionGroup action_group;
    private SimpleAction move_up_action;
    private SimpleAction move_down_action;
    private SimpleAction move_left_action;
    private SimpleAction move_right_action;

    public SudokuCell selected_cell
    {
        get { return cells[selected_row, selected_col]; }
    }

    static construct
    {
        new_move_shortcut ("grid.move-up", "w", DirectionType.UP);
        new_move_shortcut ("grid.move-left", "a", DirectionType.LEFT);
        new_move_shortcut ("grid.move-down", "s", DirectionType.DOWN);
        new_move_shortcut ("grid.move-right", "d", DirectionType.RIGHT);
    }

    private class void new_move_shortcut (string name, string accelerator, DirectionType dir)
    {
        var action = new NamedAction (name);
        var trigger = ShortcutTrigger.parse_string (accelerator);
        var shortcut = new Shortcut.with_arguments (trigger, action, "i", dir);
        add_shortcut (shortcut);
    }

    public SudokuGrid (SudokuGame game)
    {
        this.game = game;
        this.game.notify["paused"].connect (paused_cb);
        row_spacing = 2;
        column_spacing = 2;
        column_homogeneous = true;
        row_homogeneous = true;
        add_css_class("board");

        button_controller = new GestureClick ();
        button_controller.set_button (0 /* all buttons */);
        button_controller.released.connect (button_released_cb);
        add_controller (button_controller);

        number_picker = new SudokuNumberPicker (game);
        update_zoom ();

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
                attach (block_grid, block_col, block_row, 1, 1);

                blocks[block_row, block_col] = block_grid;
            }
        }

        cells = new SudokuCell[game.board.rows, game.board.cols];
        for (var row = 0; row < game.board.rows; row++)
        {
            for (var col = 0; col < game.board.cols; col++)
            {
                var cell = new SudokuCell (game, this, ref zoom_value_multiplier, ref zoom_earmark_multiplier, row, col);
                blocks[row / game.board.block_rows, col / game.board.block_cols].attach (cell, col % game.board.block_cols, row % game.board.block_rows);
                cells[row, col] = cell;
            }
        }

        focus_controller = new EventControllerFocus ();
        focus_controller.leave.connect (() => {
            Window window = get_root () as Window;
            if (window.is_active)
                unselect ();
        });
        add_controller (focus_controller);

        this.game.board.value_changed.connect (value_changed_cb);
        this.game.board.earmark_changed.connect (earmark_changed_cb);

        add_warnings ();

        action_group = new SimpleActionGroup ();

        new_move_action ("move-up", out move_up_action);
        new_move_action ("move-down", out move_down_action);
        new_move_action ("move-right", out move_right_action);
        new_move_action ("move-left", out move_left_action);

        insert_action_group ("grid", action_group);
    }

    private void new_move_action (string name, out SimpleAction action)
    {
        action = new SimpleAction (name, VariantType.INT32);
        action.activate.connect (move);
        action_group.add_action (action);
    }

    public void change_board ()
    {
        selected_col = START.col;
        selected_row = START.row;
        foreach (var cell in cells)
        {
            cell.update_content_visibility ();
            cell.update_fixed ();
        }

        update_warnings ();

        game.board.value_changed.connect (value_changed_cb);
        game.board.earmark_changed.connect (earmark_changed_cb);
    }

    private void update_highlighter (int old_row, int old_col)
    {
        set_cell_highlighter (old_row, old_col, false);
        set_cell_highlighter (selected_row, selected_col, true);
    }

    private void update_value_highlighter (int row, int col, int old_val, int new_val)
    {
        if (!Sudoku.app.highlight_numbers)
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

    public void update_zoom ()
    {
        switch (Sudoku.app.zoom_level)
        {
            case SMALL:
                zoom_value_multiplier = 0.4;
                zoom_earmark_multiplier = 0.25;
                break;
            case MEDIUM:
                zoom_value_multiplier = 0.5;
                zoom_earmark_multiplier = 0.25;
                break;
            case LARGE:
                zoom_value_multiplier = 0.6;
                zoom_earmark_multiplier = 0.3;
                break;
            default:
                assert_not_reached ();
        }

        foreach (var cell in cells)
            cell.queue_allocate ();
    }

    public void toggle_highlighter ()
    {
        if (focus_controller.contains_focus)
            set_cell_highlighter (selected_row, selected_col, true);
    }

    public void update_warnings ()
    {
        foreach (var cell in cells)
        {
            cell.update_value_warnings ();
            cell.update_all_earmark_warnings ();
        }
    }

    public void update_cell_warnings (int row, int col)
    {
        foreach (var coord in game.board.aligned_coords_for_cell[row, col])
        {
            cells[coord.row, coord.col].update_value_warnings ();
            cells[coord.row, coord.col].update_all_earmark_warnings ();
        }
    }

    public void set_selected (int cell_row, int cell_col)
    {
        if (cells[cell_row, cell_col].selected)
            return;

        var old_row = selected_row;
        var old_col = selected_col;

        selected_cell.selected = false;
        selected_row = cell_row;
        selected_col = cell_col;
        selected_cell.selected = true;

        number_picker.popdown ();
        update_highlighter (old_row, old_col);
    }

    public void unselect ()
    {
        number_picker.popdown ();
        selected_cell.selected = false;
        set_cell_highlighter (selected_row, selected_col, false);
    }

    private void move (Variant? variant)
    {
        var dir = (DirectionType) variant.get_int32 ();
        focus (dir);
    }

    private void button_released_cb (GestureClick gesture,
                                     int          n_press,
                                     double       x,
                                     double       y)
    {
        if (gesture.get_current_button () != BUTTON_PRIMARY &&
            gesture.get_current_button () != BUTTON_SECONDARY)
            return;

        number_picker.popdown ();
        gesture.set_state (EventSequenceState.CLAIMED);
    }

    private void value_changed_cb (int row, int col, int old_val, int new_val)
    {
        var action = game.get_current_stack_action ();
        if (action.is_single_value_change ())
            cells[row, col].grab_selection ();

        cells[row, col].update_content_visibility ();

        update_warnings ();
        update_value_highlighter (row, col, old_val, new_val);
    }

    private void earmark_changed_cb (int row, int col, int num, bool enabled)
    {
        var action = game.get_current_stack_action ();
        if (action.is_single_earmarks_change ())
        {
            cells[row, col].grab_selection ();
            cells[row, col].update_earmark_visibility (num);
        }
        else
        {
            if (!enabled && action == StackAction.INSERT_AND_DISABLE_RELATED_EARMARKS)
                cells[row, col].animate_earmark_removal (num);
            else
                cells[row, col].update_earmark_visibility (num);
        }

        if (Sudoku.app.earmark_warnings)
            cells[row, col].add_earmark_warnings (num);
    }

    private void paused_cb ()
    {
        if (game.paused)
            unselect ();
        else
            grab_focus ();
    }

    public override bool grab_focus ()
    {
        var window = root as SudokuWindow;

        if (window.keyboard_pressed_recently)
            return selected_cell.grab_selection ();
        else
            return selected_cell.grab_focus ();
    }

    public override bool focus (DirectionType direction)
    {
        switch (direction)
        {
            case DirectionType.TAB_FORWARD:
                //this lets us control the focus when it comes from the headerbar and gtk/adwaita
                if (!focus_controller.contains_focus)
                    return grab_focus ();
                else
                    return EVENT_PROPAGATE; //propagate the event so that the focus moves to the headerbar

            case DirectionType.TAB_BACKWARD:
                if (!focus_controller.contains_focus)
                    return grab_focus ();
                else
                    return EVENT_PROPAGATE;

            case DirectionType.UP:
                if (selected_row == 0)
                    return cells[8, selected_col].focus (direction);
                else
                    return cells[selected_row - 1, selected_col].focus (direction);

            case DirectionType.DOWN:
                if (selected_row == 8)
                    return cells[0, selected_col].focus (direction);
                else
                    return cells[selected_row + 1, selected_col].focus (direction);

            case DirectionType.LEFT:
                if (selected_col == 0)
                    return cells[selected_row, 8].focus (direction);
                else
                    return cells[selected_row, selected_col - 1].focus (direction);

            case DirectionType.RIGHT:
                if (selected_col == 8)
                    return cells[selected_row, 0].focus (direction);
                else
                    return cells[selected_row, selected_col + 1].focus (direction);
            default:
                assert_not_reached ();
        }
    }

    public override void dispose ()
    {
        number_picker.unparent ();
        base.dispose ();
    }
}
