/* -*- Mode: C++; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/*
 * Copyright © 2014 Parin Porecha
 * Copyright © 2014 Michael Catanzaro
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

#include "qqwing-wrapper.h"

#include <algorithm>
#include <cstdlib>
#include <iostream>
#include <mutex>

#include <glib.h>
#include <qqwing.hpp>

/*
 * Generate a symmetric puzzle of specified difficulty.
 * The result must be freed with g_free().
 */
int* qqwing_generate_puzzle(int difficulty)
{
    int i = 0;
    const int MAX_ITERATIONS = 1000;
    const int BOARD_SIZE = 81;
    qqwing::SudokuBoard board;
    static std::once_flag flag;

    std::call_once(flag, [] {
        srand(time(nullptr));
    });

    board.setRecordHistory(true);
    board.setLogHistory(false);
    board.setPrintStyle(qqwing::SudokuBoard::ONE_LINE);

    for (i = 0; i < MAX_ITERATIONS; i++)
    {
        bool havePuzzle = board.generatePuzzleSymmetry(qqwing::SudokuBoard::RANDOM);
        board.solve();
        if (havePuzzle && static_cast<qqwing::SudokuBoard::Difficulty>(difficulty) == board.getDifficulty())
            break;
    }

    if (i == MAX_ITERATIONS)
        g_error("Could not generate puzzle of specified difficulty. I tried so hard. Please report at https://gitlab.gnome.org/GNOME/gnome-sudoku/-/issues.");

    const int* original = board.getPuzzle();
    // Will be deleted by Vala using g_free(), so the new operator is not safe.
    int* copy = g_new(int, BOARD_SIZE);
    std::copy(original, &original[BOARD_SIZE], copy);
    return copy;
}

/*
 * Count the number of solutions of a puzzle
 * but return 2 if there are multiple.
 * Returns 0 if the puzzle is not valid.
 */
int qqwing_count_solutions_limited(int* puzzle)
{
    qqwing::SudokuBoard board;
    if (!board.setPuzzle(puzzle))
        return 0;

    return board.countSolutionsLimited();
}

/*
 * Print the stats gathered while solving the puzzle given as input.
 */
void qqwing_print_stats(int* puzzle)
{
    qqwing::SudokuBoard board;
    board.setRecordHistory(true);
    board.setLogHistory(false);
    board.setPuzzle(puzzle);
    board.solve();

    std::cout << "Number of Givens: " << board.getGivenCount() << std::endl;
    std::cout << "Number of Singles: " << board.getSingleCount() << std::endl;
    std::cout << "Number of Hidden Singles: " << board.getHiddenSingleCount() << std::endl;
    std::cout << "Number of Naked Pairs: " << board.getNakedPairCount() << std::endl;
    std::cout << "Number of Hidden Pairs: " << board.getHiddenPairCount() << std::endl;
    std::cout << "Number of Pointing Pairs/Triples: " << board.getPointingPairTripleCount() << std::endl;
    std::cout << "Number of Box/Line Intersections: " << board.getBoxLineReductionCount() << std::endl;
    std::cout << "Number of Guesses: " << board.getGuessCount() << std::endl;
    std::cout << "Number of Backtracks: " << board.getBacktrackCount() << std::endl;
    std::cout << "Difficulty: " << board.getDifficultyAsString() << std::endl;
}

/*
 * Returns the version of qqwing in use. Free with g_free().
 */
char* qqwing_get_version()
{
    return g_strdup(qqwing::getVersion().c_str());
}
