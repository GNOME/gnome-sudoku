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

public class SudokuEarmark : Adw.Bin
{
    private Adw.TimedAnimation hide_animation;
    public Label label;

    public SudokuEarmark (string? str)
    {
        label = new Label(str);
        set_child (label);
        label.add_css_class ("earmark");
        label.add_css_class ("numeric");
        var anim_target = new Adw.PropertyAnimationTarget (this, "opacity");
        hide_animation = new Adw.TimedAnimation (this, 1, 0, 1000, anim_target);
        hide_animation.done.connect (hide_animation_done);
    }

    private void hide_animation_done ()
    {
        visible = false;
        opacity = 1; //reset the opacity
    }

    public void play_hide_animation ()
    {
        hide_animation.play ();
    }

    public void skip_animation ()
    {
        if (hide_animation.state == Adw.AnimationState.PLAYING)
            hide_animation.skip ();
    }

    private bool _highlight = false;
    public bool highlight {
        get { return _highlight; }
        set
        {
            _highlight = value;
            if (value && !error)
                label.add_css_class ("highlight-number");
            else
                label.remove_css_class ("highlight-number");
        }
    }

    private bool _error = false;
    public bool error {
        get { return _error; }
        set
        {
            _error = value;
            if (value)
                label.add_css_class ("error");
            else
                label.remove_css_class ("error");
        }
    }
}
