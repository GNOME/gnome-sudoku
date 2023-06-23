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

public class Sudoku : Adw.Application
{
    private GLib.Settings settings;

    private SudokuWindow window;
    private SudokuGame? game = null;

    private SudokuView? view
    {
        get { return window.view; }
    }

    private SudokuSaver saver;

    private SimpleAction undo_action;
    private SimpleAction redo_action;
    private SimpleAction clear_action;
    private SimpleAction print_action;
    private SimpleAction print_multiple_action;
    private SimpleAction pause_action;
    private SimpleAction play_custom_game_action;
    private SimpleAction new_game_action;

    private bool show_possibilities = false;
    private GameMode current_game_mode = GameMode.PLAY;

    private const GLib.ActionEntry action_entries[] =
    {
        {"new-game", new_game_cb                                    },
        {"start-game", start_game_cb, "i"                           },
        {"create-game", create_game_cb                              },
        {"reset", reset_cb                                          },
        {"back", back_cb                                            },
        {"undo", undo_cb                                            },
        {"redo", redo_cb                                            },
        {"print", print_cb                                          },
        {"play-custom-game", play_custom_game_cb                    },
        {"pause", toggle_pause_cb                                   },
        {"print-multiple", print_multiple_cb                        },
        {"help", help_cb                                            },
        {"about", about_cb                                          },
        {"quit", quit                                               }
    };

    private const OptionEntry[] option_entries =
    {
        { "version", 'v', 0, OptionArg.NONE, null,
        /* Help string for command line --version flag */
        N_("Show release version"), null},

        { "show-possible-values", 's', 0, OptionArg.NONE, null,
        /* Help string for command line --show-possible flag */
        N_("Show the possible values for each cell"), null},

        { null }
    };

    public Sudoku ()
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Object (application_id: "org.gnome.Sudoku", flags: ApplicationFlags.FLAGS_NONE);
        add_main_option_entries (option_entries);

        typeof (SudokuMainMenuItem).ensure ();

        this.get_style_manager ().set_color_scheme (Adw.ColorScheme.FORCE_LIGHT);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* Not translated so can be easily parsed */
            stderr.printf ("gnome-sudoku %s\n", VERSION);
            return Posix.EXIT_SUCCESS;
        }
        if (options.contains ("show-possible-values"))
            show_possibilities = true;

        /* Activate */
        return -1;
    }

    protected override void startup ()
    {
        base.startup ();

        add_action_entries (action_entries, this);

        settings = new GLib.Settings ("org.gnome.Sudoku");
        var action = settings.create_action ("show-warnings");
        action.notify["state"].connect (() => {
            if (view != null && current_game_mode == GameMode.PLAY)
                view.show_warnings = settings.get_boolean ("show-warnings");
        });
        add_action (action);

        action = settings.create_action ("show-extra-warnings");
        action.notify["state"].connect (() => {
            if (view != null && current_game_mode == GameMode.PLAY)
                view.show_extra_warnings = settings.get_boolean ("show-extra-warnings");
        });
        add_action (action);

        action = settings.create_action ("highlighter");
        action.notify["state"].connect (() => {
            if (view != null)
                view.highlighter = settings.get_boolean ("highlighter");
        });
        add_action (action);

        action = settings.create_action ("initialize-earmarks");
        action.notify["state"].connect (() => {
            if (view != null)
                view.initialize_earmarks = settings.get_boolean ("initialize-earmarks");
        });
        add_action (action);

        set_accels_for_action ("app.new-game", {"<Primary>n"});
        set_accels_for_action ("app.print", {"<Primary>p"});
        set_accels_for_action ("app.quit", {"<Primary>q"});
        set_accels_for_action ("app.reset", {"<Primary>r"});
        set_accels_for_action ("app.undo", {"<Primary>z"});
        set_accels_for_action ("app.redo", {"<Primary><Shift>z"});
        set_accels_for_action ("app.help", {"F1"});

        undo_action = (SimpleAction) lookup_action ("undo");
        redo_action = (SimpleAction) lookup_action ("redo");
        new_game_action = (SimpleAction) lookup_action ("new-game");
        clear_action = (SimpleAction) lookup_action ("reset");
        print_action = (SimpleAction) lookup_action ("print");
        print_multiple_action = (SimpleAction) lookup_action ("print-multiple");
        pause_action = (SimpleAction) lookup_action ("pause");
        play_custom_game_action = (SimpleAction) lookup_action ("play-custom-game");

        Window.set_default_icon_name ("org.gnome.Sudoku");

        window = new SudokuWindow (settings);
        add_window (window);

        saver = new SudokuSaver ();
        var savegame = saver.get_savedgame ();
        if (savegame != null)
        {
            if (savegame.board.difficulty_category == DifficultyCategory.CUSTOM)
                current_game_mode = savegame.board.filled == savegame.board.fixed ? GameMode.CREATE : GameMode.PLAY;
            start_game (savegame.board);
        }
        else
            show_new_game_screen ();
    }

    protected override void activate ()
    {
        window.present ();
    }

    protected override void shutdown ()
    {
        if (game != null)
        {
            if (!game.is_empty () && !game.board.complete)
                saver.save_game (game);

            if (game.is_empty () && saver.get_savedgame () != null)
            {
                var file = File.new_for_path (SudokuSaver.savegame_file);

                try
                {
                    file.delete ();
                }
                catch (Error e)
                {
                    warning ("Failed to delete saved game: %s", e.message);
                }
            }
        }

        base.shutdown ();
    }

    private void paused_changed_cb ()
    {
        if (game.paused)
        {
            clear_action.set_enabled (false);
            undo_action.set_enabled (false);
            redo_action.set_enabled (false);
            new_game_action.set_enabled (false);
        }
        else if (game.get_total_time_played () > 0)
        {
            clear_action.set_enabled (!game.is_empty ());
            undo_action.set_enabled (!game.is_undostack_null ());
            redo_action.set_enabled (!game.is_redostack_null ());
            new_game_action.set_enabled (true);
        }

        window.display_pause_button ();
        view.queue_draw ();
    }

    private void play_custom_game_cb ()
    {
        int solutions = game.board.count_solutions_limited ();
        if (solutions == 1)
            start_custom_game (game.board);
        else if (solutions == 0)
        {
            // Error dialog shown when starting a custom game that is not valid.
            var dialog = new Adw.MessageDialog (window, _("The puzzle you have entered is not a valid Sudoku."), _("Please enter a valid puzzle."));
            dialog.add_response ("close", _("Close"));

            dialog.response.connect (() => dialog.destroy ());
            dialog.show ();
        }
        else
        {
            // Warning dialog shown when starting a custom game that has multiple solutions.
            var dialog = new Adw.MessageDialog (window, _("The puzzle you have entered has multiple solutions."), _("Valid Sudoku puzzles have exactly one solution."));
            dialog.add_response ("close", _("_Back"));
            dialog.add_response ("continue", _("Play _Anyway"));
            dialog.set_response_appearance ("continue", Adw.ResponseAppearance.DESTRUCTIVE);

            dialog.response["continue"].connect (() => {
                start_custom_game (game.board);
                dialog.destroy ();
            });

            dialog.show ();
        }
    }

    private void toggle_pause_cb ()
    {
       if (game.paused)
           game.resume_clock ();
       else
           game.stop_clock ();
    }

    private void cell_changed_cb ()
    {
        undo_action.set_enabled (!game.is_undostack_null ());
        redo_action.set_enabled (!game.is_redostack_null ());
        clear_action.set_enabled (!game.is_empty ());
        play_custom_game_action.set_enabled (!game.is_empty () && !game.board.is_fully_filled ());
    }

    private void board_completed_cb ()
    {
        window.board_completed ();

        game.stop_clock ();

        for (var i = 0; i < game.board.rows; i++)
            for (var j = 0; j < game.board.cols; j++)
                view.can_focus = false;

        saver.add_game_to_finished (game, true);

        /* Text in dialog that displays when the game is over. */
        var minutes = int.max (1, (int) game.get_total_time_played () / 60);
        var time_str = ngettext ("Well done, you completed the puzzle in %d minute!",
                                 "Well done, you completed the puzzle in %d minutes!",
                                 minutes).printf (minutes);
        var dialog = new Adw.MessageDialog (window, time_str, null);
        dialog.add_response ("close", _("Quit"));
        dialog.add_response ("play-again", _("Play _Again"));
        dialog.set_response_appearance ("play-again", Adw.ResponseAppearance.SUGGESTED);

        dialog.response.connect ((response_id) => {
            if (response_id == "play-again")
                show_new_game_screen ();
            else if (response_id == "close")
                quit ();
            dialog.destroy ();
        });

        dialog.present ();
    }

    private void start_custom_game (SudokuBoard board)
    {
        current_game_mode = GameMode.PLAY;
        game.stop_clock ();
        start_game (board);
    }

    private void start_game (SudokuBoard board)
    {
        if (current_game_mode == GameMode.PLAY)
            board.solve ();

        if (game != null)
        {
            game.paused_changed.disconnect (paused_changed_cb);
            game.cell_changed.disconnect (cell_changed_cb);
            game.board.completed.disconnect (board_completed_cb);
        }

        game = new SudokuGame (board);
        game.mode = current_game_mode;

        game.paused_changed.connect (paused_changed_cb);
        game.cell_changed.connect (cell_changed_cb);

        window.start_game (game, show_possibilities);

        print_action.set_enabled (true);
        undo_action.set_enabled (false);
        redo_action.set_enabled (false);
        new_game_action.set_enabled (true);

        clear_action.set_enabled (!game.is_empty ());
        play_custom_game_action.set_enabled (!game.is_empty ());

        if (current_game_mode != GameMode.CREATE)
            game.board.completed.connect (board_completed_cb);
    }

    private void show_new_game_screen ()
    {
        print_action.set_enabled (false);

        if (game != null)
            game.stop_clock ();

        window.show_new_game_screen ();
    }

    private void new_game_cb ()
    {
        show_new_game_screen ();
    }

    private void create_game_cb ()
    {
        current_game_mode = GameMode.CREATE;
        SudokuGenerator.generate_boards_async.begin (1, DifficultyCategory.CUSTOM, null, (obj, res) => {
            try
            {
                var gen_boards = SudokuGenerator.generate_boards_async.end (res);
                start_game (gen_boards[0]);
            }
            catch (Error e)
            {
                error ("Error: %s", e.message);
            }
        });
    }

    private void start_game_cb (SimpleAction action, Variant? difficulty)
    {
        window.will_start_game ();
        current_game_mode = GameMode.PLAY;

        // Since we cannot have enums in .ui file, the 'action-target' property
        // of new game buttons in data/gnome-sudoku.ui
        // has been set to integers corresponding to the enums.
        // Following line converts those ints to their DifficultyCategory
        var selected_difficulty = (DifficultyCategory) difficulty.get_int32 ();

        SudokuGenerator.generate_boards_async.begin (1, selected_difficulty, null, (obj, res) => {
            try
            {
                var gen_boards = SudokuGenerator.generate_boards_async.end (res);
                start_game (gen_boards[0]);
            }
            catch (Error e)
            {
                error ("Error: %s", e.message);
            }
        });
    }

    private void reset_cb ()
    {
        var dialog = new Adw.MessageDialog (window, _("Reset the board to its original state?"), null);
        dialog.add_response ("close", _("No"));
        dialog.add_response ("yes", _("Yes"));
        dialog.set_response_appearance ("yes", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.response["yes"].connect ((response_id) => {
            game.reset ();
            view.clear ();
            undo_action.set_enabled (false);
            redo_action.set_enabled (false);
            dialog.destroy ();
        });

        dialog.present ();
    }

    private void back_cb ()
    {
        window.show_game_view ();

        print_action.set_enabled (true);
    }

    private void undo_cb ()
    {
        if (!window.is_board_visible ())
            return;
        game.undo ();
        undo_action.set_enabled (!game.is_undostack_null ());
        view.redraw ();
    }

    private void redo_cb ()
    {
        if (!window.is_board_visible ())
            return;
        game.redo ();
        redo_action.set_enabled (!game.is_redostack_null ());
        view.redraw ();
    }

    private void print_cb ()
    {
        if (!window.is_board_visible ())
            return;
        print_action.set_enabled (false);
        print_multiple_action.set_enabled (false);

        var list = new Gee.ArrayList<SudokuBoard> ();
        list.add (game.board.clone ());
        var printer = new SudokuPrinter (list, 1, window);
        printer.print_sudoku ();

        print_action.set_enabled (true);
        print_multiple_action.set_enabled (true);
    }

    private void print_multiple_cb ()
    {
        var print_dialog = new PrintDialog (saver, window);
        print_dialog.show ();
    }

    private void help_cb ()
    {
        var launcher = new Gtk.UriLauncher ("help:gnome-sudoku");
        launcher.launch.begin (window, null, () => {});
    }

    private const string[] authors = { "Robert Ancell <robert.ancell@gmail.com>",
                                       "Christopher Baines <cbaines8@gmail.com>",
                                       "Thomas M. Hinkle <Thomas_Hinkle@alumni.brown.edu>",
                                       "Parin Porecha <parinporecha@gmail.com>",
                                       "John Stowers <john.stowers@gmail.com>",
                                       "Jamie Murphy <jmurphy@gnome.org>",
                                       null };

    private void about_cb ()
    {
        /* Appears on the About dialog. %s is the version of the QQwing puzzle generator in use. */
        var localized_comments_format = _("The popular Japanese logic puzzle\n\nPuzzles generated by QQwing %s");

        var about = new Adw.AboutWindow () {
            application_name = _("Sudoku"),
            application_icon = "org.gnome.Sudoku",
            version = VERSION,
            comments = localized_comments_format.printf (SudokuGenerator.qqwing_version ()),
            copyright = "Copyright © 2005–2008 Thomas M. Hinkle\nCopyright © 2010–2011 Robert Ancell\nCopyright © 2014 Parin Porecha\nCopyright © 2023 Jamie Murphy",
            license_type = License.GPL_3_0,
            developers = authors,
            translator_credits = _("translator-credits"),
            website = "https://wiki.gnome.org/Apps/Sudoku/",
        };

        about.set_transient_for (window);
        about.present ();
    }

    public static int main (string[] args)
    {
        return new Sudoku ().run (args);
    }
}

