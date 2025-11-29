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

    private SudokuWindow? window;

    private SudokuGameView game_view
    {
        get { return window.game_view; }
    }

    private SudokuGame game
    {
        get { return backend.game; }
    }

    private SimpleAction print_multiple_action;
    private SimpleAction new_game_action;
    private SimpleAction back_action;
    private SimpleAction zoom_in_action;
    private SimpleAction zoom_out_action;

    public static unowned Sudoku app;
    private SudokuBackend backend;

    public DifficultyCategory start_button_selected { get; set; }
    public ZoomLevel zoom_level { get; set; }
    public bool show_timer { get; set; }
    public bool earmark_mode { get; set; default = false; }
    public bool show_possibilities { get; set; }
    public bool highlight_row_column { get; set; }
    public bool highlight_block { get; set; }
    public bool highlight_numbers { get; set; }
    public bool duplicate_warnings { get; set; }
    public bool solution_warnings { get; set; }
    public bool earmark_warnings { get; set; }
    public bool autoclean_earmarks { get; set; }
    public bool number_picker_second_click { get; set; }

    private const GLib.ActionEntry action_entries[] =
    {
        {"new-game", new_game_cb                                    },
        {"start-game", start_game_cb, "i"                           },
        {"back", back_cb                                            },
        {"print-multiple", print_multiple_cb                        },
        {"help", help_cb                                            },
        {"about", about_cb                                          },
        {"toggle-fullscreen", toggle_fullscreen_cb                  },
        {"zoom-in", zoom_in_cb, null, "false"                       },
        {"zoom-out", zoom_out_cb, null, "false"                     },
        {"zoom-reset", zoom_reset_cb                                },
        {"shortcuts-dialog", shortcuts_dialog_cb                    },
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
        backend = new SudokuBackend ();
        app = this;

        base.startup ();

        settings = new GLib.Settings ("org.gnome.Sudoku");

        settings.bind ("start-button-selected", this, "start-button-selected", SettingsBindFlags.DEFAULT);
        settings.bind ("zoom-level", this, "zoom-level", SettingsBindFlags.DEFAULT);
        settings.bind ("show-timer", this, "show-timer", SettingsBindFlags.DEFAULT);
        settings.bind ("show-possibilities", this, "show-possibilities", SettingsBindFlags.DEFAULT);
        settings.bind ("autoclean-earmarks", this, "autoclean-earmarks", SettingsBindFlags.DEFAULT);
        settings.bind ("number-picker-second-click", this, "number-picker-second-click", SettingsBindFlags.DEFAULT);
        settings.bind ("duplicate-warnings", this, "duplicate-warnings", SettingsBindFlags.DEFAULT);
        settings.bind ("solution-warnings", this, "solution-warnings", SettingsBindFlags.DEFAULT);
        settings.bind ("earmark-warnings", this, "earmark-warnings", SettingsBindFlags.DEFAULT);
        settings.bind ("highlight-row-column", this, "highlight-row-column", SettingsBindFlags.DEFAULT);
        settings.bind ("highlight-block", this, "highlight-block", SettingsBindFlags.DEFAULT);
        settings.bind ("highlight-numbers", this, "highlight-numbers", SettingsBindFlags.DEFAULT);

        //backwards compatibility for versions <= v49
        var old_warnings_enabled = settings.get_boolean ("show-warnings");
        if (!old_warnings_enabled)
        {
            settings.reset ("show-warnings");
            duplicate_warnings = false;
            solution_warnings = false;
            earmark_warnings = false;
        }

        var old_selected_button = (DifficultyCategory) settings.get_enum ("play-difficulty");
        if (old_selected_button != DifficultyCategory.EASY)
        {
            settings.reset ("play-difficulty");
            start_button_selected = old_selected_button;
        }

        add_action_entries (action_entries, this);

        set_accels_for_action ("app.new-game", {"<Primary>n"});
        set_accels_for_action ("app.quit", {"<Primary>q"});
        set_accels_for_action ("app.help", {"F1"});
        set_accels_for_action ("app.shortcuts-dialog", {"<Primary>question"});
        set_accels_for_action ("app.preferences-dialog", {"<Primary>comma"});
        set_accels_for_action ("app.toggle-fullscreen", {"F11", "f"});
        set_accels_for_action ("app.zoom-in", {"<Primary>plus", "<Primary>equal", "ZoomIn", "<Primary>KP_Add"});
        set_accels_for_action ("app.zoom-out", {"<Primary>minus", "ZoomOut", "<Primary>KP_Subtract"});
        set_accels_for_action ("app.zoom-reset", {"<Primary>0", "<Primary>KP_0"});

        new_game_action = lookup_action ("new-game") as SimpleAction;
        print_multiple_action = lookup_action ("print-multiple") as SimpleAction;
        back_action = lookup_action ("back") as SimpleAction;
        zoom_in_action = lookup_action ("zoom-in") as SimpleAction;
        zoom_out_action = lookup_action ("zoom-out") as SimpleAction;

        zoom_in_action.set_enabled (!zoom_level.is_fully_zoomed_in ());
        zoom_out_action.set_enabled (!zoom_level.is_fully_zoomed_out ());

        Window.set_default_icon_name (APP_ID);
    }

    protected override void activate ()
    {
        if (window == null)
        {
            window = new SudokuWindow (backend, settings);
            add_window (window);

            if (backend.game != null)
                init_game_view ();
            else
                show_start_view ();
        }

        window.present ();
    }

    protected override void shutdown ()
    {
        if (window != null)
            window.close ();

        base.shutdown ();
    }

    private void board_completed_cb ()
    {
        game.board.completed.disconnect (board_completed_cb);
        backend.add_game_to_finished (Sudoku.app.show_timer);

        /* Text in dialog that displays when the game is over. */
        string win_str = _("Puzzle Completed!");
        if (show_timer)
        {
            var highscore_changed = backend.save_highscore ();

            if (window.width_is_small)
            {
                var minutes = (int) game.get_total_time_played () / 60;
                string localized_time =  ngettext ("%d minute", "%d minutes", minutes).printf (minutes);

                if (highscore_changed)
                {
                    win_str = _(//TRANSLATORS: %s is a localized time string in minute(s)
                                "Well done, you completed the puzzle in %s and set a new personal best!")
                                .printf(localized_time);
                }
                else
                {
                    win_str = _(//TRANSLATORS: %s is a localized time string in minute(s)
                                "Well done, you completed the puzzle in %s!")
                                .printf(localized_time);
                }
            }
        }

        var dialog = new Adw.AlertDialog (win_str, null);
        dialog.add_response ("quit", _("_Quit"));
        if (start_button_selected != DifficultyCategory.CUSTOM)
        {
            dialog.add_response ("start-menu", _("_Change Difficulty"));
            dialog.add_response ("play-again", _("_Play Again"));
            dialog.set_response_appearance ("play-again", Adw.ResponseAppearance.SUGGESTED);
        }
        else
        {
            dialog.add_response ("start-menu", _("_New Game…"));
            dialog.set_response_appearance ("start-menu", Adw.ResponseAppearance.SUGGESTED);
        }

        dialog.response.connect ((response_id) => {
            switch (response_id)
            {
                case "start-menu":
                    show_start_view ();
                    break;
                case "play-again":
                    create_game ();
                    break;
                case "quit":
                    quit ();
                    break;
                case "close":
                    show_start_view ();
                    break;
            }

            dialog.destroy ();
        });

        dialog.present (window);
    }

    private void create_game ()
    {
        backend.generate_game (start_button_selected, (obj) => {
            if (!game_view.initialized)
                init_game_view ();
            else
                change_board ();
        });
    }

    public void init_game_view ()
    {
        game_view.init (backend, window);
        game.bind_property ("paused", new_game_action, "enabled", BindingFlags.DEFAULT | BindingFlags.INVERT_BOOLEAN);
        game.board.completed.connect (board_completed_cb);
        show_game_view ();
    }

    public void change_board ()
    {
        game_view.change_board ();
        show_game_view ();
        game.board.completed.connect (board_completed_cb);
    }

    private void show_start_view ()
    {
        if (game != null && game.board.complete != true)
            game.stop_clock ();

        new_game_action.set_enabled (false);
        window.show_start_view ();
    }

    private void show_game_view ()
    {
        new_game_action.set_enabled (true);
        window.show_game_view ();
    }

    private void new_game_cb ()
    {
        show_start_view ();
    }

    private void start_game_cb (SimpleAction action, Variant? difficulty)
    {
        // Since we cannot have enums in .ui file, the 'action-target' property
        // of new game buttons in blueprints/start-view.blp
        // has been set to integers corresponding to the enums.
        // Following line converts those ints to their DifficultyCategory
        start_button_selected = (DifficultyCategory) difficulty;
        create_game ();
    }

    private void back_cb ()
    {
        if (game == null || game.board.complete == true)
            return;

        show_game_view ();

        if (window.current_screen == SudokuWindowScreen.PLAY)
            game.resume_clock ();
    }

    private void print_multiple_cb ()
    {
        var print_dialog = new SudokuPrintDialog (backend, window);
        print_dialog.present (window);
    }

    private void preferences_dialog_cb ()
    {
        var preferences_dialog = new SudokuPreferencesDialog ();
        preferences_dialog.present (window);
    }

    private void shortcuts_dialog_cb ()
    {
        var builder = new Gtk.Builder.from_resource ("/org/gnome/Sudoku/ui/shortcuts-dialog.ui");
        var shortcuts_dialog = builder.get_object ("SudokuShortcutsDialog") as Adw.ShortcutsDialog;
        shortcuts_dialog.present (window);
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
        var about_dialog = new Adw.AboutDialog.from_appdata ("/org/gnome/Sudoku/metainfo.xml", VERSION);
        about_dialog.set_version (VERSION);
        about_dialog.set_copyright ("Copyright © 2005–2008 Thomas M. Hinkle\nCopyright © 2010–2011 Robert Ancell\nCopyright © 2014 Parin Porecha\nCopyright © 2023 Jamie Murphy\nCopyright © 2024-2025 Johan Gay");
        about_dialog.set_developers (authors);
        about_dialog.set_translator_credits (_("translator-credits"));
        about_dialog.present (window);
    }

    private void toggle_fullscreen_cb ()
    {
        window.fullscreened = !window.fullscreened;
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
