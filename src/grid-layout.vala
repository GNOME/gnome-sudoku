/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2023 Jamie Murphy <jmurphy@gnome.org>
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

private class SudokuGridLayoutManager : LayoutManager
{
    private const int MARGIN_DEFAULT_SIZE = 25;
    private const int MARGIN_SMALL_SIZE = 10;
    private const int MARGIN_SIZE_DIFF = MARGIN_DEFAULT_SIZE - MARGIN_SMALL_SIZE;

    private int get_align (int size)
    {
        if (size > SudokuWindow.MEDIUM_WINDOW_WIDTH)
            return MARGIN_DEFAULT_SIZE;
        else
        {
            double factor = normalize (size, SudokuWindow.SMALL_WINDOW_WIDTH, SudokuWindow.MEDIUM_WINDOW_WIDTH);
            return MARGIN_SMALL_SIZE + (int) (MARGIN_SIZE_DIFF * factor);
        }
    }

    private double normalize (int val, int min, int max)
    {
        val.clamp (min, max);
        return (val - min) / (double) (max - min);
    }

    public override void measure (Widget widget,
                                  Orientation orientation,
                                  int         for_size,
                                  out int     minimum,
                                  out int     natural,
                                  out int     minimum_baseline,
                                  out int     natural_baseline)
    {
        Widget child = widget.get_first_child ();
        if (widget.visible)
        {
            int child_height_min, child_height_nat;
            int child_width_min, child_width_nat;
            child.measure (Orientation.HORIZONTAL, -1,
                                out child_width_min, out child_width_nat,
                                null, null);
            child.measure (Orientation.VERTICAL, -1,
                                out child_height_min, out child_height_nat,
                                null, null);
            minimum = int.max (child_height_min, child_width_min);
            natural = int.max (child_height_nat, child_width_nat);
        }
        else
            minimum = natural = 0;

        minimum_baseline = natural_baseline = -1;
    }

    public override void allocate (Widget widget,
                                   int width,
                                   int height,
                                   int baseline)
    {
        Widget child = widget.get_first_child ();
        int child_width, child_height;
        int halign, valign;
        halign = get_align (width);
        valign = get_align (height);

        child_width = child_height = int.min (width, height) - int.min (halign, valign) * 2;

        int start = int.max (halign, (width - child_width) / 2);
        int top = int.max (valign, (height - child_height) / 2);

        int maximum_top_offset = 40; //align with the start menu
        top = int.min (top, maximum_top_offset);

        Allocation child_allocation = {start, top, child_width, child_height};
        child.allocate_size (child_allocation, baseline);
    }
}
