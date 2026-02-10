#!/usr/bin/env julia
#
# frep.jl
#    functional representation solver
#
# usage:
#    julia Fpcb.jl | julia frep.jl [dpi [filename]]
#
# Exact replication of Python frep.py for maximum performance

using JSON
using Images
using FileIO

# read input
frep = JSON.parse(read(stdin, String))

# check arguments
if frep["type"] != "RGB"
    println("types other than RGB not (yet) supported")
    exit()
end

if length(ARGS) == 0
    println("output to out.png at 100 DPI")
    filename = "out.png"
    dpi = 100
elseif length(ARGS) == 1
    dpi = ARGS[1]
    filename = "out.png"
    println("output to out.png at $(dpi)DPI")
    dpi = parse(Int, dpi)
elseif length(ARGS) == 2
    dpi = ARGS[1]
    filename = ARGS[2]
    println("output to $filename at $(dpi) DPI")
    dpi = parse(Int, dpi)
end

# evaluate
println("evaluating")
xmin = Float64(frep["xmin"])
xmax = Float64(frep["xmax"])
ymin = Float64(frep["ymin"])
ymax = Float64(frep["ymax"])
units = Float64(frep["mm_per_unit"])
delta = (25.4 / dpi) / units

# Create coordinate arrays (exactly like Python: arange)
function arange(start::Float64, stop::Float64, step::Float64)
    if step == 0.0
        return Float64[]
    end
    n = Int(ceil((stop - start) / step))
    if n <= 0
        return Float64[]
    end
    return start .+ step .* (0:(n - 1))
end

x = arange(xmin, xmax, delta)
y = reverse(arange(ymin, ymax, delta))  # Python: flip(arange(...), 0) - reverse y axis

# Create meshgrid exactly like Python: X = outer(ones(y.size), x), Y = outer(y, ones(x.size))
# outer(a, b) creates a matrix where result[i,j] = a[i] * b[j]
# For X: each row is x (repeated)
# For Y: each column is y (repeated)
nx = length(x)
ny = length(y)
# Convert to vectors and use repeat (matches Python's outer behavior)
x_vec = collect(x)
y_vec = collect(y)
X = repeat(reshape(x_vec, 1, :), ny, 1)  # Each row is x (repeated ny times)
Y = repeat(reshape(y_vec, :, 1), 1, nx)  # Each column is y (repeated nx times)

# Define pi and e as constants (like Python's eval uses current namespace)
# X, Y, Z are already in scope for eval()
const pi = π
const e = ℯ

# Parse expression once
expr_str = frep["function"]
expr_wrapped = "@. " * expr_str
expr_parsed = Meta.parse(expr_wrapped)

# Create a function that evaluates the expression
# Use a more direct approach to avoid recompilation
# We'll define the function in a way that Julia can optimize
eval_func = let expr = expr_parsed
    function eval_expr(X, Y, Z)
        eval(expr)
    end
end

if length(frep["layers"]) == 1
    Z = frep["layers"][1]
    println("   z = $Z")
    
    # Call the compiled function (fast - no recompilation)
    println("   evaluating expression...")
    @time f = UInt32.(eval_func(X, Y, Z))
    println("   expression evaluated")
    
else
    f = zeros(UInt32, ny, nx)
    zmin = minimum(frep["layers"])
    zmax = maximum(frep["layers"])
    
    for Z_val in frep["layers"]
        println("   z = $Z_val")
        
        # Call the compiled function (fast - no recompilation)
        flayer_result = eval_func(X, Y, Z_val)
        
        # Calculate intensity exactly like Python
        i = Int(255 * (Z_val - zmin) / (zmax - zmin)) | (255 << 8) | (255 << 16)
        flayer = UInt32(i) .& UInt32.(flayer_result)
        
        # Accumulate (Python: f = f + flayer)
        global f = f .+ flayer
    end
end

# construct image exactly like Python
println("   constructing image...")
@time begin
    m = zeros(UInt8, ny, nx, 3)
    m[:, :, 1] = UInt8.(f .& UInt32(0xFF))      # Python: m[:,:,0] = (f & 255)
    m[:, :, 2] = UInt8.((f .>> 8) .& UInt32(0xFF))  # Python: m[:,:,1] = ((f >> 8) & 255)
    m[:, :, 3] = UInt8.((f .>> 16) .& UInt32(0xFF)) # Python: m[:,:,2] = ((f >> 16) & 255)
    
    # Save image - use simpler approach like Python (no complex conversion)
    # Python: im = Image.fromarray(m,'RGB'); im.save(filename,dpi=[dpi,dpi])
    # Julia Images needs (width, height, channels) format
    m_permuted = permutedims(m, (2, 1, 3)) ./ 255.0
    img = colorview(RGB,
        m_permuted[:, :, 1],
        m_permuted[:, :, 2],
        m_permuted[:, :, 3])
    
    println("   saving image...")
    @time save(filename, img)
end
abs_path = abspath(filename)
println("Saved: $abs_path")
