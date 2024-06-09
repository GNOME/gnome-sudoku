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

private class SudokuFrame: Widget
{
    private Widget? _child;
    public Widget? child
    {
        get { return _child; }
        set
        {
            _child = value;
            _child.set_parent (this);
        }
    }

    public override void measure (Orientation orientation,
                                  int         for_size,
                                  out int     minimum,
                                  out int     natural,
                                  out int     minimum_baseline,
                                  out int     natural_baseline)
    {
        if (this.child != null && this.child.visible)
            {
                int child_height_min, child_height_nat;
                int child_width_min, child_width_nat;
                this.child.measure (Orientation.HORIZONTAL, -1,
                                    out child_width_min, out child_width_nat,
                                    null, null);
                this.child.measure (Orientation.VERTICAL, -1,
                                    out child_height_min, out child_height_nat,
                                    null, null);
                minimum = int.max (child_height_min, child_width_min);
                natural = int.max (child_height_nat, child_width_nat);
            }
        else
            minimum = natural = 0;

        minimum_baseline = natural_baseline = -1;
    }

    public override void size_allocate (int width,
                                        int height,
                                        int baseline)
    {
        int child_width, child_height;
        child_width = child_height = int.min (width, height);

        Gsk.Transform center = new Gsk.Transform ().translate (Graphene.Point ().init (
            (width - child_width) / 2,
            (height - child_height) / 2
        ));

        this.child.allocate (child_width, child_height, baseline, center);
    }

    public SudokuFrame (Widget? child)
    {
        this.child = child;

        this.set_css_name ("aspectframe");
        this.set_accessible_role (AccessibleRole.GROUP);
    }

    public override void dispose ()
    {
        child.unparent ();
        base.dispose ();
    }
}
