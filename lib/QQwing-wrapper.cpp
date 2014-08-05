/* -*- Mode: CPP; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2014 Parin Porecha
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

#include <iostream>

#include "qqwing.hpp"
#include "QQwing-wrapper.h"

using namespace qqwing;

/*
 * Generate a symmetric puzzle of specified difficulty.
 */
const int* qqwing_generate_puzzle(int difficulty)
{
    int i = 0;
    bool havePuzzle = false;
    const int *puzzle_array;
    const int MAX_ITERATION_COUNT = 200;
    SudokuBoard *board = new SudokuBoard();

    board->setRecordHistory(true);
    board->setLogHistory(false);
    board->setPrintStyle(SudokuBoard::ONE_LINE);

    for (i = 0; i < MAX_ITERATION_COUNT; i++)
    {
        havePuzzle = board->generatePuzzleSymmetry(SudokuBoard::RANDOM);
        board->solve();
        if (havePuzzle && (SudokuBoard::Difficulty) difficulty == board->getDifficulty())
            break;
    }

    if (i == MAX_ITERATION_COUNT)
        g_warning ("Could not generate puzzle of specified difficulty");

    puzzle_array = board->getPuzzle();
    return puzzle_array;
}

/*
 * Print the stats gathered while solving the puzzle given as input.
 */
void qqwing_print_stats(int *initPuzzle)
{
    SudokuBoard *board = new SudokuBoard();
    board->setRecordHistory(true);
    board->setLogHistory(false);
    board->setPuzzle(initPuzzle);
    board->solve();

    cout << "Number of Givens: " << board->getGivenCount()  << endl;
    cout << "Number of Singles: " << board->getSingleCount() << endl;
    cout << "Number of Hidden Singles: " << board->getHiddenSingleCount()  << endl;
    cout << "Number of Naked Pairs: " << board->getNakedPairCount()  << endl;
    cout << "Number of Hidden Pairs: " << board->getHiddenPairCount()  << endl;
    cout << "Number of Pointing Pairs/Triples: " << board->getPointingPairTripleCount()  << endl;
    cout << "Number of Box/Line Intersections: " << board->getBoxLineReductionCount()  << endl;
    cout << "Number of Guesses: " << board->getGuessCount()  << endl;
    cout << "Number of Backtracks: " << board->getBacktrackCount()  << endl;
    cout << "Difficulty: " << board->getDifficultyAsString()  << endl;
}
