/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2020 Andrii Kuteiko
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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/preferences-window.ui")]
public class SudokuPreferencesWindow : Adw.PreferencesWindow
{
    [GtkChild] public unowned Adw.SwitchRow autoclean_earmarks;
    [GtkChild] public unowned Adw.SwitchRow show_possibilities;
    [GtkChild] public unowned Adw.SwitchRow show_timer;
    [GtkChild] public unowned Adw.SwitchRow show_earmark_warnings;
    [GtkChild] public unowned Adw.SwitchRow simple_warnings;
    [GtkChild] public unowned Adw.SwitchRow highlight_numbers;
    [GtkChild] public unowned Adw.SwitchRow highlight_block;
    [GtkChild] public unowned Adw.SwitchRow highlight_row_column;

    public SudokuPreferencesWindow (SudokuWindow window)
    {
        this.set_transient_for (window);

        show_timer.set_active (window.settings.get_boolean ("show-timer"));
        show_earmark_warnings.set_active (window.settings.get_boolean ("show-earmark-warnings"));
        show_possibilities.set_active (window.settings.get_boolean ("show-possibilities"));
        simple_warnings.set_active (!window.settings.get_boolean ("simple-warnings"));
        autoclean_earmarks.set_active (window.settings.get_boolean ("autoclean-earmarks"));
        highlight_row_column.set_active (window.settings.get_boolean ("highlight-row-column"));
        highlight_block.set_active (window.settings.get_boolean ("highlight-block"));
        highlight_numbers.set_active (window.settings.get_boolean ("highlight-numbers"));

        show_earmark_warnings.notify["active"].connect (() => {
            bool value = show_earmark_warnings.get_active ();
            window.settings.set_boolean ("show-earmark-warnings",  value);
            if (window.view != null)
                window.view.show_earmark_warnings = value;
        });

        show_possibilities.notify["active"].connect (() => {
            bool value = show_possibilities.get_active ();
            window.settings.set_boolean ("show-possibilities",  value);
            if (window.view != null)
                window.view.show_possibilities = value;
        });

        autoclean_earmarks.notify["active"].connect (() => {
            bool value = autoclean_earmarks.get_active ();
            window.settings.set_boolean ("autoclean-earmarks",  value);
            if (window.view != null)
                window.view.autoclean_earmarks = value;
        });

        simple_warnings.notify["active"].connect (() => {
            bool value = !simple_warnings.get_active ();
            window.settings.set_boolean ("simple-warnings",  value);
            if (window.view != null)
                window.view.simple_warnings = value;
        });

        show_timer.notify["active"].connect (() => {
            bool value = show_timer.get_active ();
            window.settings.set_boolean ("show-timer", value);
            window.show_timer = value;
        });

        highlight_row_column.notify["active"].connect (() => {
            bool value = highlight_row_column.get_active ();
            window.settings.set_boolean ("highlight-row-column",  value);
            if (window.view != null)
                window.view.highlight_row_column = value;
        });

        highlight_block.notify["active"].connect (() => {
            bool value = highlight_block.get_active ();
            window.settings.set_boolean ("highlight-block", value);
            if (window.view != null)
                window.view.highlight_block = value;
        });

        highlight_numbers.notify["active"].connect (() => {
            bool value = highlight_numbers.get_active ();
            window.settings.set_boolean ("highlight-numbers", value);
            if (window.view != null)
                window.view.highlight_numbers = value;
        });
    }
}
