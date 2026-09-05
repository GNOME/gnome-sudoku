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

use gtk::glib;
use gtk::prelude::*;
use gtk::subclass::prelude::*;
use gtk::cairo;
use gtk::pango;
use gtk::{PrintContext, PrintOperationResult, TextDirection};

use adw::prelude::{AdwDialogExt, AlertDialogExt};

use crate::lib::board::SudokuBoard;

use std::{array::from_fn, cell::OnceCell};

mod imp {
    use super::*;

    pub struct SudokuPrinter {
        pub boards: OnceCell<Vec<SudokuBoard>>,
        pub print_operation: gtk::PrintOperation,
        pub margin: i32,
        pub sudokus_count: OnceCell<i32>,
        pub sudokus_per_page: OnceCell<i32>,
    }

    impl SudokuPrinter {
        pub fn print_sudoku (&self, window: &gtk::Window) -> PrintOperationResult {
            let result = self.print_operation.run(gtk::PrintOperationAction::PrintDialog, Some(window));
            match result {
                Ok(print_op) => print_op,
                Err(e) => {
                    let mut title = gettextrs::gettext("Error printing file");
                    title = format!("{}\n{}", title, e.message());
                    let dialog = adw::AlertDialog::builder().title(title).build();
                    dialog.add_response("close", &gettextrs::gettext("_Close"));
                    dialog.present(Some(window));
                    PrintOperationResult::Error
                }
            }
        }

        pub fn draw_page_cb (&self, context: &PrintContext, page_nr: i32) {
            let cc = context.cairo_context();
            let width = context.width();
            let height = context.height();

            cc.set_font_size(12.0);
            cc.select_font_face("Sans", cairo::FontSlant::Normal, cairo::FontWeight::Bold);

            let label_extents = cc.text_extents("Ww").expect("Cairo Error");

            let result = self.fit_squares_in_rectangle(width, height, label_extents.height(), self.margin);
            let best_square_size = result.0;
            let n_across = result.1;
            let n_down = result.2;
            let margin_x = (width - best_square_size * n_across as f64) / (n_across as f64 + 1.0);
            let margin_y = (height - best_square_size * n_down as f64) / (n_down as f64 + 1.0);
            let spp = self.sudokus_per_page.get().unwrap();
            let start = page_nr * self.sudokus_per_page.get().unwrap();
            let end = i32::min(start + spp, self.boards.get().unwrap().len() as i32);
            let mut index = 0;
            let sudokus_on_page = &self.boards.get().unwrap()[start as usize..end as usize];

            for sudoku in sudokus_on_page {
                let left = margin_x + (index % n_across) as f64 * (best_square_size + margin_x);
                let top = margin_y + label_extents.height() + (index / n_across) as f64 
                    * (best_square_size + margin_y + label_extents.height());
                let label = sudoku.difficulty_category.to_string();
                let layout = pangocairo::functions::create_layout(&cc);
                layout.set_font_description(Some(&pango::FontDescription::from_string("Sans Bold 9")));
                layout.set_text(&label);

                let layout_size = layout.size();
                let layout_width = layout_size.0 / pango::SCALE;
                let layout_height = layout_size.1 / pango::SCALE;
                cc.move_to(left + (best_square_size - layout_width as f64) / 2.0,
                    top - layout_height as f64);
                cc.set_source_rgb(0.0, 0.0, 0.0);
                pangocairo::functions::show_layout(&cc, &layout);

                self.draw_sudoku(&cc, sudoku, best_square_size, left, top);
                index += 1;
            }
        }

        fn fit_squares_in_rectangle (&self, width: f64, height: f64, label_height: f64, margin: i32)
            -> (f64, i32, i32)
        {
            let n = self.sudokus_per_page.get().unwrap();
            let mut across = 1;
            let mut down = n.clone();
            let mut n_across = 1;

            let mut best_square_size = 0.0;
            loop {
                if n_across > *n {
                    break;
                }
                let n_down = (n + n_across - 1) / n_across;
                let mut across_size = width - ((n_across + 1) * margin) as f64;
                across_size /= n_across as f64;

                let mut down_size = height - ((n_down + 1) * margin) as f64 - n_down as f64 * label_height;
                down_size /= n_down as f64;

                let square_size = f64::min(across_size, down_size);
                if square_size > best_square_size {
                    best_square_size = square_size;
                    across = n_across;
                    down = n_down;

                }

                n_across += 1;
            }


            (best_square_size, across, down)
        }

        fn draw_sudoku (&self, cc: &cairo::Context, board: &SudokuBoard,
            size: f64, offset_x: f64, offset_y: f64)
        {
            let pencil_grey = [0.3, 0.3, 0.3];
            let background_color = [1.0, 1.0, 1.0];
            let border_color = [1.0, 1.0, 1.0];
            let line_color = [0.0, 0.0, 0.0];

            let sudoku_size = 9;
            let per_block = 3;
            let thin = size / 500.0;
            let thick = thin * 5.0;
            let border = thick;
            let white_space = size
                -(2.0 * border) as f64
                -(2.0 * thick) 
                -((per_block - 1) as f64 * thick)
                -((per_block * 2) as f64 * thin);

            let square_size = white_space / sudoku_size as f64;

            let font_size = (square_size / 2.0) as i32;
            let font_weight = cairo::FontWeight::Normal;

            //left, right, top, bottom
            let outer = [offset_x, offset_x + size, offset_y, offset_y + size];

            //Entire background
            cc.set_source_rgb(1.0, 1.0, 1.0);
            cc.rectangle(outer[0], outer[2], size, size);
            cc.fill().expect("Printer Error");

            //Outer border
            cc.set_line_join(cairo::LineJoin::Round);
            cc.set_line_width(border);
            cc.rectangle(outer[0] + border / 2.0, outer[2] + border / 2.0, size - border, size - border);

            //Inner background
            cc.set_source_rgb(background_color[0], background_color[1], background_color[2]);
            cc.fill_preserve().expect("Printer Error");

            //Border box
            cc.set_source_rgb(border_color[0], border_color[1], border_color[2]);
            cc.stroke().expect("Printer Error");

            //Outer thick lines
            cc.set_line_join(cairo::LineJoin::Miter);
            cc.set_line_width(thick);
            cc.rectangle(
                outer[0] + border + thick / 2.0,
                outer[2] + border + thick / 2.0,
                size - border * 2.0 - thick,
                size - border * 2.0 - thick
            );
            cc.set_source_rgb(line_color[0], line_color[1], line_color[2]);
            cc.stroke().expect("Printer Error");

            let mut pos = vec![0f64; sudoku_size + 1];
            let mut position = border + thick;
            pos[0] = position + square_size / 2.0;
            let mut last_line = 0.0;
            for n in 1..= sudoku_size {
                if  n % per_block == 0 {
                    cc.set_line_width(thick);
                    position += square_size + last_line / 2.0 + thick / 2.0;
                    last_line = thick;
                }
                else {
                    cc.set_line_width(thin);
                    position += square_size + last_line / 2.0 + thin / 2.0;
                    last_line = thin;
                }

                pos[n] = position + last_line / 2.0 + square_size / 2.0;
                cc.move_to(border + thick / 2.0 + offset_x, position + offset_y);
                cc.line_to(size - border - thick / 2.0 + offset_x, position + offset_y);
                cc.move_to(position + offset_x, border + thick / 2.0 + offset_y);
                cc.line_to(position + offset_x, size - border - thick / 2.0 + offset_y);
                cc.stroke().expect("Printer Error");
            }

            cc.set_font_size(font_size as f64);
            let sudoku: [[usize; 9]; 9] = from_fn(|row| from_fn(|col|
                board.cells[row][col].value.get().map_or_else(|| 0, |m| m + 1)
            ));
            let invert = gtk::Widget::default_direction() == TextDirection::Rtl;
            for x in 0..sudoku_size {
                let real_x = {
                    if invert {
                        sudoku_size - x - 1
                    }
                    else {
                        x
                    }
                };
                for y in 0..sudoku_size {
                    cc.move_to(pos[x] + offset_x, pos[y] + offset_y);
                    if sudoku[y][real_x] != 0 {
                        let letter = sudoku[y][real_x].to_string ();
                        if board.cells[y][real_x].fixed {
                            cc.select_font_face("Sans", cairo::FontSlant::Normal, font_weight);
                            cc.set_source_rgb(0.0, 0.0, 0.0);
                        }
                        else {
                            cc.select_font_face("Sans", cairo::FontSlant::Italic, font_weight);
                            cc.set_source_rgb(pencil_grey[0], pencil_grey[1], pencil_grey[2]);
                        }
                        let extents = cc.text_extents(&letter).unwrap();
                        cc.move_to(
                            pos[x] + offset_x - (extents.x_advance() / 2.0),
                            pos[y] + offset_y + (extents.height() / 2.0),
                        );
                        cc.show_text(&letter).expect("Printer error");
                    }
                }
            }
        }
    }


    #[glib::object_subclass]
    impl ObjectSubclass for SudokuPrinter {
        const NAME: &'static str = "SudokuPrinter";
        type Type = super::SudokuPrinter;
    }

    impl ObjectImpl for SudokuPrinter {
        fn constructed(&self) {
            self.parent_constructed();

            self.print_operation.connect_begin_print(glib::clone!(
                #[weak(rename_to = printer)] self,
                move |_, _| {
                    let sudokus = printer.sudokus_count.get().unwrap();
                    let spp = printer.sudokus_per_page.get().unwrap();
                    let mut pages = sudokus / spp;
                    while pages * spp < *sudokus {
                        pages += 1;
                    }
                    printer.print_operation.set_n_pages(pages);
                }
            ));

            self.print_operation.connect_draw_page(glib::clone!(
                #[weak(rename_to = printer)] self,
                move |_, context, page_nr|
                printer.draw_page_cb(context, page_nr)
            ));
        }
    }

    impl Default for SudokuPrinter {
        fn default() -> Self {
            Self {
                margin: 25,
                sudokus_count: Default::default(),
                print_operation: Default::default(),
                boards: Default::default(),
                sudokus_per_page: Default::default()
            }
        }
    }
}

glib::wrapper! {
    pub struct SudokuPrinter(ObjectSubclass<imp::SudokuPrinter>);
}

impl SudokuPrinter {
    pub fn new (boards: Vec<SudokuBoard>, sudokus_per_page: i32) -> Self {
        let printer: Self = glib::Object::builder().build();
        printer.imp().sudokus_count.set(boards.len() as i32).unwrap();
        printer.imp().sudokus_per_page.set(sudokus_per_page).unwrap();
        printer.imp().boards.set(boards).unwrap();
        printer
    }
}
