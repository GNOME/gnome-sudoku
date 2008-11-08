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
                            initial_color,
                            target_color):
    """Return a pixbuf with one color transformed."""
    if type(initial_color)==str: initial_color=html_to_tuple(initial_color)
    if type(target_color)==str: target_color=html_to_tuple(target_color)
    if type(initial_color[0])==float:
        initial_color = color_tuple_float_to_int(initial_color)
    if type(target_color[1])==float:
        target_color = color_tuple_float_to_int(target_color)
    arr = pb.get_pixels_array()
    arr = arr.copy()
    for row in arr:
        for pxl in row:
            if int(pxl[3])!=0: # not transparent
                if (not initial_color) or ((int(pxl[0])==initial_color[0] and
                                            int(pxl[1])==initial_color[1] and
                                            int(pxl[2])==initial_color[2])):
                    pxl[0]=target_color[0]
                    pxl[1]=target_color[1]
                    pxl[2]=target_color[2]
                elif pxl[0]==0:
                    print pxl[0]==initial_color[0]
                    print pxl[1]==initial_color[1]
                    print pxl[2]==initial_color[2]                    
    return gtk.gdk.pixbuf_new_from_array(arr,
                                         pb.get_colorspace(),
                                         pb.get_bits_per_sample()
                                         )


