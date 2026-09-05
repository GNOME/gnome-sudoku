/* -*- Mode: rust; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2025 Johan GAY
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

pub const APP_ID: &str = option_env!("APP_ID").expect("Could not find APP_ID");
pub const VERSION: &str = option_env!("VERSION").expect("Could not find VERSION");
pub const GETTEXT_PACKAGE: &str = option_env!("GETTEXT_PACKAGE").expect("Could not find GETTEXT_PACKAGE");
pub const LOCALEDIR: &str = option_env!("LOCALEDIR").expect("Could not find LOCALEDIR");
#[cfg(test)]
pub const QQWING_HARD: &str = option_env!("QQWING_HARD").expect("Could not find QQWING");
#[cfg(test)]
pub const QQWING_VERY_HARD: &str = option_env!("QQWING_VERY_HARD").expect("Could not find QQWING");
#[cfg(test)]
pub const QQWING_EASY: &str = option_env!("QQWING_EASY").expect("Could not find QQWING");
#[cfg(test)]
pub const QQWING_MEDIUM: &str = option_env!("QQWING_MEDIUM").expect("Could not find QQWING");
pub const GNOME_SUDOKU_RESOURCES: &[u8] = include_bytes!(env!("GNOME_SUDOKU_RESOURCES_FILE"));
pub const SMALL_WINDOW_WIDTH: i32 = 360;
pub const MEDIUM_WINDOW_WIDTH: i32 = 600;
