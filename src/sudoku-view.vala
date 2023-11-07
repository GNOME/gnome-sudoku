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
    public SudokuGame game;
    private SudokuCell[,] cells;
    private Label paused;

    private bool previous_board_broken = false;

    private Overlay overlay;
    private Grid grid;

    public int selected_row = 0;
    public int selected_col = 0;
    private void set_selected (int cell_row, int cell_col)
    {
        if (selected_row >= 0 && selected_col >= 0)
        {
            cells[selected_row, selected_col].selected = false;
        }
        selected_row = cell_row;
        selected_col = cell_col;
        if (selected_row >= 0 && selected_col >= 0)
        {
            cells[selected_row, selected_col].selected = true;
        }
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
                var cell = new SudokuCell (row, col, ref this.game);
                var cell_row = row;
                var cell_col = col;

                cell.notify["has-focus"].connect (() => {
                    if (game.paused)
                        return;

                    // Popover is needed because when the popover is open, the focus shifts.
                    // However, the current cell should still be selected.
                    if (cell.has_focus || cell.popover.visible)
                        this.set_selected (cell_row, cell_col);
                    else
                        this.set_selected (-1, -1);

                    this.update_highlights ();
                    cell.check_warnings ();
                });

                cell.notify["value"].connect ((s, p)=> {
                    if (_show_possibilities || _show_warnings || game.board.broken || previous_board_broken)
                        previous_board_broken = game.board.broken;

                    this.update_highlights ();
                    cell.check_warnings ();
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

    private void update_highlights ()
    {
        var has_selection = selected_row >= 0 && selected_col >= 0;
        var cell_value = -1;
        if (has_selection)
            cell_value = cells[selected_row, selected_col].value;

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
                    cells[row_tmp, col_tmp].highlighted_value = cell_value == cells[row_tmp, col_tmp].value;
                }
            }
        }
    }

    public void clear ()
    {
        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                game.board.disable_all_earmarks (i, j);
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
        }
    }
}

