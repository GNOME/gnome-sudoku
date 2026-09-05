/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
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

use std::{cell::{Cell, RefCell}, collections::HashMap, fs::{File, remove_file}, io::Write};

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::lib::{board::SudokuError, enums::DifficultyCategory};

#[derive(Serialize, Deserialize, Default, Debug)]
pub struct SudokuData {
    #[serde(default)]
    pub highscores: RefCell<HashMap<DifficultyCategory, f64>>,
    #[serde(default)]
    pub print_data: RefCell<PrintData>,
    #[serde(default)]
    pub start_button_selected: Cell<DifficultyCategory>,
    #[serde(skip)]
    data_file: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PrintData {
    pub number_of_puzzles: f64,
    pub number_of_puzzles_per_page: f64,
    pub difficulty: DifficultyCategory,
}

impl Default for PrintData {
    fn default() -> Self {
        Self {
            number_of_puzzles: 2.0,
            number_of_puzzles_per_page: 1.0,
            difficulty: DifficultyCategory::Easy,
        }
    }
}

impl SudokuData {
    pub fn new (path: String) -> Self {
        if let Ok(str) = std::fs::read_to_string(&path) &&
            let Ok(mut data) = Self::load(&str)
        {
            data.data_file = path;
            return data
        }
        else {
            Self {
                highscores: Default::default(),
                data_file: path,
                print_data: Default::default(),
                start_button_selected: Cell::new(DifficultyCategory::Easy)
            }
        }
    }

    //implemeted in v52, remove it in v55
    pub fn new_from_highscores (
        data_path: String,
        highscores_path: &String,
        start_button_selected: DifficultyCategory
    ) -> Result<Self, SudokuError>
    {
        let str = std::fs::read_to_string(highscores_path)?;
        let highscores = Self::legacy_load(&str)?;
        let data = Self {
            highscores: RefCell::new(highscores),
            data_file: data_path,
            print_data: Default::default(),
            start_button_selected: Cell::new(start_button_selected)
        };
        if !(data.save() && remove_file(highscores_path).is_ok()){
            eprintln!("Error deleting legacy highscore file");
        }
        Ok(data)
    }

    fn load (str: &String) -> Result<Self, SudokuError> {
        let data: Self = serde_json::from_str(str)?;
        Ok(data)
    }

    pub fn save (&self) -> bool {
        if let Ok(mut file) = File::create(&self.data_file) {
            let str = serde_json::to_string_pretty(&self).unwrap();
            file.write_all(&str.into_bytes()).expect("Error saving");
            return true;
        }
        else {
            println!("ERROR OPENING FILE");
            return false;
        }
    }

    //implemeted in v52, remove it in v55
    fn legacy_load (str: &String) -> Result<HashMap<DifficultyCategory, f64>, SudokuError> {
        let h: Value = serde_json::from_str(str)?;
        use DifficultyCategory::*;
        let mut highscores: HashMap<DifficultyCategory, f64> = HashMap::new();
        let difficulties = [Easy, Medium, Hard, VeryHard];
        for difficulty in difficulties {
            if let Some(parsed) = h[DifficultyCategory::to_string(&difficulty)].as_f64() {
                highscores.insert(difficulty, parsed);
            }
        }
        if highscores.len() == 0 {
            return Err(SudokuError::InvalidSaveData);
        }

        Ok(highscores)
    }
}
