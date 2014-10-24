/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2014 Parin Porecha
 * Copyright © 2014 Michael Catanzaro
 *
 * This file is part of GNOME Sudoku.
 *
 * GNOME Sudoku is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
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
    private int window_width;
    private int window_height;

    private ApplicationWindow window;

    // The current game and view, if they exist
    private SudokuGame game;
    private SudokuView view;

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

    private bool show_possibilities = false;

    private string? desktop;

    private const GLib.ActionEntry action_entries[] =
    {
        {"new-game", new_game_cb                                    },
        {"start-game", start_game_cb, "i"                           },
        {"reset", reset_cb                                          },
        {"back", back_cb                                            },
        {"undo", undo_cb                                            },
        {"redo", redo_cb                                            },
        {"print", print_cb                                          },
        {"print-multiple", print_multiple_cb                        },
        {"help", help_cb                                            },
        {"about", about_cb                                          },
        {"quit", quit                                               }
    };

    private static const OptionEntry[] option_entries =
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

        Object (application_id: "org.gnome.sudoku", flags: ApplicationFlags.FLAGS_NONE);
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

    private bool is_desktop (string name)
    {
        var desktop_name_list = Environment.get_variable ("XDG_CURRENT_DESKTOP");
        if (desktop_name_list == null)
            return false;

        foreach (var n in desktop_name_list.split (":"))
            if (n == name)
                return true;

        return false;
    }

    protected override void startup ()
    {
        base.startup ();

        add_action_entries (action_entries, this);

        settings = new GLib.Settings ("org.gnome.sudoku");
        var action = settings.create_action ("show-warnings");
        action.notify["state"].connect (() =>
            view.show_warnings = settings.get_boolean ("show-warnings"));
        add_action (action);

        set_accels_for_action ("app.new-game", {"<Primary>n"});
        set_accels_for_action ("app.print", {"<Primary>p"});
        set_accels_for_action ("app.quit", {"<Primary>q"});
        set_accels_for_action ("app.reset", {"<Primary>r"});
        set_accels_for_action ("app.undo", {"<Primary>z"});
        set_accels_for_action ("app.redo", {"<Primary><Shift>z"});
        set_accels_for_action ("app.help", {"F1"});

        Window.set_default_icon_name ("gnome-sudoku");

        var css_provider = new CssProvider ();
        css_provider.load_from_resource ("/org/gnome/sudoku/ui/gnome-sudoku.css");
        StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        var builder = new Builder.from_resource ("/org/gnome/sudoku/ui/gnome-sudoku.ui");

        window = (ApplicationWindow) builder.get_object ("sudoku_app");
        window.configure_event.connect (window_configure_event_cb);
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

        undo_action = (SimpleAction) lookup_action ("undo");
        redo_action = (SimpleAction) lookup_action ("redo");
        clear_action = (SimpleAction) lookup_action ("reset");
        print_action = (SimpleAction) lookup_action ("print");
        print_multiple_action = (SimpleAction) lookup_action ("print-multiple");

        if (!is_desktop ("Unity"))
        {
            headerbar.show_close_button = true;
            window.set_titlebar (headerbar);
        }
        else
        {
            var vbox = (Box) builder.get_object ("vbox");
            vbox.pack_start (headerbar, false, false, 0);
        }

        saver = new SudokuSaver ();
        var savegame = saver.get_savedgame ();
        if (savegame != null)
            start_game (savegame.board);
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
            if (!game.board.is_empty () && !game.board.complete)
                saver.save_game (game);

            if (game.board.is_empty () && saver.get_savedgame () != null)
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
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);

        base.shutdown ();
    }

    private bool window_configure_event_cb (Gdk.EventConfigure event)
    {
        if (!is_maximized)
        {
            window_width = event.width;
            window_height = event.height;
        }

        return false;
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        return false;
    }

    private void start_game (SudokuBoard board)
    {
        undo_action.set_enabled (false);
        redo_action.set_enabled (false);

        if (view != null)
            game_box.remove (view);

        if (desktop == null || desktop != "Unity")
            headerbar.subtitle = board.difficulty_category.to_string ();
        else
            headerbar.title = board.difficulty_category.to_string ();
        headerbar.visible = true;

        game = new SudokuGame (board);
        back_cb ();

        game.timer.start ();

        view = new SudokuView (game);
        view.set_size_request (480, 480);

        view.show_possibilities = show_possibilities;
        view.show_warnings = settings.get_boolean ("show-warnings");

        view.show ();
        game_box.pack_start (view);

        game.cell_changed.connect (() => {
            undo_action.set_enabled (!game.is_undostack_null ());
            redo_action.set_enabled (!game.is_redostack_null ());
            clear_action.set_enabled (!game.board.is_empty ());
        });

        game.board.completed.connect (() => {
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

            dialog.add_button (_("Play _Again"), Gtk.ResponseType.ACCEPT);
            dialog.add_button (_("_Quit"), Gtk.ResponseType.REJECT);

            dialog.response.connect ((response_id) => {
                if (response_id == Gtk.ResponseType.ACCEPT)
                    show_new_game_screen ();
                else if (response_id == Gtk.ResponseType.REJECT)
                    quit ();
                dialog.destroy ();
            });

            dialog.show ();
        });
    }

    private void show_new_game_screen ()
    {
        main_stack.set_visible_child_name ("start_box");
        clear_action.set_enabled (false);
        back_button.visible = game != null;
        undo_redo_box.visible = false;
        print_action.set_enabled (false);

        if (desktop == null || desktop != "Unity")
            headerbar.subtitle = null;
        else
            headerbar.visible = false;
    }

    private void new_game_cb ()
    {
        show_new_game_screen ();
    }

    private void start_game_cb (SimpleAction action, Variant? difficulty)
    {
        // Since we cannot have enums in .ui file, the 'action-target' property
        // of new game buttons in data/gnome-sudoku.ui
        // has been set to integers corresponding to the enums.
        // Following line converts those ints to their DifficultyCategory
        var selected_difficulty = (DifficultyCategory) difficulty.get_int32 ();

        back_button.sensitive = false;

        SudokuGenerator.generate_boards_async.begin (1, selected_difficulty, (obj, res) => {
            try {
                var gen_boards = SudokuGenerator.generate_boards_async.end (res);
                back_button.sensitive = true;
                start_game (gen_boards[0]);
            } catch (ThreadError e) {
                error ("Thread error: %s", e.message);
            }
        });
    }

    private void reset_cb ()
    {
        var dialog = new MessageDialog (window, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.OK_CANCEL, _("Reset the board to its original state?"));

        dialog.response.connect ((response_id) => {
            if (response_id == ResponseType.OK)
            {
                view.clear ();
                game.reset ();
                undo_action.set_enabled (false);
                redo_action.set_enabled (false);
            }
            dialog.destroy ();
        });

        dialog.show ();
    }

    private void back_cb ()
    {
        main_stack.set_visible_child_name ("frame");
        clear_action.set_enabled (!game.board.is_empty ());
        back_button.visible = false;
        undo_redo_box.visible = true;
        print_action.set_enabled (true);

        if (desktop == null || desktop != "Unity")
            headerbar.subtitle = game.board.difficulty_category.to_string ();
        else
            headerbar.title = game.board.difficulty_category.to_string ();
    }

    private void undo_cb ()
    {
        if (main_stack.get_visible_child_name () != "frame")
            return;
        game.undo ();
        undo_action.set_enabled (!game.is_undostack_null ());
        view.queue_draw ();
    }

    private void redo_cb ()
    {
        if (main_stack.get_visible_child_name () != "frame")
            return;
        game.redo ();
        redo_action.set_enabled (!game.is_redostack_null ());
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
        var printer = new SudokuPrinter (list, (Window) window);
        printer.print_sudoku ();

        print_action.set_enabled (true);
        print_multiple_action.set_enabled (true);
    }

    private void print_multiple_cb ()
    {
        print_action.set_enabled (false);
        print_multiple_action.set_enabled (false);
        var print_dialog = new PrintDialog (saver, window);
        print_dialog.finished.connect (() => {
            print_dialog.destroy ();
            this.print_action.set_enabled (main_stack.get_visible_child_name () == "frame");
            this.print_multiple_action.set_enabled (true);
        });
        print_dialog.run ();
    }

    private void help_cb ()
    {
        try
        {
            show_uri (window.get_screen (), "help:gnome-sudoku", get_current_event_time ());
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
        show_about_dialog (window,
                               "program-name", _("Sudoku"),
                               "logo-icon-name", "gnome-sudoku",
                               "version", VERSION,
                               /* Appears on the About dialog. %s is the version of the QQwing puzzle generator in use. */
                               "comments", _("The popular Japanese logic puzzle\n\nPuzzles generated by QQwing %s".printf (SudokuGenerator.qqwing_version ())),
                               "copyright", "Copyright © 2005–2008 Thomas M. Hinkle\nCopyright © 2010–2011 Robert Ancell\nCopyright © 2014 Parin Porecha",
                               "license-type", License.GPL_2_0,
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
