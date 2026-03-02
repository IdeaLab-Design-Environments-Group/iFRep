#!/usr/bin/env python3
#
# sample_pcb_design.py
#    Simple PCB sample — small board with pads and a trace.
#    Outputs FRep JSON for frep_multicore.py (same format as pcb.py / simple_pcb.py).
#
# usage:
#    python3 sample_pcb_design.py | python3 frep_multicore.py [dpi [filename]]
#    python3 sample_pcb_design.py | python3 frep_multicore.py --c [dpi [filename]]
#
# Example: 1.5" x 1" board with 3 pads and one trace between them.

import json
import sys

# ---------------------------------------------------------------------------
# Minimal FRep primitives (string expressions in X, Y, Z)
# ---------------------------------------------------------------------------

def color(c, part):
    return f'({c}*(({part})!=0))'

def add(part1, part2):
    return f'(({part1}) | ({part2}))'

def rectangle(x0, x1, y0, y1):
    return f'((X >= ({x0})) & (X <= ({x1})) & (Y >= ({y0})) & (Y <= ({y1})))'

def circle(x0, y0, r):
    return f'(((X-({x0}))*(X-({x0})) + (Y-({y0}))*(Y-({y0}))) <= ({r}*{r}))'

# Colors (RGB packed)
Tan   = (60 << 16) + (90 << 8) + (125 << 0)
White = (255 << 16) + (255 << 8) + (255 << 0)
Blue  = (225 << 8)

# ---------------------------------------------------------------------------
# Board: 1.5" x 1" with border, 3 pads, and one trace
# ---------------------------------------------------------------------------
x, y = 0.0, 0.0
width, height = 1.5, 1.0
border = 0.05
pad_r = 0.06
trace_w = 0.04

# Board outline and exterior
board    = rectangle(x, x + width, y, y + height)
exterior = rectangle(x - border, x + width + border, y - border, y + height + border)

# Three pads (left, center, right)
pad_left   = circle(x + 0.25, y + height/2, pad_r)
pad_center = circle(x + width/2, y + height/2, pad_r)
pad_right  = circle(x + width - 0.25, y + height/2, pad_r)

# Simple horizontal trace connecting left and center pads
trace = rectangle(
    x + 0.25 + pad_r,
    x + width/2 - pad_r,
    y + height/2 - trace_w/2,
    y + height/2 + trace_w/2
)

# Copper = pads + trace (drawn in white on top of board)
copper = add(add(add(pad_left, pad_center), pad_right), trace)
# Final: board (tan) + exterior outline (white) + copper (white)
outputs = {
    "type": "RGB",
    "xmin": x - border,
    "xmax": x + width + border,
    "ymin": y - border,
    "ymax": y + height + border,
    "mm_per_unit": 25.4,
    "layers": [0],
    "function": add(add(color(Tan, board), color(White, exterior)), color(White, copper)),
}

json.dump(outputs, sys.stdout)
