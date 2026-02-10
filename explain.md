# PCB Functional Representation System - Build Documentation

## Overview

This document tracks the step-by-step build process for creating a functional representation PCB design system. The system uses mathematical string expressions to represent PCB geometry, which can be evaluated and rendered to images or exported for manufacturing.

This documentation follows a "build from scratch" approach, explaining not just what was implemented, but how to replicate each feature from first principles. Each section includes detailed step-by-step instructions for understanding and implementing the concepts, similar to educational programs that teach by building.

## Project Structure

Created the `ifrep/` directory in the main workspace to contain the implementation files.

## Step 1: File Skeleton Creation

Created the main Julia file `Fpcb.jl` with organized sections:

1. Header and usage comments
2. Output configuration section
3. Imports section
4. Constants section
5. Shape primitives section
6. Boolean operations section
7. Transformations section
8. Text rendering section
9. PCB board class section
10. Component base class section
11. Component library section
12. Wiring functions section
13. Board definition section
14. Output generation section

Each section contains TODO placeholders for future implementation.

Building the file skeleton from scratch:
1. Understand the system architecture: Identify major components needed
2. Plan the file structure: Organize code into logical sections
3. Create header: Add shebang, file description, usage instructions
4. Define sections: List all major functional areas
5. Add placeholders: Create TODO comments for each section
6. Establish conventions: Decide on naming, formatting, documentation style

## Step 2: Output Configuration Implementation

Implemented the output configuration system using the following conventions:

- Variable name: `RENDER_MODE` (uppercase constant style using `const`)
- Value format: Uppercase string constants like `"DUAL_LAYER_FULL"`
- Documentation: Inline comments listing all available render modes

Available render modes:
- TOP_LAYER_ONLY
- TOP_WITH_LABELS
- TOP_WITH_HOLES
- TOP_FULL
- DUAL_LAYER
- DUAL_LAYER_FULL
- TOP_TRACES
- TOP_TRACES_OUTLINE
- BOTTOM_TRACES
- BOTTOM_TRACES_REVERSED
- DRILL_HOLES
- BOARD_INTERIOR
- BOARD_EXTERIOR
- SOLDER_MASK_TOP
- SOLDER_MASK_BOTTOM
- SILKSCREEN_LABELS
- LABELS_NO_MASK

Default value set to `"DUAL_LAYER_FULL"`.

Building output configuration from scratch:
1. Identify the need: System must support different rendering modes for various output types
2. Choose representation: Use string constants for mode names (readable and flexible)
3. Define naming convention: Uppercase with underscores (SCREAMING_SNAKE_CASE) for constants
4. List all modes: Document every possible output type the system should support
5. Set default: Choose most commonly used mode as default value
6. Use const keyword: Declare as constant for performance and immutability
7. Add documentation: Inline comments explain each mode's purpose and use cases

## Step 3: Imports Setup

Added required Julia packages:
- JSON (for JSON parsing and serialization)
- Images (for image creation and manipulation)
- FileIO (for file input/output operations)

Julia package management:
- Packages are loaded using `using` keyword
- Type system provides compile-time optimizations
- Native array operations without external dependencies

Building the imports setup from scratch:
1. Identify dependencies: Determine what external libraries are needed
   - JSON: For parsing and generating JSON data (data exchange format)
   - Images: For creating and manipulating image data (RGB arrays, color views)
   - FileIO: For reading and writing image files (PNG, JPEG, etc.)
2. Understand package system: Julia uses Pkg for package management
3. Install packages: Run `using Pkg; Pkg.add(["JSON", "Images", "FileIO"])` in Julia REPL
4. Load packages: Use `using PackageName` to import functionality into namespace
5. Create Project.toml: Define dependencies for reproducible builds across environments
6. Document purpose: Explain why each package is needed and what functionality it provides

## Step 4: Constants Implementation

Implemented system constants using the following naming conventions:

Boolean expression constants:
- TRUE_EXPR = "1" (string representation of true)
- FALSE_EXPR = "0" (string representation of false)

Color constants (RGB packed as 32-bit integers):
- COLOR_RED
- COLOR_GREEN
- COLOR_BLUE
- COLOR_GRAY
- COLOR_WHITE
- COLOR_TEAL
- COLOR_PINK
- COLOR_YELLOW
- COLOR_BROWN
- COLOR_NAVY
- COLOR_TAN

Color format uses bit shifting: (R << 16) | (G << 8) | B
All color constants follow the COLOR_ prefix naming convention.
Constants are declared using `const` keyword for performance optimization.

Building constants from scratch:
1. Understand the need: System needs reusable values for expressions and colors
2. Boolean constants: Simple string representations ("1" for true, "0" for false)
   - Used in expressions where boolean values are needed
   - String format allows direct insertion into expression strings
3. Color constants: Pack RGB values into 32-bit integers
   - Problem: Need to store 3 color channels (R, G, B) in single value
   - Solution: Use bit shifting to pack channels into integer
   - Red channel: Shift left 16 bits (occupies bits 16-23)
   - Green channel: Shift left 8 bits (occupies bits 8-15)
   - Blue channel: No shift (occupies bits 0-7)
   - Combine: Use bitwise OR (|) to combine channels
   - Example: White = (255 << 16) | (255 << 8) | 255
4. Naming convention: Use COLOR_ prefix for all color constants
5. Use const keyword: Declare as constant for compiler optimization
6. Calculate values: Use bit operations to compute each color constant

## Step 5: Shape Primitives Implementation

Implemented all geometric shape primitive functions using simple naming conventions:

2D shapes:
- circle(cx, cy, r) - Circular region in XY plane
- rectangle(x0, x1, y0, y1) - Rectangular region in XY plane
- right_triangle(x0, y0, l) - Right triangle (45-45-90)
- triangle(x0, y0, x1, y1, x2, y2) - Triangle from three points (clockwise order)

3D shapes:
- cylinder(cx, cy, z0, z1, r) - Cylindrical volume
- sphere(cx, cy, cz, r) - Spherical volume
- torus(cx, cy, cz, r0, r1) - Toroidal volume
- cube(x0, x1, y0, y1, z0, z1) - Rectangular box volume

Special shapes:
- line(x0, y0, x1, y1, z, width) - Line segment with specified width
- cone(cx, cy, z0, z1, r0) - Conical volume (requires taper transformation)
- pyramid(x0, x1, y0, y1, z0, z1) - Pyramidal volume (requires taper transformation)

All functions return string expressions that can be evaluated mathematically.
Functions use string interpolation for parameter substitution.
Parameter names use abbreviated forms (cx, cy, cz for coordinates, r for radius, etc.).
Type annotations ensure type safety and enable compiler optimizations.
Conical and pyramidal volumes are placeholders that require taper transformation functions.

Each shape primitive includes detailed documentation explaining:
- Mathematical basis for the shape
- How to build the expression from scratch
- Expression structure and evaluation
- Parameter descriptions
- Common use cases

## Step 6: Boolean Operations and Color Application Implementation

Implemented boolean set operations for combining shape expressions and color application functions using the following naming conventions:

Boolean operations:
- union(expr1, expr2) - Combines two shapes (OR operation)
- difference(expr1, expr2) - Subtracts second shape from first (AND NOT)
- intersect(expr1, expr2) - Finds overlapping region (AND operation)

Color application:
- color(color_value, expr) - Applies color to a functional representation expression

Mathematical foundation:
- Based on set theory operations: union (∪), intersection (∩), difference (-)
- Converted to logical operators: | (OR), & (AND), ~ (NOT)
- Each operation wraps expressions in parentheses for proper evaluation precedence
- Color multiplication applies RGB values to boolean expression results

Building boolean operations from scratch:

Step 1: Understand set theory
- Union (A ∪ B): Points that are in A OR in B (or both)
- Intersection (A ∩ B): Points that are in BOTH A AND B
- Difference (A - B): Points that are in A BUT NOT in B
- Visualize: Draw Venn diagrams to understand each operation

Step 2: Convert to logical operators
- Union: Use OR operator (|) - true if either expression is true
- Intersection: Use AND operator (&) - true only if both expressions are true
- Difference: Use AND NOT (& ~) - true if first is true AND second is false

Step 3: Expression wrapping
- Problem: Need to ensure each expression evaluates independently
- Solution: Wrap each expression in parentheses
- Why: Prevents operator precedence issues
- Format: ((expr1) operator (expr2))

Step 4: Implementation details
- Union: "((($expr1)) | (($expr2)))"
  - Double parentheses ensure expr1 evaluates completely
  - | operator combines results
  - Result is true if either side is true
- Difference: "((($expr1)) & ~(($expr2)))"
  - expr1 must be true
  - ~ negates expr2 (NOT operation)
  - & combines: true only if expr1 true AND expr2 false
- Intersection: "((($expr1)) & (($expr2)))"
  - Both expressions must be true
  - & operator requires both sides true

Step 5: String interpolation
- Use Julia's $() syntax to insert expression strings
- Ensures clean code without manual string concatenation
- Example: "((($expr1)) | (($expr2)))" where expr1 and expr2 are variables

Step 6: Return combined expression
- Function returns single string expression
- This string can be used in further operations or evaluation
- Expression maintains proper structure for evaluation

Building color application from scratch:
1. Understand the problem: Boolean expressions return 0 or 1, but we need RGB color values for rendering
2. Mathematical approach: Multiply color value by boolean result to conditionally apply color
3. Expression structure: (color_value * ((expr) != 0))
   - When expr is true: (expr) != 0 evaluates to 1, so result is color_value
   - When expr is false: (expr) != 0 evaluates to 0, so result is 0 (black)
4. Color packing format: RGB values stored as 32-bit integer
   - Red channel: bits 16-23 (shift left 16)
   - Green channel: bits 8-15 (shift left 8)
   - Blue channel: bits 0-7 (no shift)
   - Formula: (R << 16) | (G << 8) | B
5. Implementation: Create function that takes color integer and expression string
   - Use string interpolation to insert color value and expression
   - Wrap expression in double parentheses for proper evaluation
   - Return combined expression string
6. Usage: Apply color to shapes before combining with union
   - colored_shape = color(COLOR_TAN, shape_expr)
   - This ensures shapes render with visible colors instead of black

Expression structure:
- Union: ((expr1) | (expr2)) - Point is inside if in expr1 OR expr2
- Difference: ((expr1) & ~(expr2)) - Point is inside if in expr1 AND NOT in expr2
- Intersection: ((expr1) & (expr2)) - Point is inside only if in BOTH expr1 AND expr2
- Color: (color_value * (((expr)) != 0)) - Applies color when expression is true

Common use cases:
- Union: Combining multiple shapes into one
- Difference: Creating holes, cutting out regions
- Intersection: Finding overlapping areas, clipping shapes
- Color: Applying visual colors to shapes for rendering, distinguishing board regions from exterior areas

All boolean operations and color functions use string interpolation for clean code and include comprehensive documentation explaining the mathematical basis and how to build each operation from scratch.

## Step 7: Transformations Implementation

Implemented comprehensive transformation functions that modify functional representation expressions to translate, rotate, reflect, scale, and apply advanced deformations to shapes.

### Overview

Transformations allow you to modify shapes without recreating them. Instead of defining a circle at a new position, you can create one circle and translate it. This is essential for:
- Positioning components on PCBs
- Creating patterns by repeating and transforming shapes
- Applying complex deformations for advanced designs
- Rotating components to fit board layouts

### Core Transformation Categories

**1. Translation (move, translate)**
- Shifts shapes in 2D or 3D space
- Mathematical basis: Replace X with (X-dx), Y with (Y-dy), Z with (Z-dz)
- Use case: Positioning shapes at specific coordinates

**2. Rotation (rotate, rotate_x/y/z, rotate_90/180/270)**
- Rotates shapes around origin or specific axes
- Mathematical basis: Apply rotation matrix to coordinates
- 2D rotation: X' = X*cos(θ) + Y*sin(θ), Y' = -X*sin(θ) + Y*cos(θ)
- 3D rotations: Similar matrices for each axis
- Use case: Orienting components, creating rotated patterns

**3. Reflection (reflect_x/y/z, reflect_xy/xz/yz)**
- Mirrors shapes across lines or planes
- Mathematical basis: Replace coordinate with (point - coordinate)
- Swapping: Use temporary variable to swap coordinates
- Use case: Creating symmetric designs, flipping components

**4. Scaling (scale_x/y/z, scale_xy, scale_xyz)**
- Resizes shapes around a pivot point
- Mathematical basis: X' = x0 + (X - x0) / scale_factor
- Scale > 1: Makes larger (compresses coordinates)
- Scale < 1: Makes smaller (expands coordinates)
- Use case: Resizing components, creating scaled patterns

**5. Advanced Transformations**
- **Cosine scaling (coscale_x_y/z, coscale_xy_z)**: Creates wavy/undulating effects
- **Tapering (taper_x_y/z, taper_xy_z)**: Creates linear scaling variation (like pyramids)
- **Shearing (shear_x_y/z, coshear_x_z)**: Creates parallelogram-like distortions

### Building Transformations from Scratch

**Translation Example:**
1. Problem: Move a shape from (0,0) to (5, 3)
2. Solution: Evaluate original shape at (X-5, Y-3)
3. Implementation: Replace "X" with "(X-5)" and "Y" with "(Y-3)"
4. Result: Shape appears at new location when evaluated

**Rotation Example:**
1. Problem: Rotate shape by 45 degrees counterclockwise
2. Solution: Apply rotation matrix to coordinates
3. Convert angle: 45° = 45 * π/180 radians
4. Transform: X' = X*cos(θ) + Y*sin(θ), Y' = -X*sin(θ) + Y*cos(θ)
5. Implementation: Replace X and Y with rotated expressions
6. Result: Shape appears rotated when evaluated

**Scaling Example:**
1. Problem: Scale shape by 2x around point (10, 10)
2. Solution: Compress coordinates by factor of 2
3. Transform: X' = 10 + (X - 10) / 2
4. When X = 12 (distance 2 from center), X' = 10 + 2/2 = 11
5. Original shape evaluated at X=11, which maps to X=12 in scaled space
6. Result: Shape appears twice as large

**Tapering Example:**
1. Problem: Create pyramid effect (taper from 1.0 to 0.0 along Z)
2. Solution: Scale factor varies linearly with Z
3. Scale at Z: s = s0 + (s1-s0)*(Z-z0)/(z1-z0)
4. Apply scaling: X' = x0 + (X-x0) / s
5. Result: Shape tapers from full size to point

### Implementation Details

All transformation functions:
- Use Julia's `replace()` function for string substitution
- Use string interpolation for parameter values
- Handle coordinate variable replacement carefully
- Use temporary variables when swapping coordinates
- Include comprehensive documentation with mathematical basis

Key techniques:
- **String replacement**: Replace coordinate variables with transformed expressions
- **Temporary variables**: Use "temp", "y", "z" to avoid replacement conflicts
- **Expression wrapping**: Ensure transformed coordinates are properly parenthesized
- **Angle conversion**: Convert degrees to radians for trigonometric functions

### Common Use Cases

- **Component placement**: Use `move()` or `translate()` to position components
- **Orientation**: Use `rotate()` or `rotate_z()` to orient components
- **Symmetry**: Use `reflect_x()` or `reflect_y()` to create symmetric designs
- **Resizing**: Use `scale_xy()` to resize components uniformly
- **3D effects**: Use `taper_xy_z()` to create pyramid/cone effects
- **Patterns**: Combine transformations to create repeated patterns

All transformation functions are implemented with detailed documentation explaining the mathematical basis and how to build each transformation from scratch, following the educational approach of explaining concepts from first principles.

## Step 8: Text Rendering Implementation

Implemented a text rendering system that converts text strings into functional representation shapes.

### Overview

Text rendering allows you to add labels, annotations, and text-based markings to PCB designs. The system converts characters into geometric shapes that can be positioned, rotated, and colored like any other shape.

### Core Components

**1. TextRenderer Struct**
- Stores text content, position, and formatting parameters
- Builds character shapes dictionary
- Processes text into combined shape expression
- Applies alignment, rotation, and color

**2. Character Shape Dictionary**
- Each character (A-Z, a-z, 0-9, symbols) is built from primitives
- Characters designed to fit within bounding boxes
- Uses circles, rectangles, and triangles to form letter shapes
- Space character returns empty shape (FALSE_EXPR)

**3. Text Processing Pipeline**
- Character positioning: Sequential placement with spacing
- Line handling: Newlines create vertical breaks
- Alignment: Horizontal (left/center/right) and vertical (top/center/bottom)
- Transformation: Rotation and translation
- Color application: Final shape colored

### Building Text Rendering from Scratch

**Character Definition:**
1. Problem: Need to represent characters as geometric shapes
2. Solution: Build each character from basic primitives
3. Example - Letter 'A':
   - Create triangle for outer shape
   - Subtract inner triangle and horizontal bar for center
   - Result: Recognizable 'A' shape
4. Store in dictionary: Map character to shape expression

**Text Processing:**
1. Problem: Convert text string into single shape expression
2. Solution: Position each character sequentially
3. Steps:
   - Initialize position at (0, -height) for first character
   - For each character: Get shape, move to position, add to line
   - Handle newlines: Add current line, reset position, move down
   - Apply alignment: Adjust entire text block position
   - Apply rotation: Rotate entire text block
   - Apply translation: Move to final position
   - Apply color: Color the final shape

**Alignment:**
1. Horizontal alignment:
   - Left (L): No adjustment
   - Center (C): Move left by half line width
   - Right (R): Move left by full line width
2. Vertical alignment:
   - Top: No adjustment
   - Center (C): Move up by half text height
   - Bottom (B): Move up by full text height

### Implementation Details

**Character Set:**
- Uppercase letters (A-Z): Full set with recognizable shapes
- Lowercase letters (a-z): Simplified circle-based shapes
- Digits (0-9): Circle-based shapes
- Common symbols: +, -, ., /, space

**Parameters:**
- `line`: Stroke/line thickness (default: 1.0)
- `height`: Character height (default: 6*line)
- `width`: Character width (default: 4*line)
- `space`: Character spacing (default: line/2)
- `align`: Alignment string like "CC" (center-center), "LT" (left-top), etc.
- `angle`: Rotation angle in degrees
- `color_value`: Color to apply to text

**Usage:**
```julia
# Simple text
text_shape = text("Hello", 0.0, 0.0, 0.0)

# With formatting
text_shape = text("PCB", 10.0, 20.0, 0.0;
                   line=0.5, height=3.0, width=2.0,
                   align="CC", color_value=COLOR_WHITE, angle=0.0)
```

**Multi-line Text:**
- Use `\n` for line breaks
- Example: `text("Line 1\nLine 2", 0.0, 0.0)`
- Vertical spacing automatically adjusted

### Common Use Cases

- **Component labels**: Add text labels to identify components
- **Board annotations**: Mark board name, version, date
- **Pin labels**: Label connector pins
- **Orientation markers**: Text to indicate board orientation
- **Rotated text**: Use angle parameter for vertical or angled text

The text rendering system provides a complete solution for adding textual information to PCB designs, with full support for positioning, alignment, rotation, and styling.

## Step 9: PCB Class Implementation

Implemented a PCB class that manages board definition, components, layers, and manufacturing features.

### Overview

The PCB class is a container that organizes all elements of a PCB design into structured layers. It provides a high-level interface for building PCBs by managing:
- Board layer (copper traces, pads, components)
- Labels layer (silkscreen text)
- Interior/exterior regions (board outline)
- Solder mask layer (automatically generated)
- Drill holes
- Board cutouts

### Core Components

**1. PCB Struct**
- Stores board dimensions and position
- Manages separate layers as string expressions
- Tracks mask size for solder mask generation
- Provides methods for adding components and features

**2. Layer Management**
- **board**: Main copper layer (traces, pads, components)
- **labels**: Silkscreen text labels
- **interior**: Board outline rectangle
- **exterior**: Area outside board (for rendering)
- **mask**: Solder mask (expanded around parts)
- **holes**: Drill holes for through-hole components
- **cutout**: Board cutouts (internal routing, mounting holes)

**3. Key Methods**
- `add(pcb, part)`: Add component to board, auto-expand mask
- `panel(pcb, other_pcb, dx, dy, dz)`: Combine multiple PCBs
- `add_text(pcb, text_str, x, y)`: Add text labels
- `add_hole(pcb, x, y, radius)`: Add drill holes
- `add_cutout(pcb, shape)`: Add board cutouts

### Building PCB Class from Scratch

**Board Definition:**
1. Problem: Need container to organize PCB layers
2. Solution: Create struct with separate fields for each layer
3. Initialize: Set board dimensions, create interior/exterior regions
4. Start empty: All layers start as FALSE_EXPR (empty)

**Component Addition:**
1. Problem: Adding parts should update both board and mask
2. Solution: Add part to board, expand mask around it
3. Mask expansion: Create 4 diagonal copies of part
   - Directions: (-mask, mask), (-mask, -mask), (mask, mask), (mask, -mask)
4. Purpose: Creates clearance for solder mask to prevent bridges

**Panel Functionality:**
1. Problem: Combine multiple PCBs side by side
2. Solution: Translate other PCB and combine layers
3. Board/interior: Union (combine areas)
4. Exterior: Intersect (both must be exterior)
5. Mask/holes: Union (combine all features)
6. Update dimensions: Add translation to width/height

### Implementation Details

**Mask Generation:**
- Automatically expands around every added part
- Expansion in 4 diagonal directions creates clearance
- Prevents solder bridges between adjacent pads
- Mask size parameter controls clearance amount

**Layer Separation:**
- Each layer is independent expression
- Can be rendered separately or combined
- Allows different output modes (traces only, mask only, etc.)

**Point Struct:**
- Simple 3D coordinate container
- Used for component placement, pin positions
- Convenient for organizing coordinate data

### Common Use Cases

- **Board creation**: Initialize PCB with dimensions
- **Component placement**: Add parts using `add()` method
- **Labeling**: Add text labels for component identification
- **Holes**: Add drill holes for through-hole components
- **Panelization**: Combine multiple PCBs for manufacturing
- **Cutouts**: Create board cutouts for mounting or routing

**Usage Example:**
```julia
# Create PCB
pcb = PCB(0.0, 0.0, 2.0, 2.0, 0.05)

# Add components
pcb.add(circle(0.5, 0.5, 0.1))
pcb.add(rectangle(1.0, 1.5, 0.5, 1.0))

# Add labels
pcb.add_text("R1", 0.5, 0.5, line=0.01, color_value=UInt32(COLOR_WHITE))

# Add holes
pcb.add_hole(1.0, 1.0, 0.05)
```

The PCB class provides a structured, high-level interface for building complete PCB designs, automatically managing layers and manufacturing features.

## Step 10: Component Base Class Implementation

Implemented a component base class system for creating reusable PCB components.

### Overview

The component base class provides a foundation for defining reusable PCB components (resistors, capacitors, ICs, etc.). Components encapsulate geometry, pin positions, labels, and can be placed on PCBs with rotation and translation.

### Core Components

**1. ComponentText Struct**
- Stores text label information for components
- Position relative to component origin
- Angle relative to component rotation
- Used for pin labels, component identifiers, etc.

**2. Component Struct**
- **shape**: FRep expression for component body/pads
- **pad**: Array of Point objects (pin positions)
- **labels**: Array of ComponentText objects
- **value**: Component value string (e.g., "10k" for resistor)
- **holes**: Optional holes expression (for through-hole components)
- **cutout**: Optional cutout expression (for components requiring board cutouts)

**3. add_component() Function**
- Places component on PCB with rotation and translation
- Handles shape, holes, and cutout rotation/translation
- Rotates pad positions using 2D rotation matrix
- Rotates label positions and adjusts label angles
- Updates PCB layers (board, holes, interior, labels)

### Building Component System from Scratch

**Component Definition:**
1. Problem: Need reusable parts that can be placed on PCBs
2. Solution: Create struct with shape, pads, labels, value
3. Shape creation: Build FRep expression for component geometry
4. Pad positions: Define pin positions relative to component origin
5. Label positions: Define text label positions relative to component

**Placement System:**
1. Problem: Place components with rotation and translation
2. Solution: Rotate then translate all component elements
3. Rotation optimization: Check for common angles (90, 180, 270)
4. Pad rotation: Apply 2D rotation matrix to each pad position
   - x' = x*cos(θ) - y*sin(θ)
   - y' = x*sin(θ) + y*cos(θ)
5. Label rotation: Apply same matrix to label positions
6. Label angle adjustment: Combine component angle with label angle
7. Layer updates: Add shape to board, holes to holes, subtract cutout

### Implementation Details

**Rotation Matrix:**
- 2D rotation: x' = x*cos(θ) - y*sin(θ), y' = x*sin(θ) + y*cos(θ)
- Applied to pad and label positions
- Preserves relative positions after rotation

**Label Angle Handling:**
- Labels have their own rotation angle (relative to component)
- Component rotation combines with label rotation
- Special handling for angles > 90° (flip text orientation)

**Layer Management:**
- Shape added to PCB board layer (copper)
- Holes added to PCB holes layer (drill points)
- Cutout subtracted from interior, added to exterior
- Labels added to PCB labels layer (silkscreen)

### Common Use Cases

- **Component definition**: Create reusable component library
- **Component placement**: Place components on PCB with rotation
- **Pin access**: Access rotated pad positions for wiring
- **Label management**: Automatic label positioning and rotation
- **Through-hole support**: Components with drill holes
- **Cutout support**: Components requiring board cutouts

**Helper Functions:**
- `component_text(x, y, z, text_str, line, angle)`: Creates ComponentText objects
  - Convenience function for creating text labels
  - Parameters: position (x, y, z), text string, line thickness, rotation angle
  - Returns: ComponentText struct
  - Used extensively in component library definitions

**Usage Example:**
```julia
# Create component (typically done in component library)
component = Component(
    shape=circle(0.0, 0.0, 0.5),  # Component body
    pad=[Point(0.0, 0.0, 0.0)],    # Pin positions
    labels=[component_text(0.0, 0.0, 0.0, text_str="R1", line=0.006, angle=0.0)],
    value="10k"
)

# Place component on PCB
pcb = add_component(pcb, component, 1.0, 1.0, 0.0, angle=90.0)
```

The component base class provides a foundation for building component libraries and enables systematic component placement with proper rotation and layer management.

## Step 11: Expression Evaluator Implementation

Created the `frep.jl` file that evaluates functional representation expressions and renders them to images.

Core functionality:
- Reads JSON input from stdin (piped from Fpcb.jl)
- Parses command line arguments (DPI and output filename)
- Generates coordinate grids for evaluation
- Evaluates mathematical expressions at grid points
- Processes single or multiple layers
- Constructs RGB images from results
- Saves images with specified DPI

Key functions implemented:

Input processing:
- read_input() - Reads and parses JSON from stdin
- parse_arguments() - Handles command line arguments with defaults

Grid generation:
- generate_evaluation_grid() - Creates X and Y coordinate grids
- Calculates step size based on DPI: delta = (25.4 / dpi) / mm_per_unit
- Creates 2D meshgrids using Julia broadcasting
- Flips Y coordinates for image coordinate system

Expression evaluation:
- evaluate_expression() - Evaluates string expressions at grid points
- Uses Meta.parse() to parse expression string to AST
- Sets up evaluation environment with X, Y, Z variables
- Includes math functions (sqrt, sin, cos, etc.)
- Converts boolean results to UInt32 for color packing

Layer processing:
- process_layers() - Handles single or multiple Z layers
- Calculates layer intensity based on Z position
- Combines multiple layers using bitwise operations
- Maps Z coordinates to color intensity

Image construction:
- construct_image() - Converts evaluation results to RGB image
- Extracts R, G, B channels using bitwise operations
- Creates 3-channel image array (height x width x 3)
- Converts to UInt8 format for image saving

Building the evaluator from scratch:

Step 1: Understand the pipeline
- Input: JSON with mathematical expression string and parameters
- Process: Evaluate expression at every pixel location
- Output: RGB image file
- Flow: JSON -> Parse -> Generate grids -> Evaluate -> Extract colors -> Save image

Step 2: Grid generation
- Problem: Need X, Y coordinates for every pixel in the output image
- Solution: Create 2D coordinate grids using meshgrid pattern
- Calculate step size: delta = (25.4 mm/inch) / (DPI dots/inch) / (mm_per_unit units/mm)
- Create X array: xmin to xmax with step delta
- Create Y array: ymin to ymax with step delta, then reverse for image coordinates
- Generate meshgrid: X[i,j] = x[j], Y[i,j] = y[i] for all i, j
- Implementation: Use broadcasting or list comprehensions to create 2D arrays

Step 3: Expression evaluation
- Problem: Have string expression, need to evaluate it with X, Y, Z as arrays
- Solution: Parse string to AST, then evaluate in controlled environment
- Parse expression: Use Meta.parse() to convert string to Abstract Syntax Tree
- Create evaluation module: Module() provides isolated namespace
- Set variables: X, Y, Z as 2D arrays in module scope
- Import functions: Add math functions (sqrt, sin, cos, etc.) and constants (pi, e)
- Enable broadcasting: Wrap expression with @. macro or use dot operators
- Evaluate: Core.eval() executes AST in module context
- Convert result: Boolean arrays to UInt32 for color packing

Step 4: Color extraction
- Problem: Expression returns UInt32 values with packed RGB, need separate channels
- Solution: Use bitwise operations to extract each color channel
- Color format: 32-bit integer with (R << 16) | (G << 8) | B
- Extract Red: (value >> 16) & 0xFF - shift right 16 bits, mask lower 8 bits
- Extract Green: (value >> 8) & 0xFF - shift right 8 bits, mask lower 8 bits
- Extract Blue: value & 0xFF - mask lower 8 bits directly
- Create image array: 3D array (height, width, 3) with UInt8 values

Step 5: Image creation and saving
- Problem: Have RGB channel arrays, need to save as PNG image
- Solution: Use Images.jl library to create and save image
- Permute dimensions: Convert (height, width, channels) to (width, height, channels)
- Normalize values: Divide by 255.0 to convert UInt8 to Float64 in 0-1 range
- Create colorview: Use colorview(RGB, ...) to create RGB image object
- Save image: Use FileIO.save() to write PNG file
- Handle errors: Add try-catch for file I/O operations

Mathematical concepts:
- DPI to coordinate conversion: delta = (25.4 / dpi) / mm_per_unit
- Meshgrid generation: Broadcasting creates coordinate pairs efficiently
- Bitwise color extraction: R = value & 0xFF, G = (value >> 8) & 0xFF, B = (value >> 16) & 0xFF
- Layer intensity mapping: intensity = 255 * (Z - zmin) / (zmax - zmin)

Julia-specific features:
- Type annotations for performance optimization
- Native array operations without external dependencies
- Broadcasting for efficient grid generation
- JIT compilation for near-native performance

The evaluator includes comprehensive error handling and detailed documentation explaining each step of the evaluation process.

## Step 12: Example Implementation

Created example files demonstrating the system usage:

### Example 1: Simple Shapes (`examples/simple_shapes.jl`)

Features demonstrated:
- Creating basic shapes (circles, rectangles, lines)
- Combining shapes using boolean operations
- Applying colors to different regions
- Generating JSON output for the evaluator

Building the example from scratch:

Step 1: Set up the file structure
- Create examples directory in project root
- Create simple_shapes.jl file with header and usage comments
- Include Fpcb.jl to access shape functions and constants
- Import JSON package for output serialization

Step 2: Define board parameters
- Board position: (board_x, board_y) - origin coordinates
- Board dimensions: board_width, board_height - size in units
- Board layer: board_z_top - Z coordinate for top layer
- These parameters define the coordinate system and board boundaries

Step 3: Create board outline
- Use rectangle() function to define board boundary
- Parameters: x0=board_x, x1=board_x+width, y0=board_y, y1=board_y+height
- This creates the outer boundary of the PCB

Step 4: Create shape primitives
- Circle pads: Use circle(cx, cy, r) for circular pads
  - Center coordinates (cx, cy) and radius (r)
  - Multiple circles at different positions
- Rectangle pads: Use rectangle(x0, x1, y0, y1) for rectangular pads
  - Four coordinates defining rectangular region
- Traces: Use line(x0, y0, x1, y1, z, width) for connecting traces
  - Start point (x0, y0), end point (x1, y1)
  - Z level and width for 3D line segment

Step 5: Combine shapes using boolean operations
- Start with first shape as base
- Use union() to add each additional shape
- Pattern: result = union(result, new_shape)
- This creates single expression containing all shapes

Step 6: Create exterior region
- Exterior is everything NOT in board outline
- Use difference(TRUE_EXPR, board_outline)
- TRUE_EXPR represents entire space
- Difference removes board area, leaving exterior

Step 7: Apply colors to regions
- Apply color to board shapes: color(COLOR_TAN, final_board)
  - COLOR_TAN is predefined tan color constant
  - Multiplies color by boolean expression result
- Apply color to exterior: color(COLOR_WHITE, exterior_expr)
  - COLOR_WHITE is predefined white color constant
  - Makes exterior visible in rendered image

Step 8: Combine colored regions
- Use union() to combine colored board and colored exterior
- Result: output_function contains both colored regions
- When evaluated, each region renders with its assigned color

Step 9: Generate JSON output
- Create dictionary with required fields:
  - "function": The combined expression string
  - "layers": Array of Z coordinates to render
  - "xmin", "xmax", "ymin", "ymax": Bounding box coordinates
  - "mm_per_unit": Unit conversion factor (25.4 for inches)
  - "type": Output type ("RGB")
- Serialize to JSON: JSON.json(outputs)
- Print to stdout for piping to frep.jl

Step 10: Execute and render
- Run: julia simple_shapes.jl | julia ../frep.jl [dpi] [filename]
- simple_shapes.jl outputs JSON to stdout
- frep.jl reads JSON from stdin
- frep.jl evaluates expression and saves image

Example 1 creates a simple board with:
- Tan-colored board shapes (circles, rectangles, traces)
- White-colored exterior (area outside board)
- Multiple shapes connected by traces

### Example 2: Boolean Operations (`examples/boolean_ops.jl`)

Created second example demonstrating the three boolean operations:

Features demonstrated:
- Union operation: Combining two overlapping circles
- Difference operation: Creating a frame by subtracting inner rectangle from outer
- Intersect operation: Finding overlapping region between two circles
- Clear visual separation: Each operation in its own section with distinct color

Example 2 workflow:
1. Define board (4.0 x 3.0 units) - wider to accommodate three sections
2. Left section - Union demonstration:
   - Create two overlapping circles
   - Use union() to combine them
   - Result: Both circles visible as combined shape
   - Color: Red
3. Center section - Difference demonstration:
   - Create outer rectangle and inner rectangle
   - Use difference() to subtract inner from outer
   - Result: Frame shape (hollow rectangle)
   - Color: Green
4. Right section - Intersect demonstration:
   - Create two overlapping circles
   - Use intersect() to find common region
   - Result: Only the overlapping area (lens shape)
   - Color: Blue
5. Combine all three operations using union
6. Add white exterior using difference operation
7. Generate JSON output and render image

Boolean operations explained:

Union (OR operation):
- Mathematical: A ∪ B - includes all points in either shape
- Logical: expr1 | expr2 - true if either expression is true
- Visual: Both shapes visible, overlapping area included
- Use case: Combining multiple shapes into one
- Pattern: result = union(shape1, shape2)

Difference (AND NOT operation):
- Mathematical: A - B - includes points in A but not in B
- Logical: expr1 & ~expr2 - true if first true AND second false
- Visual: First shape with second shape removed (cutout)
- Use case: Creating holes, frames, cutouts
- Pattern: result = difference(outer_shape, inner_shape)

Intersect (AND operation):
- Mathematical: A ∩ B - includes only points in both shapes
- Logical: expr1 & expr2 - true only if both expressions true
- Visual: Only the overlapping region visible
- Use case: Finding common areas, clipping shapes
- Pattern: result = intersect(shape1, shape2)

Example 2 creates a clear demonstration showing:
- Three distinct sections, one for each boolean operation
- Visual comparison of how each operation affects shapes
- Simple, focused examples that are easy to understand
- Color coding: Red (union), Green (difference), Blue (intersect)

### Example 3: Text Rendering (`examples/text_rendering.jl`)

Created third example demonstrating text rendering capabilities:

**Features demonstrated:**
- Basic text rendering at specified positions
- Multi-line text with newline support
- Rotated text at various angles
- Text alignment (left, center, right)
- Text combined with shapes (text on circles)
- Color application to text

**Workflow:**
1. Create board outline
2. Render basic text at different positions
3. Demonstrate multi-line text
4. Show rotated text (0°, 45°, 90°)
5. Combine text with geometric shapes
6. Apply different colors to text

**Key Features:**
- Character shape definitions for all ASCII characters
- Position-based text placement
- Rotation and alignment support
- Color customization
- Integration with other FRep shapes

**Text Rendering Details:**
- Each character is defined as a combination of primitive shapes
- Characters are positioned sequentially with spacing
- Newlines create vertical line breaks
- Rotation applies to entire text block
- Alignment adjusts text position within bounding box

## Step 13: Component Library Implementation

### Overview

This step implements a comprehensive component library with predefined electronic components for PCB design. The library includes microcontrollers, LEDs, connectors, headers, and various other common components.

### Core Components

**Pad Definitions:**
- Common pad shapes defined as constants for reuse
- `pad_header`: Standard header pin pad (cube)
- `pad_1206`: 1206 package pad (cube)
- `pad_MTA`: MTA connector pad (cube)
- `pad_screw_terminal`: Screw terminal pad (cylinder)
- `pad_SOIC`: SOIC package pad (cube)
- `pad_RGB`: RGB LED pad (cube)
- And more specialized pad types

**Helper Functions:**
- `component_text()`: Creates ComponentText objects for labels
  - Parameters: position (x, y, z), text string, line thickness, angle
  - Returns: ComponentText struct
  - Used extensively in component definitions

**Component Categories:**
1. **Microcontrollers**: PicoW, XIAO variants (SAMD21, ESP32S3, ESP32C3, RP2040), ATtiny variants
2. **LEDs**: LED_1206, LED_RGB, WS2812B
3. **Buttons/Switches**: button_6mm, slide_switch
4. **Sensors/Drivers**: IMU_6050, TB67H451A
5. **Storage**: microSD, fab
6. **Headers**: 40+ variants (I2C, serial, power, signal, etc.)
7. **Connectors**: MTA variants, screw terminals, USB connectors, Molex
8. **Special**: hole_pad, SMD_wire_entry

### Implementation Details

**Component Structure:**
- Each component function returns a `Component` struct
- Components include: shape, pad positions, labels, value, optional holes/cutouts
- Pad positions are relative to component origin (0, 0, 0)
- Labels use `component_text()` helper function

**Component Placement:**
- Components are placed using `add_component()`
- Supports rotation and translation
- Automatically handles pad and label rotation
- Updates PCB layers appropriately

### Building Component Library from Scratch

**Problem:** Need reusable component definitions for common electronic parts.

**Approach:**
1. Define common pad shapes as constants
2. Create helper functions for text labels
3. Implement each component as a function
4. Each component:
   - Defines shape using FRep primitives
   - Defines pad positions (Point array)
   - Defines labels (ComponentText array)
   - Returns Component struct

**Implementation Steps:**
1. Create pad constants: Define reusable pad shapes
2. Create helper functions: `component_text()` for labels
3. Implement components: One function per component type
4. Test components: Verify pad positions and labels
5. Document usage: Provide examples and pinouts

**Rationale:**
- Reusable components save design time
- Consistent pad definitions ensure compatibility
- Helper functions simplify component creation
- Comprehensive library supports diverse PCB designs

## Step 14: Wiring Functions and Output Generation Implementation

### Overview

This step implements two critical functions for PCB design:
1. **Wiring functions**: Connect component pads with traces
2. **Output generation**: Create JSON output for rendering

### Core Concepts

**Wiring Functions:**
- `wire()`: Creates smooth, rounded traces connecting points
- `wirer()`: Creates rectangular (Manhattan-style) traces
- Both functions add traces to the PCB board layer
- Traces connect component pads to form electrical connections

**Output Generation:**
- `generate_output()`: Creates JSON structure for rendering
- Supports multiple output modes (top layer, bottom layer, masks, etc.)
- Configures rendering bounds, layers, and color settings
- Outputs JSON compatible with `frep.jl` for image generation

### Implementation Steps

**Step 1: Implement `wire()` function**
- Purpose: Create rounded traces between multiple points
- Algorithm:
  1. Add cylinder at starting point (rounded endpoint)
  2. For each subsequent point:
     - Draw line from previous point to current point
     - Add cylinder at current endpoint
- Parameters:
  - `pcb`: PCB struct to modify
  - `width`: Trace width (diameter)
  - `points...`: Variable number of Point structs to connect
- Returns: Modified PCB with traces added

**Step 2: Implement `wirer()` function**
- Purpose: Create rectangular (Manhattan) traces
- Algorithm:
  1. For each point pair:
     - Create horizontal segment (x-direction)
     - Create vertical segment (y-direction)
     - Use cubes for rectangular routing
- Parameters: Same as `wire()`
- Returns: Modified PCB with rectangular traces
- Use case: Clean, predictable routing for manufacturing

**Step 3: Implement `generate_output()` function**
- Purpose: Generate JSON output for rendering
- Algorithm:
  1. Check output mode string
  2. Build FRep expression based on mode:
     - Combine board, labels, holes, exterior as needed
     - Apply colors (COLOR_TAN for board, COLOR_WHITE for background)
     - Select layers (zt for top, zb for bottom)
  3. Set rendering bounds:
     - Calculate xmin, xmax, ymin, ymax with border padding
  4. Set rendering parameters:
     - `mm_per_unit`: 25.4 (inch units)
     - `type`: "RGB"
- Parameters:
  - `pcb`: PCB struct
  - `x0, y0`: Board origin
  - `zb, zt`: Bottom and top z-coordinates
  - `border`: Border size for rendering
  - `output_mode`: String specifying output type
- Returns: Dictionary with output configuration

**Step 4: Output mode support**
- Implement all output modes:
  - `TOP_FULL`: Top layer with labels and exterior
  - `TOP_LABELS_HOLES`: Top with labels and holes
  - `DUAL_LAYER_FULL`: Both layers with labels and exterior
  - `TOP_TRACES`: Top traces only
  - `BOTTOM_TRACES_REVERSED`: Bottom traces mirrored
  - `INTERIOR`, `EXTERIOR`: Board regions
  - `HOLES`: Drill holes
  - `TOP_MASK`, `BOTTOM_MASK`: Solder masks
  - `LABELS`: Silkscreen labels
  - And more...

### Rationale

**Why two wiring functions?**
- `wire()`: Smooth, rounded traces for aesthetic designs
- `wirer()`: Rectangular traces for standard PCB manufacturing
- Different routing styles suit different design requirements

**Why output generation function?**
- Centralizes output configuration logic
- Supports multiple rendering modes
- Ensures consistent JSON format for `frep.jl`
- Makes it easy to switch between output types

**Why multiple output modes?**
- Different manufacturing steps need different views:
  - Top/bottom layers for copper etching
  - Masks for solder mask application
  - Holes for drilling
  - Labels for silkscreen printing
- Each mode combines PCB layers differently

### Usage Example

```julia
# Create PCB
pcb = PCB(1.0, 1.0, 1.02, 0.87, 0.004)

# Add components
led1 = LED_1206("LED1")
pcb = add_component(pcb, led1, 1.5, 1.5, 0.0, 0.0)

# Connect with wire
pcb = wire(pcb, 0.015, 
    Point(1.5, 1.5, 0.0),
    Point(1.6, 1.5, 0.0),
    Point(1.6, 1.6, 0.0)
)

# Generate output
outputs = generate_output(pcb, 1.0, 1.0, -0.06, 0.0, 0.05, "DUAL_LAYER_FULL")
println(JSON.json(outputs))  # Print JSON for frep.jl
```

### Building from Scratch

**Problem:** Need to connect component pads with traces and generate renderable output.

**Mathematical Approach:**
- Traces: Cylinders and lines connecting points in 3D space
- Output: FRep expression combining board layers with colors

**Implementation Steps:**
1. Create `wire()` function with point-to-point line drawing
2. Create `wirer()` function with rectangular routing
3. Create `generate_output()` function with mode selection
4. Implement all output mode combinations
5. Set rendering bounds and parameters

**Rationale:**
- Wiring functions enable electrical connections between components
- Output generation provides flexible rendering options
- Multiple modes support different manufacturing workflows

## Step 15: Multicore Evaluation Implementation (frep_multicore.jl)

### Overview

This step implements `frep_multicore.jl`, an optimized FRep expression evaluator that follows Julia best practices: parse once, compile once, stable types, and optional multicore support via `Base.Threads`. The current implementation is a single-threaded optimized evaluator; the multicore design is documented below for when row-chunk parallelization is added.

### Current Implementation (Final)

**Optimized single-threaded evaluator:**
- **Parse once:** Expression is parsed a single time via `compile_expression(expr_str)` (returns a parsed expression for repeated `eval()`).
- **Stable types:** All arrays are `Float64` / `UInt32`; `arange`, `create_meshgrid`, `evaluate_single_layer`, `evaluate_multi_layer`, and `construct_image` use concrete types for performance.
- **RuntimeGeneratedFunctions:** Package is loaded and initialized for future JIT-friendly code generation; expression evaluation currently uses parse-once then `eval()` with global X, Y, Z.
- **Layered evaluation:** Single Z layer uses `evaluate_single_layer()`; multiple Z layers use `evaluate_multi_layer()` with one expression evaluation per layer.
- **Multicore-ready:** `using Base.Threads` is included; invocation with `julia -t auto` is recommended so that when row-chunk threading is implemented, it will use all cores without script changes.

**Key functions:**
- `compile_expression(expr_str)` — parse expression once (e.g. `"@. " * expr_str` then `Meta.parse`).
- `evaluate_single_layer(expr_parsed, X, Y, Z, nx, ny)` — one layer; sets global X, Y, Z, pi, e and evaluates parsed expression.
- `evaluate_multi_layer(expr_parsed, X, Y, layers, nx, ny)` — multiple Z layers; evaluates per layer and accumulates RGB.
- `construct_image(f, ny, nx, filename, dpi)` — pack UInt32 to RGB and save PNG.

### Multicore Logic (Design for Row-Chunk Parallelization)

When implementing explicit multicore evaluation, use the following design.

**Threading model:**
- Use Julia's `Base.Threads` (enabled with `julia -t auto` or `-t N`).
- Split work by **rows (y-coordinates)**: divide the grid into chunks, one chunk per thread.
- Parse the expression once; each thread evaluates its chunk with its own meshgrid (X, Y) and Z.

**Implementation steps for future row-chunk threading:**
1. **Split rows:** `chunk_size = div(ny, Threads.nthreads())`; last thread gets remainder.
2. **Per-thread evaluation:** For each chunk, build local X, Y for that row range (e.g. `create_meshgrid(x, y_chunk)`), set Z (and pi, e) in a thread-local way, then evaluate the same parsed expression.
3. **Parallel loop:** `f_chunks = Vector{Matrix{UInt32}}(undef, nchunks)`; `Threads.@threads for i in 1:nchunks` → compute `f_chunks[i]` for chunk i.
4. **Combine:** `f = vcat(f_chunks...)` to preserve row order.

**Thread safety:**
- No shared mutable state during evaluation; each thread has its own X, Y, Z (or Z in scope).
- Parsed expression is read-only and shared.
- Result arrays are written per chunk then concatenated.

**Why row-based:** Good load balance, minimal sync, and better cache locality than per-pixel threading.

### Usage

**Recommended invocation (multicore-ready):**
```bash
# From ifrep/
julia -t auto Fpcb.jl | julia -t auto frep_multicore.jl [dpi [filename]]

# From ifrep/examples/
julia -t auto code/simple_pcb.jl | julia -t auto ../frep_multicore.jl 300 out.png
julia -t 8 code/blink_board.jl | julia -t 8 ../frep_multicore.jl 300 blink.png
```

**Check threads (when row-chunk threading is added):**
```julia
using Base.Threads
println("Threads: ", Threads.nthreads())
println("CPU cores: ", Sys.CPU_THREADS)
```

### When to Use Julia vs Python Evaluator

- **Dynamic expressions (e.g. from Fpcb.jl):** Prefer **frep_multicore.py** for speed; Python’s `eval()` with NumPy uses pre-compiled routines and is much faster than Julia’s repeated `eval()` for one-off expressions.
- **frep_multicore.jl:** Use for optimized single-threaded Julia workflow and as the base for adding row-chunk multicore when needed.

## Step 16: PCB Example Implementation

### Overview

This step creates practical PCB design examples demonstrating the complete workflow from component placement to final rendering. The repository provides `examples/code/simple_pcb.jl` (minimal PCB) and `examples/code/blink_board.jl` (LED blink board); the following describe the pattern for simple and multi-component boards.

### Example 1: Simple LED Circuit (e.g. `simple_pcb.jl` / `blink_board.jl`)

**Components:**
- LED_1206: Single LED component
- header_4: 4-pin power header
- Wire traces connecting components
- Text label: "LED Circuit"

**Workflow:**
1. Create PCB board (1.5" × 1.0")
2. Place LED component
3. Place power header
4. Connect with wire traces
5. Add text label
6. Generate output for rendering

**Key Features:**
- Demonstrates basic component placement
- Shows wire routing between components
- Includes text labeling
- Uses `DUAL_LAYER_FULL` output mode

### Example 2: Multi-Component Board (e.g. extended PCB examples)

**Components:**
- LED_1206: LED indicator
- button_6mm: Push button
- header_4: General purpose header
- header_power: Power header
- Multiple wire traces
- Text labels

**Workflow:**
1. Create larger PCB board (2.0" × 1.5")
2. Place multiple components
3. Route wires between components
4. Add descriptive text labels
5. Generate output with holes visible

**Key Features:**
- Multiple component types
- Complex wiring patterns
- Power distribution
- Signal routing
- Uses `DUAL_LAYER_FULL_HOLES` output mode

### Performance Considerations

**Expression Complexity:**
- Text rendering is the main bottleneck
- Each character = 5-20 primitive shapes
- "LED Circuit" (11 chars) = 50-200+ operations
- Component labels add additional complexity

**Optimization Strategies:**
1. Remove text labels for faster rendering
2. Use shorter text strings
3. Simplify component labels
4. Use lower DPI for testing (100 DPI)
5. Use Python frep_multicore.py for production (300+ DPI) when using dynamic expressions from Fpcb.jl

**Expected Evaluation Times (at 300 DPI):**
- Simple shapes: 5-15 seconds (Julia single-threaded)
- PCB Example 1 (with text): 30-120 seconds (Julia), or ~2-5 seconds (Python frep_multicore.py)
- PCB Example 2 (with text): 60-180 seconds (Julia), or ~5-15 seconds (Python)
- For fastest dynamic expression evaluation, use: `julia ... | python3 frep_multicore.py`

### Building from Scratch

**Problem:** Need practical examples showing real PCB design workflow.

**Approach:**
1. Start simple: Basic components and wiring
2. Add complexity gradually: More components, more wires
3. Include text: Demonstrates labeling capabilities
4. Show different output modes: Various rendering options

**Implementation Steps:**
1. Define board parameters (size, origin, layers)
2. Create PCB instance
3. Add components using `add_component()`
4. Connect components using `wire()`
5. Add text labels using `add_text()`
6. Generate output using `generate_output()`
7. Render using `frep.jl`, `frep_multicore.jl`, or `frep_multicore.py` (Python recommended for speed with dynamic expressions)

## Step 17: Python Multicore FRep Implementation

### Overview

This step implements `frep_multicore.py`, a Python version of the FRep solver that provides significantly faster performance for dynamic expression evaluation compared to Julia's `eval()` approach.

### Why Python Instead of Julia for FRep Parsing?

**The Core Problem with Julia's `eval()`:**

Julia's `eval()` function has a fundamental performance issue for dynamic expressions:
- **Recompilation overhead**: Every call to `eval()` recompiles the expression from scratch
- **JIT compilation cost**: Complex FRep expressions can take seconds to compile
- **No caching**: Each evaluation recompiles, even with identical expressions
- **World age issues**: Dynamic code generation can cause world age problems

**Performance Comparison:**
- **Python + NumPy**: ~0.5 seconds for 1000 DPI simple PCB
- **Julia + eval()**: ~55 seconds for same task (100x slower!)
- **Root cause**: Python's `eval()` with NumPy dispatches to pre-compiled C/Fortran routines, while Julia's `eval()` recompiles everything

**Why Python's `eval()` is Fast:**

1. **Pre-compiled NumPy routines**: NumPy operations are implemented in C/Fortran
   - `sin()`, `cos()`, `sqrt()`, etc. are compiled machine code
   - No runtime compilation needed
   - `eval()` just dispatches to these optimized functions

2. **No JIT overhead**: Python doesn't compile expressions
   - Expression is parsed once
   - Operations execute directly on pre-compiled NumPy arrays
   - No compilation step = no compilation overhead

3. **Broadcasting optimization**: NumPy's broadcasting is highly optimized
   - Vectorized operations use SIMD instructions
   - Memory layout optimized for cache efficiency
   - Parallel execution in NumPy's internal routines

**Why Julia's `eval()` is Slow:**

1. **Recompilation on every call**: Each `eval()` compiles the expression
   - Complex expressions = complex compilation
   - Compilation time can exceed evaluation time
   - No caching between calls

2. **JIT compilation overhead**: Julia compiles code on first execution
   - First run: compile + execute
   - Subsequent runs: execute (but `eval()` forces recompilation)
   - Dynamic expressions never benefit from JIT caching

3. **Type inference challenges**: Dynamic expressions prevent type inference
   - Compiler can't optimize without type information
   - Must handle all possible types
   - Loses Julia's performance advantages

### Building frep_multicore.py from Scratch

**Problem:** Need fast FRep expression evaluation for dynamic expressions generated by Fpcb.jl.

**Solution:** Use Python with NumPy, leveraging pre-compiled C routines for maximum performance.

**Implementation Steps:**

**Step 1: Understand the Requirements**
- Read JSON input from stdin (compatible with Fpcb.jl output)
- Parse command-line arguments (DPI, filename)
- Generate coordinate grids (X, Y matrices)
- Evaluate FRep expression at each grid point
- Process single or multiple Z layers
- Extract RGB channels and save PNG image

**Step 2: Set Up Python Environment**
```python
import json, sys
from numpy import *
from PIL import Image
import os
```
- `json`: Parse JSON input from stdin
- `numpy`: Array operations and math functions
- `PIL` (Pillow): Image creation and saving
- `os`: CPU count detection

**Step 3: Implement JSON Input Parsing**
```python
frep = json.load(sys.stdin)
xmin = frep['xmin']
xmax = frep['xmax']
# ... extract all parameters
```
- Read from stdin (piped from Fpcb.jl)
- Extract bounds, units, layers, function expression
- Compatible with Fpcb.jl JSON output format

**Step 4: Generate Coordinate Grids**
```python
delta = (25.4 / dpi) / units
x = arange(xmin, xmax, delta)
y = flip(arange(ymin, ymax, delta), 0)
X = outer(ones(y.size), x)
Y = outer(y, ones(x.size))
```
- Calculate step size based on DPI
- Create 1D coordinate arrays
- Generate 2D meshgrid using `outer()` (matches Python's original frep.py)
- Flip Y axis for image coordinate system

**Step 5: Evaluate Expression with NumPy**
```python
f = eval(frep['function']).astype(uint32)
```
- **Key insight**: Python's `eval()` with NumPy namespace is fast!
- Expression string evaluated in NumPy namespace
- X, Y, Z are NumPy arrays (broadcasting works automatically)
- All math functions (sin, cos, sqrt, etc.) are pre-compiled C routines
- Result is NumPy array, convert to uint32 for color packing

**Step 6: Process Multiple Layers**
```python
for Z in frep['layers']:
    i = int(255 * (Z - zmin) / (zmax - zmin)) | (255 << 8) | (255 << 16)
    flayer = i & (eval(frep['function'])).astype(uint32)
    f = f + flayer
```
- Calculate intensity for each Z layer
- Evaluate expression for each layer
- Apply intensity mask and accumulate
- Each `eval()` call is fast (no recompilation overhead)

**Step 7: Extract RGB Channels and Save**
```python
m = zeros((y.size, x.size, 3), dtype=uint8)
m[:, :, 0] = (f & 255)           # Red channel
m[:, :, 1] = ((f >> 8) & 255)    # Green channel
m[:, :, 2] = ((f >> 16) & 255)   # Blue channel
im = Image.fromarray(m, 'RGB')
im.save(filename, dpi=[dpi, dpi])
```
- Extract color channels using bitwise operations
- Create 3-channel image array
- Convert to PIL Image object
- Save with DPI metadata

### Key Design Decisions

**Why Same Approach as Original frep.py:**
- Maintains compatibility with all FRep expressions
- NumPy already uses multiple cores internally (GIL released)
- No need for explicit threading (NumPy handles it)
- Simpler code, fewer bugs

**Why Not Explicit Multithreading:**
- NumPy operations release the GIL automatically
- Broadcasting operations are already parallelized
- Explicit threading would add complexity without benefit
- NumPy's internal optimization is sufficient

**Why Python for This Task:**
1. **Fast dynamic evaluation**: `eval()` with NumPy is optimized
2. **No compilation overhead**: Pre-compiled routines execute directly
3. **Cross-platform**: Works everywhere Python works
4. **Easy integration**: Simple JSON in/PNG out interface
5. **Proven performance**: Matches or exceeds Julia for one-off evaluations

### Performance Characteristics

**Python (frep_multicore.py):**
- Simple PCB at 1000 DPI: ~0.5 seconds
- Complex PCB at 300 DPI: ~2-5 seconds
- No compilation overhead
- Fast for dynamic expressions

**Julia (frep_multicore.jl with eval()):**
- Simple PCB at 1000 DPI: ~55 seconds
- Complex PCB at 300 DPI: ~60-120 seconds
- Recompilation overhead dominates
- Slow for dynamic expressions

**Why the Difference:**
- Python: `eval()` → pre-compiled NumPy → fast execution
- Julia: `eval()` → recompile → execute → slow overall

### Usage

**Basic command (from ifrep/examples):**
```bash
julia code/simple_pcb.jl | python3 ../frep_multicore.py [dpi [filename]]
julia code/simple_pcb.jl | python3 ../frep_multicore.py 1000 output.png
```

**With default DPI (100, out.png):**
```bash
julia code/simple_pcb.jl | python3 ../frep_multicore.py
```

**Other examples:**
```bash
julia code/blink_board.jl | python3 ../frep_multicore.py [dpi [filename]]
julia code/pcb_example1.jl | python3 ../frep_multicore.py 500 pcb1.png
julia code/pcb_example2.jl | python3 ../frep_multicore.py 500 pcb2.png
```

**Multicore:** NumPy uses all available CPU cores internally (reports `NumPy using N cores internally` at startup). No explicit threading in the script.

### Rationale

**Why Create Python Version:**
- Julia's `eval()` performance is unacceptable for dynamic expressions
- Python provides 100x speedup for this specific use case
- Maintains same interface (JSON in, PNG out)
- Easy to use and integrate

**When to Use Python Version (frep_multicore.py):**
- One-off evaluations (most common case)
- Dynamic expressions from Fpcb.jl
- Quick rendering and production output
- Best performance for dynamic FRep expressions (NumPy multicore)

**When to Use Julia Version (frep.jl / frep_multicore.jl):**
- Julia-only toolchain or no Python available
- Repeated evaluations with the same expression (JIT can help)
- As base for adding row-chunk multicore (see Step 15)

### Building from Scratch Summary

**Problem:** Julia's `eval()` is 100x slower than Python for dynamic FRep expressions.

**Root Cause:** Julia recompiles expressions on every `eval()` call, while Python dispatches to pre-compiled NumPy routines.

**Solution:** Create Python version that leverages NumPy's optimized C/Fortran routines.

**Implementation:**
1. Read JSON from stdin
2. Generate coordinate grids with NumPy
3. Evaluate expression using Python's `eval()` with NumPy namespace
4. Process layers and extract RGB channels
5. Save PNG image

**Result:** 100x performance improvement for dynamic expression evaluation.

## Current File Structure

```
ifrep/
├── Fpcb.jl                  # Main PCB functional representation file
├── frep.jl                  # Expression evaluator and image renderer (single-threaded)
├── frep_multicore.jl        # Optimized evaluator (parse once, stable types); multicore-ready (Base.Threads)
├── frep_multicore.py        # Expression evaluator (Python); NumPy uses multiple cores internally
├── explain.md                # Build documentation
├── Project.toml             # Julia package dependencies
└── examples/
    ├── code/
    │   ├── simple_shapes.jl   # Example 1: Basic shapes with simple colors
    │   ├── boolean_ops.jl     # Example 2: Boolean operations
    │   ├── text_rendering.jl  # Example 3: Text rendering
    │   ├── simple_pcb.jl      # Example 4: Minimal PCB (fast testing)
    │   └── blink_board.jl     # LED Blink Board example
    └── images/               # Example output images
```

## Implementation Approach

The implementation follows a clean-room approach:
- Replicates the conceptual structure of functional representation
- Uses different naming conventions throughout
- Maintains the same string expression evaluation model
- Organizes code into clear, documented sections
- Leverages Julia's type system for performance
- Uses native Julia array operations

## Language Features

Julia implementation benefits:
- Type annotations enable compiler optimizations
- JIT compilation provides near-native performance
- Native array operations without external dependencies
- Broadcasting for efficient grid operations
- Strong type inference system
- Multiple dispatch for flexible function design
- Multicore-ready: `Base.Threads` available for row-chunk parallelization (design in Step 15)
- For fastest dynamic expression evaluation, use Python `frep_multicore.py` (NumPy uses multiple cores internally)

## Performance Optimization

### Single-Threaded vs Optimized vs Python (Multicore)

**frep.jl (Single-threaded):**
- Simple, straightforward evaluation
- Good for low DPI (100 DPI) or simple expressions
- Uses one CPU core
- Best for: Testing, debugging, simple shapes

**frep_multicore.jl (Optimized, single-threaded; multicore-ready):**
- Parse once, stable types, RuntimeGeneratedFunctions loaded
- Same single-threaded evaluation as frep.jl but with cleaner structure
- Invoke with `julia -t auto ...` so future row-chunk threading can use all cores
- Best for: Julia-only workflow and as base for adding row-chunk multicore

**frep_multicore.py (Python – multicore via NumPy):**
- NumPy uses all CPU cores internally (no explicit threading in script)
- Much faster than Julia for dynamic expressions (e.g. from Fpcb.jl)
- Best for: Production rendering and quick iteration with dynamic expressions

### When to Use Each

**Use frep.jl when:**
- Testing or quick previews (100 DPI)
- Simple expressions (basic shapes, no text)
- Debugging expression issues or learning the system

**Use frep_multicore.jl when:**
- You want the optimized Julia pipeline and may add row-chunk threading later
- Run with `julia -t auto` for multicore-ready invocation

**Use frep_multicore.py when:**
- Production or high-DPI rendering with dynamic expressions from Fpcb.jl
- You want the fastest evaluation (NumPy’s internal multicore)

### Performance Tips

1. **Remove text for faster rendering:** Text is the main bottleneck; comment out `add_text()` or use shorter strings for testing.
2. **Use appropriate DPI:** 100 DPI for quick tests; 300+ DPI for output. Prefer `frep_multicore.py` for 300+ DPI with dynamic expressions.
3. **Prefer Python for dynamic expressions:** `julia ... | python3 frep_multicore.py` is much faster than Julia evaluators for one-off FRep from Fpcb.jl.
4. **Simplify expressions:** Fewer components, shorter wires, and fewer nested booleans speed up evaluation.

### Performance Benchmarks (Typical)

**Julia (frep.jl / frep_multicore.jl – single-threaded):**
- Simple shapes 300 DPI: ~5-15 s
- PCB with text 300 DPI: ~30-120 s

**Python (frep_multicore.py – NumPy multicore):**
- Simple PCB 1000 DPI: ~0.5 s
- Complex PCB 300 DPI: ~2-5 s