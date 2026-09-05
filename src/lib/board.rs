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

use core::fmt;
use std::{self, array::{self, from_fn}, cell::{Cell, RefCell}, collections::HashSet};
use crate::lib::enums::DifficultyCategory;
use crate::lib::enums::Coord;

//You should never be interacting with SudokuBoard directly
//everything goes through SudokuGame and SudokuBackend
#[derive(Clone, Debug)]
pub struct SudokuBoard {
    pub cells : [[SudokuBoardCell; 9]; 9],
    total_fixed : usize,
    total_earmarks : Cell<usize>,
    total_filled : Cell<usize>,
    pub broken_coords: RefCell<HashSet<Coord>>,
    digits : [DigitOccurences; 9],

    pub difficulty_category: DifficultyCategory,
    pub loaded_time: f64,
    coords_for_row: [[Coord; 9]; 9],
    coords_for_col: [[Coord; 9]; 9],
    coords_for_block: [[[Coord; 9]; 3]; 3]
}

#[derive(Default, Clone, Debug)]
pub struct SudokuBoardCell {
    pub value: Cell<Option<usize>>,
    pub earmarks: [Cell<bool>; 9],

    pub solution: usize,
    pub fixed: bool,
    pub aligned_coords: [Coord; 21]
}

#[derive(Default, Clone, Debug)]
struct DigitOccurences {
    in_row : [Cell<usize>; 9],
    in_col : [Cell<usize>; 9],
    in_block : [[Cell<usize>; 3]; 3],
}

impl DigitOccurences {
    fn increment (&self, row: usize, col: usize) {
        self.in_row[row].update(|x| x + 1);
        self.in_col[col].update(|x| x + 1);
        self.in_block[row / 3][col / 3].update(|x| x + 1);
    }

    fn decrement (&self, row: usize, col: usize) {
        self.in_row[row].update(|x| x - 1);
        self.in_col[col].update(|x| x - 1);
        self.in_block[row / 3][col / 3].update(|x| x - 1);
    }
}

impl Default for SudokuBoard {
    fn default() -> Self {
        //self referencing would skip the coord middleman but we'd need a crate like ouroboros for that
        let coords_for_row: [[Coord; 9]; 9] = {
            array::from_fn(|row|
                array::from_fn(|col|
                    Coord { row: row, col: col }
                )
            )
        };

        let coords_for_col: [[Coord; 9]; 9] = {
            array::from_fn(|col|
                array::from_fn(|row|
                    Coord { row: row, col: col }
                )
            )
        };

        let coords_for_block: [[[Coord; 9]; 3]; 3] = {
            array::from_fn(|row_block|
                array::from_fn(|col_block|
                    array::from_fn(|i| {
                        let row = row_block * 3 + i / 3;
                        let col = col_block * 3 + i % 3 ;
                        Coord { row: row, col: col }
                    })
                )
            )
        };

        let mut cells : [[SudokuBoardCell; 9]; 9] = Default::default();
        //9 in the block + 6 vertically + 6 horizontally so 21 aligned coordinates for each cell
        for row in 0..9 {
            for col in 0..9 {
                let mut set: HashSet<&Coord> = HashSet::new();
                for coord in &coords_for_col[col] {
                    set.insert(coord);
                }
                for coord in &coords_for_row[row] {
                    set.insert(coord);
                }
                for coord in &coords_for_block[row / 3][col / 3] {
                    set.insert(coord);
                }
                for cell in set.iter().enumerate() {
                    cells[row][col].aligned_coords[cell.0] = **cell.1;
                }
            }
        }

        Self {
            cells: cells,
            digits: Default::default(),
            total_fixed: Default::default(),
            total_earmarks: Default::default(),
            total_filled: Default::default(),
            coords_for_row: coords_for_row,
            coords_for_col: coords_for_col,
            coords_for_block: coords_for_block,
            broken_coords : Default::default(),
            difficulty_category: Default::default(),
            loaded_time : Default::default()
        }
    }
}

impl SudokuBoard {
    pub fn is_complete (&self) -> bool {
        let broken : bool = self.broken_coords.borrow().len() != 0;
        return !broken && self.total_filled.get() == 81;
    }

    pub fn is_empty (&self) -> bool {
        return self.total_filled.get() == self.total_fixed && self.total_earmarks.get() == 0;
    }

    pub fn fixed_cells (&self) -> [[Option<usize>; 9]; 9] {
        array::from_fn(|row|
            array::from_fn(|col|
                if self.cells[row][col].fixed {
                    self.cells[row][col].value.get()
                }
                else {
                    None
                }
            )
        )
    }

    pub fn cell(&self, pos: Coord) -> &SudokuBoardCell {
        &self.cells[pos.row][pos.col]
    }

    pub fn enable_earmark (&self, pos: Coord, num: usize) {
        self.cells[pos.row][pos.col].earmarks[num].set(true);
        self.total_earmarks.update(|x| x + 1);
    }

    pub fn disable_earmark (&self, pos: Coord, num: usize) {
        self.cells[pos.row][pos.col].earmarks[num].set(false);
        self.total_earmarks.update(|x| x - 1);
    }

    pub fn disable_all_earmarks (&self, pos: Coord) {
        let cell = &self.cell(pos);
        for num in 0..9 {
            if cell.earmarks[num].get() {
                self.disable_earmark(pos, num);
            }
        }
    }

    pub fn remove (&self, pos: Coord) {
        let old_val = self.cells[pos.row][pos.col].value.get().unwrap();
        self.remove_from_occurrences (pos.row, pos.col, old_val);
        self.remove_breakages_for (pos.row, pos.col, old_val);
        self.total_filled.update(|x| x - 1);
        self.cells[pos.row][pos.col].value.set(None);
    }

    pub fn set_value (&self, pos: Coord, new_val: Option<usize>) {
        if let Some(new_val) = new_val {
            self.insert(pos, new_val);
        }
        else {
            self.remove(pos);
        }
    }

    pub fn insert (&self, pos: Coord, new_val: usize) {
        let cell = &self.cell(pos);
        let old_val = cell.value.get();
        if let Some(old_val) = old_val {
            self.remove_from_occurrences (pos.row, pos.col, old_val);
            self.remove_breakages_for (pos.row, pos.col, old_val);
        }
        else {
            self.total_filled.update(|x| x + 1);
        }
        cell.value.set(Some(new_val));
        self.add_to_occurrences(pos.row, pos.col, new_val);
        self.mark_breakages (pos.row, pos.col, new_val);
    }

    pub fn init_cell (&mut self, row: usize, col: usize, val: Option<usize>) {
        if let Some(value) = val {
            self.insert(Coord { row, col }, value);
            self.cells[row][col].fixed = true;
            self.total_fixed += 1;
        }
    }

    fn mark_breakages (&self, row: usize, col: usize, val: usize) {
        if self.digits[val].in_row[row].get() > 1 {
            self.mark_breakages_for (self.coords_for_row[row], val);
        }

        if self.digits[val].in_col[col].get() > 1 {
            self.mark_breakages_for (self.coords_for_col[col], val);
        }

        if self.digits[val].in_block[row / 3][col / 3].get() > 1 {
            self.mark_breakages_for (self.coords_for_block[row / 3][col / 3], val);
        }
    }

    fn mark_breakages_for (&self, coords: [Coord; 9], val: usize) {
        for coord in coords {
            if let Some(target) = self.cells[coord.row][coord.col].value.get()
                && target == val
            {
                self.broken_coords.borrow_mut().insert(coord);
            }
        }
    }

    pub fn has_earmarks (&self, pos: Coord) -> bool {
        for earmark in &self.cells[pos.row][pos.col].earmarks {
            if earmark.get() {
                return true
            }
        }
        false
    }

    pub fn is_fixed (&self, pos: Coord) -> bool {
        self.cells[pos.row][pos.col].fixed
    }

    pub fn cell_possibilies (&self, pos: Coord) -> [bool; 9] {
        from_fn(|num| self.is_earmark_possible(pos, num))
    }

    pub fn is_earmark_possible (&self, pos: Coord, num: usize) -> bool {
        let digit = &self.digits[num];
        digit.in_row[pos.row].get() == 0 &&
        digit.in_col[pos.col].get() == 0 &&
        digit.in_block[pos.row / 3][pos.col / 3].get() == 0
    }

    fn remove_breakages_for (&self, row: usize, col: usize, val: usize) {
        let target = &Coord { row: row, col: col };
        let mut broken_coords = self.broken_coords.borrow_mut();
        if broken_coords.contains(target) {
            for aligned in self.cells[row][col].aligned_coords {
                if let Some(target) = self.cells[aligned.row][aligned.col].value.get() &&
                    target == val &&
                    broken_coords.contains(&aligned) &&
                    self.digits[val].in_row[aligned.row].get() <= 1 &&
                    self.digits[val].in_col[aligned.col].get() <= 1 &&
                    self.digits[val].in_block[aligned.row / 3][aligned.col / 3].get() <= 1 {
                        broken_coords.remove(&aligned);
                }
            }
        }
    }

    fn add_to_occurrences (&self, row: usize, col: usize, val:usize) {
        self.digits[val].increment(row, col);
    }

    fn remove_from_occurrences (&self, row: usize, col: usize, val:usize) {
        self.digits[val].decrement(row, col);
    }

    pub fn is_earmark_enabled (&self, pos: Coord, num: usize) -> bool {
        self.cell(pos).earmarks[num].get()
    }

    pub fn to_json (&self, elapsed_time: f64) -> String {
        let json_board = JsonBoard::from_sudoku_board(self, elapsed_time);
        serde_json::to_string_pretty(&json_board).unwrap()
    }

    pub fn from_json (path: &str) -> Result<Self, SudokuError> {
        use SudokuError::{self as e};
        let mut board : Self = Default::default();
        let file = std::fs::read_to_string(path)?;
        let b: JsonBoard = serde_json::from_str(file.as_str())?;
        //-1 is for timer disabled
        e::true_or_error(b.time_elapsed > 0.0 || b.time_elapsed == -1.0)?;
        board.loaded_time = b.time_elapsed;
        //this is unused as the solver automatically calculates the difficulty
        board.difficulty_category = b.difficulty_category;
        e::true_or_error(b.cells.len() <= 81)?;
        for cell in b.cells.iter() {
            let row = cell.position[0];
            e::true_or_error(row < 9)?;
            let col = cell.position[1];
            e::true_or_error(col < 9)?;
            let val = cell.value;
            e::true_or_error(val <= 9)?;

            if val != 0 {
                board.insert(Coord { row, col }, val - 1);
                if cell.fixed {
                    board.total_fixed += 1;
                    board.cells[row][col].fixed = true;
                }
            }
            e::true_or_error(cell.earmarks.len() <= 9)?;
            for num in &cell.earmarks {
                e::true_or_error(!board.is_earmark_enabled(Coord { row, col }, num - 1))?;
                board.enable_earmark(Coord { row, col }, num - 1);
                e::true_or_error(*num <= 9)?;
            }
        }
        Ok(board)
    }

    pub fn from_generated (
        puzzle: &[[Option<usize>; 9]; 9],
        solution:&[[usize; 9]; 9],
        difficulty: DifficultyCategory
    ) -> Self {
        let mut board = Self::default();
        for row in 0..9 {
            for col in 0..9 {
                board.init_cell(row, col, puzzle[row][col]);
                board.cells[row][col].solution = solution[row][col];
            }
        }
        board.difficulty_category = difficulty;
        board
    }

    pub fn from_string (s: &str) -> Result<Self, SudokuError> {
        if s.len() > 100 || s.len() < 81 {
            return Err(SudokuError::InvalidSaveData);
        }

        let mut row = 0;
        let mut col = 0;
        let mut board = Self::default();
        for c in s.chars() {
            if c == '\n' {
                continue;
            }

            if let Some(c) = c.to_digit(10) {
                board.init_cell(row, col, Some((c - 1) as usize));
            }
            else if c != '.' && c != ' ' && c!= '-' {
                continue;
            }

            if col == 8 {
                if row == 8 {
                    return Ok(board);
                }
                row+=1;
                col = 0;
            }
            else {
                col+=1;
            }
        }

        Err(SudokuError::InvalidSaveData)
    }

    pub fn fixed_to_string (&self) -> String {
        let mut ret = String::from("");
        for row in &self.cells {
            for cell in row {
                ret += &cell.value.get().map_or_else(||"0".to_string(), |m| (m + 1).to_string());
            }
        }
        ret
    }

    pub fn fixed_to_string_pretty (&self) -> String {
        let mut ret = String::from("");
        for row in &self.cells {
            for cell in row {
                ret += &cell.value.get().map_or_else(||".".to_string(), |m| (m + 1).to_string());
            }
            ret+="\n";
        }
        ret
    }

    pub fn fixed_to_string_short (&self) -> String {
        let mut ret = String::from("");
        for row in &self.cells {
            for cell in row {
                if cell.fixed {
                    ret += &(cell.value.get().unwrap() + 1).to_string();
                    if ret.len() == 9 {
                        return ret;
                    }
                }
            }
        }
        ret
    }

    fn to_printable_ascii (val0: u8, val1: u8) -> char {
        (val0 + 33 + val1 * 9) as char
    }

    fn from_printable_ascii (val: u8) -> (u8, u8) {
        ((val - 33) % 9, (val - 33) / 9)
    }

    pub fn fixed_to_ascii(&self) -> String {
        let mut ret = String::from("#");

        //each vectors contain all the positions for that number
        let mut number_positions: [Vec<char>; 9] = from_fn(|_v| Default::default());
        for row in 0..9 {
            for col in 0..9 {
                let cell = &self.cells[row][col];
                if cell.fixed == true {
                    let value = cell.value.get().unwrap();
                    let ascii = Self::to_printable_ascii(row as u8, col as u8);
                    number_positions[value].push(ascii);
                }
            }
        }

        for i in 0..5 {
            let len0 = number_positions[i * 2].len();
            let len1 = {
                if i != 4 {
                    Some(number_positions[i * 2 + 1].len())
                }
                else {
                    None
                }
            };
            ret += &Self::to_printable_ascii(len0 as u8, len1.unwrap_or(0) as u8).to_string();
        }

        for numbers in number_positions {
            for position in numbers {
                ret += &position.to_string();
            }
        }
        ret
    }

    pub fn from_ascii (s: &str) -> Result<SudokuBoard, SudokuError> {
        if !s.starts_with("#") || s.len() < 6 {
            return Err(SudokuError::InvalidSharedPuzzle);
        }
        let ascii = s.split_at(1).1;

        let mut board = Self::default();
        let mut sizes: Vec<_> = Default::default();

        let slices = ascii.split_at(5);
        let value_lengths = slices.0;
        let positions = slices.1;

        for c in value_lengths.chars().enumerate() {
            let new_sizes = Self::from_printable_ascii(c.1 as u8);
            sizes.push(new_sizes.0);
            //there's only 9 values so the last one is half empty
            if c.0 != 4 {
                sizes.push(new_sizes.1);
            }
        }

        let mut len_sum: usize = 6;
        for size in sizes.iter() {
            len_sum += *size as usize;
        }
        if len_sum != s.len() {
            return Err(SudokuError::InvalidSharedPuzzle);
        }

        let mut count = 0;
        let mut current_number = 0;

        for c in positions.chars() {
            while count >= sizes[current_number] {
                count = 0;
                current_number += 1;
                if current_number >= 9 {
                    return Err(SudokuError::InvalidSharedPuzzle);
                }
            }

            let coords = Self::from_printable_ascii(c as u8);
            let row = coords.0 as usize;
            let col = coords.1 as usize;
            if row >= 9 || col >= 9 {
                return Err(SudokuError::InvalidSharedPuzzle);
            }
            board.init_cell(row, col, Some(current_number));

            if count < sizes[current_number] {
                count+=1;
            }
        }

        Ok(board)
    }
}

use serde::{Deserialize, Serialize};
#[derive(Serialize, Deserialize)]
struct JsonBoard {
    difficulty_category: DifficultyCategory,
    time_elapsed: f64,
    cells: Vec<JsonCell>,
}

#[derive(Serialize, Deserialize)]
struct JsonCell {
    position: [usize; 2],
    value: usize,
    fixed: bool,
    earmarks: Vec<usize>
}

impl JsonBoard  {
    fn from_sudoku_board (board: &SudokuBoard, elapsed_time: f64) -> JsonBoard {
        let mut cells : Vec<_> = Vec::with_capacity(81);
        for row in 0..9usize {
            for col in 0..9usize {
                let bcell = &board.cells[row][col];
                let mut v : Vec<usize> = Default::default();
                for earmark in bcell.earmarks.iter().enumerate() {
                    if earmark.1.get() {
                        v.push(earmark.0 + 1);
                    }
                }
                let value = {
                    if let Some(val) = bcell.value.get() {
                        val + 1
                    }
                    else {
                        0
                    }
                };
                let cell = JsonCell{
                    position : [row, col],
                    value: value,
                    fixed : bcell.fixed,
                    earmarks: v
                };
                cells.push(cell);
            }
        }
        JsonBoard { difficulty_category: board.difficulty_category,
            time_elapsed: elapsed_time, cells: cells}
    }
}

#[derive (Debug, PartialEq)]
pub enum SudokuError {
    GenericError,
    FileNotFound,
    InvalidPuzzle,
    MultipleSolutions,
    InvalidSaveData,
    InvalidSharedPuzzle
}

impl fmt::Display for SudokuError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SudokuError::GenericError => write!(f, "SudokuBoard Error"),
            SudokuError::FileNotFound => write!(f, "Save Not Found"),
            SudokuError::InvalidPuzzle => write!(f, "Invalid Puzzle"),
            SudokuError::InvalidSharedPuzzle => write!(f, "Invalid Shared Puzzle Format"),
            SudokuError::MultipleSolutions => write!(f, "Invalid Puzzle: Multiple solutions"),
            SudokuError::InvalidSaveData => write!(f, "Invalid Saved Puzzle"),
        }
    }
}

impl SudokuError {
    pub fn true_or_error (var: bool) -> Result<bool, SudokuError> {
        if var {
            Ok(var)
        }
        else {
            Err(SudokuError::InvalidSaveData)
        }
    }
}

impl From<std::io::Error> for SudokuError {
    fn from(_: std::io::Error) -> Self {
        SudokuError::FileNotFound
    }
}

impl From<SudokuBoard> for SudokuError {
    fn from(_: SudokuBoard) -> Self {
        SudokuError::InvalidSaveData
    }
}

impl From<serde_json::Error> for SudokuError {
    fn from(_: serde_json::Error) -> Self {
        SudokuError::InvalidSaveData
    }
}
