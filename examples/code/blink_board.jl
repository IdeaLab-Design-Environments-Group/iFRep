#!/usr/bin/env julia
#
# blink_board.jl
#    LED Blink Board - Simple beginner-friendly PCB
#
# usage:
#    julia code/blink_board.jl | python3 ../frep_multicore.py [dpi [filename]]
#

using JSON

# Include the main Fpcb.jl file
include("../../Fpcb.jl")

############################################################
# LED Blink Board: Simple ATtiny + LED
############################################################

# Board parameters - simple compact board
const width = 1.0      # board width in inches
const height = 0.8     # board height in inches
const x0 = 0.5         # x origin
const y0 = 0.5         # y origin
const zt = 0.0         # top z
const zb = -0.06       # bottom z
const w = 0.015        # wire width
const mask = 0.004     # solder mask size
const border = 0.05    # image render border

# Create PCB
pcb = PCB(x0, y0, width, height, mask)

# Add ATtiny412 microcontroller (centered)
ic1 = ATtiny412("IC1\nATtiny412")
pcb = add_component(pcb, ic1, x0 + width/2, y0 + height/2, 0.0, angle=0.0)

# Add LED indicator (right side of microcontroller)
led1 = LED_1206("LED1")
pcb = add_component(pcb, led1, x0 + width/2 + 0.25, y0 + height/2, 0.0, angle=0.0)

# Add terminal pads for power (left side of microcontroller)
# Terminal A (VCC) - top
terminal_a = Component(
    pad_header,  # Use header pad for terminal
    [Point(0.0, 0.0, 0.0)],
    [component_text(0.0, 0.0, 0.0, text_str="A")],
    "A",
    nothing,
    nothing
)
pcb = add_component(pcb, terminal_a, x0 + width/2 - 0.3, y0 + height/2 + 0.15, 0.0, angle=0.0)

# Terminal C (GND) - bottom
terminal_c = Component(
    pad_header,  # Use header pad for terminal
    [Point(0.0, 0.0, 0.0)],
    [component_text(0.0, 0.0, 0.0, text_str="C")],
    "C",
    nothing,
    nothing
)
pcb = add_component(pcb, terminal_c, x0 + width/2 - 0.3, y0 + height/2 - 0.15, 0.0, angle=0.0)

# Component positions
ic_x = x0 + width/2
ic_y = y0 + height/2
led_x = x0 + width/2 + 0.25
led_y = y0 + height/2
term_a_x = x0 + width/2 - 0.3
term_a_y = y0 + height/2 + 0.15
term_c_x = x0 + width/2 - 0.3
term_c_y = y0 + height/2 - 0.15

# Wire connections

# VCC connection: Terminal A to microcontroller VCC
pcb = wire(pcb, w,
    Point(term_a_x, term_a_y, 0.0),          # Terminal A pad
    Point(ic_x - 0.11, term_a_y, 0.0),
    Point(ic_x - 0.11, ic_y + 0.075, 0.0)    # IC VCC pad
)

# GND connection: Terminal C to microcontroller GND
pcb = wire(pcb, w,
    Point(term_c_x, term_c_y, 0.0),          # Terminal C pad
    Point(ic_x - 0.11, term_c_y, 0.0),
    Point(ic_x - 0.11, ic_y + 0.075, 0.0)    # IC GND pad
)

# LED connection: LED anode to microcontroller GPIO pin
pcb = wire(pcb, w,
    Point(led_x - 0.06, led_y, 0.0),         # LED anode
    Point(ic_x + 0.11, led_y, 0.0),
    Point(ic_x + 0.11, ic_y - 0.025, 0.0)    # IC GPIO pin
)

# LED connection: LED cathode to ground
pcb = wire(pcb, w,
    Point(led_x + 0.06, led_y, 0.0),         # LED cathode
    Point(ic_x + 0.11, led_y, 0.0),
    Point(ic_x + 0.11, ic_y + 0.075, 0.0)    # IC GND
)

# Add text label
pcb = add_text(pcb, "LED Blink Board", x0 + width / 2.0, y0 + height - 0.08, 
               line=0.012, color_value=UInt32(COLOR_WHITE))

# Generate output
outputs = generate_output(pcb, x0, y0, zb, zt, border, "DUAL_LAYER_FULL")

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
    println("usage: julia blink_board.jl [dpi [filename]]")
    exit(1)
end
