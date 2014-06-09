/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

using Gee;

public class SudokuSaver
{
    public static string savegame_file { get; private set; default = ""; }
    public static string finishgame_dir { get; private set; default = ""; }

    public SudokuSaver() {
        try {

            var config_dir = Environment.get_user_data_dir ();
            var sudoku_data_dir = Path.build_path (Path.DIR_SEPARATOR_S, config_dir, "gnome-sudoku");
            savegame_file = Path.build_path (Path.DIR_SEPARATOR_S, sudoku_data_dir, "savefile");
            finishgame_dir = Path.build_path (Path.DIR_SEPARATOR_S, sudoku_data_dir, "finished");

            {
                var file = File.new_for_path (sudoku_data_dir);
                if (!file.query_exists ())
                    file.make_directory ();

                file = File.new_for_path (finishgame_dir);
                if (!file.query_exists ())
                    file.make_directory ();
            }
        }  catch (Error e) {
            warning ("%s", e.message);
        }
    }

    public SudokuGame? get_savedgame ()
    {
        var file = File.new_for_path (savegame_file);
        if (!file.query_exists ())
            return null;

        return parse_json_to_game (savegame_file);
    }

    public void save_game (SudokuGame game)
    {
        create_file_for_game (game, savegame_file);
    }

    public void add_game_to_finished (SudokuGame game, bool delete_savegame = false)
    {
        var file_name = game.board.to_string (true) + ".save";
        var file_path = Path.build_path (Path.DIR_SEPARATOR_S, finishgame_dir, file_name);
        create_file_for_game (game, file_path);

        if (delete_savegame)
        {
            // Delete savegame file
            var file = File.new_for_path (savegame_file);
            if (file.query_exists ())
            {
                try
                {
                    file.delete ();
                }
                catch (GLib.Error e)
                {
                    warning ("Failed to delete %s: %s", file.get_uri (), e.message);
                }
            }
        }
    }

    private void create_file_for_game (SudokuGame game, string file_name)
    {
        var json_str = serialize_game_to_json (game);

        try {
            FileUtils.set_contents (file_name, json_str);
        } catch (Error e) {
            warning ("%s", e.message);
        }
    }

    private string serialize_game_to_json (SudokuGame game)
    {
        var board = game.board;
        var board_cells = board.get_cells ();
        Json.Builder builder = new Json.Builder ();

        builder.begin_object ();
        builder.set_member_name ("difficulty_rating");
        builder.add_double_value (board.difficulty_rating);
        builder.set_member_name ("difficulty_category");
        builder.add_string_value (board.get_difficulty_category ().to_string ());
        builder.set_member_name ("time_elapsed");
        builder.add_double_value (game.get_total_time_played ());

        builder.set_member_name ("cells");
        builder.begin_array ();

        for (var i = 0; i < board.rows; i++)
        {
            for (var j = 0; j < board.cols; j++)
            {
                int[] earmarks = {};
                for (var k = 0; k < board.max_val; k++)
                    if (board.earmarks[i, j, k])
                        earmarks += k;

                if (board_cells[i, j] == 0 && earmarks.length == 0)
                    continue;

                builder.begin_object ();

                builder.set_member_name ("position");
                builder.begin_array ();
                builder.add_int_value (i);
                builder.add_int_value (j);
                builder.end_array ();
                builder.set_member_name ("value");
                builder.add_int_value (board_cells[i, j]);
                builder.set_member_name ("fixed");
                builder.add_boolean_value (board.is_fixed[i, j]);
                builder.set_member_name ("earmarks");
                builder.begin_array ();

                foreach (int k in earmarks)
                    builder.add_int_value (k);

                builder.end_array ();

                builder.end_object ();
            }
        }

        builder.end_array ();
        builder.end_object ();

        Json.Generator generator = new Json.Generator ();
        generator.set_pretty (true);
        Json.Node root = builder.get_root ();
        generator.set_root (root);

        return generator.to_data (null);
    }

    private SudokuGame? parse_json_to_game (string file_path)
    {
        Json.Parser parser = new Json.Parser ();
        try {
            parser.load_from_file (file_path);
        } catch (Error e) {
            return null;
        }

        var board = new SudokuBoard ();
        Json.Node node = parser.get_root ();
        Json.Reader reader = new Json.Reader (node);
        reader.read_member ("cells");
        return_val_if_fail (reader.is_array (), null);

        for (var i = 0; i < reader.count_elements (); i++)
        {
            reader.read_element (i);	// Reading a cell

            reader.read_member ("position");
            return_val_if_fail (reader.is_array (), null);
            return_val_if_fail (reader.count_elements () == 2, null);
            reader.read_element (0);
            return_val_if_fail (reader.is_value (), null);
            var row = (int) reader.get_int_value ();
            reader.end_element ();

            reader.read_element (1);
            return_val_if_fail (reader.is_value (), null);
            var col = (int) reader.get_int_value ();
            reader.end_element ();
            reader.end_member ();

            reader.read_member ("value");
            return_val_if_fail (reader.is_value (), null);
            var val = (int) reader.get_int_value ();
            reader.end_member ();

            reader.read_member ("fixed");
            return_val_if_fail (reader.is_value (), null);
            var is_fixed = reader.get_boolean_value ();
            reader.end_member ();

            if (val != 0)
                board.insert (row, col, val, is_fixed);

            reader.read_member ("earmarks");
            return_val_if_fail (reader.is_array (), null);
            for (var k = 0; k < reader.count_elements (); k++)
            {
                reader.read_element (k);
                return_val_if_fail (reader.is_value (), null);
                board.earmarks[row, col, (int) reader.get_int_value ()] = true;
                reader.end_element ();
            }
            reader.end_member ();

            reader.end_element ();
        }
        reader.end_member ();

        reader.read_member ("time_elapsed");
        return_val_if_fail (reader.is_value (), null);
        board.previous_played_time = reader.get_double_value ();
        reader.end_member ();

        return new SudokuGame (board);
    }
}
