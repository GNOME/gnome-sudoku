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

public class Sudoku : Gtk.Application
{
    private GLib.Settings settings;
    private bool is_maximized;
    private bool is_tiled;
    private int window_width;
    private int window_height;
    private Button play_custom_game_button;
    private Button play_pause_button;
    private Label play_pause_label;
    private Label clock_label;
    private Image clock_image;

    private ApplicationWindow window;

    private SudokuGame? game;
    private SudokuView? view;

    private HeaderBar headerbar;
    private Stack main_stack;
    private Box game_box; // Holds the view

    private Box undo_redo_box;
    private Button back_button;

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

        var highlighter_action = settings.create_action ("highlighter");
        highlighter_action.notify["state"].connect (() => {
            if (view != null)
                view.highlighter = settings.get_boolean ("highlighter");
        });
        add_action (highlighter_action);

        set_accels_for_action ("app.new-game", {"<Primary>n"});
        set_accels_for_action ("app.print", {"<Primary>p"});
        set_accels_for_action ("app.quit", {"<Primary>q"});
        set_accels_for_action ("app.reset", {"<Primary>r"});
        set_accels_for_action ("app.undo", {"<Primary>z"});
        set_accels_for_action ("app.redo", {"<Primary><Shift>z"});
        set_accels_for_action ("app.help", {"F1"});

        Window.set_default_icon_name ("org.gnome.Sudoku");

        var builder = new Builder.from_resource ("/org/gnome/Sudoku/ui/gnome-sudoku.ui");

        window = (ApplicationWindow) builder.get_object ("sudoku_app");
        window.size_allocate.connect (size_allocate_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        add_window (window);

        headerbar = (HeaderBar) builder.get_object ("headerbar");
        main_stack = (Stack) builder.get_object ("main_stack");
        game_box = (Box) builder.get_object ("game_box");
        undo_redo_box = (Box) builder.get_object ("undo_redo_box");
        back_button = (Button) builder.get_object ("back_button");
        clock_label = (Label) builder.get_object ("clock_label");
        clock_image = (Image) builder.get_object ("clock_image");
        play_custom_game_button = (Button) builder.get_object ("play_custom_game_button");
        play_pause_button = (Button) builder.get_object ("play_pause_button");
        play_pause_label = (Label) builder.get_object ("play_pause_label");

        undo_action = (SimpleAction) lookup_action ("undo");
        redo_action = (SimpleAction) lookup_action ("redo");
        new_game_action = (SimpleAction) lookup_action ("new-game");
        clear_action = (SimpleAction) lookup_action ("reset");
        print_action = (SimpleAction) lookup_action ("print");
        print_multiple_action = (SimpleAction) lookup_action ("print-multiple");
        pause_action = (SimpleAction) lookup_action ("pause");
        play_custom_game_action = (SimpleAction) lookup_action ("play-custom-game");

        headerbar.show_close_button = true;
        window.set_titlebar (headerbar);

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

        /* Save window state */
        settings.delay ();
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);
        settings.apply ();

        base.shutdown ();
    }

    private void size_allocate_cb (Allocation allocation)
    {
        if (is_maximized || is_tiled)
            return;
        window.get_size (out window_width, out window_height);
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        /* We don’t save this state, but track it for saving size allocation */
        if ((event.changed_mask & Gdk.WindowState.TILED) != 0)
            is_tiled = (event.new_window_state & Gdk.WindowState.TILED) != 0;
        return false;
    }

    private void paused_changed_cb ()
    {
        if (game.paused)
        {
            display_unpause_button ();
            clear_action.set_enabled (false);
            undo_action.set_enabled (false);
            redo_action.set_enabled (false);
            new_game_action.set_enabled (false);
        }
        else if (game.get_total_time_played () > 0)
        {
            display_pause_button ();
            clear_action.set_enabled (!game.is_empty ());
            undo_action.set_enabled (!game.is_undostack_null ());
            redo_action.set_enabled (!game.is_redostack_null ());
            new_game_action.set_enabled (true);
        }

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
            var error_str = "%s\n%s".printf(_("The puzzle you have entered is not a valid Sudoku."), _("Please enter a valid puzzle."));
            var dialog = new MessageDialog (window, DialogFlags.MODAL, MessageType.ERROR, ButtonsType.OK, error_str);

            dialog.run ();
            dialog.destroy ();
        }
        else
        {
            // Warning dialog shown when starting a custom game that has multiple solutions.
            var warning_str = "%s\n%s".printf(_("The puzzle you have entered has multiple solutions."), _("Valid Sudoku puzzles have exactly one solution."));
            var dialog = new MessageDialog (window, DialogFlags.MODAL, MessageType.WARNING, ButtonsType.NONE, warning_str);
            dialog.add_button (_("_Back"), ResponseType.REJECT);
            dialog.add_button (_("Play _Anyway"), ResponseType.ACCEPT);

            dialog.response.connect ((response_id) => {
                if (response_id == ResponseType.ACCEPT)
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

    private void tick_cb ()
    {
        var elapsed_time = (int) game.get_total_time_played ();
        var hours = elapsed_time / 3600;
        var minutes = (elapsed_time - hours * 3600) / 60;
        var seconds = elapsed_time - hours * 3600 - minutes * 60;
        if (hours > 0)
            clock_label.set_text ("%02d∶\xE2\x80\x8E%02d∶\xE2\x80\x8E%02d".printf (hours, minutes, seconds));
        else
            clock_label.set_text ("%02d∶\xE2\x80\x8E%02d".printf (minutes, seconds));
    }

    private void display_pause_button ()
    {
        play_pause_button.show ();
        play_pause_label.label = _("_Pause");
    }

    private void display_unpause_button ()
    {
        play_pause_button.show ();
        play_pause_label.label = _("_Resume");
    }

    private void start_custom_game (SudokuBoard board)
    {
        current_game_mode = GameMode.PLAY;
        game.stop_clock ();
        start_game (board);
    }

    private void start_game (SudokuBoard board)
    {
        if (view != null)
            game_box.remove (view);

        show_game_view ();
        game = new SudokuGame (board);
        game.mode = current_game_mode;

        undo_action.set_enabled (false);
        redo_action.set_enabled (false);
        set_headerbar_title ();
        clear_action.set_enabled (!game.is_empty ());
        play_custom_game_action.set_enabled (!game.is_empty ());

        game.tick.connect (tick_cb);
        game.paused_changed.connect (paused_changed_cb);
        game.start_clock ();

        view = new SudokuView (game);
        view.set_size_request (480, 480);

        view.show_possibilities = show_possibilities;
        if (current_game_mode == GameMode.CREATE)
            view.show_warnings = true;
        else
            view.show_warnings = settings.get_boolean ("show-warnings");
        view.highlighter = settings.get_boolean ("highlighter");

        view.show ();
        game_box.pack_start (view);

        game.cell_changed.connect (() => {
            undo_action.set_enabled (!game.is_undostack_null ());
            redo_action.set_enabled (!game.is_redostack_null ());
            clear_action.set_enabled (!game.is_empty ());
            play_custom_game_action.set_enabled (!game.is_empty () && !game.board.is_fully_filled ());
        });

        if (current_game_mode == GameMode.CREATE)
            return;

        game.board.completed.connect (() => {
            play_custom_game_button.visible = false;
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
            var dialog = new MessageDialog (window, DialogFlags.DESTROY_WITH_PARENT, MessageType.INFO, ButtonsType.NONE, time_str);

            dialog.add_button (_("_Quit"),       ResponseType.REJECT);
            dialog.add_button (_("Play _Again"), ResponseType.ACCEPT);

            dialog.response.connect ((response_id) => {
                if (response_id == ResponseType.ACCEPT)
                    show_new_game_screen ();
                else if (response_id == ResponseType.REJECT)
                    quit ();
                dialog.destroy ();
            });

            dialog.show ();
        });
    }

    private void show_new_game_screen ()
    {
        main_stack.set_visible_child_name ("start_box");
        back_button.visible = game != null;
        undo_redo_box.visible = false;
        headerbar.title = _("Select Difficulty");
        print_action.set_enabled (false);
        clock_label.hide ();
        clock_image.hide ();
        if (game != null)
            game.stop_clock ();
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
        // Since we cannot have enums in .ui file, the 'action-target' property
        // of new game buttons in data/gnome-sudoku.ui
        // has been set to integers corresponding to the enums.
        // Following line converts those ints to their DifficultyCategory
        var selected_difficulty = (DifficultyCategory) difficulty.get_int32 ();

        back_button.sensitive = false;
        current_game_mode = GameMode.PLAY;

        SudokuGenerator.generate_boards_async.begin (1, selected_difficulty, null, (obj, res) => {
            try
            {
                var gen_boards = SudokuGenerator.generate_boards_async.end (res);
                back_button.sensitive = true;
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
        var dialog = new MessageDialog (window, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.OK_CANCEL, _("Reset the board to its original state?"));

        dialog.response.connect ((response_id) => {
            if (response_id == ResponseType.OK)
            {
                game.reset ();
                view.clear ();
                undo_action.set_enabled (false);
                redo_action.set_enabled (false);
            }
            dialog.destroy ();
        });

        dialog.show ();
    }

    private void show_game_view ()
    {
        main_stack.set_visible_child_name ("frame");
        back_button.visible = false;
        undo_redo_box.visible = true;
        print_action.set_enabled (true);
        clock_label.show ();
        clock_image.show ();

        if (game != null)
            game.resume_clock ();

        if (current_game_mode == GameMode.PLAY)
        {
            play_custom_game_button.visible = false;
            play_pause_button.visible = true;
        }
        else
        {
            clock_label.hide ();
            clock_image.hide ();
            play_custom_game_button.visible = true;
            play_pause_button.visible = false;
        }
    }

    private void set_headerbar_title ()
    {
        if (current_game_mode == GameMode.PLAY)
            headerbar.title = game.board.difficulty_category.to_string ();
        else
            headerbar.title = _("Create Puzzle");
    }

    private void back_cb ()
    {
        show_game_view ();
        set_headerbar_title ();
    }

    private void undo_cb ()
    {
        if (main_stack.get_visible_child_name () != "frame")
            return;
        game.undo ();
        undo_action.set_enabled (!game.is_undostack_null ());
        view.hide_popovers ();
        view.queue_draw ();
    }

    private void redo_cb ()
    {
        if (main_stack.get_visible_child_name () != "frame")
            return;
        game.redo ();
        redo_action.set_enabled (!game.is_redostack_null ());
        view.hide_popovers ();
        view.queue_draw ();
    }

    private void print_cb ()
    {
        if (main_stack.get_visible_child_name () != "frame")
            return;
        print_action.set_enabled (false);
        print_multiple_action.set_enabled (false);

        var list = new Gee.ArrayList<SudokuBoard> ();
        list.add (game.board.clone ());
        var printer = new SudokuPrinter (list, window);
        printer.print_sudoku ();

        print_action.set_enabled (true);
        print_multiple_action.set_enabled (true);
    }

    private void print_multiple_cb ()
    {
        print_action.set_enabled (false);
        print_multiple_action.set_enabled (false);
        var print_dialog = new PrintDialog (saver, window);
        print_dialog.destroy.connect (() => {
            this.print_action.set_enabled (main_stack.get_visible_child_name () == "frame");
            this.print_multiple_action.set_enabled (true);
        });
        print_dialog.run ();
    }

    private void help_cb ()
    {
        try
        {
            show_uri_on_window (window, "help:gnome-sudoku", get_current_event_time ());
        }
        catch (GLib.Error e)
        {
            GLib.warning ("Unable to open help: %s", e.message);
        }
    }

    private const string[] authors = { "Robert Ancell <robert.ancell@gmail.com>",
                                       "Christopher Baines <cbaines8@gmail.com>",
                                       "Thomas M. Hinkle <Thomas_Hinkle@alumni.brown.edu>",
                                       "Parin Porecha <parinporecha@gmail.com>",
                                       "John Stowers <john.stowers@gmail.com>",
                                       null };

    private void about_cb ()
    {
        /* Appears on the About dialog. %s is the version of the QQwing puzzle generator in use. */
        var localized_comments_format = _("The popular Japanese logic puzzle\n\nPuzzles generated by QQwing %s");

        show_about_dialog (window,
                               "program-name", _("Sudoku"),
                               "logo-icon-name", "org.gnome.Sudoku",
                               "version", VERSION,
                               "comments", localized_comments_format.printf (SudokuGenerator.qqwing_version ()),
                               "copyright", "Copyright © 2005–2008 Thomas M. Hinkle\nCopyright © 2010–2011 Robert Ancell\nCopyright © 2014 Parin Porecha",
                               "license-type", License.GPL_3_0,
                               "authors", authors,
                               "artists", null,
                               "translator-credits", _("translator-credits"),
                               "website", "https://wiki.gnome.org/Apps/Sudoku/"
                               );
    }

    public static int main (string[] args)
    {
        return new Sudoku ().run (args);
    }
}
