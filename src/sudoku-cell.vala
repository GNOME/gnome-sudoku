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
using Gdk;

public class SudokuCell : Widget
{
    public int row { get; private set; }
    public int col { get; private set; }
    private SudokuGame game;
    private unowned SudokuView view;

    private GestureClick button_controller;
    private GestureLongPress long_press_controller;

    //Only initialized when the cell is not fixed
    private bool control_key_pressed;
    private EventControllerKey key_controller;
    private EventControllerKey popover_controller;
    public NumberPicker number_picker;

    private Label value_label;
    private Label[] earmark_labels;

    public SudokuCell (int row, int col, SudokuGame game, SudokuView view)
    {
        this.set_accessible_role (AccessibleRole.BUTTON);

        this.row = row;
        this.col = col;
        this.game = game;
        this.view = view;

        value_label = new Label (this.value.to_string ());
        value_label.visible = value != 0;
        value_label.set_parent (this);
        value_label.add_css_class ("value");

        focusable = true;
        can_focus = true;
        notify["has-focus"].connect (focus_changed_cb);

        set_fixed_css (true);

        button_controller = new GestureClick ();
        button_controller.set_button (0 /* all buttons */);
        add_controller (this.button_controller);

        long_press_controller = new GestureLongPress ();
        add_controller (this.long_press_controller);

        long_press_controller.pressed.connect (long_press_cb);
        button_controller.released.connect (button_released_cb);

        int num = 0;
        earmark_labels = new Label[9];
        for (int row_tmp = 0; row_tmp < game.board.block_rows; row_tmp++)
        {
            for (int col_tmp = 0; col_tmp < game.board.block_cols; col_tmp++)
            {
                num++;

                earmark_labels[num - 1] = new Label (num.to_string ());
                earmark_labels[num - 1].visible = false;
                earmark_labels[num - 1].set_parent (this);
                earmark_labels[num - 1].add_css_class ("earmark");
            }
        }

        if (!is_fixed)
        {
            key_controller = new EventControllerKey  ();
            add_controller (this.key_controller);
            key_controller.key_pressed.connect (key_pressed_cb);
            key_controller.key_released.connect (key_released_cb);

            /*
            popover_controller = new EventControllerKey ();
            popover_controller.key_pressed.connect (key_pressed_cb);
            popover_controller.key_released.connect (key_released_cb);
            (popover as Widget)?.add_controller (popover_controller);
            */

            number_picker = new NumberPicker (game);
            number_picker.set_parent (this);
        }
    }

    static construct
    {
        set_css_name ("sudokucell");
    }

    public int value
    {
        get { return game.board [row, col]; }
        set {
            if (value == 0)
            {
                if (game.board [row, col] != 0)
                    game.remove (row, col);
                else if (game.board.has_earmarks (row, col))
                    game.disable_all_earmarks (row, col);
            }
            else if (value != game.board [row, col])
            {
                if (view.autoclean_earmarks && game.mode == GameMode.PLAY)
                    game.insert_and_disable_related_earmarks (row, col, value);
                else
                    game.insert (row, col, value);
            }
        }
    }

    private void set_fixed_css (bool enabled)
    {
        if (is_fixed)
        {
            if (enabled)
                this.add_css_class ("fixed");
            else
                this.remove_css_class ("fixed");
        }
    }

    public bool is_fixed
    {
        get { return game.board.get_is_fixed (row, col); }
    }

    private bool _selected = false;
    public bool selected {
        get { return _selected; }
        set
        {
            _selected = value;
            set_fixed_css (!value);
            if (value)
                this.add_css_class ("selected");
            else
                this.remove_css_class ("selected");
        }
    }

    private bool _highlight_coord = false;
    public bool highlight_coord {
        get { return _highlight_coord; }
        set
        {
            _highlight_coord = value;
            if (value)
                this.add_css_class ("highlight-coord");
            else
                this.remove_css_class ("highlight-coord");
        }
    }

    private bool _highlight_number = false;
    public bool highlight_number {
        get { return _highlight_number; }
        set
        {
            _highlight_number = value;
            set_fixed_css (!value);
            if (value)
                this.add_css_class ("highlight-number");
            else
                this.remove_css_class ("highlight-number");
        }
    }

    private bool _paused = false;
    public bool paused {
        get { return _paused; }
        set
        {
            _paused = value;
            if (value)
                this.add_css_class ("paused");
            else
                this.remove_css_class ("paused");
        }
    }

    public void set_earmark_highlight (int val, bool enabled)
    {
        var earmark = earmark_labels[val-1];
        if (enabled && !earmark.has_css_class ("error"))
            earmark.add_css_class ("highlight-number");
        else
            earmark.remove_css_class ("highlight-number");
    }

    public void update_value ()
    {
        value_label.set_label (this.value.to_string ());
        value_label.visible = value != 0;
        get_visible_earmarks ();
    }

    private bool key_pressed_cb (uint         keyval,
                                 uint         keycode,
                                 ModifierType state)
    {
        if (keyval == Key.Control_L || keyval == Key.Control_R)
            control_key_pressed = true;

        // This must return false to pass the key control to the view as well,
        // for navigation and other related things
        return EVENT_PROPAGATE;
    }

    private void key_released_cb (uint         keyval,
                                  uint         keycode,
                                  ModifierType state)
    {
        if (game.paused)
            return;

        if (keyval == Key.Control_L || keyval == Key.Control_R)
            control_key_pressed = false;

        int key = get_key_number (keyval);
        if (key >= 1 && key <= 9)
        {
            bool want_earmark = control_key_pressed;
            if (view.earmark_mode)
                want_earmark = !want_earmark;

            if (!want_earmark)
            {
                value = key;
            }
            else if (game.mode == GameMode.PLAY)
            {
                var new_state = !game.board.is_earmark_enabled (row, col, key);
                if (new_state)
                    game.enable_earmark (row, col, key);
                else
                    game.disable_earmark (row, col, key);
            }
            return;
        }

        if (key == 0 ||
            keyval == Gdk.Key.BackSpace ||
            keyval == Gdk.Key.Delete)
        {
            value = 0;
            return;
        }

        if (keyval == Gdk.Key.space ||
            keyval == Gdk.Key.Return ||
            keyval == Gdk.Key.KP_Enter)
        {
            if (!view.earmark_mode)
                view.number_picker.show_value_picker (this);
            else if (this.value == 0)
                view.number_picker.show_earmark_picker (this);
            return;
        }

        if (keyval == Gdk.Key.Escape)
        {
            view.number_picker.popdown ();
            return;
        }
    }

    private void button_released_cb (GestureClick gesture,
                                     int          n_press,
                                     double       x,
                                     double       y)
    {
        if (gesture.get_current_button () != BUTTON_PRIMARY &&
            gesture.get_current_button () != BUTTON_SECONDARY)
            return;

        gesture.set_state (EventSequenceState.CLAIMED);

        if ((this.view.number_picker_second_click && !selected) ||
            is_fixed || game.paused)
        {
            grab_focus ();
            return;
        }

        grab_focus ();

        bool want_earmark = control_key_pressed;
        if (view.earmark_mode)
            want_earmark = !want_earmark;

        if (gesture.get_current_button () == BUTTON_PRIMARY)
        {
            if (!want_earmark)
                view.number_picker.show_value_picker (this);
            else if (game.mode == GameMode.PLAY)
                view.number_picker.show_earmark_picker (this);
        }
        else if (gesture.get_current_button () == BUTTON_SECONDARY)
        {
            if (want_earmark)
                view.number_picker.show_value_picker (this);
            else if (game.mode == GameMode.PLAY)
                view.number_picker.show_earmark_picker (this);
        }
    }

    private void long_press_cb (GestureLongPress gesture,
                                double           x,
                                double           y)
    {
        gesture.set_state (EventSequenceState.CLAIMED);
        grab_focus ();

        if (is_fixed || game.paused)
            return;

        if (game.mode == GameMode.CREATE || view.earmark_mode)
            view.number_picker.show_value_picker (this);
        else if (this.value == 0)
            view.number_picker.show_earmark_picker (this);
    }

    private void focus_changed_cb ()
    {
        if (game.paused)
            return;

        if (this.has_focus)
            view.set_selected (row, col);
    }

    private int get_key_number (uint keyval)
    {
        switch (keyval)
        {
            case Gdk.Key.@0:
            case Gdk.Key.KP_0:
                return 0;
            case Gdk.Key.@1:
            case Gdk.Key.KP_1:
                return 1;
            case Gdk.Key.@2:
            case Gdk.Key.KP_2:
                return 2;
            case Gdk.Key.@3:
            case Gdk.Key.KP_3:
                return 3;
            case Gdk.Key.@4:
            case Gdk.Key.KP_4:
                return 4;
            case Gdk.Key.@5:
            case Gdk.Key.KP_5:
                return 5;
            case Gdk.Key.@6:
            case Gdk.Key.KP_6:
                return 6;
            case Gdk.Key.@7:
            case Gdk.Key.KP_7:
                return 7;
            case Gdk.Key.@8:
            case Gdk.Key.KP_8:
                return 8;
            case Gdk.Key.@9:
            case Gdk.Key.KP_9:
                return 9;
            default:
                return -1;
        }
    }

    public void get_visible_earmarks ()
    {
        for (int num = 1; num <= 9; num ++)
            get_visible_earmark (num);
    }

    public void get_visible_earmark (int num)
    {
        if (value != 0)
            earmark_labels[num - 1].set_visible (false);
        else
            earmark_labels[num - 1].set_visible (game.board.is_earmark_enabled(row, col, num));
    }

    public void check_value_warnings ()
    {
        bool error = false;

        if (this.value != 0) 
        {
            if (game.board.broken_coords.contains (Coord (row, col)))
                error = true;

            else if (view.solution_warnings && game.mode == GameMode.PLAY)
            {
                int solution = game.board.get_solution (row, col);
                if (solution != 0)
                    error = this.value != solution;
            }
        }

        if (error)
            value_label.add_css_class ("error");
        else
            value_label.remove_css_class ("error");
    }

    public void check_earmarks_warnings ()
    {
        if (this.value != 0 || game.mode == GameMode.CREATE)
            return;

        var marks = game.board.get_earmarks (row, col);
        for (int num = 1; num <= marks.length; num++)
        {
            if (marks[num - 1])
                check_earmark_warnings (num);
        }
    }

    public void check_earmark_warnings (int num)
    {
        if (!game.board.is_possible (row, col, num) && view.show_earmark_warnings)
            earmark_labels[num - 1].add_css_class ("error");
        else
            earmark_labels[num - 1].remove_css_class ("error");
    }

    public void clear_warnings ()
    {
        var marks = game.board.get_earmarks (row, col);
        value_label.remove_css_class ("error");
        for (int num = 1; num <= marks.length; num++)
            earmark_labels[num-1].remove_css_class ("error");
    }

    public override void size_allocate (int width,
                                        int height,
                                        int baseline)
    {
        int zoomed_size = (int) (height * view.value_zoom_multiplier);
        set_font_size (value_label, zoomed_size);

        Requisition min_size;
        value_label.get_preferred_size (out min_size, null);

        int value_width, value_height;
        value_width = int.max (width, min_size.width);
        value_height = int.max (height, min_size.height);

        Allocation value_allocation = {0, 0, value_width, value_height};
        value_label.allocate_size (value_allocation, baseline);

        int earmark_width, earmark_height;
        earmark_width = width / game.board.block_cols;
        earmark_height = height / game.board.block_rows;

        int num = 0;
        for (int row_tmp = 0; row_tmp < game.board.block_rows; row_tmp++)
        {
            for (int col_tmp = 0; col_tmp < game.board.block_cols; col_tmp++)
            {
                num++;

                set_font_size (earmark_labels[num - 1], height / 4);
                earmark_labels[num -1].get_preferred_size (out min_size, null);
                earmark_width = int.max (earmark_width, min_size.width);
                earmark_height = int.max (earmark_height, min_size.height);

                Allocation earmark_allocation = {col_tmp * earmark_width,
                                                (game.board.block_rows - row_tmp - 1) * earmark_height,
                                                 earmark_width, earmark_height};
                earmark_labels[num - 1].allocate_size (earmark_allocation, baseline);
            }
        }
    }

    private void set_font_size (Label label, int font_size)
    {
        var attr_list = label.get_attributes ();
        if (attr_list == null)
            attr_list = new Pango.AttrList ();

        attr_list.change (
            Pango.AttrSize.new_absolute (font_size * Pango.SCALE)
        );

        label.set_attributes (attr_list);
    }

    public override void dispose ()
    {
        this.value_label.unparent ();
        foreach (Label earmark in earmark_labels)
            earmark.unparent ();
        base.dispose ();
    }
}
