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

private class SudokuCell : Widget
{
    const int size_ratio = 2;

    private int row;
    private int col;
    private SudokuGame game;
    public signal void will_open_popover ();
    private unowned SudokuView view;

    private GestureClick button_controller = new GestureClick ();
    private GestureLongPress long_press_controller = new GestureLongPress ();

    //Only initialized when the cell is not fixed
    private bool control_key_pressed;
    private Popover popover;
    private EventControllerKey key_controller;
    private NumberPicker earmark_picker;
    private NumberPicker value_picker;

    // The label can also be set to X if the label is invalid.
    // If this happens, the value **must not** be changed, only the label.
    private Label value_label = new Label ("") {
        visible = false
    };
    private Label[] earmark_labels = new Label[9];

    public SudokuCell (int row, int col, SudokuGame game, SudokuView view)
    {
        this.set_accessible_role (AccessibleRole.BUTTON);

        this.row = row;
        this.col = col;
        this.game = game;
        this.view = view;

        if (value != 0)
        {
            value_label.set_label (this.value.to_string ());
            value_label.set_visible (true);
        }

        focusable = true;
        can_focus = true;

        this.set_fixed_css (true);

        this.notify["has-focus"].connect (focus_changed_cb);
        this.button_controller.set_button (0 /* all buttons */);

        this.add_controller (this.button_controller);
        this.add_controller (this.long_press_controller);

        this.long_press_controller.pressed.connect (long_press_cb);
        this.button_controller.released.connect (button_released_cb);

        value_label.set_parent (this);

        int num = 0;
        for (int row_tmp = 0; row_tmp < game.board.block_rows; row_tmp++)
        {
            for (int col_tmp = 0; col_tmp < game.board.block_cols; col_tmp++)
            {
                num++;

                earmark_labels[num - 1] = new Label (num.to_string ()) {
                    visible = false
                };
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

            popover = new Popover ();
            popover.set_autohide (false);
            popover.set_parent (this);
            var popover_controller = new EventControllerKey ();
            popover_controller.key_pressed.connect (key_pressed_cb);
            popover_controller.key_released.connect (key_released_cb);
            (popover as Widget)?.add_controller (popover_controller);

            value_picker = new NumberPicker (game, false);
            value_picker.value_picked.connect (value_picked_cb);

            earmark_picker = new NumberPicker (game, true);
            earmark_picker.earmark_state_changed.connect (earmark_picked_cb);
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
            if (value == game.board [row, col] || is_fixed)
            {
                /* This early return avoids the property change notify. */
                return;
            }

            if (value != 0)
                value_label.set_visible (true);
            else
                value_label.set_visible (false);

            if (value == 0)
            {
                if (game.board [row, col] != 0)
                    game.remove (row, col);
            }
            else
            {
                value_label.set_label (value.to_string ());
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

    private bool _highlighted_background = false;
    public bool highlighted_background {
        get { return _highlighted_background; }
        set
        {
            _highlighted_background = value;
            set_fixed_css (!value);
            if (value)
                this.add_css_class ("highlight-bg");
            else
                this.remove_css_class ("highlight-bg");
        }
    }

    private bool _highlighted_value = false;
    public bool highlighted_value {
        get { return _highlighted_value; }
        set
        {
            _highlighted_value = value;
            if (value && !has_css_class ("error"))
                this.add_css_class ("highlight-label");
            else
                this.remove_css_class ("highlight-label");
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
        if (!game.board.is_earmark_enabled (row, col, val))
            return;

        var earmark = earmark_labels[val-1];
        if (enabled && !earmark.has_css_class ("error"))
            earmark.add_css_class ("highlight-label");
        else
            earmark.remove_css_class ("highlight-label");
    }

    public void update_value ()
    {
        if (value != 0)
        {
            value_label.set_label (this.value.to_string ());
            value_label.set_visible (true);
        }
        else
            value_label.set_visible (false);

        get_visible_earmarks ();
    }

    public void update_earmark (int num)
    {
        get_visible_earmark (num);
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
            // check for earmark popover
            var number_picker = (NumberPicker) this.popover.get_child ();
            bool ctrl_pressed = (state & ModifierType.CONTROL_MASK) > 0;
            bool want_earmark = (this.popover.visible && number_picker != null && number_picker.is_earmark_picker) ||
                                ctrl_pressed && this.value == 0;
            if (want_earmark && game.mode == GameMode.PLAY)
            {
                var new_state = !game.board.is_earmark_enabled (row, col, key);

                if (number_picker != null && number_picker.is_earmark_picker)
                {
                    number_picker.set_earmark_button (key, new_state);
                }
                else
                {
                    if (new_state)
                        game.enable_earmark (row, col, key);
                    else
                        game.disable_earmark (row, col, key);
                }
            }
            else if (!ctrl_pressed)
            {
                value = key;
                this.game.board.disable_all_earmarks (row, col);
            }
            return;
        }

        if (key == 0 ||
            keyval == Gdk.Key.BackSpace ||
            keyval == Gdk.Key.Delete)
        {
            if (game.board.has_earmarks (row, col))
                game.disable_all_earmarks (row, col);
            value = 0;
            return;
        }

        if (keyval == Gdk.Key.space ||
            keyval == Gdk.Key.Return ||
            keyval == Gdk.Key.KP_Enter)
        {
            show_value_picker ();
            return;
        }

        if (keyval == Gdk.Key.Escape)
        {
            if (popover.visible)
                popover.popdown ();
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

        if (!this.has_focus)
            grab_focus ();

        if (is_fixed || game.paused)
            return;

        if (gesture.get_current_button () == BUTTON_PRIMARY)
        {
            if (game.mode == GameMode.PLAY &&
                (gesture.get_last_event (gesture.get_last_updated_sequence ()).get_modifier_state () & ModifierType.CONTROL_MASK) > 0 &&
                this.value == 0)
            {
                show_earmark_picker ();
            }
            else
                show_value_picker ();
        }
        else if (gesture.get_current_button () == BUTTON_SECONDARY &&
                 game.mode == GameMode.PLAY &&
                 this.value == 0)
        {
            show_earmark_picker ();
        }
    }

    private void long_press_cb (GestureLongPress gesture,
                                double           x,
                                double           y)
    {
        gesture.set_state (EventSequenceState.CLAIMED);
        if (!this.has_focus)
            grab_focus ();

        if (is_fixed || game.paused)
            return;

        if (game.mode == GameMode.CREATE)
            show_value_picker ();
        else if (this.value == 0)
            show_earmark_picker ();
    }

    void focus_changed_cb ()
    {
        if (game.paused)
            return;

        if (this.has_focus)
            view.set_selected (row, col);
    }

    private void value_picked_cb (int val)
    {
        if (val > 0)
            popover.popdown ();
        else
        {
            this.game.board.disable_all_earmarks (row, col);
            value_picker.set_clear_button_visibility (false);
        }
        this.value = val;
    }

    private void earmark_picked_cb (int num, bool state)
    {
        if (state)
        {
            if (!this.game.board.is_earmark_enabled (row, col, num))
                this.game.enable_earmark (row, col, num);
        }
        else
        {
            if (num == 0)
                this.game.disable_all_earmarks (row, col);

            else if (this.game.board.is_earmark_enabled (row, col, num))
                this.game.disable_earmark (row, col, num);
        }

        earmark_picker.set_clear_button_enabled (this.game.board.has_earmarks (row, col));
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

    public void initialize_earmarks (bool show_possibilities, bool force = false)
    {
        if (value != 0 || game.mode == GameMode.CREATE)
            return;

        if (show_possibilities && (game.board.previous_played_time == 0.0 || force))
        {
            var marks = game.board.get_possibilities_as_bool_array (row, col);
            for (int num = 1; num <= 9; num++)
            {
                if (marks[num - 1] && !game.board.is_earmark_enabled (row, col, num))
                    game.board.enable_earmark (row, col, num);
            }
        }

        get_visible_earmarks ();
    }

    private void get_visible_earmarks ()
    {
        for (int num = 1; num <= 9; num ++)
            get_visible_earmark (num);
    }

    private void get_visible_earmark (int num)
    {
        if (value != 0)
            earmark_labels[num - 1].set_visible (false);
        else
            earmark_labels[num - 1].set_visible (game.board.is_earmark_enabled(row, col, num));
    }

    private void show_earmark_picker ()
        requires (this.value == 0)
    {
        if (popover.visible)
        {
            bool is_earmark_picker = ((NumberPicker)popover.child).is_earmark_picker;
            dismiss_popover ();
            if (is_earmark_picker)
                return;
        }

        will_open_popover ();

        earmark_picker.set_clear_button_visibility (true);
        earmark_picker.set_earmark_buttons (row, col);
        if (!game.board.has_earmarks (row, col))
            earmark_picker.set_clear_button_enabled (false);

        popover.set_child (earmark_picker);
        popover.popup ();
    }

    private void show_value_picker ()
    {
        if (popover.visible)
        {
            bool is_earmark_picker = ((NumberPicker)popover.child).is_earmark_picker;
            dismiss_popover ();
            if (!is_earmark_picker)
                return;
        }

        will_open_popover ();
        value_picker.set_clear_button_visibility (value > 0 || game.board.has_earmarks (row, col));

        popover.set_child (value_picker);
        popover.popup ();
    }

    public void check_value_warnings (bool show_extra_warnings)
    {
        bool error = false;

        if (this.value != 0) 
        {
            if (game.board.broken_coords.contains (Coord (row, col)))
                error = true;

            else if (show_extra_warnings && game.mode == GameMode.PLAY)
            {
                int solution = game.board.get_solution (row, col);
                if (solution != 0)
                    error = this.value != solution;
            }

            value_label.set_label (this.value.to_string ());
        }

        else if (game.board.count_possibilities (row, col) == 0)
            value_label.set_label ("X");

        if (error)
            add_css_class ("error");
        else
            remove_css_class ("error");
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
        if (!game.board.is_possible (row, col, num))
            earmark_labels[num - 1].add_css_class ("error");
        else
            earmark_labels[num - 1].remove_css_class ("error");
    }

    public void clear_warnings ()
    {
        var marks = game.board.get_earmarks (row, col);
        value_label.set_label (this.value.to_string ());
        remove_css_class ("error");
        for (int num = 1; num <= marks.length; num++)
            earmark_labels[num-1].remove_css_class ("error");
    }

    public override void size_allocate (int width,
                                        int height,
                                        int baseline)
    {
        this.popover?.present ();

        int value_width, value_height;
        value_width = value_height = int.min (width, height);

        set_font_size (value_label, height / size_ratio);

        Gtk.Requisition min_size;
        value_label.get_preferred_size (out min_size, null);
        value_width = int.max (value_width, min_size.width);
        value_height = int.max (value_height, min_size.height);

        Gsk.Transform center = new Gsk.Transform ().translate (Graphene.Point ().init (
            (width - value_width) / 2,
            (height - value_height) / 2
        ));
        this.value_label.allocate (value_width, value_height, baseline, center);

        int earmark_width, earmark_height;
        earmark_width = width / game.board.block_cols;
        earmark_height = height / game.board.block_rows;

        int num = 0;
        for (int row_tmp = 0; row_tmp < game.board.block_rows; row_tmp++)
        {
            for (int col_tmp = 0; col_tmp < game.board.block_cols; col_tmp++)
            {
                num++;

                set_font_size (earmark_labels[num - 1], height / size_ratio / 2);
                earmark_labels[num -1].get_preferred_size (out min_size, null);
                earmark_width = int.max (earmark_width, min_size.width);
                earmark_height = int.max (earmark_height, min_size.height);

                Gsk.Transform earmark_position = new Gsk.Transform ().translate (Graphene.Point ().init (
                    col_tmp * earmark_width,
                    (game.board.block_rows - row_tmp - 1) * earmark_height
                ));

                earmark_labels[num - 1].allocate (earmark_width, earmark_height, baseline, earmark_position);
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

    public void dismiss_popover ()
    {
        if (popover != null)
        {
            popover.popdown ();
            popover.child = null;
        }
    }

    public override void dispose ()
    {
        this.value_label.unparent ();
        foreach (Label earmark in earmark_labels)
            earmark.unparent ();
        popover?.unparent ();
        base.dispose ();
    }
}
