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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/menu-button.ui")]
public class SudokuMenuButton : Adw.Bin
{
    [GtkChild] public unowned Stack menu_fullscreen_stack;
    [GtkChild] public unowned Button menu_unfullscreen_button;
    [GtkChild] public unowned Button menu_fullscreen_button;

    [GtkChild] public unowned Popover main_menu;

    private void set_fullscreen_button (bool fullscreen)
    {
        if (fullscreen)
            menu_fullscreen_stack.set_visible_child (menu_unfullscreen_button);
        else
            menu_fullscreen_stack.set_visible_child (menu_fullscreen_button);
    }

    private void fullscreen_cb ()
    {
        var window = root as Window;
        set_fullscreen_button (window.fullscreened);
    }

    public override void realize ()
    {
        base.realize ();
        var window = root as Window;
        set_fullscreen_button (window.fullscreened);
        window.notify["fullscreened"].connect (fullscreen_cb);
    }
}
