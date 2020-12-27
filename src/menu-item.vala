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

private class SudokuMainMenuItem : ListBoxRow
{
    public string label { get; set construct; }
    public bool has_separator { get; set construct; }

    construct
    {
        visible = true;
        can_focus = true;

        var label_widget = new Label (this.label);
        label_widget.visible = true;
        label_widget.can_focus = false;
        label_widget.use_underline = true;
        child = label_widget;
    }
}
