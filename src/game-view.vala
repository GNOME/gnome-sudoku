/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2014 Parin Porecha
 * Copyright © 2014 Michael Catanzaro
 * Copyright © 2023 Jamie Murphy <jmurphy@gnome.org>
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
using Gdk;

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/game-view.ui")]
public class SudokuGameView : Adw.Bin
{
    [GtkChild] private unowned Overlay grid_overlay;
    [GtkChild] private unowned Adw.Bin grid_bin;
    [GtkChild] private unowned Box clock_box;
    [GtkChild] private unowned Label clock_label;
    [GtkChild] private unowned Button play_custom_game_button;
    [GtkChild] private unowned ToggleButton earmark_mode_button;

    [GtkChild] private unowned Adw.WindowTitle windowtitle;

    [GtkChild] private unowned Stack play_pause_stack;
    [GtkChild] private unowned Button pause_button;
    [GtkChild] private unowned Button play_button;

    [GtkChild] private unowned SudokuMenuButton menu_button;

    private Label paused_label;
    private GestureClick button_controller;
    private ulong tick_handle;

    public SudokuGame game;
    public SudokuGrid grid;
    public unowned SudokuWindow window;

    private SimpleAction toggle_pause_action;
    private SimpleAction earmark_mode_action;
    private SimpleAction undo_action;
    private SimpleAction redo_action;
    private SimpleAction reset_board_action;

    public double? highscore;

    static construct
    {
        var action = new NamedAction ("game-view.earmark-mode");
        var trigger = ShortcutTrigger.parse_string ("e") as KeyvalTrigger;
        var shortcut = new Shortcut (trigger, action);
        add_shortcut (shortcut);

        action = new NamedAction ("game-view.toggle-pause");
        trigger = ShortcutTrigger.parse_string ("p") as KeyvalTrigger;
        shortcut = new Shortcut (trigger, action);
        add_shortcut (shortcut);

        action = new NamedAction ("game-view.reset-board");
        trigger = ShortcutTrigger.parse_string ("<Primary>r") as KeyvalTrigger;
        shortcut = new Shortcut (trigger, action);
        add_shortcut (shortcut);

        action = new NamedAction ("game-view.undo");
        AlternativeTrigger alt_trigger = ShortcutTrigger.parse_string ("u|<Primary>z") as AlternativeTrigger;
        shortcut = new Shortcut (alt_trigger, action);
        add_shortcut (shortcut);

        action = new NamedAction ("game-view.redo");
        alt_trigger = ShortcutTrigger.parse_string ("r|<Primary><Shift>z") as AlternativeTrigger;
        shortcut = new Shortcut (alt_trigger, action);
        add_shortcut (shortcut);
    }

    public void init (SudokuBoard board, double? highscore, SudokuWindow window)
    {
        game = new SudokuGame (board);
        this.highscore = highscore;
        this.window = window;
        windowtitle.subtitle = game.board.difficulty_category.to_string ();

        var action_group = new SimpleActionGroup ();

        earmark_mode_action = new SimpleAction.stateful ("earmark-mode", null, false);
        earmark_mode_action.activate.connect (earmark_mode_cb);
        earmark_mode_action.set_enabled (game.mode != GameMode.CREATE);
        action_group.add_action (earmark_mode_action);

        toggle_pause_action = new SimpleAction.stateful ("toggle-pause", null, false);
        toggle_pause_action.activate.connect (game.toggle_pause);
        toggle_pause_action.set_enabled (game.mode == GameMode.PLAY && Sudoku.app.show_timer);
        action_group.add_action (toggle_pause_action);

        reset_board_action = new SimpleAction ("reset-board", null);
        reset_board_action.activate.connect (game.reset);
        reset_board_action.set_enabled (!game.is_empty ());
        action_group.add_action (reset_board_action);

        undo_action = new SimpleAction ("undo", null);
        undo_action.activate.connect (game.undo);
        undo_action.set_enabled (!game.is_undostack_null ());
        action_group.add_action (undo_action);

        redo_action = new SimpleAction ("redo", null);
        redo_action.activate.connect (game.redo);
        redo_action.set_enabled (!game.is_redostack_null ());
        action_group.add_action (redo_action);

        insert_action_group ("game-view", action_group);

        Sudoku.app.notify["highlighter"].connect (highlighter_cb);
        Sudoku.app.notify["show-possibilities"].connect (show_possibilities_cb);
        Sudoku.app.notify["show-warnings"].connect (warnings_cb);
        Sudoku.app.notify["earmark-warnings"].connect (warnings_cb);
        Sudoku.app.notify["solution-warnings"].connect (warnings_cb);
        Sudoku.app.notify["zoom-level"].connect (zoom_cb);
        Sudoku.app.notify["show-timer"].connect (show_timer_cb);
        this.window.notify["width-is-small"].connect (window_width_is_small_cb);

        menu_button.main_menu.closed.connect (() => {
            grab_focus ();
        });

        button_controller = new GestureClick ();
        button_controller.set_button (0 /* all buttons */);
        button_controller.released.connect (button_released_cb);
        ((Widget)this).add_controller (this.button_controller);

        paused_label= new Label(_("Paused"));

        initialize_clock_label ();
        initialize_buttons ();
        update_tick_connection ();

        if (game.board.previous_played_time == 0.0)
            add_earmark_possibilities ();

        this.vexpand = true;
        this.focusable = true;

        game.notify["paused"].connect(paused_cb);
        game.action_completed.connect (action_completed_cb);

        grid = new SudokuGrid (game);
        var grid_layout = new SudokuGridLayoutManager ();
        grid_bin.layout_manager = grid_layout;
        grid_overlay.child = grid;
    }

    public void change_board (SudokuBoard board, double? highscore)
    {
        earmark_mode_action.set_enabled (game.mode == GameMode.PLAY);
        toggle_pause_action.set_enabled (game.mode == GameMode.PLAY && Sudoku.app.show_timer);

        this.highscore = highscore;
        game.change_board (board);

        initialize_buttons ();
        add_earmark_possibilities ();
        grid.change_board ();

        initialize_clock_label ();
        update_tick_connection ();
        windowtitle.subtitle = board.difficulty_category.to_string ();

        can_focus = true;
        focus (TAB_FORWARD);
    }

    private void initialize_buttons ()
    {
        clock_box.visible = Sudoku.app.show_timer && game.mode == GameMode.PLAY && !window.width_is_small;
        play_pause_stack.visible = Sudoku.app.show_timer && game.mode == GameMode.PLAY;
        play_custom_game_button.visible = game.mode == GameMode.CREATE;
        earmark_mode_button.visible = game.mode == GameMode.PLAY &&
                                      (!Sudoku.app.show_timer ||
                                      (Sudoku.app.show_timer && !window.width_is_small));

        play_custom_game_button.set_sensitive (!game.is_empty () && !game.board.is_fully_filled ());
    }

    private void initialize_clock_label ()
    {
        if (game.mode == GameMode.CREATE || !Sudoku.app.show_timer)
            return;

        var elapsed_time = (int) game.get_total_time_played ();

        if (highscore != null)
        {
            if (elapsed_time > highscore)
                clock_label.set_css_classes ({"numeric"});
            else if (elapsed_time > highscore - 60)
                clock_label.set_css_classes ({"numeric", "warning"});
            else
                clock_label.set_css_classes ({"numeric", "success"});
        }

        set_clock_label_text (elapsed_time);
    }

    private void set_clock_label_text (int elapsed_time)
    {
        var hours = elapsed_time / 3600;
        var minutes = (elapsed_time - hours * 3600) / 60;
        var seconds = elapsed_time - hours * 3600 - minutes * 60;

        if (hours > 0)
            clock_label.set_text ("%02d∶\xE2\x80\x8E%02d∶\xE2\x80\x8E%02d".printf (hours, minutes, seconds));
        else
            clock_label.set_text ("%02d∶\xE2\x80\x8E%02d".printf (minutes, seconds));
    }

    private void add_earmark_possibilities ()
    {
        if (Sudoku.app.show_possibilities && game.mode != GameMode.CREATE)
            game.enable_all_earmark_possibilities ();
    }

    private void update_tick_connection ()
    {
        if (tick_handle == 0 && game.mode != GameMode.CREATE && Sudoku.app.show_timer)
            tick_handle = game.tick.connect (tick_cb);
        else if (tick_handle != 0 && (game.mode == GameMode.CREATE || !Sudoku.app.show_timer))
        {
            game.disconnect (tick_handle);
            tick_handle = 0;
        }
    }

    private void tick_cb ()
    {
        var elapsed_time = (int) game.get_total_time_played ();

        if (highscore != null)
        {
            if (elapsed_time > highscore && clock_label.has_css_class ("warning"))
                clock_label.remove_css_class ("warning");

            else if (elapsed_time > highscore - 60 && clock_label.has_css_class ("success"))
                clock_label.set_css_classes ({"warning"});
        }

        set_clock_label_text (elapsed_time);
    }

    private void window_width_is_small_cb ()
    {
        clock_box.visible = Sudoku.app.show_timer && !this.window.width_is_small && game.mode == GameMode.PLAY;
        earmark_mode_button.visible = game.mode == GameMode.PLAY &&
                                                   (!Sudoku.app.show_timer ||
                                                   (Sudoku.app.show_timer && !window.width_is_small));
    }

    private void action_completed_cb ()
    {
        undo_action.set_enabled (!game.is_undostack_null ());
        redo_action.set_enabled (!game.is_redostack_null ());
        reset_board_action.set_enabled (!game.is_empty ());
        play_custom_game_button.set_sensitive (!game.is_empty () && !game.board.is_fully_filled ());
    }

    private void paused_cb ()
    {
        // Set Font Size
        var attr_list = paused_label.get_attributes ();
        if (attr_list == null)
            attr_list = new Pango.AttrList ();

        attr_list.change (
            Pango.AttrSize.new_absolute ((int) (this.get_width () * 0.125) * Pango.SCALE)
        );

        paused_label.set_attributes (attr_list);
        paused_label.set_visible (this.game.paused);

        can_focus = !game.paused;

        if (game.paused)
        {
            play_pause_stack.set_visible_child (play_button);
            reset_board_action.set_enabled (false);
            grid_overlay.add_overlay (paused_label);
            grid_overlay.add_css_class ("paused");
        }
        else
        {
            play_pause_stack.set_visible_child (pause_button);
            reset_board_action.set_enabled (!game.is_empty ());
            grid_overlay.remove_overlay (paused_label);
            grid_overlay.remove_css_class ("paused");
        }
    }

    private void show_possibilities_cb ()
    {
        if (game.get_current_stack_action () == StackAction.ENABLE_ALL_EARMARK_POSSIBILITIES)
            game.undo ();
        else
            add_earmark_possibilities ();
    }

    private void highlighter_cb ()
    {
        grid.toggle_highlighter ();
    }

    private void warnings_cb ()
    {
        grid.update_warnings ();
    }

    private void zoom_cb ()
    {
        grid.update_zoom ();
    }

    private void show_timer_cb ()
    {
        if (game.mode == GameMode.PLAY)
        {
            if (Sudoku.app.show_timer)
            {
                initialize_clock_label ();
                update_tick_connection ();
                earmark_mode_button.visible = !window.width_is_small;
                clock_box.visible = !window.width_is_small;
                toggle_pause_action.set_enabled (true);
                play_pause_stack.visible = true;
            }
            else
            {
                clock_box.visible = false;
                update_tick_connection ();
                earmark_mode_button.visible = true;
                play_pause_stack.visible = false;
                toggle_pause_action.set_enabled (false);

                if (game.paused)
                    game.toggle_pause ();
            }
        }
    }

    private void button_released_cb (GestureClick gesture,
                                     int          n_press,
                                     double       x,
                                     double       y)
    {
        if (gesture.get_current_button () != BUTTON_PRIMARY &&
            gesture.get_current_button () != BUTTON_SECONDARY)
            return;

        if (!game.paused)
            grid.unselect ();

        gesture.set_state (EventSequenceState.CLAIMED);
    }

    private void earmark_mode_cb ()
    {
        Sudoku.app.earmark_mode = !Sudoku.app.earmark_mode;
        earmark_mode_button.set_active (Sudoku.app.earmark_mode);
    }

    public override bool grab_focus ()
    {
        return grid.grab_focus ();
    }

    public override void dispose ()
    {
        if (game != null && !game.paused)
            game.stop_clock ();

        grid?.unparent ();
        base.dispose ();
    }
}

public enum ZoomLevel
{
    NONE = 0,
    SMALL = 1,
    MEDIUM = 2,
    LARGE = 3;

    public bool is_fully_zoomed_out ()
    {
        switch (this)
        {
            case SMALL:
                return true;
            default:
                return false;
        }
    }

    public bool is_fully_zoomed_in ()
    {
        switch (this)
        {
            case LARGE:
                return true;
            default:
                return false;
        }
    }

    public ZoomLevel zoom_in ()
    {
        switch (this)
        {
            case SMALL:
                return MEDIUM;
            case MEDIUM:
                return LARGE;
            case LARGE:
            {
                warning ("ZOOM already at maximum");
                return LARGE;
            }
            default:
                assert_not_reached ();
        }
    }

    public ZoomLevel zoom_out ()
    {
        switch (this)
        {
            case LARGE:
                return MEDIUM;
            case MEDIUM:
                return SMALL;
            case SMALL:
            {
                warning ("ZOOM already at minimum");
                return SMALL;
            }
            default:
                assert_not_reached ();
        }
    }
}
