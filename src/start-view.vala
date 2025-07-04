/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2025 Johan Gay
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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/start-view.ui")]
public class SudokuStartView : Adw.Bin
{
    [GtkChild] public unowned Adw.HeaderBar headerbar;

    [GtkChild] private unowned CheckButton custom_check;
    [GtkChild] private unowned CheckButton easy_check;
    [GtkChild] private unowned CheckButton medium_check;
    [GtkChild] private unowned CheckButton hard_check;
    [GtkChild] private unowned CheckButton very_hard_check;

    [GtkChild] private unowned Button start_button;
    [GtkChild] private unowned Button back_button;

    static construct {
        typeof (SudokuMenuButton).ensure ();

        var action = new NamedAction ("app.back");

        var trigger = new KeyvalTrigger (Gdk.Key.Left, Gdk.ModifierType.ALT_MASK);
        var shortcut = new Shortcut (trigger, action);
        add_shortcut (shortcut);

        trigger = new KeyvalTrigger (Gdk.Key.KP_Left, Gdk.ModifierType.ALT_MASK);
        shortcut = new Shortcut (trigger, action);
        add_shortcut (shortcut);
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

    public void set_back_button_visible (bool enabled)
    {
        back_button.visible = enabled;
    }

    public void activate_difficulty_checkbutton ()
    {
        switch (Sudoku.app.play_difficulty)
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

    public override bool grab_focus ()
    {
        return start_button.grab_focus ();
    }

    public override void map ()
    {
        base.map ();
        start_button.grab_focus ();
    }

    public override void realize ()
    {
        base.realize ();
        activate_difficulty_checkbutton ();
    }
}
