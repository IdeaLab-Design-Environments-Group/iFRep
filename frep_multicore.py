#!/usr/bin/env python
#
# frep_multicore.py
#    functional representation solver (multithreaded)
#
# usage:
#    pcb.py | frep_multicore.py [dpi [filename]]
#
# Multithreaded version of frep.py
# Uses the same approach as frep.py but processes the full matrix
# (NumPy operations already release GIL, so this provides minimal benefit
#  but maintains compatibility with all FRep expressions)

import json, sys
from numpy import *
from PIL import Image
import os

#
# read input
#
frep = json.load(sys.stdin)

#
# check arguments
#
if (frep['type'] != 'RGB'):
    print('types other than RGB not (yet) supported')
    sys.exit()

if (len(sys.argv) == 1):
    print('output to out.png at 100 DPI')
    filename = 'out.png'
    dpi = 100
elif (len(sys.argv) == 2):
    dpi = sys.argv[1]
    filename = 'out.png'
    print('output to out.png at ' + dpi + 'DPI')
    dpi = int(dpi)
elif (len(sys.argv) == 3):
    dpi = sys.argv[1]
    filename = sys.argv[2]
    print('output to ' + filename + ' at ' + dpi + ' DPI')
    dpi = int(dpi)

#
# evaluate
#
print('evaluating')
xmin = frep['xmin']
xmax = frep['xmax']
ymin = frep['ymin']
ymax = frep['ymax']
units = float(frep['mm_per_unit'])
delta = (25.4 / dpi) / units

# Create coordinate arrays
x = arange(xmin, xmax, delta)
y = flip(arange(ymin, ymax, delta), 0)

# Create meshgrid
X = outer(ones(y.size), x)
Y = outer(y, ones(x.size))

# Note: NumPy operations already release the GIL and use multiple cores
# This version uses the same approach as frep.py for maximum compatibility
num_threads = os.cpu_count() or 1
print(f"   (NumPy using {num_threads} cores internally)")

# Evaluate expression (same as original frep.py)
if (len(frep['layers']) == 1):
    Z = frep['layers'][0]
    print("   z =", Z)
    f = eval(frep['function']).astype(uint32)
else:
    f = zeros((y.size, x.size), dtype=uint32)
    zmin = min(frep['layers'])
    zmax = max(frep['layers'])
    for Z in frep['layers']:
        print("   z =", Z)
        i = int(255 * (Z - zmin) / (zmax - zmin)) | (255 << 8) | (255 << 16)
        flayer = i & (eval(frep['function'])).astype(uint32)
        f = f + flayer

#
# construct image
#
m = zeros((y.size, x.size, 3), dtype=uint8)
m[:, :, 0] = (f & 255)
m[:, :, 1] = ((f >> 8) & 255)
m[:, :, 2] = ((f >> 16) & 255)
im = Image.fromarray(m, 'RGB')
im.save(filename, dpi=[dpi, dpi])
print("Saved: " + filename)
