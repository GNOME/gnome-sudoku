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

use adw::subclass::prelude::*;

use gtk::glib;
use gtk::glib::Object;
use gtk::glib::subclass::InitializingObject;
use gtk::CompositeTemplate;
use gtk::glib::{BindingFlags, object::ObjectExt};

use crate::lib::backend::SudokuBackend;

use std::cell::OnceCell;

mod imp {
    use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuPreferencesDialog {
        const NAME: &'static str = "SudokuPreferencesDialog";
        type Type = super::SudokuPreferencesDialog;
        type ParentType = adw::PreferencesDialog;

        fn class_init(klass: &mut Self::Class) {
            klass.bind_template();
        }

        fn instance_init(obj: &InitializingObject<Self>) {
            obj.init_template();
        }
    }

    #[derive(Default, CompositeTemplate)]
    #[template(resource = "/org/gnome/Sudoku/ui/preferences-dialog.ui")]
    pub struct SudokuPreferencesDialog {
            pub backend: OnceCell<SudokuBackend>,
            #[template_child]
            pub show_timer: TemplateChild<adw::SwitchRow>,
            #[template_child]
            pub autoclean_earmarks: TemplateChild<adw::SwitchRow>,
            #[template_child]
            pub number_picker_second_click: TemplateChild<adw::SwitchRow>,
            #[template_child]
            pub show_possibilities: TemplateChild<adw::SwitchRow>,
            #[template_child]
            pub earmark_warnings: TemplateChild<adw::SwitchRow>,
            #[template_child]
            pub solution_warnings: TemplateChild<adw::SwitchRow>,
            #[template_child]
            pub duplicate_warnings: TemplateChild<adw::SwitchRow>,
            #[template_child]
            pub highlight_numbers: TemplateChild<adw::SwitchRow>,
            #[template_child]
            pub highlight_block: TemplateChild<adw::SwitchRow>,
            #[template_child]
            pub highlight_row_column: TemplateChild<adw::SwitchRow>
    }

    impl SudokuPreferencesDialog{
        pub fn backend (&self) -> &SudokuBackend {
            self.backend.get().unwrap()
        }

        pub fn init (&self, backend: &SudokuBackend) {
            self.backend.set(backend.clone()).expect("PreferencesDialog is already initialized");

            self.backend().bind_property("pref-timer", &*self.show_timer, "active")
                .flags(BindingFlags::SYNC_CREATE | BindingFlags::BIDIRECTIONAL).build();
            self.backend().bind_property("pref-autoclean-earmarks", &*self.autoclean_earmarks, "active")
                .flags(BindingFlags::SYNC_CREATE | BindingFlags::BIDIRECTIONAL).build();
            self.backend().bind_property("pref-picker-second-click", &*self.number_picker_second_click, "active")
                .flags(BindingFlags::SYNC_CREATE | BindingFlags::BIDIRECTIONAL).build();
            self.backend().bind_property("pref-show-all-possibilities", &*self.show_possibilities, "active")
                .flags(BindingFlags::SYNC_CREATE | BindingFlags::BIDIRECTIONAL).build();
            self.backend().bind_property("pref-duplicate-warnings", &*self.duplicate_warnings, "active")
                .flags(BindingFlags::SYNC_CREATE | BindingFlags::BIDIRECTIONAL).build();
            self.backend().bind_property("pref-solution-warnings", &*self.solution_warnings, "active")
                .flags(BindingFlags::SYNC_CREATE | BindingFlags::BIDIRECTIONAL).build();
            self.backend().bind_property("pref-earmark-warnings", &*self.earmark_warnings, "active")
                .flags(BindingFlags::SYNC_CREATE | BindingFlags::BIDIRECTIONAL).build();
            self.backend().bind_property("pref-highlight-row-column", &*self.highlight_row_column, "active")
                .flags(BindingFlags::SYNC_CREATE | BindingFlags::BIDIRECTIONAL).build();
            self.backend().bind_property("pref-highlight-block", &*self.highlight_block, "active")
                .flags(BindingFlags::SYNC_CREATE | BindingFlags::BIDIRECTIONAL).build();
            self.backend().bind_property("pref-highlight-numbers", &*self.highlight_numbers, "active")
                .flags(BindingFlags::SYNC_CREATE | BindingFlags::BIDIRECTIONAL).build();
        }
    }

    impl ObjectImpl for SudokuPreferencesDialog {}
    impl WidgetImpl for SudokuPreferencesDialog {}
    impl AdwDialogImpl for SudokuPreferencesDialog {}
    impl PreferencesDialogImpl for SudokuPreferencesDialog {}
}

glib::wrapper! {
    pub struct SudokuPreferencesDialog(ObjectSubclass<imp::SudokuPreferencesDialog>)
    @extends adw::PreferencesDialog, adw::Dialog, gtk::Widget,
    @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget, gtk::ShortcutManager;
}

impl SudokuPreferencesDialog {
    pub fn new (backend: &SudokuBackend) -> Self {
        let dialog: Self = Object::builder()
            .build();

        dialog.imp().init(backend);
        return dialog;
    }
}
