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

    private bool initialized_earmarks;

    // Whether the control keys are pressed.
    private bool left_control;
    private bool right_control;

    public Gtk.GestureLongPress long_press;

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

    private bool _initialize_earmarks;
    public bool initialize_earmarks
    {
        get { return _initialize_earmarks; }
        set
        {
            _initialize_earmarks = value;
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
    public bool highlighted_background { get; set; }
    public bool highlighted_value { get; set; }

    private NumberPicker number_picker;
    private NumberPicker earmark_picker;

    private EventControllerKey key_controller;      // for keeping in memory

    public SudokuCellView (int row, int col, ref SudokuGame game)
    {
        this.game = game;
        this.row = row;
        this.col = col;

        init_keyboard ();

        value = game.board [row, col];

        // background_color is set in the SudokuView, as it manages the color of the cells

        can_focus = true;
        events = EventMask.EXPOSURE_MASK | EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK | EventMask.KEY_PRESS_MASK;

        if (is_fixed && game.mode == GameMode.PLAY)
            return;

        focus_out_event.connect (focus_out_cb);
        game.cell_changed.connect (cell_changed_cb);
    }

    public override bool button_press_event (EventButton event)
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

    public void long_press_event ()
    {
        if (game.mode == GameMode.PLAY && (is_fixed || game.paused))
            return;

        show_earmark_picker ();
    }

    private void create_earmark_picker ()
    {
        earmark_picker = new NumberPicker (ref game.board, true);
        earmark_picker.earmark_state_changed.connect ((number, state) => {
            // For enable and disable the "board" is written to directly to
            // avoid affecting the undo stack.
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
                destroy_popover (ref popover, ref number_picker);
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
                destroy_popover (ref earmark_popover, ref earmark_picker);
        });
        earmark_popover.focus_out_event.connect (() => {
            earmark_popover.hide ();
            return true;
        });

        earmark_popover.show ();
    }

    private void destroy_popover (ref Popover popover, ref NumberPicker picker)
    {
        picker = null;
        if (popover != null)
        {
            popover.destroy ();
            popover = null;

            // Destroying a popover means that this type of warning is now possible.
            if (warn_incorrect_solution())
                queue_draw ();
        }
    }

    public void hide_both_popovers ()
    {
        if (popover != null)
            popover.hide ();
        if (earmark_popover != null)
            earmark_popover.hide ();
    }

    private bool focus_out_cb (Widget widget, EventFocus event)
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

    private inline void init_keyboard ()  // called on construct
    {
        key_controller = new EventControllerKey (this);
        key_controller.key_pressed.connect (on_key_pressed);
        key_controller.key_released.connect (on_key_release);
    }

    private inline bool on_key_pressed (EventControllerKey _key_controller, uint keyval, uint keycode, ModifierType state)
    {
        if (keyval == Gdk.Key.Control_L)
            left_control = true;
        if (keyval == Gdk.Key.Control_R)
            right_control = true;

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

    private inline void on_key_release (EventControllerKey _key_controller, uint keyval, uint keycode, ModifierType state)
    {
        bool control_released = false;
        if (keyval == Gdk.Key.Control_L)
        {
            left_control = false;
            control_released = true;
        }
        if (keyval == Gdk.Key.Control_R)
        {
            right_control = false;
            control_released = true;
        }

        // Releasing a control means that this type of warning is now possible.
        if (control_released && warn_incorrect_solution())
            queue_draw ();
    }

    public override bool draw (Cairo.Context c)
    {
        RGBA background_color;
        if (_selected && is_focus)
            background_color = selected_bg_color;
        else if (is_fixed)
            background_color = fixed_cell_color;
        else if (_highlighted_background)
            background_color = highlight_color;
        else
            background_color = free_cell_color;

        // Highlight the cell if the value or earmarks are inconsistent with
        // a known solution, if any.
        if (warn_incorrect_solution())
        {
            bool cell_error = false;
            int solution = game.board.get_solution (row, col);
            if (value != 0)
            {
                // Check value against the solution.
                cell_error = value != solution;
            }
            else
            {
                // Check earmarks against the solution.
                var marks = game.board.get_earmarks (row, col);
                bool earmarked = false;
                bool solution_found = false;
                for (int num = 1; num <= marks.length; num++)
                {
                    if (marks[num - 1])
                    {
                        earmarked = true;
                        if (num == solution)
                            solution_found = true;
                    }
                }
                if (earmarked && !solution_found)
                    cell_error = true;
            }

            // Make the error cell more red by reducing the other colors to 60%.
            if (cell_error)
            {
                background_color.green *= 0.6;
                background_color.blue  *= 0.6;
            }
        }

        c.set_source_rgba (background_color.red, background_color.green, background_color.blue, background_color.alpha);
        c.rectangle (0, 0, get_allocated_width (), get_allocated_height ());
        c.fill();

        if (_show_warnings && game.board.broken_coords.contains (Coord (row, col)))
            c.set_source_rgb (1.0, 0.0, 0.0);
        else if (_highlighted_value)
            c.set_source_rgb (0.2, 0.4, 0.9);
        else if (_selected)
            c.set_source_rgb (0.2, 0.2, 0.2);
        else
            c.set_source_rgb (0.0, 0.0, 0.0);

        if (game.paused)
            return false;

        if (value != 0)
        {
            double height = (double) get_allocated_height ();
            double width = (double) get_allocated_width ();
            string text = "%d".printf (value);

            c.set_font_size (height / size_ratio);
            print_centered (c, text, width, height);
            return false;
        }

        if (is_fixed && game.mode == GameMode.PLAY)
            return false;

        bool[] marks = null;
        if (!_show_possibilities)
        {
            // Onetime earmark initialization.
            if (!initialized_earmarks)
            {
                // For gsetting "initialize-earmarks" only initialize the earmarks
                // if playing a new game.
                if (_initialize_earmarks && (game.mode == GameMode.PLAY) &&
                    (game.board.previous_played_time == 0.0))
                {
                    marks = game.board.get_possibilities_as_bool_array (row, col);
                    for (int num = 1; num <= marks.length; num++)
                    {
                        if (marks[num - 1])
                        {
                            game.board.enable_earmark (row, col, num);
                        }
                    }
                }
                initialized_earmarks = true;
            }

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
                        if (_show_warnings && !game.board.is_possible (row, col, num))
                            c.set_source_rgb (1.0, 0.0, 0.0);
                        else
                            c.set_source_rgb (0.0, 0.0, 0.0);

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

        return false;
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

    // Return true if the user is to be warned when the value or earmarks are
    // inconsistent with the known solution, and it is ok for the user to be
    // warned.
    private bool warn_incorrect_solution()
    {
        // In the following popovers are checked so that the solution of the cell
        // is not revealed to the user as the user enters candidate numbers for
        // the cell using the earmark picker. Similarly don't reveal the solution
        // while earmarks are being entered with the control key.
        return _show_warnings &&                                  // show warnings?
               (popover == null) && (earmark_popover == null) && // popovers gone?
               (!left_control) && (!right_control) &&             // control keys not pressed?
               game.board.solved();                               // solution exists?
    }
}

public const RGBA fixed_cell_color = {0.8, 0.8, 0.8, 1.0};
public const RGBA free_cell_color = {1.0, 1.0, 1.0, 1.0};
public const RGBA highlight_color = {0.93, 0.93, 0.93, 1.0};
public const RGBA selected_bg_color = {0.7, 0.8, 0.9, 1.0};

public class SudokuView : AspectFrame
{
    public SudokuGame game;
    private SudokuCellView[,] cells;

    private bool previous_board_broken_state = false;

    private Overlay overlay;
    private DrawingArea drawing;
    private Grid grid;

    private int selected_row = -1;
    private int selected_col = -1;
    private void set_selected (int cell_row, int cell_col)
    {
        if (selected_row >= 0 && selected_col >= 0)
        {
            cells[selected_row, selected_col].selected = false;
            cells[selected_row, selected_col].queue_draw ();
        }
        selected_row = cell_row;
        selected_col = cell_col;
        if (selected_row >= 0 && selected_col >= 0)
        {
            cells[selected_row, selected_col].selected = true;
        }
    }

    public SudokuView (SudokuGame game)
    {
        shadow_type = ShadowType.NONE;
        obey_child = false;
        ratio = 1;

        overlay = new Overlay ();
        add (overlay);

        drawing = new DrawingArea ();
        drawing.draw.connect (draw_board);

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
        css_provider.load_from_resource ("/org/gnome/Sudoku/ui/gnome-sudoku.css");

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

                cell.focus_in_event.connect (() => {
                    if (game.paused)
                        return false;

                    this.set_selected (cell_row, cell_col);
                    this.update_highlights ();
                    queue_draw ();

                    return false;
                });

                cell.focus_out_event.connect (() => {
                    if (game.paused)
                        return false;

                    this.set_selected (-1, -1);
                    this.update_highlights ();
                    queue_draw ();

                    return false;
                });

                cell.long_press = new Gtk.GestureLongPress (cell);
                cell.long_press.set_propagation_phase (Gtk.PropagationPhase.TARGET);
                cell.long_press.pressed.connect (() => {
                    cell.long_press_event ();
                });

                cell.notify["value"].connect ((s, p)=> {
                    if (_show_possibilities || _show_warnings || game.board.broken || previous_board_broken_state)
                        previous_board_broken_state = game.board.broken;

                    this.update_highlights ();
                    // Redraw the board
                    this.queue_draw ();
                });

                cells[row, col] = cell;

                blocks[row / game.board.block_rows, col / game.board.block_cols].attach (cell, col % game.board.block_cols, row % game.board.block_rows);
            }
        }

        overlay.add_overlay (drawing);
        overlay.add (grid);
        grid.show_all ();
        overlay.show ();
        drawing.hide ();
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
                cells[row_tmp, col_tmp].highlighted_background = has_selection && _highlighter && (
                    col_tmp == selected_col ||
                    row_tmp == selected_row ||
                    (col_tmp / game.board.block_cols == selected_col / game.board.block_cols &&
                     row_tmp / game.board.block_rows == selected_row / game.board.block_rows)
                );
                cells[row_tmp, col_tmp].highlighted_value = has_selection &&
                    _highlighter &&
                    cell_value == cells[row_tmp, col_tmp].value;
            }
        }
    }

    private bool draw_board (Cairo.Context c)
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

    public void hide_popovers ()
    {
        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                cells[i,j].hide_both_popovers ();
    }
}
