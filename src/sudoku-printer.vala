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

public class SudokuPrinter : GLib.Object {

    private Gee.List<SudokuBoard> boards;
    private Gtk.Window window;

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

    public SudokuPrinter (Gee.List<SudokuBoard> boards, Gtk.Window window)
    {
        this.boards = boards;
        this.window = window;
        this.margin = 25;
        this.n_sudokus = boards.size;

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
        var end = int.min ((start + SUDOKUS_PER_PAGE), boards.size);
        Gee.List<SudokuBoard> sudokus_on_page = boards.slice (start, end);

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

        var invert = Gtk.Widget.get_default_direction () == Gtk.TextDirection.RTL;

        for (var x = 0; x < SUDOKU_SIZE; x++)
        {
            var real_x = invert ? SUDOKU_SIZE - x - 1 : x;
            for (var y = 0; y < SUDOKU_SIZE; y++)
            {
                cr.move_to (pos[x] + offset_x, pos[y] + offset_y);
                letter = "";

                if (sudoku[y,real_x] != 0)
                {
                    letter = (sudoku[y,real_x]).to_string ();

                    if (sudoku_board.is_fixed[y,real_x])
                    {
                        cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, FONT_WEIGHT);
                        cr.set_source_rgb (0, 0, 0);
                    }
                    else
                    {
                        cr.select_font_face ("Sans", Cairo.FontSlant.ITALIC, FONT_WEIGHT);
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
