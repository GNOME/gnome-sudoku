/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2014 Parin Porecha
 * Copyright © 2014, 2020 Michael Catanzaro
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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/sudoku-window.ui")]
public class SudokuWindow : Adw.ApplicationWindow
{
    [GtkChild] private unowned Adw.WindowTitle windowtitle;

    [GtkChild] private unowned Box start_box;
    [GtkChild] private unowned Button start_button;
    [GtkChild] private unowned CheckButton easy_check;
    [GtkChild] private unowned CheckButton medium_check;
    [GtkChild] private unowned CheckButton hard_check;
    [GtkChild] private unowned CheckButton very_hard_check;

    [GtkChild] private unowned Box game_box; // Holds the view

    [GtkChild] private unowned MenuButton main_menu;
    [GtkChild] private unowned Button undo_button;
    [GtkChild] private unowned Button redo_button;
    [GtkChild] private unowned Button back_button;
    [GtkChild] private unowned Button unfullscreen_button;

    [GtkChild] private unowned Box clock_box;
    [GtkChild] private unowned Label clock_label;

    [GtkChild] private unowned Button play_custom_game_button;
    [GtkChild] private unowned Button play_pause_button;
    [GtkChild] private unowned Adw.HeaderBar headerbar;

    private bool window_is_maximized;
    private bool window_is_fullscreen;
    private int window_width;
    private int window_height;

    private GLib.Settings settings;

    public SudokuView? view { get; private set; }

    private SudokuGame? game = null;

    private GestureClick button_controller = new GestureClick ();
    private GestureLongPress long_press_controller = new GestureLongPress ();

    public SudokuWindow (GLib.Settings settings)
    {
        this.settings = settings;
        this.show_timer = settings.get_boolean ("show-timer");

        window_width = settings.get_int ("window-width");
        window_height = settings.get_int ("window-height");
        is_window_small = window_width <= small_window_size;
        set_default_size (window_width, window_height);

        this.window_is_maximized = settings.get_boolean ("window-is-maximized");
        this.window_is_fullscreen = settings.get_boolean ("window-is-fullscreen");

        Label title_label = (Label) windowtitle.get_first_child ().get_first_child ();
        title_label.set_property ("ellipsize", false);

        this.notify["maximized"].connect(() => {
            this.window_is_maximized = !this.window_is_maximized;
        });

        this.notify["fullscreened"].connect(() => {
            this.window_is_fullscreen = !this.window_is_fullscreen;
            if (this.window_is_fullscreen)
            {
                headerbar.set_decoration_layout (":close");
                unfullscreen_button.visible = true;
            }
            else
            {
                headerbar.set_decoration_layout (null);
                unfullscreen_button.visible = false;
                if (window_is_maximized)
                {
                    this.maximize ();
                    return;
                }
            }
        });

        main_menu.notify["active"].connect(() => {
            if (view != null)
                view.has_selection = !main_menu.active;
        });

        this.notify["default-width"].connect(width_change_cb);
        this.notify["default-height"].connect(height_change_cb);

        if (this.window_is_fullscreen)
            fullscreen ();
        else if (this.window_is_maximized)
            maximize ();

        this.button_controller.set_button (0 /* all buttons */);
        this.button_controller.released.connect (button_released_cb);
        ((Widget)this).add_controller (this.button_controller);

        this.long_press_controller.pressed.connect (long_press_cb);
        ((Widget)this).add_controller (this.long_press_controller);
    }

    ~SudokuWindow ()
    {
        /* Save window state */
        settings.delay ();
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", window_is_maximized);
        settings.set_boolean ("window-is-fullscreen", window_is_fullscreen);
        settings.set_boolean ("show-timer", show_timer);
        settings.apply ();
    }

    private const int small_window_size = 600;
    private bool is_window_small;
    private void width_change_cb ()
    {
        window_width = this.get_width ();

        bool is_new_size_small = window_width <= small_window_size;
        if (is_window_small != is_new_size_small)
        {
            is_window_small = is_new_size_small;
            if (game != null && game.mode != GameMode.CREATE)
                clock_box.visible = show_timer && !is_window_small;
        }
    }

    private void height_change_cb ()
    {
        window_height = this.get_height ();
    }

    [GtkCallback]
    private void start_game_cb (Button btn)
    {
        if (this.easy_check.active)
            (this as Widget)?.activate_action ("app.start-game", "i", 1);
        else if (this.medium_check.active)
            (this as Widget)?.activate_action ("app.start-game", "i", 2);
        else if (this.hard_check.active)
            (this as Widget)?.activate_action ("app.start-game", "i", 3);
        else if (this.very_hard_check.active)
            (this as Widget)?.activate_action ("app.start-game", "i", 4);
    }

    private bool _show_timer = true;
    public bool show_timer {
        get { return _show_timer; }
        set
        {
            _show_timer = value;
            if (game != null && game.mode != GameMode.CREATE)
            {
                clock_box.visible = show_timer && !is_window_small;
                if (value)
                    display_pause_button ();
                else
                    play_pause_button.visible = false;
            }
        }
    }

    public void will_start_game ()
    {
        back_button.sensitive = false;
    }

    public void start_game (SudokuGame game)
    {
        if (this.game != null)
            this.game.tick.disconnect (tick_cb);
        this.game = game;
        game.tick.connect (tick_cb);
        game.start_clock ();

        if (view != null)
            game_box.remove (view);

        show_game_view ();

        view = new SudokuView (game, settings);

        view.show ();
        game_box.prepend (view);
        view.grab_focus ();

        back_button.sensitive = true;
    }

    public void show_new_game_screen ()
    {
        windowtitle.subtitle = _("Select Difficulty");
        set_board_visible (false);
        back_button.visible = game != null;
        undo_button.visible = false;
        redo_button.visible = false;
        clock_box.visible = false;
        play_pause_button.visible = false;
        start_button.grab_focus ();
    }

    public void activate_difficulty_checkbutton (DifficultyCategory difficulty)
    {
        switch (difficulty)
        {
            case DifficultyCategory.EASY:
                easy_check.activate ();
                return;
            case DifficultyCategory.MEDIUM:
                medium_check.activate ();
                return;
            case DifficultyCategory.HARD:
                hard_check.activate ();
                return;
            case DifficultyCategory.VERY_HARD:
                very_hard_check.activate ();
                return;
            default:
                assert_not_reached ();
        }
    }

    public void set_board_visible (bool visible)
    {
        start_box.visible = !visible;
        game_box.visible = visible;
        play_custom_game_button.visible = visible && game.mode == GameMode.CREATE;
    }

    public bool is_board_visible ()
    {
        return game_box.visible;
    }

    public void show_game_view ()
        requires (game != null)
    {
        set_board_visible (true);
        back_button.visible = false;
        undo_button.visible = true;
        redo_button.visible = true;

        if (game.mode == GameMode.PLAY)
        {
            play_custom_game_button.visible = false;
            play_pause_button.visible = show_timer;
            clock_box.visible = show_timer && !is_window_small;
        }
        else
        {
            clock_box.visible = false;
            play_custom_game_button.visible = true;
            play_pause_button.visible = false;
        }

        set_headerbar_title ();
    }

    public void board_completed ()
    {
        play_custom_game_button.visible = false;
    }

    public void set_headerbar_title ()
        requires (game != null)
    {
        if (game.mode == GameMode.PLAY)
            windowtitle.subtitle = null;
        else
            windowtitle.subtitle = _("Create Puzzle");
    }

    public void display_pause_button ()
    {
        play_pause_button.show ();
        play_pause_button.icon_name = game.paused ? "media-playback-start-symbolic" : "media-playback-pause-symbolic";
        play_pause_button.tooltip_text = game.paused ? _("Play") : _("Pause");
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

    private void button_released_cb (GestureClick gesture,
                                     int          n_press,
                                     double       x,
                                     double       y)
    {
        if (gesture.get_current_button () != BUTTON_PRIMARY &&
            gesture.get_current_button () != BUTTON_SECONDARY)
            return;

        view?.dismiss_popovers ();
        gesture.set_state (EventSequenceState.CLAIMED);
    }

    private void long_press_cb (GestureLongPress gesture,
                                double           x,
                                double           y)
    {
        gesture.set_state (EventSequenceState.CLAIMED);
    }
}
