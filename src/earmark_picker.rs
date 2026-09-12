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
    impl ObjectSubclass for SudokuEarmarkPicker {
        const NAME: &'static str = "SudokuEarmarkPicker";
        type Type = super::SudokuEarmarkPicker;
        type ParentType = gtk::Grid;
    }

    pub struct SudokuEarmarkPicker {
        pub backend: OnceCell<SudokuBackend>,
        pub earmark_buttons: [gtk::ToggleButton; 9],
        pub lock_button: gtk::ToggleButton,
        pub clear_button: gtk::Button,
        pub cell: Cell<Option<Coord>>,
        pub value_cb_handler: Cell<Option<SignalHandlerId>>,
        pub earmark_cb_handler: Cell<Option<SignalHandlerId>>,
    }

    impl Default for SudokuEarmarkPicker {
        fn default() -> Self {
            let buttons: [_; 9] = {
                from_fn(|number| {
                    let button = gtk::ToggleButton::with_label(&(number + 1).to_string());
                    let label = button.child().unwrap();
                    label.add_css_class("numeric");
                    label.add_css_class("earmark");
                    button
                })
            };

            let lock_button = gtk::ToggleButton::new();
            lock_button.set_icon_name("sudoku-lock-symbolic");
            lock_button.set_tooltip_text(Some(&gettextrs::gettext("Lock")));

            Self {
                backend: Default::default(),
                cell: Default::default(),
                lock_button,
                value_cb_handler: Default::default(),
                earmark_cb_handler: Default::default(),
                clear_button: gtk::Button::with_label(&gettextrs::gettext("Clear")),
                earmark_buttons: buttons,
            }
        }
    }

    impl ObjectImpl for SudokuEarmarkPicker {
        fn constructed(&self) {
            self.clear_button.connect_clicked(glib::clone!(
                #[weak(rename_to = earmark_picker)] self,
                move |_|
                {
                    let pos = earmark_picker.current_position();
                    earmark_picker.backend().game_clear_cell(pos);
                    if !earmark_picker.lock_button.is_active() {
                        earmark_picker.finished();
                    }
                }
            ));
            self.obj().attach (&self.clear_button, 0, 4, 2, 1);

            self.lock_button.connect_toggled(glib::clone!(
                #[weak(rename_to = earmark_picker)] self,
                move |lock_button: &gtk::ToggleButton|
                {
                    if lock_button.is_active() {
                        lock_button.set_tooltip_text(Some(&gettextrs::gettext("Unlock")));
                    }
                    else {
                        lock_button.set_tooltip_text(Some(&gettextrs::gettext("Lock")));
                        earmark_picker.finished();
                    }
                }
            ));
            self.obj().attach (&self.lock_button, 2, 4, 1, 1);

            for row_block in (0..3).rev(){
                for col_block in 0..3  {
                    let index = col_block + (2 - row_block) * 3;
                    let button = &self.earmark_buttons[index];

                    button.connect_clicked(glib::clone!(
                        #[weak(rename_to = earmark_picker)] self,
                        move |_|
                        {
                            let pos = earmark_picker.current_position();
                            earmark_picker.backend().game_toggle_earmark(pos, index);
                            if !earmark_picker.lock_button.is_active() {
                                earmark_picker.finished();
                            }
                        }
                    ));

                    self.obj().attach(button, col_block as i32, row_block as i32, 1, 1);
                }
            }

            self.parent_constructed();
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

    impl SudokuEarmarkPicker {
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

        pub fn set_buttons_sensitive (&self, enabled: bool) {
            for button in &self.earmark_buttons {
                button.set_sensitive(enabled);
            }
        }

        pub fn update_buttons_active (&self, pos: Coord) {
            for i in 0..9 {
                let has_earmark = self.backend().game_earmark(pos, i);
                self.earmark_buttons[i].set_active(has_earmark);
            }
        }
    }

    impl PickerBaseImp for SudokuEarmarkPicker {
        fn value_changed_cb (&self, new_val: CompatValue) {
            let new_val: Option<usize> = new_val.into();
            self.clear_button.set_sensitive(new_val.is_some());
            self.set_buttons_sensitive(!new_val.is_some());
        }

        fn earmark_changed_cb (&self, pos: Coord, num: usize, enabled: bool) {
            let has_earmarks = self.backend().game_has_earmarks(pos);
            self.clear_button.set_sensitive(has_earmarks);
            self.earmark_buttons[num].set_active(enabled);
        }
    }
    impl WidgetImpl for SudokuEarmarkPicker {}
    impl GridImpl for SudokuEarmarkPicker {
    }
}

glib::wrapper! {
    pub struct SudokuEarmarkPicker(ObjectSubclass<imp::SudokuEarmarkPicker>)
        @extends gtk::Grid, gtk::Widget,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget, gtk::Orientable;
}

impl SudokuEarmarkPicker {
    pub fn new_unitialized () -> Self {
        let earmark_picker = build_picker!(Self);
        earmark_picker
    }

    pub fn init (&self, backend: &SudokuBackend) {
        self.imp().backend.set(backend.clone()).expect("Earmark Picker is already initialized");
    }
}

impl PickerBase for SudokuEarmarkPicker {
    fn connect_picker(&self, pos: Coord) {
        let imp = self.imp();
        imp.cell.set(Some(pos));
        let backend = imp.backend();
        let binding = backend.game();
        let game = binding.as_ref().unwrap();
        let handle = game.connect_closure("value-changed", false, closure_local!{
            #[weak(rename_to = earmark_picker)] imp,
            move |_ : SudokuGame, _: i32, _: i32, _: CompatValue, new_val: CompatValue| {
                earmark_picker.value_changed_cb (new_val);
            }
        });

        imp.value_cb_handler.set(Some(handle));
        let handle = game.connect_closure("earmark-changed", false, closure_local!{
            #[weak(rename_to = earmark_picker)] imp,
            move |_ : SudokuGame, row: i32, col: i32, num: i32, enabled: bool| {
                earmark_picker.earmark_changed_cb (
                    Coord {row: row as usize, col: col as usize},
                    num as usize,
                    enabled
                );
            }
        });
        imp.earmark_cb_handler.set(Some(handle));

        let has_value = backend.game_value(pos).is_some();
        let has_earmarks = backend.game_has_earmarks(pos);
        imp.clear_button.set_sensitive(has_value || has_earmarks);
        imp.set_buttons_sensitive(!has_value);
        imp.update_buttons_active(pos);
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
