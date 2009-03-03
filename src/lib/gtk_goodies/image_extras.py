# -*- coding: utf-8 -*-
import gtk
import string
import StringIO

# from http://www.daa.com.au/pipermail/pygtk/2003-June/005268.html
# (Sebastian Wilhelmi)

def pil_to_pixbuf (image):
    file = StringIO.StringIO()
    image.save(file, 'ppm')
    contents = file.getvalue()
    file.close()
    loader = gtk.gdk.PixbufLoader('pnm')
    loader.write (contents, len(contents))
    pixbuf = loader.get_pixbuf()
    loader.close()
    return pixbuf


def html_to_tuple (hexstr):
    # hackishly except 3 chars rather than 6
    if hexstr[0]=="#": hexstr=hexstr[1:]
    if len(hexstr)==3:
        hexstr = hexstr[0]+hexstr[0]+hexstr[1]+hexstr[1]+hexstr[2]+hexstr[2]
    if len(hexstr)!=6: raise ValueError('String must have 3 or 6 digits!')
    r = string.atoi(hexstr[0:2],16)
    g = string.atoi(hexstr[2:4],16)
    b = string.atoi(hexstr[4:],16)
    return (r,g,b)

def color_tuple_float_to_int (tup):
    """Take a tuple with float values from 0.0-1.0 and convert them to
    integer values from 0-255"""
    return (int(tup[0]*255),
            int(tup[1]*255),
            int(tup[2]*255))

def pixbuf_transform_color (pb,
                            target_color):
    """Return a pixbuf with one color transformed."""
    initial_color = (chr(0),chr(0),chr(0))
    if type(target_color)==str: target_color=html_to_tuple(target_color)
    if type(target_color[1])==float: target_color = color_tuple_float_to_int(target_color)

    pb_str = pb.get_pixels()
    pb_str_new = ""

    for index in range(len(pb_str)/4):
        pxl = [pb_str[(index*4)+0],
               pb_str[(index*4)+1],
               pb_str[(index*4)+2],
               pb_str[(index*4)+3]]

        if pxl[3] != chr(0): # not transparent
            if (pxl[0],pxl[1],pxl[2]) == initial_color:
                pxl[0] = chr(target_color[0])
                pxl[1] = chr(target_color[1])
                pxl[2] = chr(target_color[2])
        pb_str_new += pxl[0] + pxl[1] + pxl[2] + pxl[3] 
    
    return gtk.gdk.pixbuf_new_from_data(pb_str_new, gtk.gdk.COLORSPACE_RGB, True, 8, pb.get_width(), pb.get_height(), pb.get_rowstride())


