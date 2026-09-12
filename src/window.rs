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
use adw::StyleManager;

use crate::game;
use crate::config;
use crate::start_view::SudokuStartView;
use crate::game_view::SudokuGameView;
use crate::lib::backend::SudokuBackend;
use crate::lib::utils::new_shortcut;
use crate::lib::enums::ZoomLevel;
use crate::{connect_cb_action, create_cb_entry, preferences_dialog::SudokuPreferencesDialog, print_generator_dialog::SudokuPrintGeneratorDialog};

use gtk::gio;
use gtk::gio::SimpleActionGroup;

use gtk::{CssProvider, gio::SimpleAction, glib::Type};
use gtk::EventControllerKey;
use gtk::CompositeTemplate;

use gtk::glib::closure_local;
use gtk::glib::{self};
use gtk::glib::subclass::InitializingObject;

use std::cell::{Cell, OnceCell};

mod imp {
    use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuWindow {
        const NAME: &'static str = "SudokuWindow";
        type Type = super::SudokuWindow;
        type ParentType = adw::ApplicationWindow;

        fn class_init(klass: &mut Self::Class) {
            klass.bind_template();
            new_shortcut(klass, "app.preferences_dialog", "<Primary>comma");
            new_shortcut(klass, "app.shortcuts-dialog", "<Primary>question");
            new_shortcut(klass, "app.print-generator-dialog", "<Primary>P");
            new_shortcut(klass, "app.new-game", "<Primary>n");
            new_shortcut(klass, "app.help", "F1");
            new_shortcut(klass, "app.toggle-fullscreen", "F11|f");
            new_shortcut(klass, "app.swap-view", "A");
            new_shortcut(klass, "app.zoom-in", "<Primary>plus|<Primary>equal|ZoomIn|<Primary>KP_Add");
            new_shortcut(klass, "app.zoom-out", "<Primary>minus|ZoomOut|<Primary>KP_Subtract");
            new_shortcut(klass, "app.zoom-reset", "<Primary>0|<Primary>KP_0");
        }

        fn instance_init(obj: &InitializingObject<Self>) {
            SudokuStartView::ensure_type();
            SudokuGameView::ensure_type();
            obj.init_template();
        }
    }

    #[derive(CompositeTemplate)]
    #[template(resource = "/org/gnome/Sudoku/ui/window.ui")]
    pub struct SudokuWindow {
        pub visible_dialogue_type: Cell<Option<Type>>,
        pub print_multiple_action: SimpleAction,
        pub new_game_action: SimpleAction,
        pub zoom_in_action: SimpleAction,
        pub zoom_out_action: SimpleAction,
        pub accent_provider: CssProvider,
        pub style_manager: StyleManager,
        pub backend: OnceCell<SudokuBackend>,
        #[template_child]
        pub start_view: TemplateChild<SudokuStartView>,
        #[template_child]
        pub game_view: TemplateChild<SudokuGameView>,
        #[template_child]
        pub view_stack: TemplateChild<adw::ViewStack>,
        #[template_child]
        pub settings: TemplateChild<gio::Settings>,
    }

    impl ObjectImpl for SudokuWindow {
        fn constructed(&self) {
            self.setup_actions();

            self.settings.bind("default-height", self.obj().as_ref(), "default-height").build();
            self.settings.bind("default-width", self.obj().as_ref(), "default-width").build();
            self.settings.bind("window-is-fullscreen", self.obj().as_ref(), "fullscreened").build();
            self.settings.bind("window-is-maximized", self.obj().as_ref(), "maximized").build();

            let keyboard_controller = EventControllerKey::new();
            keyboard_controller.set_propagation_phase(gtk::PropagationPhase::Capture);
            keyboard_controller.connect_key_pressed(glib::clone!(
                #[weak(rename_to = win)] self,
                #[upgrade_or] glib::Propagation::Proceed,
                move |_, _, _, _| {
                    win.backend().set_keyboard_pressed_recently(true);
                    return glib::Propagation::Proceed
                }
            ));
            self.obj().add_controller(keyboard_controller);

            gtk::style_context_add_provider_for_display(
                &RootExt::display(&*self.obj()),
                &self.accent_provider,
                gtk::STYLE_PROVIDER_PRIORITY_APPLICATION
            );
            self.obj().connect_visible_dialog_notify(glib::clone!(
                #[weak(rename_to = win)] self,
                move |_|
                win.visible_dialog_cb()
            ));
            self.set_accent_color(&self.style_manager);
            self.style_manager.connect_accent_color_notify(glib::clone!(
                #[weak(rename_to = win)] self,
                move |manager : &StyleManager|
                win.set_accent_color(&manager)
            ));

            self.obj().set_width_request(config::SMALL_WINDOW_WIDTH);
            let measure = self.start_view.imp().headerbar.measure(gtk::Orientation::Vertical, -1);
            let headerbar_natural_height = measure.1;
            let small_window_height = headerbar_natural_height + config::SMALL_WINDOW_WIDTH;
            self.obj().set_height_request(small_window_height);

            self.parent_constructed();
        }

        fn dispose(&self) {
            println!("window disposed");
        }
    }

    impl Default for SudokuWindow {
        fn default() -> Self {
            SudokuWindow {
                style_manager: StyleManager::default(),
                accent_provider: CssProvider::new(),
                new_game_action: SimpleAction::new("new-game", None),
                print_multiple_action: SimpleAction::new("print-generator", None),
                zoom_in_action: SimpleAction::new("zoom-in", None),
                zoom_out_action: SimpleAction::new("zoom-out", None),
                backend: Default::default(),
                visible_dialogue_type: Cell::new(None),
                start_view: Default::default(),
                game_view: Default::default(),
                view_stack: Default::default(),
                settings: Default::default()
            }
        }
    }

    impl SudokuWindow {
        pub fn init (&self, backend: &SudokuBackend) {
            self.backend.set(backend.clone()).expect("Window is already initialized");
            self.start_view.init(backend);

            self.zoom_in_action.set_enabled(!self.backend().pref_zoom().is_fully_zoomed_in());
            self.zoom_out_action.set_enabled(!self.backend().pref_zoom().is_fully_zoomed_out());

            backend.connect_closure("game-changed", false, glib::closure_local!(
                #[weak(rename_to = win)] self,
                move |_: SudokuBackend| {
                    if !win.game_view.initialized(){
                        win.game_view.init(win.backend());
                    }

                    win.show_game_view();
                    win.add_game_hooks();
                }
            ));

            if self.backend().game_exists() {
                self.game_view.init(backend);
                self.show_game_view();
            }
            else {
                self.show_start_view();
            }
        }

        fn setup_actions (&self) {
            let action_group = SimpleActionGroup::new();

            let actions = [
                create_cb_entry!(self, "preferences-dialog", preferences_dialog_cb),
                create_cb_entry!(self, "toggle-fullscreen", toggle_fullscreen_cb),
                create_cb_entry!(self, "print-generator-dialog", print_generator_dialog_cb),
                create_cb_entry!(self, "shortcuts-dialog", shortcuts_dialog_cb),
                create_cb_entry!(self, "back", back_cb),
                create_cb_entry!(self, "zoom-reset", zoom_reset),
                create_cb_entry!(self, "about-dialog", about_dialog_cb),
            ];
            action_group.add_action_entries(actions);

            //we keep a reference to these to disable them
            connect_cb_action!(self, self.zoom_in_action, zoom_in, action_group);
            connect_cb_action!(self, self.zoom_out_action,  zoom_out, action_group);
            connect_cb_action!(self, self.new_game_action,  new_game_cb, action_group);
            self.obj().insert_action_group("app", Some(&action_group));
        }

        fn add_game_hooks (&self) {
            game!(self.backend()).connect_closure("paused", false, closure_local!{
                #[weak(rename_to = win)] self,
                move |_ : glib::Object, paused: bool|
                win.new_game_action.set_enabled(!paused)
            });
        }

        fn back_cb (&self) {
            if self.backend().game_exists() {
                self.show_game_view();
                self.backend().game_start_clock();
            }
        }

        fn preferences_dialog_cb(&self) {
            let preferences_dialog = SudokuPreferencesDialog::new(&self.backend());
            preferences_dialog.present(Some(self.obj().as_ref()));
        }

        fn print_generator_dialog_cb(&self) {
            let print_generator_dialog = SudokuPrintGeneratorDialog::new(&self.backend());
            print_generator_dialog.present(Some(self.obj().as_ref()));
        }

        fn shortcuts_dialog_cb (&self) {
            let shortcuts_dialog : adw::ShortcutsDialog = gtk::Builder
                ::from_resource("/org/gnome/Sudoku/ui/shortcuts-dialog.ui")
                .object("SudokuShortcutsDialog").unwrap();
            shortcuts_dialog.present(Some(self.obj().as_ref()));
        }

        fn new_game_cb (&self) {
            if self.backend().game_exists() {
                self.backend().game_stop_clock();
            }

            self.show_start_view();
        }

        pub fn backend (&self) -> &SudokuBackend {
            self.backend.get().unwrap()
        }

        fn set_accent_color (&self, manager: &StyleManager) {
            let color = manager.accent_color();
            let css_color = {
                use adw::AccentColor::*;
                match color {
                    Blue => "blue",
                    Teal => "teal",
                    Green => "green",
                    Yellow => "yellow",
                    Orange => "orange",
                    Red => "red",
                    Pink => "pink",
                    Purple => "purple",
                    Slate => "slate",
                    _ => "blue",
                }
            };
            let s = ":root {--sudoku-accent-color: var(--sudoku-accent-".to_string() + css_color + ");}";
            self.accent_provider.load_from_string(&s);
        }

        fn about_dialog_cb (&self) {
            let about_dialog = adw::AboutDialog::from_appdata("/org/gnome/Sudoku/metainfo.xml", Some(config::VERSION));
            let authors =  [
                "Robert Ancell <robert.ancell@gmail.com>",
                "Christopher Baines <cbaines8@gmail.com>",
                "Thomas M. Hinkle <Thomas_Hinkle@alumni.brown.edu>",
                "Parin Porecha <parinporecha@gmail.com>",
                "John Stowers <john.stowers@gmail.com>",
                "Jamie Murphy <jmurphy@gnome.org>",
            ];
            about_dialog.set_version (config::VERSION);
            about_dialog.set_copyright ("Copyright © 2005–2008 Thomas M. Hinkle\nCopyright © 2010–2011 Robert Ancell\nCopyright © 2014 Parin Porecha\nCopyright © 2023 Jamie Murphy\nCopyright © 2024-2026 Johan Gay");
            about_dialog.set_developers (&authors);
            about_dialog.set_translator_credits (&gettextrs::gettext("translator-credits"));
            about_dialog.present (Some(self.obj().as_ref()));
        }

        fn toggle_fullscreen_cb (&self) {
            self.obj().set_fullscreened(!self.obj().is_fullscreen());
        }

        pub fn start_screen_active (&self) -> bool {
            self.view_stack.visible_child().unwrap() == *self.start_view
        }

        fn show_start_view (&self) {
            self.view_stack.set_visible_child(&*self.start_view);
            self.start_view.update_view();
            self.start_view.connect_clipboard();
        }

        fn show_game_view (&self) {
            self.start_view.disconnect_clipboard();
            self.view_stack.set_visible_child(&*self.game_view);
            self.game_view.grab_focus();
        }

        fn zoom_in (&self) {
            let backend = self.backend();
            backend.set_pref_zoom(backend.pref_zoom().zoom_in());
            if backend.pref_zoom().is_fully_zoomed_in() {
                self.zoom_in_action.set_enabled(false);
            }
            self.zoom_out_action.set_enabled(true);
        }

        fn zoom_out (&self) {
            let backend = self.backend();
            backend.set_pref_zoom(backend.pref_zoom().zoom_out());
            if backend.pref_zoom().is_fully_zoomed_out() {
                self.zoom_out_action.set_enabled(false);
            }
            self.zoom_in_action.set_enabled(true);
        }

        fn zoom_reset (&self) {
            let backend = self.backend();
            backend.set_pref_zoom(ZoomLevel::default());
            self.zoom_in_action.set_enabled(true);
            self.zoom_out_action.set_enabled(true);
        }

        fn visible_dialog_cb (&self) {
            if self.start_screen_active() {
                return;
            }

            match self.obj().visible_dialog() {
                Some(dialog) => {
                    self.visible_dialogue_type.set(Some(*&dialog.type_()));
                    self.backend().game_stop_clock();
                }
                None => {
                    self.backend().game_start_clock();

                    if let Some(visible_dialogue_type) = self.visible_dialogue_type.take()
                        && visible_dialogue_type != adw::AlertDialog::static_type() {
                            self.game_view.grab_focus();
                    }
                }
            }
        }
    }

    impl WidgetImpl for SudokuWindow {}
    impl WindowImpl for SudokuWindow {}
    impl ApplicationWindowImpl for SudokuWindow {}
    impl AdwApplicationWindowImpl for SudokuWindow {}
}

glib::wrapper! {
    pub struct SudokuWindow(ObjectSubclass<imp::SudokuWindow>)
        @extends gtk::Widget, gtk::Window, gtk::ApplicationWindow, adw::ApplicationWindow,
        @implements gtk::Native, gio::ActionGroup, gio::ActionMap, gtk::Accessible,
                    gtk::Buildable, gtk::ConstraintTarget, gtk::Root, gtk::ShortcutManager;
}

impl SudokuWindow {
    pub fn new<A: IsA<gtk::Application>>(app: &A, backend: &SudokuBackend) -> Self {
        let window: Self = glib::Object::builder()
            .property("application", app.clone().upcast())
            .build();

        window.imp().init(backend);
        window
    }
}
