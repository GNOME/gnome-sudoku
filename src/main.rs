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
mod lib {
    pub mod backend;
    pub mod data;
    pub mod enums;
    pub mod game;
    pub mod board;
    #[macro_use]
    pub mod utils;
    pub mod board_generator;
}

mod config;
mod window;
mod preferences_dialog;
mod start_view;
mod game_view;
mod menu_button;
mod grid_layout;
mod grid;
mod cell;
mod printer;
mod picker_popover;
mod value_picker;
mod earmark_picker;
mod print_generator_dialog;

use adw::prelude::*;
use adw::subclass::prelude::*;

use gettextrs::{LocaleCategory, setlocale};
use gtk::gio;
use gtk::gio::ApplicationFlags;
use gtk::glib::{self, Char, OptionArg, OptionFlags};
use crate::lib::backend::SudokuBackend;

mod imp {

use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for GnomeSudoku {
        const NAME: &'static str = "GnomeSudoku";
        type Type = super::GnomeSudoku;
        type ParentType = adw::Application;
    }

    pub struct GnomeSudoku {
        pub backend: SudokuBackend
    }

    impl Default for GnomeSudoku {
        fn default() -> Self {
            Self { backend: SudokuBackend::new() }
        }
    }

    impl ApplicationImpl for GnomeSudoku {
        fn startup(&self) {
            self.parent_startup();
            self.setup_actions ();
        }

        fn activate(&self) {
            let app = self.obj();
            let window = window::SudokuWindow::new(app.as_ref(), &self.backend);
            window.present();
        }

        fn shutdown(&self) {
            for window in self.obj().windows() {
                window.close();
            }
            self.parent_shutdown();
        }

        fn handle_local_options(&self, options: &glib::VariantDict) -> std::ops::ControlFlow<glib::ExitCode> {
             if options.contains("version") {
                glib::g_print!( "gnome-sudoku {}\n", config::VERSION);
                return std::ops::ControlFlow::Break(glib::ExitCode::SUCCESS);
            }

            std::ops::ControlFlow::Continue(())
        }
    }

    impl GnomeSudoku {
        pub fn show_help(&self) {
            let context = self
                .obj()
                .active_window()
                .map(|w| gtk::prelude::WidgetExt::display(&w).app_launch_context());

            glib::spawn_future_local(async move {
                if let Err(e) =
                    gio::AppInfo::launch_default_for_uri_future("help:gnome-sudoku", context.as_ref())
                        .await
                {
                    eprint!("Failed to launch help: {}", e.message());
                }
            });
        }

        fn setup_actions (&self) {
            let actions = [
                create_cb_entry!(self, "help", show_help),
                create_cb_entry!(self.obj(), "quit", quit),
            ];

            self.obj().add_action_entries(actions);
            self.obj().set_accels_for_action("app.quit", &["<Primary>Q"]);
            self.obj().set_accels_for_action("app.preferences-dialog", &["<Primary>comma"]);
        }
    }

    impl ObjectImpl for GnomeSudoku {
        fn constructed(&self) {
            use config::*;
            setlocale(LocaleCategory::LcAll, "");
            gettextrs::bindtextdomain(GETTEXT_PACKAGE, LOCALEDIR)
                .expect("Unable to bind the text domain");
            gettextrs::bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8")
                .expect("Unable to bind the text domain codeset");
            gettextrs::textdomain(GETTEXT_PACKAGE).expect("Unable to switch to the text domain");

            let resources = gio::Resource::from_data(&glib::Bytes::from_static(GNOME_SUDOKU_RESOURCES))
                .expect("failed to load resources");

            gio::resources_register(&resources);

            self.parent_constructed();
        }

        fn dispose(&self) {
            println!("app disposed");
        }
    }
    impl GtkApplicationImpl for GnomeSudoku {}
    impl AdwApplicationImpl for GnomeSudoku {}
}

glib::wrapper! {
    pub struct GnomeSudoku(ObjectSubclass<imp::GnomeSudoku>)
    @extends adw::Application, gtk::Application, gio::Application,
    @implements gio::ActionGroup, gio::ActionMap;
}

impl GnomeSudoku {
    pub fn new () -> Self {
        let obj : GnomeSudoku = glib::Object::builder()
            .property("application-id", config::APP_ID)
            .property("flags", ApplicationFlags::FLAGS_NONE)
            .property("resource-base-path", "/org/gnome/Sudoku")
            .build();

        obj.add_main_option("version",
            Char('v' as i8),
            OptionFlags::NONE,
            OptionArg::None,
            /* Help string for command line --version flag */
            &gettextrs::gettext("Show release version"),
            None);

        return obj;
    }
}

fn main() {
    let app = GnomeSudoku::new();
    app.run();
}
