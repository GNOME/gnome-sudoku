# -*- coding: utf-8 -*-
import gtk, cairo

SUDOKU_SIZE = 9
N_BOXES = 3

PENCIL_GREY = (0.3, 0.3, 0.3)
BACKGROUND_COLOR = (1., 1., 1.)

def draw_sudoku (cr, sudoku, played, size, offset_x = 0, offset_y = 0, border_color = (1.0, 1.0, 1.0), line_color = (0.0, 0.0, 0.0), for_printing = False):

    if for_printing:
        THIN = size / 300.
    else:
        THIN = 1

    THICK = THIN * 2.
    BORDER = THICK

    WHITE_SPACE = (size
                   - 2 * BORDER
                   - 2 * THICK
                   - (N_BOXES - 1) * THICK
                   - (N_BOXES * 2) * THIN
                  )

    SQUARE_SIZE = WHITE_SPACE / SUDOKU_SIZE

    if for_printing:
        FONT_SIZE = SQUARE_SIZE / 2
        FONT_WEIGHT = cairo.FONT_WEIGHT_NORMAL
    else:
        FONT_SIZE = SQUARE_SIZE
        FONT_WEIGHT = cairo.FONT_WEIGHT_BOLD

    outer = {}
    outer["left"]   = offset_x
    outer["right"]  = offset_x + size
    outer["top"]    = offset_y
    outer["bottom"] = offset_y + size

    # Entire background
    cr.set_source_rgb(1., 1., 1.)
    cr.rectangle(outer["left"],
                 outer["top"],
                 size,
                 size)
    cr.fill()

    # Outer border
    cr.set_line_join(cairo.LINE_JOIN_ROUND)
    cr.set_line_width(BORDER)
    cr.rectangle(outer["left"]   + BORDER/2.0,
                 outer["top"]    + BORDER/2.0,
                 size            - BORDER,
                 size            - BORDER)

    # Inner background
    cr.set_source_rgb(*BACKGROUND_COLOR)
    cr.fill_preserve()
    #Border box
    cr.set_source_rgb(*border_color)
    cr.stroke()

    #Outer thick lines
    cr.set_line_join(cairo.LINE_JOIN_MITER)
    cr.set_line_width(THICK)
    cr.rectangle(outer["left"]   + BORDER +   THICK/2.0,
                 outer["top"]    + BORDER +   THICK/2.0,
                 size            - BORDER * 2 - THICK,
                 size            - BORDER * 2 - THICK)

    cr.set_source_rgb(*line_color)
    cr.stroke()

    inner = {}
    inner["left"]   = outer["left"]   + BORDER + THICK
    inner["right"]  = outer["right"]  - BORDER - THICK
    inner["top"]    = outer["top"]    + BORDER + THICK
    inner["bottom"] = outer["bottom"] - BORDER - THICK

    pos = {}
    position = BORDER + THICK
    pos[0] = position + SQUARE_SIZE/2.
    last_line = 0
    for n in range(1, SUDOKU_SIZE):
        if n % N_BOXES == 0:
            cr.set_line_width(THICK)
            position += SQUARE_SIZE + last_line/2.0 + THICK/2.0
            last_line = THICK
        else:
            cr.set_line_width(THIN)
            position += SQUARE_SIZE + last_line/2.0 + THIN/2.0
            last_line = THIN
        pos[n] = position + last_line/2. + SQUARE_SIZE/2.0
        cr.move_to(BORDER + THICK/2. + offset_x, position + offset_y)
        cr.line_to(size - BORDER - THICK/2. + offset_x, position + offset_y)
        cr.move_to(position + offset_x, BORDER + THICK/2. + offset_y)
        cr.line_to(position + offset_x, size - BORDER - THICK/2. + offset_y)
        cr.stroke()
    cr.set_font_size(FONT_SIZE)
    for x in range(SUDOKU_SIZE):
        for y in range(SUDOKU_SIZE):
            cr.move_to(pos[x] + offset_x, pos[y] + offset_y)
            letter = None
            if sudoku and sudoku[y][x]:
                letter = str(sudoku[y][x])
                cr.select_font_face("",
                         cairo.FONT_SLANT_NORMAL,
                         FONT_WEIGHT)
                cr.set_source_rgb(0, 0, 0)
                xbearing, ybearing, width, height, xadvance, yadvance = (
                    cr.text_extents(letter)
                    )

            elif played and played[y][x]:
                cr.select_font_face("Times",
                                    cairo.FONT_SLANT_ITALIC,
                                    cairo.FONT_WEIGHT_NORMAL)
                cr.set_source_rgb(*PENCIL_GREY)
                letter = str(played[y][x])
                xbearing, ybearing, width, height, xadvance, yadvance = (
                    cr.text_extents(letter)
                    )
            if letter:
                cr.move_to(pos[x] + offset_x - (xadvance/2.0),
                           pos[y] + offset_y + (height/2.0))
                cr.show_text(letter)

def make_pixbuf (sudoku, played, border_color, line_color = (0.4, 0.4, 0.4)):
    size = 126
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, size, size)
    cr = cairo.Context(surface)
    draw_sudoku(cr, sudoku, played,  size, 0, 0, border_color, line_color)
    pixbuf = gtk.gdk.pixbuf_new_from_data(surface.get_data(), gtk.gdk.COLORSPACE_RGB,
                                          True, 8, surface.get_width(), surface.get_height(), surface.get_stride())
    del surface
    return pixbuf

if __name__ == "__main__":
    sudoku = [[0, 0, 2, 3, 4, 5, 6, 0, 0]] * SUDOKU_SIZE
    played = [[1, 2, 0, 0, 0, 0, 0, 0, 0, 0]] + [[0, 0, 0, 0, 0, 0, 0, 0, 0, 0]] * 8


    size = 250
    line_color = (0.0, 0.0, 0.0)
    border_color = (1.0, 0.0, 0.0)
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, 750, 750)
    cr = cairo.Context(surface)
    draw_sudoku(cr, sudoku, played,  size, 100, 250, border_color, line_color)
    pb = gtk.gdk.pixbuf_new_from_data(surface.get_data(), gtk.gdk.COLORSPACE_RGB,
                                          True, 8, surface.get_width(), surface.get_height(), surface.get_stride())
    del surface


    w = gtk.Window()
    img = gtk.Image()
    img.set_from_pixbuf(pb)
    w.add(img)
    w.show_all()
    gtk.main()

