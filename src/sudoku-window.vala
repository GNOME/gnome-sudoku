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
    [GtkChild] private unowned Adw.HeaderBar headerbar;
    [GtkChild] private unowned Adw.WindowTitle windowtitle;

    [GtkChild] private unowned Box start_box;
    [GtkChild] private unowned CheckButton easy_check;
    [GtkChild] private unowned CheckButton medium_check;
    [GtkChild] private unowned CheckButton hard_check;
    [GtkChild] private unowned CheckButton very_hard_check;

    [GtkChild] private unowned Box game_box; // Holds the view

    [GtkChild] private unowned Button undo_button;
    [GtkChild] private unowned Button redo_button;
    [GtkChild] private unowned Button back_button;

    [GtkChild] private unowned Box clock_box;
    [GtkChild] private unowned Label clock_label;
    [GtkChild] private unowned Image clock_image;

    [GtkChild] private unowned Button play_custom_game_button;
    [GtkChild] private unowned Button play_pause_button;

    private bool window_is_maximized;
    private bool window_is_fullscreen;
    private int window_width;
    private int window_height;

    private bool clock_in_headerbar;

    private GLib.Settings settings;

    public SudokuView? view { get; private set; }

    private SudokuGame? game = null;

    private const int board_size = 140;
    private const int clock_in_headerbar_min_width = 450;

    private GestureClick button_controller = new GestureClick ();
    private GestureLongPress long_press_controller = new GestureLongPress ();

    public SudokuWindow (GLib.Settings settings)
    {
        this.settings = settings;

        set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            maximize ();

        this.notify["maximized"].connect(() => {
            this.window_is_maximized = !this.window_is_maximized;
        });

        this.notify["fullscreened"].connect(() => {
            this.window_is_fullscreen = !this.window_is_fullscreen;
        });

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
        settings.set_boolean ("window-is-maximized", window_is_maximized || window_is_fullscreen);
        settings.apply ();
    }

    public override void size_allocate (int width, int height, int baseline)
    {
        base.size_allocate (width, height, baseline);

        set_clock_placed_in_headerbar (width > clock_in_headerbar_min_width);

        if (window_is_maximized || window_is_fullscreen)
            return;

        window_width = width;
        window_height = height;
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

    public void will_start_game ()
    {
        back_button.sensitive = false;
    }

    public void start_game (SudokuGame game, bool show_possibilities)
    {
        if (this.game != null)
            this.game.tick.disconnect (tick_cb);
        this.game = game;
        game.tick.connect (tick_cb);
        game.start_clock ();

        if (view != null)
            game_box.remove (view);

        show_game_view ();

        view = new SudokuView (board_size, game);

        view.show_possibilities = show_possibilities;
        if (game.mode == GameMode.CREATE)
            view.show_warnings = true;
        else
            view.show_warnings = settings.get_boolean ("show-warnings");
        view.show_extra_warnings = settings.get_boolean ("show-extra-warnings");
        view.highlighter = settings.get_boolean ("highlighter");
        view.initialize_earmarks = settings.get_boolean ("initialize-earmarks");

        view.show ();
        game_box.prepend (view);
        view.grab_focus ();

        back_button.sensitive = true;
    }

    public void show_new_game_screen ()
    {
        windowtitle.title = _("Select Difficulty");
        set_board_visible (false);
        back_button.visible = game != null;
        undo_button.visible = false;
        redo_button.visible = false;
        clock_label.visible = false;
        clock_image.visible = false;
    }

    public void set_board_visible (bool visible)
    {
        start_box.visible = !visible;
        play_custom_game_button.visible = visible && game.mode == GameMode.CREATE;
        if (visible && game.mode != GameMode.CREATE)
            display_pause_button ();
        else
            play_pause_button.visible = false;
        game_box.visible = visible;
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

        clock_label.visible = true;
        clock_image.visible = true;

        if (game.mode == GameMode.PLAY)
        {
            play_custom_game_button.visible = false;
            play_pause_button.visible = true;
        }
        else
        {
            clock_label.visible = false;
            clock_image.visible = false;
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
            windowtitle.title = _("Sudoku");
        else
            windowtitle.title = _("Create Puzzle");
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

    private void set_clock_placed_in_headerbar (bool value)
    {
        if (value == clock_in_headerbar)
            return;

        clock_in_headerbar = value;
        if (value)
        {
            game_box.remove (clock_box);
            headerbar.pack_end (clock_box);
        }
        else
        {
            headerbar.remove (clock_box);
            game_box.append (clock_box);
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

        view?.dismiss_popovers ();
        gesture.set_state (EventSequenceState.CLAIMED);
    }

    private void long_press_cb (GestureLongPress gesture,
                                double           x,
                                double           y)
    {
        view?.dismiss_popovers ();
        gesture.set_state (EventSequenceState.CLAIMED);
    }
}
