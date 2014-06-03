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
    private Box game_box; // Holds the grid and controls boxes
    private Box grid_box; // Holds the view
    private Box controls_box; // Holds the controls

    private SudokuStore sudoku_store;
    private SudokuSaver saver;

    private SimpleAction undo_action;
    private SimpleAction redo_action;

    private bool show_possibilities = false;

    private const GLib.ActionEntry action_entries[] =
    {
        {"new-game", new_game_cb                                    },
        {"reset", reset_cb                                          },
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
        var action = settings.create_action ("unfillable-squares-warning");
        action.notify["state"].connect (() =>
            view.show_warnings = settings.get_boolean ("unfillable-squares-warning"));
        add_action (action);

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
        game_box = (Box) builder.get_object ("game_box");
        grid_box = (Box) builder.get_object ("grid_box");
        controls_box = (Box) builder.get_object ("controls_box");

        var new_button = new Gtk.Button ();
        var new_label = new Gtk.Label.with_mnemonic ("_New Puzzle");
        new_label.margin = 10;
        new_button.add (new_label);
        new_button.valign = Gtk.Align.CENTER;
        new_button.halign = Gtk.Align.CENTER;
        new_button.action_name = "app.new-game";
        new_button.tooltip_text = _("Start a new puzzle");
        new_button.show_all ();
        controls_box.pack_end (new_button, false, false, 0);

        var restart_button = new Gtk.Button ();
        var restart_label = new Gtk.Label.with_mnemonic ("_Clear Board");
        restart_label.margin = 10;
        restart_button.add (restart_label);
        restart_button.valign = Gtk.Align.CENTER;
        restart_button.halign = Gtk.Align.CENTER;
        restart_button.action_name = "app.reset";
        restart_button.tooltip_text = _("Reset the board to its original state");
        restart_button.show_all ();
        controls_box.pack_end (restart_button, false, false, 0);

        undo_action = (SimpleAction) lookup_action ("undo");
        redo_action = (SimpleAction) lookup_action ("redo");

        sudoku_store = new SudokuStore ();
        saver = new SudokuSaver ();
        //SudokuGenerator gen = new SudokuGenerator();

        var savegame = saver.get_savedgame ();
        if (savegame != null)
            start_game (savegame.board);
        else
        {
            var random_difficulty = (DifficultyCatagory) Random.int_range (0, 4);
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
        var completed_board = board.clone ();

        var rater = new SudokuRater(ref completed_board);
        var rating = rater.get_difficulty ();
        debug ("\n%s", rating.to_string ());
        header_bar.set_subtitle (rating.get_catagory ().to_string ());
        undo_action.set_enabled (false);
        redo_action.set_enabled (false);

        if (view != null) {
            grid_box.remove (view);
        }

        game = new SudokuGame (board);

        game.timer.start ();

        view = new SudokuView (game);

        view.show_possibilities = show_possibilities;
        view.show_warnings = settings.get_boolean ("unfillable-squares-warning");

        view.show ();
        grid_box.pack_start (view);

        game.cell_changed.connect (() => {
            undo_action.set_enabled (!game.is_undostack_null ());
            redo_action.set_enabled (!game.is_redostack_null ());
        });

        game.board.completed.connect (() => {
            var time = game.get_total_time_played ();

            for (var i = 0; i < game.board.rows; i++)
            {
                for (var j = 0; j < game.board.cols; j++)
                {
                    view.can_focus = false;
                }
            }

            saver.add_game_to_finished (game, true);

            var dialog = new MessageDialog(window, DialogFlags.DESTROY_WITH_PARENT, MessageType.INFO, ButtonsType.NONE, _("Well done, you completed the puzzle in %f seconds"), time);

            dialog.add_button (_("Same difficulty again"), 0);
            dialog.add_button (_("New difficulty"), 1);

            dialog.response.connect ((response_id) => {
                switch (response_id)
                {
                    case 0:
                        start_game (sudoku_store.get_random_board (rating.get_catagory ()));
                        break;
                    case 1:
                        DifficultyCatagory[] new_range = {};
                        for (var i = 0; i < 4; i++)
                            if (i != (int) rating.get_catagory ())
                                new_range += (DifficultyCatagory) i;

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
        var random_difficulty = (DifficultyCatagory) Random.int_range (0, 4);
        start_game (sudoku_store.get_random_board (random_difficulty));
    }

    private void reset_cb ()
    {
        var dialog = new MessageDialog (window, DialogFlags.MODAL, MessageType.QUESTION, ButtonsType.OK_CANCEL, _("Reset the board to its original state?"));

        dialog.response.connect ((response_id) => {
            if (response_id == ResponseType.OK)
                game.reset ();
            dialog.destroy ();
        });

        dialog.show ();
    }

    private void undo_cb ()
    {
        game.undo ();
        undo_action.set_enabled (!game.is_undostack_null ());
        view.queue_draw ();
    }

    private void redo_cb ()
    {
        game.redo ();
        redo_action.set_enabled (!game.is_redostack_null ());
        view.queue_draw ();
    }

    private void print_cb ()
    {
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
                                       "John Stowers <john.stowers@gmail.com>",
                                       null };

    private void about_cb ()
    {
        show_about_dialog (window,
                               "program-name", _("Sudoku"),
                               "logo-icon-name", "gnome-sudoku",
                               "version", VERSION,
                               "comments", _("The popular Japanese logic puzzle\n\nGNOME Sudoku is a part of GNOME Games."),
                               "copyright", "Copyright © 2005–2008 Thomas M. Hinkle\nCopyright © 2010–2011 Robert Ancell",
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
