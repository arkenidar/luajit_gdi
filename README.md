# LuaJIT GDI Drawing Example

A simple Windows GDI graphics demonstration using LuaJIT's FFI (Foreign Function Interface) to call Windows API functions directly from Lua.

## Description

This project demonstrates how to create a Windows application entirely in Lua using LuaJIT's FFI capabilities. It creates a window and draws two overlapping rectangles using the Windows Graphics Device Interface (GDI).

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
