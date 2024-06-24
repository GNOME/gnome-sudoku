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
    [GtkChild] private unowned Adw.HeaderBar headerbar;

    [GtkChild] private unowned Box game_box; // Holds the view

    [GtkChild] private unowned Box start_box;
    [GtkChild] private unowned Button start_button;
    [GtkChild] private unowned CheckButton easy_check;
    [GtkChild] private unowned CheckButton medium_check;
    [GtkChild] private unowned CheckButton hard_check;
    [GtkChild] private unowned CheckButton very_hard_check;

    [GtkChild] private unowned MenuButton main_menu;
    [GtkChild] private unowned ToggleButton earmark_mode_button;
    [GtkChild] private unowned Button undo_button;
    [GtkChild] private unowned Button redo_button;
    [GtkChild] private unowned Button back_button;
    [GtkChild] private unowned Button unfullscreen_button;
    [GtkChild] private unowned Button play_custom_game_button;
    [GtkChild] private unowned Button play_pause_button;

    [GtkChild] private unowned Box clock_box;
    [GtkChild] private unowned Label clock_label;

    private bool window_is_maximized;
    private bool window_is_fullscreen;
    private int window_width;
    private int window_height;

    private const int small_window_width = 600;
    private const int smallest_possible_width = 360;
    private int small_window_height;
    private int smallest_possible_height;
    private bool window_width_is_small;
    private bool window_height_is_small;
    private Adw.Breakpoint small_window_breakpoint;
    private Adw.BreakpointCondition small_window_condition;

    private const int margin_default_size = 25;
    private const int margin_small_size = 10;
    private const int margin_size_diff = margin_default_size - margin_small_size;

    private SudokuGame? game = null;

    private GestureClick button_controller;
    private GestureLongPress long_press_controller;

    public GLib.Settings settings { get; private set;}
    public SudokuView? view { get; private set; default = null;}
    public SudokuWindowScreen current_screen { get; private set; default = SudokuWindowScreen.NONE;}

    public SudokuWindow (GLib.Settings settings)
    {
        this.settings = settings;

        construct_window_parameters ();

        small_window_condition = new Adw.BreakpointCondition.length (Adw.BreakpointConditionLengthType.MAX_WIDTH, small_window_width, Adw.LengthUnit.PX);
        small_window_breakpoint = new Adw.Breakpoint (small_window_condition);
        small_window_breakpoint.unapply.connect (window_width_is_big_cb);
        small_window_breakpoint.apply.connect (window_width_is_small_cb);
        this.add_breakpoint (small_window_breakpoint);

        this.notify["maximized"].connect(() => {
            window_is_maximized = !window_is_maximized;
        });

        this.notify["fullscreened"].connect(() => {
            window_is_fullscreen = !window_is_fullscreen;
            if (window_is_fullscreen)
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

        if (this.window_is_fullscreen)
            fullscreen ();
        else if (this.window_is_maximized)
            maximize ();
        else
        {
            set_gamebox_width_margins (window_width);
            set_gamebox_height_margins (window_height);
        }
        button_controller = new GestureClick ();
        button_controller.set_button (0 /* all buttons */);
        button_controller.released.connect (button_released_cb);
        ((Widget)this).add_controller (this.button_controller);

        long_press_controller = new GestureLongPress ();
        long_press_controller.pressed.connect (long_press_cb);
        ((Widget)this).add_controller (this.long_press_controller);

        this.close_request.connect (close_cb);
    }

    static construct
    {
        add_binding_action (Gdk.Key.n, Gdk.ModifierType.CONTROL_MASK, "app.new-game", null);
        add_binding_action (Gdk.Key.p, Gdk.ModifierType.CONTROL_MASK, "app.print", null);
        add_binding_action (Gdk.Key.p, Gdk.ModifierType.NO_MODIFIER_MASK, "app.pause", null);
        add_binding_action (Gdk.Key.r, Gdk.ModifierType.CONTROL_MASK, "app.reset", null);
        add_binding_action (Gdk.Key.u, Gdk.ModifierType.NO_MODIFIER_MASK, "app.undo", null);
        add_binding_action (Gdk.Key.z, Gdk.ModifierType.CONTROL_MASK, "app.undo", null);
        add_binding_action (Gdk.Key.r, Gdk.ModifierType.NO_MODIFIER_MASK, "app.redo", null);
        add_binding_action (Gdk.Key.z, Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK, "app.redo", null);
        add_binding_action (Gdk.Key.e, Gdk.ModifierType.NO_MODIFIER_MASK, "app.earmark-mode", null);
        add_binding_action (Gdk.Key.question, Gdk.ModifierType.CONTROL_MASK, "app.shortcuts-window", null);
        add_binding_action (Gdk.Key.comma, Gdk.ModifierType.CONTROL_MASK, "app.preferences-dialog", null);
        add_binding_action (Gdk.Key.f, Gdk.ModifierType.NO_MODIFIER_MASK, "app.fullscreen", null);
        add_binding_action (Gdk.Key.F11, Gdk.ModifierType.NO_MODIFIER_MASK, "app.fullscreen", null);
        add_binding_action (Gdk.Key.h, Gdk.ModifierType.CONTROL_MASK, "app.highlighter", null);
        add_binding_action (Gdk.Key.w, Gdk.ModifierType.CONTROL_MASK, "app.show-warnings", null);
    }

    private void construct_window_parameters ()
    {
        window_width = settings.get_int ("window-width");
        window_height = settings.get_int ("window-height");
        window_is_maximized = settings.get_boolean ("window-is-maximized");
        window_is_fullscreen = settings.get_boolean ("window-is-fullscreen");
        show_timer = settings.get_boolean ("show-timer");

        int headerbar_natural_height;
        headerbar.measure (Orientation.VERTICAL, -1, null, out headerbar_natural_height, null, null);

        small_window_height = small_window_width + headerbar_natural_height;
        smallest_possible_height = smallest_possible_width + headerbar_natural_height;

        window_width_is_small = window_width <= small_window_width;
        window_height_is_small = window_height <= small_window_height;

        set_size_request (smallest_possible_width, smallest_possible_height);
        set_default_size (window_width, window_height);

        Label title_label = (Label) windowtitle.get_first_child ().get_first_child ();
        title_label.set_property ("ellipsize", false);
    }

    private bool close_cb ()
    {
        /* Save window state */
        settings.delay ();

        int default_width, default_height;
        this.get_default_size (out default_width, out default_height);
        settings.set_int ("window-width", default_width);
        settings.set_int ("window-height", default_height);
        settings.set_boolean ("window-is-maximized", window_is_maximized);
        settings.set_boolean ("window-is-fullscreen", window_is_fullscreen);
        settings.apply ();
        return EVENT_PROPAGATE;
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

    private void window_width_is_big_cb ()
    {
        window_width_is_small = false;
        if (current_screen == SudokuWindowScreen.PLAY)
        {
            clock_box.visible = show_timer;
            earmark_mode_button.visible = true;
        }
    }

    private void window_width_is_small_cb ()
    {
        window_width_is_small = true;
        clock_box.visible = false;
        if (current_screen == SudokuWindowScreen.PLAY)
            earmark_mode_button.visible = !show_timer;
    }

    private bool _show_timer;
    public bool show_timer
    {
        get { return _show_timer; }
        set {
            _show_timer = value;

            if (game != null && game.paused)
                game.paused = false;

            if (current_screen == SudokuWindowScreen.PLAY)
            {
                if (show_timer)
                {
                    earmark_mode_button.visible = !window_width_is_small;
                    clock_box.visible = !window_width_is_small;
                    display_pause_button ();
                }
                else
                {
                    clock_box.visible = false;
                    earmark_mode_button.visible = true;
                    play_pause_button.visible = false;
                }
            }
         }
    }

    public void will_start_game ()
    {
        back_button.sensitive = false;
    }

    public void start_game (SudokuGame game)
    {
        this.game = game;
        game.tick.connect (tick_cb);
        game.start_clock ();

        if (view != null)
            game_box.remove (view);

        show_game_view ();

        view = new SudokuView (game, settings);

        game_box.prepend (view);
        view.grab_focus ();

        back_button.sensitive = true;
    }

    public void show_menu_screen ()
    {
        current_screen = SudokuWindowScreen.MENU;
        windowtitle.subtitle = _("Select Difficulty");
        set_board_visible (false);
        back_button.visible = game != null;
        earmark_mode_button.visible = false;
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
            case DifficultyCategory.CUSTOM:
                easy_check.activate ();
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
        current_screen = (SudokuWindowScreen) game.mode;
        set_board_visible (true);
        back_button.visible = false;
        undo_button.visible = true;
        redo_button.visible = true;

        if (game.mode == GameMode.PLAY)
        {
            play_custom_game_button.visible = false;
            play_pause_button.visible = show_timer;
            clock_box.visible = show_timer && !window_width_is_small;
            earmark_mode_button.visible = !window_width_is_small || !show_timer;
            windowtitle.subtitle = game.board.difficulty_category.to_string ();
        }
        else
        {
            earmark_mode_button.visible = false;
            clock_box.visible = false;
            play_custom_game_button.visible = true;
            play_pause_button.visible = false;
            windowtitle.subtitle = _("Create Puzzle");
        }
    }

    public void board_completed ()
    {
        play_custom_game_button.visible = false;
    }

    public void display_pause_button ()
    {
        play_pause_button.visible = true;
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

    private double normalize (int val, int min, int max)
    {
        val.clamp (min, max);
        return (val - min) / (double) (max - min);
    }

    private void set_gamebox_width_margins (int width)
    {
        double factor =  normalize (width, smallest_possible_width, small_window_width);
        int margin_size = margin_small_size + (int) (margin_size_diff * factor);
        game_box.margin_start = margin_size;
        game_box.margin_end = margin_size;
    }

    private void set_gamebox_height_margins (int height)
    {
        double factor =  normalize (height, smallest_possible_height, small_window_height);
        int margin_size = margin_small_size + (int) (margin_size_diff * factor);
        game_box.margin_top = margin_size;
        game_box.margin_bottom = margin_size;
    }

    public override void size_allocate (int width, int height, int baseline)
    {
        if (window_width != width && window_height != height)
        {
            set_gamebox_width_margins (width);
            set_gamebox_height_margins (height);

            Gtk.Requisition min_size;
            this.get_preferred_size (out min_size, null);
            window_width = width = int.max (min_size.width, width);
            window_height = height = int.max (min_size.height, height);
        }

        base.size_allocate (width, height, baseline);
    }

    public override void dispose ()
    {
        //Vala calls init_template but doesn't call dispose_template
        //see https://gitlab.gnome.org/GNOME/vala/-/issues/1515
        dispose_template (this.get_type ());
        base.dispose ();
    }
}

//must be aligned with GameMode
public enum SudokuWindowScreen
{
    NONE,
    PLAY,
    CREATE,
    MENU;
}
