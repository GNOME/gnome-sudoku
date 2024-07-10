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

        show_timer.set_active (window.settings.get_boolean ("show-timer"));
        show_earmark_warnings.set_active (window.settings.get_boolean ("show-earmark-warnings"));
        show_possibilities.set_active (window.settings.get_boolean ("show-possibilities"));
        number_picker_second_click.set_active (window.settings.get_boolean ("number-picker-second-click"));
        solution_warnings.set_active (window.settings.get_boolean ("solution-warnings"));
        autoclean_earmarks.set_active (window.settings.get_boolean ("autoclean-earmarks"));
        highlight_row_column.set_active (window.settings.get_boolean ("highlight-row-column"));
        highlight_block.set_active (window.settings.get_boolean ("highlight-block"));
        highlight_numbers.set_active (window.settings.get_boolean ("highlight-numbers"));

        show_earmark_warnings.notify["active"].connect (() => {
            bool value = show_earmark_warnings.get_active ();
            this.window.settings.set_boolean ("show-earmark-warnings",  value);
            if (this.window.view != null)
                this.window.view.show_earmark_warnings = value;
        });

        show_possibilities.notify["active"].connect (() => {
            bool value = show_possibilities.get_active ();
            this.window.settings.set_boolean ("show-possibilities",  value);
            if (this.window.view != null)
                this.window.view.show_possibilities = value;
        });

        autoclean_earmarks.notify["active"].connect (() => {
            bool value = autoclean_earmarks.get_active ();
            this.window.settings.set_boolean ("autoclean-earmarks",  value);
            if (this.window.view != null)
                this.window.view.autoclean_earmarks = value;
        });

        number_picker_second_click.notify["active"].connect (() => {
            bool value = number_picker_second_click.get_active ();
            this.window.settings.set_boolean ("number-picker-second-click",  value);
            if (this.window.view != null)
                this.window.view.number_picker_second_click = value;
        });

        solution_warnings.notify["active"].connect (() => {
            bool value = solution_warnings.get_active ();
            this.window.settings.set_boolean ("solution-warnings",  value);
            if (this.window.view != null)
                this.window.view.solution_warnings = value;
        });

        show_timer.notify["active"].connect (() => {
            bool value = show_timer.get_active ();
            this.window.settings.set_boolean ("show-timer", value);
            this.window.show_timer = value;
        });

        highlight_row_column.notify["active"].connect (() => {
            bool value = highlight_row_column.get_active ();
            this.window.settings.set_boolean ("highlight-row-column",  value);
            if (this.window.view != null)
                this.window.view.highlight_row_column = value;
        });

        highlight_block.notify["active"].connect (() => {
            bool value = highlight_block.get_active ();
            this.window.settings.set_boolean ("highlight-block", value);
            if (this.window.view != null)
                this.window.view.highlight_block = value;
        });

        highlight_numbers.notify["active"].connect (() => {
            bool value = highlight_numbers.get_active ();
            this.window.settings.set_boolean ("highlight-numbers", value);
            if (this.window.view != null)
                this.window.view.highlight_numbers = value;
        });
    }

    public override void dispose ()
    {
        dispose_template (this.get_type ());
        base.dispose ();
    }
}
