/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gtk;
using Gdk;

private class SudokuCellView : Gtk.DrawingArea
{
    private Pango.Layout layout;

    private double size_ratio = 2;

    private Gtk.Popover popover;

    private SudokuGame game;

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

    public string top_notes { set; get; default = ""; }
    public string bottom_notes { set; get; default = ""; }

    private bool _show_possibilities;
    public bool show_possibilities
    {
        get { return _show_possibilities; }
        set {
            _show_possibilities = value;
            queue_draw ();
        }
    }

    private bool _warn_about_unfillable_squares = false;
    public bool warn_about_unfillable_squares
    {
        get { return _warn_about_unfillable_squares; }
        set {
            _warn_about_unfillable_squares = value;
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

    public SudokuCellView (int row, int col, ref SudokuGame game, bool small = false)
    {
        this.game = game;
        this._row = row;
        this._col = col;

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

        // background_color is set in the SudokuView, as it manages the color of the cells

        can_focus = true;

        style.font_desc.set_size (Pango.SCALE * 13);
        this.value = game.board [_row, _col];

        if (small)
        {
            size_ratio = 1;
        }

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
        if (event.button != 1)
            return false;

        if (!is_focus)
        {
            grab_focus ();
            return false;
        }

        if (event.y / get_allocated_height () < 0.25)
        {
            show_note_editor (0);
        }
        else
        {
            if (event.y / get_allocated_height () > 0.75)
            {
                if (!_show_possibilities)
                {
                    show_note_editor (1);
                }
            }
            else
            {
                show_number_picker ();
            }
        }

        return false;
    }

    private void show_number_picker ()
    {
        if (!is_fixed)
        {
            number_picker.set_clear_button_visibility (value != 0);
            popover.show ();
        }
    }

    private void show_note_editor (int top)
    {
        if (is_fixed)
            return;

/*  TODO - reimplement as earmarks

        var entry = new Gtk.Entry ();
        entry.has_frame = false;
        if (top == 0)
            entry.set_text (top_notes);
        else
            entry.set_text (bottom_notes);
        popover.add (entry);

        entry.focus_out_event.connect (() => {
            hide_note_editor (entry, top);
            return true;
        });

        entry.activate.connect (() => { hide_note_editor (entry, top); });
*/
    }

    private void hide_note_editor (Gtk.Entry entry, int top)
    {
        if (top == 0)
            top_notes = entry.get_text ();
        else
            bottom_notes = entry.get_text ();
        // TODO - need to hide a thing
    }

    private bool focus_out_cb (Gtk.Widget widget, Gdk.EventFocus event)
    {
        popover.hide ();
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

        return false;
    }

    public override bool draw (Cairo.Context c)
    {
        StyleContext styleContext = get_style_context ();

        // Draw the background
        if (_selected)
        {
            RGBA color = styleContext.get_background_color (StateFlags.SELECTED);
            c.set_source_rgb (color.red, color.green, color.blue);
        }
        else
        {
            c.set_source_rgb (_background_color.red, _background_color.green, _background_color.blue);
        }

        c.rectangle (0, 0, get_allocated_width (), get_allocated_height ());
        c.fill ();

        int glyph_width, glyph_height;
        layout.get_pixel_size (out glyph_width, out glyph_height);
        if (game.board.broken_coords.contains(Coord(row, col)))
        {
            c.set_source_rgb (1.0, 0.0, 0.0);
        }
        else if (_selected)
        {
            RGBA color = styleContext.get_color (StateFlags.SELECTED);
            c.set_source_rgb (color.red, color.green, color.blue);
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
        else if (_show_possibilities)
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

        // Draw the notes
        double note_size = get_allocated_height () / (size_ratio * 2);
        c.set_font_size (note_size);

        c.move_to (0, note_size);

        c.set_source_rgb (0.0, 0.0, 0.0);
        c.show_text (top_notes);

        c.move_to (0, (get_allocated_height () - 3));
        if (_warn_about_unfillable_squares)
        {
            c.set_source_rgb (1.0, 0.0, 0.0);
            c.show_text ("None");
        }
        else
        {
            c.set_source_rgb (0.0, 0.0, 0.0);
            //if (_show_possibilities)
            //{
            //    c.show_text (get_possibility_string (game.board.get_possibilities(_row, _col)));
            //}
            //else
            //{
                c.show_text (bottom_notes);
            //}
        }

        return false;
    }

    private static string get_possibility_string (int[] possibilities) {
        var builder = new StringBuilder ();
        foreach (int a in possibilities) {
            builder.append (@"$a ");
        }
        builder.truncate ((possibilities.length * 2) - 1);
        return builder.str;
    }

    public void cell_changed_cb (int row, int col, int old_val, int new_val)
    {
        if (row == this.row && col == this.col)
        {
            this.value = new_val;
            if (new_val == 0)
            {
                notify_property("value");
            }
        }
    }
}

public class SudokuView : Gtk.AspectFrame
{
    private SudokuGame game;
    private SudokuCellView[,] cells;

    public signal void cell_focus_in_event (int row, int col);
    public signal void cell_focus_out_event (int row, int col);
    public signal void cell_value_changed_event (int row, int col);

    private bool previous_board_broken_state = false;

    private Gtk.EventBox box;
    private Gtk.Grid grid;

    private int dance_step;

    private const RGBA[] dance_colors = { {0.8,                0.0,                0.0,                0.0},
                                        {0.9372549019607843, 0.1607843137254902, 0.1607843137254902, 0.0},
                                        {0.9607843137254902, 0.4745098039215686, 0.0,                0.0},
                                        {0.9882352941176471, 0.6862745098039216, 0.2431372549019607, 0.0},
                                        {0.9882352941176471, 0.9137254901960784, 0.3098039215686274, 0.0},
                                        {0.5411764705882353, 0.8862745098039215, 0.2039215686274509, 0.0},
                                        {0.4509803921568627, 0.8235294117647058, 0.0862745098039215, 0.0},
                                        {0.4470588235294118, 0.6235294117647059, 0.8117647058823529, 0.0},
                                        {0.2039215686274509, 0.3960784313725497, 0.6431372549019608, 0.0},
                                        {0.6784313725490196, 0.4980392156862745, 0.6588235294117647, 0.0},
                                        {0.4588235294117647, 0.3137254901960784, 0.4823529411764706, 0.0}
                                      };

    public const RGBA fixed_cell_color = {0.8, 0.8, 0.8, 0};
    public const RGBA free_cell_color = {1.0, 1.0, 1.0, 1.0};

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
        box.modify_bg (Gtk.StateType.NORMAL, box.style.black);
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
        grid.border_width = 3;
        grid.column_homogeneous = false;
        grid.row_homogeneous = false;

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
                        return false;
                    });

                    cell.notify["value"].connect((s, p)=> {
                        /* The board needs redrawing if it was/is broken, or if the possibilities are being displayed */
                        if (_show_possibilities || _show_warnings || game.board.broken || previous_board_broken_state) {
                            for (var i = 0; i < game.board.rows; i++)
                            {
                                for (var j = 0; j < game.board.cols; j++)
                                {
                                    if (_show_warnings && cells[i,j].value == 0 && game.board.count_possibilities (cells[i,j].row, cells[i,j].col) == 0) {
                                        if (!cells[i,j].warn_about_unfillable_squares) {
                                            cells[i,j].warn_about_unfillable_squares = true;
                                        }
                                    }
                                    else
                                    {
                                        cells[i,j].warn_about_unfillable_squares = false;
                                    }
                                }
                            }
                            previous_board_broken_state = game.board.broken;
                        }
                        cell_value_changed_event(cell_row, cell_col);
                        queue_draw ();
                    });
                }

                cells[row, col] = cell;
                cell.show ();

                if (col != 0 && (col % game.board.block_cols) == 0)
                {
                    cell.set_margin_left ((int) grid.border_width);
                }
                if (row != 0 && (row % game.board.block_rows) == 0)
                {
                    cell.set_margin_top ((int) grid.border_width);
                }
                grid.attach (cell, col, row, 1, 1);

            }
        }
        box.add (grid);
        grid.show ();
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
            {
                for (var j = 0; j < game.board.cols; j++)
                {
                    if (_show_warnings && cells[i,j].value == 0 && game.board.count_possibilities (cells[i,j].row, cells[i,j].col) == 0)
                    {
                        cells[i,j].warn_about_unfillable_squares = true;
                    }
                    else
                    {
                        cells[i,j].warn_about_unfillable_squares = false;
                    }
                }
            }
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

    public bool dance () {
        if (dance_step < 90)
        {
            for (var j = 0; j < game.board.cols; j++)
            {
                RGBA color = dance_colors[dance_step % dance_colors.length];
                dance_step++;
                for (var i = 0; i < game.board.rows; i++)
                    cells[i,j].background_color = color;
            }
        }
        else
        {
            for (var i = 0; i < game.board.rows; i++)
            {
                RGBA color = dance_colors[dance_step % dance_colors.length];
                dance_step++;
                for (var j = 0; j < game.board.cols; j++)
                    cells[i,j].background_color = color;
            }
        }

        if (dance_step > 180)
            dance_step = 0;

        if (dance_step >= 0)
            Timeout.add (200, dance);
        queue_draw ();

        return false;
    }

    public void stop_dance ()
    {
        dance_step = -1;
        reset_cell_background_colors ();
    }

    private RGBA get_next_color (RGBA color)
    {
        return dance_colors[Random.int_range(0, dance_colors.length)];
    }

    public void clear_top_notes ()
    {
        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                cells[i,j].top_notes = "";
        queue_draw ();
    }

    public void clear_bottom_notes ()
    {
        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                cells[i,j].bottom_notes = "";
        queue_draw ();
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
