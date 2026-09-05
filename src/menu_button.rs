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

mod imp {
    use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuMenuButton {
        const NAME: &'static str = "SudokuMenuButton";
        type Type = super::SudokuMenuButton;
        type ParentType = adw::Bin;

        fn class_init(klass: &mut Self::Class) {

            gtk::CheckButton::ensure_type();
            klass.bind_template();
            klass.add_shortcut(
                &gtk::Shortcut::builder()
                .action(&gtk::NamedAction::new("window.back"))
                .trigger(&gtk::ShortcutTrigger::parse_string("<Alt>Left|<Alt>KP_Left").unwrap())
                .build(),
            );
        }

        fn instance_init(obj: &InitializingObject<Self>) {
            obj.init_template();
        }
    }

    #[derive(Default, CompositeTemplate)]
    #[template(resource = "/org/gnome/Sudoku/ui/menu-button.ui")]
    pub struct SudokuMenuButton {
        #[template_child]
        pub menu_fullscreen_stack: TemplateChild<gtk::Stack>,
        #[template_child]
        pub menu_fullscreen_button: TemplateChild<gtk::Button>,
        #[template_child]
        pub menu_unfullscreen_button: TemplateChild<gtk::Button>,
        #[template_child]
        pub main_menu: TemplateChild<gtk::Popover>,
    }

    impl SudokuMenuButton {
        fn set_fullscreen_button (&self, fullscreen: bool) {
            if !fullscreen {
                self.menu_fullscreen_stack.set_visible_child(&*self.menu_fullscreen_button);
            }
            else {
                self.menu_fullscreen_stack.set_visible_child(&*self.menu_unfullscreen_button);
            }
        }
    }

    impl ObjectImpl for SudokuMenuButton {
        fn constructed(&self) {
            self.parent_constructed();
        }
    }

    impl WidgetImpl for SudokuMenuButton {
        fn realize(&self) {
            self.parent_realize();
            let window : gtk::Window = self.obj().root().and_downcast::<gtk::Window>().unwrap();
            self.set_fullscreen_button (window.is_fullscreen());
            window.connect_fullscreened_notify(glib::clone!(
                #[weak(rename_to = menu_button)] self,
                move |window| menu_button.set_fullscreen_button(window.is_fullscreen())
            ));
        }
    }
    impl BinImpl for SudokuMenuButton {}
}

glib::wrapper! {
    pub struct SudokuMenuButton(ObjectSubclass<imp::SudokuMenuButton>)
        @extends gtk::Widget, adw::Bin,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget;
}

impl SudokuMenuButton {
    pub fn new () -> Self {
        return glib::Object::builder().build();
    }

}
