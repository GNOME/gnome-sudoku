import cairo
import pango
import gtk

SUDOKU_SIZE = 9
N_BOXES = 3
FONT_SIZE = 9
SQUARE_SIZE = 11
THICK = 2 #SIZE/33 or 1
BORDER = THICK*2
THIN = 1 #SIZE/100 or 1
PENCIL_GREY = (0.3,0.3,0.3)
LINE_GREY = (0.4,0.4,0.4)
SIZE = (
    (2 * (BORDER+THICK)) # OUTER BORDER
    +
    ((N_BOXES - 1) * THICK) # INNER THICK LINES
    +
    (SQUARE_SIZE * SUDOKU_SIZE) # WHITE SPACE IN SQUARES
    +
    (SUDOKU_SIZE - N_BOXES - 1)
    )
    
(SQUARE_SIZE * SUDOKU_SIZE) + (N_BOXES)*THICK + (SUDOKU_SIZE-N_BOXES)*THIN

sudoku = [[0, 0, 2, 3, 4, 5, 6, 0, 0]]*SUDOKU_SIZE
played = [[1,2,0,0,0,0,0,0,0,0]]+[[0,0,0,0,0,0,0,0,0,0]]*8

def make_image_surface (sudoku, played, highlight_color):
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, SIZE, SIZE)
    cr = cairo.Context(surface)
    cr.set_line_width(BORDER)
    cr.set_line_join(cairo.LINE_JOIN_ROUND)
    cr.rectangle(BORDER*.5,
                 BORDER*.5,
                 (SIZE-(BORDER)),
                 (SIZE-(BORDER)),
        )
    #print 'HIGHLIGHT: ',BORDER*0.5,'-',SIZE-BORDER
    cr.set_source_rgb(1,1,1)
    cr.fill_preserve()
    cr.set_source_rgb(*highlight_color)
    cr.stroke()
    cr.set_source_rgb(*LINE_GREY)
    cr.set_line_width(THICK)
    #cr.set_line_join(cairo.LINE_JOIN_MITER)
    cr.rectangle(BORDER,
                 BORDER,
                 (SIZE-(BORDER+2*THICK)),
                 (SIZE-(BORDER+2*THICK)),
        )
    cr.stroke()
    small_size = SIZE / float(SUDOKU_SIZE)
    position = BORDER + THICK
    pos = {}
    pos[0] = position + (SQUARE_SIZE/2.0)
    #print 'Full size=',SIZE
    #print 'border =',BORDER
    #print 'thin lines=',THIN
    #print 'thick lines=',THICK
    #print 'square size=',SQUARE_SIZE
    last_line = 0
    for n in range(1,SUDOKU_SIZE):
        if n % N_BOXES == 0:
            cr.set_line_width(THICK)
            position += SQUARE_SIZE + last_line/2.0 + THICK/2.0
            last_line = THICK
            #print 'THICK',
        else:
            cr.set_line_width(THIN)
            position += SQUARE_SIZE + last_line/2.0 + THIN/2.0
            last_line = THIN
            #print 'THIN ',
        pos[n] = position + ((last_line + SQUARE_SIZE)/2.0)
        #print 'draw at ',position
        cr.move_to(BORDER,position)
        cr.line_to(SIZE-BORDER,position)
        cr.move_to(position,BORDER)
        cr.line_to(position,SIZE-BORDER)
        cr.stroke()
    cr.set_font_size(FONT_SIZE)
    for x in range(SUDOKU_SIZE):
        for y in range(SUDOKU_SIZE):
            cr.move_to(pos[x],pos[y])
            #cr.arc(pos[x],pos[y],SQUARE_SIZE/3.0,0.1,0)
            #cr.stroke()
            letter = None
            if sudoku[y][x]:
                letter = str(sudoku[y][x])
                cr.select_font_face("",
                         cairo.FONT_SLANT_NORMAL,
                         cairo.FONT_WEIGHT_BOLD)
                         #cairo.FONT_WEIGHT_NORMAL)
                cr.set_source_rgb(0,0,0)    
                xbearing,ybearing,width,height,xadvance,yadvance = (
                    cr.text_extents(letter)
                    )                

            elif played and played[y][x]:
                cr.select_font_face("Times",
                                    cairo.FONT_SLANT_ITALIC,
                                    cairo.FONT_WEIGHT_NORMAL)
                cr.set_source_rgb(*PENCIL_GREY)
                letter = str(played[y][x])
                xbearing,ybearing,width,height,xadvance,yadvance = (
                    cr.text_extents(letter)
                    )
            if letter:
                cr.move_to(pos[x]-(xadvance/2.0),
                           pos[y]+(height/2.0))
                cr.show_text(letter)
    return surface

def make_pixbuf (sudoku, played, highlight_color):
    surf = make_image_surface(sudoku,played,highlight_color)
    pixbuf = gtk.gdk.pixbuf_new_from_data(surf.get_data(), gtk.gdk.COLORSPACE_RGB,
                                          True, 8, SIZE, SIZE, SIZE*4)
    del surf
    return pixbuf

if __name__ == '__main__':
    make_image_surface(sudoku,played,
                       (1.0,0.5,0.5)).write_to_png(
        '/home/tom/Desktop/test.png'
        )
                                               
                   
