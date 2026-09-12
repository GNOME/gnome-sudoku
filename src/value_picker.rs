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

use gtk::glib::{self, closure_local};
use gtk::glib::{SignalHandlerId, subclass::Signal};

use std::cell::{Cell, OnceCell};
use std::{array::from_fn, sync::OnceLock};

use crate::lib::backend::SudokuBackend;
use crate::lib::enums::Coord;
use crate::lib::game::SudokuGame;
use crate::lib::enums::CompatValue;
use crate::{build_picker, game};
use crate::picker_popover::{PickerBase, PickerBaseImp};

mod imp {

    use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuValuePicker {
        const NAME: &'static str = "SudokuValuePicker";
        type Type = super::SudokuValuePicker;
        type ParentType = gtk::Grid;
    }

    pub struct SudokuValuePicker {
        pub backend: OnceCell<SudokuBackend>,
        pub value_buttons: [gtk::Button; 9],
        pub clear_button: gtk::Button,
        pub cell: Cell<Option<Coord>>,
        pub value_cb_handler: Cell<Option<SignalHandlerId>>,
        pub earmark_cb_handler: Cell<Option<SignalHandlerId>>,
    }

    impl Default for SudokuValuePicker {
        fn default() -> Self {
            let buttons: [_; 9] = {
                from_fn(|number| {
                    let button = gtk::Button::with_label(&(number + 1).to_string());
                    let label = button.child().unwrap();
                    label.add_css_class("numeric");
                    label.add_css_class("value");
                    button
                })
            };

            Self {
                backend: Default::default(),
                cell: Default::default(),
                value_cb_handler: Default::default(),
                earmark_cb_handler: Default::default(),
                clear_button: gtk::Button::with_label(&gettextrs::gettext("Clear")),
                value_buttons: buttons,
            }
        }
    }

    impl ObjectImpl for SudokuValuePicker {
        fn constructed(&self) {
            self.parent_constructed();
            self.obj().attach (&self.clear_button, 0, 4, 3, 1);

            self.clear_button.connect_clicked(glib::clone!(
                #[weak(rename_to = value_picker)] self,
                move |_|
                {
                    let pos = value_picker.current_position();
                    value_picker.backend().game_clear_cell(pos);
                    value_picker.finished();
                }
            ));

            for row_block in (0..3).rev(){
                for col_block in 0..3  {
                    let index = col_block + (2 - row_block) * 3;
                    let button = &self.value_buttons[index];

                    button.connect_clicked(glib::clone!(
                        #[weak(rename_to = value_picker)] self,
                        move |_|
                        {
                            let pos = value_picker.current_position();
                            value_picker.backend().game_set_value(pos, index);
                            value_picker.finished();
                        }
                    ));

                    self.obj().attach(button, col_block as i32, row_block as i32, 1, 1);
                }
            }
        }

        fn signals() -> &'static [Signal] {
            static SIGNALS: OnceLock<Vec<Signal>> = OnceLock::new();
            SIGNALS.get_or_init(|| {
                vec![
                    Signal::builder("finished")
                        .build(),
                ]
            })
        }
    }

    impl SudokuValuePicker {
        pub fn current_position (&self) -> Coord {
            let row = self.cell.get().unwrap().row;
            let col = self.cell.get().unwrap().col;
            Coord{row, col}
        }

        pub fn finished (&self) {
            self.obj().emit_by_name::<()>("finished", &[]);
        }

        pub fn backend (&self) -> &SudokuBackend {
            self.backend.get().unwrap()
        }
    }

    impl PickerBaseImp for SudokuValuePicker {
        fn value_changed_cb (&self, new_val: CompatValue) {
            let new_val: Option<usize> = new_val.into();
            self.clear_button.set_visible(new_val.is_some());
            //self.clear_button.set_sensitive(new_val.is_some());
        }

        fn earmark_changed_cb (&self, pos: Coord, _: usize, _: bool) {
            let has_earmarks = self.backend().game_has_earmarks(pos);
            let value = self.backend().game_value(pos);
            //self.clear_button.set_sensitive(has_earmarks);
            self.clear_button.set_visible(value.is_some() || has_earmarks);
        }
    }
    impl WidgetImpl for SudokuValuePicker {}
    impl GridImpl for SudokuValuePicker {
    }
}

glib::wrapper! {
    pub struct SudokuValuePicker(ObjectSubclass<imp::SudokuValuePicker>)
        @extends gtk::Grid, gtk::Widget,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget, gtk::Orientable;
}

impl SudokuValuePicker {
    pub fn new_unitialized () -> Self {
        let value_picker = build_picker!(Self);
        value_picker
    }

    pub fn init (&self, backend: &SudokuBackend) {
        self.imp().backend.set(backend.clone()).expect("Value Picker is already initialized");
    }
}

impl PickerBase for SudokuValuePicker {
    fn connect_picker(&self, pos: Coord) {
        let imp = self.imp();
        imp.cell.set(Some(pos));
        let backend = imp.backend();
        let binding = backend.game();
        let game = binding.as_ref().unwrap();
        let handle = game.connect_closure("value-changed", false, closure_local!{
            #[weak(rename_to = value_picker)] imp,
            move |_ : SudokuGame, _: i32, _: i32, _: CompatValue, new_val: CompatValue| {
                value_picker.value_changed_cb (new_val);
            }
        });

        imp.value_cb_handler.set(Some(handle));
        let handle = game.connect_closure("earmark-changed", false, closure_local!{
            #[weak(rename_to = value_picker)] imp,
            move |_ : SudokuGame, row: i32, col: i32, num: i32, enabled: bool| {
                value_picker.earmark_changed_cb (
                    Coord {row: row as usize, col: col as usize},
                    num as usize,
                    enabled
                );
            }
        });
        imp.earmark_cb_handler.set(Some(handle));

        let has_value = backend.game_value(pos).is_some();
        let has_earmarks = backend.game_has_earmarks(pos);
        imp.clear_button.set_visible(has_value || has_earmarks);
    }

    fn disconnect_picker(&self) {
        if let Some(handle) = self.imp().value_cb_handler.take() {
            game!(self.imp().backend()).disconnect(handle);
        }

        if let Some(handle) = self.imp().earmark_cb_handler.take() {
            game!(self.imp().backend()).disconnect(handle);
        }
    }
}
