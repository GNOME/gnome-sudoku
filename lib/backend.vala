/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2025 Johan Gay
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

public class SudokuBackend : Object
{
    public static string active_save_file { get; private set; default = ""; }
    public static string highscores_file { get; private set; default = ""; }
    public static string sudoku_data_dir { get; private set; default = ""; }
    public static string printed_dir { get; private set; default = ""; }
    public static string finished_dir { get; private set; default = ""; }
    public static string saved_dir { get; private set; default = ""; }

    public SudokuGame game { get; private set; default = null; }
    public SudokuGame tgame { get; private set; default = null; }

    private Highscores highscores;
    public double? get_highscore ()
    {
        if (game == null)
            return null;
        else
            return highscores.get_highscore (game.board.difficulty_category);
    }

    private uint autosave_timeout;

    static construct {
        var config_dir = Environment.get_user_data_dir ();
        sudoku_data_dir = Path.build_path (Path.DIR_SEPARATOR_S, config_dir, "gnome-sudoku");
        active_save_file = Path.build_path (Path.DIR_SEPARATOR_S, sudoku_data_dir, "savefile");
        highscores_file = Path.build_path (Path.DIR_SEPARATOR_S, sudoku_data_dir, "highscores");
        printed_dir = Path.build_path (Path.DIR_SEPARATOR_S, sudoku_data_dir, "printed");
        finished_dir = Path.build_path (Path.DIR_SEPARATOR_S, sudoku_data_dir, "finished");
        saved_dir = Path.build_path (Path.DIR_SEPARATOR_S, sudoku_data_dir, "saved");
    }

    public SudokuBackend ()
    {
        if (DirUtils.create_with_parents (sudoku_data_dir, 0755) == -1)
            warning ("Failed to create saver directory: %s", strerror (errno));

        highscores = new Highscores (highscores_file);
        load_game ();
    }

    public signal void game_changed ();
    public void change_game (SudokuGame new_game)
    {
        this.game = new_game;
        tgame = null;
        game_changed ();
    }

    public void start_shared_game ()
    {
        if (tgame != null)
            change_game (tgame);
    }

    public void save_game ()
    {
        if (game != null && !game.is_empty ())
            create_file_for_game (game, active_save_file, true);
        else
            delete_save ();
    }

    public void save_game_as (string path)
    {
        create_file_for_game (game, path, true);
    }

    public void delete_save ()
    {
        var file = File.new_for_path (active_save_file);
        try
        {
            file.delete ();
        }
        catch (GLib.Error e)
        {
            if (e.code != IOError.NOT_FOUND)
                warning ("Failed to delete %s: %s", file.get_uri (), e.message);
        }
    }

    private void load_game ()
    {
        try
        {
            var saved_board = new SudokuBoard.from_json (active_save_file);
            var saved_game = new SudokuGame (saved_board);
            game = saved_game;
            start_autosave (this);
            game_changed ();
        }
        catch (Error e)
        {
            return;
        }
    }

    public bool load_game_path (string path)
    {
        try
        {
            var ngame = new SudokuGame(new SudokuBoard.from_json(path));
            change_game (ngame);
            return true;
        }
        catch (Error e)
        {
            print (e.message);
        }

        try
        {
            var file = File.new_for_path (path);
            FileIOStream iostream = file.open_readwrite (null);
            var istream = iostream.input_stream;
            var bytes = istream.read_bytes (100).get_data ();
            var board = new SudokuBoard.from_string ((string) bytes);
            var new_game = new SudokuGame (board);

            change_game (new_game);
        }
        catch (Error e)
        {
            return false;
        }
        return true;
    }

    public bool save_highscore ()
    {
        var highscore = highscores.get_highscore (game.board.difficulty_category);
        if (highscore == null || (highscore != null && game.get_total_time_played () < highscore))
        {
            highscores.save_highscore (game.board.difficulty_category, game.get_total_time_played ());
            return true;
        }

        return false;
    }

    public bool check_clipboard (string clipboard)
    {
        try
        {
            SudokuBoard board;
            board = new SudokuBoard.from_short_string (clipboard);
            var game = new SudokuGame (board);
            tgame = game;
            return true;
        }
        catch (Error e)
        {
            print ("%s", e.message);
            return false;
        };
    }

    public delegate void BackendCallback (GLib.Object? source_object);

    public void generate_game (DifficultyCategory difficulty)
    {
        SudokuGenerator.generate_boards_async.begin (1, difficulty, null, (obj, res) => {
            try
            {
                var gen_boards = SudokuGenerator.generate_boards_async.end (res);
                game = new SudokuGame (gen_boards[0]);

                start_autosave (this);
                game_changed ();
            }
            catch (Error e)
            {
                error ("Error: %s", e.message);
            }
        });
    }

    public void export_puzzle (string path)
    {
        string content = game.board.to_string_pretty ();
        try
        {
            FileUtils.set_contents (path, content);
        }
        catch (Error e)
        {
            warning ("%s", e.message);
        }
    }

    public string get_short_puzzle ()
    {
        return game.board.fixed_to_short_string ();
    }

    //lambda capture workaround
    private static void start_autosave (SudokuBackend _this)
    {
        weak SudokuBackend weak_this = _this;
        weak_this.stop_autosave ();

        weak_this.autosave_timeout = Timeout.add_seconds (300, () =>
        {
            weak_this.save_game ();
            return Source.CONTINUE;
        });

        Source.set_name_by_id (weak_this.autosave_timeout, "[gnome-sudoku] autosave");
    }

    private void stop_autosave ()
    {
        if (autosave_timeout != 0)
        {
            Source.remove (autosave_timeout);
            autosave_timeout = 0;
        }
    }

    private void create_file_for_game (SudokuGame game, string file_name, bool save_timer)
    {
        double? elapsed_time;
        if (save_timer)
            elapsed_time = game.get_elapsed_time ();
        else
            elapsed_time = null;

        var json_str = game.board.to_json (elapsed_time);

        try
        {
            FileUtils.set_contents (file_name, json_str);
        }
        catch (Error e)
        {
            warning ("%s", e.message);
        }
    }

    public void archive_game (string dir_path, SudokuGame game, bool save_timer)
    {
        if (DirUtils.create (dir_path, 0755) == -1)
        {
            var e = IOError.from_errno (errno);
            if (e.code != IOError.EXISTS)
                warning ("Failed to create the folder to archive the game: %s", e.message);
        }

        var file_name = game.board.to_string ()+ ".save";
        var file_path = Path.build_path (Path.DIR_SEPARATOR_S, dir_path, file_name);
        create_file_for_game (game, file_path, save_timer);
    }

    public void add_board_to_printed (SudokuBoard board)
    {
        try
        {
            var ngame = new SudokuGame (board);
            archive_game (printed_dir, ngame, false);
        }
        catch (Error e)
        {
            print (e.message);
        }
    }

    public void add_game_to_printed ()
    {
        archive_game (printed_dir, game, false);
    }

    public void add_game_to_finished (bool save_timer)
    {
        stop_autosave ();
        archive_game (finished_dir, game, save_timer);
        delete_save ();
    }

    public override void dispose ()
    {
        stop_autosave ();
        save_game ();
        base.dispose ();
    }
}
