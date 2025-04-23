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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/window.ui")]
public class SudokuWindow : Adw.ApplicationWindow
{
    [GtkChild] private unowned Adw.WindowTitle windowtitle;
    [GtkChild] private unowned Adw.HeaderBar headerbar;

    [GtkChild] private unowned Adw.ViewStack view_stack; //contains game_box and start_view
    [GtkChild] private unowned SudokuStartView start_view;

    [GtkChild] private unowned PopoverMenu main_menu;

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

    private bool window_width_is_small { get; private set; }

    public const int SMALL_WINDOW_WIDTH = 360;
    public const int MEDIUM_WINDOW_WIDTH = 600;

    private CssProvider accent_provider;
    private Adw.StyleManager style_manager;

    private GestureClick button_controller;
    private GestureClick backwards_controller;
    private GestureClick forwards_controller;
    private EventControllerScroll scroll_controller;

    public SudokuGameView game_view { get; private set; default = null; }
    public SudokuWindowScreen current_screen { get; private set; default = SudokuWindowScreen.NONE; }

    public SudokuWindow (GLib.Settings settings)
    {
        Sudoku.app.notify["show-timer"].connect (show_timer_cb);
        notify["fullscreened"].connect(fullscreen_cb);
        notify["visible-dialog"].connect (visible_dialog_cb);

        settings.bind ("window-is-fullscreen", this, "fullscreened", SettingsBindFlags.DEFAULT);
        settings.bind ("window-is-maximized", this, "maximized", SettingsBindFlags.DEFAULT);
        settings.bind ("default-width", this, "default-width", SettingsBindFlags.DEFAULT);
        settings.bind ("default-height", this, "default-height", SettingsBindFlags.DEFAULT);

        construct_window_parameters ();

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
            if (current_screen != SudokuWindowScreen.START)
                game_view.grab_focus ();
            else
                start_view.grab_focus ();
        });
    }

    private void construct_window_parameters ()
    {
        int headerbar_natural_height;
        headerbar.measure (Orientation.VERTICAL, -1, null, out headerbar_natural_height, null, null);

        int small_window_height = SMALL_WINDOW_WIDTH + headerbar_natural_height;

        window_width_is_small = default_width <= MEDIUM_WINDOW_WIDTH;

        set_size_request (SMALL_WINDOW_WIDTH, small_window_height);
        set_default_size (default_width, default_height);

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

    public void start_game (SudokuBoard board, double? highscore)
    {
        back_button.sensitive = false;

        game_view = new SudokuGameView (board, highscore);
        view_stack.add (game_view);
        game_view.game.tick.connect (tick_cb);
        game_view.game.notify["paused"].connect (paused_cb);

        show_game_view ();

        if (game_view.highscore != null)
            clock_label.set_css_classes ({"success"});

        back_button.sensitive = true;
    }

    public void change_board (SudokuBoard board, double? highscore)
    {
        game_view.change_board (board, highscore);
        show_game_view ();

        if (game_view.highscore != null)
            clock_label.set_css_classes ({"success"});
    }

    public void show_start_view ()
    {
        current_screen = SudokuWindowScreen.START;
        view_stack.set_visible_child (start_view);
        windowtitle.subtitle = _("Select Difficulty");
        back_button.visible = game_view != null;
        play_custom_game_button.visible = false;
        earmark_mode_button.visible = false;
        undo_button.visible = false;
        redo_button.visible = false;
        clock_box.visible = false;
        play_pause_stack.visible = false;

        start_view.grab_focus ();
    }

    public void show_game_view ()
    {
        current_screen = (SudokuWindowScreen) game_view.game.mode;
        view_stack.set_visible_child (game_view);
        back_button.visible = false;
        undo_button.visible = true;
        redo_button.visible = true;

        if (current_screen == SudokuWindowScreen.PLAY)
        {
            play_pause_stack.visible = Sudoku.app.show_timer;
            clock_box.visible = Sudoku.app.show_timer && !window_width_is_small;
            earmark_mode_button.visible = !window_width_is_small || !Sudoku.app.show_timer;
            play_custom_game_button.visible = false;
            windowtitle.subtitle = game_view.game.board.difficulty_category.to_string ();
        }
        else
        {
            play_pause_stack.visible = false;
            clock_box.visible = false;
            earmark_mode_button.visible = false;
            play_custom_game_button.visible = true;
            windowtitle.subtitle = _("Create Puzzle");
        }

        game_view.grab_focus ();
    }

    private void visible_dialog_cb ()
    {
        if (current_screen == SudokuWindowScreen.START)
            return;

        if (visible_dialog != null)
        {
            if (!game_view.game.paused)
                game_view.game.stop_clock ();

            game_view.unselect ();
        }
        else
        {
            if (!game_view.game.paused)
                game_view.game.resume_clock ();

            game_view.grab_focus ();
        }
    }

    private void show_timer_cb ()
    {
        if (current_screen == SudokuWindowScreen.PLAY)
        {
            if (Sudoku.app.show_timer)
            {
                earmark_mode_button.visible = !window_width_is_small;
                clock_box.visible = !window_width_is_small;
                play_pause_stack.visible = true;

                if (game_view.game.paused)
                    game_view.game.paused = false;
            }
            else
            {
                clock_box.visible = false;
                earmark_mode_button.visible = true;
                play_pause_stack.visible = false;
            }
        }
    }

    private void tick_cb ()
    {
        var elapsed_time = (int) game_view.game.get_total_time_played ();

        if (game_view.highscore != null)
        {
            if (elapsed_time > game_view.highscore && clock_label.has_css_class ("warning"))
                clock_label.remove_css_class ("warning");

            else if (elapsed_time > game_view.highscore - 60 && clock_label.has_css_class ("success"))
                clock_label.set_css_classes ({"warning"});
        }

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
        if (game_view.game.paused)
            play_pause_stack.set_visible_child (play_button);
        else
            play_pause_stack.set_visible_child (pause_button);
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

    private void button_released_cb (GestureClick gesture,
                                     int          n_press,
                                     double       x,
                                     double       y)
    {
        if (gesture.get_current_button () != BUTTON_PRIMARY &&
            gesture.get_current_button () != BUTTON_SECONDARY)
            return;

        if (current_screen != SudokuWindowScreen.START && !game_view.game.paused)
        {
            game_view.unselect ();
            game_view.keep_focus = true;
        }

        gesture.set_state (EventSequenceState.CLAIMED);
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

    private void window_width_is_medium_cb ()
    {
        window_width_is_small = false;
        if (current_screen == SudokuWindowScreen.PLAY)
        {
            clock_box.visible = Sudoku.app.show_timer;
            earmark_mode_button.visible = true;
        }
    }

    private void window_width_is_small_cb ()
    {
        window_width_is_small = true;
        clock_box.visible = false;
        if (current_screen == SudokuWindowScreen.PLAY)
            earmark_mode_button.visible = !Sudoku.app.show_timer;
    }

    public override void size_allocate (int width, int height, int baseline)
    {
        if (width < MEDIUM_WINDOW_WIDTH && !window_width_is_small)
            window_width_is_small_cb ();
        else if (width >= MEDIUM_WINDOW_WIDTH && window_width_is_small)
            window_width_is_medium_cb ();
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
    START;
}
