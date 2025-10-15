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
    [GtkChild] private unowned Adw.ViewStack view_stack; //contains game_box and start_view
    [GtkChild] public unowned SudokuStartView start_view;
    [GtkChild] public unowned SudokuGameView game_view;

    private SudokuBackend backend;

    public bool width_is_small { get; private set; }

    public const int SMALL_WINDOW_WIDTH = 360;
    public const int MEDIUM_WINDOW_WIDTH = 600;

    private CssProvider accent_provider;
    private Adw.StyleManager style_manager;

    private GestureClick backwards_controller;
    private GestureClick forwards_controller;
    private EventControllerScroll scroll_controller;

    private EventControllerKey capture_key_controller;

    public bool keyboard_pressed_recently { get; private set; }
    private uint keyboard_pressed_timeout;

    public SudokuWindowScreen current_screen { get; private set; default = SudokuWindowScreen.NONE; }

    public SudokuWindow (SudokuBackend backend, GLib.Settings settings)
    {
        this.backend = backend;
        notify["visible-dialog"].connect (visible_dialog_cb);

        settings.bind ("window-is-fullscreen", this, "fullscreened", SettingsBindFlags.DEFAULT);
        settings.bind ("window-is-maximized", this, "maximized", SettingsBindFlags.DEFAULT);
        settings.bind ("default-width", this, "default-width", SettingsBindFlags.DEFAULT);
        settings.bind ("default-height", this, "default-height", SettingsBindFlags.DEFAULT);

        construct_window_parameters ();

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

        capture_key_controller = new EventControllerKey ();
        capture_key_controller.set_propagation_phase (PropagationPhase.CAPTURE);
        capture_key_controller.key_pressed.connect (capture_key_pressed_cb);
        ((Widget)this).add_controller (capture_key_controller);

        accent_provider = new CssProvider();
        StyleContext.add_provider_for_display (get_display (), accent_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        style_manager = Adw.StyleManager.get_default ();
        set_accent_color ();
        style_manager.notify["accent-color"].connect (set_accent_color);
    }

    private void construct_window_parameters ()
    {
        int headerbar_natural_height;
        start_view.headerbar.measure (Orientation.VERTICAL, -1, null, out headerbar_natural_height, null, null);

        int small_window_height = SMALL_WINDOW_WIDTH + headerbar_natural_height;

        width_is_small = default_width <= MEDIUM_WINDOW_WIDTH;

        set_size_request (SMALL_WINDOW_WIDTH, small_window_height);
        set_default_size (default_width, default_height);
    }

    void set_accent_color ()
    {
        var color = style_manager.get_accent_color ();
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

    public void start_game ()
    {
        game_view.init (backend, this);
        show_game_view ();
    }

    public void show_start_view ()
    {
        current_screen = SudokuWindowScreen.START;

        start_view.set_back_button_visible (game_view != null && backend.game != null);
        view_stack.set_visible_child (start_view);

        start_view.grab_focus ();
    }

    public void show_game_view ()
    {
        current_screen = SudokuWindowScreen.PLAY;

        view_stack.set_visible_child (game_view);
        game_view.grab_focus ();
    }

    private void visible_dialog_cb ()
    {
        if (current_screen == SudokuWindowScreen.START)
            return;

        if (visible_dialog != null)
        {
            if (!backend.game.paused)
                backend.game.stop_clock ();

            game_view.grid.unselect ();
        }
        else
        {
            if (!backend.game.paused)
                backend.game.resume_clock ();

            game_view.grab_focus ();
        }
    }

    private void backwards_pressed_cb (GestureClick gesture,
                                      int          n_press,
                                      double       x,
                                      double       y)
    {
        if (current_screen == SudokuWindowScreen.START)
            ((Widget)this).activate_action ("app.back", null);
        else
            game_view.activate_action ("game-view.undo", null);

        gesture.set_state (EventSequenceState.CLAIMED);
    }

    private void forwards_pressed_cb (GestureClick gesture,
                                      int          n_press,
                                      double       x,
                                      double       y)
    {
        if (current_screen != SudokuWindowScreen.START)
            game_view.activate_action ("game-view.redo", null);

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

    private bool capture_key_pressed_cb (uint         keyval,
                                         uint         keycode,
                                         Gdk.ModifierType state)
    {

        keyboard_pressed_recently = true;
        if (keyboard_pressed_timeout != 0)
        {
            Source.remove (keyboard_pressed_timeout);
            keyboard_pressed_timeout = 0;
        }

        keyboard_pressed_timeout = Timeout.add_seconds (5, () => {
            keyboard_pressed_recently = false;
            keyboard_pressed_timeout = 0;
            return Source.REMOVE;
        });

        return Gdk.EVENT_PROPAGATE;
    }

    private void width_is_medium_cb ()
    {
        width_is_small = false;
    }

    private void width_is_small_cb ()
    {
        width_is_small = true;
    }

    public override void size_allocate (int width, int height, int baseline)
    {
        if (width < MEDIUM_WINDOW_WIDTH && !width_is_small)
            width_is_small_cb ();
        else if (width >= MEDIUM_WINDOW_WIDTH && width_is_small)
            width_is_medium_cb ();
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
    START;
}
