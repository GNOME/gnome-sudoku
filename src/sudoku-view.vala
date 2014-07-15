/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gtk;
using Gdk;

private class SudokuCellView : Gtk.DrawingArea
{
    private Pango.Layout layout;

    private double size_ratio = 2;

    private Gtk.Popover popover;
    private Gtk.Popover earmark_popover;

    private SudokuGame game;

    private const RGBA selected_bg_color = {0.7, 0.8, 0.9};
    private const RGBA selected_stroke_color = SudokuView.selected_stroke_color;

    private int _row;
    public int row
    {
        get { return _row; }
        set { _row = value; }
    }

    private int _col;
    public int col
    {
        get { return _col; }
        set { _col = value; }
    }

    public int value
    {
        get
        {
            return game.board [_row, _col];
        }
        set
        {
            if (is_fixed)
            {
                string text = "%d".printf (game.board [_row, _col]);
                layout = create_pango_layout (text);
                layout.set_font_description (style.font_desc);
                return;
            }
            if (value == 0)
            {
                string text = "";
                layout = create_pango_layout (text);
                layout.set_font_description (style.font_desc);
                if (game.board [_row, _col] != 0)
                    game.remove (_row, _col);
                return;
            }
            if (value == game.board [_row, _col])
            {
                string text = "%d".printf (value);
                layout = create_pango_layout (text);
                layout.set_font_description (style.font_desc);
                return;
            }
            game.insert (_row, _col, value);
        }
    }

    public bool is_fixed
    {
        get
        {
            return game.board.is_fixed[_row, _col];
        }
    }

    private bool _show_possibilities;
    public bool show_possibilities
    {
        get { return _show_possibilities; }
        set {
            _show_possibilities = value;
            queue_draw ();
        }
    }

    private bool _show_warnings = true;
    public bool show_warnings
    {
        get { return _show_warnings; }
        set {
            _show_warnings = value;
            queue_draw ();
        }
    }

    private bool _selected;
    public bool selected
    {
        get { return _selected; }
        set { _selected = value; }
    }

    private bool _highlight;
    public bool highlight
    {
        get { return _highlight; }
        set { _highlight = value; }
    }

    private bool _invalid;
    public bool invalid
    {
        get { return _invalid; }
        set { _invalid = value; }
    }

    private RGBA _background_color;
    public RGBA background_color
    {
        get { return _background_color; }
        set
        {
            _background_color = value;
        }
    }

    private NumberPicker number_picker;
    private NumberPicker earmark_picker;

    public SudokuCellView (int row, int col, ref SudokuGame game, bool small = false)
    {
        this.game = game;
        this._row = row;
        this._col = col;

        style.font_desc.set_size (Pango.SCALE * 13);
        this.value = game.board [_row, _col];

        if (small)
        {
            size_ratio = 0.83;
            return;
        }

        number_picker = new NumberPicker(ref game.board);
        number_picker.number_picked.connect ((o, number) => {
            value = number;
            if (number == 0)
            {
                notify_property("value");
            }
            popover.hide ();
        });

        popover = new Popover (this);
        popover.add (number_picker);
        popover.modal = false;
        popover.position = PositionType.BOTTOM;
        popover.focus_out_event.connect (() => { popover.hide (); return true; });

        earmark_picker = new NumberPicker(ref game.board, true);
        earmark_picker.earmark_state_changed.connect ((number, state) => {
            this.game.board.earmarks[row, col, number-1] = state;
            queue_draw ();
        });
        earmark_picker.set_earmarks (row, col);

        earmark_popover = new Popover (this);
        earmark_popover.add (earmark_picker);
        earmark_popover.modal = false;
        earmark_popover.position = PositionType.BOTTOM;
        earmark_popover.focus_out_event.connect (() => { earmark_popover.hide (); return true; });

        // background_color is set in the SudokuView, as it manages the color of the cells

        can_focus = true;

        events = EventMask.EXPOSURE_MASK | EventMask.BUTTON_PRESS_MASK | EventMask.KEY_PRESS_MASK;
        focus_out_event.connect (focus_out_cb);
        game.cell_changed.connect (cell_changed_cb);
    }

    public override void get_preferred_width (out int minimal_width, out int natural_width)
    {
        int width, height, side;
        layout.get_size (out width, out height);
        side = width > height ? width : height;
        minimal_width = natural_width = (int) (size_ratio * side) / Pango.SCALE;
    }

    public override void get_preferred_height (out int minimal_height, out int natural_height)
    {
        int width, height, side;
        layout.get_size (out width, out height);
        side = width > height ? width : height;
        minimal_height = natural_height = (int) (size_ratio * side) / Pango.SCALE;
    }

    public override bool button_press_event (Gdk.EventButton event)
    {
        if (event.button != 1 && event.button != 3)
            return false;

        if (!is_focus)
            grab_focus ();

        if (popover.visible || earmark_popover.visible)
        {
            hide_both_popovers ();
            return false;
        }

        if (event.button == 1)            // Left-Click
        {
            if (!_show_possibilities && (event.state & ModifierType.CONTROL_MASK) > 0)
                show_earmark_picker ();
            else
                show_number_picker ();
        }
        else if (!_show_possibilities && event.button == 3)         // Right-Click
            show_earmark_picker ();

        return false;
    }

    private void show_number_picker ()
    {
        if (!is_fixed)
        {
            number_picker.set_clear_button_visibility (value != 0);
            earmark_popover.hide ();
            popover.show ();
        }
    }

    private void show_earmark_picker ()
    {
        if (!is_fixed)
        {
            popover.hide ();
            earmark_popover.show ();
        }
    }

    private void hide_both_popovers ()
    {
        popover.hide ();
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
        string k_name = Gdk.keyval_name (event.keyval);
        int k_no = int.parse (k_name);
        /* If k_no is 0, there might be some error in parsing, crosscheck with keypad values. */
        if (k_no == 0)
            k_no = key_map_keypad (k_name);
        if (k_no >= 1 && k_no <= 9)
        {
            if ((event.state & ModifierType.CONTROL_MASK) > 0 && !is_fixed)
            {
                var new_state = !game.board.earmarks[_row, _col, k_no-1];
                if (earmark_picker.set_earmark (_row, _col, k_no-1, new_state))
                {
                    game.board.earmarks[_row, _col, k_no-1] = new_state;
                    queue_draw ();
                }
            }
            else
                value = k_no;
            return true;
        }
        if (k_no == 0 || k_name == "BackSpace" || k_name == "Delete")
        {
            value = 0;
            notify_property("value");
            return true;
        }

        if (k_name == "space" || k_name == "Return" || k_name == "KP_Enter")
        {
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
        // Draw the background
        if (_selected)
            c.set_source_rgb (selected_bg_color.red, selected_bg_color.green, selected_bg_color.blue);
        else
            c.set_source_rgb (_background_color.red, _background_color.green, _background_color.blue);

        c.rectangle (0, 0, get_allocated_width (), get_allocated_height ());
        c.fill ();

        int glyph_width, glyph_height;
        layout.get_pixel_size (out glyph_width, out glyph_height);
        if (_show_warnings && game.board.broken_coords.contains(Coord(row, col)))
        {
            c.set_source_rgb (1.0, 0.0, 0.0);
        }
        else if (_selected)
        {
            c.set_source_rgb (0.2, 0.2, 0.2);
        }
        else
        {
            c.set_source_rgb (0.0, 0.0, 0.0);
        }

        if (value != 0)
        {
            int width, height;
            layout.get_size (out width, out height);
            height /= Pango.SCALE;

            double scale = ((double) get_allocated_height () / size_ratio) / height;
            c.move_to ((get_allocated_width () - glyph_width * scale) / 2, (get_allocated_height () - glyph_height * scale) / 2);
            c.save ();
            c.scale (scale, scale);
            Pango.cairo_update_layout (c, layout);
            Pango.cairo_show_layout (c, layout);
            c.restore ();
        }

        if (!_show_possibilities)
        {
            // Draw the earmarks
            double earmark_size = get_allocated_height () / (size_ratio * 2);
            c.set_font_size (earmark_size);

            c.move_to (0, earmark_size);

            c.set_source_rgb (0.0, 0.0, 0.0);
            c.show_text (game.board.get_earmarks_string (_row, _col));
        }
        else if (value == 0)
        {
            double possibility_size = get_allocated_height () / (size_ratio * 2);
            c.set_font_size (possibility_size);
            c.set_source_rgb (0.0, 0.0, 0.0);

            bool[] possibilities = game.board.get_possibilities_as_bool_array(row, col);

            int height = get_allocated_height () / game.board.block_cols;
            int width = get_allocated_height () / game.board.block_rows;

            int num = 0;
            for (int row = 0; row < game.board.block_rows; row++)
            {
                for (int col = 0; col < game.board.block_cols; col++)
                {
                    num++;

                    if (possibilities[num - 1])
                    {
                        c.move_to (col * width, (row * height) + possibility_size);
                        c.show_text ("%d".printf(num));
                    }
                }
            }
        }

        if (is_fixed)
            return false;

        if (_show_warnings && (value == 0 && game.board.count_possibilities (_row, _col) == 0))
        {
            string warning = "X";
            Cairo.TextExtents extents;
            c.set_font_size (get_allocated_height () / 2);
            c.text_extents (warning, out extents);
            c.move_to ((get_allocated_width () - extents.width) / 2 - 1, (get_allocated_height () + extents.height) / 2 + 1);
            c.set_source_rgb (1.0, 0.0, 0.0);
            c.show_text (warning);
        }
        else
        {
            c.set_source_rgb (0.0, 0.0, 0.0);
        }

        return false;
    }

    public void cell_changed_cb (int row, int col, int old_val, int new_val)
    {
        if (row == this.row && col == this.col)
        {
            this.value = new_val;
            notify_property("value");
        }
    }
}

public class SudokuView : Gtk.AspectFrame
{
    public SudokuGame game;
    private SudokuCellView[,] cells;

    public signal void cell_focus_in_event (int row, int col);
    public signal void cell_focus_out_event (int row, int col);
    public signal void cell_value_changed_event (int row, int col);

    private bool previous_board_broken_state = false;

    private Gtk.EventBox box;
    private Gtk.Grid grid;

    public const RGBA fixed_cell_color = {0.8, 0.8, 0.8, 0};
    public const RGBA free_cell_color = {1.0, 1.0, 1.0, 1.0};
    public const RGBA highlight_color = {0.93, 0.93, 0.93, 0};
    public const RGBA selected_stroke_color = {0.0, 0.2, 0.4};

    private int _selected_x = 0;
    public int selected_x
    {
        get { return _selected_x; }
        set {
            cells[selected_y, selected_x].selected = false;
            cells[selected_y, selected_x].queue_draw ();
             _selected_x = value;
            cells[selected_y, selected_x].selected = true;
        }
    }

    private int _selected_y = 0;
    public int selected_y
    {
        get { return _selected_y; }
        set {
            cells[selected_y, selected_x].selected = false;
            cells[selected_y, selected_x].queue_draw ();
             _selected_y = value;
            cells[selected_y, selected_x].selected = true;
        }
    }

    public SudokuView (SudokuGame game, bool preview = false)
    {
        shadow_type = Gtk.ShadowType.NONE;

        /* Use an EventBox to be able to set background */
        box = new Gtk.EventBox ();
        box.override_background_color (Gtk.StateFlags.NORMAL, {0.7, 0.7, 0.7, 1.0});
        add (box);
        box.show ();

        this.obey_child = false;

        set_game (game, preview);
    }

    public void set_game (SudokuGame game, bool preview = false)
    {
        if (grid != null)
        {
            box.remove (grid);
        }

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
                var cell = new SudokuCellView (row, col, ref this.game, preview);
                var cell_row = row;
                var cell_col = col;

                if (cell.is_fixed)
                {
                    cell.background_color = fixed_cell_color;
                }
                else
                {
                    cell.background_color = free_cell_color;
                }

                if (!preview)
                {
                    cell.focus_out_event.connect (() => {
                        cell_focus_out_event(cell_row, cell_col);
                        return false;
                    });

                    cell.focus_in_event.connect (() => {
                        this.selected_x = cell_col;
                        this.selected_y = cell_row;
                        cell_focus_in_event(cell_row, cell_col);

                        reset_cell_background_colors ();
                        set_row_background_color (cell_row, highlight_color);
                        set_col_background_color (cell_col, highlight_color);

                        var block_row = cell.row / game.board.block_rows;
                        var block_col = cell.col / game.board.block_cols;
                        set_block_background_color (block_row, block_col, highlight_color);

                        queue_draw ();

                        return false;
                    });

                    cell.notify["value"].connect((s, p)=> {
                        /* The board needs redrawing if it was/is broken, or if the possibilities are being displayed */
                        if (_show_possibilities || _show_warnings || game.board.broken || previous_board_broken_state) {
                            this.queue_draw ();
                            previous_board_broken_state = game.board.broken;
                        }
                        cell_value_changed_event(cell_row, cell_col);
                    });
                }

                cells[row, col] = cell;
                cell.show ();
                grid.attach (cell, col, row, 1, 1);

            }
        }
        box.add (grid);
        grid.show ();

        grid.draw.connect (draw_block_lines);
    }

    private bool draw_block_lines (Cairo.Context c)
    {
        var width = (double) grid.get_allocated_width ();
        var height = (double) grid.get_allocated_height ();
        c.set_line_width (1);
        c.set_source_rgb (0.2, 0.2, 0.2);

        c.move_to (width / 3, 0);
        c.line_to (width / 3, height);
        c.move_to (2 * width / 3, 0);
        c.line_to (2 * width / 3, height);

        c.move_to (0, height / 3);
        c.line_to (width, height / 3);
        c.move_to (0, 2 * height / 3);
        c.line_to (width, 2 * height / 3);
        c.stroke ();

        var cell_width = width / game.board.rows;
        var cell_height = height / game.board.cols;
        c.set_source_rgb (selected_stroke_color.red, selected_stroke_color.green, selected_stroke_color.blue);
        c.rectangle (selected_x * cell_width, selected_y * cell_height, cell_width, cell_height);
        c.stroke ();

        return false;
    }

    private bool _show_highlights = false;
    public bool show_highlights
    {
        get { return _show_highlights; }
        set { _show_highlights = value; }
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

    public void set_cell_value (int x, int y, int value) {
        cells[y, x].value = value;
        if (value == 0)
        {
            cells[y, x].notify_property("value");
        }
    }

    public void cell_grab_focus(int row, int col)
    {
        cells[row, col].grab_focus ();
    }

    public void set_cell_background_color (int row, int col, RGBA color) {
        cells[row, col].background_color = color;
    }

    public void set_row_background_color (int row, RGBA color, RGBA fixed_color = fixed_cell_color) {
        for (var col = 0; col < game.board.cols; col++) {
            if (cells[row, col].is_fixed) {
                cells[row, col].background_color = fixed_color;
            } else {
                cells[row, col].background_color = color;
            }
        }
    }

    public void set_col_background_color (int col, RGBA color, RGBA fixed_color = fixed_cell_color) {
        for (var row = 0; row < game.board.rows; row++) {
            if (cells[row, col].is_fixed) {
                cells[row, col].background_color = fixed_color;
            } else {
                cells[row, col].background_color = color;
            }
        }
    }

    public void set_block_background_color (int block_row, int block_col, RGBA color, RGBA fixed_color = fixed_cell_color) {
        foreach (Coord? coord in game.board.coords_for_block.get(Coord(block_row, block_col))) {
            if (cells[coord.row, coord.col].is_fixed) {
                cells[coord.row, coord.col].background_color = fixed_color;
            } else {
                cells[coord.row, coord.col].background_color = color;
            }
        }
    }

    public void reset_cell_background_colors () {
        for (var j = 0; j < game.board.cols; j++)
        {
            for (var i = 0; i < game.board.rows; i++)
            {
                if (cells[i,j].is_fixed)
                {
                    cells[i,j].background_color = fixed_cell_color;
                }
                else
                {
                    cells[i,j].background_color = free_cell_color;
                }
            }
        }
    }
}
