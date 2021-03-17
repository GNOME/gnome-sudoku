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
public class PrintDialog : Dialog
{
    private SudokuSaver saver;
    private GLib.Settings settings;

    [GtkChild] private unowned Button print_button;
    [GtkChild] private unowned Grid print_grid;
    [GtkChild] private unowned SpinButton n_sudokus_button;
    [GtkChild] private unowned SpinButton n_sudokus_per_page_button;
    [GtkChild] private unowned RadioButton easy_radio_button;
    [GtkChild] private unowned RadioButton medium_radio_button;
    [GtkChild] private unowned RadioButton hard_radio_button;
    [GtkChild] private unowned RadioButton very_hard_radio_button;

    private Revealer revealer;
    private Spinner spinner;

    private Cancellable cancellable;

    private const string DIFFICULTY_KEY_NAME = "print-multiple-sudoku-difficulty";
    private const int MAX_PUZZLES_PER_PAGE = 15;

    public PrintDialog (SudokuSaver saver, Window window)
    {
        Object (use_header_bar: 1);

        this.saver = saver;
        settings = new GLib.Settings ("org.gnome.Sudoku");

        this.response.connect ((response_id) => {
            if (response_id == ResponseType.CANCEL || response_id == ResponseType.DELETE_EVENT)
                cancellable.cancel ();
        });

        set_transient_for (window);

        spinner = new Spinner ();
        revealer = new Revealer ();
        revealer.add (spinner);
        revealer.valign = Align.CENTER;
        ((HeaderBar) get_header_bar ()).pack_end (revealer);

        var saved_difficulty = (DifficultyCategory) settings.get_enum (DIFFICULTY_KEY_NAME);
        if (saved_difficulty == DifficultyCategory.EASY)
            easy_radio_button.set_active (true);
        else if (saved_difficulty == DifficultyCategory.MEDIUM)
            medium_radio_button.set_active (true);
        else if (saved_difficulty == DifficultyCategory.HARD)
            hard_radio_button.set_active (true);
        else if (saved_difficulty == DifficultyCategory.VERY_HARD)
            very_hard_radio_button.set_active (true);
        else
            assert_not_reached ();

        var initial_total_value = settings.get_int ("print-multiple-sudokus-to-print");
        var initial_per_page_value = settings.get_int ("print-multiple-sudokus-to-print-per-page");

        var total = n_sudokus_button.get_adjustment ();
        var per_page = n_sudokus_per_page_button.get_adjustment ();

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
    }

    public bool start_spinner_cb ()
    {
        revealer.set_transition_type (RevealerTransitionType.SLIDE_LEFT);
        revealer.show_all ();
        spinner.start ();
        revealer.set_reveal_child (true);
        return Source.REMOVE;
    }

    public override void response (int response)
    {
        if (response != ResponseType.OK)
        {
            destroy ();
            return;
        }

        var nsudokus = (int) n_sudokus_button.get_adjustment ().get_value ();
        var nsudokus_per_page = (int) n_sudokus_per_page_button.get_adjustment ().get_value ();
        DifficultyCategory level;

        if (easy_radio_button.get_active ())
            level = DifficultyCategory.EASY;
        else if (medium_radio_button.get_active ())
            level = DifficultyCategory.MEDIUM;
        else if (hard_radio_button.get_active ())
            level = DifficultyCategory.HARD;
        else if (very_hard_radio_button.get_active ())
            level = DifficultyCategory.VERY_HARD;
        else
            assert_not_reached ();

        settings.set_enum (DIFFICULTY_KEY_NAME, level);

        Timeout.add_seconds (3, (SourceFunc) start_spinner_cb);

        print_button.sensitive = false;
        print_grid.sensitive = false;

        cancellable = new Cancellable ();
        SudokuGenerator.generate_boards_async.begin (nsudokus, level, cancellable, (obj, res) => {
            try
            {
                var boards = SudokuGenerator.generate_boards_async.end (res);

                spinner.stop ();
                revealer.hide ();

                var printer = new SudokuPrinter (boards, nsudokus_per_page, this);
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

            destroy ();
        });
    }
}
