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

use std::cell::Cell;

use gtk::{NamedAction, ShortcutAction, ShortcutTrigger, glib::{object::Cast, variant::ToVariant}, subclass::widget::WidgetClassExt};

use crate::picker_popover;

pub fn new_shortcut <T> (klass: &mut T, name: &str, accelerator: &str)
where T: WidgetClassExt {
    let action = NamedAction::new(&name);
    let trigger = ShortcutTrigger::parse_string(&accelerator);
    let shortcut = &gtk::Shortcut::new(trigger, Some(action.upcast::<ShortcutAction>()));
    klass.add_shortcut(shortcut);
}

pub fn new_shortcut_with_args <A, B> (klass: &mut A, name: &str, accelerator: &str, arg: B)
where A: WidgetClassExt, B: ToVariant {
    let action = NamedAction::new(&name);
    let trigger = ShortcutTrigger::parse_string(&accelerator);
    let shortcut = &gtk::Shortcut::with_arguments(
        trigger, Some(action.upcast::<ShortcutAction>()), &arg.to_variant());
    klass.add_shortcut(shortcut);
}

#[macro_export]
macro_rules! create_cb_entry {
    ($obj: expr, $name: expr, $cb: ident) => {
        gio::ActionEntryBuilder::new($name)
            .activate(glib::clone!(
                    #[weak(rename_to = s)] $obj,
                    move |_, _, _|
                    s.$cb()
            ))
            .build()
    };
}

#[macro_export]
macro_rules! connect_cb_action {
    ($obj: expr, $action: expr, $cb: ident, $group: expr) => {
        $action.connect_activate(glib::clone!(
                #[weak(rename_to = s)] $obj,
                move |_, _|
                s.$cb()
        ));
        $group.add_action(&$action)
    };
}

#[macro_export]
macro_rules! connect_cb_pref {
    ($obj: ident, $pref: ident, $cb: ident) => {
        $obj.backend().$pref(glib::clone!(
            #[weak(rename_to = s)] $obj,
            move |_|
            s.$cb()
        ));
    };
}

#[macro_export]
macro_rules! connect_cb_action_with_arg {
    ($obj: ident, $action: expr, $cb: ident, $group: expr) => {
        $action.connect_activate(glib::clone!(
                #[weak(rename_to = s)] $obj,
                move |_, arg|
                s.$cb(arg)
        ));
        $group.add_action(&$action)
    };
}

//copy pasted from upstream to avoid using rust nightly
pub unsafe trait CloneFromCell: Clone {}
unsafe impl CloneFromCell for picker_popover::SudokuPickerPopover {}
unsafe impl<T: CloneFromCell> CloneFromCell for Option<T> {}
/// Get a clone of the `Cell` that contains a copy of the original value.
///
/// This allows a cheaply `Clone`-able type like an `Rc` to be stored in a `Cell`, exposing the
/// cheaper `clone()` method.
///
/// # Examples
///
/// ```
/// #![feature(cell_get_cloned)]
///
/// use core::cell::Cell;
/// use std::rc::Rc;
///
/// let rc = Rc::new(1usize);
/// let c1 = Cell::new(rc);
/// let c2 = c1.get_cloned();
/// assert_eq!(*c2.into_inner(), 1);
/// ```
// `CloneFromCell` can be implemented for types that don't have indirection and which don't access
// `Cell`s in their `Clone` implementation. A commonly-used subset is covered here.
pub fn get_cloned <T: CloneFromCell> (cell: &Cell<T>) -> Cell<T> {
    // SAFETY: T is CloneFromCell, which guarantees that this is sound.
    Cell::new(T::clone(unsafe { &*cell.as_ptr() }))
}
