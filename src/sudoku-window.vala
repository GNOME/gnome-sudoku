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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/sudoku-window.ui")]
public class SudokuWindow : ApplicationWindow
{
    [GtkChild] private HeaderBar headerbar;
    [GtkChild] private Hdy.Squeezer main_squeezer;
    [GtkChild] private Box start_box;
    [GtkChild] private Box start_box_s;
    [GtkChild] private AspectFrame frame_v;
    [GtkChild] private AspectFrame frame_h;
    [GtkChild] private Box game_box; // Holds the view
    [GtkChild] private ButtonBox controls_box;

    [GtkChild] private Box undo_redo_box;
    [GtkChild] private Button back_button;

    [GtkChild] private Label clock_label;
    [GtkChild] private Image clock_image;

    [GtkChild] private Button play_custom_game_button;
    [GtkChild] private Button play_pause_button;
    [GtkChild] private Label play_pause_label;

    private bool window_is_maximized;
    private bool window_is_fullscreen;
    private bool window_is_tiled;
    private int window_width;
    private int window_height;

    private GLib.Settings settings;

    public SudokuView? view { get; private set; }

    private SudokuGame? game = null;

    private AspectFrame previous_layout;
    private Orientation main_squeezer_orientation;

    private const int board_size = 140;

    public SudokuWindow (GLib.Settings settings)
    {
        this.settings = settings;

        set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            maximize ();

        previous_layout = frame_h;

        const int BUTTON_W = 120;
        const int BUTTON_H = 60;
        var spacing = 2 * game_box.spacing + 2 * main_squeezer.margin;
        var board_and_spacing = board_size + spacing;
        var board_with_buttons = board_and_spacing + game_box.spacing + 2 * controls_box.spacing;
        frame_h.width_request = board_with_buttons + BUTTON_W;
        frame_v.height_request = board_and_spacing + 3 * BUTTON_H + 4 * controls_box.spacing;
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

    public override void size_allocate (Allocation allocation)
    {
        base.size_allocate (allocation);

        int width, height;
        get_size (out width, out height);
        update_layout (width, height);

        if (window_is_maximized || window_is_fullscreen || window_is_tiled)
            return;

        window_width = width;
        window_height = height;
    }

    private const Gdk.WindowState tiled_state = Gdk.WindowState.TILED
                                              | Gdk.WindowState.TOP_TILED
                                              | Gdk.WindowState.BOTTOM_TILED
                                              | Gdk.WindowState.LEFT_TILED
                                              | Gdk.WindowState.RIGHT_TILED;

    public override bool window_state_event (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            window_is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;

        /* fullscreen: saved as maximized */
        if ((event.changed_mask & Gdk.WindowState.FULLSCREEN) != 0)
            window_is_fullscreen = (event.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;

        /* We don’t save this state, but track it for saving size allocation */
        if ((event.changed_mask & tiled_state) != 0)
            window_is_tiled = (event.new_window_state & tiled_state) != 0;

        return base.window_state_event (event);
    }

    private void update_layout (int width, int height)
    {
        main_squeezer_orientation = height > width ? Orientation.HORIZONTAL : Orientation.VERTICAL;
        frame_h.ratio = height < 350 ? 1.9f : 1.4f;
        apply_main_squeezer_orientation ();
    }

    private void apply_main_squeezer_orientation ()
    {
        var child = main_squeezer.visible_child;
        if (child == start_box || child == start_box_s)
            main_squeezer.orientation = main_squeezer_orientation;
        else
            main_squeezer.orientation = Orientation.HORIZONTAL;
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

        view = new SudokuView (game);
        view.set_size_request (board_size, board_size);

        view.show_possibilities = show_possibilities;
        if (game.mode == GameMode.CREATE)
            view.show_warnings = true;
        else
            view.show_warnings = settings.get_boolean ("show-warnings");
        view.highlighter = settings.get_boolean ("highlighter");

        view.show ();
        game_box.pack_start (view);
        game_box.child_set_property (view, "position", 0);

        back_button.sensitive = true;
    }

    public void show_new_game_screen ()
    {
        headerbar.title = _("Select Difficulty");
        set_board_visible (false);
        back_button.visible = game != null;
        undo_redo_box.visible = false;
        clock_label.visible = false;
        clock_image.visible = false;
    }

    public void set_board_visible (bool visible)
    {
        start_box.visible = !visible;
        start_box_s.visible = !visible;
        frame_h.visible = visible;
        frame_v.visible = visible;
        apply_main_squeezer_orientation ();
    }

    public bool is_board_visible ()
    {
        return frame_h.visible;
    }

    public void show_game_view ()
        requires (game != null)
    {
        set_board_visible (true);
        back_button.visible = false;
        undo_redo_box.visible = true;

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
            headerbar.title = game.board.difficulty_category.to_string ();
        else
            headerbar.title = _("Create Puzzle");
    }

    public void display_pause_button ()
    {
        play_pause_button.show ();
        play_pause_label.label = _("_Pause");
    }

    public void display_unpause_button ()
    {
        play_pause_button.show ();
        play_pause_label.label = _("_Resume");
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

    private void set_layout (AspectFrame new_layout)
    {
        if (new_layout == frame_h)
        {
            controls_box.halign = Align.END;
            controls_box.orientation = Orientation.VERTICAL;
            game_box.orientation = Orientation.HORIZONTAL;
        }
        else
        {
            controls_box.halign = Align.CENTER;
            controls_box.orientation = Orientation.VERTICAL;
            game_box.orientation = Orientation.VERTICAL;
        }
        previous_layout.remove (game_box);
        new_layout.add (game_box);
        previous_layout = new_layout;
    }

    private bool check_layout_change ()
    {
        var layout = main_squeezer.visible_child;
        if (!(layout is AspectFrame))
            return false;
        var changed = layout != previous_layout;
        if (changed)
            set_layout ((AspectFrame) layout);
        return changed;
    }

    [GtkCallback] private bool main_squeezer_draw_cb ()
    {
        return check_layout_change ();
    }
}
