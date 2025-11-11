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
    public SudokuGame game { get; private set; default = null; }
    public SudokuGame tgame { get; private set; default = null; }
    public SudokuSaver saver;
    public double? highscore;

    private uint autosave_timeout;

    public SudokuBackend ()
    {
        saver = new SudokuSaver ();
        load_game ();
    }

    public void save_game ()
    {
        if (game != null && !game.is_empty ())
            saver.save_game (game);
        else
            saver.delete_save ();
    }

    private void load_game ()
    {
        var savedgame = saver.get_savedgame ();
        if (savedgame != null)
        {
            game = saver.get_savedgame ();
            highscore = saver.get_highscore (game.board.difficulty_category);
            start_autosave (this);
            game_changed ();
        }
    }

    public signal void game_changed ();
    public void change_game (SudokuGame new_game)
    {
        this.game = new_game;
        tgame = null;
        game_changed ();
    }

    public bool import_path (string path)
    {
        SudokuGame ngame;
        ngame = saver.parse_json_to_game (path);

        if (ngame != null)
        {
            change_game (ngame);
            return true;
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

    public void start_shared_game ()
    {
        if (tgame != null)
            change_game (tgame);
    }

    public delegate void BackendCallback (GLib.Object? source_object);

    public void generate_game (DifficultyCategory difficulty)
    {
        SudokuGenerator.generate_boards_async.begin (1, difficulty, null, (obj, res) => {
            try
            {
                var gen_boards = SudokuGenerator.generate_boards_async.end (res);
                game = new SudokuGame (gen_boards[0]);

                highscore = saver.get_highscore (difficulty);
                start_autosave (this);
                game_changed ();
            }
            catch (Error e)
            {
                error ("Error: %s", e.message);
            }
        });
    }

    public bool save_highscore ()
    {
        if (highscore == null || (highscore != null && game.get_total_time_played () < highscore))
        {
            saver.save_highscore (game.board.difficulty_category, game.get_total_time_played ());
            return true;
        }

        return false;
    }

    public void save_game_as (string path)
    {
        saver.save_game_as (game, path);
    }

    public void export_puzzle (string path)
    {
        saver.export_to_string (game.board, path);
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

    public void add_game_to_finished (bool save_timer)
    {
        stop_autosave ();
        saver.archive_game (SudokuSaver.finished_dir, game, save_timer);
        saver.delete_save ();
    }

    public void add_board_to_printed (SudokuBoard board)
    {
        saver.archive_game (SudokuSaver.printed_dir, new SudokuGame(board), false);
    }

    public void add_game_to_printed ()
    {
        saver.archive_game (SudokuSaver.printed_dir, game, false);
    }

    public override void dispose ()
    {
        stop_autosave ();
        save_game ();
        base.dispose ();
    }
}
