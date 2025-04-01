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
    [GtkChild] private unowned PopoverMenu main_menu;

    [GtkChild] private unowned Box start_box;
    [GtkChild] private unowned Button start_button;
    [GtkChild] private unowned CheckButton custom_check;
    [GtkChild] private unowned CheckButton easy_check;
    [GtkChild] private unowned CheckButton medium_check;
    [GtkChild] private unowned CheckButton hard_check;
    [GtkChild] private unowned CheckButton very_hard_check;

    [GtkChild] private unowned Stack menu_fullscreen_stack;
    [GtkChild] private unowned Stack play_pause_stack;
    [GtkChild] private unowned ToggleButton earmark_mode_button;
    [GtkChild] private unowned Button undo_button;
    [GtkChild] private unowned Button redo_button;
    [GtkChild] private unowned Button back_button;
    [GtkChild] private unowned Button unfullscreen_button;
    [GtkChild] private unowned Button menu_unfullscreen_button;
    [GtkChild] private unowned Button menu_fullscreen_button;
    [GtkChild] private unowned Button play_custom_game_button;
    [GtkChild] private unowned Button pause_button;
    [GtkChild] private unowned Button play_button;

    [GtkChild] private unowned Box clock_box;
    [GtkChild] private unowned Label clock_label;

    private int window_width { get; private set; }
    private int window_height { get; private set; }
    private bool window_width_is_small { get; private set; }
    private bool window_height_is_small { get; private set; }

    private const int SMALL_WINDOW_WIDTH = 360;
    private const int MEDIUM_WINDOW_WIDTH = 600;

    private int small_window_height;
    private int medium_window_height;

    private CssProvider accent_provider;
    private Adw.StyleManager style_manager;

    private const int MARGIN_DEFAULT_SIZE = 25;
    private const int MARGIN_SMALL_SIZE = 10;
    private const int MARGIN_SIZE_DIFF = MARGIN_DEFAULT_SIZE - MARGIN_SMALL_SIZE;

    private SudokuGame game = null;

    private GestureClick button_controller;
    private GestureClick backwards_controller;
    private GestureClick forwards_controller;
    private EventControllerScroll scroll_controller;

    public GLib.Settings settings { get; private set; }
    public SudokuView view { get; private set; default = null; }
    public SudokuWindowScreen current_screen { get; private set; default = SudokuWindowScreen.NONE; }

    public SudokuWindow (GLib.Settings settings)
    {
        this.settings = settings;

        construct_window_parameters ();

        notify["fullscreened"].connect(fullscreen_cb);

        fullscreened = settings.get_boolean ("window-is-fullscreen");
        maximized = settings.get_boolean ("window-is-maximized");
        set_gamebox_width_margins (window_width);
        set_gamebox_height_margins (window_height);

        button_controller = new GestureClick ();
        button_controller.set_button (0 /* all buttons */);
        button_controller.released.connect (button_released_cb);
        ((Widget)this).add_controller (this.button_controller);

        backwards_controller = new GestureClick ();
        backwards_controller.set_button (8 /* backward button */);
        backwards_controller.pressed.connect (backwards_pressed_cb);
        backwards_controller.set_propagation_limit (PropagationLimit.NONE);
        ((Widget)this).add_controller (backwards_controller);

        forwards_controller = new GestureClick ();
        forwards_controller.set_button (9 /* forward button */);
        forwards_controller.pressed.connect (forwards_pressed_cb);
        forwards_controller.set_propagation_limit (PropagationLimit.NONE);
        ((Widget)this).add_controller (forwards_controller);

        scroll_controller = new EventControllerScroll (EventControllerScrollFlags.VERTICAL);
        scroll_controller.scroll.connect (scroll_cb);
        scroll_controller.scroll_begin.connect (scroll_begin_cb);
        scroll_controller.scroll_end.connect (scroll_end_cb);
        scroll_controller.set_propagation_limit (PropagationLimit.NONE);
        ((Widget)this).add_controller (scroll_controller);

        accent_provider = new CssProvider();
        StyleContext.add_provider_for_display (get_display (), accent_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        style_manager = Adw.StyleManager.get_default ();
        set_accent_color (style_manager.get_accent_color ());
        style_manager.notify["accent-color"].connect(() => {
            set_accent_color (style_manager.get_accent_color ());
        });

        main_menu.closed.connect(() => {
            if (current_screen != SudokuWindowScreen.MENU)
                view.has_selection = true;
            else
                start_button.grab_focus ();
        });

        notify["visible-dialog"].connect (visible_dialog_cb);
        close_request.connect (close_cb);
    }

    static construct
    {
        add_binding_action (Gdk.Key.n, Gdk.ModifierType.CONTROL_MASK, "app.new-game", null);
        add_binding_action (Gdk.Key.p, Gdk.ModifierType.CONTROL_MASK, "app.print-current-board", null);
        add_binding_action (Gdk.Key.p, Gdk.ModifierType.NO_MODIFIER_MASK, "app.toggle-pause", null);
        add_binding_action (Gdk.Key.r, Gdk.ModifierType.CONTROL_MASK, "app.reset-board", null);
        add_binding_action (Gdk.Key.u, Gdk.ModifierType.NO_MODIFIER_MASK, "app.undo", null);
        add_binding_action (Gdk.Key.z, Gdk.ModifierType.CONTROL_MASK, "app.undo", null);
        add_binding_action (Gdk.Key.r, Gdk.ModifierType.NO_MODIFIER_MASK, "app.redo", null);
        add_binding_action (Gdk.Key.z, Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK, "app.redo", null);
        add_binding_action (Gdk.Key.e, Gdk.ModifierType.NO_MODIFIER_MASK, "app.earmark-mode", null);
        add_binding_action (Gdk.Key.question, Gdk.ModifierType.CONTROL_MASK, "app.shortcuts-window", null);
        add_binding_action (Gdk.Key.comma, Gdk.ModifierType.CONTROL_MASK, "app.preferences-dialog", null);
        add_binding_action (Gdk.Key.f, Gdk.ModifierType.NO_MODIFIER_MASK, "app.toggle-fullscreen", null);
        add_binding_action (Gdk.Key.F11, Gdk.ModifierType.NO_MODIFIER_MASK, "app.toggle-fullscreen", null);
        add_binding_action (Gdk.Key.h, Gdk.ModifierType.CONTROL_MASK, "app.highlighter", null);
        add_binding_action (Gdk.Key.w, Gdk.ModifierType.CONTROL_MASK, "app.show-warnings", null);
        add_binding_action (Gdk.Key.@0, Gdk.ModifierType.CONTROL_MASK, "app.zoom-reset", null);
        add_binding_action (Gdk.Key.KP_0, Gdk.ModifierType.CONTROL_MASK, "app.zoom-reset", null);
        add_binding_action (Gdk.Key.plus, Gdk.ModifierType.CONTROL_MASK, "app.zoom-in", null);
        add_binding_action (Gdk.Key.equal, Gdk.ModifierType.CONTROL_MASK, "app.zoom-in", null);
        add_binding_action (Gdk.Key.KP_Add, Gdk.ModifierType.CONTROL_MASK, "app.zoom-in", null);
        add_binding_action (Gdk.Key.ZoomIn, Gdk.ModifierType.NO_MODIFIER_MASK, "app.zoom-in", null);
        add_binding_action (Gdk.Key.minus, Gdk.ModifierType.CONTROL_MASK, "app.zoom-out", null);
        add_binding_action (Gdk.Key.KP_Subtract, Gdk.ModifierType.CONTROL_MASK, "app.zoom-out", null);
        add_binding_action (Gdk.Key.ZoomOut, Gdk.ModifierType.NO_MODIFIER_MASK, "app.zoom-out", null);
        add_binding_action (Gdk.Key.Left, Gdk.ModifierType.ALT_MASK, "app.back", null);
    }

    private void construct_window_parameters ()
    {
        window_width = settings.get_int ("window-width");
        window_height = settings.get_int ("window-height");

        settings.bind ("show-timer", this, "show-timer", SettingsBindFlags.GET);

        int headerbar_natural_height;
        headerbar.measure (Orientation.VERTICAL, -1, null, out headerbar_natural_height, null, null);

        small_window_height = SMALL_WINDOW_WIDTH + headerbar_natural_height;
        medium_window_height = MEDIUM_WINDOW_WIDTH + headerbar_natural_height;

        window_width_is_small = window_width <= MEDIUM_WINDOW_WIDTH;
        window_height_is_small = window_height <= medium_window_height;

        set_size_request (SMALL_WINDOW_WIDTH, small_window_height);
        set_default_size (window_width, window_height);

        Label title_label = (Label) windowtitle.get_first_child ().get_first_child ();
        title_label.set_property ("ellipsize", false);
    }

    void set_accent_color (Adw.AccentColor color)
    {
        string css_color;
        switch (color)
        {
            case BLUE:
                css_color = "blue";
                break;
            case TEAL:
                css_color = "teal";
                break;
            case GREEN:
                css_color = "green";
                break;
            case YELLOW:
                css_color = "yellow";
                break;
            case ORANGE:
                css_color = "orange";
                break;
            case RED:
                css_color = "red";
                break;
            case PINK:
                css_color = "pink";
                break;
            case PURPLE:
                css_color = "purple";
                break;
            case SLATE:
                css_color = "slate";
                break;
            default:
                css_color = "blue";
                break;
        }
        string s = ":root {--sudoku-accent-color: var(--sudoku-accent-" + css_color + ");}";
        accent_provider.load_from_string(s);
    }

    private bool close_cb ()
    {
        /* Save window state */
        settings.delay ();

        int default_width, default_height;
        this.get_default_size (out default_width, out default_height);
        settings.set_int ("window-width", default_width);
        settings.set_int ("window-height", default_height);
        settings.set_boolean ("window-is-maximized", maximized);
        settings.set_boolean ("window-is-fullscreen", fullscreened);
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
        else if (this.custom_check.active)
            (this as Widget)?.activate_action ("app.start-game", "i", 5);
    }

    private void window_width_is_medium_cb ()
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
                    play_pause_stack.visible = true;
                }
                else
                {
                    clock_box.visible = false;
                    earmark_mode_button.visible = true;
                    play_pause_stack.visible = false;
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
        game.notify["paused"].connect (paused_cb);

        if (view != null)
            game_box.remove (view);

        show_game_view ();

        view = new SudokuView (game, settings);

        game_box.prepend (view);
        view.grab_focus ();
        game.start_clock ();

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
        play_pause_stack.visible = false;
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
                custom_check.activate ();
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
            play_pause_stack.visible = show_timer;
            clock_box.visible = show_timer && !window_width_is_small;
            earmark_mode_button.visible = !window_width_is_small || !show_timer;
            windowtitle.subtitle = game.board.difficulty_category.to_string ();
        }
        else
        {
            earmark_mode_button.visible = false;
            clock_box.visible = false;
            play_custom_game_button.visible = true;
            play_pause_stack.visible = false;
            windowtitle.subtitle = _("Create Puzzle");
        }
    }

    public void board_completed ()
    {
        play_custom_game_button.visible = false;
    }

    private void visible_dialog_cb ()
    {
        if (current_screen == SudokuWindowScreen.MENU)
            return;

        if (visible_dialog != null)
        {
            if (!game.paused)
                game.stop_clock ();

            view.has_selection = false;
        }
        else
        {
            if (!game.paused)
                game.resume_clock ();

            view.has_selection = true;
        }
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

    private void paused_cb ()
    {
        if (game.paused)
            play_pause_stack.set_visible_child (play_button);
        else
            play_pause_stack.set_visible_child (pause_button);
    }

    private void button_released_cb (GestureClick gesture,
                                     int          n_press,
                                     double       x,
                                     double       y)
    {
        if (gesture.get_current_button () != BUTTON_PRIMARY &&
            gesture.get_current_button () != BUTTON_SECONDARY)
            return;

        if (current_screen != SudokuWindowScreen.MENU)
            view.dismiss_picker ();

        gesture.set_state (EventSequenceState.CLAIMED);
    }

    private void fullscreen_cb ()
    {
        if (fullscreened)
        {
            headerbar.set_decoration_layout (":close");
            unfullscreen_button.visible = true;
            menu_fullscreen_stack.set_visible_child (menu_unfullscreen_button);
        }
        else
        {
            headerbar.set_decoration_layout (null);
            unfullscreen_button.visible = false;
            menu_fullscreen_stack.set_visible_child (menu_fullscreen_button);
        }
    }

    private void backwards_pressed_cb (GestureClick gesture,
                                      int          n_press,
                                      double       x,
                                      double       y)
    {
        ((Widget)this).activate_action ("app.undo", null);
        ((Widget)this).activate_action ("app.back", null);
        gesture.set_state (EventSequenceState.CLAIMED);
    }

    private void forwards_pressed_cb (GestureClick gesture,
                                      int          n_press,
                                      double       x,
                                      double       y)
    {
        ((Widget)this).activate_action ("app.redo", null);
        gesture.set_state (EventSequenceState.CLAIMED);
    }

    private bool scroll_cb (EventControllerScroll event,
                            double                dx,
                            double                dy)
    {
        ModifierType state;
        state = event.get_current_event_state ();
        bool control_pressed = (bool) (state & ModifierType.CONTROL_MASK);
        if (control_pressed)
        {
            if (dy <= -1)
            {
                ((Widget)this).activate_action ("app.zoom-in", null);
                return Gdk.EVENT_STOP;
            }
            else if (dy >= 1)
            {
                ((Widget)this).activate_action ("app.zoom-out", null);
                return Gdk.EVENT_STOP;
            }
        }

        return Gdk.EVENT_PROPAGATE;
    }

    private void scroll_begin_cb (EventControllerScroll event)
    {
        ModifierType state;
        state = event.get_current_event_state ();
        bool control_pressed = (bool) (state & ModifierType.CONTROL_MASK);
        if (control_pressed)
        {
            event.set_flags (EventControllerScrollFlags.VERTICAL |
                             EventControllerScrollFlags.DISCRETE);
        }
    }

    private void scroll_end_cb (EventControllerScroll event)
    {
        event.set_flags (EventControllerScrollFlags.VERTICAL);
    }

    private double normalize (int val, int min, int max)
    {
        val.clamp (min, max);
        return (val - min) / (double) (max - min);
    }

    private void set_gamebox_width_margins (int width)
    {
        double factor = normalize (width, SMALL_WINDOW_WIDTH, MEDIUM_WINDOW_WIDTH);
        int margin_size = MARGIN_SMALL_SIZE + (int) (MARGIN_SIZE_DIFF * factor);
        game_box.margin_start = margin_size;
        game_box.margin_end = margin_size;
    }

    private void set_gamebox_height_margins (int height)
    {
        double factor =  normalize (height, small_window_height, medium_window_height);
        int margin_size = MARGIN_SMALL_SIZE + (int) (MARGIN_SIZE_DIFF * factor);
        game_box.margin_top = margin_size;
        game_box.margin_bottom = margin_size;
    }

    public override void size_allocate (int width, int height, int baseline)
    {
        if (width < MEDIUM_WINDOW_WIDTH && !window_width_is_small)
            window_width_is_small_cb ();
        else if (width >= MEDIUM_WINDOW_WIDTH && window_width_is_small)
            window_width_is_medium_cb ();

        if (window_width != width || window_height != height)
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
