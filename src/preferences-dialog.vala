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
    [GtkChild] public unowned Adw.SwitchRow show_earmark_warnings;
    [GtkChild] public unowned Adw.SwitchRow solution_warnings;
    [GtkChild] public unowned Adw.SwitchRow highlight_numbers;
    [GtkChild] public unowned Adw.SwitchRow highlight_block;
    [GtkChild] public unowned Adw.SwitchRow highlight_row_column;

    private SudokuWindow window;

    public SudokuPreferencesDialog (SudokuWindow window)
    {
        this.window = window;

        this.window.settings.bind ("show-timer", show_timer, "active", SettingsBindFlags.DEFAULT);
        this.window.settings.bind ("show-earmark-warnings", show_earmark_warnings, "active", SettingsBindFlags.DEFAULT);
        this.window.settings.bind ("show-possibilities", show_possibilities, "active", SettingsBindFlags.DEFAULT);
        this.window.settings.bind ("number-picker-second-click", number_picker_second_click, "active", SettingsBindFlags.DEFAULT);
        this.window.settings.bind ("solution-warnings", solution_warnings, "active", SettingsBindFlags.DEFAULT);
        this.window.settings.bind ("autoclean-earmarks", autoclean_earmarks, "active", SettingsBindFlags.DEFAULT);
        this.window.settings.bind ("highlight-row-column", highlight_row_column, "active", SettingsBindFlags.DEFAULT);
        this.window.settings.bind ("highlight-block", highlight_block, "active", SettingsBindFlags.DEFAULT);
        this.window.settings.bind ("highlight-numbers", highlight_numbers, "active", SettingsBindFlags.DEFAULT);
    }

    public override void dispose ()
    {
        dispose_template (this.get_type ());
        base.dispose ();
    }
}
