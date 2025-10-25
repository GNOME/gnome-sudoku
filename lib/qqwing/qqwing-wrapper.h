/* -*- Mode: C; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
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

#ifndef QQWING_WRAPPER_H
#define QQWING_WRAPPER_H

#include <glib.h>

G_BEGIN_DECLS

int *qqwing_generate_puzzle(int difficulty);
gboolean qqwing_solve_puzzle(int *puzzle, int *difficulty);
int qqwing_count_solutions_limited(int *puzzle);
void qqwing_print_stats(int *puzzle);
char *qqwing_get_version(void);

G_END_DECLS

#endif
