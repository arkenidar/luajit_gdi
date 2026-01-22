# LuaJIT GDI Drawing Example

> **TL;DR:** An interactive fractal viewer. Zoom in with mouse wheel or left-click, zoom out with right-click. Press ESC to exit. Available in both C and Lua versions.

A simple Windows GDI graphics demonstration using LuaJIT's FFI (Foreign Function Interface) to call Windows API functions directly from Lua.

## Description

This project demonstrates how to create a Windows application entirely in Lua using LuaJIT's FFI capabilities. It creates an interactive Mandelbrot fractal explorer using the Windows Graphics Device Interface (GDI).

## The Mandelbrot Set

The Mandelbrot set is a famous fractal defined by iterating a simple formula on complex numbers.

### Formula

For each point $c$ in the complex plane, we iterate:

$$z_{n+1} = z_n^2 + c$$

Starting with $z_0 = 0$. A point $c$ belongs to the Mandelbrot set if this sequence remains bounded (does not escape to infinity).

### Algorithm

1. For each pixel, map its $(x, y)$ coordinates to a complex number $c = x + yi$
2. Initialize $z = 0$
3. Iterate $z \leftarrow z^2 + c$ up to a maximum number of iterations
4. If $|z|^2 > 4$ (escape radius), the point escapes — color based on iteration count
5. If the point never escapes, color it black (part of the Mandelbrot set)

### Color Mapping

Points that escape are colored using a smooth polynomial gradient based on how quickly they escape:

$$t = \frac{\text{iterations}}{\text{max\_iterations}}$$

- Red: $9(1-t)t^3 \times 255$
- Green: $15(1-t)^2t^2 \times 255$  
- Blue: $8.5(1-t)^3t \times 255$

## Features

- Direct Windows API calls from Lua using FFI
- Window creation and message loop handling
- GDI drawing operations
- Proper callback handling for window procedures

## Requirements

- **LuaJIT** (2.0 or later)
- **Windows OS** (uses Windows GDI and User32 APIs)

## Installation

1. Install LuaJIT if not already installed:
   ```bash
   # On MSYS2/MinGW
   pacman -S mingw-w64-x86_64-luajit
   ```

2. Clone or download this repository

## Usage

Run the program with:
```bash
luajit gdi_draw.lua
```

A window will appear displaying two overlapping rectangles. Close the window by clicking the X button.

## Code Structure

- **FFI Declarations**: Windows types and function signatures
- **Window Procedure**: Callback function handling WM_PAINT and WM_DESTROY messages
- **Main Function**: Window class registration, window creation, and message loop
- **Helper Functions**: Wide character string conversion utilities

## Technical Details

The program uses:
- `ffi.cdef` to declare Windows API structures and functions
- `ffi.cast` to create proper callback functions for window procedures
- `ffi.new` to allocate C structures from Lua
- Direct calls to `user32.dll` and `gdi32.dll` functions

## Original C Code

This Lua implementation is a port of the C program in `gdi_draw.c`, demonstrating how Windows applications can be created using pure Lua with FFI.

## License

Public Domain / Unlicense
