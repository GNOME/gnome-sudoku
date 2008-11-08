# -*- coding: utf-8 -*-
def rgb_to_hsv (r,g,b,maxval=255):
    if type(r)==int: r = r/float(maxval)
    if type(g)==int: g = g/float(maxval)
    if type(b)==int: b = b/float(maxval)
    # Taken from
    # http://www.easyrgb.com/math.php?MATH=M20#text20
    var_min = min(r,g,b)
    var_max = max(r,g,b)
    delta = var_max - var_min
    v = var_max
    if delta == 0:
        # we're grey
        h = 0
        s = 0
    else:
        s = delta/var_max
        delta_r = ( ( (var_max - r) / 6) + (delta/2) ) / delta
        delta_g = ( ( (var_max - g) / 6) + (delta/2) ) / delta
        delta_b = ( ( (var_max - b) / 6) + (delta/2) ) / delta
        if (r==var_max):
            h = delta_b - delta_g
        elif g==var_max:
            h = (1.0/3)+delta_r-delta_b
        elif b==var_max:
            h = (2.0/3)+delta_g-delta_r
        if (h < 0): h+=1
        if (h > 1): h -= 1
    return h,s,v
            
def hsv_to_rgb (h,s,v):
    if s==0:
        return v,v,v
    else:
        h = h*6
        if h == 6: h = 0
        i = int(h)
        c1 = v*(1 - s)
        c2 = v*(1 - s * ( h-i ) )
        c3 = v *(1 - s * (1 - (h - i) ) )
        if i==0: r=v;g=c3;b=c1
        elif i==1: r=c2; g=v; b=c1
        elif i==2: r=c1; g=v; b=c3
        elif i==3: r=c1; g=c2; b=v
        elif i==4: r=c3; g=c1; b=v
        else: r=v; g=c1; b=c2
        return r,g,b

def rotate_hue (h,s,v, rotate_by=.25):
    h += rotate_by
    if h > 1.0: h = h-1.0
    return h,s,v

def rotate_hue_rgb (r,g,b, rotate_by=0.25, maxval=255):
    h,s,v = rgb_to_hsv(r,g,b,maxval=maxval)
    h,s,v = rotate_hue (h,s,v,rotate_by=rotate_by)
    return hsv_to_rgb(h,s,v)

def color_hex_to_float (hstr):
    hstr = hstr.strip('#')
    if len(hstr)==6:
        r = hstr[:2]
        g = hstr[2:4]
        b = hstr[4:]
        maxval = 255
    elif len(hstr)==3:
        r,g,b = hstr
        maxval = 15
    else:
        raise ValueError('%s is not a 6 or 3 digit color string'%hstr)
    r,g,b = int(r,16),int(g,16),int(b,16)
    return r/float(maxval),g/float(maxval),b/float(maxval)
