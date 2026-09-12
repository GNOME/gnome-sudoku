/* -*- Mode: rust; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2026 Johan GAY
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


use adw::prelude::*;
use adw::subclass::prelude::*;

use gtk::glib;
use gtk::glib::closure_local;

use crate::cell::SudokuCell;
use crate::lib::enums::CompatValue;
use crate::lib::backend::SudokuBackend;
use crate::lib::enums::Coord;

use std::{cell::{Cell, OnceCell}};

use crate::{earmark_picker::SudokuEarmarkPicker, value_picker::SudokuValuePicker};

mod imp {

    use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuNumberPicker {
        const NAME: &'static str = "SudokuPickerPopover";
        type Type = super::SudokuPickerPopover;
        type ParentType = gtk::Popover;
    }

    pub struct SudokuNumberPicker {
        pub backend: OnceCell<SudokuBackend>,
        pub picker_stack: gtk::Stack,
        pub value_picker: SudokuValuePicker,
        pub earmark_picker: SudokuEarmarkPicker,
        pub state: Cell<Option<PopoverPickerState>>
    }

    impl ObjectImpl for SudokuNumberPicker {
        fn constructed(&self) {
            self.picker_stack.add_child(&self.value_picker);
            self.value_picker.connect_closure("finished", false, closure_local!(
                #[weak(rename_to = picker_popover)] self.obj(),
                move |_ : SudokuValuePicker|
                picker_popover.popdown()
            ));

            self.picker_stack.add_child(&self.earmark_picker);
            self.earmark_picker.connect_closure("finished", false, closure_local!(
                #[weak(rename_to = picker_popover)] self.obj(),
                move |_ : SudokuEarmarkPicker|
                picker_popover.popdown()
            ));
            self.obj().set_child(Some(&self.picker_stack));

            self.parent_constructed();
        }
    }

    impl Default for SudokuNumberPicker {
        fn default() -> Self {
            let stack = glib::Object::builder()
                .property("interpolate-size", true)
                .property("vhomogeneous", false)
                .build();

            Self {
                backend: Default::default(),
                picker_stack: stack,
                value_picker: SudokuValuePicker::new_unitialized(),
                earmark_picker: SudokuEarmarkPicker::new_unitialized(),
                state: Default::default()
            }
        }
    }

    impl WidgetImpl for SudokuNumberPicker {}
    impl PopoverImpl for SudokuNumberPicker {
        fn closed(&self) {
            self.parent_closed();
            if let Some(state) = self.state.get() {
                if state == PopoverPickerState::ValuePicker {
                    self.value_picker.disconnect_picker ();
                }
                else {
                    self.earmark_picker.disconnect_picker ();
                }
                self.state.set(None);
            }
            let cell = self.obj().parent().unwrap().downcast::<SudokuCell>().unwrap();
            cell.drop_picker();
            self.obj().unparent();
        }
    }
}

glib::wrapper! {
    pub struct SudokuPickerPopover(ObjectSubclass<imp::SudokuNumberPicker>)
        @extends gtk::Popover, gtk::Widget,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget, gtk::Native, gtk::ShortcutManager;
}

impl SudokuPickerPopover {
    pub fn new_unitialized () -> Self {
        let picker_popover : Self = glib::Object::builder()
            .property("autohide", false)
            .property("can-focus", false)
            .build();

        picker_popover
    }

    pub fn init (&self, backend: &SudokuBackend) {
        self.imp().backend.set(backend.clone()).expect("Picker Popover is already initialized");
        self.imp().value_picker.init(backend);
        self.imp().earmark_picker.init(backend);
    }

    /* pub fn popdown_if_not_parent (&self, cell: &SudokuCell) {
        if let Some(parent) = self.parent() {
            let parent = parent.downcast::<SudokuCell>().unwrap();
            if parent != *cell {
                self.popdown();
            }
        }
    } */

    pub fn show_value_picker (&self, cell: &SudokuCell) {
        let imp = self.imp();

        if let Some(state) = imp.state.get() {
            match state {
                PopoverPickerState::ValuePicker => {
                    self.popdown();
                    return;
                }

                PopoverPickerState::EarmarkPicker => {
                    self.imp().earmark_picker.disconnect_picker ();
                    if imp.backend.get().unwrap().earmark_mode() {
                        imp.picker_stack.set_transition_type(gtk::StackTransitionType::SlideLeft);
                    }
                    else {
                        imp.picker_stack.set_transition_type(gtk::StackTransitionType::SlideRight);
                    }
                    imp.picker_stack.set_visible_child (&imp.value_picker);
                }
            }
        }
        else {
            self.set_parent(cell);
            imp.picker_stack.set_visible_child (&imp.value_picker);
            self.popup();
        }

        imp.value_picker.connect_picker (cell.pos());
        imp.state.set(Some(PopoverPickerState::ValuePicker));
    }

    pub fn show_earmark_picker (&self, cell: &SudokuCell) {
        let imp = self.imp();

        if let Some(state) = imp.state.get() {
            match state {
                PopoverPickerState::EarmarkPicker => {
                    self.popdown();
                    return;
                }

                PopoverPickerState::ValuePicker => {
                    self.imp().value_picker.disconnect_picker ();
                    if imp.backend.get().unwrap().earmark_mode() {
                        imp.picker_stack.set_transition_type(gtk::StackTransitionType::SlideRight);
                    }
                    else {
                        imp.picker_stack.set_transition_type(gtk::StackTransitionType::SlideLeft);
                    }
                    imp.picker_stack.set_visible_child (&imp.earmark_picker);
                }
            }
        }
        else {
            self.set_parent(cell);
            imp.picker_stack.set_visible_child (&imp.earmark_picker);
            self.popup();
        }

        imp.earmark_picker.connect_picker (cell.pos());
        imp.state.set(Some(PopoverPickerState::EarmarkPicker));
    }
}

#[macro_export]
macro_rules! build_picker {
    ($obj: ty) =>  {
        glib::Object::builder::<$obj>()
            .property("css-name", "sudoku-picker")
            .property("row-spacing", 3)
            .property("column-spacing", 3)
            .build()
    }
}

pub trait PickerBaseImp {
    fn value_changed_cb (&self, new_val: CompatValue);
    fn earmark_changed_cb (&self, pos: Coord, num: usize, enabled: bool);
}

pub trait PickerBase {
    fn connect_picker(&self, pos: Coord);
    fn disconnect_picker(&self);
}

#[derive(Clone, Copy, PartialEq)]
pub enum PopoverPickerState {
    ValuePicker,
    EarmarkPicker
}
