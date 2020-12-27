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
    [GtkChild] private Box start_box;
    [GtkChild] private Box game_box;

    [GtkChild] private Box undo_redo_box;
    [GtkChild] private Button back_button;

    [GtkChild] private Label clock_label;
    [GtkChild] private Image clock_image;

    [GtkChild] private Button play_custom_game_button;
    [GtkChild] private Button play_pause_button;
    [GtkChild] private Label play_pause_label;

    [GtkChild] private ListBox main_menu;

    private GLib.Settings settings;

    public SudokuView? view { get; private set; }

    private SudokuGame? game = null;

    private const int board_size = 140;

    public SudokuWindow (GLib.Settings settings)
    {
        this.settings = settings;

        set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            maximize ();

        main_menu.can_focus = false;
        main_menu.set_header_func ((row) => {
            var mi = row as SudokuMainMenuItem;
            if (mi != null && mi.has_separator)
            {
                var separator = new Separator (Orientation.HORIZONTAL);
                mi.set_header (separator);
            }
        });
    }

    ~SudokuWindow ()
    {
        /* Save window state */
        settings.delay ();
        settings.set_int ("window-width", default_width);
        settings.set_int ("window-height", default_height);
        settings.set_boolean ("window-is-maximized", maximized);
        settings.apply ();
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
        game_box.prepend (view);

        back_button.sensitive = true;
    }

    public void show_new_game_screen ()
    {
        title = _("Select Difficulty");
        set_board_visible (false);
        back_button.visible = game != null;
        undo_redo_box.visible = false;
        clock_label.visible = false;
        clock_image.visible = false;
    }

    public void set_board_visible (bool visible)
    {
        start_box.visible = !visible;
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

        if (game.mode == GameMode.PLAY)
            title = game.board.difficulty_category.to_string ();
        else
            title = _("Create Puzzle");
    }

    public void board_completed ()
    {
        play_custom_game_button.visible = false;
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
}
