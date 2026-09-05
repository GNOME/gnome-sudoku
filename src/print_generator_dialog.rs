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
use gtk::glib::subclass::InitializingObject;
use gtk::CompositeTemplate;
use gtk::PrintOperationResult;

use crate::lib::backend::SudokuBackend;
use crate::menu_button::SudokuMenuButton;
use crate::lib::board::SudokuBoard;
use crate::lib::enums::DifficultyCategory;
use crate::{game, printer::SudokuPrinter};

use std::cell::OnceCell;

mod imp {
    use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuPrintGeneratorDialog {
        const NAME: &'static str = "SudokuPrintGeneratorDialog";
        type Type = super::SudokuPrintGeneratorDialog;
        type ParentType = adw::Dialog;

        fn class_init(klass: &mut Self::Class) {
            klass.bind_template();
            klass.bind_template_callbacks();
        }

        fn instance_init(obj: &InitializingObject<Self>) {
            SudokuMenuButton::ensure_type();
            obj.init_template();
        }
    }

    #[derive(Default, CompositeTemplate)]
    #[template(resource = "/org/gnome/Sudoku/ui/print-generator-dialog.ui")]
    pub struct SudokuPrintGeneratorDialog {
        pub backend: OnceCell<SudokuBackend>,
        #[template_child]
        pub puzzles_row: TemplateChild<adw::SpinRow>,
        #[template_child]
        pub puzzles_per_page_row: TemplateChild<adw::SpinRow>,
        #[template_child]
        pub difficulty_row: TemplateChild<adw::ComboRow>,
        #[template_child]
        pub print_current_puzzle_row: TemplateChild<adw::SwitchRow>,
    }

    #[gtk::template_callbacks]
    impl SudokuPrintGeneratorDialog {
        #[template_callback]
        fn print_button_pressed (&self, _: &gtk::Button) {
            let mut puzzles_to_generate = self.puzzles_row.adjustment().value() as u8;
            let puzzles_per_page = self.puzzles_per_page_row.adjustment().value() as i32;
            let difficulty_category: DifficultyCategory = (self.difficulty_row.selected() + 1).into();
            let mut boards : Vec<SudokuBoard> = Default::default();

            if self.print_current_puzzle_row.is_active() {
                boards.push(game!(self.backend.get().unwrap()).board().clone());
                puzzles_to_generate -= 1;
                if puzzles_to_generate == 0 {
                    self.send_to_printer(boards, puzzles_per_page);
                    return;
                }
            }

            let boards = SudokuBackend::generate_multiple_puzzles(
                difficulty_category,
                puzzles_to_generate
            );
            self.send_to_printer(boards, puzzles_per_page);
        }

        pub fn init (&self, backend: &SudokuBackend) {
            self.backend.set(backend.clone())
                .expect("Print Generator Dialog is already initialized");
            self.print_current_puzzle_row.set_visible(backend.game_exists());
            let p_otions = backend.print_options();
            self.puzzles_row.set_value(p_otions.0);
            self.puzzles_per_page_row.set_value(p_otions.1);
            self.difficulty_row.set_selected((p_otions.2 as i32 - 1) as u32);
        }

        fn send_to_printer (&self, boards: Vec<SudokuBoard>, puzzles_per_page: i32) {
            let printer = SudokuPrinter::new(boards, puzzles_per_page);
            let window : gtk::Window = self.obj().root().and_downcast::<gtk::Window>().unwrap();

            if printer.imp().print_sudoku (&window) == PrintOperationResult::Apply {
                for board in printer.imp().boards.get().unwrap() {
                    self.backend.get().unwrap().save_printed_board(&board);
                }
            }
        }
    }

    impl ObjectImpl for SudokuPrintGeneratorDialog {
        fn constructed(&self) {
            self.parent_constructed();

            //makes sure the number of puzzles to print is a factor of the puzzles per page
            self.puzzles_per_page_row.adjustment().connect_value_changed(glib::clone!(
                #[weak(rename_to = dialog)] self,
                move |adjustment|
                {
                    let per_page = adjustment.value();
                    dialog.puzzles_row.adjustment().set_step_increment(per_page);
                    dialog.puzzles_row.adjustment().set_page_increment(per_page * 5.0);
                    dialog.puzzles_row.adjustment().set_lower(per_page);
                    if dialog.puzzles_row.adjustment().value() as i64 % per_page as i64 != 0 {
                        dialog.puzzles_row.adjustment().set_value(
                            per_page - dialog.puzzles_row.adjustment().value() % per_page);
                    }
                }
            ));
        }

        fn dispose (&self) {
            let backend = &self.backend.get().unwrap();
            backend.set_print_options(
                self.puzzles_row.value(),
                self.puzzles_per_page_row.value(),
                DifficultyCategory::from(self.difficulty_row.selected() + 1)
            );
        }
    }

    impl WidgetImpl for SudokuPrintGeneratorDialog {}
    impl AdwDialogImpl for SudokuPrintGeneratorDialog {}
}

glib::wrapper! {
    pub struct SudokuPrintGeneratorDialog(ObjectSubclass<imp::SudokuPrintGeneratorDialog>)
        @extends gtk::Widget, adw::Dialog,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget, gtk::ShortcutManager;
}

impl SudokuPrintGeneratorDialog {
    pub fn new (backend: &SudokuBackend) -> Self {
        let dialog: Self = glib::Object::builder()
            .build();

        dialog.imp().init(backend);
        dialog
    }
}
