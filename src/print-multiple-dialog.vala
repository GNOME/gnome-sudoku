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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/print-multiple-dialog.ui")]
public class SudokuPrintDialog : Adw.Dialog
{
    [GtkChild] private unowned Adw.SpinRow puzzles_row;
    [GtkChild] private unowned Adw.SpinRow puzzles_per_page_row;
    [GtkChild] private unowned Adw.ComboRow difficulty_row;
    [GtkChild] private unowned Adw.SwitchRow print_current_puzzle_row;

    private SudokuWindow window;
    private SudokuBackend backend;
    private Adjustment per_page_adjustment;

    public SudokuPrintDialog (SudokuBackend backend, SudokuWindow window)
    {
        this.window = window;
        this.backend = backend;

        if (Sudoku.app.start_button_selected != DifficultyCategory.CUSTOM)
            difficulty_row.set_selected (((int) Sudoku.app.start_button_selected) - 1);

        print_current_puzzle_row.visible = backend.game != null;

        per_page_adjustment = puzzles_per_page_row.get_adjustment ();
        per_page_adjustment.value_changed.connect (() => {
            var per_page = per_page_adjustment.value;
            puzzles_row.adjustment.step_increment = per_page;
            puzzles_row.adjustment.page_increment = per_page * 5;
            puzzles_row.adjustment.lower = per_page;
            if (puzzles_row.adjustment.value % per_page != 0)
                puzzles_row.adjustment.value += per_page - puzzles_row.adjustment.value % per_page;
        });
    }

    [GtkCallback]
    public void print ()
    {
        int puzzles_to_generate = (int) puzzles_row.get_adjustment ().get_value ();
        int puzzles_per_page = (int) puzzles_per_page_row.get_adjustment ().get_value ();
        DifficultyCategory diff_cat = (DifficultyCategory) difficulty_row.get_selected() + 1;
        var boards = new Gee.ArrayList<SudokuBoard> ();

        if (backend.game != null && print_current_puzzle_row.active)
        {
            boards.add (backend.game.board);
            puzzles_to_generate--;
            if (puzzles_to_generate == 0)
            {
                send_to_printer (boards, puzzles_per_page);
                return;
            }
        }

        SudokuGenerator.generate_boards_async.begin (puzzles_to_generate, diff_cat, null, (obj, res) => {
            try
            {
                boards.add_all (SudokuGenerator.generate_boards_async.end (res));
                send_to_printer (boards, puzzles_per_page);
            }
            catch (ThreadError e)
            {
                error ("Thread error: %s\n", e.message);
            }
            catch (IOError e)
            {
                if (!(e is IOError.CANCELLED))
                    warning ("Error: %s\n", e.message);
            }

            close ();
        });
    }

    void send_to_printer (Gee.List<SudokuBoard> boards, int puzzles_per_page)
    {
        var printer = new SudokuPrinter (boards, puzzles_per_page);
        if (printer.print_sudoku (window) == PrintOperationResult.APPLY)
        {
            foreach (SudokuBoard board in boards)
                backend.add_board_to_printed (board);
        }
    }
}
