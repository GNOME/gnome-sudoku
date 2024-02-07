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
    private SudokuGame _game;
    public SudokuGame game
    {
        get { return _game; }
        private set { _game = value; }
    }

    private SudokuCell[,] cells;
    private Label paused;

    private Overlay overlay;
    private Grid grid;

    public int selected_row { get; private set; default = 0; }
    public int selected_col { get; private set; default = 0; }
    public signal void selection_changed (int old_row, int old_col, int new_row, int new_col);

    private void set_selected (int cell_row, int cell_col)
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

    public SudokuView (int frame_size, SudokuGame game)
    {
        this.vexpand = true;

        this.focusable = true;
        this.can_focus = true;

        overlay = new Overlay ();
        var frame = new SudokuFrame (overlay);
        this.set_child (frame);

        this.paused = new Gtk.Label ("Paused");
        this.paused.add_css_class ("paused");

        if (grid != null)
            overlay.set_child (null);

        this.game = game;
        this.game.paused_changed.connect(() => {
            // Set Font Size
            var attr_list = this.paused.get_attributes ();
            if (attr_list == null)
                attr_list = new Pango.AttrList ();

            attr_list.change (
                Pango.AttrSize.new_absolute ((int) (this.get_width () * 0.125) * Pango.SCALE)
            );

            this.paused.set_attributes (attr_list);

            if (this.game.paused)
                paused.set_visible (true);
            else
                paused.set_visible (false);
        });

        this.game.cell_changed.connect (cell_changed_cb);
        this.game.board.earmark_changed.connect (earmark_changed_cb);
        this.selection_changed.connect (selection_changed_cb);

        grid = new Grid () {
            row_spacing = 2,
            column_spacing = 2,
            column_homogeneous = true,
            row_homogeneous = true,
            vexpand = true,
            hexpand = true
        };
        grid.add_css_class ("board");

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
                var cell = new SudokuCell (row, col, ref _game);
                var cell_row = row;
                var cell_col = col;

                cell.notify["has-focus"].connect (() => {
                    if (game.paused)
                        return;

                    if (cell.has_focus)
                        this.set_selected (cell_row, cell_col);
                });

                cell.will_open_popover.connect (() => {
                    dismiss_popovers ();
                });

                cells[row, col] = cell;

                blocks[row / game.board.block_rows, col / game.board.block_cols].attach (cell, col % game.board.block_cols, row % game.board.block_rows);
            }
        }

        overlay.add_overlay (paused);
        overlay.set_child (grid);
        grid.show ();
        overlay.show ();
        paused.set_visible (false);
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

            view.dismiss_popovers ();
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

            view.dismiss_popovers ();
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

            view.dismiss_popovers ();
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

            view.dismiss_popovers ();
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
        cells[row, col].update_value ();

        set_value_highlighter (old_val, false);
        set_value_highlighter (new_val, true);
        update_warnings ();
    }

    private void earmark_changed_cb (int row, int col, bool enabled, int val)
    {
        cells[row, col].update_earmark (val, enabled);
    }


        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
        {
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
            {
                cells[row_tmp, col_tmp].check_warnings ();
                if (has_selection && _highlighter) {
                    cells[row_tmp, col_tmp].highlighted_background = (
                        col_tmp == selected_col ||
                        row_tmp == selected_row ||
                        (col_tmp / game.board.block_cols == selected_col / game.board.block_cols &&
                         row_tmp / game.board.block_rows == selected_row / game.board.block_rows)
                    );
                    if (cell_value > 0)
                        cells[row_tmp, col_tmp].highlighted_value = cell_value == cells[row_tmp, col_tmp].value;
                    else
                        cells[row_tmp, col_tmp].highlighted_value = false;
                }
            }
        }
    }

    private void clear_highlights ()
    {
        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
        {
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
            {
                cells[row_tmp, col_tmp].highlighted_value = false;
                cells[row_tmp, col_tmp].highlighted_background = false;
            }
        }
    }

    private void update_warnings ()
    {
        if (!show_warnings)
            return;

        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
                cells[row_tmp, col_tmp].check_warnings ();
    }

    public void clear ()
    {
        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                game.board.disable_all_earmarks (i, j);
    }

    private void clear_all_warnings ()
    {
        for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
            for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
            {
                cells[row_tmp, col_tmp].clear_warnings ();
            }
    }

    public void redraw ()
    {
        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                cells[i,j].check_warnings ();
    }

    private bool _show_warnings = false;
    public bool show_warnings
    {
        get { return _show_warnings; }
        set {
            _show_warnings = value;
            for (var i = 0; i < game.board.rows; i++)
                for (var j = 0; j < game.board.cols; j++)
                    cells[i,j].show_warnings = _show_warnings;

            if (show_warnings)
                update_warnings ();
            else
                clear_all_warnings ();
         }
    }

    private bool _show_extra_warnings = false;
    public bool show_extra_warnings
    {
        get { return _show_extra_warnings; }
        set {
            _show_extra_warnings = value;
            for (var i = 0; i < game.board.rows; i++)
                for (var j = 0; j < game.board.cols; j++)
                    cells[i,j].show_extra_warnings = _show_extra_warnings;
         }
    }

    private bool _show_possibilities = false;
    public bool show_possibilities
    {
        get { return _show_possibilities; }
        set {
            _show_possibilities = value;
            for (var i = 0; i < game.board.rows; i++)
                for (var j = 0; j < game.board.cols; j++)
                    cells[i,j].show_possibilities = value;
        }
    }

    private bool _initialize_earmarks = false;
    public bool initialize_earmarks
    {
        get { return _initialize_earmarks; }
        set {
            _initialize_earmarks = value;
            for (var i = 0; i < game.board.rows; i++)
                for (var j = 0; j < game.board.cols; j++)
                    cells[i,j].initialize_earmarks = value;
        }
    }

    private bool _highlighter = false;
    public bool highlighter
    {
        get { return _highlighter; }
        set {
            _highlighter = value;
            if (!_highlighter)
                clear_highlights ();
        }
    }

    public void dismiss_popovers ()
    {
        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                cells[i,j].dismiss_popover ();
    }
}

