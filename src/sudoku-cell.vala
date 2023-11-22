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

    /* Gesture Controllers */
    private GestureClick button_controller = new GestureClick ();
    private GestureLongPress long_press_controller = new GestureLongPress ();
    private EventControllerKey key_controller = new EventControllerKey ();

    private Popover _popover = null;
    public Popover popover
    {
        get {
            if (_popover == null)
            {
                _popover = new Popover ();
                _popover.autohide = false;
            }
            return _popover;
        }
    }

    // The label can also be set to X if the label is invalid.
    // If this happens, the value **must not** be changed, only the label.
    private Label value_label = new Label ("") {
        visible = false
    };
    private Label[] earmark_labels = new Label[8];

    public int value
    {
        get { return game.board [row, col]; }
        set {
            if (value != 0)
                value_label.set_visible (true);
            else
                value_label.set_visible (false);

            if (is_fixed)
            {
                if (game.mode == GameMode.PLAY)
                    return;
            }

            if (value == 0)
            {
                if (game.board [row, col] != 0)
                    game.remove (row, col);
                if (game.mode == GameMode.PLAY)
                    return;
            }

            if (value == game.board [row, col])
                return;

            value_label.set_label (value.to_string ());

            game.insert (row, col, value);
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

    private bool _show_warnings = true;
    public bool show_warnings
    {
        get { return _show_warnings; }
        set
        {
            _show_warnings = value;
            check_warnings ();
        }
    }

    private bool _show_extra_warnings = false;
    public bool show_extra_warnings
    {
        get { return _show_extra_warnings; }
        set
        {
            _show_extra_warnings = value;
            check_warnings ();
        }
    }

    public bool show_possibilities;
    private bool control_key_pressed;

    private bool initialized_earmarks;
    private bool _initialize_earmarks;
    public bool initialize_earmarks
    {
        get { return _initialize_earmarks; }
        set
        {
            _initialize_earmarks = value;
            get_visible_earmarks ();
        }
    }

    public SudokuCell (int row, int col, ref SudokuGame game)
    {
        this.set_accessible_role (AccessibleRole.BUTTON);

        this.row = row;
        this.col = col;
        this.game = game;

        this.value = game.board [row, col];

        focusable = true;
        can_focus = true;

        if (is_fixed)
            this.add_css_class ("fixed");

        this.button_controller.set_button (0 /* all buttons */);

        this.add_controller (this.button_controller);
        this.add_controller (this.long_press_controller);
        this.add_controller (this.key_controller);
        this.button_controller.group (this.long_press_controller);

        this.long_press_controller.pressed.connect (long_press_cb);
        this.button_controller.released.connect (button_released_cb);
        this.key_controller.key_pressed.connect (key_pressed_cb);
        this.key_controller.key_released.connect (key_released_cb);
        game.cell_changed.connect (cell_changed_cb);

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

        popover.set_parent (this);
        var popover_controller = new EventControllerKey ();
        popover_controller.key_pressed.connect (key_pressed_cb);
        popover_controller.key_released.connect (key_released_cb);
        (popover as Widget)?.add_controller (popover_controller);
        popover.closed.connect (() => {
            if (popover.visible)
            {
                popover.set_child (null);

                check_warnings ();
                this.grab_focus ();
            }
        });

        // Needed for initial earmarks from saved games
        get_visible_earmarks ();
    }

    static construct {
        set_css_name ("sudokucell");
    }

    private void cell_changed_cb (int row,
                                  int col,
                                  int old_val,
                                  int new_val)
    {
        if (row == this.row && col == this.col)
        {
            this.value = new_val;
            notify_property ("value");
            get_visible_earmarks ();
        }
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
        if (game.mode == GameMode.PLAY && (is_fixed || game.paused))
            return;

        if (keyval == Key.Control_L || keyval == Key.Control_R)
        {
            control_key_pressed = false;
            check_warnings ();
        }

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
                    number_picker.set_earmark (row, col, key - 1, new_state);
                }
                else
                {
                    if (new_state)
                        game.enable_earmark (row, col, key);
                    else
                        game.disable_earmark (row, col, key);
                    this.game.cell_changed (row, col, value, value);
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
            value = 0;
            notify_property ("value");
            return;
        }

        if (keyval == Gdk.Key.space ||
            keyval == Gdk.Key.Return ||
            keyval == Gdk.Key.KP_Enter)
        {
            if (popover.visible)
                return;
            show_number_picker ();
            return;
        }

        if (keyval == Gdk.Key.Escape)
        {
            if (popover.visible)
                popover.popdown ();
            return;
        }
    }

    private void long_press_cb (GestureLongPress gesture,
                                double           x,
                                double           y)
    {
        if (game.mode == GameMode.PLAY && (is_fixed || game.paused) || this.value != 0)
            return;

        show_earmark_picker ();
    }

    private void button_released_cb (GestureClick gesture,
                                     int          n_press,
                                     double       x,
                                     double       y)
    {
        if (gesture.get_current_button () != BUTTON_PRIMARY &&
            gesture.get_current_button () != BUTTON_SECONDARY)
            return;

        if (!this.has_focus)
            grab_focus ();

        if (game.mode == GameMode.PLAY && (is_fixed || game.paused))
            return;

        if (gesture.get_current_button () == BUTTON_PRIMARY)
        {
            if (!show_possibilities &&
                (gesture.get_last_event (gesture.get_last_updated_sequence ()).get_modifier_state () & ModifierType.CONTROL_MASK) > 0 &&
                this.value == 0)
                show_earmark_picker ();
            else
                show_number_picker ();
            gesture.set_state (EventSequenceState.CLAIMED);
        }
        else if (!show_possibilities &&
                 gesture.get_current_button () == BUTTON_SECONDARY &&
                 this.value == 0)
        {
            show_earmark_picker ();
            gesture.set_state (EventSequenceState.CLAIMED);
        }
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

    private void get_visible_earmarks ()
    {
        bool[] marks = null;
        if (!show_possibilities)
        {
            if (!initialized_earmarks)
            {
                if (_initialize_earmarks && (game.mode == GameMode.PLAY) &&
                    (game.board.previous_played_time == 0.0))
                {
                    marks = game.board.get_possibilities_as_bool_array (row, col);
                    for (int num = 1; num <= marks.length; num++)
                    {
                        if (marks[num - 1])
                        {
                            game.board.enable_earmark (row, col, num);
                        }
                    }
                }
                initialized_earmarks = true;
            }

            marks = game.board.get_earmarks (row, col);
        }
        else if (value == 0)
        {
            marks = game.board.get_possibilities_as_bool_array (row, col);
        }

        int num = 0;
        for (int row_tmp = 0; row_tmp < game.board.block_rows; row_tmp++)
        {
            for (int col_tmp = 0; col_tmp < game.board.block_cols; col_tmp++)
            {
                num++;

                if (marks == null || value != 0)
                    earmark_labels[num - 1].set_visible (false);
                else
                    earmark_labels[num - 1].set_visible (marks[num - 1]);
            }
        }
    }

    private void show_earmark_picker ()
        requires (this.value == 0)
    {
        if (this.popover.visible && ((NumberPicker)popover.child).is_earmark_picker)
            return;

        will_open_popover ();

        var earmark_picker = new NumberPicker (game, true);
        earmark_picker.set_clear_button_visibility (true);
        if (!this.game.board.has_earmarks (row, col))
            earmark_picker.set_clear_button_enabled (false);
            earmark_picker.earmark_state_changed.connect ((number, state) => {
                if (state)
                {
                    this.game.enable_earmark (row, col, number);
                }
                else
                {
                    if (number == 0)
                        this.game.disable_all_earmarks (row, col);
                    else
                        this.game.disable_earmark (row, col, number);
                }

            if (!this.game.board.has_earmarks (row, col))
                earmark_picker.set_clear_button_enabled (false);
            else
                earmark_picker.set_clear_button_enabled (true);

            check_warnings ();
            this.game.cell_changed (row, col, value, value);
        });
        earmark_picker.set_earmarks (row, col);
        popover.set_child (earmark_picker);

        popover.popup ();
    }

    private void show_number_picker ()
    {
        if (this.popover.visible && ((NumberPicker)popover.child).is_earmark_picker)
            return;

        will_open_popover ();

        var number_picker = new NumberPicker (game);
        number_picker.number_picked.connect ((o, number) => {
            popover.popdown ();

            value = number;
            if (number == 0)
                notify_property ("value");
            this.game.board.disable_all_earmarks (row, col);
            this.game.cell_changed (row, col, value, value);
        });
        number_picker.set_clear_button_visibility (value != 0);
        popover.set_child (number_picker);

        popover.popup ();
    }

    public void check_warnings ()
    {
        bool error = false;
        int solution = game.board.get_solution (row, col);
        var marks = game.board.get_earmarks (row, col);

        if (show_warnings &&
            this.value == 0 &&
            game.board.count_possibilities (row, col) == 0)
        {
            value_label.set_label ("X");
        }
        else
            value_label.set_label (this.value.to_string ());

        if (warn_incorrect_solution () && this.value != 0)
            error = this.value != solution;

        if (show_warnings &&
            game.board.broken_coords.contains (Coord (row, col)))
        {
            error = true;
        }

        if (error)
            add_css_class ("error");
        else
            remove_css_class ("error");

        if (this.value != 0)
            return;

        for (int num = 1; num <= marks.length; num++)
        {
            if (marks[num - 1])
            {
                if (!game.board.is_possible (row, col, num) || warn_incorrect_solution () && num != solution)
                    earmark_labels[num - 1].add_css_class ("error");
                else
                    earmark_labels[num - 1].remove_css_class ("error");
            }
        }
    }

    // Return true if the user is to be warned when the value or earmarks are
    // inconsistent with the known solution, and it is ok for the user to be
    // warned.
    private bool warn_incorrect_solution ()
    {
        // In the following popovers are checked so that the solution of the cell
        // is not revealed to the user as the user enters candidate numbers for
        // the cell using the earmark picker. Similarly don't reveal the solution
        // while earmarks are being entered with the control key.
        return show_extra_warnings &&  // Extra warnings should be shown
               !control_key_pressed && // Right or Left control pressed
               game.board.solved ();   // Does a solution exist
    }

    public override void dispose ()
    {
        base.dispose ();

        this.value_label.unparent ();
    }

    public override void size_allocate (int width,
                                        int height,
                                        int baseline)
    {
        this.popover.present ();

        int value_width, value_height;
        value_width = value_height = int.min (width, height);

        set_font_size (ref value_label, height / size_ratio);

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

                set_font_size (ref earmark_labels[num - 1], height / size_ratio / 2);

                Gsk.Transform earmark_position = new Gsk.Transform ().translate (Graphene.Point ().init (
                    col_tmp * earmark_width,
                    (game.board.block_rows - row_tmp - 1) * earmark_height
                ));

                earmark_labels[num - 1].allocate (earmark_width, earmark_height, baseline, earmark_position);
            }
        }
    }

    private void set_font_size (ref Label label, int font_size)
    {
        var attr_list = label.get_attributes ();
        if (attr_list == null)
            attr_list = new Pango.AttrList ();

        attr_list.change (
            Pango.AttrSize.new_absolute (font_size * Pango.SCALE)
        );

        label.set_attributes (attr_list);
    }
}

