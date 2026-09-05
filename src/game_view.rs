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
use gtk::gdk::{BUTTON_PRIMARY, BUTTON_SECONDARY};
use gtk::glib::subclass::InitializingObject;
use gtk::CompositeTemplate;
use gtk::{DialogError, EventSequenceState, FileDialog, GestureClick, gio::{self, Cancellable, SimpleAction, SimpleActionGroup}, glib::closure_local, pango::{AttrList, AttrSize}};

use crate::grid_layout::SudokuGridLayout;
use crate::menu_button::SudokuMenuButton;
use crate::grid::SudokuGrid;
use crate::lib::utils::new_shortcut;
use crate::lib::backend::SudokuBackend;
use crate::lib::enums::DifficultyCategory;
use crate::lib::game::{SudokuGame, StackAction};
use crate::{connect_cb_pref, create_cb_entry};

use std::cell::OnceCell;

mod imp {
    use std::cell::Cell;

use super::*;

    #[glib::object_subclass]
    impl ObjectSubclass for SudokuGameView {
        const NAME: &'static str = "SudokuGameView";
        type Type = super::SudokuGameView;
        type ParentType = adw::BreakpointBin;

        fn class_init(klass: &mut Self::Class) {
            klass.bind_template();
            new_shortcut (klass, "game-view.earmark-mode", "e");
            new_shortcut (klass, "game-view.toggle-pause", "p");
            new_shortcut (klass, "game-view.reset-board", "<Primary>r");
            new_shortcut (klass, "game-view.undo", "u|<Primary>z");
            new_shortcut (klass, "game-view.redo", "r|<Primary><Shift>z");
            new_shortcut (klass, "game-view.save-game-as", "<Primary>s");
            new_shortcut (klass, "game-view.share-puzzle", "<Primary>c");
            new_shortcut (klass, "game-view.export-puzzle", "<Primary>e");
        }

        fn instance_init(obj: &InitializingObject<Self>) {
            obj.init_template();
        }
    }

    #[derive(CompositeTemplate)]
    #[template(resource = "/org/gnome/Sudoku/ui/game-view.ui")]
    pub struct SudokuGameView {
        undo_action: SimpleAction,
        redo_action: SimpleAction,
        reset_board_action: SimpleAction,
        toggle_pause_action: SimpleAction,

        is_vertical: Cell<bool>,
        width_is_small: Cell<bool>,

        pub grid: SudokuGrid,
        pub backend: OnceCell<SudokuBackend>,

        #[template_child]
        pub top_headerbar: TemplateChild<adw::HeaderBar>,
        #[template_child]
        grid_overlay: TemplateChild<gtk::Overlay>,
        #[template_child]
        toast_overlay: TemplateChild<adw::ToastOverlay>,
        #[template_child]
        grid_bin: TemplateChild<adw::Bin>,
        #[template_child]
        ui_breakpoint: TemplateChild<adw::Breakpoint>,
        #[template_child]
        windowtitle: TemplateChild<adw::WindowTitle>,
        #[template_child]
        bottom_headerbar: TemplateChild<adw::HeaderBar>,
        #[template_child]
        menu_button: TemplateChild<SudokuMenuButton>,
        #[template_child]
        undo_button: TemplateChild<gtk::Button>,
        #[template_child]
        redo_button: TemplateChild<gtk::Button>,
        #[template_child]
        earmark_mode_button: TemplateChild<gtk::ToggleButton>,
        #[template_child]
        play_pause_stack: TemplateChild<gtk::Stack>,
        #[template_child]
        pause_button: TemplateChild<gtk::Button>,
        #[template_child]
        play_button: TemplateChild<gtk::Button>,
        #[template_child]
        clock_box: TemplateChild<gtk::Box>,
        #[template_child]
        clock_label: TemplateChild<gtk::Label>,
        #[template_child]
        pub clock_stack: TemplateChild<gtk::Stack>,
        #[template_child]
        pub clock_medal: TemplateChild<gtk::Label>,
        #[template_child]
        clock_image: TemplateChild<gtk::Image>,
        #[template_child]
        paused_label: TemplateChild<gtk::Label>,
    }

    impl Default for SudokuGameView {
        fn default() -> Self {
            Self {
                is_vertical: Default::default(),
                width_is_small: Default::default(),
                undo_action: SimpleAction::new("undo", None),
                redo_action: SimpleAction::new("redo", None),
                reset_board_action: SimpleAction::new("reset-board", None),
                toggle_pause_action: SimpleAction::new("toggle-pause", None),
                grid: SudokuGrid::new_unitialized(),
                backend: Default::default(),
                top_headerbar: Default::default(),
                grid_overlay: Default::default(),
                toast_overlay: Default::default(),
                grid_bin: Default::default(),
                ui_breakpoint: Default::default(),
                windowtitle: Default::default(),
                bottom_headerbar: Default::default(),
                menu_button: Default::default(),
                undo_button: Default::default(),
                redo_button: Default::default(),
                earmark_mode_button: Default::default(),
                play_pause_stack: Default::default(),
                pause_button: Default::default(),
                play_button: Default::default(),
                clock_box: Default::default(),
                clock_label: Default::default(),
                clock_stack: Default::default(),
                clock_medal: Default::default(),
                clock_image: Default::default(),
                paused_label: Default::default()
            }
        }
    }

    impl SudokuGameView {
        pub fn init (&self, backend: &SudokuBackend) {
            let window : gtk::Window = self.obj().root().and_downcast::<gtk::Window>().unwrap();
            self.backend.set(backend.clone()).expect("Game View is already initialized");
            self.obj().set_size_request (window.width_request(), window.height_request());
            connect_cb_pref!(self, connect_pref_timer_notify, show_timer_cb);

            let backwards_controller = GestureClick::new();
            backwards_controller.set_button(8);
            backwards_controller.set_propagation_limit(gtk::PropagationLimit::None);
            backwards_controller.connect_pressed(glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |gesture: &GestureClick, _, _, _| {
                    game_view.obj().activate_action("game-view.undo", None).unwrap();
                    gesture.set_state(EventSequenceState::Claimed);
                }
            ));

            self.obj().add_controller(backwards_controller);

            let forwards_controller = GestureClick::new();
            forwards_controller.set_button(9);
            forwards_controller.set_propagation_limit(gtk::PropagationLimit::None);
            forwards_controller.connect_pressed(glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |gesture: &GestureClick, _, _, _| {
                    game_view.obj().activate_action("game-view.redo", None).unwrap();
                    gesture.set_state(EventSequenceState::Claimed);
                }
            ));
            self.obj().add_controller(forwards_controller);

            let button_controller = GestureClick::new();
            button_controller.set_button(0);
            button_controller.connect_released(glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |gesture: &GestureClick, _, _, _| {
                    let current_button = gesture.current_button();
                    if current_button != BUTTON_PRIMARY && current_button != BUTTON_SECONDARY {
                        return;
                    }

                    if !game_view.backend().game_paused(){
                        game_view.grid.unselect();
                    }
                    gesture.set_state(gtk::EventSequenceState::Claimed);
                }
            ));
            self.obj().add_controller(button_controller);

            self.initialize_clock_label();
            self.initialize_buttons();

            self.windowtitle.set_subtitle(&self.backend().game_difficulty().to_translated_string());

            backend.connect_closure("game-changed", false, glib::closure_local!(
                #[weak(rename_to = game_view)] self,
                move |backend: SudokuBackend| {
                    game_view.add_game_hooks();
                    game_view.initialize_buttons();
                    game_view.initialize_clock_label();
                    game_view.windowtitle.set_subtitle(&backend.game_difficulty().to_translated_string());
                }
            ));

            self.ui_breakpoint.connect_apply(glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |_| {
                    game_view.set_vertical_ui();
                }
            ));

            self.ui_breakpoint.connect_unapply(glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |_| {
                    game_view.set_wide_ui();
                }
            ));

            self.add_game_hooks ();

            let grid_layout = SudokuGridLayout::new(&self.grid, backend);
            self.grid_bin.set_layout_manager(Some(grid_layout));

            self.grid.init(backend);
        }

        pub fn initialize_clock_label (&self){
            if !self.backend().pref_timer() {
                return;
            }

            self.clock_stack.set_visible_child(&*self.clock_image);
            let elapsed_time = self.backend().game_time_played() as i64;
            let backend = self.backend();
            if let Some(highscore) = backend.game_highscore() {
                let highscore = highscore as i64;
                let highscore_string = "🥇".to_string()
                    + &self.create_timer_string (highscore);
                self.clock_box.set_tooltip_markup(Some(format!(
                    "<span font_features='tnum=1'>{}</span>",
                    highscore_string).as_str()));

                if elapsed_time > highscore {
                    self.clock_label.set_css_classes(&["numeric"]);
                }
                else if elapsed_time > highscore - 60 {
                    self.clock_label.set_css_classes(&["numeric", "warning"]);
                }
                else {
                    self.clock_label.set_css_classes(&["numeric", "success"]);
                }
            }
            else {
                self.clock_label.set_css_classes(&["numeric"]);
                self.clock_box.set_tooltip_text(None);
            }

            self.clock_label.set_label(self.create_timer_string(elapsed_time).as_str());
        }

        pub fn setup_actions (&self) {
            let action_group = SimpleActionGroup::new();
            let actions = [
                create_cb_entry!(self, "earmark-mode", earmark_mode_cb),
                create_cb_entry!(self, "share-puzzle", share_puzzle_cb),
                create_cb_entry!(self, "export-puzzle", export_puzzle_cb),
                create_cb_entry!(self, "save-game-as", save_game_as_cb),
            ];
            action_group.add_action_entries(actions);

            self.toggle_pause_action.connect_activate(glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |_, _| {
                    let backend = game_view.backend();
                    backend.game_toggle_pause();
                }
            ));
            action_group.add_action(&self.toggle_pause_action);

            self.reset_board_action.connect_activate(glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |_, _| {
                    game_view.backend().game_reset();
                }
            ));
            action_group.add_action(&self.reset_board_action);

            self.undo_action.connect_activate(glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |_, _| {
                    game_view.backend().game_undo();
                }
            ));
            action_group.add_action(&self.undo_action);

            self.redo_action.connect_activate(glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |_, _| {
                    game_view.backend().game_redo();
                }
            ));
            action_group.add_action(&self.redo_action);

            self.obj().insert_action_group("game-view", Some(&action_group));
        }

        pub fn backend (&self) -> &SudokuBackend {
            self.backend.get().unwrap()
        }

        fn set_wide_ui (&self) {
            self.unparent_buttons();
            self.is_vertical.set(false);
            self.update_buttons_visibility();
            self.top_headerbar.pack_start(&*self.undo_button);
            self.top_headerbar.pack_start(&*self.redo_button);
            self.top_headerbar.pack_start(&*self.earmark_mode_button);
            self.top_headerbar.pack_start(&*self.play_pause_stack);
            self.top_headerbar.pack_end(&*self.clock_box);
        }

        fn set_vertical_ui (&self) {
            self.unparent_buttons();
            self.is_vertical.set(true);
            self.update_buttons_visibility();
            self.bottom_headerbar.pack_start(&*self.undo_button);
            self.bottom_headerbar.pack_start(&*self.redo_button);
            self.bottom_headerbar.pack_end(&*self.earmark_mode_button);
            self.bottom_headerbar.pack_end(&*self.play_pause_stack);
            self.top_headerbar.pack_start(&*self.clock_box);
        }

        fn unparent_buttons (&self) {
            self.play_pause_stack.unparent();
            self.earmark_mode_button.unparent();
            self.undo_button.unparent();
            self.redo_button.unparent();
            self.clock_box.unparent();
        }

        fn update_buttons_visibility (&self) {
            let show_timer = self.backend().pref_timer();
            self.clock_box.set_visible(show_timer && (!self.width_is_small.get() || self.is_vertical.get()));
            self.redo_button.set_visible(!show_timer || !self.width_is_small.get() || self.is_vertical.get());
        }

        pub fn initialize_buttons (&self) {
            let backend = self.backend();
            self.clock_box.set_visible(backend.pref_timer());
            self.play_pause_stack.set_visible(backend.pref_timer());
            self.undo_action.set_enabled (backend.game_can_undo());
            self.redo_action.set_enabled (backend.game_can_redo());
            self.reset_board_action.set_enabled (!backend.game_is_empty());
        }

        fn earmark_mode_cb (&self) {
            let earmark_mode = self.backend().earmark_mode();
            self.backend().set_earmark_mode(!earmark_mode);
            self.earmark_mode_button.set_active(!earmark_mode);
        }

        fn share_puzzle_cb (&self) {
            let clipboard = self.obj().clipboard();
            clipboard.set_text(&self.backend().game_ascii());
            let toast = adw::Toast::new(&gettextrs::gettext("Puzzle copied to clipboard"));
            toast.set_timeout(3);
            self.toast_overlay.add_toast(toast);
        }

        fn save_game_as_cb (&self) {
            let file_dialog = FileDialog::new();
            let info = self.backend().game_save_as_info();
            file_dialog.set_initial_name(Some(&info.0));
            file_dialog.set_initial_folder(Some(&info.1));

            let window : gtk::Window = self.obj().root().and_downcast::<gtk::Window>().unwrap();
            file_dialog.save(Some(&window), None::<&Cancellable>, glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |result: Result<gio::File, glib::Error>| {
                    match result {
                        Ok(file) => {
                            let path = file.path().unwrap();
                            let path = path.to_str().unwrap();
                            game_view.backend().game_save_as(path);
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

        fn export_puzzle_cb (&self) {
            let file_dialog = FileDialog::new();
            file_dialog.set_initial_name(Some(&gettextrs::pgettext(
                ".skp is a file extension",
                "Sudoku puzzle.skp")
            ));
            let window : gtk::Window = self.obj().root().and_downcast::<gtk::Window>().unwrap();
            file_dialog.save(Some(&window), None::<&Cancellable>, glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |result: Result<gio::File, glib::Error>| {
                    match result {
                        Ok(file) => {
                            let path = file.path().unwrap();
                            let path = path.to_str().unwrap();
                            game_view.backend().export_puzzle(path);
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

        fn game_completed_cb (&self) {
            // game.board.completed.disconnect (board_completed_cb);
            self.backend().game_save_completed ();
            let highscore_changed = self.backend().game_save_highscore ();
            if highscore_changed {
                self.clock_stack.set_visible_child (&*self.clock_medal);
            }

            use gettextrs::gettext;
            let win_str = gettext("Puzzle Completed!");
            let dialog = adw::AlertDialog::new(Some(&win_str), None);
            dialog.add_response("quit", &gettext("_Quit"));
            let backend = self.backend();
            if backend.selected_difficulty() != DifficultyCategory::Custom {
                dialog.add_response("start-menu", &gettext("_Change Difficulty"));
                dialog.add_response("play-again", &gettext("_Play Again"));
                dialog.set_response_appearance("play-again", adw::ResponseAppearance::Suggested);
                dialog.set_default_response(Some("play-again"));
            }
            else {
                dialog.add_response("play-again", &gettext("_Play Again"));
                dialog.add_response("start-menu", &gettext("_New Game…"));
                dialog.set_default_response(Some("start-menu"));
            }

            dialog.connect_response(None, glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |dialog, response|
                {
                    match response {
                        "start-menu" | "close" => {
                            game_view.backend().game_delete();
                            game_view.obj().activate_action("app.new-game", None).unwrap();
                        },
                        "quit" => game_view.obj().activate_action("app.quit", None).unwrap(),
                        "play-again" => game_view.backend().new_game(),
                        _ => println!("dialog answer {}", response)

                    }
                    dialog.close();
                }
            ));

            let window : gtk::Window = self.obj().root().and_downcast::<gtk::Window>().unwrap();
            dialog.present (Some(&window));
        }

        pub fn add_game_hooks (&self) {
            let binding = self.backend().game();
            let game = binding.as_ref().unwrap();
            game.connect_closure("tick", false, closure_local!{
                #[weak(rename_to = game_view)] self,
                move |_ : glib::Object| {
                    game_view.tick_cb();
                }
            });

            game.connect_closure("paused", false, closure_local!{
                #[weak(rename_to = game_view)] self,
                move |_ : glib::Object, paused: bool| {
                    game_view.paused_cb(paused);
                }
            });

            game.connect_closure("completed", false, closure_local!{
                #[weak(rename_to = game_view)] self,
                move |_ : glib::Object| {
                    game_view.game_completed_cb();
                }
            });

            game.connect_closure("action-completed", false, closure_local!{
                #[weak(rename_to = game_view)] self,
                move |game : SudokuGame, _: StackAction| {
                    game_view.undo_action.set_enabled (!game.is_undostack_null ());
                    game_view.redo_action.set_enabled (!game.is_redostack_null ());
                    game_view.reset_board_action.set_enabled (!game.board().is_empty());
                }
            });
        }

        fn tick_cb (&self) {
            let elapsed_time = self.backend().game_time_played();
            self.clock_label.set_label(&self.create_timer_string(elapsed_time as i64));
        }

        fn create_timer_string (&self, elapsed_time: i64) -> String {
            let hours = elapsed_time / 3600;
            let minutes = (elapsed_time - hours * 3600) / 60;
            let seconds = elapsed_time - hours * 3600 - minutes * 60;
            if hours > 0 {
                format!("{}:{:02}:{:02}", hours, minutes, seconds)
            }
            else {
                format!("{:02}:{:02}", minutes, seconds)
            }
        }

        pub fn paused_cb (&self, paused: bool) {
            self.paused_label.set_visible(paused);
            if paused {
                self.update_paused_label_size(self.obj().width(), self.obj().height());
                self.play_pause_stack.set_visible_child(&*self.play_button);
                self.grid_overlay.add_overlay(&*self.paused_label);
                self.grid_overlay.add_css_class("paused");
                self.reset_board_action.set_enabled(false);
            }
            else {
                self.play_pause_stack.set_visible_child(&*self.pause_button);
                self.grid_overlay.remove_overlay(&*self.paused_label);
                self.grid_overlay.remove_css_class("paused");
                self.reset_board_action.set_enabled(self.backend().game_is_empty());
            }
        }

        pub fn update_paused_label_size (&self, width: i32, height: i32) {
            let smallest = i32::min(width, height);
            let attr_list = self.paused_label.attributes().unwrap_or(AttrList::new());
            let size = smallest as f64 * 0.125 * gtk::pango::SCALE as f64;
            attr_list.change(
                AttrSize::new_size_absolute(size as i32)
            );
            self.paused_label.set_attributes(Some(&attr_list));
        }

        pub fn show_timer_cb (&self) {
            let show_timer = self.backend().pref_timer();
            self.update_buttons_visibility();
            self.toggle_pause_action.set_enabled(show_timer);
            self.play_pause_stack.set_visible(show_timer);
            if show_timer {
                self.initialize_clock_label();
            }
        }
    }

    impl ObjectImpl for SudokuGameView {
        fn constructed(&self) {
            self.parent_constructed();
            self.grid_overlay.set_child(Some(&self.grid));
            self.setup_actions();

            self.menu_button.imp().main_menu.connect_closed(glib::clone!(
                #[weak(rename_to = game_view)] self,
                move |_|
                {
                    game_view.grab_focus();
                }
            ));
        }

        fn dispose(&self) {
            println!("game-view disposed");
        }
    }

    impl WidgetImpl for SudokuGameView {
        fn grab_focus(&self) -> bool {
            self.obj().grid().grab_focus()
        }
        fn size_allocate(&self, width: i32, height: i32, baseline: i32) {
            if width < 600 && !self.width_is_small.get() {
                self.width_is_small.set(true);
                self.update_buttons_visibility();
            }
            else if width >= 600 && self.width_is_small.get() {
                self.width_is_small.set(false);
                self.update_buttons_visibility();
            }
            if self.paused_label.is_visible() {
                self.update_paused_label_size(width, height);
            }
            self.parent_size_allocate(width, height, baseline);
        }
    }
    impl BinImpl for SudokuGameView {}
    impl BreakpointBinImpl for SudokuGameView {}
}

glib::wrapper! {
    pub struct SudokuGameView(ObjectSubclass<imp::SudokuGameView>)
        @extends gtk::Widget, adw::Bin, adw::BreakpointBin,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget;
}

impl SudokuGameView {
    //this is separated as the backend is required for functionality and its reference can't be initialized
    //during gobject construction
    pub fn init (&self, backend: &SudokuBackend) {
        self.imp().init(backend);
    }

    pub fn initialized (&self) -> bool {
        self.imp().backend.get().is_some()
    }

    pub fn grid (&self) -> &SudokuGrid {
        &self.imp().grid
    }
}
