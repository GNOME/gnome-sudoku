/* -*- Mode: C; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright © 2014 Parin Porecha
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

#ifndef QQWING_WRAPPER_H
#define QQWING_WRAPPER_H

#include <glib.h>

G_BEGIN_DECLS

int *qqwing_generate_puzzle(int difficulty);
void qqwing_print_stats(int *puzzle);
char *qqwing_get_version(void);

G_END_DECLS

#endif
