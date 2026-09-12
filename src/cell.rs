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
use gtk::{ Allocation, GestureClick, TextDirection, gdk::{BUTTON_PRIMARY, BUTTON_SECONDARY, ModifierType}, gio::{SimpleAction, SimpleActionGroup}, glib::{SignalHandlerId, Variant, VariantTy, subclass::Signal}, pango::{AttrList, AttrSize}};

use crate::lib::backend::SudokuBackend;
use crate::lib::enums::Coord;
use crate::lib::game::SudokuGame;
use std::{cell::{Cell, OnceCell}, sync::OnceLock};
use crate::lib::utils::{get_cloned, new_shortcut, new_shortcut_with_args};
use crate::{connect_cb_action, connect_cb_action_with_arg, picker_popover::SudokuPickerPopover};

mod imp {
    use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuCell {
        const NAME: &'static str = "SudokuCell";
        type Type = super::SudokuCell;
        type ParentType = gtk::Widget;

        fn class_init(klass: &mut Self::Class) {
            klass.set_css_name("sudoku-cell");
            new_shortcut_with_args(klass, "cell.show-picker", "Return|KP_Enter|space", true);
            new_shortcut_with_args(klass, "cell.show-picker", "<Primary>Return|<Primary>space|<Primary>KP_Enter", false);

            new_shortcut(klass, "cell.clear", "Delete|BackSpace|KP_0|0");
            for i in 1..10 {
                let accel = i.to_string();
                let accel = accel.clone() + "|KP_" + &accel;
                new_shortcut_with_args(klass, "cell.insert-value", &accel, i - 1);

                let accel = i.to_string();
                let accel = "<Primary>".to_string() + &accel.clone() + "|<Primary>KP_" + &accel;
                new_shortcut_with_args(klass, "cell.insert-earmark", &accel, i - 1);
            }
        }
    }

    pub struct SudokuCell {
        pub insert_earmark_action: SimpleAction,
        pub insert_value_action: SimpleAction,
        pub show_picker_action: SimpleAction,
        pub clear_action: SimpleAction,
        pub value_label: gtk::Label,
        pub earmark_labels: [gtk::Label; 9],
        pub earmark_hide_animations: [adw::TimedAnimation; 9],
        pub insert_value_closure_id: Cell<Option<SignalHandlerId>>,
        pub insert_earmark_closure_id: Cell<Option<SignalHandlerId>>,
        pub backend: OnceCell<SudokuBackend>,
        pub picker_popover: Cell<Option<SudokuPickerPopover>>,
        pub accented: Cell<bool>,
        pub selected: Cell<bool>,
        pub position: OnceCell<Coord>
    }

    impl Default for SudokuCell {
        fn default ()-> Self {
            let value_label: gtk::Label = glib::Object::builder()
                .property("css-name", "sudoku-value")
                .build();

            value_label.add_css_class("numeric");

            let earmark_labels : [_; 9] = std::array::from_fn(|num| {
                let earmark_label: gtk::Label = glib::Object::builder()
                    .property("label", (num + 1).to_string())
                    .property("css-name", "sudoku-earmark")
                    .build();

                earmark_label.add_css_class("numeric");
                earmark_label
            });


            let earmark_hide_animations : [_; 9] = std::array::from_fn(|num| {
                let anim_target = adw::PropertyAnimationTarget::new(&earmark_labels[num], "opacity");
                let hide_animation = adw::TimedAnimation::new(&earmark_labels[num], 1.0, 0.0, 1000, anim_target);
                hide_animation.connect_done(glib::clone!{
                    move |animation|
                    {
                        let label = animation.widget();
                        label.set_visible(false);
                        label.set_opacity(1.0);
                    }
                });
                hide_animation
            });

            Self {
                value_label,
                earmark_labels,
                earmark_hide_animations,
                show_picker_action: SimpleAction::new("show-picker", Some(VariantTy::BOOLEAN)),
                clear_action: SimpleAction::new("clear", None),
                insert_earmark_action: SimpleAction::new("insert-earmark", Some(VariantTy::INT32)),
                insert_value_action: SimpleAction::new("insert-value", Some(VariantTy::INT32)),
                insert_value_closure_id: Default::default(),
                insert_earmark_closure_id: Default::default(),
                backend: Default::default(),
                picker_popover: Default::default(),
                selected: Default::default(),
                accented: Default::default(),
                position: Default::default()
            }
        }
    }

    impl SudokuCell {
        pub fn init (&self) {
            self.backend().connect_earmark_mode_notify (glib::clone!(
                #[weak(rename_to = cell)] self,
                move |_|
                cell.flip_shortcuts()
            ));
            let backend = self.backend();

            if backend.game_fixed(self.pos()){
                self.obj().add_css_class("fixed");
                self.show_picker_action.set_enabled(false);
                self.insert_value_action.set_enabled(false);
                self.insert_earmark_action.set_enabled(false);
            }
            let value = backend.game_value(self.pos());
            if let Some(value) = value {
                self.value_label.set_text(&(value + 1).to_string());
            }
            self.value_label.set_visible(value.is_some());
            self.value_label.set_parent(&*self.obj());

            let click_controller = GestureClick::new();
            click_controller.set_button(0); //all the buttons
            click_controller.connect_released(glib::clone!(
                #[weak(rename_to = cell)] self,
                move |gesture, _, _, _|
                cell.click_cb(gesture)
            ));
            self.obj().add_controller(click_controller);

            for earmark in self.earmark_labels.iter().enumerate() {
                earmark.1.set_visible(backend.game_earmark(self.pos(), earmark.0));
                earmark.1.set_parent(&*self.obj());
            }
        }

        pub fn setup_actions (&self){
            let action_group = SimpleActionGroup::new();
            action_group.add_action(&self.insert_value_action);
            action_group.add_action(&self.insert_earmark_action);
            action_group.add_action(&self.show_picker_action);
            self.obj().insert_action_group("cell", Some(&action_group));

            connect_cb_action!(self, self.clear_action, clear_cb, action_group);
            connect_cb_action_with_arg!(self, self.show_picker_action, show_picker_cb, action_group);
            self.set_default_shortcuts();
        }

        pub fn value (&self) -> Option<usize> {
            self.backend().game_value(self.pos())
        }

        pub fn set_actions (&self, enabled: bool) {
            self.show_picker_action.set_enabled(enabled);
            self.insert_value_action.set_enabled(enabled);
            self.insert_earmark_action.set_enabled(enabled);
        }

        pub fn click_cb (&self, gesture: &gtk::GestureClick) {
            let gesture_button = gesture.current_button();
            if gesture_button != BUTTON_PRIMARY && gesture_button != BUTTON_SECONDARY {
                return;
            }
            gesture.set_state(gtk::EventSequenceState::Claimed);

            let backend = self.backend();
            let double_click_wanted = backend.pref_picker_second_click() ||
                                      (self.value().is_some() && backend.pref_highlight_numbers());

            if backend.game_fixed(self.pos()) ||
               (!self.selected.get() && double_click_wanted)
            {
                self.obj().select();
                return;
            }

            let state = gesture.current_event_state();
            let control_pressed = {
                //this makes sure we're getting only the control mask state in the bit field
                let state = state & ModifierType::CONTROL_MASK;
                match state {
                    ModifierType::CONTROL_MASK => true,
                    _ => false
                }
            };

            let wants_value = !control_pressed;
            if gesture_button == BUTTON_PRIMARY {
                self.obj()
                    .activate_action("cell.show-picker", Some(&(wants_value).to_variant()))
                    .expect("Could not activate picker");
            }
            else {
                self.obj()
                    .activate_action("cell.show-picker", Some(&(!wants_value).to_variant()))
                    .expect("Could not activate picker");
            }
        }

        pub fn show_picker_cb (&self, wants_value: Option<&Variant>) {
            self.obj().select();

            self.obj().emit_by_name::<()>("grab-picker", &[]);
            let picker = get_cloned(&self.picker_popover).into_inner().unwrap();
            println!("picker refcount: {}", &picker.ref_count());

            let wants_value = wants_value.unwrap().get::<bool>().unwrap();
            let wants_value_picker = wants_value ^ self.backend().earmark_mode();

            match wants_value_picker {
                true => picker.show_value_picker(&self.obj()),
                false => picker.show_earmark_picker(&self.obj()),
            }
        }

        pub fn backend (&self) -> &SudokuBackend {
            self.backend.get().unwrap()
        }

        pub fn set_default_shortcuts (&self)
        {
            self.insert_value_closure_id.set(Some(
                self.insert_value_action.connect_activate(glib::clone!(
                    #[weak(rename_to = cell)] self,
                    move |_, var|
                    cell.insert_value_cb(var.unwrap())))
                )
            );

            self.insert_earmark_closure_id.set(Some(
                self.insert_earmark_action.connect_activate(glib::clone!(
                    #[weak(rename_to = cell)] self,
                    move |_, var|
                    cell.toggle_earmark_cb(var.unwrap())))
                )
            );
        }

        pub fn flip_shortcuts (&self) {
            self.insert_value_action.disconnect(self.insert_value_closure_id.take().unwrap());
            self.insert_earmark_action.disconnect(self.insert_earmark_closure_id.take().unwrap());

            if self.backend().earmark_mode() {
                self.insert_value_closure_id.set(Some(
                    self.insert_value_action.connect_activate(glib::clone!(
                        #[weak(rename_to = cell)] self,
                        move |_, var|
                        cell.toggle_earmark_cb(var.unwrap())))
                    )
                );

                self.insert_earmark_closure_id.set(Some(
                    self.insert_earmark_action.connect_activate(glib::clone!(
                        #[weak(rename_to = cell)] self,
                        move |_, var|
                        cell.insert_value_cb(var.unwrap())))
                    )
                );
            }
            else {
                self.set_default_shortcuts();
            }
        }

        pub fn clear_cb (&self) {
            self.backend().game_clear_cell(self.pos());
        }

        pub fn insert_value_cb (&self, variant: &Variant) {
            let val = variant.get::<i32>().unwrap() as usize;
            self.backend().game_set_value(self.pos(), val);
        }

        pub fn toggle_earmark_cb (&self, variant: &Variant) {
            let num = variant.get::<i32>().unwrap();

            self.backend().game_toggle_earmark (
                self.pos(),
                num as usize,
            );
        }

        pub fn set_font_size (label: &gtk::Label, font_size: i32) {
            let attr_list = label.attributes().unwrap_or(AttrList::new());
            attr_list.change(
                AttrSize::new_size_absolute(font_size * gtk::pango::SCALE)
            );
            label.set_attributes(Some(&attr_list));
        }

        pub fn pos (&self) -> Coord {
            *self.position.get().unwrap()
        }

        pub fn earmark_play_hide_animation (&self, num: usize) {
            self.earmark_hide_animations[num].play();
        }

        pub fn earmark_skip_animation (&self, num: usize) {
            if self.earmark_hide_animations[num].state() == adw::AnimationState::Playing {
                self.earmark_hide_animations[num].skip();
            }
        }
    }

    impl ObjectImpl for SudokuCell {
        fn constructed(&self) {
            self.setup_actions();
            self.parent_constructed();
        }

        fn dispose (&self) {
            if let Some(picker) = self.picker_popover.take() {
                picker.unparent();
            }
            self.value_label.unparent();
            for earmark in &self.earmark_labels {
                earmark.unparent();
            }
        }

        fn signals() -> &'static [Signal] {
            static SIGNALS: OnceLock<Vec<Signal>> = OnceLock::new();
            SIGNALS.get_or_init(|| {
                vec![
                    Signal::builder("selected")
                        .build(),
                    Signal::builder("grab-picker")
                        .build(),
                ]
            })
        }
    }

    impl WidgetImpl for SudokuCell {
        fn size_allocate(&self, width: i32, height: i32, baseline: i32) {
            let value_label = &self.value_label;
            if value_label.is_visible() {
                let value_nat = value_label.preferred_size().1;
                let value_width = i32::min(value_nat.width(), width);
                let value_height = i32::min(value_nat.height(), height);
                let value_allocation = Allocation::new(
                    (width - value_width) / 2,
                    (height - value_height) / 2,
                    value_nat.width(),
                    value_nat.height());
                value_label.size_allocate(&value_allocation, baseline);
            }

            if let Some(number_picker) = get_cloned(&self.picker_popover).into_inner() {
                number_picker.present();
            }

            let mut num = 0;
            let max_earmark_size = width / 3; //3 earmarks per row and per column
            for row in (0..3).rev() {
                for col in 0..3 {
                    let earmark = &self.earmark_labels[num];
                    if earmark.is_visible(){
                        let earmark_nat = earmark.preferred_size().1;
                        let earmark_width = i32::min(max_earmark_size, earmark_nat.width());
                        let earmark_height = i32::min(max_earmark_size, earmark_nat.height());
                        let oriented_col = {
                            match self.obj().direction(){
                                TextDirection::Rtl =>  2 - col,
                                _ => col
                            }
                        };
                        let earmark_allocation = Allocation::new(
                            oriented_col * max_earmark_size + (max_earmark_size - earmark_width) / 2,
                            row * max_earmark_size + (max_earmark_size - earmark_height) / 2,
                            earmark_width, earmark_height
                        );
                        earmark.size_allocate(&earmark_allocation, baseline);
                    }

                    num += 1;
                }
            }
        }

        fn grab_focus(&self) -> bool {
            self.obj().emit_by_name::<()>("selected", &[]);
            self.selected.set(true);
            self.parent_grab_focus()
        }
    }
}

glib::wrapper! {
    pub struct SudokuCell(ObjectSubclass<imp::SudokuCell>)
        @extends gtk::Widget,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget;
}

impl SudokuCell {
    pub fn new (row: usize, col: usize) -> Self {
        let cell: Self = glib::Object::builder()
            .property("focusable", true)
            .build();

        cell.imp().position.set(Coord { row, col }).unwrap();
        cell
    }

    pub fn set_font_sizes (&self, height: i32) {
        if self.imp().value_label.is_visible() {
            imp::SudokuCell::set_font_size(&self.imp().value_label,
            (height as f64 * self.imp().backend().pref_zoom().to_value_multiplier()) as i32);
        }

        for earmark in &self.imp().earmark_labels {
            if earmark.is_visible () {
                imp::SudokuCell::set_font_size(&earmark,
                    (height as f64 * self.imp().backend().pref_zoom().to_earmark_multiplier()) as i32);
            }
        }
    }

    pub fn set_accented (&self, enabled: bool) {
        if enabled {
            self.add_css_class("accented");
        }
        else {
            self.remove_css_class("accented");
        }
        self.imp().accented.set(enabled);
    }

    pub fn init (&self, backend: &SudokuBackend) {
        self.imp().backend.set(backend.clone()).expect("Cell is already initialized");
        self.imp().init();
        self.add_game_hooks();
    }

    pub fn set_picker (&self, picker: &SudokuPickerPopover) {
        self.imp().picker_popover.set(Some(picker.clone()));
    }

    pub fn pos (&self) -> Coord {
        *self.imp().position.get().unwrap()
    }

    pub fn drop_picker (&self) {
        self.imp().picker_popover.set(None);
    }

    pub fn highlight_value (&self, enabled: bool) {
        if enabled {
            self.add_css_class("highlight-digit");
        }
        else {
            self.remove_css_class("highlight-digit");
        }
    }

    pub fn highlight_earmark (&self, num: usize, enabled: bool) {
        if enabled {
            self.imp().earmark_labels[num].add_css_class("highlight-digit");
        }
        else {
            self.imp().earmark_labels[num].remove_css_class("highlight-digit");
        }
    }

    pub fn highlight_coord (&self, enabled: bool) {
        if enabled {
            self.add_css_class("highlight-coord");
        }
        else {
            self.remove_css_class("highlight-coord");
        }
    }

    pub fn quiet_select (&self) -> bool {
        self.grab_focus()
    }

    pub fn select (&self) -> bool {
        self.set_accented(true);
        self.grab_focus()
    }

    pub fn unselect (&self) {
        self.set_accented(false);
    }

    pub fn update_value_warnings (&self) {
        let imp = self.imp();
        let value = {
            match imp.value(){
                None => return,
                Some(value) => value
            }
        };

        let mut error = false;

        if imp.backend().pref_duplicate_warnings() &&
            imp.backend().game_broken(self.pos()) {
                error = true;
        }
        else if imp.backend().pref_solution_warnings() {
            let solution = imp.backend().game_solution(self.pos());
            error = value != solution;
        }

        if error {
            imp.value_label.add_css_class("error");
        }
        else {
            imp.value_label.remove_css_class("error");
        }
    }

    pub fn update_all_earmark_warnings (&self) {
        if self.imp().value().is_none() {
            let earmarks = self.imp().backend().game_earmarks(self.pos());
            for num in 0..9 {
                if earmarks[num].get() {
                    self.update_earmark_warnings(num);
                }
            }
        }
    }

    pub fn update_earmark_warnings (&self, num: usize) {
        let imp = self.imp();
        let error = imp.backend().pref_earmark_warnings() &&
            !imp.backend().game_earmark_is_possible(self.pos(), num);

        if error {
            imp.earmark_labels[num].add_css_class("error");
        }
        else {
            imp.earmark_labels[num].remove_css_class("error");
        }
    }

    pub fn add_game_hooks (&self) {
        let backend = self.imp().backend();
        use crate::game;
        game!(backend).connect_closure("paused", false, glib::closure_local!(
            #[weak(rename_to = cell)] self,
            move |_: SudokuGame, paused: bool|
            {
                cell.imp().set_actions(!paused);
                if paused {
                    cell.add_css_class("paused");
                }
                else {
                    cell.remove_css_class("paused");
                }
            }
        ));
    }

    pub fn set_earmark_visibility (&self, num: usize, enabled: bool) {
        self.imp().earmark_skip_animation(num);
        self.imp().earmark_labels[num].set_visible (enabled);
    }

    pub fn update_visibility (&self) {
        let backend = self.imp().backend();
        let value = backend.game_value(self.pos());

        if let Some(value) = value {
            self.imp().value_label.set_label(&(value + 1).to_string());
        }
        self.imp().value_label.set_visible(value.is_some());

        for num in 0..9 {
            let earmark_visible = backend.game_earmark(self.pos(), num);
            self.set_earmark_visibility(num, earmark_visible);
        }

        let fixed = backend.game_fixed(self.pos());
        self.imp().set_actions(!fixed);
        if backend.game_fixed(self.pos()){
            self.add_css_class("fixed");
        }
        else {
            self.remove_css_class("fixed");
        }
    }

    pub fn selected (&self) -> bool {
        self.imp().selected.get()
    }

    pub fn accented (&self) -> bool {
        self.imp().accented.get()
    }

    pub fn update_value_visibility (&self, old_val: Option<usize>, new_val: Option<usize>) {
        if let Some(new_val) = new_val {
            self.imp().value_label.set_label(&(new_val + 1).to_string());
        }
        self.imp().value_label.set_visible(new_val.is_some());
        if old_val.is_none() {
            for num in 0..9 {
                self.set_earmark_visibility(num, false);
            }
        }
    }
}
