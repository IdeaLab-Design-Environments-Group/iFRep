#!/usr/bin/env julia
#
# simple_shapes.jl
#    Simple example demonstrating functional representation shapes
#
# usage:
#    julia simple_shapes.jl | julia ../frep.jl [dpi [filename]]
#

using JSON

# Include the main Fpcb.jl file to get shape functions and constants
include("../../Fpcb.jl")

############################################################
# Simple example: Create a board with basic shapes
############################################################

# Board parameters
const board_x = 0.0
const board_y = 0.0
const board_width = 2.0
const board_height = 2.0
const board_z_top = 0.0

# Create board outline (rectangle)
board_outline = rectangle(board_x, board_x + board_width, 
                         board_y, board_y + board_height)

# Create some example shapes on the board
# Circle pad at position (0.5, 0.5) with radius 0.1
circle_pad = circle(0.5, 0.5, 0.1)

# Rectangle pad from (1.0, 0.5) to (1.5, 1.0)
rect_pad = rectangle(1.0, 1.5, 0.5, 1.0)

# Another circle at (1.5, 1.5) with radius 0.15
circle2 = circle(1.5, 1.5, 0.15)

# Combine all shapes using union
all_shapes = union(circle_pad, rect_pad)
all_shapes = union(all_shapes, circle2)

# Create traces connecting the shapes (lines with width)
trace1 = line(0.5, 0.5, 1.0, 0.75, board_z_top, 0.02)
trace2 = line(1.5, 0.75, 1.5, 1.5, board_z_top, 0.02)

# Combine everything (shapes and traces)
final_board = union(all_shapes, trace1)
final_board = union(final_board, trace2)

# Create exterior (area outside board)
# Exterior is everything NOT in the board outline
exterior_expr = difference(TRUE_EXPR, board_outline)

# Apply colors to board and exterior
# Board shapes will be colored tan, exterior will be white
colored_board = color(COLOR_TAN, final_board)
colored_exterior = color(COLOR_WHITE, exterior_expr)

# Combine colored board and exterior
output_function = union(colored_board, colored_exterior)

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

json_str = JSON.json(outputs)

# If no args, emit JSON to stdout for piping into frep.jl (original behavior)
if length(ARGS) == 0
    println(json_str)
elseif length(ARGS) <= 2
    frep_path = joinpath(@__DIR__, "..", "..", "frep.jl")
    cmd = `julia $frep_path $(ARGS...)`
    open(cmd, "w") do io
        write(io, json_str)
    end
else
    println("usage: julia simple_shapes.jl [dpi [filename]]")
    exit(1)
end
