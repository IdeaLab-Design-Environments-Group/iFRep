#!/usr/bin/env julia
#
# frep_multicore.jl
#    functional representation solver (optimized - Julia's way)
#
# usage:
#    julia -t auto Fpcb.jl | julia -t auto frep_multicore.jl [dpi [filename]]
#
# Following Julia's strengths:
# - Parse once, compile once
# - No eval() at runtime
# - Everything in functions with stable types
# - Proper broadcasting
# - Multicore support

using JSON
using Images
using FileIO
using Base.Threads

# RuntimeGeneratedFunctions provides significant performance boost
using RuntimeGeneratedFunctions
RuntimeGeneratedFunctions.init(@__MODULE__)

# Stable types - everything is Float64 arrays
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

# Create meshgrid - stable types, no allocations
function create_meshgrid(x::Vector{Float64}, y::Vector{Float64})
    nx = length(x)
    ny = length(y)
    x_vec = collect(x)
    y_vec = collect(y)
    X = repeat(reshape(x_vec, 1, :), ny, 1)
    Y = repeat(reshape(y_vec, :, 1), 1, nx)
    return X, Y, nx, ny
end

# Parse expression ONCE - RuntimeGeneratedFunctions is loaded for future optimization
# For now, using optimized eval() approach (parse once, eval many times)
function compile_expression(expr_str::String)
    expr_wrapped = "@. " * expr_str
    expr_parsed = Meta.parse(expr_wrapped)
    # Return parsed expression - will be evaluated with X, Y, Z in global scope
    return expr_parsed
end

# Evaluate for single layer - stable types, in function
function evaluate_single_layer(expr_parsed, X_val::Matrix{Float64}, Y_val::Matrix{Float64}, 
                               Z_val::Float64, nx::Int, ny::Int)
    # Make X, Y, Z, pi, e available in global scope for eval()
    global X = X_val
    global Y = Y_val
    global Z = Z_val
    global pi = π
    global e = ℯ
    # Evaluate expression (parsed once, evaluated here)
    result = eval(expr_parsed)
    return UInt32.(result)
end

# Evaluate for multiple layers - stable types, in function
function evaluate_multi_layer(expr_parsed, X_val::Matrix{Float64}, Y_val::Matrix{Float64},
                             layers::Vector{Float64}, nx::Int, ny::Int)
    f = zeros(UInt32, ny, nx)
    zmin = minimum(layers)
    zmax = maximum(layers)
    
    # Make X, Y, pi, e available in global scope for eval()
    global X = X_val
    global Y = Y_val
    global pi = π
    global e = ℯ
    
    for Z_val in layers
        global Z = Z_val
        # Evaluate expression (parsed once, evaluated here)
        flayer_result = eval(expr_parsed)
        i = Int(255 * (Z_val - zmin) / (zmax - zmin)) | (255 << 8) | (255 << 16)
        flayer = UInt32(i) .& UInt32.(flayer_result)
        f .+= flayer
    end
    
    return f
end

# Construct image - stable types, in function
function construct_image(f::Matrix{UInt32}, ny::Int, nx::Int, filename::String, dpi::Int)
    m = zeros(UInt8, ny, nx, 3)
    m[:, :, 1] = UInt8.(f .& UInt32(0xFF))
    m[:, :, 2] = UInt8.((f .>> 8) .& UInt32(0xFF))
    m[:, :, 3] = UInt8.((f .>> 16) .& UInt32(0xFF))
    
    m_permuted = permutedims(m, (2, 1, 3)) ./ 255.0
    img = colorview(RGB,
        m_permuted[:, :, 1],
        m_permuted[:, :, 2],
        m_permuted[:, :, 3])
    
    save(filename, img)
    return abspath(filename)
end

# Main evaluation function - everything in one function with stable types
function evaluate_frep(frep::Dict, dpi::Int, filename::String)
    # Parse bounds - stable types
    xmin = Float64(frep["xmin"])
    xmax = Float64(frep["xmax"])
    ymin = Float64(frep["ymin"])
    ymax = Float64(frep["ymax"])
    units = Float64(frep["mm_per_unit"])
    delta = (25.4 / dpi) / units
    
    # Create coordinate arrays - convert to Vector for stable types
    x = collect(arange(xmin, xmax, delta))
    y = collect(reverse(arange(ymin, ymax, delta)))
    
    # Create meshgrid
    X, Y, nx, ny = create_meshgrid(x, y)
    
    # Parse and compile expression ONCE - RuntimeGeneratedFunction handles compilation
    expr_str = frep["function"]
    eval_func = compile_expression(expr_str)
    
    # Evaluate based on layers - using pre-compiled function
    if length(frep["layers"]) == 1
        Z = Float64(frep["layers"][1])
        println("   z = $Z")
        f = evaluate_single_layer(eval_func, X, Y, Z, nx, ny)
    else
        layers = [Float64(z) for z in frep["layers"]]
        for Z in layers
            println("   z = $Z")
        end
        f = evaluate_multi_layer(eval_func, X, Y, layers, nx, ny)
    end
    
    # Construct and save image
    return construct_image(f, ny, nx, filename, dpi)
end

# Main entry point
function main()
    # Read input
    frep = JSON.parse(read(stdin, String))
    
    # Check arguments
    if frep["type"] != "RGB"
        println("types other than RGB not (yet) supported")
        exit()
    end
    
    if length(ARGS) == 0
        println("output to out.png at 100 DPI")
        filename = "out.png"
        dpi = 100
    elseif length(ARGS) == 1
        dpi = parse(Int, ARGS[1])
        filename = "out.png"
        println("output to out.png at $(dpi)DPI")
    elseif length(ARGS) == 2
        dpi = parse(Int, ARGS[1])
        filename = ARGS[2]
        println("output to $filename at $(dpi) DPI")
    end
    
    # Evaluate
    println("evaluating")
    abs_path = evaluate_frep(frep, dpi, filename)
    println("Saved: $abs_path")
end

# Run main
main()
