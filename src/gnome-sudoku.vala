/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gtk;
using Gee;
using Gdk;

public class Sudoku : Gtk.Application
{
    private GLib.Settings settings;

    private Builder builder;

    private ApplicationWindow window;

    // The current game and view, if they exist
    private SudokuGame game;
    private SudokuView view;

    private HeaderBar header_bar;
    private Stack main_stack;
    private Box grid_box; // Holds the view

    private Box undo_redo_box;
    private Button back_button;

    private SudokuStore sudoku_store;
    private SudokuSaver saver;

    private SimpleAction undo_action;
    private SimpleAction redo_action;
    private SimpleAction clear_action;
    private SimpleAction print_action;

    private string header_bar_subtitle;

    private bool show_possibilities = false;

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
        {"quit", quit_cb                                            }
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
        else if (options.contains ("show-possible-values"))
        {
            show_possibilities = true;
        }

        /* Activate */
        return -1;
    }

    protected override void startup ()
    {
        base.startup ();

        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        add_action_entries (action_entries, this);

        settings = new GLib.Settings ("org.gnome.sudoku");
        var action = settings.create_action ("show-warnings");
        action.notify["state"].connect (() =>
            view.show_warnings = settings.get_boolean ("show-warnings"));
        add_action (action);

        add_accelerator ("<Primary>z", "app.undo", null);
        add_accelerator ("<Primary><Shift>z", "app.redo", null);
        add_accelerator ("<Primary>p", "app.print", null);
        add_accelerator ("<Primary>q", "app.quit", null);
        add_accelerator ("F1", "app.help", null);

        Gtk.Window.set_default_icon_name ("gnome-sudoku");
    }

    protected override void activate () {
        builder = new Builder ();
        try
        {
            builder.add_from_resource ("/org/gnome/gnome-sudoku/ui/gnome-sudoku.ui");
            builder.add_from_resource ("/org/gnome/gnome-sudoku/ui/gnome-sudoku-menu.ui");
        }
        catch (GLib.Error e)
        {
            GLib.warning ("Could not load UI: %s", e.message);
        }
        window = (ApplicationWindow) builder.get_object ("sudoku_app");

        add_window (window);

        set_app_menu (builder.get_object ("sudoku-menu") as MenuModel);

        header_bar = (HeaderBar) builder.get_object ("headerbar");
        main_stack = (Stack) builder.get_object ("main_stack");
        grid_box = (Box) builder.get_object ("grid_box");
        undo_redo_box = (Box) builder.get_object ("undo_redo_box");
        back_button = (Button) builder.get_object ("back_button");

        undo_action = (SimpleAction) lookup_action ("undo");
        redo_action = (SimpleAction) lookup_action ("redo");
        clear_action = (SimpleAction) lookup_action ("reset");
        print_action = (SimpleAction) lookup_action ("print");

        sudoku_store = new SudokuStore ();
        saver = new SudokuSaver ();

        var savegame = saver.get_savedgame ();
        if (savegame != null)
            start_game (savegame.board);
        else
        {
            var random_difficulty = (DifficultyCategory) Random.int_range (0, 4);
            start_game (sudoku_store.get_random_board (random_difficulty));
        }

        window.show ();

        window.delete_event.connect ((event) => {
            if (!game.board.complete)
                saver.save_game (game);

            return false;
        });
    }

    private void start_game (SudokuBoard board)
    {
        var difficulty_category = board.get_difficulty_category ();
        undo_action.set_enabled (false);
        redo_action.set_enabled (false);
        clear_action.set_enabled (!board.is_empty ());

        if (view != null) {
            grid_box.remove (view);
        }

        header_bar_subtitle = difficulty_category.to_string ();
        back_cb ();

        game = new SudokuGame (board);

        game.timer.start ();

        view = new SudokuView (game);

        view.show_possibilities = show_possibilities;
        view.show_warnings = settings.get_boolean ("show-warnings");

        view.show ();
        grid_box.pack_start (view);

        game.cell_changed.connect (() => {
            undo_action.set_enabled (!game.is_undostack_null ());
            redo_action.set_enabled (!game.is_redostack_null ());
            clear_action.set_enabled (!game.board.is_empty ());
        });

        game.board.completed.connect (() => {
            var time = game.get_total_time_played ();
            var time_str = SudokuGame.seconds_to_hms_string (time);

            for (var i = 0; i < game.board.rows; i++)
            {
                for (var j = 0; j < game.board.cols; j++)
                {
                    view.can_focus = false;
                }
            }

            saver.add_game_to_finished (game, true);

            var dialog = new MessageDialog(window, DialogFlags.DESTROY_WITH_PARENT, MessageType.INFO, ButtonsType.NONE, _("Well done, you completed the puzzle in %s"), time_str);

            dialog.add_button (_("Same difficulty again"), 0);
            dialog.add_button (_("New difficulty"), 1);

            dialog.response.connect ((response_id) => {
                switch (response_id)
                {
                    case 0:
                        start_game (sudoku_store.get_random_board (difficulty_category));
                        break;
                    case 1:
                        DifficultyCategory[] new_range = {};
                        for (var i = 0; i < 4; i++)
                            if (i != (int) difficulty_category)
                                new_range += (DifficultyCategory) i;

                        start_game (sudoku_store.get_random_board (new_range[Random.int_range (0, 3)]));
                        break;
                }
                dialog.destroy ();
            });

            dialog.show ();
        });
    }

    private void new_game_cb ()
    {
        main_stack.set_visible_child_name ("start_box");
        back_button.visible = true;
        undo_redo_box.visible = false;
        header_bar_subtitle = header_bar.get_subtitle ();
        header_bar.set_subtitle (null);
        print_action.set_enabled (false);
    }

    private void start_game_cb (SimpleAction action, Variant? difficulty)
    {
        // Since we cannot have enums in .ui file, the 'action-target' property
        // of new game buttons in data/gnome-sudoku.ui
        // has been set to integers corresponding to the enums.
        // Following line converts those ints to their DifficultyCategory
        var selected_difficulty = (DifficultyCategory) difficulty.get_int32 ();
        start_game (sudoku_store.get_random_board (selected_difficulty));
    }

    private void reset_cb ()
    {
        var dialog = new MessageDialog (window, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.OK_CANCEL, _("Reset the board to its original state?"));

        dialog.response.connect ((response_id) => {
            if (response_id == ResponseType.OK)
            {
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
        main_stack.set_visible_child_name ("game_box");
        back_button.visible = false;
        undo_redo_box.visible = true;
        header_bar.set_subtitle (header_bar_subtitle);
        print_action.set_enabled (true);
    }

    private void undo_cb ()
    {
        if (main_stack.get_visible_child_name () != "game_box")
            return;
        game.undo ();
        undo_action.set_enabled (!game.is_undostack_null ());
        view.queue_draw ();
    }

    private void redo_cb ()
    {
        if (main_stack.get_visible_child_name () != "game_box")
            return;
        game.redo ();
        redo_action.set_enabled (!game.is_redostack_null ());
        view.queue_draw ();
    }

    private void print_cb ()
    {
        if (main_stack.get_visible_child_name () != "game_box")
            return;
        var printer = new SudokuPrinter ({game.board.clone ()}, ref window);
        printer.print_sudoku ();
    }

    private void print_multiple_cb ()
    {
        var printer = new GamePrinter (sudoku_store, saver, ref window);
        printer.run_dialog ();
    }

    private void quit_cb ()
    {
        saver.save_game (game);
        window.destroy ();
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
                               "comments", _("The popular Japanese logic puzzle\n\nGNOME Sudoku is a part of GNOME Games."),
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
