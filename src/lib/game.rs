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

use gtk::glib::{self, ThreadPool};
use gtk::glib::SourceId;
use gtk::glib::{Properties, subclass::Signal};
use gtk::prelude::*;
use gtk::subclass::prelude::*;

use crate::lib::board::SudokuError;
use crate::lib::board_generator::SudokuBoardGenerator;
use crate::lib::board::SudokuBoard;
use crate::lib::enums::DifficultyCategory;
use crate::lib::enums::CompatValue;
use crate::lib::enums::Coord;

use std::cell::{Cell, OnceCell};
use std::sync::Arc;
use std::time::{Duration, SystemTime};
use std::{cell::RefCell, sync::OnceLock};

mod imp {

use super::*;

    #[derive(Properties, Default)]
    #[properties(wrapper_type = super::SudokuGame)]
    pub struct SudokuGame {
        pub timer: Cell<Option<SystemTime>>,
        pub stored_time: Cell<f64>,
        pub paused: Cell<bool>,
        pub timer_source_id: Cell<Option<SourceId>>,
        pub board: OnceCell<SudokuBoard>,
        pub stack_head_index: Cell<Option<usize>>,
        pub current_action: Cell<Option<StackAction>>,
        pub stack: RefCell<Vec<StackItem>>,
    }

    impl SudokuGame {
        pub fn add_value_step (
            &self,
            item: &mut StackItem,
            pos: Coord,
            old_val: Option<usize>,
            new_val: Option<usize>
        ) {
            let value_step = ValueChange { pos, old_val, new_val };
            item.value_changes.push(value_step);

            self.obj().board().set_value(pos, new_val);
            self.value_changed(pos, CompatValue::from(old_val), CompatValue::from(new_val));
        }

        pub fn add_earmark_step (&self, item: &mut StackItem, pos: Coord, num: usize, enabled: bool) {
            let earmark_step = EarmarkChange { pos, num, enabled };
            item.earmark_changes.push(earmark_step);
            match enabled {
                true => self.obj().board().enable_earmark(pos, num),
                false => self.obj().board().disable_earmark(pos, num)
            }
            self.earmark_changed(pos, num, enabled);
        }

        pub fn disable_all_earmarks_helper (&self, pos: Coord, item: &mut StackItem) {
            for num in 0..9 {
                if self.obj().board().is_earmark_enabled(pos, num) {
                    self.add_earmark_step(&mut *item, pos, num, false);
                }
            }
        }

        pub fn value_changed (&self, pos: Coord, old_val: CompatValue, new_val: CompatValue) {
            self.obj().emit_by_name::<()>(
                "value-changed",
                &[&(pos.row as i32), &(pos.col as i32), &old_val.0, &new_val.0]
            );
        }

        pub fn completed (&self) {
            self.obj().emit_by_name::<()>("completed", &[]);
        }

        pub fn paused(&self, paused: bool) {
            self.obj().emit_by_name::<()>("paused", &[&paused]);
        }

        pub fn earmark_changed (&self, pos: Coord, num: usize, enabled: bool) {
            self.obj().emit_by_name::<()>(
                "earmark-changed",
                &[&(pos.row as i32), &(pos.col as i32), &(num as i32), &enabled]
            );
        }

        //clears all redo actions
        pub fn truncate_stack (&self) {
            if let Some(stack_head_index) = self.stack_head_index.get() {
                self.stack.borrow_mut().truncate(stack_head_index + 1);
            }
            else {
                self.stack.borrow_mut().clear();
            }
            self.stack_head_index.set(Some(self.stack.borrow().len()));
        }

        pub fn start_clock_tick (&self) {
            self.timer_source_id.set(Some(glib::timeout_add_seconds_local(1, glib::clone!(
                #[weak(rename_to = obj)] self.obj(),
                #[upgrade_or] glib::ControlFlow::Break,
                move || {
                    obj.emit_by_name::<()>("tick", &[]);
                    glib::ControlFlow::Continue
                }
            ))));
        }
    }

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuGame {
        const NAME: &'static str = "SudokuGame";
        type Type = super::SudokuGame;
    }

    #[glib::derived_properties]
    impl ObjectImpl for SudokuGame {
        fn signals() -> &'static [Signal] {
            static SIGNALS: OnceLock<Vec<Signal>> = OnceLock::new();
            SIGNALS.get_or_init(|| {
                vec![
                    Signal::builder("action-completed")
                        .param_types([StackAction::static_type()])
                        .build(),

                    Signal::builder("tick")
                        .build(),

                    Signal::builder("completed")
                        .build(),

                    Signal::builder("paused")
                        .param_types([bool::static_type()])
                        .build(),

                    //pos, value, enabled
                    Signal::builder("earmark-changed")
                        .param_types([
                            i32::static_type(),
                            i32::static_type(),
                            i32::static_type(),
                            bool::static_type()
                        ])
                        .build(),

                    //pos, old_val, new_val
                    Signal::builder("value-changed")
                        .param_types([
                            i32::static_type(),
                            i32::static_type(),
                            i32::static_type(),
                            i32::static_type(),
                        ])
                        .build(),
                ]
            })
        }
        fn constructed(&self) {
        }
    }

    impl StackAction {
        pub fn is_single_value_change (&self) -> bool {
            use StackAction::*;
            match self {
                Insert | Remove | InsertAndDisableAlignedEarmarks => return true,
                _ => return false
            }
        }

        pub fn is_single_earmarks_change (&self) -> bool {
            use StackAction::*;
            match self {
                EnableEarmark | DisableEarmark | DisableAllEarmarks => return true,
                _ => return false
            }
        }
    }
}

macro_rules! new_action {
    ($obj: expr, $action_type: expr) => {{
        $obj.imp().current_action.set(Some($action_type));
        $obj.imp().truncate_stack();
        StackItem::new($action_type)
    }};
}

macro_rules! finish_action {
    ($obj: expr, $item: expr) => {
        $obj.imp().current_action.set(None);
        let action_type = $item.action_type;
        $obj.imp().stack.borrow_mut().push($item);
        $obj.emit_by_name::<()>("action-completed", &[&action_type]);
    };
}

glib::wrapper! {
    pub struct SudokuGame(ObjectSubclass<imp::SudokuGame>);
}

impl SudokuGame {
    pub fn new_from_fn <F: Fn(&str) -> Result<SudokuBoard, SudokuError>>
        (func: F, path: &str)  -> Result<Self, SudokuError> {

        let game: Self = glib::Object::new();
        let mut board = func(path)?;
        if let Some(error) = SudokuGame::solve(&mut board){
            return Err(error);
        }
        game.imp().board.set(board).unwrap();
        game.start_clock ();
        Ok(game)
    }

    pub fn new_from_json (path: &str) -> Result<Self, SudokuError> {
        Self::new_from_fn(SudokuBoard::from_json, path)
    }

    pub fn new_from_string (s: &str) -> Result<Self, SudokuError> {
        Self::new_from_fn(SudokuBoard::from_string, s)
    }

    pub fn new_from_ascii (s: &str) -> Result<Self, SudokuError> {
        Self::new_from_fn(SudokuBoard::from_ascii, s)
    }

    pub fn new_from_generator (difficulty: DifficultyCategory) -> Self {
        let pool = ThreadPool::shared(Some(gtk::glib::num_processors())).unwrap();
        let generator: Arc<OnceLock<SudokuBoardGenerator>> = Arc::new(OnceLock::new());
        let time = SystemTime::now();

        for _i in 0..gtk::glib::num_processors() {
            let weak_generator = Arc::downgrade(&generator);
            pool.push(move ||{
                let mut boardg: SudokuBoardGenerator = Default::default();
                loop {
                    boardg.new_puzzle ();
                    boardg.solve().unwrap();
                    if let Some(generator) = weak_generator.upgrade() {
                        if boardg.difficulty() == difficulty {
                            if generator.get().is_none() {
                                let _ = generator.set(boardg);
                                break;
                            }
                            else {
                                break;
                            }
                        }
                    }
                    else {
                        break;
                    }

                }
            }).unwrap();
        }

        loop {
            std::thread::sleep(Duration::from_millis(1));
            if generator.get().is_some() {
                break;
            }
        }

        let generator = Arc::into_inner(generator).unwrap().into_inner().unwrap();
        let board = SudokuBoard::from_generated(&generator.get_puzzle(), &generator.get_solution(), difficulty);
        let game: Self = glib::Object::new();
        game.imp().board.set(board).unwrap();
        game.start_clock ();

        let new_time = SystemTime::now();
        println!("Multithreaded generator initialized game in {}ms",
            new_time.duration_since(time).unwrap().as_millis());

        game
    }

    pub fn solve (board: &mut SudokuBoard) -> Option<SudokuError> {
        let fixed_cells = board.fixed_cells();

        let mut board_generator = SudokuBoardGenerator::default();
        if !board_generator.set_puzzle(fixed_cells) {
            return Some(SudokuError::InvalidPuzzle);
        }
        match board_generator.solve_unique() {
            Ok(solution) => {
                for row in 0..9 {
                    for col in 0..9 {
                        board.cells[row][col].solution = solution[row][col];
                    }
                }
                board.difficulty_category = board_generator.difficulty();
                None
            },
            Err(_e) => Some(SudokuError::MultipleSolutions)
        }
    }

    pub fn board (&self) -> &SudokuBoard {
        self.imp().board.get().unwrap()
    }

    pub fn toggle_pause (&self) {
        let paused = self.imp().paused.get();
        if paused {
            self.start_clock();
        }
        else {
            self.stop_clock();
        }
        self.imp().paused(!paused);
    }

    pub fn start_clock (&self) {
        if self.imp().timer.get().is_none() {
            self.imp().timer.set(Some(SystemTime::now()));
            self.imp().start_clock_tick();
            self.imp().paused.set(false);
        }
    }

    pub fn total_time_played (&self) -> f64 {
        let imp = self.imp();
        let mut accumulated_time = imp.stored_time.get();
        if let Some(timer) = imp.timer.get() {
            if let Ok(elapsed_time) = timer.elapsed() {
                accumulated_time += elapsed_time.as_secs() as f64;
            }
        }
        accumulated_time += imp.board.get().unwrap().loaded_time;
        accumulated_time
    }

    pub fn stop_clock (&self) {
        if let Some(timer) = self.imp().timer.get(){
            if let Some(source_id) = self.imp().timer_source_id.take() {
                SourceId::remove(source_id);
            }
            if let Ok(elapsed_time) = timer.elapsed() {
                self.imp().stored_time.update(|x| x + elapsed_time.as_secs_f64());
                self.imp().timer.set(None);
                self.imp().paused.set(true);
            }
        }
    }

    pub fn difficulty (&self) -> DifficultyCategory {
        self.board().difficulty_category
    }

    pub fn is_undostack_null (&self) -> bool {
        self.imp().stack_head_index.get().is_none()
    }

    pub fn is_redostack_null (&self) -> bool {
        if let Some(stack_head_index) = self.imp().stack_head_index.get() {
            stack_head_index == self.imp().stack.borrow().len() - 1
        }
        else {
            self.imp().stack.borrow().len() == 0
        }
    }

    pub fn enable_earmark (&self, pos: Coord, num: usize) {
        let imp = self.imp();
        let mut item = new_action!(self, StackAction::EnableEarmark);
        imp.add_earmark_step(&mut item, pos, num, true);
        finish_action!(self, item);
    }

    pub fn enable_all_earmark_possibilities (&self) {
        let imp = self.imp();
        let stack_head_index_copy = self.imp().stack_head_index.get();

        let mut item = new_action!(self, StackAction::EnableAllEarmarkPossibilities);

        for row in 0..9 {
            for col in 0..9 {
                let pos = Coord { row, col };
                let cell = &self.board().cells[row][col];
                if cell.value.get().is_some() {
                    continue;
                }

                let possibilities = self.board().cell_possibilies(pos);
                for num in 0..9 {
                    if !cell.earmarks[num].get() && possibilities[num] {
                        imp.add_earmark_step(&mut item, pos, num, true);
                    }
                }
            }
        }

        if item.earmark_changes.len() > 0 {
            finish_action!(self, item);
        }
        else {
            self.imp().stack_head_index.set(stack_head_index_copy);
        }
    }

    pub fn disable_earmark (&self, pos: Coord, num: usize) {
        let imp = self.imp();
        let mut item = new_action!(self, StackAction::DisableEarmark);
        imp.add_earmark_step(&mut item, pos, num, false);
        finish_action!(self, item);
    }

    pub fn disable_all_earmarks (&self, pos: Coord) {
        let imp = self.imp();
        let mut item = new_action!(self, StackAction::DisableAllEarmarks);

        imp.disable_all_earmarks_helper(pos, &mut item);

        finish_action!(self, item);
    }

    pub fn insert_and_disable_aligned_earmarks (&self, pos: Coord, new_val: usize) {
        let imp = self.imp();
        let old_val = self.board().cell(pos).value.get();

        let mut item = new_action!(self, StackAction::InsertAndDisableAlignedEarmarks);

        for new_pos in self.board().cell(pos).aligned_coords {
            if pos == new_pos {
                continue;
            }

            if self.board().is_earmark_enabled(new_pos, new_val) {
                imp.add_earmark_step(&mut item, new_pos, new_val, false);
            }
        }

        if self.board().has_earmarks(pos) {
            imp.disable_all_earmarks_helper(pos, &mut item);
        }

        imp.add_value_step(&mut item, pos, old_val, Some(new_val));

        finish_action!(self, item);

        if self.board().is_complete() {
            imp.completed();
        }
    }

    pub fn insert (&self, pos: Coord, new_val: usize) {
        let imp = self.imp();
        let old_val = self.board().cell(pos).value.get();

        let mut item = new_action!(self, StackAction::Insert);

        if self.board().has_earmarks(pos) {
            imp.disable_all_earmarks_helper(pos, &mut item);
        }

        imp.add_value_step(&mut item, pos, old_val, Some(new_val));

        finish_action!(self, item);

        if self.board().is_complete() {
            imp.completed();
        }
    }

    pub fn remove (&self, pos: Coord) {
        let imp = self.imp();
        let old_val = self.board().cell(pos).value.get();

        let mut item = new_action!(self, StackAction::Remove);
        imp.add_value_step(&mut item, pos, old_val, None);

        finish_action!(self, item);
    }

    pub fn reset (&self) {
        let imp = self.imp();
        let mut item = new_action!(self, StackAction::Reset);

        for row in 0..9 {
            for col in 0..9 {
                let cell = &self.board().cells[row][col];
                if cell.fixed {
                    continue;
                }
                let pos = Coord { row, col };

                if let Some(value) = cell.value.get() {
                    imp.add_value_step(&mut item, pos, Some(value), None);
                }
                else if self.board().has_earmarks(pos) {
                    imp.disable_all_earmarks_helper(pos, &mut item);
                }
            }
        }

        finish_action!(self, item);
    }

    pub fn current_action (&self) -> StackAction {
        self.imp().current_action.get().unwrap()
    }

    pub fn undo (&self) {
        let stack_head_index = self.imp().stack_head_index.get().unwrap();
        let changes = &self.imp().stack.borrow()[stack_head_index];
        let imp = self.imp();
        imp.current_action.set(Some(changes.action_type));

        for vc in changes.value_changes.iter(){
            self.board().set_value (vc.pos, vc.old_val);
            imp.value_changed(vc.pos, CompatValue::from(vc.new_val), CompatValue::from(vc.old_val));
        }

        for ec in changes.earmark_changes.iter() {
            if ec.enabled {
                self.board().disable_earmark(ec.pos, ec.num);
            }
            else {
                self.board().enable_earmark(ec.pos, ec.num);
            }
            imp.earmark_changed(ec.pos, ec.num, !ec.enabled);
        }

        if stack_head_index == 0 {
            imp.stack_head_index.set(None);
        }
        else {
            imp.stack_head_index.set(Some(stack_head_index - 1));
        }

        self.imp().current_action.set(None);
        self.emit_by_name::<()>("action-completed", &[&changes.action_type]);
    }

    pub fn redo (&self) {
        let index_to_redo = {
            if let Some(stack_head_index) = self.imp().stack_head_index.get() {
                stack_head_index + 1
            }
            else {
                0
            }
        };
        let imp = self.imp();
        let changes = &imp.stack.borrow()[index_to_redo];
        imp.current_action.set(Some(changes.action_type));

        for vc in changes.value_changes.iter(){
            self.board().set_value (vc.pos, vc.new_val);
            imp.value_changed(vc.pos, CompatValue::from(vc.old_val), CompatValue::from(vc.new_val));
        }

        for ec in changes.earmark_changes.iter() {
            if ec.enabled {
                self.board().enable_earmark(ec.pos, ec.num);
            }
            else {
                self.board().disable_earmark(ec.pos, ec.num);
            }
            imp.earmark_changed(ec.pos, ec.num, ec.enabled);
        }

        imp.stack_head_index.set(Some(index_to_redo));
        self.imp().current_action.set(None);
        self.emit_by_name::<()>("action-completed", &[&changes.action_type]);
    }

    //for testing purposes
    pub fn _auto_complete (&self) {
        for row in 0..9 {
            for col in 0..9 {
                let cell = &self.board().cells[row][col];
                if cell.value.get().is_none_or(|value| value != cell.solution) {
                    self.insert(Coord { row, col }, cell.solution);
                }
            }
        }
    }
}

#[derive(Default, Debug, Copy, Clone, PartialEq, Eq, glib::Enum)]
#[enum_type(name = "StackAction")]
pub enum StackAction {
    #[default] None,
    Insert,
    Remove,
    EnableEarmark,
    DisableEarmark,
    DisableAllEarmarks,
    InsertAndDisableAlignedEarmarks,
    EnableAllEarmarkPossibilities,
    Reset
}

#[derive(Clone, Copy)]
struct EarmarkChange {
    pos: Coord,
    num: usize,
    enabled: bool
}

#[derive(Clone, Copy)]
struct ValueChange {
    pos: Coord,
    old_val: Option<usize>,
    new_val: Option<usize>
}

#[derive(Clone)]
pub struct StackItem {
    value_changes: Vec<ValueChange>,
    earmark_changes: Vec<EarmarkChange>,
    action_type: StackAction
}

impl StackItem {
    fn new (action_type: StackAction) -> Self {
        return Self {
            value_changes: Default::default(),
            earmark_changes: Default::default(),
            action_type: action_type
        };
    }
}
