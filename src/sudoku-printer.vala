/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gtk;
using Gee;
using Gdk;

public class SudokuPrinter : GLib.Object {

    private SudokuBoard[] boards;
    private ApplicationWindow window;

    private int margin;
    private int n_sudokus;
    private int sudokus_per_page;

    private PrintOperation print_op;

    public PrintOperationResult print_sudoku ()
    {
        try
        {
            var result = print_op.run (Gtk.PrintOperationAction.PRINT_DIALOG, window);
            return result;
        }
        catch (GLib.Error e)
        {
            new Gtk.MessageDialog (window, Gtk.DialogFlags.MODAL,
                                   Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
                                   /* Error message if printing fails */
                                   "%s\n%s".printf (_("Error printing file:"), e.message)).run ();
        }

        return Gtk.PrintOperationResult.ERROR;
    }

    public SudokuPrinter (SudokuBoard[] boards, ref ApplicationWindow window, int sudokus_per_page = 1)
    {
        this.boards = boards;
        this.window = window;
        this.margin = 25;
        this.n_sudokus = boards.length;
        this.sudokus_per_page = sudokus_per_page;

        this.print_op = new Gtk.PrintOperation ();
        print_op.begin_print.connect (begin_print_cb);
        print_op.draw_page.connect (draw_page_cb);
    }

    private void begin_print_cb (Gtk.PrintOperation operation, Gtk.PrintContext context)
    {
        int remainder = (n_sudokus % sudokus_per_page) == 0 ? 0 : 1;
        operation.set_n_pages ((n_sudokus / sudokus_per_page) + remainder);
    }

    private void draw_page_cb (Gtk.PrintOperation operation, Gtk.PrintContext context, int page_nr)
    {
        Cairo.Context cr = context.get_cairo_context ();
        var width = context.get_width ();
        var height = context.get_height ();

        var best_values = fit_squares_in_rectangle (width, height, margin);
        var best_fit = best_values[0];
        var best_square_size = best_values[1];

        var start = page_nr * sudokus_per_page;
        var end = (start + sudokus_per_page) > boards.length ? boards.length : (start + sudokus_per_page);
        SudokuBoard[] sudokus_on_page = boards[start : end];

        double left = margin;
        double top = margin;
        int[] pos = {1, 1};
        var label = "";

        foreach (SudokuBoard sudoku in sudokus_on_page)
        {
            if (n_sudokus > 1)
                label = sudoku.get_difficulty_catagory ().to_string () + " (" + sudoku.difficulty_rating.to_string ()[0:4] + ")";
            else
                label = "";
            cr.set_font_size (12);
            cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            cr.set_source_rgb (0, 0, 0);
            Cairo.TextExtents extents;
            cr.text_extents (label, out extents);
            cr.move_to (left, top - extents.height / 2);
            cr.show_text (label);

            draw_sudoku (cr, sudoku, best_square_size, left, top);

            if (pos[0] < best_fit)
            {
                left = left + best_square_size + margin;
                pos[0] += 1;
            }
            else
            {
                top = top + best_square_size + margin;
                left = margin;
                pos[0] = 1;
                pos[1] += 1;
            }
        }
    }

    private double[] fit_squares_in_rectangle (double width, double height, int margin)
    {
        var n = sudokus_per_page;
        var best_square_size = 0.0;
        double[] best_fit = {0,0};
        var square_size = 0.0;

        for (var n_across = 1; n_across <= n; n_across++)
        {
            double n_down = n / n_across + ((n % n_across) & 1);
            double across_size = width - ((n_across + 1) * margin);
            across_size = across_size / n_across;
            double down_size = height - ((n_down + 1) * margin);
            down_size = down_size / n_down;

            if (across_size < down_size)
            {
                square_size = across_size;
            }
            else
            {
                square_size = down_size;
            }
            if (square_size > best_square_size)
            {
                best_square_size = square_size;
                best_fit = {n_across, best_square_size};
            }
        }

        return best_fit;
    }

    private void draw_sudoku (Cairo.Context cr, SudokuBoard sudoku_board, double size, double offset_x, double offset_y)
    {
        const int SUDOKU_SIZE = 9;
        const int N_BOXES = 3;
        const double[] PENCIL_GREY = {0.3, 0.3, 0.3};
        const double[] BACKGROUND_COLOR = {1.0, 1.0, 1.0};

        const double[] BORDER_COLOR = {1.0, 1.0, 1.0};
        const double[] LINE_COLOR = {0.0, 0.0, 0.0};

        var THIN = size / 500.0;
        var THICK = THIN * 5;
        var BORDER  = THICK;
        var WHITE_SPACE = (size - (2 * BORDER)- (2 * THICK) - ((N_BOXES -1) * THICK) - ((N_BOXES * 2) * THIN));
        var SQUARE_SIZE = WHITE_SPACE / SUDOKU_SIZE;

        var FONT_SIZE = (int) SQUARE_SIZE / 2;
        const Cairo.FontWeight FONT_WEIGHT = Cairo.FontWeight.NORMAL;

        double[] outer = {offset_x, offset_x + size, offset_y, offset_y + size};  // left, right, top, bottom

        // Entire Background
        cr.set_source_rgb (1.0, 1.0, 1.0);
        cr.rectangle (outer[0], outer[2], size, size);
        cr.fill ();

        // Outer border
        cr.set_line_join (Cairo.LineJoin.ROUND);
        cr.set_line_width (BORDER);
        cr.rectangle (outer[0] + BORDER/2.0, outer[2] + BORDER/2.0, size -  BORDER, size -  BORDER);

        // Inner background
        cr.set_source_rgb (BACKGROUND_COLOR[0], BACKGROUND_COLOR[1], BACKGROUND_COLOR[2]);
        cr.fill_preserve ();
        // Border box
        cr.set_source_rgb (BORDER_COLOR[0], BORDER_COLOR[1], BORDER_COLOR[2]);
        cr.stroke ();

        // Outer thick lines
        cr.set_line_join (Cairo.LineJoin.MITER);
        cr.set_line_width (THICK);
        cr.rectangle (outer[0] + BORDER + THICK / 2.0, outer[2] + BORDER + THICK / 2.0, size -  BORDER * 2 - THICK, size -  BORDER * 2 - THICK);
        cr.set_source_rgb (LINE_COLOR[0], LINE_COLOR[1], LINE_COLOR[2]);
        cr.stroke ();

        var pos = new double[SUDOKU_SIZE+1];
        var position = BORDER + THICK;
        pos[0] = position + SQUARE_SIZE / 2.0;
        var last_line = 0.0;

        for (var n = 1; n <= SUDOKU_SIZE; n++)
        {
            if (n % N_BOXES == 0)
            {
                cr.set_line_width (THICK);
                position += SQUARE_SIZE + last_line/2.0 + THICK/2.0;
                last_line = THICK;
            }
            else
            {
                cr.set_line_width (THIN);
                position += SQUARE_SIZE + last_line/2.0 + THIN/2.0;
                last_line = THIN;
            }

            pos[n] = position + last_line/2.0 + SQUARE_SIZE/2.0;
            cr.move_to (BORDER + THICK/2.0 + offset_x, position + offset_y);
            cr.line_to (size - BORDER - THICK/2.0 + offset_x, position + offset_y);
            cr.move_to (position + offset_x, BORDER + THICK/2.0 + offset_y);
            cr.line_to (position + offset_x, size - BORDER - THICK/2.0 + offset_y);
            cr.stroke ();
        }

        cr.set_font_size (FONT_SIZE);
        var letter = "";
        Cairo.TextExtents extents;
        var sudoku = sudoku_board.get_cells ();

        for (var x = 0; x < SUDOKU_SIZE; x++)
        {
            for (var y = 0; y < SUDOKU_SIZE; y++)
            {
                cr.move_to (pos[x] + offset_x, pos[y] + offset_y);
                letter = "";

                if (sudoku[y,x] != 0)
                {
                    letter = (sudoku[y,x]).to_string ();

                    if (sudoku_board.is_fixed[y,x])
                    {
                        cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, FONT_WEIGHT);
                        cr.set_source_rgb (0, 0, 0);
                    }
                    else
                    {
                        cr.select_font_face ("Times", Cairo.FontSlant.ITALIC, FONT_WEIGHT);
                        cr.set_source_rgb (PENCIL_GREY[0], PENCIL_GREY[1], PENCIL_GREY[2]);
                    }
                    cr.text_extents (letter, out extents);
                    cr.move_to (pos[x] + offset_x - (extents.x_advance / 2.0), pos[y] + offset_y + (extents.height / 2.0));
                    cr.show_text (letter);
                }
            }
        }
    }
}

public class GamePrinter: GLib.Object {

    private SudokuStore store;
    private SudokuSaver saver;
    private ApplicationWindow window;
    private GLib.Settings settings;
    private Gtk.Dialog dialog;
    private HashMap<string, CheckButton> options_map;
    private SpinButton sudokusToPrintSpinButton;
    private SpinButton sudokusPerPageSpinButton;

    public GamePrinter (SudokuStore store, SudokuSaver saver, ref ApplicationWindow window)
    {
        this.store = store;
        this.saver = saver;
        this.window = window;
        this.settings = new GLib.Settings ("org.gnome.gnome-sudoku");
        this.options_map = new HashMap<string, CheckButton> ();

        Gtk.Builder builder = new Builder ();
        try
        {
            builder.add_from_resource ("/org/gnome/gnome-sudoku/ui/print-games.ui");
        }
        catch (GLib.Error e)
        {
            GLib.warning ("Could not load UI: %s", e.message);
        }
        builder.connect_signals (null);
        this.dialog = builder.get_object ("dialog") as Dialog;
        dialog.set_transient_for (window);
        dialog.set_default_response (Gtk.ResponseType.OK);
        dialog.response.connect (response_cb);

        string[,] settings_to_widgets = {
            {"mark-printed-as-played", "markAsPlayedToggle"},
            {"print-already-played-games", "includeOldGamesToggle"},
            {"print-easy", "easyCheckButton"},
            {"print-medium", "mediumCheckButton"},
            {"print-hard", "hardCheckButton"},
            {"print-very-hard", "very_hardCheckButton"}};
        CheckButton check_button;
        string setting0, setting1;

        for (var i=0; i<6; i++)
        {
            setting0 = settings_to_widgets[i,0];
            setting1 = settings_to_widgets[i,1];
            try
            {
                check_button = builder.get_object (setting1) as CheckButton;
            }
            catch (GLib.Error e)
            {
                GLib.warning ("Widget %s does not exist: %s", setting1, e.message);
            }
            wrap_toggle (setting0, check_button);
            options_map.set (setting1, check_button);
        }

        sudokusToPrintSpinButton = builder.get_object ("sudokusToPrintSpinButton") as SpinButton;
        sudokusPerPageSpinButton = builder.get_object ("sudokusPerPageSpinButton") as SpinButton;

        wrap_adjustment ("print-multiple-sudokus-to-print", sudokusToPrintSpinButton.get_adjustment ());
        wrap_adjustment ("sudokus-per-page", sudokusPerPageSpinButton.get_adjustment ());
    }

    private void wrap_toggle (string key_name, CheckButton action)
    {
        action.set_active (settings.get_boolean (key_name));
        action.toggled.connect (() => settings.set_boolean (key_name, action.get_active ()));
    }

    private void wrap_adjustment (string key_name, Adjustment action)
    {
        action.set_value (settings.get_int (key_name));
        action.value_changed.connect (() => settings.set_int (key_name, (int) action.get_value ()));
    }

    private void response_cb (Dialog dialog, int response)
    {
        if (response != Gtk.ResponseType.ACCEPT && response != Gtk.ResponseType.OK)
        {
            dialog.hide ();
            return;
        }

        var nsudokus = (int) sudokusToPrintSpinButton.get_adjustment ().get_value ();
        var sudokus_per_page = (int) sudokusPerPageSpinButton.get_adjustment ().get_value ();
        DifficultyCatagory[] levels = {};

        if (options_map.get ("easyCheckButton").get_active () == true)
            levels += DifficultyCatagory.EASY;
        if (options_map.get ("mediumCheckButton").get_active () == true)
            levels += DifficultyCatagory.MEDIUM;
        if (options_map.get ("hardCheckButton").get_active () == true)
            levels += DifficultyCatagory.HARD;
        if (options_map.get ("very_hardCheckButton").get_active () == true)
            levels += DifficultyCatagory.VERY_HARD;

        var boards = new ArrayList<SudokuBoard> ();
        boards = store.get_assorted_boards (nsudokus, levels, !options_map.get ("includeOldGamesToggle").get_active ());

        SudokuBoard[] sorted_boards = {};

        foreach (SudokuBoard i in boards)
            sorted_boards += i;

        SudokuPrinter printer = new SudokuPrinter (sorted_boards, ref window, sudokus_per_page);
        PrintOperationResult result = printer.print_sudoku ();

        if (result == PrintOperationResult.APPLY)
        {
            dialog.hide ();
            if (options_map.get ("markAsPlayedToggle").get_active ())
                foreach (SudokuBoard i in sorted_boards)
                    saver.add_game_to_finished (new SudokuGame (i));
        }
    }

    public void run_dialog ()
    {
        dialog.show ();
    }

}
