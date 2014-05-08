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

    // The start box (contains the new game previews)
    private Box start_box;
    private Box game_box; // Holds the grid and controls boxes
    private Box grid_box; // Holds the view
    private Box help_box;

    private Box controls_box; // Holds the controls (including the number picker)
    private NumberPicker number_picker;

    private SudokuView easy_preview;
    private SudokuView medium_preview;
    private SudokuView hard_preview;
    private SudokuView very_hard_preview;
    private SudokuView savegame_preview;

    private SudokuStore sudoku_store;

    private SudokuSaver saver;

    // Help Stuff
    private Box naked_single_items;
    private Box hidden_single_items;
    private Box naked_subset_items;

    private const GLib.ActionEntry action_entries[] =
    {
        {"new-game", new_game_cb                                    },
        {"reset", reset_cb                                          },
        {"undo", undo_cb                                            },
        {"redo", redo_cb                                            },
        {"print", print_cb                                          },
        {"print-multiple", print_multiple_cb                        },
        {"possible-numbers",   possible_numbers_cb,   null, "false" },
        {"unfillable-squares", unfillable_squares_cb, null, "false" },
        {"help", help_cb                                            },
        {"about", about_cb                                          },
        {"quit", quit_cb                                            }
    };

    public Sudoku ()
    {
        Object (application_id: "org.gnome.gnome-sudoku", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void startup()
    {
        base.startup ();
        add_action_entries (action_entries, this);
    }

    protected override void activate () {
        settings = new GLib.Settings ("org.gnome.gnome-sudoku");

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

        start_box = (Box) builder.get_object ("start_box");
        game_box = (Box) builder.get_object ("game_box");
        grid_box = (Box) builder.get_object ("grid_box");
        help_box = (Box) builder.get_object ("help_box");

        naked_single_items = (Box) builder.get_object ("naked_single_items");
        hidden_single_items = (Box) builder.get_object ("hidden_single_items");
        naked_subset_items = (Box) builder.get_object ("naked_subset_items");

        controls_box = (Box) builder.get_object ("number_picker_box");

        var back_button = (Button) builder.get_object ("back_button");
        back_button.clicked.connect (() => {
            undo_cb();
        });

        var hint_button = (Button) builder.get_object ("hint_button");
        hint_button.clicked.connect (() => {
            view.hint ();
        });

        var help_button = (Button) builder.get_object ("help_button");
        help_button.clicked.connect (() => {
            help_box.visible = !help_box.visible;
        });

        sudoku_store = new SudokuStore ();
        saver = new SudokuSaver ();
        //SudokuGenerator gen = new SudokuGenerator();

        var easy_grid = (Box) builder.get_object ("easy_grid");
        var medium_grid = (Box) builder.get_object ("medium_grid");
        var hard_grid = (Box) builder.get_object ("hard_grid");
        var very_hard_grid = (Box) builder.get_object ("very_hard_grid");
        var savegame_grid = (Box) builder.get_object ("savegame_grid");

        var easy_board = sudoku_store.get_random_easy_board ();
        //gen.make_symmetric_puzzle(Random.int_range(0, 4));
        //gen.generate (DifficultyRating.easy_range);
        easy_preview = new SudokuView (new SudokuGame (easy_board), true);
        easy_preview.show ();
        easy_grid.pack_start (easy_preview);

        easy_grid.button_press_event.connect ((event) => {
            if (event.button == 1)
                start_game (easy_board);

            return false;
        });

        var medium_board = sudoku_store.get_random_medium_board ();
        //gen.make_symmetric_puzzle(Random.int_range(0, 4));
        // gen.generate (DifficultyRating.medium_range);
        medium_preview = new SudokuView (new SudokuGame (medium_board), true);
        medium_preview.show ();
        medium_grid.pack_start (medium_preview);

        medium_grid.button_press_event.connect ((event) => {
            if (event.button == 1)
                start_game (medium_board);

            return false;
        });

        var hard_board = sudoku_store.get_random_hard_board ();
        //gen.make_symmetric_puzzle(Random.int_range(0, 4));
        //gen.generate (DifficultyRating.hard_range);
        hard_preview = new SudokuView (new SudokuGame (hard_board), true);
        hard_preview.show ();
        hard_grid.pack_start (hard_preview);

        hard_grid.button_press_event.connect ((event) => {
            if (event.button == 1)
                start_game (hard_board);

            return false;
        });

        var very_hard_board = sudoku_store.get_random_very_hard_board ();
        //gen.make_symmetric_puzzle(Random.int_range(0, 4));
        //gen.generate (DifficultyRating.very_hard_range);
        very_hard_preview = new SudokuView (new SudokuGame (very_hard_board), true);
        very_hard_preview.show ();
        very_hard_grid.pack_start (very_hard_preview);

        very_hard_grid.button_press_event.connect ((event) => {
            if (event.button == 1)
                start_game (very_hard_board);

            return false;
        });

        // FIXME: Remove the preview and directly start the game instead
        var savegame = saver.get_savedgame ();
        if (savegame == null)
            savegame = new SudokuGame (sudoku_store.get_random_easy_board ());
        //gen.make_symmetric_puzzle(Random.int_range(0, 4));
        // gen.generate (DifficultyRating.medium_range);
        savegame_preview = new SudokuView (savegame, true);
        savegame_preview.show ();
        savegame_grid.pack_start (savegame_preview);

        savegame_grid.button_press_event.connect ((event) => {
            if (event.button == 1)
                start_game (savegame.board);

            return false;
        });

        show_start ();

        builder.connect_signals (this);

        window.show ();

        window.delete_event.connect ((event) => {
            if (game_box.visible)
                saver.save_game (game);

            return false;
        });
    }

    private void start_game (SudokuBoard board)
    {
        var completed_board = board.clone ();

        var rater = new SudokuRater(ref completed_board);
        var rating = rater.get_difficulty ();
        rating.pretty_print ();

        var show_possibilities = false;
        var show_warnings = false;

        if (view != null) {
            show_possibilities = view.show_possibilities;
            show_warnings = view.show_warnings;

            grid_box.remove (view);
            controls_box.remove (number_picker);
        }

        game_box.visible = true;
        start_box.visible = false;

        game = new SudokuGame (board);

        game.timer.start ();

        view = new SudokuView (game);

        view.show_possibilities = show_possibilities;
        view.show_warnings = show_warnings;

        view.show ();
        grid_box.pack_start (view);

        update_help ();

        number_picker = new NumberPicker(ref game.board);
        controls_box.pack_start (number_picker);

        view.cell_focus_in_event.connect ((row, col) => {
            // Only enable the NumberPicker for unfixed cells
            number_picker.sensitive = !game.board.is_fixed[row, col];
        });

        view.cell_value_changed_event.connect ((row, col) => {
            update_help ();
        });


        number_picker.number_picked.connect ((number) => {
            view.set_cell_value (view.selected_x, view.selected_y, number);
        });

        game.board.completed.connect (() => {
            view.dance ();

            var time = game.get_total_time_played ();

            for (var i = 0; i < game.board.rows; i++)
            {
                for (var j = 0; j < game.board.cols; j++)
                {
                    view.can_focus = false;
                }
            }

            saver.add_game_to_finished (game, true);

            var dialog = new MessageDialog(null, DialogFlags.DESTROY_WITH_PARENT, MessageType.INFO, ButtonsType.NONE, "Well done, you completed the puzzle in %f seconds", time);

            dialog.add_button ("Same difficulty again", 0);
            dialog.add_button ("New difficulty", 1);

            dialog.response.connect ((response_id) => {
                switch (response_id)
                {
                    case 0:
                        start_game (sudoku_store.get_random_board (rating.get_catagory ()));
                        break;
                    case 1:
                        show_start ();
                        break;
                }
                dialog.destroy ();
            });

            dialog.show ();
        });
    }

    private void update_help ()
    {
        var logical_solver = new LogicalSudokuSolver(ref game.board);

        view.reset_cell_background_colors ();
        view.queue_draw ();

        RGBA highlight_color = {0.47, 0.75, 1, 0};
        RGBA highlight_fixed_color = {0.8, 0.8, 0.9, 0};

        foreach (Widget w in naked_single_items.get_children())
        {
            naked_single_items.remove (w);
        }

        foreach (Cell? cell in logical_solver.naked_singles)
        {
            var event_box = new Gtk.EventBox ();

            var label = new Gtk.Label ("%d is the only possiblility in %d, %d".printf (cell.val, cell.coord.col, cell.coord.row));

            event_box.enter_notify_event.connect ((event) => {
                view.cell_grab_focus (cell.coord.row, cell.coord.col);
                return true;
            });

            label.use_markup = true;
            event_box.add (label);
            naked_single_items.add (event_box);
            event_box.show ();
            label.show ();
        }

        foreach (Widget w in hidden_single_items.get_children())
        {
            hidden_single_items.remove (w);
        }

        foreach (HiddenSingle? hidden_single in logical_solver.hidden_singles)
        {
            var event_box = new Gtk.EventBox ();

            var description = "%d should go in %d, %d because its the only place it can go in the associated ".printf (hidden_single.cell.val, hidden_single.cell.coord.col, hidden_single.cell.coord.row);
            if (hidden_single.row && hidden_single.col && hidden_single.block)
            {
                description += "row, column and block";
            }
            else if (hidden_single.row && hidden_single.col)
            {
                description += "row and column";
            }
            else if (hidden_single.col && hidden_single.block)
            {
                description += "column and block";
            }
            else if (hidden_single.row && hidden_single.block)
            {
                description += "row and block";
            }
            else if (hidden_single.row)
            {
                description += "row";
            }
            else if (hidden_single.col)
            {
                description += "column";
            }
            else if (hidden_single.block)
            {
                description += "block";
            }

            var label = new Gtk.Label (description);

            event_box.enter_notify_event.connect ((event) => {
                view.cell_grab_focus (hidden_single.cell.coord.row, hidden_single.cell.coord.col);

                if (hidden_single.row) {
                    view.set_row_background_color (hidden_single.cell.coord.row, highlight_color, highlight_fixed_color);
                }

                if (hidden_single.col) {
                    view.set_col_background_color (hidden_single.cell.coord.col, highlight_color, highlight_fixed_color);
                }

                if (hidden_single.block) {
                    Coord block = game.board.get_block_for (hidden_single.cell.coord.row, hidden_single.cell.coord.col);
                    view.set_block_background_color (block.row, block.col, highlight_color, highlight_fixed_color);
                }

                view.selected_x = hidden_single.cell.coord.col;
                view.selected_y = hidden_single.cell.coord.row;

                view.queue_draw ();

                return true;
            });

            event_box.leave_notify_event.connect ((event) => {
                view.reset_cell_background_colors ();
                view.queue_draw ();

                return true;
            });

            label.use_markup = true;
            event_box.add (label);
            hidden_single_items.add (event_box);
            event_box.show ();
            label.show ();
        }

        foreach (Widget w in naked_subset_items.get_children())
        {
            naked_subset_items.remove (w);
        }

        foreach (Subset? subset in logical_solver.get_naked_subsets()) {
            var event_box = new Gtk.EventBox ();

            var description = "naked subset";

            var label = new Gtk.Label (description);

            event_box.enter_notify_event.connect ((event) => {
                foreach (Cell? cell in subset.eliminated_possibilities) {
                    view.set_cell_background_color(cell.coord.row, cell.coord.col, {1, 0, 0, 0});
                }

                foreach (Coord? coord in subset.coords) {
                    view.set_cell_background_color(coord.row, coord.col, {0, 1, 0, 0});
                }

                view.queue_draw ();

                return true;
            });

            event_box.leave_notify_event.connect ((event) => {
                view.reset_cell_background_colors ();
                view.queue_draw ();

                return true;
            });

            event_box.add (label);
            naked_subset_items.add (event_box);
            event_box.show ();
            label.show ();
        }
    }

    private void show_start ()
    {
        game_box.visible = false;
        help_box.visible = false;
        start_box.visible = true;
    }

    public void new_game_cb ()
    {
        show_start ();
    }

    public void reset_cb ()
    {
        game.reset ();
    }

    public void undo_cb ()
    {
        game.undo ();
    }

    public void redo_cb ()
    {
        game.redo ();
    }

    public void print_cb ()
    {
        if (game_box.visible)
        {
            var printer = new SudokuPrinter ({game.board.clone ()}, ref window);
            printer.print_sudoku ();
        }
    }

    public void print_multiple_cb ()
    {
        var printer = new GamePrinter (sudoku_store, saver, ref window);
        printer.run_dialog ();
    }

    public void possible_numbers_cb (SimpleAction action)
    {
        view.show_possibilities = !view.show_possibilities;
        action.set_state (view.show_possibilities);
    }

    public void unfillable_squares_cb (SimpleAction action)
    {
        view.show_warnings = !view.show_warnings;
        action.set_state (view.show_warnings);
    }

    public void quit_cb ()
    {
        if (game_box.visible)
            saver.save_game (game);
        window.destroy ();
    }

    public void help_cb ()
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

    public void about_cb ()
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
}
