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

//this file was ported over from QQwing https://github.com/stephenostermiller/qqwing

use std::{array::{self, from_fn}, collections::HashSet};


use crate::lib::{enums::Coord, enums::DifficultyCategory};
#[derive (Clone, Debug)]
pub struct SudokuBoardGenerator{
    cells: [[SudokuGeneratorCell; 9]; 9],
    rng: fastrand::Rng,

    //this is much slower than a plain loop so avoid using it in solve
    positions: [Coord; 81],
    positions_random: [Coord; 81],

    random_possibility_array: [usize; 9],

    pub counts: Counts
}

#[derive (Clone, Default, Copy, PartialEq, Debug)]
pub struct SudokuGeneratorCell {
    //the given values go unchanged while solving
    pub value: Option<usize>,
    pub solution: Option<Solution>,
    //Some() = round at which the possibility was disqualified
    pub impossibilities: [Option<usize>; 9],
    //these do not include the cell itself unlike in SudokuBoard
    pub aligned_coords: [Coord; 20]
}

pub struct GeneratorStackAction {
    pos: Coord,
    action: GeneratorAction,
    round: usize
}

impl SudokuGeneratorCell {
    fn local_reset (&mut self) {
        self.solution = Default::default();
        self.impossibilities = Default::default();
    }

    fn reset (&mut self) {
        self.solution = Default::default();
        self.impossibilities = Default::default();
        self.value = Default::default();
    }
}

#[derive (Default, Clone, Copy, PartialEq, Debug)]
pub struct Solution {
    pub value: usize,
    pub round: usize,
}

#[derive (Default, Clone, Copy, Debug)]
pub struct Counts {
    //keep track of the solve types for the difficulty
    singles: u8,
    hidden_singles_row: u8,
    hidden_singles_col: u8,
    hidden_singles_block: u8,
    guesses: u8,
    naked_pairs_row: u8,
    naked_pairs_col: u8,
    naked_pairs_block: u8,
    pointing_pairs_triple_row: u8,
    pointing_pairs_triple_col: u8,
    row_block_reductions: u8,
    col_block_reductions: u8,
    hidden_pairs_row: u8,
    hidden_pairs_col: u8,
    hidden_pairs_block: u8,
}

impl Default for SudokuBoardGenerator {
    fn default() -> Self {
        let random_possibility_array = from_fn(|i| i as usize);
        let positions = from_fn(|i| {
            Coord { row: i % 9, col: i / 9 }
        });
        let positions_random = positions.clone();

        let mut cells : [[SudokuGeneratorCell; 9]; 9] = Default::default();

        //8 in the block + 6 vertically + 6 horizontally so 20 aligned coordinates for each cell
        for pos in positions {
            let mut set: HashSet<Coord> = HashSet::new();
            for row in 0..9 {
                set.insert(Coord { row, col: pos.col });
            }

            for col in 0..9 {
                set.insert(Coord { row: pos.row, col });
            }

            let row_start = pos.row / 3 * 3; //clip to the lower 3 multiplier
            let col_start = pos.col / 3 * 3;
            for row in row_start..row_start + 3 {
                for col in col_start..col_start + 3 {
                    set.insert(Coord { row, col });
                }
            }

            set.remove(&Coord{row: pos.row, col: pos.col});

            for cell in set.iter().enumerate() {
                cells[pos.row][pos.col].aligned_coords[cell.0] = *cell.1;
            }
        }

        Self {
            positions,
            positions_random,
            counts: Default::default(),
            cells: cells,
            random_possibility_array: random_possibility_array,
            //using our own rng is more "efficient" according to the docs
            rng: fastrand::Rng::new(),
        }
    }
}

macro_rules! propagate {
    ($func: expr) => {
        if let Some(result) = $func {
            return Some(result);
        }
    };
}

macro_rules! check_if_only_num {
    ($row: expr, $col: expr, $impossibility: expr, $saved: expr, $label: lifetime) => {
        if $impossibility.is_none() {
            if $saved.is_some(){
                continue $label;
            }
            else {
                $saved = Some(Coord{row:$row, col:$col});
            }
        }
    };
}

macro_rules! return_if_only_num {
    ($s: ident, $pos: expr, $action:expr, $round: expr, $num:expr) => {
        if let Some(pos) = $pos {
            $s.mark(pos.row, pos.col, $round, $num);
            return Some(GeneratorStackAction { pos, action: $action, round:$round});
        }
    };
}

macro_rules! update_pair {
    ($row: expr, $col: expr, $impossibility: expr, $pair: expr, $label: lifetime) => {
        if $impossibility.is_none() {
            if $pair.0.is_none (){
                $pair.0 = Some(Coord{row: $row, col: $col});
            }
            else if $pair.1.is_none (){
                $pair.1 = Some(Coord{row: $row, col: $col});
            }
            else {
                continue $label;
            }
        }
    };
}

macro_rules! unwrap_pair {
    ($pair: expr, $label: lifetime) => {
        if let Some(pos0) = $pair.0 && let Some(pos1) = $pair.1 {
            (pos0, pos1)
        }
        else {
            continue $label;
        }
    };
}

impl SudokuBoardGenerator {
    pub fn cell(&self, pos: Coord) -> &SudokuGeneratorCell {
        &self.cells[pos.row][pos.col]
    }

    pub fn cell_mut(&mut self, pos: Coord) -> &mut SudokuGeneratorCell {
        &mut self.cells[pos.row][pos.col]
    }

    pub fn shuffle_arrays (&mut self) {
        self.rng.shuffle(self.positions_random.as_mut_slice());
        self.rng.shuffle(self.random_possibility_array.as_mut_slice());
    }

    pub fn set_puzzle (&mut self, puzzle: [[Option<usize>; 9]; 9]) -> bool {
        self.reset();
        for row in 0..9 {
            for col in 0..9 {
                self.cells[row][col].value = puzzle[row][col];
            }
        }
        return self.local_reset();
    }

    #[cfg(test)]
    pub fn set_puzzle_qqwing (&mut self, puzzle: &str) -> bool {
        self.reset();
        let mut row = 0;
        let mut col = 0;
        for c in puzzle.chars() {
            if c == '\n' {
                continue;
            }

            if let Some(value) = c.to_digit(10) {
                self.cells[row][col].value = Some(value as usize - 1);
            }
            else if c != '.' {
                panic!("Error setting qqwing puzzle");
            }

            if col == 8 {
                if row == 8 {
                    break;
                }
                row+=1;
                col = 0;
            }
            else {
                col+=1;
            }
        }
        return self.local_reset();
    }

    fn local_reset(&mut self) -> bool {
        //does not reset the cell's value
        for row in 0..9 {
            for col in 0..9 {
                self.cells[row][col].local_reset();
            }
        }

        for row in 0..9 {
            for col in 0..9 {
                let cell = self.cells[row][col];
                if let Some(value) = cell.value {
                    if cell.impossibilities[value].is_some() {
                        self.reset();
                        return false;
                    }
                    else {
                        self.mark(row, col, 0, value);
                    }
                }
            }
        }

        self.counts = Default::default();
        return true;
    }

    fn reset (&mut self) {
        for pos in self.positions {
            self.cell_mut(pos).reset();
        }
        self.counts = Default::default();
    }

    pub fn solve (&mut self) -> Result<[[usize; 9]; 9], ()> {
        if !self.local_reset() {
            panic!("solve error");
        }
        self.shuffle_arrays();
        //round 0 are givens
        if self.solver(1) {
            Ok(self.get_solution())
        }
        else {
            Err(())
        }
    }

    fn solver (&mut self, round: usize) -> bool {
        if self.is_solved() {
            return true;
        }

        if let Some(action) = self.single_solve_move(round) {
            if self.is_impossible() {
                self.rollback_stack(action);
            }
            else if !self.solver(round + 1) {
                self.rollback_stack(action);
                return false;
            }
            else {
                self.counts.add_action(action.action);
                return true;
            }
        }

        let random_array = self.random_possibility_array;
        let pos = self.find_cell_with_fewest_possibilities();
        for value in random_array {
            let impossibility = self.cell(pos).impossibilities[value];
            if impossibility.is_some() {
                continue;
            }

            self.mark(pos.row, pos.col, round, value);
            let action = GeneratorStackAction { pos, action: GeneratorAction::Guess, round };

            if self.is_impossible() {
                self.rollback_stack(action);
            }
            else if !self.solver(round + 1) {
                self.rollback_stack(action);
            }
            else {
                self.counts.add_action(action.action);
                return true;
            }
        }
        false
    }


    fn check_unique_solution (&mut self) -> bool {
        if !self.local_reset() {
            panic!("solve error");
        }
        self.shuffle_arrays();
        //round 0 are givens
        let solutions = self.solver_unique(1);
        self.local_reset();
        solutions == 1
    }

    pub fn solve_unique (&mut self) -> Result<[[usize; 9]; 9], ()> {
        if self.check_unique_solution() {
            return self.solve();
        }
        else {
            Err(())
        }
    }

    fn solver_unique (&mut self, round: usize) -> u8 {
        if self.is_solved() {
            return 1;
        }

        let mut solutions = 0;

        if let Some(action) = self.single_solve_move(round) {
            if self.is_impossible() {
                self.rollback_stack(action);
                return 0;
            }

            solutions += self.solver_unique(round + 1);
            self.rollback_stack(action);
            return solutions;
        }

        let random_array = self.random_possibility_array;
        let pos = self.find_cell_with_fewest_possibilities();
        for value in random_array {
            let impossibility = self.cell(pos).impossibilities[value];
            if impossibility.is_some() {
                continue;
            }

            self.mark(pos.row, pos.col, round, value);
            let action = GeneratorStackAction { pos, action: GeneratorAction::Guess, round };

            if self.is_impossible() {
                self.rollback_stack(action);
            }
            else {
                solutions += self.solver_unique(round + 1);
                self.rollback_stack(action);
                if solutions > 1 {
                    break;
                }
            }
        }
        solutions
    }

    //a grid is impossible whenever a single cell has no solution or possibility left
    fn is_impossible (&self) -> bool {
        for row in 0..9 {
            'a: for col in 0..9 {
                let cell = self.cells[row][col];
                if cell.solution.is_some() {
                    continue;
                }

                for num in 0..9 {
                    if cell.impossibilities[num].is_none() {
                        continue 'a;
                    }
                }

                return true;
            }
        }
        false
    }

    pub fn difficulty (&self) -> DifficultyCategory {
        use DifficultyCategory::*;
        if self.counts.guesses > 0 {
            return VeryHard
        }

        if self.counts.naked_pairs() > 0 {
            return Hard;
        }

        if self.counts.hidden_pairs()> 0  {
            return Hard;
        }

        if self.counts.pointing_pairs()> 0  {
            return Hard;
        }

        if self.counts.block_reductions()> 0  {
            return Hard;
        }

        if self.counts.hidden_pairs()> 0  {
            return Hard;
        }

        if self.counts.hidden_singles() > 0 {
            return Medium;
        }

        if self.counts.singles > 0 {
            return Easy
        }

        panic!("unreachable difficulty");
    }

    fn count_possibilities_limited (&self, pos: Coord, limit: usize) -> bool {
        let mut count = 0;
        for impossibility in self.cell(pos).impossibilities {
            if impossibility.is_some() {
                continue;
            }

            count += 1;
            if count > limit {
                return false;
            }
        }

        count == limit
    }

    fn solve_only_possibility_for_cell (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for row in 0..9 {
            'a: for col in 0..9 {
                let cell = self.cells[row][col];
                if cell.solution.is_some() {
                    continue;
                }

                let mut value = None;
                for i in 0..9 {
                    if cell.impossibilities[i].is_some() {
                        continue;
                    }

                    if value.is_some() {
                        continue 'a;
                    }
                    value = Some(i);
                }

                if let Some(value) = value {
                    self.mark(row, col, round, value);
                    return Some(GeneratorStackAction{ pos: Coord{ row, col },
                        action: GeneratorAction::Single, round });
                }
            }
        }
        None
    }

    //fill cell with the value if it's the number's only possibility in the row
    fn solve_only_value_in_row (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for num in 0..9 {
            'a: for row in 0..9 {
                let mut pos = None;
                for col in 0..9 {
                    let impossibility = self.cells[row][col].impossibilities[num];
                    check_if_only_num!(row, col, impossibility, pos, 'a);
                }
                return_if_only_num!(self, pos, GeneratorAction::HiddenSingleRow, round, num);
            }
        }
        None
    }

    fn solve_only_value_in_col (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for col in 0..9 {
            'a: for num in 0..9 {
                let mut pos = None;
                for row in 0..9 {
                    let impossibility = self.cells[row][col].impossibilities[num];
                    check_if_only_num!(row, col, impossibility, pos, 'a);
                }
                return_if_only_num!(self, pos, GeneratorAction::HiddenSingleCol, round, num);
            }
        }
        None
    }

    fn solve_only_value_in_block (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for row_block in 0..3 {
            for col_block in 0..3 {
                'a: for num in 0..9 {
                    let mut pos = None;
                    for i in 0..9 {
                        let row = row_block * 3 + i / 3;
                        let col = col_block * 3 + i % 3;
                        let impossibility = self.cells[row][col].impossibilities[num];
                        check_if_only_num!(row, col, impossibility, pos, 'a);
                    }
                    return_if_only_num!(self, pos, GeneratorAction::HiddenSingleBlock, round, num);
                }
            }
        }
        None
    }

    //if we have a naked pair, remove possibilities for the pair in its aligned coordinates
    fn solve_naked_pairs (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for row in 0..9 {
            for col in 0..9 {
                let pos = Coord { row, col };
                if !self.count_possibilities_limited(pos, 2) {
                    continue;
                }

                for aligned_pos in self.cell(pos).aligned_coords {
                    if !self.check_if_naked_pair(pos, aligned_pos) {
                        continue;
                    }

                    if let Some(action) = self.clear_pair(round, pos, aligned_pos) {
                        return Some(action);
                    }
                }
            }
        }
        None
    }

    //pairs are identical possibilities that are present in exactly two cells in the same row / column / block
    fn solve_pairs_in_row (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for num0 in 0..9 {
            'a: for row in 0..9 {
                let mut pair0 = (None, None);
                for col in 0..9 {
                    let impossibility = self.cells[row][col].impossibilities[num0];
                    update_pair!(row, col, impossibility, pair0, 'a);
                }
                let pair0 = unwrap_pair!(pair0, 'a);

                'b: for num1 in num0+1..9  {
                    let mut pair1 = (None, None);
                    for col in 0..9 {
                        let impossibility = self.cells[row][col].impossibilities[num1];
                        update_pair!(row, col, impossibility, pair1, 'b);
                    }
                    let pair1 = unwrap_pair!(pair1, 'b);

                    if (pair0.0.col != pair1.0.col || pair0.1.col != pair1.1.col) &&
                       (pair0.1.col != pair1.1.col || pair0.1.col != pair1.0.col){
                        continue;
                    }

                    if let Some(action) = self.nakify_pair(
                            num0, num1,
                            pair0.0, pair1.1,
                            round, GeneratorAction::HiddenPairRow
                        ){
                        return Some(action);
                    }
                }
            }
        }
        None
    }

    fn solve_pairs_in_col (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for num0 in 0..9 {
            'a: for col in 0..9 {
                let mut pair0 = (None, None);
                for row in 0..9 {
                    let impossibility = self.cells[row][col].impossibilities[num0];
                    update_pair!(row, col, impossibility, pair0, 'a);
                }
                let pair0 = unwrap_pair!(pair0, 'a);

                'b: for num1 in num0+1..9  {
                    let mut pair1 = (None, None);
                    for row in 0..9 {
                        let impossibility = self.cells[row][col].impossibilities[num1];
                        update_pair!(row, col, impossibility, pair1, 'b);
                    }
                    let pair1 = unwrap_pair!(pair1, 'b);

                    if (pair0.0.row != pair1.0.row || pair0.1.row != pair1.1.row) &&
                       (pair0.1.row != pair1.1.row || pair0.1.row != pair1.0.row) {
                        continue;
                    }

                    if let Some(action) = self.nakify_pair(
                            num0, num1,
                            pair0.0, pair1.1,
                            round, GeneratorAction::HiddenPairCol
                        ){
                        return Some(action);
                    }
                }
            }
        }
        None
    }

    fn solve_pairs_in_block (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for num0 in 0..9 {
            for row_block in 0..3 {
                'a: for col_block in 0..3  {
                    let mut pair0 = (None, None);
                    for i in 0..9 {
                        let row = row_block * 3 + i / 3;
                        let col = col_block * 3 + i % 3;
                        let impossibility = self.cells[row][col].impossibilities[num0];
                        update_pair!(row, col, impossibility, pair0, 'a);
                    }
                    let pair0 = unwrap_pair!(pair0, 'a);

                    'b: for num1 in num0+1..9  {
                        let mut pair1 = (None, None);
                        for i in 0..9 {
                            let row = row_block * 3 + i / 3;
                            let col = col_block * 3 + i % 3;
                            let impossibility = self.cells[row][col].impossibilities[num1];
                            update_pair!(row, col, impossibility, pair1, 'b);
                        }
                        let pair1 = unwrap_pair!(pair1, 'b);

                        if (pair0.0 != pair1.0 || pair0.1 != pair1.1) &&
                           (pair0.0 != pair1.1 || pair0.1 != pair1.0) {
                            continue;
                        }

                        if let Some(action) = self.nakify_pair(
                                num0, num1,
                                pair0.0, pair1.1,
                                round,
                                GeneratorAction::HiddenPairBlock
                            ){
                            return Some(action);
                        }
                    }
                }
            }
        }
        None
    }

    //2-3 horizontally aligned, equal possibilities in the same block which are exclusive in the block
    //disqualifies the same possibility in the rest of the row
    fn solve_pointing_row (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for row_block in 0..3 {
            for col_block in 0..3 {
                'a: for num in 0..9 {
                    let mut row = None;
                    let mut count = 0;
                    for i in 0..9 {
                        let pos = Coord { row: row_block * 3 + i / 3, col: col_block * 3 + i % 3 };
                        if self.cell(pos).impossibilities[num].is_some() {
                            continue;
                        }

                        if let Some(row) = row {
                            if row == pos.row {
                                count+=1;
                            }
                            else {
                                continue 'a;
                            }
                        }
                        else {
                            row = Some(pos.row);
                            count+=1;
                        }
                    }

                    if count >= 2 {
                        let row = row.unwrap();
                        let col_start = col_block * 3;

                        let mut did_something = false;

                        for tcol in 0..9 {
                            if tcol / 3 == col_block {
                                continue;
                            }

                            let impossibility = &mut self.cells[row][tcol].impossibilities[num];
                            if impossibility.is_none() {
                                *impossibility = Some(round);
                                did_something = true;
                            }
                        }

                        if did_something {
                            return Some(GeneratorStackAction {
                                pos: Coord { row, col: col_start },
                                action: GeneratorAction::PointingPairTripleRow,
                                round
                            });
                        }
                    }
                }
            }
        }
        None
    }

    fn solve_pointing_col (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for row_block in 0..3 {
            for col_block in 0..3 {
                'a: for num in 0..9 {
                    let mut col = None;
                    let mut count = 0;
                    for i in 0..9 {
                        let pos = Coord { row: row_block * 3 + i / 3, col: col_block * 3 + i % 3 };
                        if self.cell(pos).impossibilities[num].is_none(){
                            if let Some(col) = col {
                                if col == pos.col {
                                    count+=1;
                                }
                                else {
                                    continue 'a;
                                }
                            }
                            else {
                                col = Some(pos.col);
                                count+=1;
                            }
                        }
                    }

                    if count >= 2 {
                        let col = col.unwrap();
                        let row_start = row_block * 3;
                        let mut did_something = false;

                        for trow in 0..9 {
                            if trow / 3 == row_block {
                                continue;
                            }

                            let impossibility = &mut self.cells[trow][col].impossibilities[num];
                            if impossibility.is_none() {
                                *impossibility = Some(round);
                                did_something = true;
                            }
                        }

                        if did_something {
                            return Some(GeneratorStackAction {
                                pos: Coord { row: row_start, col },
                                action: GeneratorAction::PointingPairTripleCol,
                                round
                            });
                        }
                    }
                }
            }
        }

        None
    }

    //2-3 horizontally aligned, equal possibilities in the same block which are exclusive in the row
    //disqualifies the same possibility in the rest of the block: reverse pointing row
    fn solve_row_block_reduction (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for row in 0..9 {
            'a: for num in 0..9 {
                let mut count = 0;
                let mut col_block = None;
                for col in 0..9 {
                    let cell = &self.cells[row][col];
                    if cell.impossibilities[num].is_some() {
                        continue;
                    }

                    if let Some(col_block) = col_block {
                        if col_block == col / 3 {
                            count+=1;
                        }
                        else {
                            continue 'a;
                        }
                    }
                    else {
                        col_block = Some(col / 3);
                        count+=1;
                    }
                }

                if count >= 2 {
                    let col_block = col_block.unwrap();
                    let col_start = col_block * 3;
                    let row_start = row / 3 * 3;
                    let mut did_something = false;

                    for trow in row_start..row_start + 3 {
                        for col in col_start..col_start + 3 {
                            if trow == row {
                                continue;
                            }

                            let impossibility = &mut self.cells[trow][col].impossibilities[num];
                            if impossibility.is_none() {
                                *impossibility = Some(round);
                                did_something = true;
                            }
                        }
                    }

                    if did_something {
                        return Some(GeneratorStackAction {
                            pos: Coord { row: row_start, col: col_start },
                            action: GeneratorAction::RowBlockReduction,
                            round
                        });
                    }
                }
            }
        }
        None
    }

    fn solve_col_block_reduction (&mut self, round: usize) -> Option<GeneratorStackAction> {
        for col in 0..9 {
            'a: for num in 0..9 {
                let mut count = 0;
                let mut row_block = None;
                for row in 0..9 {
                    let cell = &self.cells[row][col];
                    if cell.impossibilities[num].is_some() {
                        continue;
                    }

                    if let Some(row_block) = row_block {
                        if row_block == row / 3 {
                            count+=1;
                        }
                        else {
                            continue 'a;
                        }
                    }
                    else {
                        row_block = Some(row / 3);
                        count+=1;
                    }
                }

                if count >= 2 {
                    let row_block = row_block.unwrap();
                    let row_start = row_block * 3;
                    let col_start = col / 3 * 3;
                    let mut did_something = false;

                    for row in row_start..row_start + 3 {
                        for tcol in col_start..col_start + 3 {
                            if tcol == col {
                                continue;
                            }

                            let impossibility = &mut self.cells[row][tcol].impossibilities[num];
                            if impossibility.is_none() {
                                *impossibility = Some(round);
                                did_something = true;
                            }
                        }
                    }

                    if did_something {
                        return Some(GeneratorStackAction {
                            pos: Coord { row: row_start, col: col_start },
                            action: GeneratorAction::ColBlockReduction,
                            round
                        });
                    }
                }
            }
        }
        None
    }

    fn calc_random_symmetry (&mut self) -> Symmetry {
        match self.rng.u8(0..4){
            0 => Symmetry::Rotate90,
            1 => Symmetry::Rotate180,
            2 => Symmetry::Mirror,
            3 => Symmetry::Flip,
            _ => unreachable!("error")
        }
    }

    fn nakify_pair (
        &mut self,
        num0: usize, num1: usize,
        pos0: Coord, pos1: Coord,
        round: usize,
        action: GeneratorAction
    ) -> Option<GeneratorStackAction> {
        let coords = [pos0, pos1];
        for pos in coords {
            let mut did_something = false;
            let cell = self.cell_mut(pos);
            for num in 0..9 {
                if num == num0 || num == num1 {
                    continue;
                }

                if cell.impossibilities[num].is_none() {
                    did_something = true;
                    cell.impossibilities[num] = Some(round);
                }
            }

            //this only nakifies one of the two positions as we are limited by our rollback method
            if did_something {
                return Some(GeneratorStackAction { pos, action, round });
            }
        }
        None
    }

    fn check_if_naked_pair (&self, pos0: Coord, pos1: Coord) -> bool {
        for num in 0..9 {
            if self.cell(pos0).impossibilities[num].is_none() != self.cell(pos1).impossibilities[num].is_none() {
                return false;
            }
        }
        true
    }

    fn is_same_block (pos0: Coord, pos1: Coord) -> bool {
        pos0.row / 3 == pos1.row / 3 && pos0.col / 3 == pos1.col / 3
    }

    #[cfg(test)]
    pub fn generate_board (difficulty: DifficultyCategory) -> ([[Option<usize>; 9]; 9], [[usize; 9]; 9]) {
        let mut generator = SudokuBoardGenerator::default();
        loop {
            generator.new_puzzle();
            generator.solve().unwrap();
            if generator.difficulty() == difficulty {
                break;
            }
        }
        (generator.get_puzzle(), generator.get_solution())
    }

    pub fn new_puzzle (&mut self){
        self.reset();
        let symmetry = self.calc_random_symmetry();

        self.solve().unwrap();
        //store our solution
        for pos in self.positions {
            let cell = self.cell_mut(pos);
            cell.value = Some(cell.solution.unwrap().value);
        }

        //randomize order so it's different than the order in which the puzzle was solved
        self.shuffle_arrays();
        //remove values while we have a unique solution
        for pos in self.positions_random {
            if let Some(value) = self.cell(pos).value {
                let mut syms: [Option<_>; 3] = Default::default();

                match symmetry {
                    Symmetry::Rotate90 => {
                        syms[0] = Some(Coord { row: 8 - pos.row, col: 8 - pos.col} );
                        syms[1] = Some(Coord { row: 8 - pos.col, col: pos.row} );
                        syms[2] = Some(Coord { row: pos.col, col: 8 -  pos.row} );
                    }
                    Symmetry::Rotate180 => syms[0] = Some(Coord { row: 8 - pos.row, col: 8 - pos.col} ),
                    Symmetry::Mirror => syms[0] = Some(Coord { row: pos.row, col: 8 - pos.col }),
                    Symmetry::Flip => syms[0] = Some(Coord { row: 8 - pos.row, col: pos.col} )
                }

                //erase the backed up old value
                self.cell_mut(pos).value = None;

                let mut sym_values: [Option<_>; 3] = Default::default();
                for i in 0..syms.len() {
                    if let Some(sym) = syms[i] && let Some(value) = self.cell(sym).value {
                        sym_values[i] = Some(value);
                        self.cell_mut(sym).value = None;
                    }
                }

                if self.check_unique_solution() {
                    continue;
                };

                //rollback
                self.cell_mut(pos).value = Some(value);
                for i in 0..syms.len() {
                    if let Some(sym) = syms[i] && let Some(value) = sym_values[i] {
                        self.cell_mut(sym).value = Some(value);
                    }
                }
            }
        }
    }

    fn get_pair_possibility (&self, cell: &SudokuGeneratorCell) -> [usize; 2] {
        let mut ret: [Option<usize>; 2] = Default::default();
        for num in 0..9 {
            if cell.impossibilities[num].is_some() {
                continue;
            }

            if ret[0].is_none() {
                ret[0] = Some(num);
            }
            else {
                ret[1] = Some(num);
                break;
            }
        }

        [ret[0].unwrap(), ret[1].unwrap()]
    }

    fn clear_pair (
        &mut self, round: usize,
        pos0: Coord,
        pos1: Coord
    )
    -> Option<GeneratorStackAction> {
        let possibilities = self.get_pair_possibility(&self.cell(pos0));
        let row0 = pos0.row; let col0 = pos0.col;
        let row1 = pos1.row; let col1 = pos1.col;

        if Self::is_same_block(pos0, pos1) {
            let mut did_something = false;
            let row_block_start = row0 / 3 * 3;
            let col_block_start = col0 / 3 * 3;
            for row in row_block_start..row_block_start + 3 {
                for col in col_block_start..col_block_start + 3 {
                    if (col == col0 && row == row0) ||
                       (col == col1 && row == row1) {
                            continue;
                    }

                    for num in possibilities {
                        if self.cells[row][col].impossibilities[num].is_none () {
                            self.cells[row][col].impossibilities[num] = Some(round);
                            did_something = true;
                        }
                    }
                }

            }

            if did_something {
                return Some(
                    GeneratorStackAction {
                        pos: Coord { row: row_block_start, col: col_block_start },
                        action: GeneratorAction::NakedPairBlock,
                        round
                    });
            }
        }

        if col0 == col1 {
            let mut did_something = false;
            let col = col0;
            for row in 0..9 {
                if row == row0 || row == row1 {
                    continue;
                }

                for num in possibilities {
                    if self.cells[row][col].impossibilities[num].is_none () {
                        self.cells[row][col].impossibilities[num] = Some(round);
                        did_something = true;
                    }
                }
            }

            if did_something {
                return Some(GeneratorStackAction {
                    pos: Coord { row: usize::MAX, col },
                    action: GeneratorAction::NakedPairCol,
                    round
                });
            }
        }
        else if row0 == row1 {
            let mut did_something = false;
            let row = row0;
            for col in 0..9 {
                if col == col0 || col == col1 {
                    continue;
                }

                for num in possibilities {
                    if self.cells[row][col].impossibilities[num].is_none () {
                        self.cells[row][col].impossibilities[num] = Some(round);
                        did_something = true;
                    }
                }
            }

            if did_something {
                return Some(GeneratorStackAction {
                    pos: Coord { row, col: usize::MAX },
                    action: GeneratorAction::NakedPairRow,
                    round
                });
           }
        }

        None
    }

    fn single_solve_move (&mut self, round: usize) -> Option<GeneratorStackAction> {
        propagate!(self.solve_only_possibility_for_cell(round));
        propagate!(self.solve_only_value_in_row(round));
        propagate!(self.solve_only_value_in_col(round));
        propagate!(self.solve_only_value_in_block(round));
        propagate!(self.solve_naked_pairs(round));
        propagate!(self.solve_pointing_row(round));
        propagate!(self.solve_pointing_col(round));
        propagate!(self.solve_row_block_reduction(round));
        propagate!(self.solve_col_block_reduction(round));
        propagate!(self.solve_pairs_in_row(round));
        propagate!(self.solve_pairs_in_col(round));
        propagate!(self.solve_pairs_in_block(round));
        None
    }

    pub fn is_solved (&self) -> bool {
        for row in self.cells {
            for cell in row {
                if cell.solution.is_none() {
                    return false;
                }
            }
        }
        true
    }

    //Remove aligned possibilities for value
    fn mark (&mut self, row: usize, col: usize, round: usize, value: usize) {
        let cell = &mut self.cells[row][col];
        if cell.solution.is_some() {
            panic!("Marking position that already has been marked.")
        }

        if cell.impossibilities[value].is_some() {
            panic!("Marking impossible position.")
        }

        cell.solution = Some(Solution{value, round});

        //mark the cell itself as no longer possible
        for impossibility in &mut cell.impossibilities {
            if impossibility.is_none() {
                *impossibility = Some(round);
            }
        }

        //mark aligned coordinates as no longer possible
        for aligned_pos in cell.aligned_coords {
            let impossibility = &mut self.cell_mut(aligned_pos).impossibilities[value];
            if impossibility.is_none() {
                *impossibility = Some(round);
            }
        }
    }

    pub fn get_solution (&self) -> [[usize; 9]; 9]{
        array::from_fn(|row|
            array::from_fn(|col|
                self.cells[row][col].solution.unwrap().value
            )
        )
    }

    pub fn get_puzzle (&self) -> [[Option<usize>; 9]; 9]{
        array::from_fn(|row|
            array::from_fn(|col|
                self.cells[row][col].value
            )
        )
    }

    fn find_cell_with_fewest_possibilities (&self) -> Coord {
        let mut min_possibilities = usize::MAX;
        let mut best_position: Coord = Default::default();
        for row in 0..9 {
            'a: for col in 0..9 {
                let cell = self.cells[row][col];
                if cell.solution.is_some() {
                    continue;
                }

                let mut count = 0;
                for impossibility in cell.impossibilities {
                    if impossibility.is_some() {
                        continue;
                    }

                    count += 1;

                    if count >= min_possibilities {
                        continue 'a;
                    }
                }

                if count < min_possibilities {
                    min_possibilities = count;
                    best_position = Coord { row, col };
                    if min_possibilities == 1 {
                        return best_position
                    }
                }
            }
        }

        best_position
    }

    fn rollback_cell (&mut self, pos: Coord, round: usize) {
        let cell = self.cell_mut(pos);
        cell.solution = None;
        for impossibility in &mut cell.impossibilities {
            if let Some(impos_round) = impossibility && *impos_round == round {
                *impossibility = None;
            }
        }
    }

    fn rollback_pos (&mut self, pos: Coord, round: usize) {
        let cell = self.cell_mut(pos);
        for impossibility in &mut cell.impossibilities {
            if let Some(impos_round) = impossibility && *impos_round == round {
                *impossibility = None;
            }
        }
    }

    fn rollback_aligned (&mut self, pos: Coord, round: usize) {
        self.rollback_cell(pos, round);

        for aligned in self.cell(pos).aligned_coords {
            for num in 0..9 {
                let impossibility = &mut self.cell_mut(aligned).impossibilities[num];
                if let Some(impos_round) = *impossibility && impos_round == round {
                    *impossibility = None;
                }
            }
        }
    }


    fn rollback_stack(&mut self, stack: GeneratorStackAction) {
        let pos = stack.pos;
        let round = stack.round;

        use GeneratorAction::*;
        match stack.action {
            //these call the mark function which affects the entire board
            Guess | Single | HiddenSingleCol | HiddenSingleBlock | HiddenSingleRow
                => self.rollback_aligned(pos, round),
            //these are a bit wasteful as they rollback extra cells
            PointingPairTripleRow | NakedPairRow =>
                for col in 0..9 {
                    let pos = Coord{row: pos.row, col};
                    self.rollback_pos(pos, round);
                },
            PointingPairTripleCol | NakedPairCol =>
                for row in 0..9 {
                    let pos = Coord{row, col: pos.col};
                    self.rollback_pos(pos, round);
                },
            RowBlockReduction | ColBlockReduction | NakedPairBlock => {
                let row_start = pos.row / 3 * 3;
                let col_start = pos.col / 3 * 3;
                for row in row_start..row_start + 3  {
                    for col in col_start..col_start + 3 {
                        let pos = Coord{row, col};
                        self.rollback_pos(pos, round);
                    }
                }
            },
            _ => self.rollback_cell(pos, round),
        }
    }
}

impl Counts {
    pub fn add_action (&mut self, action: GeneratorAction) {
        use GeneratorAction::*;
        match action {
            Single => self.singles += 1,
            HiddenSingleRow => self.hidden_singles_row += 1,
            HiddenSingleCol => self.hidden_singles_col += 1,
            HiddenSingleBlock => self.hidden_singles_block += 1,
            Guess => self.guesses += 1,
            NakedPairRow => self.naked_pairs_row += 1,
            NakedPairCol => self.naked_pairs_col += 1,
            NakedPairBlock => self.naked_pairs_block += 1,
            PointingPairTripleRow => self.pointing_pairs_triple_row += 1,
            PointingPairTripleCol => self.pointing_pairs_triple_col += 1,
            RowBlockReduction => self.row_block_reductions += 1,
            ColBlockReduction => self.col_block_reductions += 1,
            HiddenPairRow => self.hidden_pairs_row += 1,
            HiddenPairCol => self.hidden_pairs_col += 1,
            HiddenPairBlock => self.hidden_pairs_block += 1,
        };
    }

    pub fn hidden_singles (&self) -> u8 {
        self.hidden_singles_row + self.hidden_singles_col + self.hidden_singles_block
    }

    pub fn naked_pairs (&self) -> u8 {
        self.naked_pairs_row + self.naked_pairs_col + self.naked_pairs_block
    }

    pub fn hidden_pairs (&self) -> u8 {
        self.hidden_pairs_row + self.hidden_pairs_col + self.hidden_pairs_block
    }

    pub fn block_reductions (&self) -> u8 {
        self.row_block_reductions + self.col_block_reductions
    }

    pub fn pointing_pairs (&self) -> u8 {
        self.pointing_pairs_triple_row + self.pointing_pairs_triple_col
    }
}

#[cfg(test)]
mod tests {
    use std::time::SystemTime;
    use super::*;
    #[derive (Default, Clone, Copy)]
    pub struct TestCounts {
        //keep track of the solve types for the difficulty
        singles: usize,
        hidden_singles_row: usize,
        hidden_singles_col: usize,
        hidden_singles_block: usize,
        guesses: usize,
        naked_pairs_row: usize,
        naked_pairs_col: usize,
        naked_pairs_block: usize,
        pointing_pairs_triple_row: usize,
        pointing_pairs_triple_col: usize,
        row_block_reductions: usize,
        col_block_reductions: usize,
        hidden_pairs_row: usize,
        hidden_pairs_col: usize,
        hidden_pairs_block: usize,
    }

    impl TestCounts {
        fn add_count(&mut self, counts: &Counts) {
            self.singles += counts.singles as usize;
            self.hidden_singles_row += counts.hidden_singles_row as usize;
            self.hidden_singles_col += counts.hidden_singles_col as usize;
            self.hidden_singles_block += counts.hidden_singles_block as usize;
            self.guesses += counts.guesses as usize;
            self.naked_pairs_row += counts.naked_pairs_row as usize;
            self.naked_pairs_col += counts.naked_pairs_col as usize;
            self.naked_pairs_block += counts.naked_pairs_block as usize;
            self.pointing_pairs_triple_row += counts.pointing_pairs_triple_row as usize;
            self.pointing_pairs_triple_col += counts.pointing_pairs_triple_col as usize;
            self.row_block_reductions += counts.row_block_reductions as usize;
            self.col_block_reductions += counts.col_block_reductions as usize;
            self.hidden_pairs_row += counts.hidden_pairs_row as usize;
            self.hidden_pairs_col += counts.hidden_pairs_col as usize;
            self.hidden_pairs_block += counts.hidden_pairs_block as usize;
        }

        fn print_all (&self) {
            println!("Single: {}", self.singles);
            println!("HiddenSingleRow: {}", self.hidden_singles_row);
            println!("HiddenSingleCol: {}", self.hidden_singles_col);
            println!("HiddenSingleBlock: {}", self.hidden_singles_block);
            println!("Guess: {}", self.guesses);
            println!("NakedPairRow: {}", self.naked_pairs_row);
            println!("NakedPairCol: {}", self.naked_pairs_col);
            println!("NakedPairBlock: {}", self.naked_pairs_block);
            println!("PointingPairTripleRow: {}", self.pointing_pairs_triple_row);
            println!("PointingPairTripleCol: {}", self.pointing_pairs_triple_col);
            println!("RowBlockReduction: {}", self.row_block_reductions);
            println!("ColBlockReduction: {}", self.col_block_reductions);
            println!("HiddenPairRow: {}", self.hidden_pairs_row);
            println!("HiddenPairCol: {}", self.hidden_pairs_col);
            println!("HiddenPairBlock: {}", self.hidden_pairs_block);
        }
    }

    #[test]
    fn test_solver () {
        let mut boardg = SudokuBoardGenerator::default();
        let mut counts : TestCounts = Default::default();
        let mut count_easy = 0;
        let mut count_medium = 0;
        let mut count_hard = 0;
        let mut count_very_hard = 0;
        for _i in 0..100 {
            boardg.new_puzzle();
            boardg.solve().unwrap();
            match boardg.difficulty() {
                DifficultyCategory::Easy => count_easy+=1,
                DifficultyCategory::Medium => count_medium+=1,
                DifficultyCategory::Hard => count_hard+=1,
                DifficultyCategory::VeryHard => count_very_hard+=1,
                _ => panic!("unreachable difficulty")
            }
            counts.add_count(&boardg.counts);
        }
        println!("Solver Test:");
        println!("Generated {} easy puzzles", count_easy);
        println!("Generated {} medium puzzles", count_medium);
        println!("Generated {} hard puzzles", count_hard);
        println!("Generated {} very_hard puzzles", count_very_hard);
        println!("Total solve moves:");
        counts.print_all();
    }
    #[test]
    pub fn test_generate_puzzle () {
        use DifficultyCategory::*;
        let difficulties = [Easy, Medium, Hard, VeryHard];
        for i in 0..5 {
            for difficulty in difficulties {
                let time = SystemTime::now();
                SudokuBoardGenerator::generate_board(difficulty);
                let new_time = SystemTime::now();
                println!("{} Puzzle generated in {}ms",
                    difficulty.to_string(), new_time.duration_since(time).unwrap().as_millis());
            }
        }
    }

    use crate::config;
    #[test]
    pub fn test_qqwing_backwards_compatibility () {
        use DifficultyCategory::*;
        let arr = [
            (std::fs::read_to_string(config::QQWING_EASY).unwrap(), Easy),
            (std::fs::read_to_string(config::QQWING_MEDIUM).unwrap(), Medium),
            (std::fs::read_to_string(config::QQWING_HARD).unwrap(), Hard),
            (std::fs::read_to_string(config::QQWING_VERY_HARD).unwrap(), VeryHard)
        ];

        let mut boardg : SudokuBoardGenerator = Default::default();
        for file in arr {
            for line in file.0.lines().enumerate() {
                if line.0 <= 10000 {
                    boardg.set_puzzle_qqwing(line.1);
                    if boardg.solve_unique().is_err() || boardg.difficulty() != file.1 {
                        panic!("QQWING backwards compatibility test failed, puzzle:{}", line.1);
                    }
                }
            }
        }
    }
}

enum Symmetry {
    Rotate90,
    Rotate180,
    Mirror,
    //upside down
    Flip,
}

#[derive(Default, Clone, Copy, PartialEq)]
pub enum GeneratorAction {
    #[default]
    Single,
    HiddenSingleRow,
    HiddenSingleCol,
    HiddenSingleBlock,
    Guess,
    NakedPairRow,
    NakedPairCol,
    NakedPairBlock,
    PointingPairTripleRow,
    PointingPairTripleCol,
    RowBlockReduction,
    ColBlockReduction,
    HiddenPairRow,
    HiddenPairCol,
    HiddenPairBlock
}
