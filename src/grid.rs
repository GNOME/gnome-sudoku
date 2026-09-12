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
use gtk::gio;
use gtk::gio::SimpleAction;
use gtk::{EventControllerFocus, gio::SimpleActionGroup, glib::{Propagation, Variant, WeakRef, closure_local}};

use crate::lib::backend::SudokuBackend;
use crate::lib::enums::{Coord, SudokuDirection, CompatValue};
use crate::lib::game::{SudokuGame, StackAction};
use crate::lib::utils::{new_shortcut, new_shortcut_with_args};

use crate::cell::SudokuCell;
use crate::picker_popover::SudokuPickerPopover;
use crate::connect_cb_action;
use crate::connect_cb_pref;

use std::cell::{Cell, OnceCell};

mod imp {

use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuGrid {
        const NAME: &'static str = "SudokuGrid";
        type Type = super::SudokuGrid;
        type ParentType = gtk::Grid;

        fn class_init(klass: &mut Self::Class) {
            klass.set_css_name("sudoku-grid");
            new_shortcut (klass, "grid.escape", "Escape");

            new_shortcut_with_args(klass, "grid.move-up", "w", SudokuDirection::Up);
            new_shortcut_with_args(klass, "grid.move-down", "s", SudokuDirection::Down);
            new_shortcut_with_args(klass, "grid.move-left", "a", SudokuDirection::Left);
            new_shortcut_with_args(klass, "grid.move-right", "d", SudokuDirection::Right);
        }
    }

    pub struct SudokuGrid {
        pub cells: [[SudokuCell; 9]; 9],
        pub focus_controller: WeakRef<EventControllerFocus>,
        pub selected_row: Cell<usize>,
        pub selected_col: Cell<usize>,
        pub picker_popover: SudokuPickerPopover,
        pub backend: OnceCell<SudokuBackend>,
    }

    impl Default for SudokuGrid {
        fn default() -> Self {
            let cells: [[SudokuCell; 9]; 9] = std::array::from_fn(|row| std::array::from_fn(|col| {
                let cell = SudokuCell::new(row, col);
                cell
            }));

            Self {
                cells: cells,
                selected_row: Cell::new(4),
                selected_col: Cell::new(4),
                focus_controller: Default::default(),
                picker_popover: SudokuPickerPopover::new_unitialized(),
                backend: Default::default()
            }
        }
    }

    impl SudokuGrid {
        pub fn selected_cell (&self) -> &SudokuCell {
            &self.cells[self.selected_row.get()][self.selected_col.get()]
        }

        fn update_selected (&self, cell: &SudokuCell) {
            let old_pos = self.selected_pos();
            if self.selected_cell() != cell {
                self.selected_cell().unselect();
                self.selected_row.set(cell.pos().row as usize);
                self.selected_col.set(cell.pos().col as usize);
                self.picker_popover.popdown();
            }

            //handles quiet select
            if self.selected_cell().accented() {
                self.update_highlighter(old_pos);
            }
        }

        fn move_cb (&self, variant: &Variant) {
            let dir = SudokuDirection::from_variant(variant);
            self.obj().child_focus(dir.unwrap().into());
        }

        fn setup_actions(&self) {
            let action_group = SimpleActionGroup::new();

            self.create_move_action("move-up", &action_group);
            self.create_move_action("move-down", &action_group);
            self.create_move_action("move-left", &action_group);
            self.create_move_action("move-right", &action_group);

            let action = SimpleAction::new("escape", None);
            connect_cb_action!(self.obj(), action, unselect, action_group);

            self.obj().insert_action_group("grid", Some(&action_group));
        }

        pub fn backend (&self) -> &SudokuBackend {
            self.backend.get().unwrap()
        }

        pub fn selected_pos (&self) -> Coord {
            Coord { row: self.selected_row.get(), col: self.selected_col.get() }
        }

        fn update_warnings (&self) {
            for row in &self.cells {
                for cell in row {
                    cell.update_value_warnings();
                    cell.update_all_earmark_warnings();
                }
            }
        }

        fn create_move_action (&self, name: &str, group: &SimpleActionGroup) {
            let action = gio::SimpleAction::new(name, Some(&i32::static_variant_type()));
            action.connect_activate(glib::clone!(
                #[weak(rename_to = grid)] self,
                move |_, variant|
                grid.move_cb (&variant.unwrap())
            ));
            group.add_action(&action);
        }

        pub fn add_game_hooks(&self) {
            let binding = self.backend().game();
            let game = binding.as_ref().unwrap();
            game.connect_closure("earmark-changed", false, closure_local!{
                #[weak(rename_to = grid)] self,
                move |game : SudokuGame, row: i32, col: i32, num: i32, enabled: bool| {
                    let cell = &grid.cells[row as usize][col as usize];
                    let action = game.current_action();
                    if action.is_single_earmarks_change() {
                        cell.select();
                        cell.set_earmark_visibility(num as usize, enabled);
                    }
                    else {
                        if !enabled && action == StackAction::InsertAndDisableAlignedEarmarks {
                            cell.imp().earmark_play_hide_animation (num as usize);
                        }
                        else {
                            cell.set_earmark_visibility(num as usize, enabled);
                        }
                    }

                    cell.update_earmark_warnings(num as usize);
                }
            });

            game.connect_closure("value-changed", false, closure_local!{
                #[weak(rename_to = grid)] self,
                move |_ : glib::Object, row: i32, col: i32, old_val: CompatValue, new_val: CompatValue| {
                    let cell = &grid.cells[row as usize][col as usize];
                    cell.select ();
                    cell.update_value_visibility(old_val.into(), new_val.into());
                    grid.update_value_highlighter(
                        Coord {row: row as usize, col: col as usize},
                        old_val.into(),
                        new_val.into()
                    );
                    for row in 0..9 {
                        for col in 0..9 {
                            grid.cells[row][col].update_value_warnings();
                        }
                    }
                }
            });

            game.connect_closure("paused", false, closure_local!{
                #[weak(rename_to = grid)] self,
                move |_ : glib::Object, paused: bool| {
                    grid.obj().set_can_focus(!paused);
                    if paused {
                        grid.obj().unselect();
                    }
                    else {
                        grid.grab_focus();
                    }
                }
            });
        }

        fn update_highlighter (&self, old_pos: Coord) {
            self.set_cell_highlighter(old_pos, false);
            self.set_cell_highlighter(self.selected_pos(), true);
        }

        fn update_value_highlighter (&self, old_pos: Coord, old_val: Option<usize>, new_val: Option<usize>) {
            if !self.backend().pref_highlight_numbers() {
                return;
            }

            //undo and redo jump the position
            if old_pos != self.selected_pos() {
                let cell = &self.cells[old_pos.row][old_pos.col];
                if old_val == new_val {
                    cell.highlight_value(false);
                }
                else if new_val.is_some() {
                    cell.highlight_value(true);
                }
                return;
            }

            for row in 0..9 {
                for col in 0..9 {
                    let cell = &self.cells[row][col];
                    if *cell == *self.selected_cell() {
                        continue;
                    }

                    if let Some(value) = self.backend().game_value(Coord { row, col }) {
                        if let Some(old_val) = old_val && old_val == value {
                            cell.highlight_value(false);
                        }
                        else if let Some(new_val) = new_val && new_val == value {
                            cell.highlight_value(true);
                        }
                    }
                    else {
                        if let Some(old_val) = old_val {
                            cell.highlight_earmark(old_val, false);
                        }
                        if let Some(new_val) = new_val {
                            cell.highlight_earmark(new_val, true);
                        }
                    }
                }
            }
        }

        pub fn set_cell_highlighter (&self, pos: Coord, enabled: bool) {
            let target_cell = &self.cells[pos.row][pos.col];

            let backend = self.backend();
            for row in 0..9 {
                for col in 0..9 {
                    let cell = &self.cells[row][col];
                    if *cell == *target_cell {
                        continue;
                    }

                    if backend.pref_highlight_numbers() && let Some(target_value) = target_cell.imp().value() {
                        let cell_value = cell.imp().value();
                        if let Some(cell_value) = cell_value && cell_value == target_value {
                            cell.highlight_value(enabled);
                        }
                        else  {
                            cell.highlight_earmark(target_value, enabled);
                        }
                    }

                    if !backend.game_fixed(Coord { row, col }) &&
                        ((backend.pref_highlight_row_column() && (pos.row == row || pos.col == col)) ||
                        (backend.pref_highlight_block() && row / 3 == pos.row / 3 && col / 3 == pos.col / 3))
                    {
                        cell.highlight_coord(enabled);
                    }
                }
            }
        }

        pub fn init (&self, backend: &SudokuBackend) {
            self.backend.set(backend.clone()).expect("Grid is already initialized");
            for row in 0..9 {
                for col in 0..9 {
                    self.cells[row][col].init(backend);
                }
            }

            self.picker_popover.init(backend);

            backend.connect_closure("game-changed", false, glib::closure_local!(
                #[weak(rename_to = grid)] self,
                move |_: SudokuBackend| {
                    //necessary because the focus flip flops during game completed
                    grid.obj().unselect();

                    for row in 0..9 {
                        for col in 0..9 {
                            grid.cells[row][col].update_visibility();
                            grid.cells[row][col].add_game_hooks();
                        }
                    }
                    grid.selected_row.set(4);
                    grid.selected_col.set(4);
                    grid.update_warnings();
                    grid.add_game_hooks();

                    grid.grab_focus();
                }
            ));

            connect_cb_pref!(self, connect_pref_duplicate_warnings_notify, update_warnings);
            connect_cb_pref!(self, connect_pref_solution_warnings_notify, update_warnings);
            connect_cb_pref!(self, connect_pref_earmark_warnings_notify, update_warnings);

            self.add_game_hooks ();

            self.update_warnings();
        }

    }

    impl ObjectImpl for SudokuGrid {
        fn constructed(&self) {
            self.parent_constructed();
            self.obj().set_direction(gtk::TextDirection::Ltr);

            let focus_controller = EventControllerFocus::new();
            self.focus_controller.set(Some(&focus_controller));
            self.focus_controller.upgrade().unwrap().connect_leave(glib::clone!(
                #[weak(rename_to = grid)] self,
                move |_| {
                    let window : gtk::Window = grid.obj().root().and_downcast::<gtk::Window>().unwrap();
                    if window.is_active () && grid.backend().game_exists() {
                        grid.obj().unselect();
                    }
                }
            ));

            self.obj().add_controller(self.focus_controller.upgrade().unwrap());
            self.setup_actions();

            for block_row in 0..3 {
                for block_col in 0..3 {
                    let block = glib::Object::builder::<gtk::Grid>()
                        .property("row_spacing", 1)
                        .property("column_spacing", 1)
                        .property("row_homogeneous", true)
                        .property("column_homogeneous", true)
                        .property("css-name", "sudoku-block")
                        .build();

                    block.set_direction(gtk::TextDirection::Ltr);
                    self.obj().attach(&block, block_col, block_row, 1, 1);
                }
            }

            for row in 0..9 {
                for col in 0..9 {
                    let cell = &self.cells[row][col];

                    cell.connect_closure("selected", false, closure_local!(
                        #[weak(rename_to = grid)] self,
                        move |grid_cell : SudokuCell| {
                            grid.update_selected(&grid_cell);
                    }));


                    cell.connect_closure("grab-picker", false, closure_local!(
                        #[weak(rename_to = grid)] self,
                        move |grid_cell : SudokuCell| {
                            grid_cell.set_picker(&grid.picker_popover);
                    }));
                    let row = row as i32;
                    let col = col as i32;

                    let block = self.obj().child_at(col / 3, row / 3);
                    let block = block.unwrap().dynamic_cast::<gtk::Grid>().unwrap();
                    block.attach(cell, col % 3, row % 3, 1, 1);
                }
            }
        }

        fn dispose(&self) {
            println!("Grid disposed");
        }
    }

    impl WidgetImpl for SudokuGrid {
        fn focus(&self, direction_type: gtk::DirectionType) -> bool {
            use gtk::DirectionType::*;
            match direction_type {
                //this lets us control the focus when it comes from the headerbar and gtk/adwaita
                TabForward | TabBackward => {
                    if !self.focus_controller.upgrade().unwrap().contains_focus() {
                        self.grab_focus()
                    }
                    else {
                        Propagation::Proceed.into() //propagate the event so that the focus moves to the headerbar
                    }
                }
                Up => {
                    if self.selected_row.get() == 0 {
                        self.cells[8][self.selected_col.get()].select()
                    }
                    else {
                        self.cells[self.selected_row.get() - 1][self.selected_col.get()].select()
                    }
                }

                Down => {
                    if self.selected_row.get() == 8 {
                        self.cells[0][self.selected_col.get()].select()
                    }
                    else {
                        self.cells[self.selected_row.get() + 1][self.selected_col.get()].select()
                    }
                }

                Right => {
                    if self.selected_col.get() == 8 {
                        self.cells[self.selected_row.get()][0].select()
                    }
                    else {
                        self.cells[self.selected_row.get()][self.selected_col.get() + 1].select()
                    }
                }

                Left => {
                    if self.selected_col.get() == 0 {
                        self.cells[self.selected_row.get()][8].select()
                    }
                    else {
                        self.cells[self.selected_row.get()][self.selected_col.get() - 1].select()
                    }
                }
                _ => panic!("Failed to parse direction")
            }
        }

        fn grab_focus(&self) -> bool {
            if self.backend().keyboard_pressed_recently() {
                self.selected_cell().select()
            }
            else {
                self.selected_cell().quiet_select()
            }
        }
    }
    impl GridImpl for SudokuGrid{}
}

glib::wrapper! {
    pub struct SudokuGrid(ObjectSubclass<imp::SudokuGrid>)
        @extends gtk::Widget, gtk::Grid,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget, gtk::Orientable;
}

impl SudokuGrid {
    pub fn new_unitialized () -> Self {
        let grid: Self = glib::Object::builder()
            .property("row_spacing", 2)
            .property("column_spacing", 2)
            .property("row_homogeneous", true)
            .property("column_homogeneous", true)
            .build();

        grid
    }

    pub fn set_font_size (&self, height: i32) {
        for row in &self.imp().cells {
            for cell in row {
                let grid_padding = 10; //for size consistency with <= v50, remove with gtk5
                let height = (height - grid_padding) / 9;
                cell.set_font_sizes(height);
            }
        }
    }

    pub fn init (&self, backend: &SudokuBackend) {
        self.imp().init(backend);
    }

    pub fn unselect (&self) {
        self.imp().selected_cell().unselect();
        self.imp().picker_popover.popdown();
        self.imp().set_cell_highlighter(self.imp().selected_pos(), false);
    }

    pub fn set_quiet_select (&self) {
        self.imp().selected_cell().set_accented(false);
    }
}
