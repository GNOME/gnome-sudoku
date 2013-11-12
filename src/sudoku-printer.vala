using Gtk;
using Gdk;

public class SudokuPrinter : GLib.Object {

    private SudokuBoard board;
    private DifficultyRating difficulty_rating;
    private ApplicationWindow window;

    private int margin;
    private int n_sudokus;
    private int sudokus_per_page;

    private Gtk.PrintOperation print_op;

    public void print_sudoku ()
    {
        Gtk.PrintOperationResult result = print_op.run (Gtk.PrintOperationAction.PRINT_DIALOG, window);
        if (result == Gtk.PrintOperationResult.ERROR)
        {
            Gtk.MessageDialog error_dialog = new Gtk.MessageDialog (window, Gtk.DialogFlags.DESTROY_WITH_PARENT, Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE, "Error printing file\n");
            error_dialog.response.connect ((w) => {
                error_dialog.destroy();
            });
            error_dialog.show ();
        }
    }

    public SudokuPrinter (SudokuBoard board, ref  ApplicationWindow window)
    {
        this.board = board;
        this.window = window;
        this.margin = 25;
        this.n_sudokus = 1;
        this.sudokus_per_page = 1;

        this.print_op = new Gtk.PrintOperation ();
        print_op.begin_print.connect (begin_print_cb);
        print_op.draw_page.connect (draw_page_cb);
    }

    private void begin_print_cb (Gtk.PrintOperation operation, Gtk.PrintContext context)
    {
        operation.set_n_pages ((n_sudokus / sudokus_per_page) + ((n_sudokus % sudokus_per_page) & 1));
    }

    private void draw_page_cb (Gtk.PrintOperation operation, Gtk.PrintContext context, int page_nr)
    {
        Cairo.Context cr = context.get_cairo_context ();
        double width = context.get_width ();
        double height = context.get_height ();

        double[] best_values = fit_squares_in_rectangle (width, height, sudokus_per_page, margin);
        double best_fit = best_values[0];
        double best_square_size = best_values[1];

        int start = page_nr * sudokus_per_page;
        int left = margin;
        int top = margin;

        draw_sudoku (cr, best_square_size, left, top);
    }

    private double[] fit_squares_in_rectangle (double width, double height, int n, int margin)
    {
        double best_square_size = 0;
        double[] best_fit = {0,0};
        double square_size = 0;

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

    private void draw_sudoku (Cairo.Context cr, double size, int offset_x, int offset_y)
    {
        const int SUDOKU_SIZE = 9;
        const int N_BOXES = 3;
        const double[] PENCIL_GREY = {0.3, 0.3, 0.3};
        const double[] BACKGROUND_COLOR = {1.0, 1.0, 1.0};

        const double[] BORDER_COLOR = {1.0, 1.0, 1.0};
        const double[] LINE_COLOR = {0.0, 0.0, 0.0};

        double THIN = size / 500.0;
        double THICK = THIN * 5;
        double BORDER  = THICK;
        double WHITE_SPACE = (size - (2 * BORDER)- (2 * THICK) - ((N_BOXES -1) * THICK) - ((N_BOXES * 2) * THIN));
        double SQUARE_SIZE = WHITE_SPACE / SUDOKU_SIZE;

        int FONT_SIZE = (int) SQUARE_SIZE / 2;
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

        double[] pos = new double[SUDOKU_SIZE+1];
        double position = BORDER + THICK;
        pos[0] = position + SQUARE_SIZE / 2.0;
        double last_line = 0;

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
        string letter = "";
        Cairo.TextExtents extents;
        int[,] sudoku = board.get_cells ();

        for (var x = 0; x < SUDOKU_SIZE; x++)
        {
            for (var y = 0; y < SUDOKU_SIZE; y++)
            {
                cr.move_to (pos[x] + offset_x, pos[y] + offset_y);
                letter = "";

                if (sudoku[y,x] != 0)
                {
                    letter = (sudoku[y,x]).to_string ();

                    if (board.is_fixed[y,x])
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
