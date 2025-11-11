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

[GtkTemplate (ui = "/org/gnome/Sudoku/ui/start-view.ui")]
public class SudokuStartView : Adw.Bin
{
    [GtkChild] public unowned Adw.HeaderBar headerbar;

    [GtkChild] private unowned CheckButton custom_check;
    [GtkChild] private unowned CheckButton easy_check;
    [GtkChild] private unowned CheckButton medium_check;
    [GtkChild] private unowned CheckButton hard_check;
    [GtkChild] private unowned CheckButton very_hard_check;

    [GtkChild] private unowned Button start_button;
    [GtkChild] private unowned Button open_button_pill;
    [GtkChild] private unowned Button back_button;
    [GtkChild] private unowned Stack start_open_stack;

    [GtkChild] private unowned Box open_and_shared_box;

    private SudokuBackend backend;
    private uint clipboard_timeout;
    private ulong clipboard_handle = 0;
    private Cancellable clipboard_cancellable;
    private string? clipboard_string;
    public Clipboard clipboard;

    static construct {
        typeof (SudokuMenuButton).ensure ();

        var action = new NamedAction ("app.back");
        var alt_trigger = ShortcutTrigger.parse_string ("<Alt>Left|<Alt>KP_Left");
        var shortcut = new Shortcut (alt_trigger, action);
        add_shortcut (shortcut);
    }

    public void init (SudokuBackend backend, Clipboard clipboard)
    {
        this.backend = backend;
        this.clipboard = clipboard;
        activate_difficulty_checkbutton ();

        this.backend.notify["tgame"].connect (() => {
            if (backend.tgame == null)
                start_open_stack.set_visible_child (open_button_pill);
            else if (custom_check.active == true)
                start_open_stack.set_visible_child (open_and_shared_box);
        });
    }

    [GtkCallback]
    private void start_game_cb (Button btn)
    {
        if (this.easy_check.active)
            (this as Widget)?.activate_action ("app.start-game", "i", 1);
        else if (this.medium_check.active)
            (this as Widget)?.activate_action ("app.start-game", "i", 2);
        else if (this.hard_check.active)
            (this as Widget)?.activate_action ("app.start-game", "i", 3);
        else if (this.very_hard_check.active)
            (this as Widget)?.activate_action ("app.start-game", "i", 4);
    }

    [GtkCallback]
    private void open_file_cb ()
    {
        ((Widget)this).activate_action ("app.open-file", null);
    }

    [GtkCallback]
    private void custom_checkbutton_activated_cb ()
    {
        if (clipboard_handle == 0)
        {
            clipboard_handle = clipboard.changed.connect (clipboard_cb);
            clipboard_cb ();
        }

        if (backend.tgame == null)
            start_open_stack.set_visible_child (open_button_pill);
        else
            start_open_stack.set_visible_child (open_and_shared_box);
    }

    [GtkCallback]
    private void difficulty_checkbutton_activated_cb ()
    {
        start_open_stack.set_visible_child (start_button);
        if (clipboard_handle != 0)
        {
            clipboard.changed.disconnect (clipboard_cb);
            clipboard_handle = 0;
        }
    }

    [GtkCallback]
    private void start_shared_game_cb ()
    {
        backend.start_shared_game ();
        clipboard_string = null;
    }

    public void set_back_button_visible (bool enabled)
    {
        back_button.visible = enabled;
    }

    public void activate_difficulty_checkbutton ()
    {
        switch (Sudoku.app.start_button_selected)
        {
            case DifficultyCategory.EASY:
                easy_check.active = true;
                start_open_stack.set_visible_child (start_button);
                return;
            case DifficultyCategory.MEDIUM:
                medium_check.active = true;
                start_open_stack.set_visible_child (start_button);
                return;
            case DifficultyCategory.HARD:
                hard_check.active = true;
                start_open_stack.set_visible_child (start_button);
                return;
            case DifficultyCategory.VERY_HARD:
                very_hard_check.active = true;
                start_open_stack.set_visible_child (start_button);
                return;
            case DifficultyCategory.CUSTOM:
                start_open_stack.set_visible_child (open_button_pill);
                custom_check.active = true;
                return;
            default:
                assert_not_reached ();
        }
    }

    public void disconnect_clipboard ()
    {
        if (clipboard_handle != 0)
        {
            clipboard.changed.disconnect (clipboard_cb);
            clipboard_handle = 0;
        }
    }

    public void connect_clipboard ()
    {
        if (clipboard_handle == 0 && custom_check.active)
        {
            clipboard_handle = clipboard.changed.connect (clipboard_cb);
            clipboard_cb ();
        }
    }

    private void clipboard_cb ()
    {
        clipboard_cancellable = new Cancellable ();

        clipboard_timeout = Timeout.add_once (200, () => {
            clipboard_cancellable.cancel ();
        });

        clipboard.read_text_async.begin (clipboard_cancellable, (obj, res) =>{
            try
            {
                var string = clipboard.read_text_async.end (res);
                if (clipboard_timeout != 0)
                {
                    Source.remove (clipboard_timeout);
                    clipboard_timeout = 0;
                }
                if (clipboard_string == null || clipboard_string != string)
                {
                    backend.check_clipboard (string);
                    clipboard_string = string;
                }
            }
            catch (Error e)
            {
                print ("%s", e.message);
                /* if (e.code != IOError.NOT_FOUND && e.code != IOError.NOT_SUPPORTED)
                    warning ("Error: %s, %s, dom:%s", e.message, e.code.to_string (), e.domain.to_string ()); */
            }
        });
    }

    public override bool grab_focus ()
    {
        return start_open_stack.visible_child.grab_focus ();
    }
}
