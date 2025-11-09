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
    [GtkChild] private unowned Button print_button;
    [GtkChild] private unowned Adw.PreferencesGroup options_group;
    [GtkChild] private unowned Adw.SpinRow n_puzzles;
    [GtkChild] private unowned Adw.SpinRow n_puzzles_per_page;
    [GtkChild] private unowned Adw.ComboRow difficulty;

    private SudokuWindow window;
    private SudokuSaver saver;

    public SudokuPrintDialog (SudokuSaver saver, SudokuWindow window)
    {
        this.window = window;
        this.saver = saver;

        if (Sudoku.app.play_difficulty != DifficultyCategory.CUSTOM)
            difficulty.set_selected (((int) Sudoku.app.play_difficulty) - 1);
    }

    [GtkCallback]
    public void print ()
    {
        var npuzzles = (int) n_puzzles.get_adjustment ().get_value ();
        var npuzzles_per_page = (int) n_puzzles_per_page.get_adjustment ().get_value ();
        DifficultyCategory level = (DifficultyCategory) difficulty.get_selected() + 1;

        print_button.sensitive = false;
        options_group.sensitive = false;

        SudokuGenerator.generate_boards_async.begin (npuzzles, level, null, (obj, res) => {
            try
            {
                var boards = SudokuGenerator.generate_boards_async.end (res);

                var printer = new SudokuPrinter (boards, npuzzles_per_page);
                if (printer.print_sudoku (window) == PrintOperationResult.APPLY)
                {
                    foreach (SudokuBoard board in boards)
                        saver.add_game_to_finished (new SudokuGame (board));
                }
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
}
