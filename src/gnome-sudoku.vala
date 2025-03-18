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

// https://gitlab.gnome.org/GNOME/gtk/-/issues/6135
namespace Workaround {
    [CCode (cheader_filename = "gtk/gtk.h", cname = "gtk_show_uri")]
    extern static void gtk_show_uri (Gtk.Window? parent, string uri, uint32 timestamp);
}

public class Sudoku : Adw.Application
{
    private GLib.Settings settings;

    private SudokuWindow window;

    private SudokuGameView view
    {
        get { return window.view; }
    }

    private SudokuGame game
    {
        get { return view.game; }
    }

    private SudokuSaver saver;

    private SimpleAction undo_action;
    private SimpleAction redo_action;
    private SimpleAction reset_board_action;
    private SimpleAction print_current_board_action;
    private SimpleAction print_multiple_action;
    private SimpleAction toggle_pause_action;
    private SimpleAction play_custom_game_action;
    private SimpleAction new_game_action;
    private SimpleAction earmark_mode_action;
    private SimpleAction zoom_in_action;
    private SimpleAction zoom_out_action;

    public static unowned Sudoku app;

    public DifficultyCategory play_difficulty { get; set; }
    public ZoomLevel zoom_level { get; set; }
    public bool show_timer { get; set; }
    public bool earmark_mode { get; set; default = false; }
    public bool show_possibilities { get; set; }
    public bool highlighter { get; set; }
    public bool highlight_row_column { get; set; }
    public bool highlight_block { get; set; }
    public bool highlight_numbers { get; set; }
    public bool show_warnings { get; set; }
    public bool solution_warnings { get; set; }
    public bool earmark_warnings { get; set; }
    public bool autoclean_earmarks { get; set; }
    public bool number_picker_second_click { get; set; }

    private const GLib.ActionEntry action_entries[] =
    {
        {"new-game", new_game_cb                                    },
        {"start-game", start_game_cb, "i"                           },
        {"create-game", create_game_cb                              },
        {"reset-board", reset_board_cb                              },
        {"back", back_cb                                            },
        {"undo", undo_cb                                            },
        {"redo", redo_cb                                            },
        {"print-current-board", print_current_board_cb              },
        {"play-custom-game", play_custom_game_cb                    },
        {"toggle-pause", toggle_pause_cb                            },
        {"print-multiple", print_multiple_cb                        },
        {"help", help_cb                                            },
        {"about", about_cb                                          },
        {"toggle-fullscreen", toggle_fullscreen_cb                  },
        {"zoom-in", zoom_in_cb, null, "false"                       },
        {"zoom-out", zoom_out_cb, null, "false"                     },
        {"zoom-reset", zoom_reset_cb                                },
        {"earmark-mode", earmark_mode_cb, null, "false"             },
        {"shortcuts-window", shortcuts_window_cb                    },
        {"preferences-dialog", preferences_dialog_cb                },
        {"quit", quit                                               }
    };

    private const OptionEntry[] option_entries =
    {
        { "version", 'v', 0, OptionArg.NONE, null,
        /* Help string for command line --version flag */
        N_("Show release version"), null},

        { null }
    };

    public Sudoku ()
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Object (application_id: APP_ID, flags: ApplicationFlags.DEFAULT_FLAGS, resource_base_path: "/org/gnome/Sudoku");
        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* Not translated so can be easily parsed */
            stderr.printf ("gnome-sudoku %s\n", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        /* Activate */
        return -1;
    }

    protected override void startup ()
    {
        app = this;

        base.startup ();

        settings = new GLib.Settings ("org.gnome.Sudoku");

        settings.bind ("play-difficulty", this, "play-difficulty", SettingsBindFlags.DEFAULT);
        settings.bind ("zoom-level", this, "zoom-level", SettingsBindFlags.DEFAULT);
        settings.bind ("show-timer", this, "show-timer", SettingsBindFlags.DEFAULT);
        settings.bind ("show-possibilities", this, "show-possibilities", SettingsBindFlags.DEFAULT);
        settings.bind ("highlighter", this, "highlighter", SettingsBindFlags.DEFAULT);
        settings.bind ("highlight-row-column", this, "highlight-row-column", SettingsBindFlags.DEFAULT);
        settings.bind ("highlight-block", this, "highlight-block", SettingsBindFlags.DEFAULT);
        settings.bind ("highlight-numbers", this, "highlight-numbers", SettingsBindFlags.DEFAULT);
        settings.bind ("show-warnings", this, "show-warnings", SettingsBindFlags.DEFAULT);
        settings.bind ("solution-warnings", this, "solution-warnings", SettingsBindFlags.DEFAULT);
        settings.bind ("earmark-warnings", this, "earmark-warnings", SettingsBindFlags.DEFAULT);
        settings.bind ("autoclean-earmarks", this, "autoclean-earmarks", SettingsBindFlags.DEFAULT);
        settings.bind ("number-picker-second-click", this, "number-picker-second-click", SettingsBindFlags.DEFAULT);

        add_action_entries (action_entries, this);

        var action = settings.create_action ("show-warnings");
        add_action (action);
        action = settings.create_action ("highlighter");
        add_action (action);

        set_accels_for_action ("app.quit", {"<Primary>q"});
        set_accels_for_action ("app.help", {"F1"});

        undo_action = (SimpleAction) lookup_action ("undo");
        redo_action = (SimpleAction) lookup_action ("redo");
        earmark_mode_action = (SimpleAction) lookup_action ("earmark-mode");
        new_game_action = (SimpleAction) lookup_action ("new-game");
        reset_board_action = (SimpleAction) lookup_action ("reset-board");
        print_current_board_action = (SimpleAction) lookup_action ("print-current-board");
        print_multiple_action = (SimpleAction) lookup_action ("print-multiple");
        toggle_pause_action = (SimpleAction) lookup_action ("toggle-pause");
        play_custom_game_action = (SimpleAction) lookup_action ("play-custom-game");
        zoom_in_action = (SimpleAction) lookup_action ("zoom-in");
        zoom_out_action = (SimpleAction) lookup_action ("zoom-out");
        zoom_in_action.set_enabled (!zoom_level.is_fully_zoomed_in ());
        zoom_out_action.set_enabled (!zoom_level.is_fully_zoomed_out ());

        Window.set_default_icon_name (APP_ID);

        window = new SudokuWindow (settings);
        add_window (window);

        saver = new SudokuSaver ();
        var savegame = saver.get_savedgame ();
        if (savegame != null)
            start_game (savegame.board);
        else
            show_menu_screen ();
    }

    protected override void activate ()
    {
        window.present ();
    }

    protected override void shutdown ()
    {
        if (view != null)
        {
            if (!game.is_empty () && !game.board.complete)
                saver.save_game (game);
            else
                saver.delete_save ();
        }

        window.close ();
        base.shutdown ();
    }

    private void paused_cb ()
    {
        if (game.paused)
        {
            reset_board_action.set_enabled (false);
            undo_action.set_enabled (false);
            redo_action.set_enabled (false);
            new_game_action.set_enabled (false);
            game.stop_clock ();
        }
        else
        {
            reset_board_action.set_enabled (!game.is_empty ());
            undo_action.set_enabled (!game.is_undostack_null ());
            redo_action.set_enabled (!game.is_redostack_null ());
            new_game_action.set_enabled (true);
            game.resume_clock ();
        }

        view.queue_draw ();
    }

    private void play_custom_game_cb ()
    {
        int solutions = game.board.count_solutions_limited ();
        if (solutions == 1)
            start_custom_game ();
        else if (solutions == 0)
        {
            // Error dialog shown when starting a custom game that is not valid.
            var dialog = new Adw.AlertDialog (_("The puzzle you have entered is not a valid Sudoku."), _("Please enter a valid puzzle."));
            dialog.add_response ("close", _("Close"));

            dialog.response.connect (() => dialog.destroy ());
            dialog.present (window);
        }
        else
        {
            // Warning dialog shown when starting a custom game that has multiple solutions.
            var dialog = new Adw.AlertDialog (_("The puzzle you have entered has multiple solutions."), _("Valid Sudoku puzzles have exactly one solution."));
            dialog.add_response ("close", _("_Back"));
            dialog.add_response ("continue", _("Play _Anyway"));
            dialog.set_response_appearance ("continue", Adw.ResponseAppearance.DESTRUCTIVE);

            dialog.response["continue"].connect (() => {
                start_custom_game ();
                dialog.destroy ();
            });

            dialog.present (window);
        }
    }

    private void toggle_pause_cb ()
    {
        if (window.current_screen == SudokuWindowScreen.PLAY && show_timer)
            game.paused = !game.paused;
    }

    private void action_completed_cb ()
    {
        undo_action.set_enabled (!game.is_undostack_null ());
        redo_action.set_enabled (!game.is_redostack_null ());
        reset_board_action.set_enabled (!game.is_empty ());
        play_custom_game_action.set_enabled (!game.is_empty () && !game.board.is_fully_filled ());
    }

    private void board_completed_cb ()
    {
        game.stop_clock ();

        saver.add_game_to_finished (game, true, show_timer);

        /* Text in dialog that displays when the game is over. */
        string win_str;
        if (show_timer)
        {
            var minutes = int.max (1, (int) game.get_total_time_played () / 60);
            win_str = ngettext ("Well done, you completed the puzzle in %d minute!",
                                "Well done, you completed the puzzle in %d minutes!",
                                minutes).printf (minutes);
        }
        else
            win_str = gettext ("Well done, you completed the puzzle!");

        var dialog = new Adw.AlertDialog (win_str, null);
        dialog.add_response ("close", _("Quit"));
        dialog.add_response ("play-again", _("Play _Again"));
        dialog.set_response_appearance ("play-again", Adw.ResponseAppearance.SUGGESTED);

        dialog.response.connect ((response_id) => {
            if (response_id == "play-again")
                start_game_async ();
            else if (response_id == "close")
                quit ();
            dialog.destroy ();
        });

        dialog.present (window);
    }

    private void start_custom_game ()
    {
        game.board.set_all_is_fixed ();
        start_game (game.board);
    }

    private void start_game (SudokuBoard board)
    {
        if (view == null)
        {
            window.start_game (board);
            game.action_completed.connect (action_completed_cb);
            game.notify["paused"].connect (paused_cb);
        }
        else
            game.change_board (board);

        print_current_board_action.set_enabled (true);
        undo_action.set_enabled (!game.is_undostack_null ());
        redo_action.set_enabled (!game.is_redostack_null ());
        new_game_action.set_enabled (true);
        earmark_mode_action.set_enabled (game.mode == GameMode.PLAY);
        reset_board_action.set_enabled (!game.is_empty ());
        play_custom_game_action.set_enabled (!game.is_empty ());

        if (game.mode != GameMode.CREATE)
            game.board.completed.connect (board_completed_cb);
        else
            game.board.completed.disconnect (board_completed_cb);
    }

    private void show_menu_screen ()
    {
        if (view != null)
            game.stop_clock ();

        print_current_board_action.set_enabled (false);
        new_game_action.set_enabled (false);
        reset_board_action.set_enabled (false);

        window.show_menu_screen ();
        window.activate_difficulty_checkbutton (play_difficulty);
    }

    private void new_game_cb ()
    {
        show_menu_screen ();
    }

    private void create_game_cb ()
    {
        play_difficulty = DifficultyCategory.CUSTOM;
        start_game_async ();
    }

    private void start_game_cb (SimpleAction action, Variant? difficulty)
    {
        // Since we cannot have enums in .ui file, the 'action-target' property
        // of new game buttons in data/gnome-sudoku.ui
        // has been set to integers corresponding to the enums.
        // Following line converts those ints to their DifficultyCategory
        play_difficulty = (DifficultyCategory) difficulty.get_int32 ();
        start_game_async ();
    }

    private void start_game_async ()
    {
        SudokuGenerator.generate_boards_async.begin (1, play_difficulty, null, (obj, res) => {
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

    private void reset_board_cb ()
    {
        if (window.current_screen != SudokuWindowScreen.MENU)
            game.reset ();
    }

    private void back_cb ()
    {
        if (window.current_screen != SudokuWindowScreen.MENU)
            return;

        window.show_game_view ();
        if (window.current_screen == SudokuWindowScreen.PLAY)
            game.resume_clock ();

        print_current_board_action.set_enabled (true);
        new_game_action.set_enabled (true);
        reset_board_action.set_enabled (!game.is_empty ());
    }

    private void undo_cb ()
    {
        if (window.current_screen != SudokuWindowScreen.MENU)
            game.undo ();
    }

    private void redo_cb ()
    {
        if (window.current_screen != SudokuWindowScreen.MENU)
            game.redo ();
    }

    private void earmark_mode_cb ()
    {
        if (window.current_screen == SudokuWindowScreen.PLAY)
        {
            earmark_mode = !earmark_mode;
            earmark_mode_action.set_state (earmark_mode);
        }
    }

    private void print_current_board_cb ()
    {
        if (!window.is_board_visible ())
            return;
        print_current_board_action.set_enabled (false);
        print_multiple_action.set_enabled (false);

        var list = new Gee.ArrayList<SudokuBoard> ();
        list.add (game.board.clone ());
        var printer = new SudokuPrinter (list, 1, window);
        printer.print_sudoku ();

        print_current_board_action.set_enabled (true);
        print_multiple_action.set_enabled (true);
    }

    private void print_multiple_cb ()
    {
        var print_dialog = new SudokuPrintDialog (saver, window);
        print_dialog.present (window);
    }

    private void preferences_dialog_cb ()
    {
        var preferences_dialog = new SudokuPreferencesDialog ();
        preferences_dialog.present (window);
    }

    private void shortcuts_window_cb ()
    {
        var builder = new Gtk.Builder.from_resource ("/org/gnome/Sudoku/ui/shortcuts-window.ui");
        var shortcuts_window = builder.get_object ("shortcuts-window") as ShortcutsWindow;

        if (view != null)
        {
            if (!game.paused)
                game.stop_clock ();

            window.view.unselect ();

            shortcuts_window.close_request.connect(() => {
                if (!game.paused)
                    game.resume_clock ();

                if (window.view != null)
                    window.view.grab_focus ();
                return Gdk.EVENT_PROPAGATE;
            });
        }

        shortcuts_window.set_transient_for (window);
        shortcuts_window.present ();
    }

    private void help_cb ()
    {
        Workaround.gtk_show_uri (window, "help:gnome-sudoku", Gdk.CURRENT_TIME);
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
        var about_dialog = new Adw.AboutDialog.from_appdata ("/org/gnome/Sudoku/metainfo.xml", VERSION);
        about_dialog.set_version (VERSION);
        about_dialog.set_comments (localized_comments_format.printf (SudokuGenerator.qqwing_version ()));
        about_dialog.set_copyright ("Copyright © 2005–2008 Thomas M. Hinkle\nCopyright © 2010–2011 Robert Ancell\nCopyright © 2014 Parin Porecha\nCopyright © 2023 Jamie Murphy\nCopyright © 2024 Johan Gay");
        about_dialog.set_developers (authors);
        about_dialog.set_translator_credits (_("translator-credits"));
        about_dialog.present (window);
    }

    private void toggle_fullscreen_cb ()
    {
        if (window.is_fullscreen ())
            window.unfullscreen ();
        else
            window.fullscreen ();
    }

    private void zoom_in_cb ()
    {
        zoom_level = zoom_level.zoom_in ();
        if (zoom_level.is_fully_zoomed_in ())
            zoom_in_action.set_enabled (false);

        zoom_out_action.set_enabled (true);
    }

    private void zoom_out_cb ()
    {
        zoom_level = zoom_level.zoom_out ();
        if (zoom_level.is_fully_zoomed_out ())
            zoom_out_action.set_enabled (false);

        zoom_in_action.set_enabled (true);
    }

    private void zoom_reset_cb ()
    {
        settings.reset ("zoom-level");
        zoom_in_action.set_enabled (true);
        zoom_out_action.set_enabled (true);
    }

    public static int main (string[] args)
    {
        return new Sudoku ().run (args);
    }
}
