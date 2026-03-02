#!/usr/bin/env python3
#
# frep_multicore.py
#    functional representation solver (multithreaded)
#
# usage:
#    pcb.py | frep_multicore.py [dpi [filename]]
#    pcb.py | frep_multicore.py --c [dpi [filename]]   # generate C, compile, run (faster)
#
# Default: NumPy evaluation (works everywhere). With --c: generates C code,
# compiles with gcc/clang, runs multi-threaded native code, then cleans up.

import json
import sys
import os

# ---------------------------------------------------------------------------
# argv: optional --c / -c, then [dpi [filename]]
# ---------------------------------------------------------------------------
args = [a for a in sys.argv[1:] if a not in ('--c', '-c')]
use_c = ('--c' in sys.argv[1:]) or ('-c' in sys.argv[1:])

if len(args) == 0:
    dpi = 100
    filename = 'out.png'
elif len(args) == 1:
    dpi = int(args[0])
    filename = 'out.png'
else:
    dpi = int(args[0])
    filename = args[1]

frep = json.load(sys.stdin)

if frep.get('type') != 'RGB':
    print('types other than RGB not (yet) supported', file=sys.stderr)
    sys.exit(1)

if use_c:
    from frep_c_backend import run_c_backend
    if len(args) == 0:
        print('output to out.png at 300 DPI (C backend)')
        dpi = 300
        filename = 'out.png'
    elif len(args) == 1:
        print('output to out.png at', dpi, 'DPI (C backend)')
        filename = 'out.png'
    else:
        print('output to', filename, 'at', dpi, 'DPI (C backend)')
    print('compile ...')
    run_c_backend(frep, dpi, filename)
else:
    # NumPy path
    if len(args) == 0:
        print('output to out.png at 100 DPI')
    elif len(args) == 1:
        print('output to out.png at', dpi, 'DPI')
    else:
        print('output to', filename, 'at', dpi, 'DPI')

    from numpy import *
    from PIL import Image

    print('evaluating')
    xmin = frep['xmin']
    xmax = frep['xmax']
    ymin = frep['ymin']
    ymax = frep['ymax']
    units = float(frep['mm_per_unit'])
    delta = (25.4 / dpi) / units

    x = arange(xmin, xmax, delta)
    y = flip(arange(ymin, ymax, delta), 0)
    X = outer(ones(y.size), x)
    Y = outer(y, ones(x.size))

    num_threads = os.cpu_count() or 1
    print(f"   (NumPy using {num_threads} cores internally)")

    if len(frep['layers']) == 1:
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

    m = zeros((y.size, x.size, 3), dtype=uint8)
    m[:, :, 0] = (f & 255)
    m[:, :, 1] = ((f >> 8) & 255)
    m[:, :, 2] = ((f >> 16) & 255)
    im = Image.fromarray(m, 'RGB')
    im.save(filename, dpi=[dpi, dpi])
    print("Saved: " + filename)
