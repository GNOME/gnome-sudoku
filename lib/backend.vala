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
    public SudokuGame game;
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
            start_autosave ();
        }
    }

    public delegate void BackendCallback (GLib.Object? source_object);

    public void generate_game (DifficultyCategory difficulty, BackendCallback callback)
    {
        SudokuGenerator.generate_boards_async.begin (1, difficulty, null, (obj, res) => {
            try
            {
                var gen_boards = SudokuGenerator.generate_boards_async.end (res);
                if (game != null)
                    game.change_board (gen_boards[0]);
                else
                    game = new SudokuGame (gen_boards[0]);

                highscore = saver.get_highscore (difficulty);
                start_autosave ();
                callback (obj);
            }
            catch (Error e)
            {
                error ("Error: %s", e.message);
            }
        });
    }

    public void save_highscore ()
    {
        saver.save_highscore (game.board.difficulty_category, game.get_total_time_played ());
    }

    private void start_autosave ()
    {
        if (autosave_timeout != 0)
            Source.remove (autosave_timeout);

        autosave_timeout = Timeout.add_seconds (300, () => {
            save_game ();
            return Source.CONTINUE;
        });

        Source.set_name_by_id (autosave_timeout, "[gnome-sudoku] autosave");
    }

    //FIXME dispose doesn't get called
    public override void dispose ()
    {
        if (autosave_timeout != 0)
            Source.remove (autosave_timeout);

        save_game ();
        base.dispose ();
    }
}
