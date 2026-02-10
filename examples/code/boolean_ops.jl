#!/usr/bin/env julia
#
# boolean_ops.jl
#    Simple example demonstrating boolean operations (union, difference, intersect)
#
# usage:
#    julia boolean_ops.jl | julia ../frep.jl [dpi [filename]]
#

using JSON

# Include the main Fpcb.jl file to get shape functions and constants
include("../../Fpcb.jl")

############################################################
# Example: Demonstrate boolean operations
############################################################

# Board parameters
const board_x = 0.0
const board_y = 0.0
const board_width = 4.0
const board_height = 3.0
const board_z_top = 0.0

# Create board outline
board_outline = rectangle(board_x, board_x + board_width, 
                         board_y, board_y + board_height)

# Create base shapes for demonstrations
# Left section: Union demonstration
circle1 = circle(0.8, 2.0, 0.3)
circle2 = circle(1.2, 2.0, 0.3)
# Union: Combine two circles (OR operation)
union_result = union(circle1, circle2)
union_colored = color(COLOR_RED, union_result)

# Center section: Difference demonstration
outer_rect = rectangle(1.8, 2.8, 0.5, 2.5)
inner_rect = rectangle(2.0, 2.6, 0.7, 2.3)
# Difference: Subtract inner from outer (AND NOT operation)
difference_result = difference(outer_rect, inner_rect)
difference_colored = color(COLOR_GREEN, difference_result)

# Right section: Intersect demonstration
circle3 = circle(3.2, 1.5, 0.4)
circle4 = circle(3.5, 1.5, 0.4)
# Intersect: Find overlapping region (AND operation)
intersect_result = intersect(circle3, circle4)
intersect_colored = color(COLOR_BLUE, intersect_result)

# Combine all boolean operation results
all_operations = union(union_colored, difference_colored)
all_operations = union(all_operations, intersect_colored)

# Create exterior (white background)
exterior_expr = difference(TRUE_EXPR, board_outline)
white_exterior = color(COLOR_WHITE, exterior_expr)

# Final output
output_function = union(all_operations, white_exterior)

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
