#!/usr/bin/env python3
#
# simple_pcb.py
#    Minimal PCB example — outputs FRep JSON for frep_multicore.py
#
# usage:
#    python3 simple_pcb.py | python3 frep_multicore.py [dpi [filename]]
#    python3 simple_pcb.py | python3 frep_multicore.py --c [dpi [filename]]
#
# A 1" x 1" board with one pad. Same JSON format as pcb.py.

import json
import sys

# ---------------------------------------------------------------------------
# Minimal FRep primitives (string expressions in X, Y, Z)
# ---------------------------------------------------------------------------

def color(c, part):
    return f'({c}*(({part})!=0))'

def add(part1, part2):
    return f'(({part1}) | ({part2}))'

def subtract(part1, part2):
    return f'(({part1}) & ~({part2}))'

def rectangle(x0, x1, y0, y1):
    return f'((X >= ({x0})) & (X <= ({x1})) & (Y >= ({y0})) & (Y <= ({y1})))'

def circle(x0, y0, r):
    return f'(((X-({x0}))*(X-({x0})) + (Y-({y0}))*(Y-({y0}))) <= ({r}*{r}))'

# Colors (RGB packed)
Tan   = (60 << 16) + (90 << 8) + (125 << 0)
White = (255 << 16) + (255 << 8) + (255 << 0)
Blue  = (225 << 8)

# ---------------------------------------------------------------------------
# Board: 1" x 1" with border and one pad
# ---------------------------------------------------------------------------
x, y = 0.0, 0.0
width, height = 1.0, 1.0
border = 0.05

board    = rectangle(x, x + width, y, y + height)
exterior = rectangle(x - border, x + width + border, y - border, y + height + border)
pad      = circle(x + width/2, y + height/2, 0.05)

# One layer (top); output: board (tan) + exterior outline (white) + pad (white)
zt = 0
outputs = {
    "type": "RGB",
    "xmin": x - border,
    "xmax": x + width + border,
    "ymin": y - border,
    "ymax": y + height + border,
    "mm_per_unit": 25.4,
    "layers": [zt],
    "function": add(add(color(Tan, board), color(White, exterior)), color(White, pad)),
}

json.dump(outputs, sys.stdout)
