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


[GtkTemplate (ui = "/org/gnome/Sudoku/ui/game-view.ui")]
public class SudokuGameView : Adw.Bin
{
    [GtkChild] private unowned Label paused_label;
    [GtkChild] private unowned Overlay overlay;
    [GtkChild] private unowned Grid grid;

    private EventControllerKey key_controller;
    private EventControllerFocus focus_controller;
    private GestureClick grid_button_controller;

    private SudokuCell[,] cells;

    public SudokuNumberPicker number_picker;
    public SudokuGame game;

    public double value_zoom_multiplier { get; private set; }
    public bool keep_focus { get; set; default = false; }

    private const Coord START = {4, 4};

    public int selected_row { get; private set; default = START.row; }
    public int selected_col { get; private set; default = START.col; }

    private SudokuCell selected_cell
    {
        get { return cells[selected_row, selected_col]; }
    }

    public SudokuGameView (SudokuBoard board)
    {
        game = new SudokuGame (board);

        Sudoku.app.notify["show-warnings"].connect (warnings_cb);
        Sudoku.app.notify["earmark-warnings"].connect (warnings_cb);
        Sudoku.app.notify["solution-warnings"].connect (warnings_cb);
        Sudoku.app.notify["highlighter"].connect (highlighter_cb);
        Sudoku.app.notify["zoom-level"].connect (update_zoom);
        Sudoku.app.notify["show-possibilities"].connect (show_possibilities_cb);

        if (game.board.previous_played_time == 0.0)
            add_earmark_possibilities ();

        this.vexpand = true;
        this.focusable = true;

        number_picker = new SudokuNumberPicker (game);
        layout_manager = new SudokuGameViewLayoutManager ();

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
        game.notify["paused"].connect(paused_cb);
        game.notify["board"].connect(board_changed_cb);

        key_controller = new EventControllerKey ();
        key_controller.key_pressed.connect (key_pressed_cb);
        add_controller (key_controller);

        focus_controller = new EventControllerFocus ();
        focus_controller.leave.connect (() => {
            Window window = get_root () as Window;
            if (window.is_active)
                unselect ();
        });
        add_controller (focus_controller);

        //grid controller handles input between cells
        grid_button_controller = new GestureClick ();
        grid_button_controller.set_button (0 /* all buttons */);
        grid_button_controller.released.connect (grid_button_released_cb);
        grid.add_controller (grid_button_controller);

        update_zoom ();
        update_warnings ();
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
                    return focus (DirectionType.UP);

                case Key.s :
                    return focus (DirectionType.DOWN);

                case Key.a :
                    return focus (DirectionType.LEFT);

                case Key.d :
                    return focus (DirectionType.RIGHT);

                case Key.Escape:
                    unselect ();
                    keep_focus = true;
                    return EVENT_STOP;

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

            case Key.space : case Key.Return : case Key.KP_Enter:
                selected_cell.grab_focus ();
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
        {
            cells[row, col].grab_focus ();
            cells[row, col].update_earmark_visibility (num);
        }
        else
        {
            if (!enabled && action == StackAction.INSERT_AND_DISABLE_RELATED_EARMARKS)
                cells[row, col].animate_earmark_removal (num);
            else
                cells[row, col].update_earmark_visibility (num);
        }

        if (Sudoku.app.show_warnings && Sudoku.app.earmark_warnings)
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

        can_focus = !game.paused;

        if (game.paused)
        {
            overlay.add_overlay (paused_label);
            overlay.add_css_class ("paused");
            unselect ();
        }
        else
        {
            overlay.remove_overlay (paused_label);
            overlay.remove_css_class ("paused");
            grab_focus ();
        }
    }

    public void set_selected (int cell_row, int cell_col)
    {
        if (cells[cell_row, cell_col].selected)
            return;

        keep_focus = false;

        var old_row = selected_row;
        var old_col = selected_col;

        selected_cell.selected = false;
        selected_row = cell_row;
        selected_col = cell_col;
        selected_cell.selected = true;

        dismiss_picker ();
        update_highlighter (old_row, old_col);
    }

    public void unselect ()
    {
        number_picker.popdown ();
        selected_cell.selected = false;
        if (Sudoku.app.highlighter)
            set_cell_highlighter (selected_row, selected_col, false);
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
        if (game.get_current_stack_action () == StackAction.ENABLE_ALL_EARMARK_POSSIBILITIES)
            game.undo ();
        else
            add_earmark_possibilities ();
    }

    private void highlighter_cb ()
    {
        selected_cell.grab_focus ();

        if (!Sudoku.app.highlighter)
            set_cell_highlighter (selected_row, selected_col, false);
        else if (focus_controller.contains_focus)
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
        add_earmark_possibilities ();
        update_warnings ();
        game.board.value_changed.connect (value_changed_cb);
        game.board.earmark_changed.connect (earmark_changed_cb);
        cells[START.row, START.col].grab_focus ();
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

    private void add_earmark_possibilities ()
    {
        if (Sudoku.app.show_possibilities && game.mode != GameMode.CREATE)
            game.enable_all_earmark_possibilities ();
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

    private void grid_button_released_cb (GestureClick gesture,
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

    public void dismiss_picker ()
    {
        number_picker.popdown ();
    }

    public override bool grab_focus ()
    {
        if (keep_focus)
            return base.grab_focus ();
        else
            return selected_cell.grab_focus ();
    }

    public override bool focus (DirectionType direction)
    {
        switch (direction)
        {
            case DirectionType.TAB_FORWARD:
                //this lets us control the focus when it comes from the headerbar
                if (!focus_controller.contains_focus)
                    return selected_cell.focus (direction);
                //propagate the event so that the focus moves to the headerbar
                else
                    return EVENT_PROPAGATE;

            case DirectionType.TAB_BACKWARD:
                if (!focus_controller.contains_focus)
                    return selected_cell.focus (direction);
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
        if (!game.paused)
            game.stop_clock ();

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
