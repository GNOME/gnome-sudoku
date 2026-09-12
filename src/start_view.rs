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
use gtk::glib::subclass::InitializingObject;
use gtk::CompositeTemplate;
use std::cell::{Cell, OnceCell, RefCell};
use std::sync::Arc;
use std::time::Duration;
use gettextrs::gettext;
use gtk::{DialogError, FileDialog, FileFilter};
use gtk::gdk::Clipboard;
use gtk::gio::Cancellable;
use gtk::glib::{SignalHandlerId, SourceId};

use crate::menu_button::SudokuMenuButton;
use crate::lib::backend::SudokuBackend;
use crate::lib::utils::new_shortcut;
use crate::lib::enums::DifficultyCategory;

mod imp {
    use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuStartView {
        const NAME: &'static str = "SudokuStartView";
        type Type = super::SudokuStartView;
        type ParentType = adw::Bin;

        fn class_init(klass: &mut Self::Class) {
            klass.bind_template();
            klass.bind_template_callbacks();
            new_shortcut(klass, "app.back", "<Alt>Left|<Alt>KP_Left");
        }

        fn instance_init(obj: &InitializingObject<Self>) {
            SudokuMenuButton::ensure_type();
            obj.init_template();
        }
    }

    #[derive(Default, CompositeTemplate)]
    #[template(resource = "/org/gnome/Sudoku/ui/start-view.ui")]
    pub struct SudokuStartView {
        pub backend: OnceCell<SudokuBackend>,
        pub clipboard_handle: Cell<Option<SignalHandlerId>>,
        pub clipboard: OnceCell<Clipboard>,
        pub clipboard_string: RefCell<String>,
        #[template_child]
        pub headerbar: TemplateChild<adw::HeaderBar>,
        #[template_child]
        pub back_button: TemplateChild<gtk::Button>,
        #[template_child]
        pub custom_check: TemplateChild<gtk::CheckButton>,
        #[template_child]
        pub easy_check: TemplateChild<gtk::CheckButton>,
        #[template_child]
        pub medium_check: TemplateChild<gtk::CheckButton>,
        #[template_child]
        pub hard_check: TemplateChild<gtk::CheckButton>,
        #[template_child]
        pub very_hard_check: TemplateChild<gtk::CheckButton>,
        #[template_child]
        pub start_open_stack: TemplateChild<gtk::Stack>,
        #[template_child]
        pub open_and_shared_box: TemplateChild<gtk::Box>,
        #[template_child]
        pub start_shared_button: TemplateChild<gtk::Button>,
        #[template_child]
        pub open_button_pill: TemplateChild<gtk::Button>,
        #[template_child]
        pub start_button: TemplateChild<gtk::Button>,
    }

    #[gtk::template_callbacks]
    impl SudokuStartView {
        #[template_callback]
        fn start_game_cb (&self, _: &gtk::Button) {
            let backend = self.backend.get().unwrap();
            if self.easy_check.is_active() {
                backend.game_generate(DifficultyCategory::Easy);
            }
            else if self.medium_check.is_active() {
                backend.game_generate(DifficultyCategory::Medium);
            }
            else if self.hard_check.is_active() {
                backend.game_generate(DifficultyCategory::Hard);
            }
            else if self.very_hard_check.is_active() {
                backend.game_generate(DifficultyCategory::VeryHard);
            }
        }

        #[template_callback]
        fn custom_checkbutton_activated_cb (&self, _: &adw::ActionRow) {
            if let Some(child) = self.start_open_stack.visible_child() && child != *self.open_and_shared_box {
                self.start_open_stack.set_visible_child(&*self.open_button_pill);
                self.connect_clipboard();
            }
        }

        #[template_callback]
        fn difficulty_checkbutton_activated_cb (&self, _: &adw::ActionRow) {
            self.start_open_stack.set_visible_child(&*self.start_button);
            if let Some(handle) = self.clipboard_handle.take() {
                self.clipboard.get().unwrap().disconnect(handle);
                self.clipboard_string.replace(Default::default());
            }
        }

        #[template_callback]
        fn open_file_cb (&self, _: &gtk::Button) {
            let file_dialog = FileDialog::new();
            file_dialog.set_accept_label(Some(&gettextrs::gettext("Start Game")));
            let filter = {
                let default = file_dialog.default_filter();
                if default.is_none() {
                    file_dialog.set_default_filter(Some(&FileFilter::new()));
                    file_dialog.default_filter().unwrap()
                }
                else {
                    default.unwrap()
                }
            };
            filter.add_suffix("skp");
            filter.add_suffix("save");
            filter.add_mime_type("text/plain");

            let window : gtk::Window = self.obj().root().and_downcast::<gtk::Window>().unwrap();
            file_dialog.open(Some(&window), None::<&Cancellable>, glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |result| {
                    match result {
                        Ok(file) => {
                            let backend = game_view.backend.get().unwrap();
                            if !backend.game_load(file.path().unwrap().to_str().unwrap()) {
                                game_view.open_fail();
                            }
                        },
                        Err(e) => {
                            if e.matches(DialogError::Failed) {
                                eprintln!("{}", e.message())
                            }
                        }
                    }
                }
            ));
        }

        #[template_callback]
        fn start_shared_game_cb (&self, _: &gtk::Button) {
            self.backend.get().unwrap().tgame_start();
        }

        pub fn open_fail (&self) {
            let dialog = adw::AlertDialog::new(
                Some(&gettext("Failed to import the puzzle, please enter a valid Sudoku puzzle")),
                None
            );
            dialog.add_response("close", &gettext("_Cancel"));
            dialog.add_response("open", &gettext("Try Again"));
            dialog.set_response_appearance("open", adw::ResponseAppearance::Suggested);
            dialog.set_default_response(Some("open"));

            let window : gtk::Window = self.obj().root().and_downcast::<gtk::Window>().unwrap();
            dialog.connect_response(None, glib::clone!(
                #[weak(rename_to = start_view)] self,
                move |_, response|
                if response == "open" {
                    start_view.open_file_cb(&start_view.open_button_pill)
                }
            ));
            dialog.present(Some(&window));
        }

        pub fn connect_clipboard (&self) {
            if let Some(handle) = self.clipboard_handle.take() {
                self.clipboard_handle.set(Some(handle));
            }
            else {
                self.clipboard_handle.set(Some(self.clipboard.get().unwrap().connect_changed(glib::clone!(
                    #[weak(rename_to = start_view)] self,
                    move |_|
                    start_view.clipboard_cb()
                ))));
                self.clipboard_cb();
            }
        }

        pub fn clipboard_cb (&self) {
            let clipboard_cancellable = Arc::new(Cancellable::new());

            let clipboard_cancellable_clone = Arc::clone(&clipboard_cancellable);
            let clipboard_timeout = glib::timeout_add_once(Duration::from_millis(200), glib::clone!(
                move ||
                clipboard_cancellable_clone.cancel()
            ));

            self.clipboard.get().unwrap().read_text_async(Some(Arc::as_ref(&clipboard_cancellable)), glib::clone!(
                #[weak(rename_to = start_view)] self,
                move |result|
                {
                    SourceId::remove(clipboard_timeout);
                    if let Ok(clipboard) = result {
                        if let Some(s) = clipboard {
                            let mut old_string = start_view.clipboard_string.borrow_mut();
                            if s != *old_string {
                                start_view.backend.get().unwrap().check_clipboard(&s);
                                *old_string = s.to_string();
                            }
                        }
                    }
                }
            ));
        }

        pub fn toggle_difficulty_checkbutton (&self) {
            use DifficultyCategory::*;
            match self.backend.get().unwrap().selected_difficulty(){
                Custom => self.custom_check.set_active(true),
                Easy => self.easy_check.set_active(true),
                Medium => self.medium_check.set_active(true),
                Hard => self.hard_check.set_active(true),
                VeryHard => self.very_hard_check.set_active(true),
                _ => eprintln!("Unknown difficulty category")
            }
        }

        pub fn init (&self, backend: &SudokuBackend) {
            self.backend.set(backend.clone()).expect("Start View is already initialized");
            self.clipboard.set(self.obj().clipboard()).unwrap();
            self.toggle_difficulty_checkbutton();
            if self.custom_check.is_active() {
                self.start_open_stack.set_visible_child(&*self.open_button_pill);
            }

            backend.connect_tgame_notify(glib::clone!(
                #[weak(rename_to = start_view)] self,
                move |backend|
                if backend.tgame().is_some () {
                    start_view.start_open_stack.set_visible_child(&*start_view.open_and_shared_box);
                    start_view.start_shared_button.grab_focus();
                }
                else {
                    start_view.start_open_stack.set_visible_child(&*start_view.open_button_pill);
                }
            ));
        }

        pub fn get_selected_difficulty (&self) -> DifficultyCategory {
            use DifficultyCategory::*;
            if self.custom_check.is_active() {
                Custom
            }
            else if self.easy_check.is_active() {
                Easy
            }
            else if self.medium_check.is_active() {
                Medium
            }
            else if self.hard_check.is_active() {
                Hard
            }
            else if self.very_hard_check.is_active() {
                VeryHard
            }
            else {
                panic!("Unreachable difficulty");
            }
        }
    }

    impl ObjectImpl for SudokuStartView {
        fn constructed(&self) {
            self.parent_constructed();
            self.very_hard_check.set_active(true);
        }

        fn dispose(&self) {
            self.backend.get().unwrap().set_selected_difficulty(self.get_selected_difficulty());
        }
    }

    impl WidgetImpl for SudokuStartView {}
    impl BinImpl for SudokuStartView {}
}

glib::wrapper! {
    pub struct SudokuStartView(ObjectSubclass<imp::SudokuStartView>)
        @extends gtk::Widget, adw::Bin,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget;
}

impl SudokuStartView {
    pub fn init (&self, backend: &SudokuBackend) {
        self.imp().init(backend);
    }

    pub fn connect_clipboard (&self) {
        if self.imp().custom_check.is_active() {
            self.imp().connect_clipboard();
        }
    }

    pub fn disconnect_clipboard (&self) {
        if let Some(handle) = self.imp().clipboard_handle.take() {
            self.imp().clipboard.get().unwrap().disconnect(handle);
        }
    }

    pub fn update_view (&self) {
        let imp = self.imp();
        imp.back_button.set_visible(imp.backend.get().unwrap().game_exists());

        let visible_child = imp.start_open_stack.visible_child().unwrap();
        if visible_child == *imp.start_button {
            imp.start_button.grab_focus();
        }
        else if visible_child == *imp.open_and_shared_box {
            imp.start_shared_button.grab_focus();
        }
        else if visible_child == *imp.open_button_pill {
            imp.open_button_pill.grab_focus();
        }
    }
}
