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
    private SudokuGame game;
    private SudokuCell[,] cells;

    public bool autoclean_earmarks;
    public bool highlight_row_column;
    public bool highlight_block;
    public bool highlight_numbers;

    public int selected_row { get; private set; default = 0; }
    public int selected_col { get; private set; default = 0; }

    public signal void selection_changed (int old_row, int old_col, int new_row, int new_col);

    public void set_selected (int cell_row, int cell_col)
    {
        if (selected_row == cell_row && selected_col == cell_col)
            return;

        if (selected_row >= 0 && selected_col >= 0)
            cells[selected_row, selected_col].selected = false;

        var old_row = selected_row;
        var old_col = selected_col;

        selected_row = cell_row;
        selected_col = cell_col;

        selection_changed(old_row, old_col, selected_row, selected_col);

        if (selected_row >= 0 && selected_col >= 0)
            cells[selected_row, selected_col].selected = true;
    }

    public SudokuView (SudokuGame game, GLib.Settings settings)
    {
        this.game = game;

        this.vexpand = true;
        this.focusable = true;
        this.can_focus = true;

        if (game.mode == GameMode.CREATE)
            this._show_warnings = true;
        else
            this._show_warnings = settings.get_boolean ("show-warnings");
        this._show_possibilities = settings.get_boolean ("show-possibilities");
        this._simple_warnings = settings.get_boolean ("simple-warnings");
        this._show_earmark_warnings = settings.get_boolean ("show-earmark-warnings");
        this._highlighter = settings.get_boolean ("highlighter");
        this.autoclean_earmarks = settings.get_boolean ("autoclean-earmarks");
        this.highlight_row_column = settings.get_boolean ("highlight-row-column");
        this.highlight_block = settings.get_boolean ("highlight-block");
        this.highlight_numbers = settings.get_boolean ("highlight-numbers");

        var overlay = new Overlay ();
        var frame = new SudokuFrame (overlay);
        this.set_child (frame);

        var paused_label = new Gtk.Label ("Paused");
        paused_label.add_css_class ("paused");
        paused_label.set_visible (false);
        overlay.add_overlay (paused_label);

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

        this.game.board.cell_changed.connect (cell_changed_cb);
        this.game.board.earmark_changed.connect (earmark_changed_cb);
        this.selection_changed.connect (selection_changed_cb);

        if (show_possibilities && game.mode != GameMode.CREATE && game.board.previous_played_time == 0.0)
            game.enable_all_earmark_possibilities ();

        update_warnings ();
    }

    static construct {
        ShortcutFunc up_func = (self) => {
            var view = (SudokuView) self;

            if (view.selected_row == -1 || view.selected_col == -1)
                return Gdk.EVENT_PROPAGATE;

            if (view.selected_row == 0)
                view.cells[8, view.selected_col].grab_focus ();
            else
                view.cells[view.selected_row - 1, view.selected_col].grab_focus ();

            return Gdk.EVENT_STOP;
        };
        ShortcutFunc down_func = (self) => {
            var view = (SudokuView) self;

            if (view.selected_row == -1 || view.selected_col == -1)
                return Gdk.EVENT_PROPAGATE;

            if (view.selected_row == 8)
                view.cells[0, view.selected_col].grab_focus ();
            else
                view.cells[view.selected_row + 1, view.selected_col].grab_focus ();

            return Gdk.EVENT_STOP;
        };
        ShortcutFunc left_func = (self) => {
            var view = (SudokuView) self;

            if (view.selected_row == -1 || view.selected_col == -1)
                return Gdk.EVENT_PROPAGATE;

            if (view.selected_col == 0)
                view.cells[view.selected_row, 8].grab_focus ();
            else
                view.cells[view.selected_row, view.selected_col - 1].grab_focus ();

            return Gdk.EVENT_STOP;
        };
        ShortcutFunc right_func = (self) => {
            var view = (SudokuView) self;

            if (view.selected_row == -1 || view.selected_col == -1)
                return Gdk.EVENT_PROPAGATE;

            if (view.selected_col == 8)
                view.cells[view.selected_row, 0].grab_focus ();
            else
                view.cells[view.selected_row, view.selected_col + 1].grab_focus ();

            return Gdk.EVENT_STOP;
        };

        add_binding (Gdk.Key.Up, 0, up_func, null);
        add_binding (Gdk.Key.KP_Up, 0, up_func, null);
        add_binding (Gdk.Key.w, 0, up_func, null);
        add_binding (Gdk.Key.Down, 0, down_func, null);
        add_binding (Gdk.Key.KP_Down, 0, down_func, null);
        add_binding (Gdk.Key.s, 0, down_func, null);
        add_binding (Gdk.Key.Left, 0, left_func, null);
        add_binding (Gdk.Key.KP_Left, 0, left_func, null);
        add_binding (Gdk.Key.a, 0, left_func, null);
        add_binding (Gdk.Key.Right, 0, right_func, null);
        add_binding (Gdk.Key.KP_Right, 0, right_func, null);
        add_binding (Gdk.Key.d, 0, right_func, null);
    }

    private void selection_changed_cb (int old_row, int old_col, int new_row, int new_col)
    {
        set_cell_highlighter (old_row, old_col, false);
        set_cell_highlighter (new_row, new_col, true);
        cells[old_row, old_col].dismiss_popover ();
    }

    private void cell_changed_cb (int row, int col, int old_val, int new_val)
    {
        var action = game.get_current_stack_action ();
        if (!action.is_multi_value_step ())
            cells[row, col].grab_focus ();

        cells[row, col].update_value ();
        update_warnings ();
        set_value_highlighter (old_val, false);
        set_value_highlighter (new_val, true);
    }

    private void earmark_changed_cb (int row, int col, int num, bool enabled)
    {
        var action = game.get_current_stack_action ();
        if (!action.is_multi_step ())
            cells[row, col].grab_focus ();

        cells[row, col].get_visible_earmark (num);
        if (show_warnings && enabled)
            cells[row, col].check_earmark_warnings (num);
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
                        cell_tmp.highlighted_value = enabled;
                    else if (cell_tmp.value == 0)
                        cell_tmp.set_earmark_highlight (cell.value, enabled);
                }

                if (!cell_tmp.is_fixed &&
                   ((highlight_row_column && (row_tmp == row || col_tmp == col)) ||
                   (highlight_block &&
                   row_tmp / game.board.block_cols == row / game.board.block_cols &&
                   col_tmp / game.board.block_rows == col / game.board.block_rows)))
                {
                    cell_tmp.highlighted_background = enabled;
                }
            }
        }
    }

    private void set_value_highlighter (int val, bool enabled)
    {
        if (!highlighter || val == 0 || !highlight_numbers)
            return;

        var cell = cells[selected_row, selected_col];

        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
        {
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
            {
                var cell_tmp = cells[row_tmp, col_tmp];

                if (cell == cell_tmp)
                    continue;

                if (val == cell_tmp.value)
                    cell_tmp.highlighted_value = enabled;
                else if (cell_tmp.value == 0)
                    cell_tmp.set_earmark_highlight (val, enabled);
            }
        }
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

    private bool _simple_warnings;
    public bool simple_warnings
    {
        get { return _simple_warnings; }
        set {
            _simple_warnings = value;
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
            var cell = cells[selected_row, selected_col];
            cell.selected = has_selection;
            if (has_selection)
                cell.grab_focus ();
            else
                cell.dismiss_popover ();

            set_cell_highlighter (selected_row, selected_col, has_selection);
        }
    }

    public void dismiss_popovers ()
    {
        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                cells[i,j].dismiss_popover ();
    }
}

