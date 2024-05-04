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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/print-dialog.ui")]
public class PrintDialog : Adw.Dialog
{
    private SudokuSaver saver;
    private GLib.Settings settings;

    [GtkChild] private unowned Button print_button;
    [GtkChild] private unowned Adw.PreferencesGroup options_group;
    [GtkChild] private unowned Adw.SpinRow n_puzzles;
    [GtkChild] private unowned Adw.SpinRow n_puzzles_per_page;
    [GtkChild] private unowned Adw.ComboRow difficulty;

    private Cancellable cancellable;
    private SudokuWindow window;

    private const string DIFFICULTY_KEY_NAME = "print-multiple-sudoku-difficulty";
    private const int MAX_PUZZLES_PER_PAGE = 15;

    public PrintDialog (SudokuSaver saver, SudokuWindow window)
    {
        this.window = window;
        this.saver = saver;
        settings = new GLib.Settings ("org.gnome.Sudoku");

        var saved_difficulty = (DifficultyCategory) settings.get_enum (DIFFICULTY_KEY_NAME);
        difficulty.set_selected (((int) saved_difficulty) - 1);

        var initial_total_value = settings.get_int ("print-multiple-sudokus-to-print");
        var initial_per_page_value = settings.get_int ("print-multiple-sudokus-to-print-per-page");

        var total = n_puzzles.get_adjustment ();
        var per_page = n_puzzles_per_page.get_adjustment ();

        total.set_value (initial_total_value);
        var initial_max_per_page = int.min (MAX_PUZZLES_PER_PAGE, initial_total_value);
        per_page.set_value (int.min (initial_max_per_page, initial_per_page_value));
        per_page.set_upper (initial_max_per_page);

        total.value_changed.connect (() => {
            var total_value = (int) total.get_value ();
            settings.set_int ("print-multiple-sudokus-to-print", total_value);

            var max_per_page = int.min (MAX_PUZZLES_PER_PAGE, total_value);
            var per_page_value = (int) per_page.get_value ();
            per_page_value = int.min (per_page_value, max_per_page);
            per_page.set_upper (max_per_page);
            per_page.set_value (per_page_value);
        });
        per_page.value_changed.connect (() => {
            var per_page_value = (int) per_page.get_value ();
            settings.set_int ("print-multiple-sudokus-to-print-per-page", per_page_value);
        });

        print_button.clicked.connect (() => {
            print ();
        });
    }

    public void print ()
    {
        var npuzzles = (int) n_puzzles.get_adjustment ().get_value ();
        var npuzzles_per_page = (int) n_puzzles_per_page.get_adjustment ().get_value ();
        DifficultyCategory level = (DifficultyCategory) difficulty.get_selected() + 1;

        settings.set_enum (DIFFICULTY_KEY_NAME, level);

        print_button.sensitive = false;
        options_group.sensitive = false;

        cancellable = new Cancellable ();
        SudokuGenerator.generate_boards_async.begin (npuzzles, level, cancellable, (obj, res) => {
            try
            {
                var boards = SudokuGenerator.generate_boards_async.end (res);

                var printer = new SudokuPrinter (boards, npuzzles_per_page, window);
                if (printer.print_sudoku () == PrintOperationResult.APPLY)
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
