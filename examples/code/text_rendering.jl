#!/usr/bin/env julia
#
# text_rendering.jl
#    Example demonstrating text rendering capabilities
#
# usage:
#    julia text_rendering.jl | julia ../frep.jl [dpi [filename]]
#

using JSON
include("../../Fpcb.jl")

const board_x = 0.0
const board_y = 0.0
const board_width = 6.0
const board_height = 8.0
const board_z_top = 0.0

# Create board outline
board_outline = rectangle(board_x, board_x + board_width,
                         board_y, board_y + board_height)

# --- Example 1: Basic text labels ---
# Simple text at different positions
text1 = text("PCB", 1.0, 7.0, board_z_top, 
             line=0.15, height=0.8, width=0.5, 
             color_value=UInt32(COLOR_BLUE))
text2 = text("Design", 1.0, 6.0, board_z_top,
             line=0.12, height=0.6, width=0.4,
             color_value=UInt32(COLOR_GREEN))

# --- Example 2: Multi-line text ---
# Text with line breaks
multiline_text = text("Line 1\nLine 2\nLine 3", 4.0, 7.0, board_z_top,
                      line=0.1, height=0.5, width=0.35,
                      align="LT", color_value=UInt32(COLOR_RED))

# --- Example 3: Rotated text ---
# Text rotated 90 degrees (using purple-like color: pink)
rotated_text = text("ROTATED", 0.5, 4.0, board_z_top,
                    line=0.1, height=0.5, width=0.35,
                    angle=90.0, color_value=UInt32(COLOR_PINK))

# --- Example 4: Centered text ---
# Text centered on board (using yellow)
centered_text = text("CENTER", 3.0, 4.0, board_z_top,
                     line=0.12, height=0.6, width=0.4,
                     align="CC", color_value=UInt32(COLOR_YELLOW))

# --- Example 5: Right-aligned text ---
# Text aligned to the right
right_text = text("RIGHT", 5.5, 2.0, board_z_top,
                  line=0.1, height=0.5, width=0.35,
                  align="RT", color_value=UInt32(COLOR_TEAL))

# --- Example 6: Text with shapes ---
# Combine text with geometric shapes
label_circle = circle(4.5, 1.5, 0.3)
label_circle_colored = color(UInt32(COLOR_YELLOW), label_circle)
label_text = text("PIN", 4.5, 1.5, board_z_top,
                  line=0.08, height=0.4, width=0.3,
                  align="CC", color_value=UInt32(COLOR_NAVY))

# Combine all text elements
all_text = union(text1, text2)
all_text = union(all_text, multiline_text)
all_text = union(all_text, rotated_text)
all_text = union(all_text, centered_text)
all_text = union(all_text, right_text)
all_text = union(all_text, label_circle_colored)
all_text = union(all_text, label_text)

# Create exterior (area outside board) - white colored
exterior_expr = difference(TRUE_EXPR, board_outline)
white_exterior = color(UInt32(COLOR_WHITE), exterior_expr)

# Combine board and exterior
output_function = union(all_text, white_exterior)

# Generate output JSON
outputs = Dict(
    "function" => output_function,
    "layers" => [board_z_top],
    "xmin" => board_x - 0.1,
    "xmax" => board_x + board_width + 0.1,
    "ymin" => board_y - 0.1,
    "ymax" => board_y + board_height + 0.1,
    "mm_per_unit" => 25.4,
    "type" => "RGB"
)

# Output JSON to stdout
println(JSON.json(outputs))
