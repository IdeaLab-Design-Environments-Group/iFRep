#!/usr/bin/env julia
#
# simple_pcb.jl
#    Minimal PCB example for quick testing
#
# usage:
#    cd examples/code
#    julia simple_pcb.jl | julia -t auto ../../frep_multicore.jl [dpi [filename]]
#    OR from examples/:
#    julia code/simple_pcb.jl | python3 ../frep_multicore.py [dpi [filename]]
#

using JSON

# Include the main Fpcb.jl file
include("../../Fpcb.jl")

############################################################
# Simple PCB Example: Minimal board with one LED
############################################################

# Board parameters - smaller board for faster rendering
const width = 0.5       # board width in inches (smaller)
const height = 0.5      # board height in inches (smaller)
const x0 = 0.5          # x origin
const y0 = 0.5          # y origin
const zt = 0.0          # top z
const zb = -0.06        # bottom z
const w = 0.015         # wire width
const mask = 0.004      # solder mask size
const border = 0.05     # image render border

# Create PCB
pcb = PCB(x0, y0, width, height, mask)

# Add just one simple LED (minimal components)
led1 = LED_1206("LED1")
pcb = add_component(pcb, led1, x0 + width/2, y0 + height/2, 0.0, angle=0.0)

# Add simple text label
pcb = add_text(pcb, "Simple PCB", x0 + width / 2.0, y0 + height - 0.08, 
               line=0.01, color_value=UInt32(COLOR_WHITE))

# Generate output - use TOP_FULL for faster rendering (single layer, no bottom)
outputs = generate_output(pcb, x0, y0, zb, zt, border, "TOP_FULL")

# Output JSON
json_str = JSON.json(outputs)

# If no args, emit JSON to stdout for piping into frep.jl
if length(ARGS) == 0
    println(json_str)
elseif length(ARGS) <= 2
    frep_path = joinpath(@__DIR__, "..", "..", "frep_multicore.jl")
    cmd = `julia -t auto $frep_path $(ARGS...)`
    open(cmd, "w") do io
        write(io, json_str)
    end
else
    println("usage: julia simple_pcb.jl [dpi [filename]]")
    exit(1)
end
