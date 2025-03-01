/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2024 Johan Gay
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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/preferences-dialog.ui")]
public class SudokuPreferencesDialog : Adw.PreferencesDialog
{
    [GtkChild] public unowned Adw.SwitchRow autoclean_earmarks;
    [GtkChild] public unowned Adw.SwitchRow show_possibilities;
    [GtkChild] public unowned Adw.SwitchRow show_timer;
    [GtkChild] public unowned Adw.SwitchRow number_picker_second_click;
    [GtkChild] public unowned Adw.SwitchRow earmark_warnings;
    [GtkChild] public unowned Adw.SwitchRow solution_warnings;
    [GtkChild] public unowned Adw.SwitchRow highlight_numbers;
    [GtkChild] public unowned Adw.SwitchRow highlight_block;
    [GtkChild] public unowned Adw.SwitchRow highlight_row_column;

    public SudokuPreferencesDialog ()
    {
        Sudoku.app.bind_property ("show-timer", show_timer, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        Sudoku.app.bind_property ("earmark-warnings", earmark_warnings, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        Sudoku.app.bind_property ("show-possibilities", show_possibilities, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        Sudoku.app.bind_property ("number_picker-second_click", number_picker_second_click, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        Sudoku.app.bind_property ("solution-warnings", solution_warnings, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        Sudoku.app.bind_property ("autoclean-earmarks", autoclean_earmarks, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        Sudoku.app.bind_property ("highlight-row-column", highlight_row_column, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        Sudoku.app.bind_property ("highlight-block", highlight_block, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        Sudoku.app.bind_property ("highlight-numbers", highlight_numbers, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
    }

    public override void dispose ()
    {
        dispose_template (this.get_type ());
        base.dispose ();
    }
}
