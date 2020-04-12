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
using Gdk;

private class SudokuCellView : DrawingArea
{
    private double size_ratio = 2;

    private Popover popover;
    private Popover earmark_popover;

    private SudokuGame game;

    private int row;
    private int col;

    public int value
    {
        get { return game.board [row, col]; }
        set
        {
            if (is_fixed)
            {
                if (game.mode == GameMode.PLAY)
                    return;
            }
            if (value == 0)
            {
                if (game.board [row, col] != 0)
                    game.remove (row, col);
                if (game.mode == GameMode.PLAY)
                    return;
            }
            if (value == game.board [row, col])
                return;

            game.insert (row, col, value);
        }
    }

    public bool is_fixed
    {
        get { return game.board.is_fixed[row, col]; }
    }

    private bool _show_possibilities;
    public bool show_possibilities
    {
        get { return _show_possibilities; }
        set
        {
            _show_possibilities = value;
            queue_draw ();
        }
    }

    private bool _show_warnings = true;
    public bool show_warnings
    {
        get { return _show_warnings; }
        set
        {
            _show_warnings = value;
            queue_draw ();
        }
    }

    public bool selected { get; set; }
    public bool highlighted { get; set; }

    private NumberPicker number_picker;
    private NumberPicker earmark_picker;

    internal EventControllerFocus focus_controller; // for keeping in memory
    private EventControllerKey key_controller;      // for keeping in memory
    private GestureClick click_controller;          // for keeping in memory

    public SudokuCellView (int row, int col, ref SudokuGame game)
    {
        this.game = game;
        this.row = row;
        this.col = col;

        init_mouse ();
        init_keyboard ();
        set_draw_func (draw);

        value = game.board [row, col];

        // background_color is set in the SudokuView, as it manages the color of the cells

        can_focus = true;

        if (is_fixed && game.mode == GameMode.PLAY)
            return;

        game.cell_changed.connect (cell_changed_cb);
    }

    private inline void init_mouse ()  // called on construct
    {
        click_controller = new Gtk.GestureClick ();
        click_controller.set_button (/* all buttons */ 0);
        click_controller.pressed.connect (on_click);
        add_controller (click_controller);
    }

    private inline void on_click (GestureClick _click_controller, int n_press, double event_x, double event_y)
    {
        uint button = _click_controller.get_current_button ();
        if (button != Gdk.BUTTON_PRIMARY && button != Gdk.BUTTON_SECONDARY)
            return;

        if (!is_focus ())
            grab_focus ();
        if (game.mode == GameMode.PLAY && (is_fixed || game.paused))
            return;

        if (popover != null || earmark_popover != null)
        {
            hide_both_popovers ();
            return;
        }

        if (button == Gdk.BUTTON_PRIMARY)       // Left-Click
        {
            Gdk.ModifierType state = _click_controller.get_current_event_state ();
            if (!_show_possibilities && (state & ModifierType.CONTROL_MASK) > 0 && game.mode == GameMode.PLAY)
                show_earmark_picker ();
            else
                show_number_picker ();
        }
        else if (!_show_possibilities && button == Gdk.BUTTON_SECONDARY && game.mode == GameMode.PLAY)      // Right-Click
            show_earmark_picker ();
    }

    private void create_earmark_picker ()
    {
        earmark_picker = new NumberPicker (ref game.board, true);
        earmark_picker.earmark_state_changed.connect ((number, state) => {
            if (state)
                this.game.enable_earmark (row, col, number);
            else
                this.game.disable_earmark (row, col, number);
            this.game.cell_changed (row, col, value, value);
            queue_draw ();
        });
        earmark_picker.set_earmarks (row, col);
    }

    private EventControllerFocus popover_focus_controller;
    private void show_number_picker ()
    {
        if (earmark_popover != null)
            earmark_popover.popdown ();

        number_picker = new NumberPicker (ref game.board);
        number_picker.number_picked.connect ((o, number) => {
            value = number;
            if (number == 0)
                notify_property ("value");
            this.game.board.disable_all_earmarks (row, col);

            popover.popdown ();
        });
        number_picker.set_clear_button_visibility (value != 0);

        popover = new Popover ();
        popover.add (number_picker);
        popover.set_autohide (false);
        popover.position = PositionType.BOTTOM;
        popover.notify["visible"].connect (()=> {
            if (!popover.visible)
                destroy_popover (ref popover, ref number_picker);
        });
        popover_focus_controller = new EventControllerFocus ();
        popover_focus_controller.leave.connect (popover.popdown);
        ((Widget) popover).add_controller (popover_focus_controller);

        popover.popup ();
    }

    private EventControllerFocus earmark_focus_controller;
    private void show_earmark_picker ()
    {
        if (popover != null)
            popover.popdown ();

        create_earmark_picker ();

        earmark_popover = new Popover ();
        earmark_popover.add (earmark_picker);
        earmark_popover.set_autohide (false);
        earmark_popover.position = PositionType.BOTTOM;
        earmark_popover.notify["visible"].connect (()=> {
            if (!earmark_popover.visible)
                destroy_popover (ref earmark_popover, ref earmark_picker);
        });
        earmark_focus_controller = new EventControllerFocus ();
        earmark_focus_controller.leave.connect (earmark_popover.popdown);
        ((Widget) earmark_popover).add_controller (earmark_focus_controller);

        earmark_popover.popup ();
    }

    private void destroy_popover (ref Popover popover, ref NumberPicker picker)
    {
        picker = null;
        if (popover != null)
        {
            popover.destroy ();
            popover = null;
        }
    }

    public void hide_both_popovers ()
    {
        if (popover != null)
            popover.popdown ();
        if (earmark_popover != null)
            earmark_popover.popdown ();
    }

    /* Key mapping function to help convert Gdk.keyval_name string to numbers */
    private int key_map_keypad (string key_name)
    {
        /* Compared with "0" to make sure, actual "0" is not misinterpreted as parse error in int.parse() */
        if (key_name == "KP_0" || key_name == "0")
            return 0;
        if (key_name == "KP_1")
            return 1;
        if (key_name == "KP_2")
            return 2;
        if (key_name == "KP_3")
            return 3;
        if (key_name == "KP_4")
            return 4;
        if (key_name == "KP_5")
            return 5;
        if (key_name == "KP_6")
            return 6;
        if (key_name == "KP_7")
            return 7;
        if (key_name == "KP_8")
            return 8;
        if (key_name == "KP_9")
            return 9;
        return -1;
    }

    private inline void init_keyboard ()  // called on construct
    {
        focus_controller = new EventControllerFocus ();
        focus_controller.leave.connect (on_focus_out);
        add_controller (focus_controller);

        key_controller = new EventControllerKey ();
        key_controller.key_pressed.connect (on_key_pressed);
        add_controller (key_controller);
    }

    private inline void on_focus_out ()
    {
        hide_both_popovers ();
    }

    private inline bool on_key_pressed (EventControllerKey _key_controller, uint keyval, uint keycode, ModifierType state)
    {
        if (game.mode == GameMode.PLAY && (is_fixed || game.paused))
            return false;
        string k_name = keyval_name (keyval);
        int k_no = int.parse (k_name);
        /* If k_no is 0, there might be some error in parsing, crosscheck with keypad values. */
        if (k_no == 0)
            k_no = key_map_keypad (k_name);
        if (k_no >= 1 && k_no <= 9)
        {
            bool want_earmark = (earmark_popover != null && earmark_popover.is_visible ())
                || (state & ModifierType.CONTROL_MASK) > 0;
            if (want_earmark && game.mode == GameMode.PLAY)
            {
                var new_state = !game.board.is_earmark_enabled (row, col, k_no);
                if (new_state)
                    game.enable_earmark (row, col, k_no);
                else
                    game.disable_earmark (row, col, k_no);

                if (earmark_picker != null)
                    earmark_picker.set_earmark (row, col, k_no-1, new_state);

                queue_draw ();
            }
            else
            {
                value = k_no;
                this.game.board.disable_all_earmarks (row, col);
                hide_both_popovers ();
            }
            return true;
        }
        if (k_no == 0 || k_name == "BackSpace" || k_name == "Delete")
        {
            value = 0;
            notify_property ("value");
            return true;
        }

        if (k_name == "space" || k_name == "Return" || k_name == "KP_Enter")
        {
            if (popover != null)
            {
                popover.popdown ();
                return false;
            }
            show_number_picker ();
            return true;
        }

        if (k_name == "Escape")
        {
            hide_both_popovers ();
            return true;
        }

        return false;
    }

    private inline void draw (DrawingArea _this, Cairo.Context c, int new_width, int new_height)
    {
        RGBA background_color;
        if (_selected)
            background_color = selected_bg_color;
        else if (is_fixed)
            background_color = fixed_cell_color;
        else if (_highlighted)
            background_color = highlight_color;
        else
            background_color = free_cell_color;
        c.set_source_rgba (background_color.red, background_color.green, background_color.blue, background_color.alpha);
        c.rectangle (0, 0, get_allocated_width (), get_allocated_height ());
        c.fill();

        if (_show_warnings && game.board.broken_coords.contains (Coord (row, col)))
            c.set_source_rgb (1.0, 0.0, 0.0);
        else if (_selected)
            c.set_source_rgb (0.2, 0.2, 0.2);
        else
            c.set_source_rgb (0.0, 0.0, 0.0);

        if (game.paused)
            return;

        if (value != 0)
        {
            double height = (double) get_allocated_height ();
            double width = (double) get_allocated_width ();
            string text = "%d".printf (value);

            c.set_font_size (height / size_ratio);
            print_centered (c, text, width, height);
            return;
        }

        if (is_fixed && game.mode == GameMode.PLAY)
            return;

        bool[] marks = null;
        if (!_show_possibilities)
        {
            marks = game.board.get_earmarks (row, col);
        }
        else if (value == 0)
        {
            marks = game.board.get_possibilities_as_bool_array (row, col);
        }

        if (marks != null)
        {
            double possibility_size = get_allocated_height () / size_ratio / 2;
            c.set_font_size (possibility_size);
            c.set_source_rgb (0.0, 0.0, 0.0);

            double height = (double) get_allocated_height () / game.board.block_rows;
            double width = (double) get_allocated_width () / game.board.block_cols;

            int num = 0;
            for (int row_tmp = 0; row_tmp < game.board.block_rows; row_tmp++)
            {
                for (int col_tmp = 0; col_tmp < game.board.block_cols; col_tmp++)
                {
                    num++;

                    if (marks[num - 1])
                    {
                        var text = "%d".printf (num);

                        c.save ();
                        c.translate (col_tmp * width, (game.board.block_rows - row_tmp - 1) * height);
                        print_centered (c, text, width, height);
                        c.restore ();
                    }
                }
            }
        }

        if (_show_warnings && (value == 0 && game.board.count_possibilities (row, col) == 0))
        {
            c.set_font_size (get_allocated_height () / size_ratio);
            c.set_source_rgb (1.0, 0.0, 0.0);
            print_centered (c, "X", get_allocated_width (), get_allocated_height ());
        }
    }

    private void print_centered (Cairo.Context c, string text, double width, double height)
    {
        Cairo.FontExtents font_extents;
        c.font_extents (out font_extents);

        Cairo.TextExtents text_extents;
        c.text_extents (text, out text_extents);

        c.move_to (
            (width - text_extents.width) / 2 - text_extents.x_bearing,
            (height + font_extents.height) / 2 - font_extents.descent
        );
        c.show_text (text);
    }

    public void cell_changed_cb (int row, int col, int old_val, int new_val)
    {
        if (row == this.row && col == this.col)
        {
            this.value = new_val;
            notify_property ("value");
        }
    }

    public void clear ()
    {
        game.board.disable_all_earmarks (row, col);
    }
}

public const RGBA  fixed_cell_color = { 0.8f,  0.8f,  0.8f,  1.0f };
public const RGBA   free_cell_color = { 1.0f,  1.0f,  1.0f,  1.0f };
public const RGBA   highlight_color = { 0.93f, 0.93f, 0.93f, 1.0f };
public const RGBA selected_bg_color = { 0.7f,  0.8f,  0.9f,  1.0f };

public class SudokuView : Widget
{
    public SudokuGame game;
    private SudokuCellView[,] cells;

    private bool previous_board_broken_state = false;

    private AspectFrame frame;
    private Overlay     overlay;
    private DrawingArea drawing;
    private Grid        grid;

    private int selected_row = 0;
    private int selected_col = 0;
    private void set_selected (int cell_row, int cell_col)
    {
        cells[selected_row, selected_col].selected = false;
        cells[selected_row, selected_col].queue_draw ();
        selected_row = cell_row;
        selected_col = cell_col;
        cells[selected_row, selected_col].selected = true;
    }

    public SudokuView (SudokuGame game)
    {
        BinLayout layout = new BinLayout ();
        set_layout_manager (layout);

        frame = new AspectFrame (/* no title */ null, /* xalign */ 0.5f, /* yalign */ 0.5f, /* ratio */ 1.0f, /* obey child */ false);
        frame.shadow_type = ShadowType.NONE;
        frame.insert_after (this, /* insert first */ null);

        overlay = new Overlay ();
        frame.add (overlay);

        drawing = new DrawingArea ();
        drawing.visible = false;
        drawing.set_draw_func (draw_board);

        if (grid != null)
            overlay.remove (grid);

        this.game = game;
        this.game.paused_changed.connect(() => {
            if (this.game.paused)
                drawing.show ();
            else
                drawing.hide ();
        });

        var css_provider = new CssProvider ();
        try {
            css_provider.load_from_data ("
                grid.board {
                    border: 2px solid #333;
                    background: #333;
                }
                grid.block {
                    background: #999;
                }
            ");
        } catch (Error e) {
            assert_no_error(e);
        }

        grid = new Grid ();
        grid.row_spacing = 2;
        grid.column_spacing = 2;
        grid.column_homogeneous = true;
        grid.row_homogeneous = true;
        grid.get_style_context ().add_class ("board");
        grid.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

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
                block_grid.get_style_context ().add_class ("block");
                block_grid.get_style_context ().add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                grid.attach (block_grid, block_col, block_row, 1, 1);

                blocks[block_row, block_col] = block_grid;
            }
        }

        cells = new SudokuCellView[game.board.rows, game.board.cols];
        for (var row = 0; row < game.board.rows; row++)
        {
            for (var col = 0; col < game.board.cols; col++)
            {
                var cell = new SudokuCellView (row, col, ref this.game);
                var cell_row = row;
                var cell_col = col;

                cell.focus_controller.enter.connect (() => {
                    if (game.paused)
                        return;

                    this.set_selected (cell_row, cell_col);

                    for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
                    {
                        for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++) {
                            cells[row_tmp, col_tmp].highlighted = _highlighter && (
                                col_tmp == cell_col ||
                                row_tmp == cell_row ||
                                (col_tmp / game.board.block_cols == cell_col / game.board.block_cols &&
                                 row_tmp / game.board.block_rows == cell_row / game.board.block_rows)
                            );
                        }
                    }

                    queue_draw ();
                });

                cell.notify["value"].connect ((s, p)=> {
                    if (_show_possibilities || _show_warnings || game.board.broken || previous_board_broken_state)
                        previous_board_broken_state = game.board.broken;

                    // Redraw the board
                    this.queue_draw ();
                });

                cells[row, col] = cell;

                blocks[row / game.board.block_rows, col / game.board.block_cols].attach (cell, col % game.board.block_cols, row % game.board.block_rows);
            }
        }

        overlay.add_overlay (drawing);
        overlay.add (grid);
    }

    private inline void draw_board (DrawingArea _drawing, Cairo.Context c, int new_width, int new_height)
    {
        if (game.paused)
        {
            int board_length = grid.get_allocated_width ();

            c.set_source_rgba (0, 0, 0, 0.75);
            c.paint ();

            c.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            c.set_font_size (get_allocated_width () * 0.125);

            /* Text on overlay when game is paused */
            var text = _("Paused");
            Cairo.TextExtents extents;
            c.text_extents (text, out extents);
            c.move_to (board_length/2.0 - extents.width/2.0, board_length/2.0 + extents.height/2.0);
            c.set_source_rgb (1, 1, 1);
            c.show_text (text);
        }
    }

    public void clear ()
    {
        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                cells[i,j].clear ();
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

    private bool _highlighter = false;
    public bool highlighter
    {
        get { return _highlighter; }
        set {
            _highlighter = value;
        }
    }

    public void hide_popovers ()
    {
        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                cells[i,j].hide_both_popovers ();
    }
}
