/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2025 Johan GAY
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

using Gee;

public class Highscores : Object
{
    string highscores_file;
    public Highscores(string path)
    {
        highscores = new HashMap<DifficultyCategory, double?>();
        highscores_file = path;
        get_highscores ();
    }

    private HashMap<DifficultyCategory, double?> highscores;
    public double? get_highscore (DifficultyCategory difficulty)
    {
        return highscores.get (difficulty);
    }

    private void get_highscores ()
    {
        Json.Parser parser = new Json.Parser ();

        try
        {
            parser.load_from_file (highscores_file);
        }
        catch (Error e)
        {
            return;
        }

        Json.Node node = parser.get_root ();
        Json.Reader reader = new Json.Reader (node);

        read_difficulty (reader, DifficultyCategory.EASY);
        read_difficulty (reader, DifficultyCategory.MEDIUM);
        read_difficulty (reader, DifficultyCategory.HARD);
        read_difficulty (reader, DifficultyCategory.VERY_HARD);
    }

    private void read_difficulty (Json.Reader reader, DifficultyCategory diff)
    {
        reader.read_member (diff.to_untranslated_string ());
        if (reader.is_value ())
            highscores.set (diff, reader.get_double_value ());
        reader.end_member ();
    }

    public void save_highscore (DifficultyCategory difficulty, double time_elapsed)
    {
        highscores.set (difficulty, time_elapsed);
        save_highscores ();
    }

    private void save_highscores ()
    {
        Json.Builder builder = new Json.Builder ();

        builder.begin_object ();
        foreach (var highscore in highscores)
        {
            builder.set_member_name (highscore.key.to_untranslated_string ());
            builder.add_double_value (highscore.value);
        }
        builder.end_object ();

        Json.Generator generator = new Json.Generator ();
        generator.set_pretty (true);
        Json.Node root = builder.get_root ();
        generator.set_root (root);

        try
        {
            generator.to_file (highscores_file);
        }
        catch (Error e)
        {
            warning ("%s", e.message);
        }
    }
}
