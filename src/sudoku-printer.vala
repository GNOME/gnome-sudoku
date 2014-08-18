/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gtk;
using Gee;
using Gdk;

public class SudokuPrinter : GLib.Object {

    private SudokuBoard[] boards;
    private ApplicationWindow window;

    private int margin;
    private int n_sudokus;
    private const int SUDOKUS_PER_PAGE = 2;

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

    public SudokuPrinter (SudokuBoard[] boards, ref ApplicationWindow window)
    {
        this.boards = boards;
        this.window = window;
        this.margin = 25;
        this.n_sudokus = boards.length;

        this.print_op = new Gtk.PrintOperation ();
        print_op.begin_print.connect (begin_print_cb);
        print_op.draw_page.connect (draw_page_cb);
    }

    private void begin_print_cb (Gtk.PrintOperation operation, Gtk.PrintContext context)
    {
        int pages = n_sudokus / SUDOKUS_PER_PAGE;
        while (pages * SUDOKUS_PER_PAGE < n_sudokus)
            pages += 1;

        operation.set_n_pages (pages);
    }

    private void draw_page_cb (Gtk.PrintOperation operation, Gtk.PrintContext context, int page_nr)
    {
        Cairo.Context cr = context.get_cairo_context ();
        var width = context.get_width ();
        var height = context.get_height ();

        var best_square_size = fit_squares_in_rectangle (width, height, margin);

        var start = page_nr * SUDOKUS_PER_PAGE;
        var end = int.min ((start + SUDOKUS_PER_PAGE), boards.length);
        SudokuBoard[] sudokus_on_page = boards[start : end];

        double left = (width - best_square_size) / 2;
        double top = margin;

        foreach (SudokuBoard sudoku in sudokus_on_page)
        {
            var label = sudoku.difficulty_category.to_string ();
            cr.set_font_size (12);
            cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            cr.set_source_rgb (0, 0, 0);
            Cairo.TextExtents extents;
            cr.text_extents (label, out extents);
            cr.move_to ((width - extents.width) / 2, top - extents.height / 2);
            cr.show_text (label);

            draw_sudoku (cr, sudoku, best_square_size, left, top);

            top += best_square_size + (2 * margin);
        }
    }

    private double fit_squares_in_rectangle (double width, double height, int margin)
    {
        var n = SUDOKUS_PER_PAGE;
        var best_square_size = 0.0;
        var square_size = 0.0;

        for (var n_across = 1; n_across <= n; n_across++)
        {
            double n_down = n / n_across;
            double across_size = width - ((n_across + 1) * margin);
            across_size = across_size / n_across;
            double down_size = height - ((n_down + 1) * margin);
            down_size = down_size / n_down;

            square_size = double.min (across_size, down_size);
            if (square_size > best_square_size)
                best_square_size = square_size;
        }

        return best_square_size;
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

public class GamePrinter: GLib.Object
{
    private SudokuSaver saver;
    private ApplicationWindow window;
    private GLib.Settings settings;
    private Gtk.Dialog dialog;
    private SpinButton nsudokus_button;

    private RadioButton easy_button;
    private RadioButton medium_button;
    private RadioButton hard_button;
    private RadioButton very_hard_button;

    private Spinner spinner;

    private const string DIFFICULTY_KEY_NAME = "print-multiple-sudoku-difficulty";

    public GamePrinter (SudokuSaver saver, ref ApplicationWindow window)
    {
        this.saver = saver;
        this.window = window;
        this.settings = new GLib.Settings ("org.gnome.sudoku");

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

        SList<RadioButton> radio_group = new SList<RadioButton> ();

        easy_button = builder.get_object ("easyRadioButton") as RadioButton;
        easy_button.set_group (radio_group);

        medium_button = builder.get_object ("mediumRadioButton") as RadioButton;
        medium_button.join_group (easy_button);

        hard_button = builder.get_object ("hardRadioButton") as RadioButton;
        hard_button.join_group (easy_button);

        very_hard_button = builder.get_object ("very_hardRadioButton") as RadioButton;
        very_hard_button.join_group (easy_button);

        var saved_difficulty = (DifficultyCategory) settings.get_enum (DIFFICULTY_KEY_NAME);

        if (saved_difficulty == DifficultyCategory.EASY)
            easy_button.set_active (true);
        else if (saved_difficulty == DifficultyCategory.MEDIUM)
            medium_button.set_active (true);
        else if (saved_difficulty == DifficultyCategory.HARD)
            hard_button.set_active (true);
        else if (saved_difficulty == DifficultyCategory.VERY_HARD)
            very_hard_button.set_active (true);

        nsudokus_button = builder.get_object ("sudokusToPrintSpinButton") as SpinButton;
        wrap_adjustment ("print-multiple-sudokus-to-print", nsudokus_button.get_adjustment ());

        spinner = builder.get_object ("spinner") as Spinner;
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

        var nsudokus = (int) nsudokus_button.get_adjustment ().get_value ();
        DifficultyCategory level;

        if (easy_button.get_active ())
            level = DifficultyCategory.EASY;
        else if (medium_button.get_active ())
            level = DifficultyCategory.MEDIUM;
        else if (hard_button.get_active ())
            level = DifficultyCategory.HARD;
        else if (very_hard_button.get_active ())
            level = DifficultyCategory.VERY_HARD;
        else
            assert_not_reached ();

        settings.set_enum (DIFFICULTY_KEY_NAME, level);

        spinner.visible = true;
        spinner.active = true;
        spinner.show ();
        spinner.start ();
        dialog.sensitive = false;

        SudokuGenerator.generate_boards_async.begin(nsudokus, level, (obj, res) => {
            try {
                var boards = SudokuGenerator.generate_boards_async.end(res);

                spinner.stop ();
                spinner.hide ();
                dialog.sensitive = true;

                SudokuPrinter printer = new SudokuPrinter (boards, ref window);
                PrintOperationResult result = printer.print_sudoku ();
                if (result == PrintOperationResult.APPLY)
                {
                    dialog.hide ();
                    foreach (SudokuBoard board in boards)
                        saver.add_game_to_finished (new SudokuGame (board));
                }
            } catch (ThreadError e) {
                error ("Thread error: %s\n", e.message);
            }
        });
    }

    public void run_dialog ()
    {
        dialog.show ();
    }

}
