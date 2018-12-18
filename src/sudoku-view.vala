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

private class SudokuCellView : Gtk.DrawingArea
{
    private Pango.Layout layout;

    private double size_ratio = 2;

    private Gtk.Popover popover;
    private Gtk.Popover earmark_popover;

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
                string text = "%d".printf (game.board [row, col]);
                layout = create_pango_layout (text);
                layout.set_font_description (style.font_desc);
                if (game.mode == GameMode.PLAY)
                    return;
            }
            if (value == 0)
            {
                string text = "";
                layout = create_pango_layout (text);
                layout.set_font_description (style.font_desc);
                if (game.board [row, col] != 0)
                    game.remove (row, col);
                if (game.mode == GameMode.PLAY)
                    return;
            }
            if (value == game.board [row, col])
            {
                string text = "%d".printf (value);
                layout = create_pango_layout (text);
                layout.set_font_description (style.font_desc);
                return;
            }
            assert (layout != null);
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
    public RGBA background_color { get; set; }

    private NumberPicker number_picker;
    private NumberPicker earmark_picker;

    public SudokuCellView (int row, int col, ref SudokuGame game)
    {
        this.game = game;
        this.row = row;
        this.col = col;

        style.font_desc.set_size (Pango.SCALE * 13);
        value = game.board [row, col];

        // background_color is set in the SudokuView, as it manages the color of the cells

        can_focus = true;
        events = EventMask.EXPOSURE_MASK | EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK | EventMask.KEY_PRESS_MASK;

        if (is_fixed && game.mode == GameMode.PLAY)
            return;

        focus_out_event.connect (focus_out_cb);
        game.cell_changed.connect (cell_changed_cb);
    }

    public override bool button_press_event (Gdk.EventButton event)
    {
        if (event.button != 1 && event.button != 3)
            return false;

        if (!is_focus)
            grab_focus ();
        if (game.mode == GameMode.PLAY && (is_fixed || game.paused))
            return false;

        if (popover != null || earmark_popover != null)
        {
            hide_both_popovers ();
            return false;
        }

        if (event.button == 1)            // Left-Click
        {
            if (!_show_possibilities && (event.state & ModifierType.CONTROL_MASK) > 0 && game.mode == GameMode.PLAY)
                show_earmark_picker ();
            else
                show_number_picker ();
        }
        else if (!_show_possibilities && event.button == 3 && game.mode == GameMode.PLAY)         // Right-Click
            show_earmark_picker ();

        return false;
    }

    private void create_earmark_picker ()
    {
        earmark_picker = new NumberPicker (ref game.board, true);
        earmark_picker.earmark_state_changed.connect ((number, state) => {
            if (state)
                this.game.board.enable_earmark (row, col, number);
            else
                this.game.board.disable_earmark (row, col, number);
            this.game.cell_changed (row, col, value, value);
            queue_draw ();
        });
        earmark_picker.set_earmarks (row, col);
    }

    private void show_number_picker ()
    {
        if (earmark_popover != null)
            earmark_popover.hide ();

        number_picker = new NumberPicker (ref game.board);
        number_picker.number_picked.connect ((o, number) => {
            value = number;
            if (number == 0)
                notify_property ("value");
            this.game.board.disable_all_earmarks (row, col);

            popover.hide ();
        });
        number_picker.set_clear_button_visibility (value != 0);

        popover = new Popover (this);
        popover.add (number_picker);
        popover.modal = false;
        popover.position = PositionType.BOTTOM;
        popover.notify["visible"].connect (()=> {
            if (!popover.visible)
                destroy_popover (ref popover);
        });
        popover.focus_out_event.connect (() => {
            popover.hide ();
            return true;
        });

        popover.show ();
    }

    private void show_earmark_picker ()
    {
        if (popover != null)
            popover.hide ();

        create_earmark_picker ();

        earmark_popover = new Popover (this);
        earmark_popover.add (earmark_picker);
        earmark_popover.modal = false;
        earmark_popover.position = PositionType.BOTTOM;
        earmark_popover.notify["visible"].connect (()=> {
            if (!earmark_popover.visible)
                destroy_popover (ref earmark_popover);
        });
        earmark_popover.focus_out_event.connect (() => {
            earmark_popover.hide ();
            return true;
        });

        earmark_popover.show ();
    }

    private void destroy_popover (ref Gtk.Popover popover)
    {
        if (popover != null)
        {
            popover.destroy ();
            popover = null;
        }
    }

    private void hide_both_popovers ()
    {
        if (popover != null)
            popover.hide ();
        if (earmark_popover != null)
            earmark_popover.hide ();
    }

    private bool focus_out_cb (Gtk.Widget widget, Gdk.EventFocus event)
    {
        hide_both_popovers ();
        return false;
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

    public override bool key_press_event (Gdk.EventKey event)
    {
        if (game.mode == GameMode.PLAY && (is_fixed || game.paused))
            return false;
        string k_name = Gdk.keyval_name (event.keyval);
        int k_no = int.parse (k_name);
        /* If k_no is 0, there might be some error in parsing, crosscheck with keypad values. */
        if (k_no == 0)
            k_no = key_map_keypad (k_name);
        if (k_no >= 1 && k_no <= 9)
        {
            if ((event.state & ModifierType.CONTROL_MASK) > 0 && game.mode == GameMode.PLAY)
            {
                var new_state = !game.board.is_earmark_enabled (row, col, k_no);
                if (earmark_picker == null)
                    create_earmark_picker ();
                if (earmark_picker.set_earmark (row, col, k_no-1, new_state))
                {
                    if (new_state)
                        game.board.enable_earmark (row, col, k_no);
                    else
                        game.board.disable_earmark (row, col, k_no);
                    queue_draw ();
                }
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
                popover.hide ();
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

    public override bool draw (Cairo.Context c)
    {
        int glyph_width, glyph_height;
        layout.get_pixel_size (out glyph_width, out glyph_height);
        if (_show_warnings && game.board.broken_coords.contains (Coord (row, col)))
            c.set_source_rgb (1.0, 0.0, 0.0);
        else if (_selected)
            c.set_source_rgb (0.2, 0.2, 0.2);
        else
            c.set_source_rgb (0.0, 0.0, 0.0);

        if (game.paused)
            return false;

        if (value != 0)
        {
            int width, height;
            layout.get_size (out width, out height);
            height /= Pango.SCALE;

            double scale = ((double) get_allocated_height () / size_ratio) / height;
            c.move_to ((get_allocated_width () - glyph_width * scale) / 2, (get_allocated_height () - glyph_height * scale) / 2);
            c.save ();
            c.scale (scale, scale);
            Pango.cairo_show_layout (c, layout);
            c.restore ();
        }

        if (is_fixed && game.mode == GameMode.PLAY)
            return false;

        if (!_show_possibilities)
        {
            // Draw the earmarks
            double earmark_size = get_allocated_height () / (size_ratio * 2);
            c.set_font_size (earmark_size);

            c.move_to (0, earmark_size);

            c.set_source_rgb (0.0, 0.0, 0.0);
            c.show_text (game.board.get_earmarks_string (row, col));
        }
        else if (value == 0)
        {
            double possibility_size = get_allocated_height () / (size_ratio * 2);
            c.set_font_size (possibility_size);
            c.set_source_rgb (0.0, 0.0, 0.0);

            bool[] possibilities = game.board.get_possibilities_as_bool_array (row, col);

            int height = get_allocated_height () / game.board.block_cols;
            int width = get_allocated_height () / game.board.block_rows;

            int num = 0;
            for (int row_tmp = 0; row_tmp < game.board.block_rows; row_tmp++)
            {
                for (int col_tmp = 0; col_tmp < game.board.block_cols; col_tmp++)
                {
                    num++;

                    if (possibilities[num - 1])
                    {
                        c.move_to (col_tmp * width, (row_tmp * height) + possibility_size);
                        c.show_text ("%d".printf (num));
                    }
                }
            }
        }

        if (_show_warnings && (value == 0 && game.board.count_possibilities (row, col) == 0))
        {
            string warning = "X";
            Cairo.TextExtents extents;
            c.set_font_size (get_allocated_height () / 2);
            c.text_extents (warning, out extents);
            c.move_to ((get_allocated_width () - extents.width) / 2 - 1, (get_allocated_height () + extents.height) / 2 + 1);
            c.set_source_rgb (1.0, 0.0, 0.0);
            c.show_text (warning);
        }

        return false;
    }

    public void cell_changed_cb (int row, int col, int old_val, int new_val)
    {
        if (row == this.row && col == this.col)
        {
            this.value = new_val;

            if (game.mode == GameMode.CREATE)
            {
                if (_selected)
                    background_color = selected_bg_color;
                else
                    background_color = is_fixed ? fixed_cell_color : free_cell_color;
            }

            notify_property ("value");
        }
    }

    public void clear ()
    {
        game.board.disable_all_earmarks (row, col);
    }
}

public const RGBA fixed_cell_color = {0.8, 0.8, 0.8, 0};
public const RGBA free_cell_color = {1.0, 1.0, 1.0, 1.0};
public const RGBA highlight_color = {0.93, 0.93, 0.93, 0};
public const RGBA selected_bg_color = {0.7, 0.8, 0.9};
public const RGBA same_value_bg_color = {0.6, 0.8, 1.0};

public class SudokuView : Gtk.AspectFrame
{
    public SudokuGame game;
    private SudokuCellView[,] cells;

    private bool previous_board_broken_state = false;

    private Gtk.Overlay overlay;
    private Gtk.DrawingArea drawing;
    private Gtk.Grid grid;

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
        shadow_type = Gtk.ShadowType.NONE;
        obey_child = false;
        ratio = 1;

        overlay = new Gtk.Overlay ();
        add (overlay);

        drawing = new Gtk.DrawingArea ();
        drawing.draw.connect (draw_board);

        if (grid != null)
            overlay.remove (grid);

        this.game = game;

        grid = new Gtk.Grid ();
        grid.row_spacing = 1;
        grid.column_spacing = 1;
        grid.column_homogeneous = true;
        grid.row_homogeneous = true;

        cells = new SudokuCellView[game.board.rows, game.board.cols];
        for (var row = 0; row < game.board.rows; row++)
        {
            for (var col = 0; col < game.board.cols; col++)
            {
                var cell = new SudokuCellView (row, col, ref this.game);
                var cell_row = row;
                var cell_col = col;

                cell.background_color = cell.is_fixed ? fixed_cell_color : free_cell_color;

                cell.focus_in_event.connect (() => {
                    if (game.paused)
                        return false;

                    this.set_selected (cell_row, cell_col);

                    for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
                    {
                        var color = (col_tmp == cell_col && _highlighter) ? highlight_color : free_cell_color;
                        for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
                            cells[row_tmp,col_tmp].background_color = cells[row_tmp,col_tmp].is_fixed ? fixed_cell_color : color;
                    }
                    for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
                    {
                        if (cells[cell_row, col_tmp].is_fixed)
                            cells[cell_row, col_tmp].background_color = fixed_cell_color;
                        else if (_highlighter)
                            cells[cell_row, col_tmp].background_color = highlight_color;
                        else
                            cells[cell_row, col_tmp].background_color = free_cell_color;
                    }

                    foreach (Coord? coord in game.board.coords_for_block.get (Coord (cell_row / game.board.block_rows, cell_col / game.board.block_cols)))
                    {
                        if (cells[coord.row, coord.col].is_fixed)
                            cells[coord.row, coord.col].background_color = fixed_cell_color;
                        else if (_highlighter)
                            cells[coord.row, coord.col].background_color = highlight_color;
                        else
                            cells[coord.row, coord.col].background_color = free_cell_color;
                    }

                    for (var col_tmp = 0; col_tmp < game.board.cols; col_tmp++)
                    {
                        for (var row_tmp = 0; row_tmp < game.board.rows; row_tmp++)
                        {
                            if (cells[cell_row, cell_col].value != 0 && cells[cell_row, cell_col].value == cells[row_tmp, col_tmp].value)
                                cells[row_tmp, col_tmp].background_color = same_value_bg_color;
                        }
                    }

                    cells[cell_row, cell_col].background_color = selected_bg_color;

                    queue_draw ();

                    return false;
                });

                cell.notify["value"].connect ((s, p)=> {
                    if (_show_possibilities || _show_warnings || game.board.broken || previous_board_broken_state)
                        previous_board_broken_state = game.board.broken;

                    // Redraw the board
                    this.queue_draw ();
                });

                cells[row, col] = cell;
                grid.attach (cell, col, row, 1, 1);
            }
        }

        overlay.add (drawing);
        overlay.add_overlay (grid);
        drawing.show ();
        grid.show_all ();
        overlay.show ();
    }

    private bool draw_board (Cairo.Context c)
    {
        int board_length = grid.get_allocated_width ();
        /* not exactly the tile's edge length: includes the width of a border line (1) */
        double tile_length = ((double) (board_length - 1)) / game.board.cols;

        if (Gtk.Widget.get_default_direction () == Gtk.TextDirection.RTL)
        {
            c.translate (board_length, 0);
            c.scale (-1, 1);
        }

        /* TODO game.board.cols == game.board.rows... */
        for (var i = 0; i < game.board.cols; i++)
        {
            for (var j = 0; j < game.board.cols; j++)
            {
                var background_color = cells[i, j].background_color;
                c.set_source_rgb (background_color.red, background_color.green, background_color.blue);

                c.rectangle ((int) (j * tile_length) + 0.5, (int) (i * tile_length) + 0.5, (int) ((j + 1) * tile_length) + 0.5, (int) ((i + 1) * tile_length) + 0.5);
                c.fill ();
            }
        }

        c.set_line_width (1);
        c.set_source_rgb (0.6, 0.6, 0.6);
        for (var i = 1; i < game.board.cols; i++)
        {
            if (i % game.board.block_cols == 0)
                continue;
            /* we could use board_length - 1 */
            c.move_to (((int) (i * tile_length)) + 0.5, 1);
            c.line_to (((int) (i * tile_length)) + 0.5, board_length);
        }
        for (var i = 1; i < game.board.cols; i++)
        {
            if (i % game.board.block_rows == 0)
                continue;

            c.move_to (1, ((int) (i * tile_length)) + 0.5);
            c.line_to (board_length, ((int) (i * tile_length)) + 0.5);
        }
        c.stroke ();

        c.set_line_width (2);
        c.set_source_rgb (0.0, 0.0, 0.0);
        for (var i = 0; i <= game.board.cols; i += game.board.block_cols)
        {
            c.move_to (((int) (i * tile_length)) + 0.5, 0);
            c.line_to (((int) (i * tile_length)) + 0.5, board_length);
        }
        for (var i = 0; i <= game.board.cols; i += game.board.block_rows)
        {
            c.move_to (0, ((int) (i * tile_length)) + 0.5);
            c.line_to (board_length, ((int) (i * tile_length)) + 0.5);
        }
        c.stroke ();

        if (game.paused)
        {
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

        return false;
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
}
