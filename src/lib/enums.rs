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

use gtk::glib::types::{StaticType, Type};
use gtk::glib::value::{Value, FromValue, ToValue, GenericValueTypeChecker};
use gtk::glib::variant::{FromVariant, StaticVariantType, ToVariant};
use gtk::{self, DirectionType};
use gtk::glib::{self, Variant, VariantTy};
use serde::{Deserialize, Serialize};

//must remain aligned with gschema
#[derive(Default, Debug, Copy, Clone, PartialEq, Eq, glib::Enum, Hash)]
#[enum_type(name = "DifficultyCategory")]
pub enum DifficultyCategory {
    Unknown = 0,
    #[default] Easy = 1,
    Medium = 2,
    Hard = 3,
    VeryHard = 4,
    Custom = 5
}

#[derive(Default, PartialEq, Eq, Hash, Clone, Copy, Debug)]
pub struct Coord {
    pub row: usize,
    pub col: usize,
}

impl DifficultyCategory {
    pub fn to_translated_string (&self) -> String
    {
        use DifficultyCategory::*;
        use gettextrs::gettext;
        match self {
            Easy => gettext("Easy Difficulty"),
            Medium =>  gettext("Medium Difficulty"),
            Hard =>  gettext("Hard Difficulty"),
            VeryHard =>  gettext("Very Hard Difficulty"),
            _ => {
                eprintln!("Unknown difficulty, this is a bug - please report it");
                "BUG - UNKNOWN DIFFICULTY".to_string()
            },
        }
    }

    pub fn to_string (&self) -> String {
        use DifficultyCategory::*;
        match self {
            Easy => "Easy Difficulty".to_string(),
            Medium =>  "Medium Difficulty".to_string(),
            Hard =>  "Hard Difficulty".to_string(),
            VeryHard =>  "Very Hard Difficulty".to_string(),
            Custom =>  "Custom Difficulty".to_string(),
            _ => {
                eprintln!("Unknown difficulty, this is a bug - please report it");
                "BUG - UNKNOWN DIFFICULTY".to_string()
            },
        }
    }

    pub fn from_string (s: &str) -> Self {
        use DifficultyCategory::*;
        match s {
            "Easy Difficulty" => Easy,
            "Medium Difficulty" => Medium,
            "Hard Difficulty" => Hard,
            "Very Hard Difficulty" => VeryHard,
            "Custom Difficulty" => Custom,
            _ => {
                eprintln!("Unknown difficulty, this is a bug - please report it");
                Unknown
            }
        }
    }
}

impl Serialize for DifficultyCategory {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer
    {
        serializer.serialize_str(&self.to_string())
    }
}

impl <'de>Deserialize<'de> for DifficultyCategory {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>
    {
        let s = String::deserialize(deserializer)?;
        Ok(DifficultyCategory::from_string(&s))
    }
}

impl From<i32> for DifficultyCategory {
    fn from(value: i32) -> Self {
        use DifficultyCategory::*;
        match value {
            0 => Unknown,
            1 => Easy,
            2 => Medium,
            3 => Hard,
            4 => VeryHard,
            5 => Custom,
            _ => Unknown
        }
    }
}

impl Into<i32> for DifficultyCategory {
    fn into(self) -> i32 {
        use DifficultyCategory::*;
        match self {
            Unknown => 0,
            Easy => 1,
            Medium => 2,
            Hard => 3,
            VeryHard => 4,
            Custom => 5,
        }
    }
}

impl From<u32> for DifficultyCategory {
    fn from(value: u32) -> Self {
        use DifficultyCategory::*;
        match value {
            0 => Unknown,
            1 => Easy,
            2 => Medium,
            3 => Hard,
            4 => VeryHard,
            5 => Custom,
            _ => Unknown
        }
    }
}

impl Into<u32> for DifficultyCategory {
    fn into(self) -> u32 {
        use DifficultyCategory::*;
        match self {
            Unknown => 0,
            Easy => 1,
            Medium => 2,
            Hard => 3,
            VeryHard => 4,
            Custom => 5,
        }
    }
}

impl FromVariant for DifficultyCategory {
    fn from_variant(variant: &Variant) -> Option<Self> {
        use DifficultyCategory::*;
        let variant = variant.get::<String>().unwrap();
        let variant = variant.as_str();
        match variant {
            "unknown" => Some(Unknown),
            "easy" => Some(Easy),
            "medium" => Some(Medium),
            "hard" => Some(Hard),
            "very-hard" => Some(VeryHard),
            "custom" => Some(Custom),
            _ => panic!()
        }
    }
}

impl StaticVariantType for DifficultyCategory {
    fn static_variant_type() -> std::borrow::Cow<'static, VariantTy> {
        String::static_variant_type()
    }
}

pub enum SudokuDirection {
    TabForward,
    TabBackward,
    Up,
    Down,
    Left,
    Right,
    __Unknown(i32),
}

impl FromVariant for SudokuDirection {
    fn from_variant(variant: &Variant) -> Option<Self> {
        use SudokuDirection::*;
        let variant = variant.get::<i32>().unwrap();
        match variant {
            0 => Some(TabForward),
            1 => Some(TabBackward),
            2 => Some(Up),
            3 => Some(Down),
            4 => Some(Left),
            5 => Some(Right),
            _ => panic!()
        }
    }
}
impl StaticVariantType for SudokuDirection {
    fn static_variant_type() -> std::borrow::Cow<'static, VariantTy> {
        i32::static_variant_type()
    }
}

impl ToVariant for SudokuDirection {
    fn to_variant(&self) -> Variant {
        use SudokuDirection::*;
        match self {
            TabForward => 0.to_variant(),
            TabBackward => 1.to_variant(),
            Up => 2.to_variant(),
            Down => 3.to_variant(),
            Left => 4.to_variant(),
            Right => 5.to_variant(),
            _ => panic!()
        }
    }
}

impl From<DirectionType> for SudokuDirection {
    fn from(value: DirectionType) -> Self {
        use SudokuDirection::*;
        use gtk::DirectionType as d;
        match value {
            d::TabForward => TabForward,
            d::TabBackward => TabBackward,
            d::Up => Up,
            d::Down => Down,
            d::Left => Left,
            d::Right => Right,
            _ => panic!()
        }
    }
}

impl Into<DirectionType> for SudokuDirection {
    fn into(self) -> gtk::DirectionType {
        use SudokuDirection::*;
        use gtk::DirectionType as d;
        match self {
            TabForward => d::TabForward,
            TabBackward => d::TabBackward,
            Up => d::Up,
            Down => d::Down,
            Left => d::Left,
            Right => d::Right,
            _ => panic!()
        }
    }
}

//must remain aligned with gschema
#[derive(Default, Debug, Copy, Clone, PartialEq, Eq, glib::Enum)]
#[enum_type(name = "ZoomLevel")]
pub enum ZoomLevel
{
    None = 0,
    Small = 1,
    #[default] Medium = 2,
    Large = 3
}

impl ZoomLevel{
    pub fn is_fully_zoomed_out (&self) -> bool {
        use ZoomLevel::*;
        match self {
            Small => true,
            _ => false
        }
    }

    pub fn is_fully_zoomed_in (&self) -> bool {
        use ZoomLevel::*;
        match self {
            Large => true,
            _ => false
        }
    }

    pub fn zoom_in (&self) -> ZoomLevel {
        use ZoomLevel::*;
        match self {
            Small => Medium,
            Medium => Large,
            _ => {
                eprintln! ("Zoom error");
                Medium
            }
        }
    }

    pub fn zoom_out (&self) -> ZoomLevel {
        use ZoomLevel::*;
        match self {
            Large => Medium,
            Medium => Small,
            _ => {
                eprintln! ("Zoom error");
                Medium
            }
        }
    }

    pub fn to_value_multiplier (&self) -> f64 {
        use ZoomLevel::*;
        match self {
            Small => 0.4,
            Medium => 0.5,
            Large => 0.6,
            _ => {
                eprintln! ("Zoom error");
                0.5
            }
        }
    }

    pub fn to_earmark_multiplier (&self) -> f64 {
        use ZoomLevel::*;
        match self {
            Small => 0.25,
            Medium => 0.25,
            Large => 0.3,
            _ => {
                eprintln! ("Zoom error");
                0.25
            }
        }
    }
}

//this lets us transform back and forth an i32 into an Option<usize>
//careful when accessing directly the inner value as i32::MAX is None
#[derive(Clone, Copy)]
pub struct CompatValue(pub i32);

impl ToValue for CompatValue {
    fn to_value(&self) -> Value {
        self.0.to_value()
    }

    fn value_type(&self) -> Type {
        i32::static_type()
    }
}

impl From<Option<usize>> for CompatValue {
    fn from(value: Option<usize>) -> Self {
        match value {
            None => Self(i32::MAX),
            Some(val) => Self(val as i32)
        }
    }
}

impl Into<Option<usize>> for CompatValue {
    fn into(self) -> Option<usize> {
        match self.0 {
            i32::MAX => None,
            _ => Some(self.0 as usize)
        }
    }
}

impl StaticType for CompatValue {
    fn static_type() -> glib::Type {
        i32::static_type()
    }
}

unsafe impl <'a>FromValue<'a> for CompatValue {
    type Checker = GenericValueTypeChecker<Self>;
    #[inline]
    unsafe fn from_value(value: &'a Value) -> Self {
        unsafe { Self(i32::from_value(value)) }
    }
}

