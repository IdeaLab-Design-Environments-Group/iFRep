#!/usr/bin/env julia
#
# Fpcb.jl
#    functional representation PCB template
#
# usage:
#    julia Fpcb.jl | julia frep.jl [dpi [filename]]
#

############################################################
# output configuration
############################################################

# Available render modes:
#   TOP_LAYER_ONLY          - Top copper layer only
#   TOP_WITH_LABELS         - Top layer with silkscreen labels
#   TOP_WITH_HOLES          - Top layer with drill holes
#   TOP_FULL                - Top layer, labels, holes, and board outline
#   DUAL_LAYER              - Both top and bottom layers
#   DUAL_LAYER_FULL         - Both layers with labels, holes, and outline
#   TOP_TRACES              - Top traces only (white)
#   TOP_TRACES_OUTLINE      - Top traces with board outline
#   BOTTOM_TRACES           - Bottom traces only
#   BOTTOM_TRACES_REVERSED  - Bottom traces mirrored for viewing
#   DRILL_HOLES             - Drill hole pattern
#   BOARD_INTERIOR          - Board area only
#   BOARD_EXTERIOR          - Area outside board
#   SOLDER_MASK_TOP         - Top solder mask layer
#   SOLDER_MASK_BOTTOM      - Bottom solder mask layer
#   SILKSCREEN_LABELS       - Silkscreen labels only
#   LABELS_NO_MASK          - Labels excluding mask areas

const RENDER_MODE = "DUAL_LAYER_FULL"  # Change this to select output type

############################################################
# imports
############################################################

using JSON

############################################################
# constants
############################################################

# Boolean expression constants
const TRUE_EXPR = "1"
const FALSE_EXPR = "0"

# Color constants (RGB packed as 32-bit integers)
# Format: (R << 16) | (G << 8) | B
const COLOR_RED = (225 << 0)
const COLOR_GREEN = (225 << 8)
const COLOR_BLUE = (225 << 16)
const COLOR_GRAY = (128 << 16) + (128 << 8) + (128 << 0)
const COLOR_WHITE = (255 << 16) + (255 << 8) + (255 << 0)
const COLOR_TEAL = (255 << 16) + (255 << 8)
const COLOR_PINK = (255 << 16) + (255 << 0)
const COLOR_YELLOW = (255 << 8) + (255 << 0)
const COLOR_BROWN = (45 << 16) + (82 << 8) + (145 << 0)
const COLOR_NAVY = (128 << 16) + (0 << 8) + (0 << 0)
const COLOR_TAN = (60 << 16) + (90 << 8) + (125 << 0)

############################################################
# shape primitives
############################################################

# Shape primitives generate mathematical string expressions that define
# geometric regions in 3D space. These expressions use variables X, Y, Z
# which are evaluated at each point in space. The expression returns a
# boolean value (true/false) indicating whether a point is inside the shape.
#
# Building expressions from scratch:
# 1. Start with the mathematical definition of the shape
# 2. Convert to an inequality or set of inequalities
# 3. Express in terms of X, Y, Z coordinates
# 4. Use string interpolation to substitute parameter values
# 5. Return the complete expression string

"""
    circle(cx, cy, r)

Create a circular region expression in XY plane.

Mathematical basis:
- A circle is defined as all points (x,y) where distance from center <= radius
- Distance formula: sqrt((x-cx)^2 + (y-cy)^2) <= r
- Squaring both sides: (x-cx)^2 + (y-cy)^2 <= r^2

Expression structure:
- (X-cx)^2 + (Y-cy)^2 calculates squared distance from center
- Compare to r^2 to determine if point is inside circle
- Only uses X and Y coordinates (Z is unconstrained)

Parameters:
- cx, cy: Center coordinates of the circle
- r: Radius of the circle

Returns: String expression evaluating to 1 (inside) or 0 (outside)
"""
function circle(cx::Float64, cy::Float64, r::Float64)::String
    # Build expression: distance squared from center must be <= radius squared
    return "(((X-($cx))*(X-($cx)) + (Y-($cy))*(Y-($cy))) <= ($r*$r))"
end

"""
    cylinder(cx, cy, z0, z1, r)

Create a cylindrical volume expression.

Mathematical basis:
- A cylinder extends a circle along the Z axis
- Point must be inside the circle in XY plane AND within Z bounds
- Circle condition: (x-cx)^2 + (y-cy)^2 <= r^2
- Z bounds: z0 <= Z <= z1

Expression structure:
- First part: Same as circle, checks XY distance from axis
- Second part: Z coordinate must be between z0 and z1
- Combined with AND operator (&) to require both conditions

Parameters:
- cx, cy: Center coordinates of the cylinder base
- z0, z1: Bottom and top Z coordinates
- r: Radius of the cylinder

Returns: String expression for cylindrical volume
"""
function cylinder(cx::Float64, cy::Float64, z0::Float64, z1::Float64, r::Float64)::String
    # Combine circle condition with Z bounds using AND
    return "(((X-($cx))*(X-($cx)) + (Y-($cy))*(Y-($cy)) <= ($r*$r)) & (Z >= ($z0)) & (Z <= ($z1)))"
end

"""
    sphere(cx, cy, cz, r)

Create a spherical volume expression.

Mathematical basis:
- A sphere is all points where 3D distance from center <= radius
- Distance formula: sqrt((x-cx)^2 + (y-cy)^2 + (z-cz)^2) <= r
- Squaring: (x-cx)^2 + (y-cy)^2 + (z-cz)^2 <= r^2

Expression structure:
- Calculate squared distance in all three dimensions
- Compare to radius squared
- All three coordinates (X, Y, Z) are constrained

Parameters:
- cx, cy, cz: Center coordinates of the sphere
- r: Radius of the sphere

Returns: String expression for spherical volume
"""
function sphere(cx::Float64, cy::Float64, cz::Float64, r::Float64)::String
    # Build 3D distance squared expression
    return "(((X-($cx))*(X-($cx)) + (Y-($cy))*(Y-($cy)) + (Z-($cz))*(Z-($cz))) <= ($r*$r))"
end

"""
    torus(cx, cy, cz, r0, r1)

Create a toroidal volume expression (donut shape).

Mathematical basis:
- A torus is a circle rotated around an axis
- Distance from center in XY plane: d = sqrt((x-cx)^2 + (y-cy)^2)
- Distance from the major radius circle: |d - r0|
- Combined with Z distance: (|d - r0|)^2 + (z-cz)^2 <= r1^2

Expression structure:
- Calculate distance from center in XY plane
- Find distance from major radius circle: r0 - d
- Square this distance and add Z distance squared
- Compare to minor radius squared (r1^2)

Parameters:
- cx, cy, cz: Center coordinates of the torus
- r0: Major radius (distance from center to tube center)
- r1: Minor radius (radius of the tube)

Returns: String expression for toroidal volume
"""
function torus(cx::Float64, cy::Float64, cz::Float64, r0::Float64, r1::Float64)::String
    # Calculate distance from major radius circle, then check if within minor radius
    return "((((($r0) - sqrt((X-($cx))*(X-($cx)) + (Y-($cy))*(Y-($cy)))))*(($r0) - sqrt((X-($cx))*(X-($cx)) + (Y-($cy))*(Y-($cy))))) + (Z-($cz))*(Z-($cz))) <= ($r1*$r1))"
end

"""
    rectangle(x0, x1, y0, y1)

Create a rectangular region expression in XY plane.

Mathematical basis:
- A rectangle is defined by bounds in X and Y directions
- Point is inside if: x0 <= x <= x1 AND y0 <= y <= y1

Expression structure:
- Four inequalities combined with AND operators
- X must be between x0 and x1
- Y must be between y0 and y1
- Z is unconstrained

Parameters:
- x0, x1: Minimum and maximum X coordinates
- y0, y1: Minimum and maximum Y coordinates

Returns: String expression for rectangular region
"""
function rectangle(x0::Float64, x1::Float64, y0::Float64, y1::Float64)::String
    # Combine four boundary conditions with AND
    return "((X >= ($x0)) & (X <= ($x1)) & (Y >= ($y0)) & (Y <= ($y1)))"
end

"""
    cube(x0, x1, y0, y1, z0, z1)

Create a cuboid (rectangular box) volume expression.

Mathematical basis:
- A cube is a rectangle extended into 3D
- Point must satisfy all six boundary conditions
- x0 <= x <= x1 AND y0 <= y <= y1 AND z0 <= z <= z1

Expression structure:
- Six inequalities (two per axis) combined with AND
- Each coordinate must be within its bounds
- All conditions must be true simultaneously

Parameters:
- x0, x1: Minimum and maximum X coordinates
- y0, y1: Minimum and maximum Y coordinates
- z0, z1: Minimum and maximum Z coordinates

Returns: String expression for cuboid volume
"""
function cube(x0::Float64, x1::Float64, y0::Float64, y1::Float64, z0::Float64, z1::Float64)::String
    # Combine six boundary conditions (two per axis) with AND
    return "((X >= ($x0)) & (X <= ($x1)) & (Y >= ($y0)) & (Y <= ($y1)) & (Z >= ($z0)) & (Z <= ($z1)))"
end

"""
    line(x0, y0, x1, y1, z, width)

Create a line segment expression with specified width.

Mathematical basis:
- A line segment is a rectangle along a line with finite width
- Project point onto line direction vector
- Check if projection is within segment length
- Check if perpendicular distance is within width/2

Expression structure:
1. Calculate direction vector: (dx, dy) = (x1-x0, y1-y0)
2. Normalize to unit vector: (nx, ny) = (dx, dy) / length
3. Calculate perpendicular vector: (rx, ry) = (-ny, nx)
4. Project point onto line: dot product with direction
5. Check projection is between 0 and length
6. Check perpendicular distance is within width/2
7. Constrain Z to be at line level (with small epsilon)

Parameters:
- x0, y0: Start point coordinates
- x1, y1: End point coordinates
- z: Z level of the line
- width: Width of the line segment

Returns: String expression for line segment volume
"""
function line(x0::Float64, y0::Float64, x1::Float64, y1::Float64, z::Float64, width::Float64)::String
    # Calculate line direction and length
    dx = x1 - x0
    dy = y1 - y0
    length = sqrt(dx*dx + dy*dy)
    
    # Handle degenerate case (zero length line becomes a circle)
    if length == 0
        return circle(x0, y0, width/2)
    end
    
    # Calculate unit direction vector (normalized)
    nx = dx / length
    ny = dy / length
    
    # Calculate perpendicular vector (rotated 90 degrees)
    rx = -ny
    ry = nx
    
    # Small epsilon for Z constraint (allows slight tolerance)
    epsilon = 1e-6
    
    # Build expression checking:
    # 1. Projection along line is between 0 and length
    # 2. Perpendicular distance is within width/2
    # 3. Z coordinate is at line level
    return "((((X-($x0))*($nx) + (Y-($y0))*($ny)) >= 0) & (((X-($x0))*($nx) + (Y-($y0))*($ny)) <= ($length)) & (((X-($x0))*($rx) + (Y-($y0))*($ry)) >= (-$width/2)) & (((X-($x0))*($rx) + (Y-($y0))*($ry)) <= ($width/2)) & (Z > ($z-$epsilon)) & (Z < ($z+$epsilon)))"
end

"""
    right_triangle(x0, y0, l)

Create a right triangular region (45-45-90 triangle).

Mathematical basis:
- Right triangle with legs along X and Y axes
- Hypotenuse forms a line from (x0+l, y0) to (x0, y0+l)
- Point is inside if: x >= x0 AND y >= y0 AND x <= x0 + l - (y-y0)

Expression structure:
- Check X and Y are above bottom-left corner
- Check point is below the diagonal line
- The diagonal constraint: X <= x0 + l - (Y-y0)

Parameters:
- x0, y0: Bottom-left corner coordinates
- l: Length of the legs (triangle extends l units in both X and Y)

Returns: String expression for right triangular region
"""
function right_triangle(x0::Float64, y0::Float64, l::Float64)::String
    # Triangle bounded by: X >= x0, Y >= y0, and diagonal line
    return "((X >= $x0) & (X <= $x0 + $l - (Y-$y0)) & (Y >= $y0))"
end

"""
    triangle(x0, y0, x1, y1, x2, y2)

Create a triangular region from three points (clockwise order).

Mathematical basis:
- Triangle defined by three vertices
- Use cross product to determine which side of each edge a point is on
- For clockwise vertices, point is inside if on right side of all edges
- Cross product sign indicates which side: (y1-y0)*(x-x0) - (x1-x0)*(y-y0)

Expression structure:
- For each edge, calculate cross product
- Check that cross product is >= 0 (point is to the right of edge)
- All three edges must satisfy this condition
- Edge 1: (x0,y0) to (x1,y1)
- Edge 2: (x1,y1) to (x2,y2)
- Edge 3: (x2,y2) to (x0,y0)

Parameters:
- x0, y0: First vertex coordinates
- x1, y1: Second vertex coordinates
- x2, y2: Third vertex coordinates
- Vertices must be in clockwise order

Returns: String expression for triangular region
"""
function triangle(x0::Float64, y0::Float64, x1::Float64, y1::Float64, x2::Float64, y2::Float64)::String
    # Check point is to the right of all three edges using cross products
    return "((((($y1)-($y0))*(X-($x0))-(($x1)-($x0))*(Y-($y0))) >= 0) & (((($y2)-($y1))*(X-($x1))-(($x2)-($x1))*(Y-($y1))) >= 0) & (((($y0)-($y2))*(X-($x2))-(($x0)-($x2))*(Y-($y2))) >= 0))"
end

"""
    cone(cx, cy, z0, z1, r0)

Create a conical volume (requires taper transformation).

Mathematical basis:
- A cone is a cylinder that tapers from base radius to zero
- Base implementation starts as a cylinder
- Taper transformation scales radius based on Z position
- At z0: radius = r0, at z1: radius = 0

Expression structure:
- Currently returns a cylinder (base shape)
- Will be modified by taper transformation function
- Taper function adjusts radius based on Z coordinate

Parameters:
- cx, cy: Center coordinates of the cone base
- z0, z1: Bottom and top Z coordinates
- r0: Base radius (at z0)

Returns: String expression for conical volume (requires taper to complete)
"""
function cone(cx::Float64, cy::Float64, z0::Float64, z1::Float64, r0::Float64)::String
    # Start with cylinder - taper transformation will modify radius based on Z
    return cylinder(cx, cy, z0, z1, r0)
end

"""
    pyramid(x0, x1, y0, y1, z0, z1)

Create a pyramidal volume (requires taper transformation).

Mathematical basis:
- A pyramid is a cube that tapers from full size to a point
- Base implementation starts as a cube
- Taper transformation scales X and Y dimensions based on Z position
- At z0: full size, at z1: zero size (point)

Expression structure:
- Currently returns a cube (base shape)
- Will be modified by taper transformation function
- Taper function adjusts X and Y bounds based on Z coordinate

Parameters:
- x0, x1: Base X bounds (at z0)
- y0, y1: Base Y bounds (at z0)
- z0, z1: Bottom and top Z coordinates

Returns: String expression for pyramidal volume (requires taper to complete)
"""
function pyramid(x0::Float64, x1::Float64, y0::Float64, y1::Float64, z0::Float64, z1::Float64)::String
    # Start with cube - taper transformation will modify X/Y bounds based on Z
    return cube(x0, x1, y0, y1, z0, z1)
end

############################################################
# boolean operations
############################################################

# Boolean operations combine shape expressions using set theory operations.
# These are fundamental for building complex shapes from simple primitives.
#
# Building boolean operations from scratch:
# 1. Understand set theory: union (OR), intersection (AND), difference (subtract)
# 2. Convert to logical operators: | (OR), & (AND), ~ (NOT)
# 3. Combine expressions by wrapping in parentheses for proper precedence
# 4. Return new expression string that can be evaluated
#
# Mathematical basis:
# - Union (A ∪ B): Point is in result if it's in A OR B
# - Intersection (A ∩ B): Point is in result if it's in A AND B
# - Difference (A - B): Point is in result if it's in A AND NOT in B

"""
    union(expr1, expr2)

Create a union (OR) operation combining two expressions.

Mathematical basis:
- Union represents all points that are in either shape
- Set theory: A ∪ B = {x | x ∈ A OR x ∈ B}
- Logical equivalent: result = expr1 OR expr2

Expression structure:
- Use logical OR operator (|) to combine expressions
- Wrap each expression in parentheses for safety
- Result: (expr1) | (expr2)
- When evaluated: returns 1 if point is in expr1 OR expr2

Building from scratch:
1. Take two expression strings
2. Wrap each in parentheses to ensure proper evaluation
3. Combine with OR operator (|)
4. Return combined expression

Parameters:
- expr1: First shape expression string
- expr2: Second shape expression string

Returns: Combined expression string representing union
"""
function union(expr1::String, expr2::String)::String
    # Combine expressions with OR operator
    # Parentheses ensure each expression is evaluated independently
    return "(($expr1) | ($expr2))"
end

"""
    difference(expr1, expr2)

Create a difference (subtract) operation removing expr2 from expr1.

Mathematical basis:
- Difference represents points in first shape but not in second
- Set theory: A - B = {x | x ∈ A AND x ∉ B}
- Logical equivalent: result = expr1 AND NOT expr2

Expression structure:
- Use logical AND with negation: expr1 & ~expr2
- Wrap each expression in parentheses
- Result: (expr1) & ~(expr2)
- When evaluated: returns 1 if point is in expr1 AND NOT in expr2

Building from scratch:
1. Take two expression strings (base and subtractor)
2. Wrap base expression in parentheses
3. Negate second expression with ~ operator
4. Combine with AND operator (&)
5. Return combined expression

Parameters:
- expr1: Base shape expression (what to keep)
- expr2: Shape to subtract (what to remove)

Returns: Combined expression string representing difference
"""
function difference(expr1::String, expr2::String)::String
    # Subtract expr2 from expr1 using AND with negation
    # ~expr2 means "NOT in expr2"
    # Combined: in expr1 AND NOT in expr2
    return "(($expr1) & ~($expr2))"
end

"""
    intersect(expr1, expr2)

Create an intersection (AND) operation finding common region.

Mathematical basis:
- Intersection represents points that are in both shapes
- Set theory: A ∩ B = {x | x ∈ A AND x ∈ B}
- Logical equivalent: result = expr1 AND expr2

Expression structure:
- Use logical AND operator (&) to combine expressions
- Wrap each expression in parentheses
- Result: (expr1) & (expr2)
- When evaluated: returns 1 only if point is in BOTH expr1 AND expr2

Building from scratch:
1. Take two expression strings
2. Wrap each in parentheses
3. Combine with AND operator (&)
4. Return combined expression

Parameters:
- expr1: First shape expression string
- expr2: Second shape expression string

Returns: Combined expression string representing intersection
"""
function intersect(expr1::String, expr2::String)::String
    # Combine expressions with AND operator
    # Both conditions must be true for point to be inside
    return "(($expr1) & ($expr2))"
end

"""
    color(color_value, expr)

Apply color to a functional representation expression.

Mathematical basis:
- Expression evaluates to boolean (0 or 1)
- Multiply by color value to get colored result
- Format: (color * ((expr) != 0))
- When expr is true (1), result is color value
- When expr is false (0), result is 0 (black)

Color format:
- Colors are packed as 32-bit integers: (R << 16) | (G << 8) | B
- Red: bits 16-23
- Green: bits 8-15
- Blue: bits 0-7

Parameters:
- color_value: Integer color value (e.g., COLOR_WHITE, COLOR_TAN)
- expr: String expression to colorize

Returns: String expression with color applied
"""
function color(color_value, expr::String)::String
    # Apply color: multiply color value by boolean result
    # Format matches Python: (color * ((expr) != 0))
    # Accept both Int64 and UInt32 color values
    return "($(color_value) * ((($expr)) != 0))"
end

############################################################
# transformations
############################################################

"""
    move(expr, dx, dy)

Translate a 2D functional representation expression by (dx, dy).

Mathematical basis:
- Translation in 2D: To move a shape by (dx, dy), we evaluate the shape
  at coordinates (X-dx, Y-dy) instead of (X, Y).
- This is achieved by replacing X with (X-dx) and Y with (Y-dy) in the expression.
- The shape's definition remains the same, but it's evaluated at translated coordinates.

Building from scratch:
1. The input expression uses variables X and Y.
2. To translate by (dx, dy), we need to "undo" the translation by evaluating
   the original shape at (X-dx, Y-dy).
3. Replace all occurrences of X with (X-dx) and Y with (Y-dy).

Parameters:
- expr: String expression to translate
- dx: Translation distance in X direction
- dy: Translation distance in Y direction

Returns: Translated string expression
"""
function move(expr::String, dx::Float64, dy::Float64)::String
    result = replace(expr, "X" => "(X-($(dx)))")
    result = replace(result, "Y" => "(Y-($(dy)))")
    return result
end

"""
    translate(expr, dx, dy, dz)

Translate a 3D functional representation expression by (dx, dy, dz).

Mathematical basis:
- Same as move(), but includes Z-axis translation.
- Replaces X with (X-dx), Y with (Y-dy), and Z with (Z-dz).

Parameters:
- expr: String expression to translate
- dx: Translation distance in X direction
- dy: Translation distance in Y direction
- dz: Translation distance in Z direction

Returns: Translated string expression
"""
function translate(expr::String, dx::Float64, dy::Float64, dz::Float64)::String
    result = replace(expr, "X" => "(X-($(dx)))")
    result = replace(result, "Y" => "(Y-($(dy)))")
    result = replace(result, "Z" => "(Z-($(dz)))")
    return result
end

"""
    rotate(expr, angle)

Rotate a 2D functional representation expression around the origin by angle degrees.

Mathematical basis:
- Rotation in 2D: To rotate a point (x, y) by angle θ:
  x' = x*cos(θ) + y*sin(θ)
  y' = -x*sin(θ) + y*cos(θ)
- To rotate a shape, we apply the inverse rotation to the coordinates:
  Evaluate the original shape at rotated coordinates.
- We replace X with (cos(θ)*X + sin(θ)*Y) and Y with (-sin(θ)*X + cos(θ)*Y).

Building from scratch:
1. Convert angle from degrees to radians: θ = angle * π/180
2. Apply rotation matrix to coordinates:
   - X_new = cos(θ)*X + sin(θ)*Y
   - Y_new = -sin(θ)*X + cos(θ)*Y
3. Replace X and Y in the expression with these rotated coordinates.
4. Use temporary variable 'y' to avoid conflicts during replacement.

Parameters:
- expr: String expression to rotate
- angle: Rotation angle in degrees (counterclockwise)

Returns: Rotated string expression
"""
function rotate(expr::String, angle::Float64)::String
    angle_rad = angle * π / 180.0
    # First replace X with rotated X (using temporary 'y' for Y)
    result = replace(expr, "X" => "(cos($(angle_rad))*X+sin($(angle_rad))*y)")
    # Then replace Y with rotated Y
    result = replace(result, "Y" => "(-sin($(angle_rad))*X+cos($(angle_rad))*y)")
    # Finally replace temporary 'y' with actual Y
    result = replace(result, "y" => "Y")
    return result
end

"""
    rotate_x(expr, angle)

Rotate a 3D functional representation expression around the X-axis by angle degrees.

Mathematical basis:
- Rotation around X-axis: Only Y and Z coordinates change.
- Y' = Y*cos(θ) + Z*sin(θ)
- Z' = -Y*sin(θ) + Z*cos(θ)
- X remains unchanged.

Parameters:
- expr: String expression to rotate
- angle: Rotation angle in degrees

Returns: Rotated string expression
"""
function rotate_x(expr::String, angle::Float64)::String
    angle_rad = angle * π / 180.0
    result = replace(expr, "Y" => "(cos($(angle_rad))*Y+sin($(angle_rad))*z)")
    result = replace(result, "Z" => "(-sin($(angle_rad))*Y+cos($(angle_rad))*z)")
    result = replace(result, "z" => "Z")
    return result
end

"""
    rotate_y(expr, angle)

Rotate a 3D functional representation expression around the Y-axis by angle degrees.

Mathematical basis:
- Rotation around Y-axis: Only X and Z coordinates change.
- X' = X*cos(θ) + Z*sin(θ)
- Z' = -X*sin(θ) + Z*cos(θ)
- Y remains unchanged.

Parameters:
- expr: String expression to rotate
- angle: Rotation angle in degrees

Returns: Rotated string expression
"""
function rotate_y(expr::String, angle::Float64)::String
    angle_rad = angle * π / 180.0
    result = replace(expr, "X" => "(cos($(angle_rad))*X+sin($(angle_rad))*z)")
    result = replace(result, "Z" => "(-sin($(angle_rad))*X+cos($(angle_rad))*z)")
    result = replace(result, "z" => "Z")
    return result
end

"""
    rotate_z(expr, angle)

Rotate a 3D functional representation expression around the Z-axis by angle degrees.

Mathematical basis:
- Rotation around Z-axis: Only X and Y coordinates change (same as 2D rotation).
- X' = X*cos(θ) + Y*sin(θ)
- Y' = -X*sin(θ) + Y*cos(θ)
- Z remains unchanged.

Parameters:
- expr: String expression to rotate
- angle: Rotation angle in degrees

Returns: Rotated string expression
"""
function rotate_z(expr::String, angle::Float64)::String
    angle_rad = angle * π / 180.0
    result = replace(expr, "X" => "(cos($(angle_rad))*X+sin($(angle_rad))*y)")
    result = replace(result, "Y" => "(-sin($(angle_rad))*X+cos($(angle_rad))*y)")
    result = replace(result, "y" => "Y")
    return result
end

"""
    rotate_90(expr)

Rotate a 2D functional representation expression by 90 degrees counterclockwise.

Mathematical basis:
- 90° rotation: (x, y) → (-y, x)
- This can be achieved by reflecting Y across 0, then swapping X and Y.

Parameters:
- expr: String expression to rotate

Returns: Rotated string expression
"""
function rotate_90(expr::String)::String
    result = reflect_y(expr, 0.0)
    result = reflect_xy(result)
    return result
end

"""
    rotate_180(expr)

Rotate a 2D functional representation expression by 180 degrees.

Mathematical basis:
- 180° rotation: (x, y) → (-x, -y)
- Can be achieved by two 90° rotations.

Parameters:
- expr: String expression to rotate

Returns: Rotated string expression
"""
function rotate_180(expr::String)::String
    result = rotate_90(expr)
    result = rotate_90(result)
    return result
end

"""
    rotate_270(expr)

Rotate a 2D functional representation expression by 270 degrees counterclockwise
(equivalent to 90 degrees clockwise).

Mathematical basis:
- 270° rotation: (x, y) → (y, -x)
- Can be achieved by three 90° rotations.

Parameters:
- expr: String expression to rotate

Returns: Rotated string expression
"""
function rotate_270(expr::String)::String
    result = rotate_90(expr)
    result = rotate_90(result)
    result = rotate_90(result)
    return result
end

"""
    reflect_x(expr, x0)

Reflect a functional representation expression across the line X = x0.

Mathematical basis:
- Reflection: A point at distance d from the mirror is reflected to distance -d.
- If mirror is at x0, point at x is reflected to 2*x0 - x.
- We replace X with (x0 - X) to achieve this (note: (x0 - X) = -(X - x0),
  which when evaluated at the original X gives the reflected coordinate).

Building from scratch:
1. To reflect across X = x0, we need: X_reflected = 2*x0 - X
2. However, in functional representation, we evaluate the original shape
   at the reflected coordinates.
3. So we replace X with (x0 - X), which when the evaluator uses the original
   X coordinate, effectively evaluates at the reflected position.

Parameters:
- expr: String expression to reflect
- x0: X coordinate of the reflection line

Returns: Reflected string expression
"""
function reflect_x(expr::String, x0::Float64)::String
    result = replace(expr, "X" => "(($(x0))-X)")
    return result
end

"""
    reflect_y(expr, y0)

Reflect a functional representation expression across the line Y = y0.

Mathematical basis:
- Same as reflect_x(), but for Y-axis.
- Replace Y with (y0 - Y).

Parameters:
- expr: String expression to reflect
- y0: Y coordinate of the reflection line

Returns: Reflected string expression
"""
function reflect_y(expr::String, y0::Float64)::String
    result = replace(expr, "Y" => "(($(y0))-Y)")
    return result
end

"""
    reflect_z(expr, z0)

Reflect a functional representation expression across the plane Z = z0.

Mathematical basis:
- Same as reflect_x(), but for Z-axis.
- Replace Z with (z0 - Z).

Parameters:
- expr: String expression to reflect
- z0: Z coordinate of the reflection plane

Returns: Reflected string expression
"""
function reflect_z(expr::String, z0::Float64)::String
    result = replace(expr, "Z" => "(($(z0))-Z)")
    return result
end

"""
    reflect_xy(expr)

Swap X and Y coordinates (reflect across the line Y = X).

Mathematical basis:
- Reflection across Y = X swaps coordinates: (x, y) → (y, x)
- Achieved by swapping X and Y in the expression using a temporary variable.

Building from scratch:
1. Use temporary variable to hold one coordinate.
2. Replace X with temp, Y with X, then temp with Y.
3. This effectively swaps X and Y.

Parameters:
- expr: String expression to reflect

Returns: Reflected string expression
"""
function reflect_xy(expr::String)::String
    result = replace(expr, "X" => "temp")
    result = replace(result, "Y" => "X")
    result = replace(result, "temp" => "Y")
    return result
end

"""
    reflect_xz(expr)

Swap X and Z coordinates (reflect across the plane X = Z).

Mathematical basis:
- Same as reflect_xy(), but swaps X and Z.

Parameters:
- expr: String expression to reflect

Returns: Reflected string expression
"""
function reflect_xz(expr::String)::String
    result = replace(expr, "X" => "temp")
    result = replace(result, "Z" => "X")
    result = replace(result, "temp" => "Z")
    return result
end

"""
    reflect_yz(expr)

Swap Y and Z coordinates (reflect across the plane Y = Z).

Mathematical basis:
- Same as reflect_xy(), but swaps Y and Z.

Parameters:
- expr: String expression to reflect

Returns: Reflected string expression
"""
function reflect_yz(expr::String)::String
    result = replace(expr, "Y" => "temp")
    result = replace(result, "Z" => "Y")
    result = replace(result, "temp" => "Z")
    return result
end

"""
    scale_x(expr, x0, sx)

Scale a functional representation expression along the X-axis.

Mathematical basis:
- Scaling: To scale by factor s around point x0, we transform coordinates:
  X_scaled = x0 + (X - x0) / s
- When s > 1, the shape appears larger (coordinates are "compressed").
- When s < 1, the shape appears smaller (coordinates are "expanded").
- The division by s in the expression means we evaluate the original shape
  at compressed/expanded coordinates.

Building from scratch:
1. To scale around point x0 by factor sx:
   - Distance from x0: d = X - x0
   - Scaled distance: d' = d / sx
   - Scaled coordinate: X' = x0 + d' = x0 + (X - x0) / sx
2. Replace X with this scaled coordinate expression.

Parameters:
- expr: String expression to scale
- x0: Center point of scaling (pivot point)
- sx: Scale factor (sx > 1 makes larger, sx < 1 makes smaller)

Returns: Scaled string expression
"""
function scale_x(expr::String, x0::Float64, sx::Float64)::String
    result = replace(expr, "X" => "((($(x0))) + (X-(($(x0))))/($(sx)))")
    return result
end

"""
    scale_y(expr, y0, sy)

Scale a functional representation expression along the Y-axis.

Mathematical basis:
- Same as scale_x(), but for Y-axis.
- Replace Y with (y0 + (Y - y0) / sy).

Parameters:
- expr: String expression to scale
- y0: Center point of scaling
- sy: Scale factor

Returns: Scaled string expression
"""
function scale_y(expr::String, y0::Float64, sy::Float64)::String
    result = replace(expr, "Y" => "((($(y0))) + (Y-(($(y0))))/($(sy)))")
    return result
end

"""
    scale_z(expr, z0, sz)

Scale a functional representation expression along the Z-axis.

Mathematical basis:
- Same as scale_x(), but for Z-axis.
- Replace Z with (z0 + (Z - z0) / sz).

Parameters:
- expr: String expression to scale
- z0: Center point of scaling
- sz: Scale factor

Returns: Scaled string expression
"""
function scale_z(expr::String, z0::Float64, sz::Float64)::String
    result = replace(expr, "Z" => "((($(z0))) + (Z-(($(z0))))/($(sz)))")
    return result
end

"""
    scale_xy(expr, x0, y0, sxy)

Scale a functional representation expression uniformly in X and Y directions.

Mathematical basis:
- Uniform 2D scaling: Apply same scale factor to both X and Y.
- Replace X with (x0 + (X - x0) / sxy) and Y with (y0 + (Y - y0) / sxy).

Parameters:
- expr: String expression to scale
- x0: X center point of scaling
- y0: Y center point of scaling
- sxy: Scale factor for both X and Y

Returns: Scaled string expression
"""
function scale_xy(expr::String, x0::Float64, y0::Float64, sxy::Float64)::String
    result = replace(expr, "X" => "((($(x0))) + (X-(($(x0))))/($(sxy)))")
    result = replace(result, "Y" => "((($(y0))) + (Y-(($(y0))))/($(sxy)))")
    return result
end

"""
    scale_xyz(expr, x0, y0, z0, sxyz)

Scale a functional representation expression uniformly in all three directions.

Mathematical basis:
- Uniform 3D scaling: Apply same scale factor to X, Y, and Z.
- Replace X, Y, Z with scaled coordinates.

Parameters:
- expr: String expression to scale
- x0: X center point of scaling
- y0: Y center point of scaling
- z0: Z center point of scaling
- sxyz: Scale factor for all axes

Returns: Scaled string expression
"""
function scale_xyz(expr::String, x0::Float64, y0::Float64, z0::Float64, sxyz::Float64)::String
    result = replace(expr, "X" => "((($(x0))) + (X-(($(x0))))/($(sxyz)))")
    result = replace(result, "Y" => "((($(y0))) + (Y-(($(y0))))/($(sxyz)))")
    result = replace(result, "Z" => "((($(z0))) + (Z-(($(z0))))/($(sxyz)))")
    return result
end

"""
    coscale_x_y(expr, x0, y0, y1, angle0, angle1, amplitude, offset)

Apply cosine-based scaling to X-axis that varies with Y position.

Mathematical basis:
- Creates a wavy/undulating scaling effect along X-axis.
- Scale factor varies as: offset + amplitude * cos(phase)
- Phase varies linearly from angle0 to angle1 as Y goes from y0 to y1.
- This creates patterns like corrugated surfaces or waves.

Building from scratch:
1. Convert angle0 and angle1 from degrees to radians (phase0, phase1).
2. Calculate phase at current Y: phase = phase0 + (phase1 - phase0) * (Y - y0) / (y1 - y0)
3. Calculate scale factor: s = offset + amplitude * cos(phase)
4. Apply scaling: X' = x0 + (X - x0) / s

Parameters:
- expr: String expression to transform
- x0: X center point of scaling
- y0: Y start position
- y1: Y end position
- angle0: Starting phase angle in degrees
- angle1: Ending phase angle in degrees
- amplitude: Amplitude of cosine variation
- offset: Base offset for scale factor

Returns: Transformed string expression
"""
function coscale_x_y(expr::String, x0::Float64, y0::Float64, y1::Float64,
                     angle0::Float64, angle1::Float64, amplitude::Float64, offset::Float64)::String
    phase0 = angle0 * π / 180.0
    phase1 = angle1 * π / 180.0
    scale_expr = "((($(x0))) + (X-(($(x0))))/((($(offset))) + (($(amplitude)))*cos((($(phase0))) + ((($(phase1)))-(($(phase0))))*(Y-(($(y0))))/((($(y1)))-(($(y0)))))))"
    result = replace(expr, "X" => scale_expr)
    return result
end

"""
    coscale_x_z(expr, x0, z0, z1, angle0, angle1, amplitude, offset)

Apply cosine-based scaling to X-axis that varies with Z position.

Mathematical basis:
- Same as coscale_x_y(), but phase varies with Z instead of Y.

Parameters:
- expr: String expression to transform
- x0: X center point of scaling
- z0: Z start position
- z1: Z end position
- angle0: Starting phase angle in degrees
- angle1: Ending phase angle in degrees
- amplitude: Amplitude of cosine variation
- offset: Base offset for scale factor

Returns: Transformed string expression
"""
function coscale_x_z(expr::String, x0::Float64, z0::Float64, z1::Float64,
                     angle0::Float64, angle1::Float64, amplitude::Float64, offset::Float64)::String
    phase0 = angle0 * π / 180.0
    phase1 = angle1 * π / 180.0
    scale_expr = "((($(x0))) + (X-(($(x0))))/((($(offset))) + (($(amplitude)))*cos((($(phase0))) + ((($(phase1)))-(($(phase0))))*(Z-(($(z0))))/((($(z1)))-(($(z0)))))))"
    result = replace(expr, "X" => scale_expr)
    return result
end

"""
    coscale_xy_z(expr, x0, y0, z0, z1, angle0, angle1, amplitude, offset)

Apply cosine-based scaling to both X and Y axes that varies with Z position.

Mathematical basis:
- Same as coscale_x_z(), but applies to both X and Y uniformly.
- Creates 3D wavy/undulating effects.

Parameters:
- expr: String expression to transform
- x0: X center point of scaling
- y0: Y center point of scaling
- z0: Z start position
- z1: Z end position
- angle0: Starting phase angle in degrees
- angle1: Ending phase angle in degrees
- amplitude: Amplitude of cosine variation
- offset: Base offset for scale factor

Returns: Transformed string expression
"""
function coscale_xy_z(expr::String, x0::Float64, y0::Float64, z0::Float64, z1::Float64,
                      angle0::Float64, angle1::Float64, amplitude::Float64, offset::Float64)::String
    phase0 = angle0 * π / 180.0
    phase1 = angle1 * π / 180.0
    scale_expr = "((($(x0))) + (X-(($(x0))))/((($(offset))) + (($(amplitude)))*cos((($(phase0))) + ((($(phase1)))-(($(phase0))))*(Z-(($(z0))))/((($(z1)))-(($(z0)))))))"
    result = replace(expr, "X" => scale_expr)
    scale_expr_y = "((($(y0))) + (Y-(($(y0))))/((($(offset))) + (($(amplitude)))*cos((($(phase0))) + ((($(phase1)))-(($(phase0))))*(Z-(($(z0))))/((($(z1)))-(($(z0)))))))"
    result = replace(result, "Y" => scale_expr_y)
    return result
end

"""
    taper_x_y(expr, x0, y0, y1, s0, s1)

Apply tapering (linear scaling variation) to X-axis that varies with Y position.

Mathematical basis:
- Tapering: Scale factor varies linearly from s0 at y0 to s1 at y1.
- Creates shapes that get wider or narrower along one axis.
- Scale factor at Y: s = s1*(Y-y0) + s0*(y1-Y) / (y1-y0)
- This is a linear interpolation: s = s0 when Y = y0, s = s1 when Y = y1.

Building from scratch:
1. Linear interpolation of scale factor:
   s = (s1*(Y-y0) + s0*(y1-Y)) / (y1-y0)
2. Apply scaling: X' = x0 + (X-x0) * (y1-y0) / (s*(Y-y0) + s0*(y1-Y))
3. Simplifying: X' = x0 + (X-x0) * (y1-y0) / (s1*(Y-y0) + s0*(y1-Y))

Parameters:
- expr: String expression to transform
- x0: X center point of tapering
- y0: Y start position
- y1: Y end position
- s0: Scale factor at y0
- s1: Scale factor at y1

Returns: Transformed string expression
"""
function taper_x_y(expr::String, x0::Float64, y0::Float64, y1::Float64,
                   s0::Float64, s1::Float64)::String
    taper_expr = "((($(x0))) + (X-(($(x0))))*((($(y1)))-(($(y0))))/((($(s1)))*(Y-(($(y0)))) + (($(s0)))*((($(y1)))-Y)))"
    result = replace(expr, "X" => taper_expr)
    return result
end

"""
    taper_x_z(expr, x0, z0, z1, s0, s1)

Apply tapering to X-axis that varies with Z position.

Mathematical basis:
- Same as taper_x_y(), but phase varies with Z instead of Y.

Parameters:
- expr: String expression to transform
- x0: X center point of tapering
- z0: Z start position
- z1: Z end position
- s0: Scale factor at z0
- s1: Scale factor at z1

Returns: Transformed string expression
"""
function taper_x_z(expr::String, x0::Float64, z0::Float64, z1::Float64,
                   s0::Float64, s1::Float64)::String
    taper_expr = "((($(x0))) + (X-(($(x0))))*((($(z1)))-(($(z0))))/((($(s1)))*(Z-(($(z0)))) + (($(s0)))*((($(z1)))-Z)))"
    result = replace(expr, "X" => taper_expr)
    return result
end

"""
    taper_xy_z(expr, x0, y0, z0, z1, s0, s1)

Apply tapering to both X and Y axes that varies with Z position.

Mathematical basis:
- Same as taper_x_z(), but applies to both X and Y uniformly.
- Creates 3D tapered shapes (like pyramids or cones).

Parameters:
- expr: String expression to transform
- x0: X center point of tapering
- y0: Y center point of tapering
- z0: Z start position
- z1: Z end position
- s0: Scale factor at z0
- s1: Scale factor at z1

Returns: Transformed string expression
"""
function taper_xy_z(expr::String, x0::Float64, y0::Float64, z0::Float64, z1::Float64,
                    s0::Float64, s1::Float64)::String
    taper_expr = "((($(x0))) + (X-(($(x0))))*((($(z1)))-(($(z0))))/((($(s1)))*(Z-(($(z0)))) + (($(s0)))*((($(z1)))-Z)))"
    result = replace(expr, "X" => taper_expr)
    taper_expr_y = "((($(y0))) + (Y-(($(y0))))*((($(z1)))-(($(z0))))/((($(s1)))*(Z-(($(z0)))) + (($(s0)))*((($(z1)))-Z)))"
    result = replace(result, "Y" => taper_expr_y)
    return result
end

"""
    shear_x_y(expr, y0, y1, dx0, dx1)

Apply shearing (skewing) to X-axis that varies with Y position.

Mathematical basis:
- Shearing: Shift X coordinate by an amount that varies with Y.
- Creates parallelogram-like distortions.
- X shift varies linearly from dx0 at y0 to dx1 at y1.
- X' = X - dx0 - (dx1-dx0)*(Y-y0)/(y1-y0)

Building from scratch:
1. Calculate X shift at current Y using linear interpolation:
   dx = dx0 + (dx1-dx0)*(Y-y0)/(y1-y0)
2. Apply shift: X' = X - dx
3. Simplifying: X' = X - dx0 - (dx1-dx0)*(Y-y0)/(y1-y0)

Parameters:
- expr: String expression to transform
- y0: Y start position
- y1: Y end position
- dx0: X shift at y0
- dx1: X shift at y1

Returns: Transformed string expression
"""
function shear_x_y(expr::String, y0::Float64, y1::Float64, dx0::Float64, dx1::Float64)::String
    shear_expr = "(X - (($(dx0))) - ((($(dx1)))-(($(dx0))))*(Y-(($(y0))))/((($(y1)))-(($(y0)))))"
    result = replace(expr, "X" => shear_expr)
    return result
end

"""
    shear_x_z(expr, z0, z1, dx0, dx1)

Apply shearing to X-axis that varies with Z position.

Mathematical basis:
- Same as shear_x_y(), but shift varies with Z instead of Y.

Parameters:
- expr: String expression to transform
- z0: Z start position
- z1: Z end position
- dx0: X shift at z0
- dx1: X shift at z1

Returns: Transformed string expression
"""
function shear_x_z(expr::String, z0::Float64, z1::Float64, dx0::Float64, dx1::Float64)::String
    shear_expr = "(X - (($(dx0))) - ((($(dx1)))-(($(dx0))))*(Z-(($(z0))))/((($(z1)))-(($(z0)))))"
    result = replace(expr, "X" => shear_expr)
    return result
end

"""
    coshear_x_z(expr, z0, z1, angle0, angle1, amplitude, offset)

Apply cosine-based shearing to X-axis that varies with Z position.

Mathematical basis:
- Similar to coscale, but applies shearing (translation) instead of scaling.
- X shift varies as: offset + amplitude * cos(phase)
- Phase varies linearly from angle0 to angle1 as Z goes from z0 to z1.
- Creates wavy/undulating shearing effects.

Parameters:
- expr: String expression to transform
- z0: Z start position
- z1: Z end position
- angle0: Starting phase angle in degrees
- angle1: Ending phase angle in degrees
- amplitude: Amplitude of cosine variation
- offset: Base offset for shift

Returns: Transformed string expression
"""
function coshear_x_z(expr::String, z0::Float64, z1::Float64,
                     angle0::Float64, angle1::Float64, amplitude::Float64, offset::Float64)::String
    phase0 = angle0 * π / 180.0
    phase1 = angle1 * π / 180.0
    shear_expr = "(X - (($(offset))) - (($(amplitude)))*cos((($(phase0))) + ((($(phase1)))-(($(phase0))))*(Z-(($(z0))))/((($(z1)))-(($(z0))))))"
    result = replace(expr, "X" => shear_expr)
    return result
end

############################################################
# text rendering
############################################################

"""
    TextRenderer

A struct that creates text as functional representation shapes.

Mathematical basis:
- Text rendering converts characters into geometric shapes
- Each character is defined as a combination of basic primitives (circles, rectangles, triangles)
- Characters are positioned sequentially to form words and lines
- Alignment, rotation, and positioning are applied as transformations

Building from scratch:
1. Character definition: Each character (A-Z, a-z, 0-9, symbols) is built from primitives
2. Character positioning: Characters are placed horizontally with spacing
3. Line handling: Newlines create vertical spacing between lines
4. Alignment: Text can be aligned left/center/right horizontally, top/center/bottom vertically
5. Transformation: Apply rotation and translation to position text
6. Color application: Apply color to the final text shape

Usage:
    renderer = TextRenderer("Hello", 0.0, 0.0, 0.0)
    text_shape = renderer.shape
"""
mutable struct TextRenderer
    text::String
    x::Float64
    y::Float64
    z::Float64
    line::Float64
    height::Float64
    width::Float64
    space::Float64
    align::String
    color_value::UInt32
    angle::Float64
    shape::String
    
    function TextRenderer(text::String, x::Float64, y::Float64, z::Float64=0.0;
                         line::Float64=1.0, height::Float64=0.0, width::Float64=0.0,
                         space::Float64=0.0, align::String="CC", color_value::UInt32=COLOR_WHITE,
                         angle::Float64=0.0)
        # Set defaults
        if height == 0.0
            height = 6.0 * line
        end
        if width == 0.0
            width = 4.0 * line
        end
        if space == 0.0
            space = line / 2.0
        end
        
        # Create instance
        renderer = new(text, x, y, z, line, height, width, space, align, color_value, angle, "")
        
        # Build character shapes dictionary
        shapes = build_character_shapes(width, height, line)
        
        # Process text into shape
        renderer.shape = process_text(renderer, shapes)
        
        return renderer
    end
end

"""
    build_character_shapes(width, height, line)

Build a dictionary of character shapes for text rendering.

Mathematical basis:
- Each character is constructed from basic primitives
- Characters are designed to fit within a bounding box (width x height)
- Line thickness determines stroke width for characters
- Characters use circles, rectangles, and triangles to form letter shapes

Building from scratch:
1. Define character dimensions: width and height define character cell size
2. Build each character: Use primitives to create recognizable letter shapes
3. Store in dictionary: Map character to its shape expression
4. Handle special cases: Space character returns FALSE_EXPR (empty)

This function creates shapes for:
- Uppercase letters (A-Z)
- Lowercase letters (a-z)  
- Digits (0-9)
- Common symbols (space, +, -, ., /, etc.)

Parameters:
- width: Character cell width
- height: Character cell height
- line: Line/stroke thickness

Returns: Dictionary mapping characters to shape expressions
"""
function build_character_shapes(width::Float64, height::Float64, line::Float64)::Dict{Char, String}
    shapes = Dict{Char, String}()
    
    # A
    shape = triangle(0.0, 0.0, width/2.0, height, width, 0.0)
    cutout = triangle(0.0, -2.5*line, width/2.0, height-2.5*line, width, -2.5*line)
    cutout = difference(cutout, rectangle(0.0, width, height/4-line/2, height/4+line/2))
    shape = difference(shape, cutout)
    shapes['A'] = shape
    
    # a
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/4))
    shape = union(shape, rectangle(width-line, width, 0.0, height/3))
    shapes['a'] = shape
    
    # B
    shape = rectangle(0.0, width-height/4, 0.0, height)
    shape = union(shape, circle(width-height/4, height/4, height/4))
    shape = union(shape, circle(width-height/4, 3*height/4, height/4))
    w = height/2 - 1.5*line
    shape = difference(shape, rectangle(line, line+w/1.5, height/2+line/2, height-line))
    shape = difference(shape, circle(line+w/1.5, height/2+line/2+w/2, w/2))
    shape = difference(shape, rectangle(line, line+w/1.5, line, height/2-line/2))
    shape = difference(shape, circle(line+w/1.5, height/2-line/2-w/2, w/2))
    shapes['B'] = shape
    
    # b
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/4))
    shape = union(shape, rectangle(0.0, line, 0.0, height))
    shapes['b'] = shape
    
    # C
    shape = circle(width/2, width/2, width/2)
    shape = union(shape, circle(width/2, height-width/2, width/2))
    w = width - 2*line
    shape = union(shape, rectangle(0.0, width, line+w/2, height-line-w/2))
    shape = difference(shape, circle(width/2, line+w/2, w/2))
    shape = difference(shape, circle(width/2, height-line-w/2, w/2))
    shape = difference(shape, rectangle(line, width, line+w/2, height-line-w/2))
    shapes['C'] = shape
    
    # c
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/4))
    shape = difference(shape, rectangle(width/2, width, width/2-line/1.5, width/2+line/1.5))
    shapes['c'] = shape
    
    # D
    shape = circle(line, width-line, width-line)
    shape = difference(shape, circle(line, width-line, width-2*line))
    shape = difference(shape, rectangle(-width, line, 0.0, height))
    shape = scale_y(shape, 0.0, height/(2*(width-line)))
    shape = union(shape, rectangle(0.0, line, 0.0, height))
    shapes['D'] = shape
    
    # d
    shape = rectangle(width-line, width, 0.0, height)
    shape = union(shape, circle(width/2, width/2, width/2))
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shapes['d'] = shape
    
    # E
    shape = rectangle(0.0, line, 0.0, height)
    shape = union(shape, rectangle(0.0, width, height-line, height))
    shape = union(shape, rectangle(0.0, 2*width/3, height/2-line/2, height/2+line/2))
    shape = union(shape, rectangle(0.0, width, 0.0, line))
    shapes['E'] = shape
    
    # e
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = difference(shape, triangle(width, 0.0, width/2, width/2-line/2, width, width/2-line/2))
    shape = union(shape, rectangle(0.0, width, width/2-line/2, width/2+line/2))
    shapes['e'] = shape
    
    # F
    shape = rectangle(0.0, line, 0.0, height)
    shape = union(shape, rectangle(0.0, width, height-line, height))
    shape = union(shape, rectangle(0.0, 2*width/3, height/2-line/2, height/2+line/2))
    shapes['F'] = shape
    
    # f
    shape = circle(width-line/2, height-width/2, width/2)
    shape = difference(shape, circle(width-line/2, height-width/2, width/2-line))
    shape = difference(shape, rectangle(0.0, width-line/2, 0.0, height-width/2))
    shape = difference(shape, rectangle(width-line/2, 2*width, 0.0, height))
    shape = union(shape, rectangle(width/2-line/2, width/2+line/2, 0.0, height-width/2))
    shape = union(shape, rectangle(width/5, 4*width/5, height/2-line/2, height/2+line/2))
    shapes['f'] = shape
    
    # G
    shape = circle(width/2, width/2, width/2)
    shape = union(shape, circle(width/2, height-width/2, width/2))
    w = width - 2*line
    shape = union(shape, rectangle(0.0, width, line+w/2, height-line-w/2))
    shape = difference(shape, circle(width/2, line+w/2, w/2))
    shape = difference(shape, circle(width/2, height-line-w/2, w/2))
    shape = difference(shape, rectangle(line, width, line+w/2, height-line-w/2))
    shape = union(shape, rectangle(width/2, width, line+w/2, 2*line+w/2))
    shapes['G'] = shape
    
    # g
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    w = height/3 - width/2
    shape = union(shape, rectangle(width-line, width, w, width))
    shape = union(shape, difference(difference(circle(width/2, w, width/2), circle(width/2, w, width/2-line)), rectangle(0.0, width, w, height)))
    shapes['g'] = shape
    
    # H
    shape = rectangle(0.0, line, 0.0, height)
    shape = union(shape, rectangle(width-line, width, 0.0, height))
    shape = union(shape, rectangle(0.0, width, height/2-line/2, height/2+line/2))
    shapes['H'] = shape
    
    # h
    w = width/2
    shape = circle(width/2, w, width/2)
    shape = difference(shape, circle(width/2, w, width/2-line))
    shape = difference(shape, rectangle(0.0, width, 0.0, w))
    shape = union(shape, rectangle(0.0, line, 0.0, height))
    shape = union(shape, rectangle(width-line, width, 0.0, w))
    shapes['h'] = shape
    
    # I
    shape = rectangle(width/2-line/2, width/2+line/2, 0.0, height)
    shape = union(shape, rectangle(width/5, 4*width/5, 0.0, line))
    shape = union(shape, rectangle(width/5, 4*width/5, height-line, height))
    shapes['I'] = shape
    
    # i
    shape = rectangle(width/2-line/2, width/2+line/2, 0.0, height/2)
    shape = union(shape, circle(width/2, 3*height/4, 0.6*line))
    shapes['i'] = shape
    
    # J
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = difference(shape, rectangle(0.0, width, width/2, height))
    shape = union(shape, rectangle(width-line, width, width/2, height))
    shapes['J'] = shape
    
    # j
    w = height/3 - width/2
    shape = rectangle(width/2-line/2, width/2+line/2, w, height/2)
    shape = union(shape, difference(difference(difference(circle(width/4-line/2, w, width/2), circle(width/4-line/2, w, width/2-line)), rectangle(0.0, width, w, height)), rectangle(-width, width/4-line/2, -height/3, height)))
    shape = union(shape, circle(width/2, 3*height/4, 0.6*line))
    shapes['j'] = shape
    
    # K
    shape = rectangle(0.0, width, 0.0, height)
    shape = difference(shape, triangle(line, height, width-1.1*line, height, line, height/2+0.5*line))
    shape = difference(shape, triangle(width, 0.0, line+0.8*line, height/2, width, height))
    shape = difference(shape, triangle(line, 0.0, line, height/2-0.5*line, width-1.1*line, 0.0))
    shapes['K'] = shape
    
    # k
    shape = rectangle(0.0, width, 0.0, height)
    shape = difference(shape, rectangle(line, width, 2*height/3, height))
    shape = difference(shape, triangle(line, 2*height/3, width-1.3*line, 2*height/3, line, height/3+0.5*line))
    shape = difference(shape, triangle(width, 0.0, line+0.8*line, height/3, width, 2*height/3))
    shape = difference(shape, triangle(line, 0.0, line, height/3-0.5*line, width-1.3*line, 0.0))
    shapes['k'] = shape
    
    # L
    shape = rectangle(0.0, line, 0.0, height)
    shape = union(shape, rectangle(0.0, width, 0.0, line))
    shapes['L'] = shape
    
    # l
    shape = rectangle(width/2-line/2, width/2+line/2, 0.0, height)
    shapes['l'] = shape
    
    # M
    shape = rectangle(0.0, width, 0.0, height)
    shape = difference(shape, triangle(line, 0.0, line, height-3*line, width/2-line/3, 0.0))
    shape = difference(shape, triangle(line, height, width-line, height, width/2, 1.5*line))
    shape = difference(shape, triangle(width/2+line/3, 0.0, width-line, height-3*line, width-line, 0.0))
    shapes['M'] = shape
    
    # m
    w = width/2
    l = 1.3*line
    shape = circle(width/2, w, width/2)
    shape = difference(shape, circle(width/2, w, width/2-l))
    shape = difference(shape, rectangle(0.0, width, 0.0, w))
    shape = union(shape, rectangle(width-l, width, 0.0, w))
    shape = union(shape, move(shape, width-l, 0.0))
    shape = union(shape, rectangle(0.0, l, 0.0, width))
    shape = scale_x(shape, 0.0, width/(2*width-l))
    shapes['m'] = shape
    
    # N
    shape = rectangle(0.0, width, 0.0, height)
    shape = difference(shape, triangle(line, height+1.5*line, width-line, height+1.5*line, width-line, 1.5*line))
    shape = difference(shape, triangle(line, -1.5*line, line, height-1.5*line, width-line, -1.5*line))
    shapes['N'] = shape
    
    # n
    w = width/2
    shape = circle(width/2, w, width/2)
    shape = difference(shape, circle(width/2, w, width/2-line))
    shape = difference(shape, rectangle(0.0, width, 0.0, w))
    shape = union(shape, rectangle(0.0, line, 0.0, width))
    shape = union(shape, rectangle(width-line, width, 0.0, w))
    shapes['n'] = shape
    
    # O
    shape = circle(width/2, width/2, width/2)
    shape = union(shape, circle(width/2, height-width/2, width/2))
    w = width - 2*line
    shape = union(shape, rectangle(0.0, width, line+w/2, height-line-w/2))
    shape = difference(shape, circle(width/2, line+w/2, w/2))
    shape = difference(shape, circle(width/2, height-line-w/2, w/2))
    shape = difference(shape, rectangle(line, width-line, line+w/2, height-line-w/2))
    shapes['O'] = shape
    
    # o
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shapes['o'] = shape
    
    # P
    shape = rectangle(0.0, line, 0.0, height)
    w = 2*height/3
    shape = union(shape, circle(width-w/2, height-w/2, w/2))
    shape = union(shape, rectangle(0.0, width-w/2, height-w, height))
    shape = difference(shape, circle(width-w/2, height-w/2, w/2-line))
    shape = difference(shape, rectangle(line, width-w/2, height-w+line, height-line))
    shapes['P'] = shape
    
    # p
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/4))
    shape = union(shape, rectangle(0.0, line, -height/3, width))
    shapes['p'] = shape
    
    # Q
    shape = difference(circle(width/2, width/2, width/2), circle(width/2, width/2, width/2-0.9*line))
    shape = scale_y(shape, 0.0, height/width)
    shape = union(shape, move(rotate(rectangle(-line/2, line/2, -width/4, width/4), 30.0), 3*width/4, width/4))
    shapes['Q'] = shape
    
    # q
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = union(shape, rectangle(width-line, width, -height/3, width))
    shapes['q'] = shape
    
    # R
    shape = rectangle(0.0, line, 0.0, height)
    w = 2*height/3
    shape = union(shape, circle(width-w/2, height-w/2, w/2))
    shape = union(shape, rectangle(0.0, width-w/2, height-w, height))
    shape = difference(shape, circle(width-w/2, height-w/2, w/2-line))
    shape = difference(shape, rectangle(line, width-w/2, height-w+line, height-line))
    leg = triangle(line, 0.0, line, height, width, 0.0)
    leg = difference(leg, triangle(line, -2.0*line, line, height-2.0*line, width, -2.0*line))
    leg = difference(leg, rectangle(0.0, width, height/3, height))
    shape = union(shape, leg)
    shapes['R'] = shape
    
    # r
    shape = circle(width, 0.0, width)
    shape = difference(shape, circle(width, 0.0, width-line))
    shape = difference(shape, rectangle(0.8*width, 2*width, -height, height))
    shape = difference(shape, rectangle(0.0, 2*width, -height, 0.0))
    shape = union(shape, rectangle(0.0, line, 0.0, width))
    shapes['r'] = shape
    
    # S
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = difference(shape, rectangle(0.0, width/2, width/2, width))
    shape = union(shape, move(reflect_y(reflect_x(shape, width), width), 0.0, width-line))
    shape = scale_y(shape, 0.0, height/(2*width-line))
    shapes['S'] = shape
    
    # s
    w = width/3
    shape = circle(w, w, w)
    shape = difference(shape, circle(w, w, w-0.9*line))
    shape = difference(shape, rectangle(0.0, w, w, 2*w))
    shape = union(shape, move(reflect_y(reflect_x(shape, 2*w), 2*w), 0.0, 2*w-0.9*line))
    shape = scale_y(shape, 0.0, (2*height/3)/(4*w-0.9*line))
    shape = move(shape, (width/2)-w, 0.0)
    shapes['s'] = shape
    
    # T
    shape = rectangle(width/2-line/2, width/2+line/2, 0.0, height)
    shape = union(shape, rectangle(0.0, width, height-line, height))
    shapes['T'] = shape
    
    # t
    shape = circle(0.0, 3*width/8, 3*width/8)
    shape = difference(shape, circle(0.0, 3*width/8, 3*width/8-line))
    shape = difference(shape, rectangle(-width, width, 3*width/8, height))
    shape = difference(shape, rectangle(0.0, width, -height, height))
    shape = move(shape, width/2-line/2+3*width/8, 0.0)
    shape = union(shape, rectangle(width/2-line/2, width/2+line/2, width/4, 3*height/4))
    shape = union(shape, rectangle(width/5, 4*width/5, height/2-line/2, height/2+line/2))
    shapes['t'] = shape
    
    # U
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = difference(shape, rectangle(0.0, width, width/2, height))
    shape = union(shape, rectangle(0.0, line, width/2, height))
    shape = union(shape, rectangle(width-line, width, width/2, height))
    shapes['U'] = shape
    
    # u
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = difference(shape, rectangle(0.0, width, width/2, height))
    shape = union(shape, rectangle(0.0, line, width/2, 2*height/3))
    shape = union(shape, rectangle(width-line, width, 0.0, 2*height/3))
    shapes['u'] = shape
    
    # V
    shape = triangle(0.0, height, width, height, width/2, 0.0)
    shape = difference(shape, triangle(0.0, height+3*line, width, height+3*line, width/2, 3*line))
    shapes['V'] = shape
    
    # v
    w = 2*height/3.0
    shape = triangle(0.0, w, width, w, width/2, 0.0)
    shape = difference(shape, triangle(0.0, w+2*line, width, w+2*line, width/2, 2*line))
    shapes['v'] = shape
    
    # W
    shape = triangle(0.0, height, width, height, width/2, 0.0)
    shape = union(shape, move(shape, 0.6*width, 0.0))
    cutout = triangle(0.0, height+4*line, width, height+4*line, width/2, 4*line)
    cutout = union(cutout, move(cutout, 0.6*width, 0.0))
    shape = difference(shape, cutout)
    shape = scale_x(shape, 0.0, 1.0/1.6)
    shapes['W'] = shape
    
    # w
    shape = scale_y(shapes['W'], 0.0, width/height)
    shapes['w'] = shape
    
    # X
    shape = rectangle(0.0, width, 0.0, height)
    shape = difference(shape, triangle(0.0, 0.0, 0.0, height, width/2-0.7*line, height/2))
    shape = difference(shape, triangle(width, 0.0, width/2+0.7*line, height/2, width, height))
    shape = difference(shape, triangle(1.1*line, height, width-1.1*line, height, width/2, height/2+line))
    shape = difference(shape, triangle(1.1*line, 0.0, width/2, height/2-line, width-1.1*line, 0.0))
    shapes['X'] = shape
    
    # x
    w = 2*height/3.0
    shape = rectangle(0.0, width, 0.0, w)
    shape = difference(shape, triangle(0.0, 0.0, 0.0, w, width/2-0.75*line, w/2))
    shape = difference(shape, triangle(width, 0.0, width/2+0.75*line, w/2, width, w))
    shape = difference(shape, triangle(1.25*line, 0.0, width/2, w/2-0.75*line, width-1.25*line, 0.0))
    shape = difference(shape, triangle(1.25*line, w, width-1.25*line, w, width/2, w/2+0.75*line))
    shapes['x'] = shape
    
    # Y
    w = height/2
    shape = rectangle(0.0, width, w, height)
    shape = difference(shape, triangle(0.0, w, 0.0, height, width/2-line/2, w))
    shape = difference(shape, triangle(width/2+line/2, w, width, height, width, w))
    shape = difference(shape, triangle(1.1*line, height, width-1.1*line, height, width/2, w+1.1*line))
    shape = union(shape, rectangle(width/2-line/2, width/2+line/2, 0.0, w))
    shapes['Y'] = shape
    
    # y
    shape = rectangle(0.0, width, -height/3, width)
    shape = difference(shape, triangle(0.0, -height/3, 0.0, width, width/2-0.9*line, 0.0))
    shape = difference(shape, triangle(1.1*line, width, width-1.1*line, width, width/2-0.2*line, 1.6*line))
    shape = difference(shape, triangle(1.2*line, -height/3, width, width, width, -height/3))
    shapes['y'] = shape
    
    # Z
    shape = rectangle(0.0, width, 0.0, height)
    shape = difference(shape, triangle(0.0, line, 0.0, height-line, width-1.4*line, height-line))
    shape = difference(shape, triangle(1.4*line, line, width, height-line, width, line))
    shapes['Z'] = shape
    
    # z
    w = 2*height/3
    shape = rectangle(0.0, width, 0.0, w)
    shape = difference(shape, triangle(0.0, line, 0.0, w-line, width-1.6*line, w-line))
    shape = difference(shape, triangle(width, line, 1.6*line, line, width, w-line))
    shapes['z'] = shape
    
    # Digits 0-9
    # 0
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-0.9*line))
    shape = scale_y(shape, 0.0, height/width)
    shapes['0'] = shape
    
    # 1
    shape = rectangle(width/2-line/2, width/2+line/2, 0.0, height)
    w = width/2-line/2
    cutout = circle(0.0, height, w)
    shape = union(shape, rectangle(0.0, width/2, height-w-line, height))
    shape = difference(shape, cutout)
    shape = move(shape, (width/2+line/2)/4, 0.0)
    shapes['1'] = shape
    
    # 2
    shape = circle(width/2, height-width/2, width/2)
    shape = difference(shape, circle(width/2, height-width/2, width/2-line))
    shape = difference(shape, rectangle(0.0, width/2, 0.0, height-width/2))
    shape = union(shape, rectangle(0.0, width, 0.0, height-width/2))
    shape = difference(shape, triangle(0.0, line, 0.0, height-width/2, width-line, height-width/2))
    shape = difference(shape, triangle(1.5*line, line, width, height-width/2-0.5*line, width, line))
    shapes['2'] = shape
    
    # 3
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = scale_y(shape, 0.0, (height/2+line/2)/width)
    shape = union(shape, move(shape, 0.0, height/2-line/2))
    shape = difference(shape, rectangle(0.0, width/2, height/4, 3*height/4))
    shapes['3'] = shape
    
    # 4
    shape = rectangle(width-line, width, 0.0, height)
    shape = union(shape, triangle(0.0, height/3, width-line, height, width-line, height/3))
    shape = difference(shape, triangle(1.75*line, height/3+line, width-line, height-1.5*line, width-line, height/3+line))
    shapes['4'] = shape
    
    # 5
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = difference(shape, rectangle(0.0, width/2, width/2, width))
    shape = union(shape, rectangle(0.0, width/2, width-line, width))
    shape = union(shape, rectangle(0.0, line, width-line, height))
    shape = union(shape, rectangle(0.0, width, height-line, height))
    shapes['5'] = shape
    
    # 6
    shape = circle(width/2, height-width/2, width/2)
    shape = difference(shape, circle(width/2, height-width/2, width/2-line))
    shape = difference(shape, rectangle(0.0, width, 0.0, height-width/2))
    shape = difference(shape, triangle(width, height, width, height/2, width/2, height/2))
    shape = union(shape, circle(width/2, width/2, width/2))
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = union(shape, rectangle(0.0, line, width/2, height-width/2))
    shapes['6'] = shape
    
    # 7
    shape = rectangle(0.0, width, 0.0, height)
    shape = difference(shape, triangle(0.0, 0.0, 0.0, height-line, width-line, height-line))
    shape = difference(shape, triangle(line, 0.0, width, height-line, width, 0.0))
    shapes['7'] = shape
    
    # 8
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = scale_y(shape, 0.0, (height/2+line/2)/width)
    shape = union(shape, move(shape, 0.0, height/2-line/2))
    shapes['8'] = shape
    
    # 9
    shape = circle(width/2, width/2, width/2)
    shape = difference(shape, circle(width/2, width/2, width/2-line))
    shape = difference(shape, rectangle(0.0, width, width/2, height))
    shape = difference(shape, triangle(0.0, 0.0, 0.0, height/2, width/2, height/2))
    shape = union(shape, circle(width/2, height-width/2, width/2))
    shape = difference(shape, circle(width/2, height-width/2, width/2-line))
    shape = union(shape, rectangle(width-line, width, width/2, height-width/2))
    shapes['9'] = shape
    
    # Symbols
    # (
    w = width/2
    shape = circle(w, w, w)
    shape = difference(shape, circle(w, w, w-line))
    shape = difference(shape, rectangle(w, width, 0.0, height))
    shape = scale_y(shape, 0.0, height/width)
    shape = move(shape, w/2, 0.0)
    shapes['('] = shape
    
    # )
    shape = reflect_x(shape, width)
    shapes[')'] = shape
    
    # Space
    shapes[' '] = FALSE_EXPR
    
    # +
    shape = rectangle(width/2-width/3, width/2+width/3, height/2-line/2, height/2+line/2)
    shape = union(shape, rectangle(width/2-line/2, width/2+line/2, height/2-width/3, height/2+width/3))
    shapes['+'] = shape
    
    # -
    shape = rectangle(width/2-width/3, width/2+width/3, height/2-line/2, height/2+line/2)
    shapes['-'] = shape
    
    # .
    shape = circle(width/2, line, 0.75*line)
    shapes['.'] = shape
    
    # /
    shape = rectangle(0.0, width, 0.0, height)
    d = 0.8*line
    shape = difference(shape, triangle(d, 0.0, width, height-d, width, 0.0))
    shape = difference(shape, triangle(0.0, d, 0.0, height, width-d, height))
    shapes['/'] = shape
    
    # Unimplemented symbols (use slash shape as placeholder)
    for sym in ['~', '!', '@', '#', '$', '%', '^', '&', '_', '=', '[', '{', ']', '}', ';', ':', "'", '"', ',', '<', '>', '?']
        shapes[sym[1]] = shapes['/']
    end
    
    return shapes
end

"""
    process_text(renderer, shapes)

Process text string into a combined shape expression.

Mathematical basis:
- Characters are positioned sequentially with spacing
- Newlines create vertical line breaks
- Alignment adjusts position of entire text block
- Rotation and translation position text in final location

Building from scratch:
1. Initialize: Start with empty shape, set initial position
2. Loop through characters:
   - If newline: Add current line, reset position, move down
   - Otherwise: Get character shape, move to position, add to line
3. Add final line
4. Apply horizontal alignment (left/center/right)
5. Apply vertical alignment (top/center/bottom)
6. Apply rotation
7. Apply translation to final position
8. Apply color

Parameters:
- renderer: TextRenderer instance
- shapes: Dictionary of character shapes

Returns: Final text shape expression string
"""
function process_text(renderer::TextRenderer, shapes::Dict{Char, String})::String
    dx = 0.0
    dy = -renderer.height
    text_width = -renderer.space
    text_height = renderer.height
    line_shape = FALSE_EXPR
    final_shape = FALSE_EXPR
    line_count = 0
    
    # Process each character
    for chr in renderer.text
        if chr == '\n'
            # Newline: add current line and start new line
            if line_shape != FALSE_EXPR
                # Apply horizontal alignment to line
                aligned_line = apply_horizontal_alignment(line_shape, text_width, renderer.align[1])
                final_shape = union(final_shape, aligned_line)
            end
            dx = 0.0
            line_count += 1
            dy -= 1.5 * renderer.height / (1 + (line_count - 1) * 1.5)
            text_width = -renderer.space
            text_height += 1.5 * renderer.height
            line_shape = FALSE_EXPR
        else
            # Get character shape and position it
            if haskey(shapes, chr)
                char_shape = shapes[chr]
                if char_shape != FALSE_EXPR
                    positioned_char = move(char_shape, dx, dy)
                    line_shape = union(line_shape, positioned_char)
                end
            end
            text_width += renderer.space + renderer.width
            dx += renderer.width + renderer.space
        end
    end
    
    # Add final line
    if line_shape != FALSE_EXPR
        aligned_line = apply_horizontal_alignment(line_shape, text_width, renderer.align[1])
        final_shape = union(final_shape, aligned_line)
    end
    
    # Apply vertical alignment
    final_shape = apply_vertical_alignment(final_shape, text_height, renderer.align)
    
    # Apply rotation
    if renderer.angle == 90.0
        final_shape = rotate_90(final_shape)
    elseif renderer.angle == 180.0
        final_shape = rotate_180(final_shape)
    elseif renderer.angle == 270.0 || renderer.angle == -90.0
        final_shape = rotate_270(final_shape)
    elseif renderer.angle != 0.0
        final_shape = rotate(final_shape, renderer.angle)
    end
    
    # Apply translation to final position
    final_shape = move(final_shape, renderer.x, renderer.y)
    
    # Apply color
    final_shape = color(renderer.color_value, final_shape)
    
    return final_shape
end

"""
    apply_horizontal_alignment(line_shape, line_width, align_char)

Apply horizontal alignment to a line of text.

Parameters:
- line_shape: Shape expression for the line
- line_width: Total width of the line
- align_char: Alignment character ('L'=left, 'C'=center, 'R'=right)

Returns: Aligned line shape
"""
function apply_horizontal_alignment(line_shape::String, line_width::Float64, align_char::Char)::String
    if align_char == 'C'
        # Center: move left by half width
        return move(line_shape, -line_width / 2.0, 0.0)
    elseif align_char == 'R'
        # Right: move left by full width
        return move(line_shape, -line_width, 0.0)
    else
        # Left: no adjustment
        return line_shape
    end
end

"""
    apply_vertical_alignment(text_shape, text_height, align)

Apply vertical alignment to text block.

Parameters:
- text_shape: Shape expression for entire text
- text_height: Total height of text
- align: Alignment string (e.g., "CC" for center-center)

Returns: Aligned text shape
"""
function apply_vertical_alignment(text_shape::String, text_height::Float64, align::String)::String
    if length(align) >= 2
        align_char = align[2]
        if align_char == 'C'
            # Center: move up by half height
            return move(text_shape, 0.0, text_height / 2.0)
        elseif align_char == 'B'
            # Bottom: move up by full height
            return move(text_shape, 0.0, text_height)
        end
    end
    # Top: no adjustment
    return text_shape
end

"""
    text(text_str, x, y, z=0.0; kwargs...)

Convenience function to create text and return its shape expression.

Parameters:
- text_str: Text string to render
- x, y, z: Position coordinates
- kwargs: Optional parameters (line, height, width, space, align, color_value, angle)

Returns: Text shape expression string
"""
function text(text_str::String, x::Float64, y::Float64, z::Float64=0.0;
              line::Float64=1.0, height::Float64=0.0, width::Float64=0.0,
              space::Float64=0.0, align::String="CC", color_value::UInt32=COLOR_WHITE,
              angle::Float64=0.0)::String
    renderer = TextRenderer(text_str, x, y, z;
                            line=line, height=height, width=width,
                            space=space, align=align, color_value=color_value,
                            angle=angle)
    return renderer.shape
end

############################################################
# PCB board class
############################################################

"""
    PCB

A struct that manages a PCB board definition, including board shape, components,
labels, solder mask, holes, and cutouts.

Mathematical basis:
- PCB is a container that organizes different layers and elements
- Board: Main copper layer (traces, pads, components)
- Interior: Board outline rectangle (defines board area)
- Exterior: Everything outside board (for rendering background)
- Mask: Solder mask layer (expanded around parts to prevent solder bridges)
- Holes: Drill holes for through-hole components
- Cutout: Board cutouts (internal routing, mounting holes, etc.)
- Labels: Text labels for silkscreen

Building from scratch:
1. Board definition: Create rectangle for board outline
2. Interior: Rectangle defining board area
3. Exterior: Difference of entire space and interior
4. Component management: Add parts to board, automatically expand mask
5. Mask generation: Expand parts in 4 directions to create mask clearance
6. Layer organization: Separate expressions for each layer type

Usage:
    pcb = PCB(0.0, 0.0, 2.0, 2.0, 0.05)
    pcb.add(circle(0.5, 0.5, 0.1))
    pcb.text("Label", 1.0, 1.0, 0.01, COLOR_WHITE)
"""
mutable struct PCB
    x0::Float64
    y0::Float64
    width::Float64
    height::Float64
    mask_size::Float64
    board::String
    labels::String
    interior::String
    exterior::String
    mask::String
    holes::String
    cutout::String
    
    function PCB(x0::Float64, y0::Float64, width::Float64, height::Float64, mask_size::Float64)
        # Initialize with empty shapes
        board = FALSE_EXPR
        labels = FALSE_EXPR
        interior = rectangle(x0, x0 + width, y0, y0 + height)
        exterior = difference(TRUE_EXPR, rectangle(x0, x0 + width, y0, y0 + height))
        mask = FALSE_EXPR
        holes = FALSE_EXPR
        cutout = FALSE_EXPR
        
        return new(x0, y0, width, height, mask_size,
                   board, labels, interior, exterior, mask, holes, cutout)
    end
end

"""
    add(pcb, part)

Add a part (shape) to the PCB board.

Mathematical basis:
- Adds part to board layer (copper traces/pads)
- Automatically expands mask around part in 4 directions
- Mask expansion prevents solder bridges by creating clearance
- Expansion in 4 diagonal directions: (-mask, mask), (-mask, -mask), (mask, mask), (mask, -mask)

Building from scratch:
1. Add part to board: Union part with existing board
2. Expand mask: Create 4 copies of part, each translated diagonally
3. Combine mask expansions: Union all 4 expanded parts
4. This creates clearance around parts for solder mask

Parameters:
- pcb: PCB instance
- part: Shape expression string to add

Returns: Modified PCB instance (for method chaining)
"""
function add(pcb::PCB, part::String)::PCB
    # Add part to board layer
    pcb.board = union(pcb.board, part)
    
    # Expand mask around part in 4 diagonal directions
    # This creates clearance for solder mask
    pcb.mask = union(pcb.mask, move(part, -pcb.mask_size, pcb.mask_size))
    pcb.mask = union(pcb.mask, move(part, -pcb.mask_size, -pcb.mask_size))
    pcb.mask = union(pcb.mask, move(part, pcb.mask_size, pcb.mask_size))
    pcb.mask = union(pcb.mask, move(part, pcb.mask_size, -pcb.mask_size))
    
    return pcb
end

"""
    panel(pcb, other_pcb, dx, dy, dz=0.0)

Panel multiple PCBs together (combine boards side by side).

Mathematical basis:
- Combines two PCBs by translating one relative to the other
- Board layers are combined (union)
- Interior areas are combined (union)
- Exterior areas are intersected (both must be exterior)
- Mask and holes are combined (union)
- Board dimensions are updated

Building from scratch:
1. Translate other PCB: Move all layers by (dx, dy, dz)
2. Combine boards: Union board layers
3. Combine interiors: Union interior rectangles
4. Combine exteriors: Intersect (both must be exterior)
5. Combine masks and holes: Union translated layers
6. Update dimensions: Add translation to width/height

Parameters:
- pcb: Main PCB instance (modified in place)
- other_pcb: Other PCB to panel
- dx: X translation
- dy: Y translation
- dz: Z translation (default 0.0)

Returns: Modified PCB instance
"""
function panel(pcb::PCB, other_pcb::PCB, dx::Float64, dy::Float64, dz::Float64=0.0)::PCB
    # Translate other PCB's layers
    other_board = translate(other_pcb.board, dx, dy, dz)
    other_interior = translate(other_pcb.interior, dx, dy, dz)
    other_exterior = translate(other_pcb.exterior, dx, dy, dz)
    other_mask = translate(other_pcb.mask, dx, dy, dz)
    other_holes = translate(other_pcb.holes, dx, dy, dz)
    
    # Combine layers
    pcb.board = union(pcb.board, other_board)
    pcb.interior = union(pcb.interior, other_interior)
    pcb.exterior = intersect(pcb.exterior, other_exterior)
    pcb.mask = union(pcb.mask, other_mask)
    pcb.holes = union(pcb.holes, other_holes)
    
    # Update dimensions
    pcb.width = pcb.width + dx
    pcb.height = pcb.height + dy
    
    return pcb
end

"""
    add_text(pcb, text_str, x, y, line=0.01, color_value=COLOR_WHITE)

Add text label to the PCB.

Mathematical basis:
- Creates text shape using text rendering system
- Adds text to labels layer (silkscreen)
- Text is positioned at specified coordinates
- Text can be colored for visibility

Parameters:
- pcb: PCB instance
- text_str: Text string to render
- x, y: Position coordinates
- line: Line thickness (default 0.01)
- color_value: Text color (default COLOR_WHITE)

Returns: Modified PCB instance
"""
function add_text(pcb::PCB, text_str::String, x::Float64, y::Float64;
                  line::Float64=0.01, color_value::UInt32=UInt32(COLOR_WHITE),
                  angle::Float64=0.0)::PCB
    # Create text shape
    text_shape = text(text_str, x, y, 0.0, line=line, color_value=color_value, angle=angle)
    
    # Add to labels layer
    pcb.labels = union(pcb.labels, text_shape)
    
    return pcb
end

"""
    add_hole(pcb, x, y, radius)

Add a drill hole to the PCB.

Mathematical basis:
- Creates circular hole at specified position
- Holes are subtracted from board (not added)
- Used for through-hole components and mounting

Parameters:
- pcb: PCB instance
- x, y: Hole center coordinates
- radius: Hole radius

Returns: Modified PCB instance
"""
function add_hole(pcb::PCB, x::Float64, y::Float64, radius::Float64)::PCB
    hole_shape = circle(x, y, radius)
    pcb.holes = union(pcb.holes, hole_shape)
    return pcb
end

"""
    add_cutout(pcb, shape)

Add a board cutout (internal routing, mounting holes, etc.).

Mathematical basis:
- Cutouts are areas removed from board outline
- Used for internal routing, mounting holes, or board shapes
- Different from holes (which are just drill points)

Parameters:
- pcb: PCB instance
- shape: Shape expression for cutout

Returns: Modified PCB instance
"""
function add_cutout(pcb::PCB, shape::String)::PCB
    pcb.cutout = union(pcb.cutout, shape)
    return pcb
end

"""
    Point

A simple struct representing a 3D point.

Mathematical basis:
- Represents coordinates in 3D space
- Used for component placement, pin positions, etc.
- Simple container for x, y, z coordinates

Usage:
    pt = Point(1.0, 2.0, 0.0)
"""
struct Point
    x::Float64
    y::Float64
    z::Float64
    
    function Point(x::Float64, y::Float64, z::Float64=0.0)
        return new(x, y, z)
    end
end

############################################################
# component base class
############################################################

"""
    ComponentText

Represents a text label associated with a component.

Mathematical basis:
- Stores text label information (position, text, line thickness, angle)
- Position is relative to component origin
- Angle is relative to component rotation
- Used for pin labels, component identifiers, etc.

Fields:
- x, y, z: Position coordinates (relative to component)
- text: Text string to display
- line: Line thickness for text rendering
- angle: Rotation angle (degrees, relative to component)
"""
struct ComponentText
    x::Float64
    y::Float64
    z::Float64
    text::String
    line::Float64
    angle::Float64
    
    function ComponentText(x::Float64, y::Float64, z::Float64=0.0,
                          text::String="", line::Float64=0.006, angle::Float64=0.0)
        return new(x, y, z, text, line, angle)
    end
end

"""
    Component

Base class for all PCB components.

Mathematical basis:
- Components are reusable parts that can be placed on PCBs
- Each component has:
  - Shape: FRep expression for component body/pads
  - Pads: Array of pin positions (Point objects)
  - Labels: Array of text labels (ComponentText objects)
  - Value: Component value string (e.g., "10k" for resistor)
  - Optional holes: For through-hole components
  - Optional cutout: For components that require board cutouts

Building from scratch:
1. Component definition: Create struct with shape, pads, labels
2. Shape creation: Build FRep expression for component geometry
3. Pad positions: Define pin positions relative to component origin
4. Label positions: Define text label positions relative to component
5. Placement: Use add() method to place component on PCB
6. Rotation: Rotate shape, pads, and labels using rotation matrix
7. Translation: Move everything to final position

Usage:
    # Component is typically subclassed, not used directly
    # Example: Resistor, Capacitor, IC, etc.
"""
mutable struct Component
    shape::String
    pad::Vector{Point}
    labels::Vector{ComponentText}
    value::String
    holes::Union{String, Nothing}
    cutout::Union{String, Nothing}
    
    function Component(shape::String, pad::Vector{Point}, labels::Vector{ComponentText},
                      value::String="", holes::Union{String, Nothing}=nothing,
                      cutout::Union{String, Nothing}=nothing)
        return new(shape, pad, labels, value, holes, cutout)
    end
end

"""
    add_component(pcb, component, x, y, z=0.0, angle=0.0, line=0.007)

Place a component on the PCB.

Mathematical basis:
- Rotates component shape, holes, and cutout based on angle
- Translates everything to position (x, y, z)
- Rotates pad positions using 2D rotation matrix:
  - x' = x*cos(θ) - y*sin(θ)
  - y' = x*sin(θ) + y*cos(θ)
- Rotates label positions using same matrix
- Adjusts label angles based on component rotation
- Adds component shape to PCB board layer
- Adds holes to PCB holes layer
- Subtracts cutout from PCB interior

Building from scratch:
1. Rotation handling: Check for common angles (90, 180, 270) for optimization
2. Shape rotation: Apply rotation to component shape expression
3. Translation: Move rotated shape to final position
4. Pad rotation: Apply rotation matrix to each pad position
5. Label rotation: Apply rotation matrix to each label position
6. Label angle adjustment: Combine component angle with label angle
7. Layer updates: Add shape to board, holes to holes, subtract cutout from interior

Parameters:
- pcb: PCB instance
- component: Component to place
- x, y, z: Position coordinates
- angle: Rotation angle in degrees (default 0.0)
- line: Line thickness for value label (default 0.007)

Returns: Modified PCB instance
"""
function add_component(pcb::PCB, component::Component, x::Float64, y::Float64, z::Float64=0.0;
                      angle::Float64=0.0, line::Float64=0.007)::PCB
    # Rotate and translate shape
    shape = component.shape
    if angle == 90.0
        shape = rotate_90(shape)
    elseif angle == 180.0
        shape = rotate_180(shape)
    elseif angle == 270.0 || angle == -90.0
        shape = rotate_270(shape)
    elseif angle != 0.0
        shape = rotate(shape, angle)
    end
    shape = translate(shape, x, y, z)
    
    # Rotate and translate holes if present
    if component.holes !== nothing
        holes = component.holes
        if angle == 90.0
            holes = rotate_90(holes)
        elseif angle == 180.0
            holes = rotate_180(holes)
        elseif angle == 270.0 || angle == -90.0
            holes = rotate_270(holes)
        elseif angle != 0.0
            holes = rotate(holes, angle)
        end
        holes = translate(holes, x, y, z)
        pcb.holes = union(pcb.holes, holes)
    end
    
    # Rotate and translate cutout if present
    if component.cutout !== nothing
        cutout = component.cutout
        if angle == 90.0
            cutout = rotate_90(cutout)
        elseif angle == 180.0
            cutout = rotate_180(cutout)
        elseif angle == 270.0 || angle == -90.0
            cutout = rotate_270(cutout)
        elseif angle != 0.0
            cutout = rotate(cutout, angle)
        end
        cutout = translate(cutout, x, y, z)
        pcb.interior = difference(pcb.interior, cutout)
        pcb.exterior = union(pcb.exterior, cutout)
    end
    
    # Rotate pad positions using rotation matrix
    angle_rad = angle * π / 180.0
    cos_a = cos(angle_rad)
    sin_a = sin(angle_rad)
    
    for i in 1:length(component.pad)
        pad = component.pad[i]
        x_new = cos_a * pad.x - sin_a * pad.y
        y_new = sin_a * pad.x + cos_a * pad.y
        component.pad[i] = Point(x + x_new, y + y_new, pad.z + z)
    end
    
    # Add value label
    if component.value != ""
        pcb = add_text(pcb, component.value, x, y, line=line, color_value=UInt32(COLOR_GREEN))
    end
    
    # Rotate and add component labels
    for label in component.labels
        x_new = cos_a * label.x - sin_a * label.y
        y_new = sin_a * label.x + cos_a * label.y
        label_x = x + x_new
        label_y = y + y_new
        label_z = label.z + z
        
        # Adjust label angle based on component rotation
        if -90.0 < angle <= 90.0
            label_angle = angle - label.angle
        else
            label_angle = angle - label.angle - 180.0
        end
        
        pcb = add_text(pcb, label.text, label_x, label_y, line=label.line,
                      color_value=UInt32(COLOR_RED), angle=label_angle)
    end
    
    # Add component shape to board
    pcb = add(pcb, shape)
    
    return pcb
end

############################################################
# component library
############################################################

# Common pad definitions
const pad_header = cube(-0.05, 0.05, -0.025, 0.025, 0.0, 0.0)
const pad_1206 = cube(-0.032, 0.032, -0.034, 0.034, 0.0, 0.0)
const pad_MTA = cube(-0.021, 0.021, -0.041, 0.041, 0.0, 0.0)
const pad_MTA_solder = cube(-0.071, 0.071, -0.041, 0.041, 0.0, 0.0)
const pad_screw_terminal = cylinder(0.0, 0.0, 0.0, 0.0, 0.047)
const pad_stereo_2_5mm = cube(-0.03, 0.03, -0.05, 0.05, 0.0, 0.0)
const pad_Molex = cube(-0.0155, 0.0155, -0.0265, 0.0265, 0.0, 0.0)
const pad_Molex_solder = cube(-0.055, 0.055, -0.065, 0.065, 0.0, 0.0)
const pad_SOIC = cube(-0.041, 0.041, -0.015, 0.015, 0.0, 0.0)
const pad_RGB = cube(-0.02, 0.02, -0.029, 0.029, 0.0, 0.0)

# Helper function to create ComponentText (replaces Python's self.text() method)
function component_text(x::Float64, y::Float64, z::Float64=0.0;
                        text_str::String="", line::Float64=0.006, angle::Float64=0.0)::ComponentText
    return ComponentText(x, y, z, text_str, line, angle)
end

# Helper for hole_screw_terminal (circle converted to cylinder)
function hole_screw_terminal(x::Float64, y::Float64, zb::Float64, zt::Float64)::String
    return cylinder(x, y, zb, zt, 0.025)
end

# fab component
function fab(r::Float64=0.05, value::String="")::Component
    d = 1.8 * r
    l = 3.5 * r
    h = r / 2.0
    shape = rectangle(-d, d, -d, d)
    shape = subtract(shape, circle(0.0, 0.0, r))
    shape = subtract(shape, rectangle(-l, 0.0, -h, h))
    shape = union(shape, rectangle(d, l, -h, h))
    shape = union(shape, circle(l, 0.0, r))
    shape = union(shape, circle(-l, 0.0, r))
    
    return Component(shape, [Point(0.0, 0.0, 0.0)], ComponentText[], value, nothing, nothing)
end

# LED_1206 component
function LED_1206(value::String="")::Component
    shape = translate(pad_1206, -0.06, 0.0, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.055, 0.0, 0.0), Point(0.055, 0.0, 0.0)]
    labels = [
        component_text(-0.055, 0.0, 0.0, text_str="A"),
        component_text(0.055, 0.0, 0.0, text_str="C")
    ]
    shape = union(shape, translate(pad_1206, 0.06, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# LED_RGB component
function LED_RGB(value::String="")::Component
    dx = 0.029
    dy = 0.059
    pad_RGB_local = pad_RGB
    
    shape = translate(pad_RGB_local, -dx, -dy, 0.0)
    shape = union(shape, cylinder(-dx, -dy - 0.029, 0.0, 0.0, 0.02))
    pad_list = [Point(0.0, 0.0, 0.0), Point(-dx, -dy, 0.0), Point(dx, -dy, 0.0), Point(dx, dy, 0.0), Point(-dx, dy, 0.0)]
    labels = [
        component_text(-dx, -dy, 0.0, text_str="R"),
        component_text(dx, -dy, 0.0, text_str="A"),
        component_text(dx, dy, 0.0, text_str="B"),
        component_text(-dx, dy, 0.0, text_str="G")
    ]
    
    shape = union(shape, translate(pad_RGB_local, dx, -dy, 0.0))
    shape = union(shape, translate(pad_RGB_local, dx, dy, 0.0))
    shape = union(shape, translate(pad_RGB_local, -dx, dy, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# WS2812B component
function WS2812B(value::String="")::Component
    padl = cube(-0.06, 0.0, -0.02, 0.02, 0.0, 0.0)
    padr = cube(0.0, 0.06, -0.02, 0.02, 0.0, 0.0)
    
    shape = translate(padl, -0.067, 0.065, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.096, 0.065, 0.0), Point(-0.096, -0.065, 0.0), Point(0.096, -0.065, 0.0), Point(0.096, 0.065, 0.0)]
    labels = [
        component_text(-0.096, 0.065, 0.0, text_str=".V"),
        component_text(-0.096, -0.065, 0.0, text_str="DOUT"),
        component_text(0.096, -0.065, 0.0, text_str="GND"),
        component_text(0.096, 0.065, 0.0, text_str="DIN")
    ]
    
    shape = union(shape, translate(padl, -0.067, -0.065, 0.0))
    shape = union(shape, translate(padr, 0.067, -0.065, 0.0))
    shape = union(shape, translate(padr, 0.067, 0.065, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# button_6mm component
function button_6mm(value::String="")::Component
    pad_button_6mm = cube(-0.04, 0.04, -0.03, 0.03, 0.0, 0.0)
    
    shape = translate(pad_button_6mm, -0.125, 0.08, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.125, 0.08, 0.0), Point(-0.125, -0.08, 0.0), Point(0.125, -0.08, 0.0), Point(0.125, 0.08, 0.0)]
    labels = [
        component_text(-0.125, 0.08, 0.0, text_str="L1"),
        component_text(-0.125, -0.08, 0.0, text_str="R1"),
        component_text(0.125, -0.08, 0.0, text_str="R2"),
        component_text(0.125, 0.08, 0.0, text_str="L2")
    ]
    
    shape = union(shape, translate(pad_button_6mm, -0.125, -0.08, 0.0))
    shape = union(shape, translate(pad_button_6mm, 0.125, -0.08, 0.0))
    shape = union(shape, translate(pad_button_6mm, 0.125, 0.08, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# IMU_6050 component (through-hole version)
function IMU_6050(value::String, zb::Float64, zt::Float64)::Component
    pad_header_local = cylinder(0.0, 0.0, zb, zt, 0.04)
    pad_hole = cylinder(0.0, 0.0, zb, zt, 0.018)
    
    shape = translate(pad_header_local, 0.0, 0.35, 0.0)
    holes = translate(pad_hole, 0.0, 0.35, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.35, 0.0), Point(0.0, 0.25, 0.0), Point(0.0, 0.15, 0.0), Point(0.0, 0.05, 0.0), Point(0.0, -0.05, 0.0), Point(0.0, -0.15, 0.0), Point(0.0, -0.25, 0.0), Point(0.0, -0.35, 0.0)]
    labels = [
        component_text(0.0, 0.35, 0.0, text_str="VCC"),
        component_text(0.0, 0.25, 0.0, text_str="GND"),
        component_text(0.0, 0.15, 0.0, text_str="SCL"),
        component_text(0.0, 0.05, 0.0, text_str="SDA"),
        component_text(0.0, -0.05, 0.0, text_str="XDA"),
        component_text(0.0, -0.15, 0.0, text_str="XCL"),
        component_text(0.0, -0.25, 0.0, text_str="AD0"),
        component_text(0.0, -0.35, 0.0, text_str="INT")
    ]
    
    shape = union(shape, translate(pad_header_local, 0.0, 0.25, 0.0))
    holes = union(holes, translate(pad_hole, 0.0, 0.25, 0.0))
    shape = union(shape, translate(pad_header_local, 0.0, 0.15, 0.0))
    holes = union(holes, translate(pad_hole, 0.0, 0.15, 0.0))
    shape = union(shape, translate(pad_header_local, 0.0, 0.05, 0.0))
    holes = union(holes, translate(pad_hole, 0.0, 0.05, 0.0))
    shape = union(shape, translate(pad_header_local, 0.0, -0.05, 0.0))
    holes = union(holes, translate(pad_hole, 0.0, -0.05, 0.0))
    shape = union(shape, translate(pad_header_local, 0.0, -0.15, 0.0))
    holes = union(holes, translate(pad_hole, 0.0, -0.15, 0.0))
    shape = union(shape, translate(pad_header_local, 0.0, -0.25, 0.0))
    holes = union(holes, translate(pad_hole, 0.0, -0.25, 0.0))
    shape = union(shape, translate(pad_header_local, 0.0, -0.35, 0.0))
    holes = union(holes, translate(pad_hole, 0.0, -0.35, 0.0))
    
    return Component(shape, pad_list, labels, value, holes, nothing)
end

# PicoW component
function PicoW(value::String="")::Component
    board_width = 22.58 / 25.4
    pad_width = 3.2 / 25.4
    pad_height = 0.08
    pad_pitch = 0.1
    pad_offset = pad_width / 4.0
    pad_left = cube(0.0, pad_width, -pad_height / 2.0, pad_height / 2.0, 0.0, 0.0)
    pad_right = cube(-pad_width, 0.0, -pad_height / 2.0, pad_height / 2.0, 0.0, 0.0)
    label_offset = pad_width / 2.0
    
    shape = "0"
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # Pins 1-10
    for i in 0:9
        y_pos = (9.5 - i) * pad_pitch
        shape = union(shape, translate(pad_left, -board_width / 2.0 - pad_offset, y_pos, 0.0))
        push!(pad_list, Point(-board_width / 2.0 - pad_offset, y_pos, 0.0))
        push!(labels, component_text(-board_width / 2.0 - pad_offset + label_offset, y_pos, 0.0, text_str=string(i + 1)))
    end
    
    # Pins 11-20
    for i in 0:9
        y_pos = -(0.5 + i) * pad_pitch
        shape = union(shape, translate(pad_left, -board_width / 2.0 - pad_offset, y_pos, 0.0))
        push!(pad_list, Point(-board_width / 2.0 - pad_offset, y_pos, 0.0))
        push!(labels, component_text(-board_width / 2.0 - pad_offset + label_offset, y_pos, 0.0, text_str=string(11 + i)))
    end
    
    # Pins 21-30
    for i in 0:9
        y_pos = -(9.5 - i) * pad_pitch
        shape = union(shape, translate(pad_right, board_width / 2.0 + pad_offset, y_pos, 0.0))
        push!(pad_list, Point(board_width / 2.0 + pad_offset, y_pos, 0.0))
        push!(labels, component_text(board_width / 2.0 + pad_offset - label_offset, y_pos, 0.0, text_str=string(21 + i)))
    end
    
    # Pins 31-40
    for i in 0:9
        y_pos = (0.5 + i) * pad_pitch
        shape = union(shape, translate(pad_right, board_width / 2.0 + pad_offset, y_pos, 0.0))
        push!(pad_list, Point(board_width / 2.0 + pad_offset, y_pos, 0.0))
        push!(labels, component_text(board_width / 2.0 + pad_offset - label_offset, y_pos, 0.0, text_str=string(31 + i)))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# XIAO_SAMD21 component
function XIAO_SAMD21(value::String="")::Component
    padl = cube(-0.04, 0.081, -0.070 / 2.0, 0.070 / 2.0, 0.0, 0.0)
    padr = cube(-0.081, 0.04, -0.070 / 2.0, 0.070 / 2.0, 0.0, 0.0)
    pitch = 0.1
    dx = 0.035
    width = 0.685
    length = 0.798
    d = 0.015
    l = 0.004
    
    shape = translate(padl, -width / 2.0, 3 * pitch, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-width / 2.0, 3 * pitch, 0.0)]
    labels = [component_text(-width / 2.0 + dx, 3 * pitch, 0.0, text_str="D0", line=l)]
    
    # Pin 2
    shape = union(shape, translate(padl, -width / 2.0, 2 * pitch, 0.0))
    push!(pad_list, Point(-width / 2.0, 2 * pitch, 0.0))
    push!(labels, component_text(-width / 2.0 + dx, 2 * pitch, 0.0, text_str="D1", line=l))
    
    # Pin 3
    shape = union(shape, translate(padl, -width / 2.0, 1 * pitch, 0.0))
    push!(pad_list, Point(-width / 2.0, 1 * pitch, 0.0))
    push!(labels, component_text(-width / 2.0 + dx, 1 * pitch, 0.0, text_str="D2", line=l))
    
    # Pin 4
    shape = union(shape, translate(padl, -width / 2.0, 0 * pitch, 0.0))
    push!(pad_list, Point(-width / 2.0, 0 * pitch, 0.0))
    push!(labels, component_text(-width / 2.0 + dx, 0 * pitch, 0.0, text_str="D3", line=l))
    
    # Pin 5
    shape = union(shape, translate(padl, -width / 2.0, -1 * pitch, 0.0))
    push!(pad_list, Point(-width / 2.0, -1 * pitch, 0.0))
    push!(labels, component_text(-width / 2.0 + dx, -1 * pitch, 0.0, text_str="SDA", line=l))
    
    # Pin 6
    shape = union(shape, translate(padl, -width / 2.0, -2 * pitch, 0.0))
    push!(pad_list, Point(-width / 2.0, -2 * pitch, 0.0))
    push!(labels, component_text(-width / 2.0 + dx, -2 * pitch, 0.0, text_str="SCL", line=l))
    
    # Pin 7
    shape = union(shape, translate(padl, -width / 2.0, -3 * pitch, 0.0))
    push!(pad_list, Point(-width / 2.0, -3 * pitch, 0.0))
    push!(labels, component_text(-width / 2.0 + dx, -3 * pitch, 0.0, text_str="TX", line=l))
    
    # Pin 8
    shape = union(shape, translate(padr, width / 2.0, -3 * pitch, 0.0))
    push!(pad_list, Point(width / 2.0, -3 * pitch, 0.0))
    push!(labels, component_text(width / 2.0 - dx, -3 * pitch, 0.0, text_str="RX", line=l))
    
    # Pin 9
    shape = union(shape, translate(padr, width / 2.0, -2 * pitch, 0.0))
    push!(pad_list, Point(width / 2.0, -2 * pitch, 0.0))
    push!(labels, component_text(width / 2.0 - dx, -2 * pitch, 0.0, text_str="SCK", line=l))
    
    # Pin 10
    shape = union(shape, translate(padr, width / 2.0, -1 * pitch, 0.0))
    push!(pad_list, Point(width / 2.0, -1 * pitch, 0.0))
    push!(labels, component_text(width / 2.0 - dx, -1 * pitch, 0.0, text_str="SDI", line=l))
    
    # Pin 11
    shape = union(shape, translate(padr, width / 2.0, 0 * pitch, 0.0))
    push!(pad_list, Point(width / 2.0, 0 * pitch, 0.0))
    push!(labels, component_text(width / 2.0 - dx, 0 * pitch, 0.0, text_str="SDO", line=l))
    
    # Pin 12
    shape = union(shape, translate(padr, width / 2.0, 1 * pitch, 0.0))
    push!(pad_list, Point(width / 2.0, 1 * pitch, 0.0))
    push!(labels, component_text(width / 2.0 - dx, 1 * pitch, 0.0, text_str="3V3", line=l))
    
    # Pin 13
    shape = union(shape, translate(padr, width / 2.0, 2 * pitch, 0.0))
    push!(pad_list, Point(width / 2.0, 2 * pitch, 0.0))
    push!(labels, component_text(width / 2.0 - dx, 2 * pitch, 0.0, text_str="G", line=l))
    
    # Pin 14
    shape = union(shape, translate(padr, width / 2.0, 3 * pitch, 0.0))
    push!(pad_list, Point(width / 2.0, 3 * pitch, 0.0))
    push!(labels, component_text(width / 2.0 - dx, 3 * pitch, 0.0, text_str="5V", line=l))
    
    # JTAG pads
    dw = 0.047
    left = 0.27
    right = 0.27
    top = 0.050
    bottom = 0.20
    pad = cube(-dw / 2.0, dw / 2.0, -dw / 2.0, dw / 2.0, 0.0, 0.0)
    
    shape = union(shape, translate(pad, -width / 2.0 + left + dw / 2.0, length / 2.0 - bottom + dw / 2.0, 0.0))
    push!(pad_list, Point(-width / 2.0 + left + dw / 2.0, length / 2.0 - bottom + dw / 2.0, 0.0))
    push!(labels, component_text(-width / 2.0 + left + dw / 2.0, length / 2.0 - bottom + dw / 2.0, 0.0, text_str="", line=l))
    
    shape = union(shape, translate(pad, -width / 2.0 + left + dw / 2.0, length / 2.0 - top - dw / 2.0, 0.0))
    push!(pad_list, Point(-width / 2.0 + left + dw / 2.0, length / 2.0 - top - dw / 2.0, 0.0))
    push!(labels, component_text(-width / 2.0 + left + dw / 2.0, length / 2.0 - top - dw / 2.0, 0.0, text_str="", line=l))
    
    shape = union(shape, translate(pad, width / 2.0 - right - dw / 2.0, length / 2.0 - bottom + dw / 2.0, 0.0))
    push!(pad_list, Point(width / 2.0 - right - dw / 2.0, length / 2.0 - bottom + dw / 2.0, 0.0))
    push!(labels, component_text(width / 2.0 - right - dw / 2.0, length / 2.0 - bottom + dw / 2.0, 0.0, text_str="", line=l))
    
    shape = union(shape, translate(pad, width / 2.0 - right - dw / 2.0, length / 2.0 - top - dw / 2.0, 0.0))
    push!(pad_list, Point(width / 2.0 - right - dw / 2.0, length / 2.0 - top - dw / 2.0, 0.0))
    push!(labels, component_text(width / 2.0 - right - dw / 2.0, length / 2.0 - top - dw / 2.0, 0.0, text_str="", line=l))
    
    # Battery pads
    dx_bat = 0.042
    dy_bat = 0.081
    left_bat = 0.27
    right_bat = 0.27
    bottom_bat = 0.020
    pad_bat = cube(-dx_bat / 2.0, dx_bat / 2.0, -dy_bat / 2.0, dy_bat / 2.0, 0.0, 0.0)
    
    shape = union(shape, translate(pad_bat, -width / 2.0 + left_bat + dx_bat / 2.0, -length / 2.0 + bottom_bat + dy_bat / 2.0, 0.0))
    push!(pad_list, Point(-width / 2.0 + left_bat + dx_bat / 2.0, -length / 2.0 + bottom_bat + dy_bat / 2.0, 0.0))
    push!(labels, component_text(-width / 2.0 + left_bat + dx_bat / 2.0, -length / 2.0 + bottom_bat + dy_bat / 2.0, 0.0, text_str="VIN", line=l))
    
    shape = union(shape, translate(pad_bat, width / 2.0 - right_bat - dx_bat / 2.0, -length / 2.0 + bottom_bat + dy_bat / 2.0, 0.0))
    push!(pad_list, Point(width / 2.0 - right_bat - dx_bat / 2.0, -length / 2.0 + bottom_bat + dy_bat / 2.0, 0.0))
    push!(labels, component_text(width / 2.0 - right_bat - dx_bat / 2.0, -length / 2.0 + bottom_bat + dy_bat / 2.0, 0.0, text_str="GND", line=l))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# XIAO_ESP32S3 component (similar structure to XIAO_SAMD21 but with different pinout)
function XIAO_ESP32S3(value::String="")::Component
    padl = cube(-0.04, 0.081, -0.070 / 2.0, 0.070 / 2.0, 0.0, 0.0)
    padr = cube(-0.081, 0.04, -0.070 / 2.0, 0.070 / 2.0, 0.0, 0.0)
    pitch = 0.1
    dx = 0.035
    width = 0.685
    length = 0.798
    d = 0.015
    l = 0.004
    
    # Similar pin structure to XIAO_SAMD21 (D0-D3, SDA, SCL, TX, RX, SCK, SDI, SDO, 3V3, G, 5V)
    # Plus JTAG and battery pads with different positions
    shape = translate(padl, -width / 2.0, 3 * pitch, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # Main pins 1-14 (same as XIAO_SAMD21)
    pin_labels = ["D0", "D1", "D2", "D3", "SDA", "SCL", "TX", "RX", "SCK", "SDI", "SDO", "3V3", "G", "5V"]
    for (i, label) in enumerate(pin_labels)
        if i <= 7
            y_pos = (4 - i) * pitch
            shape = union(shape, translate(padl, -width / 2.0, y_pos, 0.0))
            push!(pad_list, Point(-width / 2.0, y_pos, 0.0))
            push!(labels, component_text(-width / 2.0 + dx, y_pos, 0.0, text_str=label, line=l))
        else
            y_pos = (8 - i) * pitch
            shape = union(shape, translate(padr, width / 2.0, y_pos, 0.0))
            push!(pad_list, Point(width / 2.0, y_pos, 0.0))
            push!(labels, component_text(width / 2.0 - dx, y_pos, 0.0, text_str=label, line=l))
        end
    end
    
    # JTAG pads (different positions for ESP32S3)
    dw = 0.052
    left = 0.297
    right = 0.399
    top = 0.064
    dy = 0.099
    pad_jtag = cube(-dw / 2.0, dw / 2.0, -dw / 2.0, dw / 2.0, 0.0, 0.0)
    jtag_labels = ["MTDI", "MTDO", "EN", "GND", "MTMS", "MTCK", "D-", "D+"]
    
    for (i, label) in enumerate(jtag_labels)
        row = div(i - 1, 2)
        col = (i - 1) % 2
        x_pos = -width / 2.0 + (col == 0 ? left : right) + dw / 2.0
        y_pos = length / 2.0 - top - row * dy
        shape = union(shape, translate(pad_jtag, x_pos, y_pos, 0.0))
        push!(pad_list, Point(x_pos, y_pos, 0.0))
        push!(labels, component_text(x_pos, y_pos, 0.0, text_str=label, line=l))
    end
    
    # Battery pads
    dx_bat = 0.084
    dy_bat = 0.045
    left_bat = 0.124
    topm = 0.283
    topp = 0.359
    pad_bat = cube(-dx_bat / 2.0, dx_bat / 2.0, -dy_bat / 2.0, dy_bat / 2.0, 0.0, 0.0)
    
    shape = union(shape, translate(pad_bat, -width / 2.0 + left_bat + dx_bat / 2.0, length / 2.0 - topm - dy_bat / 2.0, 0.0))
    push!(pad_list, Point(-width / 2.0 + left_bat + dx_bat / 2.0, length / 2.0 - topm - dy_bat / 2.0, 0.0))
    push!(labels, component_text(-width / 2.0 + left_bat + dx_bat / 2.0, length / 2.0 - topm - dy_bat / 2.0, 0.0, text_str="-", line=l))
    
    shape = union(shape, translate(pad_bat, -width / 2.0 + left_bat + dx_bat / 2.0, length / 2.0 - topp - dy_bat / 2.0, 0.0))
    push!(pad_list, Point(-width / 2.0 + left_bat + dx_bat / 2.0, length / 2.0 - topp - dy_bat / 2.0, 0.0))
    push!(labels, component_text(-width / 2.0 + left_bat + dx_bat / 2.0, length / 2.0 - topp - dy_bat / 2.0, 0.0, text_str="+", line=l))
    
    # Thermal pad
    left_thermal = 0.333
    top_thermal = 0.429
    dx_thermal = 0.108
    dy_thermal = 0.100
    pad_thermal = cube(-dx_thermal / 2.0, dx_thermal / 2.0, -dy_thermal / 2.0, dy_thermal / 2.0, 0.0, 0.0)
    shape = union(shape, translate(pad_thermal, -width / 2.0 + left_thermal + dx_thermal / 2.0, length / 2.0 - top_thermal - dy_thermal / 2.0, 0.0))
    push!(pad_list, Point(-width / 2.0 + left_thermal + dx_thermal / 2.0, length / 2.0 - top_thermal - dy_thermal / 2.0, 0.0))
    push!(labels, component_text(-width / 2.0 + left_thermal + dx_thermal / 2.0, length / 2.0 - top_thermal - dy_thermal / 2.0, 0.0, text_str="thermal", line=l))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# XIAO_ESP32C3 component
function XIAO_ESP32C3(value::String="")::Component
    padl = cube(-0.04, 0.081, -0.070 / 2.0, 0.070 / 2.0, 0.0, 0.0)
    padr = cube(-0.081, 0.04, -0.070 / 2.0, 0.070 / 2.0, 0.0, 0.0)
    pitch = 0.1
    dx = 0.035
    width = 0.685
    length = 0.798
    d = 0.015
    
    shape = translate(padl, -width / 2.0, 3 * pitch, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # Main pins 1-14
    pin_labels = ["D0", "D1", "D2", "D3", "SDA", "SCL", "TX", "RX", "SCK", "SDI", "SDO", "3V3", "G", "5V"]
    for (i, label) in enumerate(pin_labels)
        if i <= 7
            y_pos = (4 - i) * pitch
            shape = union(shape, translate(padl, -width / 2.0, y_pos, 0.0))
            push!(pad_list, Point(-width / 2.0, y_pos, 0.0))
            push!(labels, component_text(-width / 2.0 + dx, y_pos, 0.0, text_str=label))
        else
            y_pos = (8 - i) * pitch
            shape = union(shape, translate(padr, width / 2.0, y_pos, 0.0))
            push!(pad_list, Point(width / 2.0, y_pos, 0.0))
            push!(labels, component_text(width / 2.0 - dx, y_pos, 0.0, text_str=label))
        end
    end
    
    # Thermal pad, +, -, and prog pads (complex geometry from Python code)
    # Thermal pad
    shape = union(shape, cube(width / 2.0 - 0.304 - d, width / 2.0 - 0.197 + d, length / 2.0 - 0.475 - d, length / 2.0 - 0.369 + d, 0.0, 0.0))
    push!(pad_list, Point(width / 2.0 - 0.197 - (0.304 - 0.197) / 2.0, length / 2.0 - 0.369 - (0.475 - 0.369) / 2.0, 0.0))
    push!(labels, component_text(width / 2.0 - 0.197 - (0.304 - 0.197) / 2.0, length / 2.0 - 0.369 - (0.475 - 0.369) / 2.0, 0.0, text_str="thermal"))
    
    # + pad
    shape = union(shape, cube(width / 2.0 - 0.555 - d, width / 2.0 - 0.477 + d, length / 2.0 - 0.402 - d, length / 2.0 - 0.362, 0.0, 0.0))
    push!(pad_list, Point(width / 2.0 - 0.477 - (0.555 - 0.477) / 2.0, length / 2.0 - 0.362 - (0.402 - 0.362) / 2.0, 0.0))
    push!(labels, component_text(width / 2.0 - 0.477 - (0.555 - 0.477) / 2.0, length / 2.0 - 0.362 - (0.402 - 0.362) / 2.0, 0.0, text_str="+"))
    
    # - pad
    shape = union(shape, cube(width / 2.0 - 0.555 - d, width / 2.0 - 0.477 + d, length / 2.0 - 0.331, length / 2.0 - 0.291 + d, 0.0, 0.0))
    push!(pad_list, Point(width / 2.0 - 0.477 - (0.555 - 0.477) / 2.0, length / 2.0 - 0.291 - (0.331 - 0.291) / 2.0, 0.0))
    push!(labels, component_text(width / 2.0 - 0.477 - (0.555 - 0.477) / 2.0, length / 2.0 - 0.291 - (0.331 - 0.291) / 2.0, 0.0, text_str="-"))
    
    # Prog pads (6 pads total)
    prog_positions = [
        (width / 2.0 - 0.312 - d, width / 2.0 - 0.271 + d, length / 2.0 - 0.086, length / 2.0 - 0.043 + d),
        (width / 2.0 - 0.413 - d, width / 2.0 - 0.368 + d, length / 2.0 - 0.086, length / 2.0 - 0.043 + d),
        (width / 2.0 - 0.312 - d, width / 2.0 - 0.271 + d, length / 2.0 - 0.186, length / 2.0 - 0.143 + d),
        (width / 2.0 - 0.413 - d, width / 2.0 - 0.368 + d, length / 2.0 - 0.186, length / 2.0 - 0.143 + d),
        (width / 2.0 - 0.312 - d, width / 2.0 - 0.271 + d, length / 2.0 - 0.286, length / 2.0 - 0.243 + d),
        (width / 2.0 - 0.413 - d, width / 2.0 - 0.368 + d, length / 2.0 - 0.286, length / 2.0 - 0.243 + d)
    ]
    
    for (x0, x1, y0, y1) in prog_positions
        shape = union(shape, cube(x0, x1, y0, y1, 0.0, 0.0))
        push!(pad_list, Point(x0 + (x1 - x0) / 2.0, y0 + (y1 - y0) / 2.0, 0.0))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# XIAO_RP2040 component
function XIAO_RP2040(value::String="")::Component
    padl = cube(-0.04, 0.081, -0.070 / 2.0, 0.070 / 2.0, 0.0, 0.0)
    padr = cube(-0.081, 0.04, -0.070 / 2.0, 0.070 / 2.0, 0.0, 0.0)
    pitch = 0.1
    dx = 0.035
    width = 0.699
    length = 0.818
    d = 0.015
    
    shape = translate(padl, -width / 2.0, 3 * pitch, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # Main pins 1-14 (same structure as other XIAO boards)
    pin_labels = ["D0", "D1", "D2", "D3", "SDA", "SCL", "TX", "RX", "SCK", "SDI", "SDO", "3V3", "G", "5V"]
    for (i, label) in enumerate(pin_labels)
        if i <= 7
            y_pos = (4 - i) * pitch
            shape = union(shape, translate(padl, -width / 2.0, y_pos, 0.0))
            push!(pad_list, Point(-width / 2.0, y_pos, 0.0))
            push!(labels, component_text(-width / 2.0 + dx, y_pos, 0.0, text_str=label))
        else
            y_pos = (8 - i) * pitch
            shape = union(shape, translate(padr, width / 2.0, y_pos, 0.0))
            push!(pad_list, Point(width / 2.0, y_pos, 0.0))
            push!(labels, component_text(width / 2.0 - dx, y_pos, 0.0, text_str=label))
        end
    end
    
    # VIN pad
    shape = union(shape, cube(width / 2.0 - 0.418 - d, width / 2.0 - 0.376 + d, length / 2.0 - 0.798 - d, length / 2.0 - 0.714 + d, 0.0, 0.0))
    push!(pad_list, Point(width / 2.0 - 0.376 - (0.418 - 0.376) / 2.0, length / 2.0 - 0.714 - (0.798 - 0.714) / 2.0, 0.0))
    push!(labels, component_text(width / 2.0 - 0.376 - (0.418 - 0.376) / 2.0, length / 2.0 - 0.714 - (0.798 - 0.714) / 2.0, 0.0, text_str="VIN"))
    
    # GND pad
    shape = union(shape, cube(width / 2.0 - 0.317 - d, width / 2.0 - 0.275 + d, length / 2.0 - 0.798 - d, length / 2.0 - 0.714 + d, 0.0, 0.0))
    push!(pad_list, Point(width / 2.0 - 0.275 - (0.317 - 0.275) / 2.0, length / 2.0 - 0.714 - (0.798 - 0.714) / 2.0, 0.0))
    push!(labels, component_text(width / 2.0 - 0.275 - (0.317 - 0.275) / 2.0, length / 2.0 - 0.714 - (0.798 - 0.714) / 2.0, 0.0, text_str="GND"))
    
    # Prog pads (4 pads)
    prog_positions = [
        (width / 2.0 - 0.320 - d, width / 2.0 - 0.276 + d, length / 2.0 - 0.107 - d, length / 2.0 - 0.060 + d),
        (width / 2.0 - 0.424 - d, width / 2.0 - 0.376 + d, length / 2.0 - 0.107 - d, length / 2.0 - 0.060 + d),
        (width / 2.0 - 0.424 - d, width / 2.0 - 0.376 + d, length / 2.0 - 0.209 - d, length / 2.0 - 0.161 + d),
        (width / 2.0 - 0.320 - d, width / 2.0 - 0.276 + d, length / 2.0 - 0.209 - d, length / 2.0 - 0.161 + d)
    ]
    
    for (x0, x1, y0, y1) in prog_positions
        shape = union(shape, cube(x0, x1, y0, y1, 0.0, 0.0))
        push!(pad_list, Point(x0 + (x1 - x0) / 2.0, y0 + (y1 - y0) / 2.0, 0.0))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# ATtiny1624_SOIC component
function ATtiny1624_SOIC(value::String="")::Component
    d = 0.11
    w = 0.015
    h = 0.03
    pad = cube(-h, h, -w, w, 0.0, 0.0)
    
    shape = translate(pad, -d, 0.15, 0.0)
    shape = union(shape, cylinder(-d - h, 0.15, 0.0, 0.0, w))
    pad_list = [Point(0.0, 0.0, 0.0), Point(-d, 0.15, 0.0)]
    labels = [component_text(-d, 0.15, 0.0, text_str=".VCC")]
    
    # Pins 2-14
    pin_positions = [0.1, 0.05, 0.0, -0.05, -0.1, -0.15]
    pin_labels_left = ["PA4", "PA5", "PA6", "PA7", "PB3", "PB2"]
    pin_labels_right = ["PB1", "PB0", "UPDI", "PA1", "PA2", "PA3", "GND"]
    
    for (i, y_pos) in enumerate(pin_positions)
        if i <= 6
            shape = union(shape, translate(pad, -d, y_pos, 0.0))
            push!(pad_list, Point(-d, y_pos, 0.0))
            push!(labels, component_text(-d, y_pos, 0.0, text_str=pin_labels_left[i]))
        end
    end
    
    # Right side pins
    for (i, y_pos) in enumerate(reverse(pin_positions))
        if i <= 7
            shape = union(shape, translate(pad, d, y_pos, 0.0))
            push!(pad_list, Point(d, y_pos, 0.0))
            push!(labels, component_text(d, y_pos, 0.0, text_str=pin_labels_right[i]))
        end
    end
    
    # Pin 14 (GND)
    shape = union(shape, translate(pad, d, 0.15, 0.0))
    push!(pad_list, Point(d, 0.15, 0.0))
    push!(labels, component_text(d, 0.15, 0.0, text_str="GND"))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# ATtiny1614 component
function ATtiny1614(value::String="")::Component
    d = 0.11
    w = 0.015
    h = 0.03
    pad = cube(-h, h, -w, w, 0.0, 0.0)
    
    shape = translate(pad, -d, 0.15, 0.0)
    shape = union(shape, cylinder(-d - h, 0.15, 0.0, 0.0, w))
    pad_list = [Point(0.0, 0.0, 0.0), Point(-d, 0.15, 0.0)]
    labels = [component_text(-d, 0.15, 0.0, text_str=".VCC")]
    
    # Similar structure to ATtiny1624 but with different pin labels
    pin_positions = [0.1, 0.05, 0.0, -0.05, -0.1, -0.15]
    pin_labels_left = ["PA4", "PA5", "PA6", "PA7", "PB3", "PB2"]
    pin_labels_right = ["PB1", "PB0", "UPDI", "PA1", "PA2", "PA3", "GND"]
    
    for (i, y_pos) in enumerate(pin_positions)
        if i <= 6
            shape = union(shape, translate(pad, -d, y_pos, 0.0))
            push!(pad_list, Point(-d, y_pos, 0.0))
            push!(labels, component_text(-d, y_pos, 0.0, text_str=pin_labels_left[i]))
        end
    end
    
    for (i, y_pos) in enumerate(reverse(pin_positions))
        if i <= 7
            shape = union(shape, translate(pad, d, y_pos, 0.0))
            push!(pad_list, Point(d, y_pos, 0.0))
            push!(labels, component_text(d, y_pos, 0.0, text_str=pin_labels_right[i]))
        end
    end
    
    shape = union(shape, translate(pad, d, 0.15, 0.0))
    push!(pad_list, Point(d, 0.15, 0.0))
    push!(labels, component_text(d, 0.15, 0.0, text_str="GND"))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# ATtiny412 component
function ATtiny412(value::String="")::Component
    d = 0.11
    w = 0.015
    h = 0.03
    pad = cube(-h, h, -w, w, 0.0, 0.0)
    
    shape = translate(pad, -d, 0.075, 0.0)
    shape = union(shape, cylinder(-d - h, 0.075, 0.0, 0.0, w))
    pad_list = [Point(0.0, 0.0, 0.0), Point(-d, 0.075, 0.0)]
    labels = [component_text(-d, 0.075, 0.0, text_str="VCC")]
    
    # 8-pin SOIC
    pin_positions = [0.025, -0.025, -0.075]
    pin_labels_left = ["PA6", "PA7", "PA1"]
    pin_labels_right = ["PA2", "UPDI", "PA3", "GND"]
    
    for (i, y_pos) in enumerate(pin_positions)
        shape = union(shape, translate(pad, -d, y_pos, 0.0))
        push!(pad_list, Point(-d, y_pos, 0.0))
        push!(labels, component_text(-d, y_pos, 0.0, text_str=pin_labels_left[i]))
    end
    
    for (i, y_pos) in enumerate(reverse(pin_positions))
        shape = union(shape, translate(pad, d, y_pos, 0.0))
        push!(pad_list, Point(d, y_pos, 0.0))
        push!(labels, component_text(d, y_pos, 0.0, text_str=pin_labels_right[i]))
    end
    
    shape = union(shape, translate(pad, d, 0.075, 0.0))
    push!(pad_list, Point(d, 0.075, 0.0))
    push!(labels, component_text(d, 0.075, 0.0, text_str="GND"))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# TB67H451A component
function TB67H451A(value::String="")::Component
    shape = translate(pad_SOIC, -0.11, 0.075, 0.0)
    shape = union(shape, cylinder(-0.153, 0.075, 0.0, 0.0, 0.015))
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.11, 0.075, 0.0)]
    labels = [component_text(-0.11, 0.075, 0.0, text_str="GND.")]
    
    # Pins 2-8
    pin_positions = [0.025, -0.025, -0.075]
    pin_labels_left = ["IN2", "IN1", "VREF"]
    pin_labels_right = ["VBB", "OUT1", "LSS", "OUT2"]
    
    for (i, y_pos) in enumerate(pin_positions)
        shape = union(shape, translate(pad_SOIC, -0.11, y_pos, 0.0))
        push!(pad_list, Point(-0.11, y_pos, 0.0))
        push!(labels, component_text(-0.11, y_pos, 0.0, text_str=pin_labels_left[i]))
    end
    
    for (i, y_pos) in enumerate(reverse(pin_positions))
        shape = union(shape, translate(pad_SOIC, 0.11, y_pos, 0.0))
        push!(pad_list, Point(0.11, y_pos, 0.0))
        push!(labels, component_text(0.11, y_pos, 0.0, text_str=pin_labels_right[i]))
    end
    
    shape = union(shape, translate(pad_SOIC, 0.11, 0.075, 0.0))
    push!(pad_list, Point(0.11, 0.075, 0.0))
    push!(labels, component_text(0.11, 0.075, 0.0, text_str="OUT2"))
    
    # Thermal pad
    shape = union(shape, rectangle(-0.04, 0.04, -0.075, 0.075))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# microSD component
function microSD(value::String="")::Component
    pad_size = cube(-0.0138, 0.0138, -0.034, 0.034, 0.0, 0.0)
    shape = translate(pad_size, -0.177 + 7 * 0.0433, -0.304, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # Pins 1-8
    pin_labels = [".NC", "CS", "SDI", "VCC", "SCK", "GND", "SDO", "NC"]
    for i in 0:7
        x_pos = -0.177 + (7 - i) * 0.0433
        y_pos = -0.304
        shape = union(shape, translate(pad_size, x_pos, y_pos, 0.0))
        push!(pad_list, Point(x_pos, y_pos, 0.0))
        push!(labels, component_text(x_pos, y_pos, 0.0, text_str=pin_labels[i + 1], angle=90.0))
    end
    
    # Feet pads
    feet_pads = [
        (cube(-0.021, 0.021, -0.029, 0.029, 0.0, 0.0), -0.228, -0.299),
        (cube(-0.029, 0.029, -0.029, 0.029, 0.0, 0.0), 0.222, -0.299),
        (cube(-0.015, 0.015, -0.029, 0.025, 0.0, 0.0), -0.232, 0.0),
        (cube(-0.015, 0.015, -0.029, 0.029, 0.0, 0.0), -0.232 + 0.47, 0.025),
        (cube(-0.028, 0.028, -0.019, 0.019, 0.0, 0.0), -0.221, 0.059),
        (cube(-0.019, 0.019, -0.030, 0.030, 0.0, 0.0), 0.222, 0.121)
    ]
    
    for (pad_shape, x, y) in feet_pads
        shape = union(shape, translate(pad_shape, x, y, 0.0))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# slide_switch component
function slide_switch(value::String="")::Component
    pad = cube(-0.039 / 2.0, 0.039 / 2.0, -0.047 / 2.0, 0.047 / 2.0, 0.0, 0.0)
    
    shape = translate(pad, -0.098, 0.1, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.098, 0.1, 0.0), Point(0.0, 0.1, 0.0), Point(0.098, 0.1, 0.0)]
    labels = [
        component_text(-0.098, 0.1, 0.0, text_str=""),
        component_text(0.0, 0.1, 0.0, text_str=""),
        component_text(0.098, 0.1, 0.0, text_str="")
    ]
    
    shape = union(shape, translate(pad, 0.0, 0.1, 0.0))
    shape = union(shape, translate(pad, 0.098, 0.1, 0.0))
    
    # Holes (requires zb, zt parameters - will be set when component is used)
    # Note: holes will be added when component is placed on PCB
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# SMD_wire_entry component
function SMD_wire_entry(value::String="")::Component
    pad1 = cube(-0.199 / 2.0, 0.169 / 2.0, -0.079 / 2.0, 0.079 / 2.0, 0.0, 0.0)
    l1 = 0.169
    pad2 = cube(-0.228 / 2.0, 0.258 / 2.0, -0.079 / 2.0, 0.079 / 2.0, 0.0, 0.0)
    l2 = 0.228
    gap = 0.106
    
    shape = translate(pad1, -gap / 2.0 - l1 / 2.0, 0.0, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-gap / 2.0 - l1 / 2.0, 0.0, 0.0), Point(gap / 2.0 + l2 / 2.0, 0.0, 0.0)]
    labels = [
        component_text(-gap / 2.0 - l1 / 2.0, 0.0, 0.0, text_str="1"),
        component_text(gap / 2.0 + l2 / 2.0, 0.0, 0.0, text_str="2")
    ]
    
    shape = union(shape, translate(pad2, gap / 2.0 + l2 / 2.0, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# hole_pad component
function hole_pad(value::String, zb::Float64, zt::Float64)::Component
    pad_header_local = cylinder(0.0, 0.0, zb, zt, 0.03)
    pad_hole = cylinder(0.0, 0.0, zb, zt, 0.018)
    
    shape = translate(pad_header_local, 0.0, 0.0, 0.0)
    holes = translate(pad_hole, 0.0, 0.0, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.0, 0.0)]
    
    return Component(shape, pad_list, ComponentText[], value, holes, nothing)
end

# header_APA component
function header_APA(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.05, 0.0)
    shape = union(shape, cylinder(0.157, -0.05, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.05, 0.0), Point(-0.107, -0.05, 0.0), Point(0.107, 0.05, 0.0), Point(-0.107, 0.05, 0.0)]
    labels = [
        component_text(0.107, -0.05, 0.0, text_str="GND"),
        component_text(-0.107, -0.05, 0.0, text_str="in"),
        component_text(0.107, 0.05, 0.0, text_str="V"),
        component_text(-0.107, 0.05, 0.0, text_str="out")
    ]
    
    shape = union(shape, translate(pad_header, -0.107, -0.05, 0.0))
    shape = union(shape, translate(pad_header, 0.107, 0.05, 0.0))
    shape = union(shape, translate(pad_header, -0.107, 0.05, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_6 component
function header_6(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.1, 0.0)
    shape = union(shape, cylinder(0.157, -0.1, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 6 pins in 2x3 configuration
    pin_positions = [-0.1, 0.0, 0.1]
    for y_pos in pin_positions
        shape = union(shape, translate(pad_header, 0.107, y_pos, 0.0))
        push!(pad_list, Point(0.107, y_pos, 0.0))
        push!(labels, component_text(0.107, y_pos, 0.0, text_str=""))
        
        shape = union(shape, translate(pad_header, -0.107, y_pos, 0.0))
        push!(pad_list, Point(-0.107, y_pos, 0.0))
        push!(labels, component_text(-0.107, y_pos, 0.0, text_str=""))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_ATP component
function header_ATP(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.1, 0.0)
    shape = union(shape, cylinder(0.157, -0.1, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.1, 0.0)]
    labels = [component_text(0.107, -0.1, 0.0, text_str="BI")]
    
    # 6 pins with ATP labels
    pin_positions = [(-0.107, -0.1, "BO"), (0.107, 0.0, "AI"), (-0.107, 0.0, "AO"), (0.107, 0.1, "BI"), (-0.107, 0.1, "BO")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_PDI component
function header_PDI(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.1, 0.0)
    shape = union(shape, cylinder(0.157, -0.1, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.1, 0.0)]
    labels = [component_text(0.107, -0.1, 0.0, text_str="DAT")]
    
    # 6 pins with PDI labels
    pin_positions = [(-0.107, -0.1, "VCC"), (0.107, 0.0, "NC"), (-0.107, 0.0, "NC"), (0.107, 0.1, "CLK"), (-0.107, 0.1, "GND")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_ISP component
function header_ISP(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.1, 0.0)
    shape = union(shape, cylinder(0.157, -0.1, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.1, 0.0)]
    labels = [component_text(0.107, -0.1, 0.0, text_str="MISO")]
    
    # 6 pins with ISP labels
    pin_positions = [(-0.107, -0.1, "V"), (0.107, 0.0, "SCK"), (-0.107, 0.0, "MOSI"), (0.107, 0.1, "RST"), (-0.107, 0.1, "GND")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_nRF24L01 component
function header_nRF24L01(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.15, 0.0)
    shape = union(shape, cylinder(0.157, -0.15, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.15, 0.0)]
    labels = [component_text(0.107, -0.15, 0.0, text_str="GND")]
    
    # 8 pins with nRF24L01 labels
    pin_positions = [
        (-0.107, -0.15, "VCC"), (0.107, -0.05, "CE"), (-0.107, -0.05, "CS"),
        (0.107, 0.05, "SCK"), (-0.107, 0.05, "MOSI"), (0.107, 0.15, "MISO")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_servo component
function header_servo(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.1, 0.0)
    shape = union(shape, cylinder(0.157, -0.1, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.1, 0.0)]
    labels = [component_text(0.107, -0.1, 0.0, text_str="G/blk")]
    
    # 6 pins with servo labels
    pin_positions = [
        (-0.107, -0.1, "G/blk"), (0.107, 0.0, "V/red"), (-0.107, 0.0, "V/red"),
        (0.107, 0.1, "S0/wht"), (-0.107, 0.1, "S1/wht")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_unipolar_stepper component
function header_unipolar_stepper(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.1, 0.0)
    shape = union(shape, cylinder(0.157, -0.1, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.1, 0.0)]
    labels = [component_text(0.107, -0.1, 0.0, text_str="red")]
    
    # 6 pins with color labels
    pin_positions = [
        (-0.107, -0.1, "green"), (0.107, 0.0, "black"), (-0.107, 0.0, "brown"),
        (0.107, 0.1, "orange"), (-0.107, 0.1, "yellow")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_LCD component
function header_LCD(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.2, 0.0)
    shape = union(shape, cylinder(0.157, -0.2, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 10 pins with LCD labels
    pin_positions = [
        (0.107, -0.2, "DB7\n14"), (-0.107, -0.2, "DB6\n13"), (0.107, -0.1, "DB5\n12"),
        (-0.107, -0.1, "DB4\n11"), (0.107, 0.0, "E\n6"), (-0.107, 0.0, "R/W\n5"),
        (0.107, 0.1, "RS\n4"), (-0.107, 0.1, "Vee\n3"), (0.107, 0.2, "Vcc\n2"),
        (-0.107, 0.2, "GND\n1")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_serial_reverse component
function header_serial_reverse(value::String="")::Component
    shape = translate(pad_header, 0.0, -0.25, 0.0)
    shape = union(shape, cylinder(-0.05, -0.25, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, -0.25, 0.0)]
    labels = [component_text(0.0, -0.25, 0.0, text_str="GND")]
    
    # 6 pins with serial reverse labels
    pin_positions = [
        (0.0, -0.15, "CTS"), (0.0, -0.05, "VCC"), (0.0, 0.05, "Tx"),
        (0.0, 0.15, "Rx"), (0.0, 0.25, "RTS")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_FTDI component
function header_FTDI(value::String="")::Component
    shape = translate(pad_header, 0.0, 0.25, 0.0)
    shape = union(shape, cylinder(-0.05, 0.25, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.25, 0.0)]
    labels = [component_text(0.0, 0.25, 0.0, text_str="GND")]
    
    # 6 pins with FTDI labels
    pin_positions = [
        (0.0, 0.15, "CTS"), (0.0, 0.05, "VCC"), (0.0, -0.05, "Tx"),
        (0.0, -0.15, "Rx"), (0.0, -0.25, "RTS")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# MTA_2 component
function MTA_2(value::String="")::Component
    shape = translate(pad_MTA, -0.025, -0.1, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.025, -0.1, 0.0), Point(0.025, 0.1, 0.0)]
    labels = [
        component_text(-0.025, -0.1, 0.0, text_str="1"),
        component_text(0.025, 0.1, 0.0, text_str="2")
    ]
    
    shape = union(shape, translate(pad_MTA, 0.025, 0.1, 0.0))
    shape = union(shape, translate(pad_MTA_solder, -0.187, 0.0, 0.0))
    shape = union(shape, translate(pad_MTA_solder, 0.187, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# MTA_power component
function MTA_power(value::String="")::Component
    shape = translate(pad_MTA, -0.025, -0.1, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.025, -0.1, 0.0), Point(0.025, 0.1, 0.0)]
    labels = [
        component_text(-0.025, -0.1, 0.0, text_str="1\nGND"),
        component_text(0.025, 0.1, 0.0, text_str="Vcc")
    ]
    
    shape = union(shape, translate(pad_MTA, 0.025, 0.1, 0.0))
    shape = union(shape, translate(pad_MTA_solder, -0.187, 0.0, 0.0))
    shape = union(shape, translate(pad_MTA_solder, 0.187, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# MTA_3 component
function MTA_3(value::String="")::Component
    shape = translate(pad_MTA, 0.05, 0.1, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.05, 0.1, 0.0), Point(-0.05, 0.1, 0.0), Point(0.0, -0.1, 0.0)]
    labels = [
        component_text(0.05, 0.1, 0.0, text_str="1"),
        component_text(-0.05, 0.1, 0.0, text_str="2"),
        component_text(0.0, -0.1, 0.0, text_str="3")
    ]
    
    shape = union(shape, translate(pad_MTA, -0.05, 0.1, 0.0))
    shape = union(shape, translate(pad_MTA, 0.0, -0.1, 0.0))
    shape = union(shape, translate(pad_MTA_solder, -0.212, 0.0, 0.0))
    shape = union(shape, translate(pad_MTA_solder, 0.212, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# MTA_i0 component
function MTA_i0(value::String="")::Component
    shape = translate(pad_MTA, 0.05, 0.1, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.05, 0.1, 0.0), Point(-0.05, 0.1, 0.0), Point(0.0, -0.1, 0.0)]
    labels = [
        component_text(0.05, 0.1, 0.0, text_str="1\nGND"),
        component_text(-0.05, 0.1, 0.0, text_str="V"),
        component_text(0.0, -0.1, 0.0, text_str="data")
    ]
    
    shape = union(shape, translate(pad_MTA, -0.05, 0.1, 0.0))
    shape = union(shape, translate(pad_MTA, 0.0, -0.1, 0.0))
    shape = union(shape, translate(pad_MTA_solder, -0.212, 0.0, 0.0))
    shape = union(shape, translate(pad_MTA_solder, 0.212, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# MTA_4 component
function MTA_4(value::String="")::Component
    shape = translate(pad_MTA, 0.075, 0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 4 pins
    pin_positions = [(0.075, 0.15, "1"), (-0.075, 0.15, "2"), (0.075, -0.15, "3"), (-0.075, -0.15, "4")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_MTA, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    shape = union(shape, translate(pad_MTA_solder, -0.237, 0.0, 0.0))
    shape = union(shape, translate(pad_MTA_solder, 0.237, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# MTA_serial component
function MTA_serial(value::String="")::Component
    shape = translate(pad_MTA, 0.075, 0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 4 pins with serial labels
    pin_positions = [(0.075, 0.15, "Rx"), (-0.075, 0.15, "Tx"), (0.075, -0.15, "GND"), (-0.075, -0.15, "V")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_MTA, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    shape = union(shape, translate(pad_MTA_solder, -0.237, 0.0, 0.0))
    shape = union(shape, translate(pad_MTA_solder, 0.237, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# MTA_PS2 component
function MTA_PS2(value::String="")::Component
    shape = translate(pad_MTA, 0.075, 0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 4 pins with PS2 labels
    pin_positions = [(0.075, 0.15, "data"), (-0.075, 0.15, "clock"), (0.075, -0.15, "V"), (-0.075, -0.15, "GND")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_MTA, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    shape = union(shape, translate(pad_MTA_solder, -0.237, 0.0, 0.0))
    shape = union(shape, translate(pad_MTA_solder, 0.237, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# MTA_5 component
function MTA_5(value::String="")::Component
    shape = translate(pad_MTA, 0.1, 0.2, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 5 pins
    pin_positions = [(0.1, 0.2, "1"), (-0.1, 0.2, "2"), (0.1, 0.0, "3"), (-0.1, 0.0, "4"), (0.1, -0.2, "5")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_MTA, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    shape = union(shape, translate(pad_MTA_solder, -0.262, 0.0, 0.0))
    shape = union(shape, translate(pad_MTA_solder, 0.262, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# MTA_ICP component
function MTA_ICP(value::String="")::Component
    shape = translate(pad_MTA, 0.1, 0.2, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 5 pins with ICP labels
    pin_positions = [(0.1, 0.2, "MISO"), (-0.1, 0.2, "VCC"), (0.1, 0.0, "SCK"), (-0.1, 0.0, "MOSI"), (0.1, -0.2, "GND")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_MTA, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    shape = union(shape, translate(pad_MTA_solder, -0.262, 0.0, 0.0))
    shape = union(shape, translate(pad_MTA_solder, 0.262, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# screw_terminal_2 component
function screw_terminal_2(value::String="")::Component
    shape = translate(pad_screw_terminal, -0.069, 0.0, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.069, 0.0, 0.0), Point(0.069, 0.0, 0.0)]
    labels = [
        component_text(-0.069, 0.0, 0.0, text_str="1"),
        component_text(0.069, 0.0, 0.0, text_str="2")
    ]
    
    shape = union(shape, translate(pad_screw_terminal, 0.069, 0.0, 0.0))
    # Note: holes would be added when component is placed (requires zb, zt)
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# screw_terminal_power component
function screw_terminal_power(value::String="")::Component
    shape = translate(pad_screw_terminal, -0.069, 0.0, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.069, 0.0, 0.0), Point(0.069, 0.0, 0.0)]
    labels = [
        component_text(-0.069, 0.0, 0.0, text_str="G"),
        component_text(0.069, 0.0, 0.0, text_str="V")
    ]
    
    shape = union(shape, translate(pad_screw_terminal, 0.069, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# screw_terminal_i0 component
function screw_terminal_i0(value::String="")::Component
    shape = translate(pad_screw_terminal, -0.138, 0.0, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.138, 0.0, 0.0), Point(0.0, 0.0, 0.0), Point(0.138, 0.0, 0.0)]
    labels = [
        component_text(-0.138, 0.0, 0.0, text_str="Gnd\n1"),
        component_text(0.0, 0.0, 0.0, text_str="data"),
        component_text(0.138, 0.0, 0.0, text_str="V")
    ]
    
    shape = union(shape, pad_screw_terminal)
    shape = union(shape, translate(pad_screw_terminal, 0.138, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# power_65mm component
function power_65mm(value::String="")::Component
    shape = cube(0.433, 0.512, -0.047, 0.047, 0.0, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.467, 0.0, 0.0), Point(0.354, -0.144, 0.0), Point(0.394, 0.144, 0.0)]
    labels = [
        component_text(0.467, 0.0, 0.0, text_str="P"),
        component_text(0.354, -0.144, 0.0, text_str="G"),
        component_text(0.394, 0.144, 0.0, text_str="C")
    ]
    
    shape = union(shape, cube(0.285, 0.423, -0.189, -0.098, 0.0, 0.0))
    shape = union(shape, cube(0.325, 0.463, 0.098, 0.189, 0.0, 0.0))
    shape = union(shape, cube(0.108, 0.246, -0.169, -0.110, 0.0, 0.0))
    shape = union(shape, cube(0.069, 0.207, 0.110, 0.169, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# stereo_2_5mm component
function stereo_2_5mm(value::String="")::Component
    shape = translate(pad_stereo_2_5mm, -0.130, -0.16, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.130, -0.149, 0.0), Point(0.197, 0.141, 0.0), Point(-0.012, -0.149, 0.0)]
    labels = [
        component_text(-0.130, -0.149, 0.0, text_str="base"),
        component_text(0.197, 0.141, 0.0, text_str="tip"),
        component_text(-0.012, -0.149, 0.0, text_str="middle")
    ]
    
    shape = union(shape, translate(pad_stereo_2_5mm, 0.197, 0.15, 0.0))
    shape = union(shape, translate(pad_stereo_2_5mm, -0.012, -0.16, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# Molex_serial component
function Molex_serial(value::String="")::Component
    shape = translate(pad_Molex, -0.075, 0.064, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.075, 0.064, 0.0), Point(-0.025, 0.064, 0.0), Point(0.025, 0.064, 0.0), Point(0.075, 0.064, 0.0)]
    labels = [
        component_text(-0.075, 0.064, 0.0, text_str="Rx"),
        component_text(-0.025, 0.064, 0.0, text_str="Tx"),
        component_text(0.025, 0.064, 0.0, text_str="DTR"),
        component_text(0.075, 0.064, 0.0, text_str="GND")
    ]
    
    shape = union(shape, translate(pad_Molex, -0.025, 0.064, 0.0))
    shape = union(shape, translate(pad_Molex, 0.025, 0.064, 0.0))
    shape = union(shape, translate(pad_Molex, 0.075, 0.064, 0.0))
    shape = union(shape, translate(pad_Molex_solder, -0.16, -0.065, 0.0))
    shape = union(shape, translate(pad_Molex_solder, 0.16, -0.065, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_I2C_hole component
function header_I2C_hole(value::String, zb::Float64, zt::Float64)::Component
    pad_header_local = cylinder(0.0, 0.0, zb, zt, 0.04)
    pad_hole = cylinder(0.0, 0.0, zb, zt, 0.018)
    
    shape = translate(pad_header_local, 0.0, 0.15, 0.0)
    holes = translate(pad_hole, 0.0, 0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.15, 0.0)]
    labels = [component_text(0.0, 0.15, 0.0, text_str="SDA")]
    
    # 4 pins
    pin_positions = [(0.0, 0.05, "SCL"), (0.0, -0.05, "VCC"), (0.0, -0.15, "GND")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        holes = union(holes, translate(pad_hole, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, holes, nothing)
end

# header_IMU_3463_hole component
function header_IMU_3463_hole(value::String, zb::Float64, zt::Float64)::Component
    pad_header_local = cylinder(0.0, 0.0, zb, zt, 0.03)
    pad_hole = cylinder(0.0, 0.0, zb, zt, 0.018)
    
    shape = translate(pad_header_local, 0.0, 0.25, 0.0)
    holes = translate(pad_hole, 0.0, 0.25, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.25, 0.0)]
    labels = [component_text(0.0, 0.25, 0.0, text_str="Vin")]
    
    # 6 pins
    pin_positions = [(0.0, 0.15, "3.3"), (0.0, 0.05, "GND"), (0.0, -0.05, "SCL"), (0.0, -0.15, "SDA"), (0.0, -0.25, "RST")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        holes = union(holes, translate(pad_hole, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, holes, nothing)
end

# header_IMU_3463 component
function header_IMU_3463(value::String="")::Component
    pad_header_local = cylinder(0.0, 0.0, 0.0, 0.0, 0.03)
    
    shape = translate(pad_header_local, 0.0, 0.25, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.25, 0.0)]
    labels = [component_text(0.0, 0.25, 0.0, text_str="Vin")]
    
    # 6 pins
    pin_positions = [(0.0, 0.15, "3.3"), (0.0, 0.05, "GND"), (0.0, -0.05, "SCL"), (0.0, -0.15, "SDA"), (0.0, -0.25, "RST")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_IMU_2472 component
function header_IMU_2472(value::String="")::Component
    pad_header_local = cylinder(0.0, 0.0, 0.0, 0.0, 0.03)
    
    shape = translate(pad_header_local, 0.0, 0.25, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.25, 0.0)]
    labels = [component_text(0.0, 0.25, 0.0, text_str="Vin")]
    
    # 6 pins
    pin_positions = [(0.0, 0.15, "3.3"), (0.0, 0.05, "GND"), (0.0, -0.05, "SDA"), (0.0, -0.15, "SCL"), (0.0, -0.25, "RST")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_IMU_2738 component
function header_IMU_2738(value::String="")::Component
    pad_header_local = cylinder(0.0, 0.0, 0.0, 0.0, 0.03)
    
    shape = translate(pad_header_local, 0.0, 0.2, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.2, 0.0)]
    labels = [component_text(0.0, 0.2, 0.0, text_str="1SCL")]
    
    # 5 pins
    pin_positions = [(0.0, 0.1, "SDA"), (0.0, 0.0, "GND"), (0.0, -0.1, "VIN"), (0.0, -0.2, "VDD")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_serial_M component
function header_serial_M(value::String="")::Component
    shape = translate(pad_header, 0.0, 0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.15, 0.0)]
    labels = [component_text(0.0, 0.15, 0.0, text_str=".Rx")]
    
    # 4 pins
    pin_positions = [(0.0, 0.05, "Tx"), (0.0, -0.05, "5V"), (0.0, -0.15, "G")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_serial_Frev component
function header_serial_Frev(value::String="")::Component
    shape = translate(pad_header, 0.0, 0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.15, 0.0)]
    labels = [component_text(0.0, 0.15, 0.0, text_str=".G")]
    
    # 4 pins
    pin_positions = [(0.0, 0.05, "5V"), (0.0, -0.05, "Tx"), (0.0, -0.15, "Rx")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_serial_F component
function header_serial_F(value::String="")::Component
    shape = translate(pad_header, 0.0, 0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.15, 0.0)]
    labels = [component_text(0.0, 0.15, 0.0, text_str=".G")]
    
    # 4 pins
    pin_positions = [(0.0, 0.05, "5V"), (0.0, -0.05, "Rx"), (0.0, -0.15, "Tx")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_2H component
function header_2H(value::String="")::Component
    shape = translate(pad_header, 0.0, 0.05, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.05, 0.0), Point(0.0, -0.05, 0.0)]
    labels = [
        component_text(0.0, 0.05, 0.0, text_str="1"),
        component_text(0.0, -0.05, 0.0, text_str="2")
    ]
    
    shape = union(shape, translate(pad_header, 0.0, -0.05, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_3H component
function header_3H(value::String="")::Component
    shape = translate(pad_header, 0.0, 0.1, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.1, 0.0), Point(0.0, 0.0, 0.0), Point(0.0, -0.1, 0.0)]
    labels = [
        component_text(0.0, 0.1, 0.0, text_str="1"),
        component_text(0.0, 0.0, 0.0, text_str="2"),
        component_text(0.0, -0.1, 0.0, text_str="3")
    ]
    
    shape = union(shape, pad_header)
    shape = union(shape, translate(pad_header, 0.0, -0.1, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_4H component
function header_4H(value::String="")::Component
    shape = translate(pad_header, 0.0, 0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 4 pins
    pin_positions = [(0.0, 0.15, "1"), (0.0, 0.05, "2"), (0.0, -0.05, "3"), (0.0, -0.15, "4")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_NEO_6M component
function header_NEO_6M(value::String="")::Component
    pad_header_local = cylinder(0.0, 0.0, 0.0, 0.0, 0.03)
    
    shape = translate(pad_header_local, 0.0, 0.2, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.2, 0.0)]
    labels = [component_text(0.0, 0.2, 0.0, text_str="PPS")]
    
    # 4 pins
    pin_positions = [(0.0, 0.1, "TX"), (0.0, 0.0, "RX"), (0.0, -0.1, "GND"), (0.0, -0.2, "VCC")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_MFRC522 component
function header_MFRC522(value::String="")::Component
    pad_header_local = cylinder(0.0, 0.0, 0.0, 0.0, 0.03)
    
    shape = translate(pad_header_local, 0.0, 0.35, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 8 pins
    pin_positions = [
        (0.0, 0.35, "1SDA"), (0.0, 0.25, "SCK"), (0.0, 0.15, "COPI"), (0.0, 0.05, "CIPO"),
        (0.0, -0.05, "IRQ"), (0.0, -0.15, "GND"), (0.0, -0.25, "RST"), (0.0, -0.35, "3.3V")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_LSM6DS33_2736 component
function header_LSM6DS33_2736(value::String="")::Component
    pad_header_local = cylinder(0.0, 0.0, 0.0, 0.0, 0.03)
    
    shape = translate(pad_header_local, 0.0, 0.4, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 9 pins
    pin_positions = [
        (0.0, 0.4, "1VDD"), (0.0, 0.3, "VIN"), (0.0, 0.2, "GND"), (0.0, 0.1, "SDA"),
        (0.0, 0.0, "SCL"), (0.0, -0.1, "SDO"), (0.0, -0.2, "CS"), (0.0, -0.3, "INT2"),
        (0.0, -0.4, "INT1")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_VL53L1X_3415 component
function header_VL53L1X_3415(value::String="")::Component
    pad_header_local = cylinder(0.0, 0.0, 0.0, 0.0, 0.03)
    
    shape = translate(pad_header_local, 0.0, 0.3, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 7 pins
    pin_positions = [
        (0.0, 0.3, "1VDD"), (0.0, 0.2, "VIN"), (0.0, 0.1, "GND"), (0.0, 0.0, "SDA"),
        (0.0, -0.1, "SCL"), (0.0, -0.2, "XSHUT"), (0.0, -0.3, "GPIO1")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_serial_reverse_5V component
function header_serial_reverse_5V(value::String="")::Component
    shape = translate(pad_header, 0.0, -0.25, 0.0)
    shape = union(shape, cylinder(-0.05, -0.25, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, -0.25, 0.0)]
    labels = [component_text(0.0, -0.25, 0.0, text_str="GND")]
    
    # 6 pins
    pin_positions = [(0.0, -0.15, "CTS"), (0.0, -0.05, "5V"), (0.0, 0.05, "Tx"), (0.0, 0.15, "Rx"), (0.0, 0.25, "RTS")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_serial_reverse_3V3 component
function header_serial_reverse_3V3(value::String="")::Component
    shape = translate(pad_header, 0.0, -0.25, 0.0)
    shape = union(shape, cylinder(-0.05, -0.25, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, -0.25, 0.0)]
    labels = [component_text(0.0, -0.25, 0.0, text_str="GND")]
    
    # 6 pins
    pin_positions = [(0.0, -0.15, "CTS"), (0.0, -0.05, "3.3V"), (0.0, 0.05, "Tx"), (0.0, 0.15, "Rx"), (0.0, 0.25, "RTS")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# TFT8x1v component
function TFT8x1v(value::String="")::Component
    pad_header_local = cube(-0.079 / 2.0, 0.079 / 2.0, -0.039 / 2.0, 0.039 / 2.0, 0.0, 0.0)
    d = 0.209 / 2.0 - 0.079 / 2.0
    
    shape = translate(pad_header_local, -d, -0.35, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0)]
    labels = ComponentText[]
    
    # 8 pins
    pin_positions = [
        (-d, -0.35, "1LED"), (d, -0.25, "SCK"), (-d, -0.15, "MOSI"), (d, -0.05, "DC"),
        (-d, 0.05, "RST"), (d, 0.15, "CS"), (-d, 0.25, "GND"), (d, 0.35, "VCC")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_SWD_4_05 component
function header_SWD_4_05(value::String="")::Component
    pad_header_local = cube(-0.043, 0.043, -0.015, 0.015, 0.0, 0.0)
    
    shape = translate(pad_header_local, -0.072, 0.025, 0.0)
    shape = union(shape, cylinder(-0.116, 0.025, 0.0, 0.0, 0.015))
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.072, 0.025, 0.0)]
    labels = [component_text(-0.072, 0.025, 0.0, text_str="CLK")]
    
    # 4 pins
    pin_positions = [(0.072, 0.025, "DIO"), (-0.072, -0.025, "RST"), (0.072, -0.025, "GND")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_SWD_4_1 component
function header_SWD_4_1(value::String="")::Component
    shape = translate(pad_header, -0.107, 0.05, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.107, 0.05, 0.0)]
    labels = [component_text(-0.107, 0.05, 0.0, text_str=".CLK")]
    
    # 4 pins
    pin_positions = [(0.107, 0.05, "DIO"), (-0.107, -0.05, "RST"), (0.107, -0.05, "GND")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_UPDI component
function header_UPDI(value::String="")::Component
    shape = translate(pad_header, 0.0, -0.05, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, -0.05, 0.0), Point(0.0, 0.05, 0.0)]
    labels = [
        component_text(0.0, -0.05, 0.0, text_str="UPDI"),
        component_text(0.0, 0.05, 0.0, text_str="GND")
    ]
    
    shape = union(shape, translate(pad_header, 0.0, 0.05, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_UPDI_reverse component
function header_UPDI_reverse(value::String="")::Component
    shape = translate(pad_header, 0.0, 0.05, 0.0)
    shape = union(shape, cylinder(0.05, 0.05, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.05, 0.0), Point(0.0, -0.05, 0.0)]
    labels = [
        component_text(0.0, 0.05, 0.0, text_str="UPDI"),
        component_text(0.0, -0.05, 0.0, text_str="GND")
    ]
    
    shape = union(shape, translate(pad_header, 0.0, -0.05, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# USB_A_plug component
function USB_A_plug(value::String="")::Component
    shape = translate(cube(-0.05, 0.242, -0.02, 0.02, 0.0, 0.0), 0.0, 0.138, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, 0.138, 0.0)]
    labels = [component_text(0.0, 0.138, 0.0, text_str="5V")]
    
    # 4 pins
    pin_positions = [
        (0.0, 0.039, "D-"), (0.0, -0.039, "D+"), (0.0, -0.138, "GND")
    ]
    
    for (x, y, label) in pin_positions
        pad_shape = (y == 0.039 || y == -0.039) ? cube(-0.05, 0.202, -0.02, 0.02, 0.0, 0.0) : cube(-0.05, 0.242, -0.02, 0.02, 0.0, 0.0)
        shape = union(shape, translate(pad_shape, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    # Plug cutout (requires zb, zt - will be set when component is used)
    # Note: cutout will be added when component is placed on PCB
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_SWD component
function header_SWD(value::String="")::Component
    d = 0.077
    w = 0.015
    h = 0.047
    pad = cube(-h, h, -w, w, 0.0, 0.0)
    
    shape = translate(pad, d, -0.1, 0.0)
    shape = union(shape, cylinder(d + h, -0.1, 0.0, 0.0, w))
    pad_list = [Point(0.0, 0.0, 0.0), Point(d, -0.1, 0.0)]
    labels = [component_text(d, -0.1, 0.0, text_str="VCC")]
    
    # 10 pins
    pin_positions = [
        (-d, -0.1, "DIO"), (d, -0.05, "GND"), (-d, -0.05, "CLK"), (d, 0.0, "GND"),
        (-d, 0.0, "SWO"), (d, 0.05, "KEY"), (-d, 0.05, "NC"), (d, 0.1, "GND"),
        (-d, 0.1, "RST")
    ]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# I2C4x1h component
function I2C4x1h(value::String="")::Component
    shape = translate(pad_header, 0.0, -0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.0, -0.15, 0.0)]
    labels = [component_text(0.0, -0.15, 0.0, text_str="SCL")]
    
    # 4 pins
    pin_positions = [(0.0, -0.05, "SDA"), (0.0, 0.05, "VCC"), (0.0, 0.15, "GND")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# I2C4x1v component
function I2C4x1v(value::String="")::Component
    pad_header_local = cube(-0.079 / 2.0, 0.079 / 2.0, -0.039 / 2.0, 0.039 / 2.0, 0.0, 0.0)
    d = 0.209 / 2.0 - 0.079 / 2.0
    
    shape = translate(pad_header_local, -d, -0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-d, -0.15, 0.0)]
    labels = [component_text(-d, -0.15, 0.0, text_str="1VCC")]
    
    # 4 pins
    pin_positions = [(d, -0.05, "GND"), (-d, 0.05, "SCL"), (d, 0.15, "SDA")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# I2C4x1i component
function I2C4x1i(value::String="")::Component
    pad_header_local = cube(-0.079 / 2.0, 0.079 / 2.0, -0.039 / 2.0, 0.039 / 2.0, 0.0, 0.0)
    d = 0.0
    
    shape = translate(pad_header_local, -d, -0.15, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-d, -0.15, 0.0)]
    labels = [component_text(-d, -0.15, 0.0, text_str="1VCC")]
    
    # 4 pins
    pin_positions = [(d, -0.05, "GND"), (-d, 0.05, "SCL"), (d, 0.15, "SDA")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header_local, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_4 component
function header_4(value::String="")::Component
    shape = translate(pad_header, -0.107, 0.05, 0.0)
    shape = union(shape, cylinder(-0.157, 0.05, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(-0.107, 0.05, 0.0)]
    labels = [component_text(-0.107, 0.05, 0.0, text_str="1")]
    
    # 4 pins
    pin_positions = [(0.107, 0.05, "2"), (-0.107, -0.05, "3"), (0.107, -0.05, "4")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_signal component
function header_signal(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.05, 0.0)
    shape = union(shape, cylinder(0.157, -0.05, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.05, 0.0)]
    labels = [component_text(0.107, -0.05, 0.0, text_str="GND")]
    
    # 4 pins
    pin_positions = [(-0.107, -0.05, ""), (0.107, 0.05, "signal"), (-0.107, 0.05, "")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_power component
function header_power(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.05, 0.0)
    shape = union(shape, cylinder(0.157, -0.05, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.05, 0.0)]
    labels = [component_text(0.107, -0.05, 0.0, text_str="GND")]
    
    # 4 pins
    pin_positions = [(-0.107, -0.05, ""), (0.107, 0.05, "V"), (-0.107, 0.05, "")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_i0 component
function header_i0(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.05, 0.0)
    shape = union(shape, cylinder(0.157, -0.05, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.05, 0.0)]
    labels = [component_text(0.107, -0.05, 0.0, text_str="GND")]
    
    # 4 pins
    pin_positions = [(-0.107, -0.05, "data"), (0.107, 0.05, "V"), (-0.107, 0.05, "")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_serial component
function header_serial(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.05, 0.0)
    shape = union(shape, cylinder(0.157, -0.05, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.05, 0.0)]
    labels = [component_text(0.107, -0.05, 0.0, text_str="GND")]
    
    # 4 pins
    pin_positions = [(-0.107, -0.05, "DTR"), (0.107, 0.05, "Tx"), (-0.107, 0.05, "Rx")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_bus component
function header_bus(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.05, 0.0)
    shape = union(shape, cylinder(0.157, -0.05, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.05, 0.0)]
    labels = [component_text(0.107, -0.05, 0.0, text_str="GND")]
    
    # 4 pins
    pin_positions = [(-0.107, -0.05, "Tx"), (0.107, 0.05, "V"), (-0.107, 0.05, "Rx")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# header_I2C component
function header_I2C(value::String="")::Component
    shape = translate(pad_header, 0.107, -0.05, 0.0)
    shape = union(shape, cylinder(0.157, -0.05, 0.0, 0.0, 0.025))
    pad_list = [Point(0.0, 0.0, 0.0), Point(0.107, -0.05, 0.0)]
    labels = [component_text(0.107, -0.05, 0.0, text_str="SCL")]
    
    # 4 pins
    pin_positions = [(-0.107, -0.05, "G"), (0.107, 0.05, "SDA"), (-0.107, 0.05, "V")]
    
    for (x, y, label) in pin_positions
        shape = union(shape, translate(pad_header, x, y, 0.0))
        push!(pad_list, Point(x, y, 0.0))
        push!(labels, component_text(x, y, 0.0, text_str=label))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# USB_mini_CUI component
function USB_mini_CUI(value::String="")::Component
    p = 0.8 / 25.4
    h = 2.5 / 25.4 / 2.0
    w = 0.0075
    y = 5.48 / 25.4
    pad = cube(-w, w, -h, h, 0.0, 0.0)
    l = 0.006
    
    shape = translate(pad, -2 * p, y, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-2 * p, y, 0.0)]
    labels = [component_text(-2 * p, y, 0.0, text_str="V", line=l)]
    
    # 5 pins
    pin_positions = [(-p, y, "-"), (0.0, y, "+"), (p, y, "I"), (2 * p, y, "G")]
    
    for (x, y_pos, label) in pin_positions
        shape = union(shape, translate(pad, x, y_pos, 0.0))
        push!(pad_list, Point(x, y_pos, 0.0))
        push!(labels, component_text(x, y_pos, 0.0, text_str=label, line=l))
    end
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end

# USB_mini_Hirose component
function USB_mini_Hirose(value::String="")::Component
    w = 0.0049
    h = 1.35 / 25.4 / 2.0
    p = 1.3 / 25.4 / 2.0
    y = (3.55 - 1.35 / 2.0) / 25.4
    pad = cube(-w, w, -h, h, 0.0, 0.0)
    l = 0.006
    
    shape = translate(pad, -2 * p, y, 0.0)
    pad_list = [Point(0.0, 0.0, 0.0), Point(-2 * p, y, 0.0)]
    labels = [component_text(-2 * p, y, 0.0, text_str="V", line=l)]
    
    # 5 pins
    pin_positions = [(-p, y, "-"), (0.0, y, "+"), (p, y, "I"), (2 * p, y, "G")]
    
    for (x, y_pos, label) in pin_positions
        shape = union(shape, translate(pad, x, y_pos, 0.0))
        push!(pad_list, Point(x, y_pos, 0.0))
        push!(labels, component_text(x, y_pos, 0.0, text_str=label, line=l))
    end
    
    # Feet pads
    x_feet = (9.8 + 6.2) / 2.0 / 25.4 / 2.0
    w_feet = (9.8 - 6.2) / 25.4 / 2.0 / 2.0
    h_feet = 1.9 / 25.4 / 2.0
    pad_feet = cube(-w_feet, w_feet, -h_feet, h_feet, 0.0, 0.0)
    shape = union(shape, translate(pad_feet, -x_feet, 0.0, 0.0))
    shape = union(shape, translate(pad_feet, x_feet, 0.0, 0.0))
    
    return Component(shape, pad_list, labels, value, nothing, nothing)
end



############################################################
# wiring functions
############################################################

"""
    wire(pcb, width, points...)

Creates rounded traces connecting multiple points on a PCB.

This function draws smooth, rounded traces between points by:
1. Adding a cylinder at the starting point (rounded endpoint)
2. Drawing lines between consecutive points
3. Adding cylinders at each endpoint for smooth connections

# Arguments
- `pcb`: PCB struct to add traces to
- `width`: Trace width (diameter of the trace)
- `points...`: Variable number of Point structs to connect

# Returns
Modified PCB struct with traces added to board layer

# Example
```julia
pcb = wire(pcb, 0.015, point1, point2, point3)
# Creates a trace from point1 -> point2 -> point3
```
"""
function wire(pcb::PCB, width::Float64, points::Point...)::PCB
    if length(points) == 0
        return pcb
    end
    
    # Small offset to ensure cylinders connect properly with lines
    roundoff = 1e-6
    
    # Add cylinder at first point
    p0 = points[1]
    pcb.board = union(pcb.board, cylinder(p0.x, p0.y, p0.z - roundoff, p0.z + roundoff, width / 2.0))
    
    # Connect each point to the next with a line and endpoint cylinder
    for i in 2:length(points)
        p_prev = points[i - 1]
        p_curr = points[i]
        
        # Draw line from previous point to current point
        pcb.board = union(pcb.board, line(p_prev.x, p_prev.y, p_curr.x, p_curr.y, p_curr.z, width))
        
        # Add cylinder at current endpoint for smooth connection
        pcb.board = union(pcb.board, cylinder(p_curr.x, p_curr.y, p_curr.z - roundoff, p_curr.z + roundoff, width / 2.0))
    end
    
    return pcb
end

"""
    wirer(pcb, width, points...)

Creates rectangular (Manhattan-style) traces connecting multiple points.

This function draws rectangular traces using only horizontal and vertical segments,
following Manhattan routing style (right-angle turns only). Useful for:
- Clean, predictable routing
- Easier manufacturing
- Standard PCB routing patterns

# Arguments
- `pcb`: PCB struct to add traces to
- `width`: Trace width
- `points...`: Variable number of Point structs to connect

# Returns
Modified PCB struct with rectangular traces added to board layer

# Example
```julia
pcb = wirer(pcb, 0.015, point1, point2, point3)
# Creates rectangular routing: point1 -> point2 -> point3
```
"""
function wirer(pcb::PCB, width::Float64, points::Point...)::PCB
    if length(points) < 2
        return pcb
    end
    
    # Connect each point to the next with rectangular segments
    for i in 2:length(points)
        p_prev = points[i - 1]
        p_curr = points[i]
        
        # Create horizontal segment (x-direction)
        if p_prev.x < p_curr.x
            # Moving right
            pcb.board = union(pcb.board, cube(
                p_prev.x - width / 2.0,
                p_curr.x + width / 2.0,
                p_prev.y - width / 2.0,
                p_prev.y + width / 2.0,
                p_prev.z,
                p_prev.z
            ))
        elseif p_curr.x < p_prev.x
            # Moving left
            pcb.board = union(pcb.board, cube(
                p_curr.x - width / 2.0,
                p_prev.x + width / 2.0,
                p_prev.y - width / 2.0,
                p_prev.y + width / 2.0,
                p_prev.z,
                p_prev.z
            ))
        end
        
        # Create vertical segment (y-direction)
        if p_prev.y < p_curr.y
            # Moving up
            pcb.board = union(pcb.board, cube(
                p_curr.x - width / 2.0,
                p_curr.x + width / 2.0,
                p_prev.y - width / 2.0,
                p_curr.y + width / 2.0,
                p_prev.z,
                p_prev.z
            ))
        elseif p_curr.y < p_prev.y
            # Moving down
            pcb.board = union(pcb.board, cube(
                p_curr.x - width / 2.0,
                p_curr.x + width / 2.0,
                p_curr.y - width / 2.0,
                p_prev.y + width / 2.0,
                p_prev.z,
                p_prev.z
            ))
        end
    end
    
    return pcb
end

############################################################
# board definition
############################################################

# Note: Board definition is done by the user in their PCB design script.
# Example usage:
#   width = 1.02  # board width in inches
#   height = 0.87  # board height in inches
#   x0 = 1.0  # x origin
#   y0 = 1.0  # y origin
#   mask = 0.004  # solder mask size
#   pcb = PCB(x0, y0, width, height, mask)
#
#   # Add components
#   component1 = LED_1206("LED1")
#   pcb = add_component(pcb, component1, 1.5, 1.5, 0.0, 0.0)
#
#   # Add wiring
#   pcb = wire(pcb, 0.015, point1, point2, point3)

############################################################
# output generation
############################################################

"""
    generate_output(pcb, x0, y0, zb, zt, border, output_mode)

Generates JSON output for PCB rendering based on selected output mode.

This function creates a JSON structure compatible with frep.jl that specifies:
- The FRep expression to evaluate
- Layer z-coordinates to render
- Rendering bounds (xmin, xmax, ymin, ymax)
- Unit conversion (mm_per_unit)
- Color type (RGB)

# Arguments
- `pcb`: PCB struct containing board, labels, interior, exterior, mask, holes, cutout
- `x0`: X origin of board
- `y0`: Y origin of board
- `zb`: Bottom layer z-coordinate (for double-sided boards)
- `zt`: Top layer z-coordinate (typically 0.0)
- `border`: Border size for rendering (adds padding around board)
- `output_mode`: String specifying desired output type (see RENDER_MODE constants)

# Returns
Dictionary (Dict) containing output configuration for frep.jl

# Output Modes
- `"TOP_FULL"`: Top layer with labels and exterior background
- `"TOP_LABELS_HOLES"`: Top layer with labels and holes highlighted
- `"TOP_FULL_HOLES"`: Top layer with labels, holes, and exterior
- `"DUAL_LAYER_FULL"`: Both top and bottom layers with labels and exterior
- `"DUAL_LAYER_FULL_HOLES"`: Both layers with labels, holes, and exterior
- `"TOP_TRACES"`: Top traces only (white on black)
- `"TOP_TRACES_OUTLINE"`: Top traces with board outline
- `"BOTTOM_TRACES"`: Bottom traces only
- `"BOTTOM_TRACES_REVERSED"`: Bottom traces with x-axis reflection
- `"BOTTOM_TRACES_REVERSED_OUTLINE"`: Bottom traces reversed with outline
- `"INTERIOR"`: Board interior area only
- `"EXTERIOR"`: Area outside board only
- `"HOLES"`: Holes only (white on black)
- `"HOLES_INTERIOR"`: Holes subtracted from interior
- `"TOP_MASK"`: Top solder mask
- `"BOTTOM_MASK"`: Bottom solder mask
- `"LABELS"`: Labels only
- `"LABELS_MINUS_MASK"`: Labels with mask subtracted

# Example
```julia
outputs = generate_output(pcb, 1.0, 1.0, -0.06, 0.0, 0.05, "DUAL_LAYER_FULL")
println(JSON.json(outputs))  # Print JSON to stdout for frep.jl
```
"""
function generate_output(pcb::PCB, x0::Float64, y0::Float64, zb::Float64, zt::Float64,
                         border::Float64, output_mode::String)::Dict{String, Any}
    outputs = Dict{String, Any}()
    
    # Calculate full image bounds
    xmin = x0 - border
    xmax = x0 + pcb.width + border
    ymin = y0 - border
    ymax = y0 + pcb.height + border
    
    # Create full-screen exterior (black background covering entire image)
    # This is everything in the image bounds except the interior
    full_exterior = difference(rectangle(xmin, xmax, ymin, ymax), pcb.interior)
    
    if output_mode == "TOP_FULL"
        # Top layer with labels and exterior background
        outputs["function"] = union(
            union(color(COLOR_TAN, pcb.board), pcb.labels),
            color(COLOR_WHITE, full_exterior)
        )
        outputs["layers"] = [zt]
        
    elseif output_mode == "TOP_LABELS_HOLES"
        # Top layer with labels and holes highlighted
        outputs["function"] = union(
            union(color(COLOR_TAN, pcb.board), pcb.labels),
            color(COLOR_BLUE, pcb.holes)
        )
        outputs["layers"] = [zt]
        
    elseif output_mode == "TOP_FULL_HOLES"
        # Top layer with labels, holes, and exterior
        outputs["function"] = union(
            union(color(COLOR_TAN, pcb.board), pcb.labels),
            union(color(COLOR_WHITE, full_exterior), color(COLOR_BLUE, pcb.holes))
        )
        outputs["layers"] = [zt]
        
    elseif output_mode == "DUAL_LAYER_FULL"
        # Both top and bottom layers with labels and exterior
        outputs["function"] = union(
            union(color(COLOR_TAN, pcb.board), pcb.labels),
            color(COLOR_WHITE, full_exterior)
        )
        outputs["layers"] = [zb, zt]
        
    elseif output_mode == "DUAL_LAYER_FULL_HOLES"
        # Both layers with labels, holes, and exterior
        outputs["function"] = union(
            union(color(COLOR_TAN, pcb.board), pcb.labels),
            union(color(COLOR_WHITE, full_exterior), color(COLOR_BLUE, pcb.holes))
        )
        outputs["layers"] = [zb, zt]
        
    elseif output_mode == "TOP_TRACES"
        # Top traces only (white on black)
        outputs["function"] = color(COLOR_WHITE, pcb.board)
        outputs["layers"] = [zt]
        
    elseif output_mode == "TOP_TRACES_OUTLINE"
        # Top traces with board outline
        outputs["function"] = color(COLOR_WHITE, union(pcb.board, full_exterior))
        outputs["layers"] = [zt]
        
    elseif output_mode == "BOTTOM_TRACES"
        # Bottom traces only
        outputs["function"] = color(COLOR_WHITE, pcb.board)
        outputs["layers"] = [zb]
        
    elseif output_mode == "BOTTOM_TRACES_REVERSED"
        # Bottom traces with x-axis reflection (for viewing from bottom)
        reflection_x = 2.0 * x0 + pcb.width
        outputs["function"] = color(COLOR_WHITE, reflect_x(pcb.board, reflection_x))
        outputs["layers"] = [zb]
        
    elseif output_mode == "BOTTOM_TRACES_REVERSED_OUTLINE"
        # Bottom traces reversed with exterior
        reflection_x = 2.0 * x0 + pcb.width
        outputs["function"] = color(COLOR_WHITE, reflect_x(union(pcb.board, full_exterior), reflection_x))
        outputs["layers"] = [zb]
        
    elseif output_mode == "INTERIOR"
        # Board interior area only
        outputs["function"] = color(COLOR_WHITE, pcb.interior)
        outputs["layers"] = [zt]
        
    elseif output_mode == "EXTERIOR"
        # Area outside board only (full screen)
        outputs["function"] = color(COLOR_WHITE, full_exterior)
        outputs["layers"] = [zt]
        
    elseif output_mode == "HOLES"
        # Holes only (white on black background)
        outputs["function"] = color(COLOR_WHITE, difference(union(full_exterior, pcb.interior), pcb.holes))
        outputs["layers"] = [zb]
        
    elseif output_mode == "HOLES_INTERIOR"
        # Holes subtracted from interior
        outputs["function"] = color(COLOR_WHITE, difference(pcb.interior, pcb.holes))
        outputs["layers"] = [zb]
        
    elseif output_mode == "TOP_MASK"
        # Top solder mask
        outputs["function"] = color(COLOR_WHITE, pcb.mask)
        outputs["layers"] = [zt]
        
    elseif output_mode == "BOTTOM_MASK"
        # Bottom solder mask
        outputs["function"] = color(COLOR_WHITE, pcb.mask)
        outputs["layers"] = [zb]
        
    elseif output_mode == "LABELS"
        # Labels only
        outputs["function"] = color(COLOR_WHITE, pcb.labels)
        outputs["layers"] = [zt]
        
    elseif output_mode == "LABELS_MINUS_MASK"
        # Labels with mask subtracted (for silkscreen)
        outputs["function"] = difference(color(COLOR_WHITE, pcb.labels), color(COLOR_WHITE, pcb.mask))
        outputs["layers"] = [zt]
        
    else
        error("Unknown output mode: $output_mode")
    end
    
    # Set rendering bounds and parameters
    outputs["xmin"] = xmin
    outputs["xmax"] = xmax
    outputs["ymin"] = ymin
    outputs["ymax"] = ymax
    outputs["mm_per_unit"] = 25.4  # Use inch units (25.4 mm per inch)
    outputs["type"] = "RGB"  # Use RGB color format
    
    return outputs
end
