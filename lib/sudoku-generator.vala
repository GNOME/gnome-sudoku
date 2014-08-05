/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */

public void generate_puzzle()
{
    stdout.printf ("Testing qqwing, generating 4 puzzles of different difficulties ...\n\n");

    int number_to_generate = 4;

    // 1 corresponds to SIMPLE difficulty
    // 2 corresponds to EASY difficulty
    // 3 corresponds to INTERMEDIATE difficulty
    // 4 corresponds to EXPERT difficulty
    int difficulty = 1;

    for (var i = 0; i < number_to_generate; i++)
    {
        int[] puzzle = QQwing.generate_puzzle (difficulty++);

        stdout.printf ("\n");
        for (var j = 0; j < 81; j++)
            stdout.printf ("%d", puzzle[j]);
        stdout.printf ("\n");

        QQwing.print_stats (puzzle);
    }
}
