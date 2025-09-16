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

    private GestureClick button_controller;
    private GestureLongPress long_press_controller;

    private Label value_label;
    private SudokuEarmark[] earmarks;

    private SudokuGame game;

    private unowned SudokuGrid grid;
    private unowned double? zoom_value_multiplier;
    private unowned double? zoom_earmark_multiplier;

    private SimpleAction insert_earmark_action;
    private SimpleAction insert_value_action;
    private SimpleAction show_picker_action;

    static Shortcut earmark_shortcuts[9];
    static Shortcut value_shortcuts[9];

    static construct
    {
        set_css_name ("sudoku-cell");

        var action = new NamedAction ("cell.show-picker");
        var alt_trigger = ShortcutTrigger.parse_string ("Return|KP_Enter|space");
        var shortcut = new Shortcut.with_arguments (alt_trigger, action, "b", true);
        add_shortcut (shortcut);
        alt_trigger = ShortcutTrigger.parse_string ("<Primary>Return|<Primary>space|<Primary>KP_Enter");
        shortcut = new Shortcut.with_arguments (alt_trigger, action, "b", false);
        add_shortcut (shortcut);

        new_shortcut ("cell.insert-value", "Delete|BackSpace|KP_0|0", 0);
        for (int i = 1; i < 10; i++)
        {
            string accel = i.to_string ();
            accel = accel + "|KP_" + accel;
            value_shortcuts[i - 1] = new_shortcut ("cell.insert-value", accel, i);

            accel = i.to_string ();
            accel = "<Primary>" + accel + "|<Primary>KP_" + accel;
            earmark_shortcuts[i - 1] = new_shortcut ("cell.insert-earmark", accel, i);
        }
    }

    private class Shortcut new_shortcut (string name, string accelerator, int val)
    {
        var action = new NamedAction (name);
        var trigger = ShortcutTrigger.parse_string (accelerator);
        var shortcut = new Shortcut.with_arguments (trigger, action, "i", val);
        add_shortcut (shortcut);
        return shortcut;
    }

    private void insert_value (Variant? variant)
    {
        grid.number_picker.popdown ();
        value = variant.get_int32 ();
    }

    private void insert_earmark (Variant? variant)
    {
        grid.number_picker.popdown ();
        var key = variant.get_int32 ();

        if (value == 0)
        {
            var enabled = game.board.is_earmark_enabled (row, col, key);
            if (!enabled)
                game.enable_earmark (row, col, key);
            else
                game.disable_earmark (row, col, key);
        }
    }

    public SudokuCell (SudokuGame game, SudokuGrid grid, ref double zoom_value_multiplier, ref double zoom_earmark_multiplier, int row, int col)
    {
        this.game = game;
        this.grid = grid;
        this.zoom_value_multiplier = zoom_value_multiplier;
        this.zoom_earmark_multiplier = zoom_earmark_multiplier;
        this.set_accessible_role (AccessibleRole.BUTTON);

        this.row = row;
        this.col = col;

        value_label = new Label (this.value.to_string ());
        value_label.visible = value != 0;
        value_label.set_parent (this);
        value_label.add_css_class ("value");
        value_label.add_css_class ("numeric");

        focusable = true;
        can_focus = true;
        game.notify["paused"].connect(paused_cb);
        Sudoku.app.notify["earmark-mode"].connect(flip_shortcuts);

        button_controller = new GestureClick ();
        button_controller.set_button (0 /* all buttons */ );
        button_controller.released.connect (button_released_cb);
        add_controller (this.button_controller);

        long_press_controller = new GestureLongPress ();
        long_press_controller.pressed.connect (long_press_cb);
        add_controller (this.long_press_controller);

        earmarks = new SudokuEarmark[9];
        for (int num = 1; num < 10; num++)
        {
            earmarks[num - 1] = new SudokuEarmark (num.to_string ());
            earmarks[num - 1].visible = game.board.is_earmark_enabled(row, col, num);
            earmarks[num - 1].set_parent (this);
        }

        var action_group = new SimpleActionGroup ();

        insert_value_action = new SimpleAction ("insert-value", VariantType.INT32);
        insert_value_action.activate.connect (insert_value);
        action_group.add_action (insert_value_action);

        insert_earmark_action = new SimpleAction ("insert-earmark", VariantType.INT32);
        insert_earmark_action.activate.connect (insert_earmark);
        action_group.add_action (insert_earmark_action);

        show_picker_action = new SimpleAction ("show-picker", VariantType.BOOLEAN);
        show_picker_action.activate.connect (show_picker);
        action_group.add_action (show_picker_action);

        insert_action_group ("cell", action_group);

        update_fixed ();
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
                if (Sudoku.app.autoclean_earmarks)
                    game.insert_and_disable_related_earmarks (row, col, value);
                else
                    game.insert (row, col, value);
            }
        }
    }

    public void update_fixed ()
    {
        set_actions (!is_fixed);
        if (is_fixed)
            this.add_css_class ("fixed");
        else
            this.remove_css_class ("fixed");
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
            if (value)
                this.add_css_class ("highlight-number");
            else
                this.remove_css_class ("highlight-number");
        }
    }

    public void set_earmark_highlight (int num, bool enabled)
    {
        earmarks[num - 1].highlight = enabled;
    }

    public void animate_earmark_removal (int num)
    {
        earmarks[num - 1].play_hide_animation ();
    }

    public void update_content_visibility ()
    {
        value_label.set_label (this.value.to_string ());
        value_label.visible = value != 0;
        for (int num = 1; num <= 9; num ++)
            update_earmark_visibility (num);
    }

    public bool grab_selection ()
    {
        grid.set_selected (row, col);
        return grab_focus ();
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

        bool double_click_wanted = Sudoku.app.number_picker_second_click ||
                                   (Sudoku.app.highlight_numbers && value != 0);

        if (is_fixed || (!selected && double_click_wanted))
        {
            grab_selection ();
            return;
        }

        ModifierType state;
        state = gesture.get_current_event_state ();
        bool control_pressed = (bool) (state & ModifierType.CONTROL_MASK);

        if (gesture.get_current_button () == BUTTON_PRIMARY)
            activate_action_variant ("cell.show-picker", !control_pressed);
        else if (gesture.get_current_button () == BUTTON_SECONDARY)
            activate_action_variant ("cell.show-picker", control_pressed);
    }

    private void long_press_cb (GestureLongPress gesture,
                                double           x,
                                double           y)
    {
        if (gesture.get_current_button () != BUTTON_PRIMARY &&
            gesture.get_current_button () != BUTTON_SECONDARY)
            return;

        gesture.set_state (EventSequenceState.CLAIMED);

        if (Sudoku.app.earmark_mode)
            activate_action_variant ("cell.show-picker", true);
        else
            activate_action_variant ("cell.show-picker", false);
    }

    private void show_picker (Variant? wants_value)
    {
        grab_selection ();

        bool value_picker = wants_value.get_boolean() ^ Sudoku.app.earmark_mode;

        if (value_picker)
            grid.number_picker.show_value_picker (this);
        else
            grid.number_picker.show_earmark_picker (this);
    }

    private void flip_shortcuts ()
    {
        for (int i = 0; i < 9; i++)
        {
            var copy = earmark_shortcuts[i].get_trigger ();
            earmark_shortcuts[i].set_trigger (value_shortcuts[i].get_trigger ());
            value_shortcuts[i].set_trigger (copy);
        }
    }

    private void set_actions (bool enabled)
    {
        insert_value_action.set_enabled (enabled);
        insert_earmark_action.set_enabled (enabled);
        show_picker_action.set_enabled (enabled);
    }

    private void paused_cb ()
    {
        if (game.paused)
        {
            add_css_class ("paused");
            set_actions (false);
        }
        else
        {
            remove_css_class ("paused");
            set_actions (!is_fixed);
        }
    }

    public void update_earmark_visibility (int num)
    {
        earmarks[num - 1].skip_animation ();
        earmarks[num - 1].set_visible (game.board.is_earmark_enabled(row, col, num));
    }

    public void update_value_warnings ()
    {
        if (value == 0)
            return;

        bool error = false;

        if (Sudoku.app.duplicate_warnings && game.board.broken_coords.contains (Coord (row, col)))
            error = true;

        else if (Sudoku.app.solution_warnings)
        {
            int solution = game.board.get_solution (row, col);
            if (solution != 0)
                error = this.value != solution;
        }

        if (error)
            value_label.add_css_class ("error");
        else
            value_label.remove_css_class ("error");
    }

    public void update_all_earmark_warnings ()
    {
        if (value != 0)
            return;

        var marks = game.board.get_earmarks (row, col);
        for (int num = 1; num <= marks.length; num++)
            if (marks[num - 1])
                update_earmark_warning (num);
    }

    public void update_earmark_warning (int num)
    {
        earmarks[num - 1].error =  Sudoku.app.earmark_warnings && !game.board.is_possible (row, col, num);
    }

    public override bool focus (DirectionType direction)
    {
        grid.set_selected (row, col);
        return base.focus (direction);
    }

    public override void size_allocate (int width,
                                        int height,
                                        int baseline)
    {
        int zoomed_size = (int) (height * zoom_value_multiplier);
        set_font_size (value_label, zoomed_size);

        Widget child = get_last_child ();
        while (child != null)
        {
            if (child == grid.number_picker)
            {
                grid.number_picker.present ();
                break;
            }

            child = child.get_prev_sibling ();
        }

        Requisition nat;
        value_label.get_preferred_size (null, out nat);
        int value_width = int.min (nat.width, width);
        int value_height = int.min (nat.height, height);

        Allocation value_allocation = {(width - value_width) / 2, (height - value_height) / 2, nat.width, nat.height};
        value_label.allocate_size (value_allocation, baseline);

        int earmark_width, earmark_height;
        int max_earmark_size = width / 3; //3 earmarks per row and per column
        int num = 0;

        zoomed_size = (int) (height * zoom_earmark_multiplier);
        for (int row_tmp = 2; row_tmp >= 0; row_tmp--)
            for (int col_tmp = 0; col_tmp < 3; col_tmp++)
            {
                set_font_size (earmarks[num].label, zoomed_size);
                earmarks[num].get_preferred_size (null, out nat);
                earmark_width = int.min (max_earmark_size, nat.width);
                earmark_height = int.min (max_earmark_size, nat.height);

                Allocation earmark_allocation = {col_tmp * max_earmark_size + (max_earmark_size - earmark_width) / 2,
                                                 row_tmp * max_earmark_size + (max_earmark_size - earmark_height) / 2,
                                                 earmark_width, earmark_height};
                earmarks[num].allocate_size (earmark_allocation, baseline);

                num++;
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
        foreach (var earmark in earmarks)
            earmark.unparent ();
        base.dispose ();
    }
}
