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
use gtk::gio;

use glib::ThreadPool;
use glib::subclass::Signal;
use glib::user_data_dir;
use glib::Properties;
use glib::timeout_add_seconds_local_once;
use glib::timeout_add_local;
use glib::SourceId;

use crate::lib::enums::Coord;
use crate::lib::board::SudokuBoard;
use crate::lib::board_generator::SudokuBoardGenerator;
use crate::lib::enums::DifficultyCategory;
use crate::lib::enums::ZoomLevel;
use crate::lib::{board::SudokuError, data::SudokuData, game::SudokuGame};

use std::array::from_fn;
use std::cell::Cell;
use std::cell::Ref;
use std::io::ErrorKind::AlreadyExists;
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::Mutex;
use std::time::Duration;
use std::{cell::RefCell, fs::File, io::{ErrorKind, Write}, sync::OnceLock};

mod imp {
    use super::*;

    #[derive(Properties)]
    #[properties(wrapper_type = super::SudokuBackend)]
    pub struct SudokuBackend {
        pub game: RefCell<Option<SudokuGame>>,
        settings: gio::Settings,
        pub paths: SudokuPaths,
        pub sdata: SudokuData,
        pub keyboard_pressed_sourceid: Cell<Option<SourceId>>,
        pub autosave_sourceid: Cell<Option<SourceId>>,

        #[property(get, set, builder(ZoomLevel::None))]
        pub pref_zoom: Cell<ZoomLevel>,
        #[property(get, set)]
        pub pref_timer: Cell<bool>,
        #[property(get, set)]
        pub pref_show_all_possibilities: Cell<bool>,
        #[property(get, set)]
        pub pref_highlight_row_column: Cell<bool>,
        #[property(get, set)]
        pub pref_highlight_block: Cell<bool>,
        #[property(get, set)]
        pub pref_highlight_numbers: Cell<bool>,
        #[property(get, set)]
        pub pref_duplicate_warnings: Cell<bool>,
        #[property(get, set)]
        pub pref_solution_warnings: Cell<bool>,
        #[property(get, set)]
        pub pref_earmark_warnings: Cell<bool>,
        #[property(get, set)]
        pub pref_autoclean_earmarks: Cell<bool>,
        #[property(get, set)]
        pub pref_picker_second_click: Cell<bool>,
        #[property(get)]
        pub tgame: RefCell<Option<SudokuGame>>,
        //doesn't get saved and it's reset in between games
        #[property(get, set)]
        pub earmark_mode: Cell<bool>,
        #[property(get, set)]
        pub keyboard_pressed_recently: Cell<bool>,
    }

    impl Default for SudokuBackend {
        fn default () -> Self {
            let paths = SudokuPaths::default();
            let settings = gio::Settings::new("org.gnome.Sudoku");
            let sudoku_data = {
                let start_button_selected = settings.get::<DifficultyCategory>("start-button-selected");
                if let Ok(sudoku_data) = SudokuData::new_from_highscores(
                    paths.data_file.clone(), &paths.highscores_file, start_button_selected)
                {
                    sudoku_data
                }
                else {
                    SudokuData::new(paths.data_file.clone())
                }
            };

            Self {
                sdata: sudoku_data,
                game: Default::default(),
                tgame: Default::default(),
                paths: paths,
                pref_zoom: Default::default(),
                settings,
                pref_timer: Default::default(),
                earmark_mode: Default::default(),
                pref_show_all_possibilities: Default::default(),
                pref_highlight_row_column: Default::default(),
                pref_highlight_block: Default::default(),
                pref_highlight_numbers: Default::default(),
                pref_duplicate_warnings: Default::default(),
                pref_solution_warnings: Default::default(),
                pref_earmark_warnings: Default::default(),
                pref_autoclean_earmarks: Default::default(),
                pref_picker_second_click: Default::default(),
                autosave_sourceid: Default::default(),
                keyboard_pressed_recently: Default::default(),
                keyboard_pressed_sourceid: Default::default(),
            }
        }
    }

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuBackend {
        const NAME: &'static str = "SudokuBackend";
        type Type = super::SudokuBackend;
    }

    #[glib::derived_properties]
    impl ObjectImpl for SudokuBackend {
        fn constructed(&self) {
            self.settings.bind("zoom-level", &*self.obj(), "pref_zoom").build();
            self.settings.bind("show-timer", &*self.obj(), "pref_timer").build();
            self.settings.bind("show-possibilities", &*self.obj(), "pref_show_all_possibilities").build();
            self.settings.bind("autoclean-earmarks", &*self.obj(), "pref_autoclean_earmarks").build();
            self.settings.bind("number-picker-second-click", &*self.obj(), "pref_picker_second_click").build();
            self.settings.bind("duplicate-warnings", &*self.obj(), "pref_duplicate_warnings").build();
            self.settings.bind("solution-warnings", &*self.obj(), "pref_solution_warnings").build();
            self.settings.bind("earmark-warnings", &*self.obj(), "pref_earmark_warnings").build();
            self.settings.bind("highlight-row-column", &*self.obj(), "pref_highlight_row_column").build();
            self.settings.bind("highlight-block", &*self.obj(), "pref_highlight_block").build();
            self.settings.bind("highlight-numbers", &*self.obj(), "pref_highlight_numbers").build();

            self.add_preference_cbs();
            let save_path = &self.paths.active_save_file;
            match SudokuGame::new_from_json(&save_path){
                Ok(game) => {
                    self.game.replace(Some(game));
                    self.obj().game_enable_all_possibilities();
                    self.game_changed();
                }
                Err(e) => {
                    if e != SudokuError::FileNotFound {
                        eprintln!("{}", e);
                    }
                }
            }
        }

        fn signals() -> &'static [Signal] {
            static SIGNALS: OnceLock<Vec<Signal>> = OnceLock::new();
            SIGNALS.get_or_init(|| {
                vec![
                    Signal::builder("game-changed")
                        .build(),
                ]
            })
        }

        fn dispose (&self) {
            self.save_game(&self.paths.active_save_file);

            if !self.sdata.save() {
                eprintln!("Error saving data file");
            }
            else {
                println!("SAVED DATA");
            }
        }
    }

    impl SudokuBackend {
        pub fn save_game (&self, path: &str) {
            let binding = self.game.borrow();
            if let Some(game) = binding.as_ref() && !game.board().is_complete() && !game.board().is_empty(){
                let elapsed_time = {
                    if self.obj().pref_timer() {
                        game.total_time_played()
                    }
                    else {
                        -1.0
                    }
                };

                Self::create_file_for_board(&path, game.board(), elapsed_time);
            }
            else {
                self.delete_save();
            }
        }

        pub fn delete_save (&self) {
            if let Err(e) = std::fs::remove_file(&self.paths.active_save_file)
                && e.kind() != ErrorKind::NotFound {
                    eprintln!("{}", e);
            }
        }

        pub fn game_changed (&self) {
            self.stop_autosave();
            self.autosave_sourceid.set(Some(timeout_add_local(Duration::from_mins(5), glib::clone!(
                #[weak(rename_to = backend)] self,
                #[upgrade_or] glib::ControlFlow::Break,
                move || {
                    backend.save_game(&backend.paths.active_save_file);
                    glib::ControlFlow::Continue
                }
            ))));

            self.obj().emit_by_name::<()>(
                "game-changed",
                &[]
            );
        }

        pub fn stop_autosave (&self) {
            if let Some(autosave) = self.autosave_sourceid.take() {
                SourceId::remove(autosave);
            }
        }

        pub fn add_preference_cbs (&self) {
            self.obj().connect_pref_show_all_possibilities_notify(glib::clone!(
                move |backend: &crate::lib::backend::SudokuBackend|
                if backend.pref_show_all_possibilities() {
                    if let Some(game) = &*backend.imp().game.borrow() {
                        game.enable_all_earmark_possibilities();
                    }
                }
            ));

            self.obj().connect_keyboard_pressed_recently_notify(glib::clone!(
                move |backend: &crate::lib::backend::SudokuBackend|
                if backend.keyboard_pressed_recently() {
                    if let Some(source_id) =  backend.imp().keyboard_pressed_sourceid.take(){
                        SourceId::remove(source_id);
                    }
                    backend.imp().create_keyboard_pressed_timeout();
                }
            ));
        }

        pub fn create_keyboard_pressed_timeout (&self) {
            self.keyboard_pressed_sourceid.set(Some(timeout_add_seconds_local_once(5, glib::clone!(
                #[weak(rename_to = backend)] self,
                move || {
                    backend.keyboard_pressed_sourceid.set(None);
                    //this doesn't call the property notify
                    backend.keyboard_pressed_recently.set(false)
                }
            ))));
        }

        pub fn save_printed_board (&self, board: &SudokuBoard) {
            let save_name = board.fixed_to_string() + ".save";
            let save_path = self.paths.printed_dir.join(save_name);
            let save_path = save_path.to_str().expect("Failed to convert path");
            Self::create_file_for_board(save_path, board, -1.0);
        }

        pub fn archive_game (&self) {
            let binding = self.game.borrow();
            let game = binding.as_ref().unwrap();
            let board = game.board();

            let timer = match self.obj().pref_timer() {
                true => game.total_time_played(),
                false => -1.0
            };
            let save_name = board.fixed_to_string() + ".save";
            let save_path = self.paths.saved_dir.join(save_name);
            let save_path = save_path.to_str().expect("Failed to convert path");
            Self::create_file_for_board(save_path, board, timer);
        }

        fn create_file_for_board (file_name: &str, board: &SudokuBoard, elapsed_time: f64) {
            let board = board.to_json(elapsed_time);
            match &mut File::create(file_name) {
                Ok(file) => {
                    match file.write_all(&board.into_bytes())
                    {
                        Ok(_) => println!("SAVED GAME"),
                        Err(e) => eprintln!("Failed to save, {}", e.to_string())
                    }
                },
                Err(e) => eprintln!("Failed to open save file, {}", e.to_string())
            }
        }
    }
}

#[macro_export]
macro_rules! game {
    ($backend: expr) => {
        $backend.imp().game.borrow().as_ref().unwrap()
    }
}

impl SudokuBackend {
    pub fn new() -> Self {
        glib::Object::builder()
            .build()
    }

    pub fn game (&self) -> Ref<'_, Option<SudokuGame>> {
        self.imp().game.borrow()
    }

    pub fn game_exists (&self) -> bool {
        self.imp().game.borrow().is_some()
    }

    pub fn game_delete (&self) {
        self.imp().game.replace(None);
    }

    pub fn game_clear_cell (&self, pos: Coord) {
        let binding = self.game();
        let game = binding.as_ref().unwrap();
        if game.board().is_fixed(pos) {
            return;
        }

        let old_val = self.game_value(pos);

        if old_val.is_some() {
            game.remove (pos);
        }
        else if game.board().has_earmarks(pos){
            game.disable_all_earmarks (pos);
        }
    }

    pub fn game_set_value (&self, pos: Coord, new_val: usize) {
        let binding = self.game();
        let game = binding.as_ref().unwrap();
        if game.board().is_fixed(pos) {
            return;
        }

        let old_val = self.game_value(pos);
        if old_val.is_none_or(|old_val| old_val != new_val) {
            if self.pref_autoclean_earmarks() {
                game.insert_and_disable_aligned_earmarks(pos, new_val);
            }
            else {
                game.insert(pos, new_val);
            }
        }
    }

    pub fn game_toggle_earmark (&self, pos: Coord, num: usize) {
        let binding = self.game();
        let game = binding.as_ref().unwrap();
        let cell = game.board().cell(pos);
        if cell.value.get().is_none() {
            let enabled = cell.earmarks[num].get();
            match enabled {
                true => game.disable_earmark(pos, num),
                false => game.enable_earmark(pos, num)
            }
        }
    }

    pub fn game_earmark_is_possible (&self, pos: Coord, num: usize) -> bool {
        game!(self).board().is_earmark_possible(pos, num)
    }

    pub fn game_has_earmarks (&self, pos: Coord) -> bool {
        game!(self).board().has_earmarks(pos)
    }

    pub fn game_broken (&self, pos: Coord) -> bool {
        game!(self).board().broken_coords.borrow().contains(&pos)
    }

    pub fn game_difficulty (&self) -> DifficultyCategory {
        game!(self).board().difficulty_category
    }

    pub fn game_is_empty (&self) -> bool {
        game!(self).board().is_empty()
    }

    pub fn game_value (&self, pos: Coord) -> Option<usize> {
        game!(self).board().cell(pos).value.get()
    }

    pub fn game_solution (&self, pos: Coord) -> usize {
        game!(self).board().cell(pos).solution
    }

    pub fn game_fixed (&self, pos: Coord) -> bool {
        game!(self).board().cell(pos).fixed
    }

    pub fn game_earmarks (&self, pos: Coord) -> [Cell<bool>; 9] {
        game!(self).board().cell(pos).earmarks.clone()
    }

    pub fn game_earmark (&self, pos: Coord, num: usize) -> bool {
        game!(self).board().cell(pos).earmarks[num].get()
    }

    pub fn game_toggle_pause (&self) {
        game!(self).toggle_pause();
    }

    pub fn game_paused (&self) -> bool {
        game!(self).imp().paused.get()
    }

    pub fn game_start_clock (&self) {
        game!(self).start_clock();
    }

    pub fn game_undo (&self) {
        game!(self).undo();
    }

    pub fn game_redo (&self) {
        game!(self).redo();
    }

    pub fn game_reset (&self) {
        game!(self).reset();
    }

    pub fn game_time_played (&self) -> f64 {
        game!(self).total_time_played()
    }

    pub fn game_stop_clock (&self) {
        game!(self).stop_clock();
    }

    pub fn game_can_redo (&self) -> bool {
        !game!(self).is_redostack_null()
    }

    pub fn game_can_undo (&self) -> bool {
        !game!(self).is_redostack_null()
    }

    pub fn game_enable_all_possibilities (&self) {
        let binding = self.game();
        let game = binding.as_ref().unwrap();
        if self.pref_show_all_possibilities() && game.board().loaded_time == 0.0 {
            game.enable_all_earmark_possibilities();
        }
    }

    pub fn game_generate (&self, difficulty: DifficultyCategory) {
        let game = SudokuGame::new_from_generator(difficulty);
        self.imp().game.replace(Some(game));
        self.imp().game_changed();
    }

    pub fn game_load (&self, path: &str) -> bool {
        let mut errors = Vec::new();
        match SudokuGame::new_from_json(path){
            Ok(game) => {
                self.imp().game.replace(Some(game));
                self.imp().game_changed();
                return true;
            },
            Err(e) => errors.push(e)
        }
        match std::fs::File::open(path){
            Ok(mut file) => {
                let mut buffer : [u8; 100] = from_fn(|_| 0);
                use std::io::Read;
                let _ = file.read_exact(buffer.as_mut_slice());
                match str::from_utf8(&buffer) {
                    Ok(s) => 
                        match SudokuGame::new_from_string(&s){
                            Ok(game) => {
                                self.imp().game.replace(Some(game));
                                self.imp().game_changed();
                                return true;
                            },
                            Err(e) => errors.push(e)
                        }
                    ,
                    Err(_) => errors.push(SudokuError::InvalidPuzzle),
                }
            }

            Err(_) => errors.push(SudokuError::InvalidPuzzle),
        }

        for error in errors.iter().enumerate() {
            eprintln!("{}: {}", error.0, error.1);
        }

        false
    }

    pub fn game_ascii(&self) -> String {
        game!(self).board().fixed_to_ascii()
    }

    pub fn game_highscore (&self) -> Option<f64> {
        self.imp().sdata.highscores.borrow().get(&game!(self).difficulty()).cloned()
    }

    pub fn game_save_as (&self, path: &str) {
        self.imp().save_game(path);
    }

    pub fn game_save_completed (&self) {
        self.imp().delete_save();
        self.imp().archive_game();
        self.imp().stop_autosave();
    }

    pub fn game_save_as_info (&self) -> (String, gio::File) {
        (game!(self).board().fixed_to_string_short() + ".save",
         gio::File::for_path(self.imp().paths.saved_dir.as_path()))
    }

    pub fn game_save_highscore (&self) -> bool {
        let old_highscore = self.game_highscore();
        let new_highscore = game!(self).total_time_played();
        match old_highscore {
            Some(old_highscore) => {
                if old_highscore > new_highscore {
                    let difficulty = game!(self).difficulty();
                    self.set_highscore(difficulty, new_highscore);
                    return true
                }
                false
            }
            None => {
                let difficulty = game!(self).difficulty();
                self.set_highscore(difficulty, new_highscore);
                true
            }
        }
    }

    pub fn set_print_options (&self,
        number_of_puzzles: f64,
        number_of_puzzles_per_page: f64,
        difficulty: DifficultyCategory)
    {
        let mut print_options = self.imp().sdata.print_data.borrow_mut();
        print_options.number_of_puzzles = number_of_puzzles;
        print_options.number_of_puzzles_per_page = number_of_puzzles_per_page;
        print_options.difficulty = difficulty;
    }

    pub fn export_puzzle (&self, path: &str) {
        match std::fs::File::create(&path){
            Ok(mut file) => {
                let content = game!(self).board().fixed_to_string_pretty();
                use std::io::Write;
                file.write_all(&content.into_bytes()).expect("Error saving");
            }
            Err(e) => eprintln!("Failed to create file:{}", e)
        }
    }

    pub fn print_options (&self) -> (f64, f64, DifficultyCategory){
        let print_options = &self.imp().sdata.print_data.borrow();
        (
            print_options.number_of_puzzles,
            print_options.number_of_puzzles_per_page,
            print_options.difficulty
        )
    }

    pub fn new_game (&self) {
        let difficulty = game!(self).difficulty();
        self.game_generate(difficulty);
    }

    pub fn check_clipboard (&self, s: &str) {
        match SudokuGame::new_from_ascii(s){
            Ok(game) => {
                self.imp().tgame.replace(Some(game));
                self.notify_tgame();
            },
            Err(e) => eprintln!("Failed to grab clipboard:{} ", e)
        }
    }

    pub fn tgame_start (&self) {
        if let Some(tgame) = self.imp().tgame.take() {
            self.imp().game.replace(Some(tgame));
            self.notify_tgame();
            self.imp().game_changed();
        }
    }

    pub fn generate_multiple_puzzles (difficulty: DifficultyCategory, number_of_puzzles: u8) -> Vec<SudokuBoard> {
        let pool = ThreadPool::shared(Some(gtk::glib::num_processors())).unwrap();
        let boards: Arc<Mutex<Vec<SudokuBoard>>> = Arc::new(Mutex::new(Default::default()));

        for _i in 0..gtk::glib::num_processors() {
            let weak_boards = Arc::downgrade(&boards);
            pool.push(move ||{
                let mut boardg: SudokuBoardGenerator = Default::default();
                'a: loop {
                    boardg.new_puzzle ();
                    boardg.solve().unwrap();
                    if boardg.difficulty() == difficulty {
                        let board = SudokuBoard::from_generated(
                            &boardg.get_puzzle(),
                            &boardg.get_solution(),
                            difficulty
                        );

                        if let Some(boards) = weak_boards.upgrade()
                        {
                            if let Ok(mut boards) = boards.lock() {
                                if boards.len() > number_of_puzzles as usize {
                                    break 'a;
                                }
                                else {
                                    boards.push(board);
                                    if boards.len() > number_of_puzzles as usize {
                                        break 'a;
                                    }
                                    else {
                                        continue 'a;
                                    }
                                }
                            }
                        }
                        else {
                            break 'a;
                        }
                    }
                }
            }).unwrap();
        }

        loop {
            std::thread::sleep(Duration::from_millis(5));
            if let Ok(boards) = boards.lock() && boards.len() >= number_of_puzzles as usize {
                break;
            }
        }
        Arc::into_inner(boards).unwrap().into_inner().unwrap()
    }

    pub fn selected_difficulty (&self) -> DifficultyCategory {
        self.imp().sdata.start_button_selected.get()
    }

    fn set_highscore (&self, difficulty: DifficultyCategory, highscore: f64) {
        self.imp().sdata.highscores.borrow_mut().insert(difficulty, highscore);
    }

    pub fn set_selected_difficulty(&self, difficulty: DifficultyCategory) {
        self.imp().sdata.start_button_selected.set(difficulty);
    }

    pub fn save_printed_board (&self, board: &SudokuBoard) {
        self.imp().save_printed_board(board);
    }
}

glib::wrapper! {
    pub struct SudokuBackend(ObjectSubclass<imp::SudokuBackend>);
}

#[derive(Clone)]
pub struct SudokuPaths {
    pub active_save_file: String,
    pub highscores_file: String,
    pub data_file: String,
    pub printed_dir: PathBuf,
    pub finished_dir: PathBuf,
    pub saved_dir: PathBuf,
}

impl Default for SudokuPaths {
    fn default() -> Self {
        let data_dir = &user_data_dir();
        let sudoku_dir = data_dir.join("gnome-sudoku");
        let printed_dir = sudoku_dir.join("printed");
        let finished_dir = sudoku_dir.join("finished");
        let saved_dir = sudoku_dir.join("saved");

        SudokuPaths::create_dir(&sudoku_dir);
        SudokuPaths::create_dir(&printed_dir);
        SudokuPaths::create_dir(&finished_dir);
        SudokuPaths::create_dir(&saved_dir);
        return Self {
            active_save_file: Self::convert_path(&sudoku_dir.join("savefile")),
            highscores_file: Self::convert_path(&sudoku_dir.join("highscores")),
            data_file: Self::convert_path(&sudoku_dir.join("data")),
            printed_dir,
            finished_dir,
            saved_dir,
        }
    }
}

impl SudokuPaths {
    fn create_dir(dir: &PathBuf) {
        if let Err(e) = std::fs::create_dir(&dir) {
            if e.kind() != AlreadyExists {
                eprintln!("Error creating save directory: {}", e);
            }
        }
    }

    fn convert_path(old: &PathBuf) -> String {
        old.to_str().expect("Error setting up save paths").to_string()
    }
}
