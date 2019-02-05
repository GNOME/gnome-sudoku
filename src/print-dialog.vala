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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/print-dialog.ui")]
public class PrintDialog : Gtk.Dialog
{
    private SudokuSaver saver;
    private Settings settings;

    [GtkChild]
    private Gtk.Button print_button;
    [GtkChild]
    private Gtk.Box print_box;
    [GtkChild]
    private Gtk.SpinButton n_sudokus_button;
    [GtkChild]
    private Gtk.RadioButton easy_radio_button;
    [GtkChild]
    private Gtk.RadioButton medium_radio_button;
    [GtkChild]
    private Gtk.RadioButton hard_radio_button;
    [GtkChild]
    private Gtk.RadioButton very_hard_radio_button;

    private Gtk.Revealer revealer;
    private Gtk.Spinner spinner;

    private Cancellable cancellable;

    private const string DIFFICULTY_KEY_NAME = "print-multiple-sudoku-difficulty";

    public PrintDialog (SudokuSaver saver, Gtk.Window window)
    {
        Object (use_header_bar: 1);

        this.saver = saver;
        settings = new GLib.Settings ("org.gnome.sudoku");

        this.response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.CANCEL || response_id == Gtk.ResponseType.DELETE_EVENT)
                cancellable.cancel ();
        });

        set_transient_for (window);

        spinner = new Gtk.Spinner ();
        revealer = new Gtk.Revealer ();
        revealer.add (spinner);
        revealer.valign = Gtk.Align.CENTER;
        ((Gtk.HeaderBar) get_header_bar ()).pack_end (revealer);

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

        wrap_adjustment ("print-multiple-sudokus-to-print", n_sudokus_button.get_adjustment ());
    }

    private void wrap_adjustment (string key_name, Gtk.Adjustment action)
    {
        action.set_value (settings.get_int (key_name));
        action.value_changed.connect (() => settings.set_int (key_name, (int) action.get_value ()));
    }

    public bool start_spinner_cb ()
    {
        revealer.set_transition_type (Gtk.RevealerTransitionType.SLIDE_LEFT);
        revealer.show_all ();
        spinner.start ();
        revealer.set_reveal_child (true);
        return Source.REMOVE;
    }

    public override void response (int response)
    {
        if (response != Gtk.ResponseType.OK)
        {
            destroy ();
            return;
        }

        var nsudokus = (int) n_sudokus_button.get_adjustment ().get_value ();
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
        print_box.sensitive = false;

        cancellable = new Cancellable ();
        SudokuGenerator.generate_boards_async.begin (nsudokus, level, cancellable, (obj, res) => {
            try
            {
                var boards = SudokuGenerator.generate_boards_async.end (res);

                spinner.stop ();
                revealer.hide ();

                var printer = new SudokuPrinter (boards, this);
                if (printer.print_sudoku () == Gtk.PrintOperationResult.APPLY)
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
