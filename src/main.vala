/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2012 Robert Ancell <robert.ancell@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

private static bool show_version;

private static const OptionEntry[] options =
{
    { "version", 'v', 0, OptionArg.NONE, ref show_version,
    /* Help string for command line --version flag */
    N_("Show release version"), null},
    { null }
};

public static int main (string[] args)
{
    //SudokuGenerator.gen_stats ();
    //SudokuRater.gen_python_test ();

    //SudokuGenerator gen = new SudokuGenerator ();
    //SudokuBoard board = gen.make_symmetric_puzzle(GLib.Random.int_range(0, 4));
    //board.get_string ();
    //stdout.printf("\n");

    //SudokuBoard test_board = board.clone ();
    //SudokuSolver test_solver = new SudokuSolver (ref test_board);

    /*if (test_solver.quick_has_unique_solution ())
        stdout.printf("Unique solution\n");
    else
        stdout.printf("No unique solution\n");


    SudokuSolver solver = new SudokuSolver (ref board);
    foreach (SudokuBoard solved_board in solver)
    {
        solved_board.get_string ();
        stdout.printf("\n");
    }*/

    //return 0;

    Gtk.init (ref args);

    var c = new OptionContext (/* Arguments and description for --help text */
                                   _("[FILE] - Play Sudoku"));
    c.add_main_entries (options, GETTEXT_PACKAGE);
    c.add_group (Gtk.get_option_group (true));
    try
    {
        c.parse (ref args);
    }
    catch (Error e)
    {
        stderr.printf ("%s\n", e.message);
        stderr.printf (/* Text printed out when an unknown command-line argument provided */
                       _("Run '%s --help' to see a full list of available command line options."), args[0]);
        stderr.printf ("\n");
        return Posix.EXIT_FAILURE;
    }
    if (show_version)
    {
        /* Note, not translated so can be easily parsed */
        stderr.printf ("gnome-sudoku %s\n", VERSION);
        return Posix.EXIT_SUCCESS;
    }

    var app = new Sudoku ();

    return app.run ();
}
