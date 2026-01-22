local ffi = require("ffi")
local bit = require("bit")

ffi.cdef [[
    typedef struct HWND__* HWND;
    typedef struct HDC__* HDC;
    typedef struct HINSTANCE__* HINSTANCE;
    typedef struct HICON__* HICON;
    typedef struct HBRUSH__* HBRUSH;
    typedef struct HMENU__* HMENU;
    typedef struct HBITMAP__* HBITMAP;
    typedef struct HGDIOBJ__* HGDIOBJ;
    typedef void* LPVOID;
    typedef void* PVOID;
    typedef const char* LPCSTR;
    typedef const wchar_t* LPCWSTR;
    typedef unsigned int UINT;
    typedef long LONG;
    typedef unsigned long DWORD;
    typedef long long LONG_PTR;
    typedef unsigned long long UINT_PTR;
    typedef UINT_PTR WPARAM;
    typedef LONG_PTR LPARAM;
    typedef LONG_PTR LRESULT;
    typedef int BOOL;
    typedef unsigned short WORD;

    typedef struct {
        UINT    style;
        LONG_PTR lpfnWndProc;
        int     cbClsExtra;
        int     cbWndExtra;
        HINSTANCE hInstance;
        HICON   hIcon;
        HICON   hCursor;
        HBRUSH  hbrBackground;
        LPCWSTR lpszMenuName;
        LPCWSTR lpszClassName;
    } WNDCLASSW;

    typedef struct {
        HWND   hwnd;
        UINT   message;
        WPARAM wParam;
        LPARAM lParam;
        DWORD  time;
        LONG   x;
        LONG   y;
    } MSG;

    typedef struct {
        HDC  hdc;
        BOOL fErase;
        LONG left;
        LONG top;
        LONG right;
        LONG bottom;
        BOOL fRestore;
        BOOL fIncUpdate;
        char rgbReserved[32];
    } PAINTSTRUCT;

    typedef struct {
        LONG left;
        LONG top;
        LONG right;
        LONG bottom;
    } RECT;

    typedef struct {
        LONG x;
        LONG y;
    } POINT;

    typedef struct {
        DWORD biSize;
        LONG  biWidth;
        LONG  biHeight;
        WORD  biPlanes;
        WORD  biBitCount;
        DWORD biCompression;
        DWORD biSizeImage;
        LONG  biXPelsPerMeter;
        LONG  biYPelsPerMeter;
        DWORD biClrUsed;
        DWORD biClrImportant;
    } BITMAPINFOHEADER;

    typedef struct {
        BITMAPINFOHEADER bmiHeader;
        DWORD            bmiColors[1];
    } BITMAPINFO;

    // Constants
    static const int CS_HREDRAW = 0x0002;
    static const int CS_VREDRAW = 0x0001;
    static const int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static const int WS_VISIBLE = 0x10000000;
    static const int WM_PAINT = 0x000F;
    static const int WM_DESTROY = 0x0002;
    static const int WM_ERASEBKGND = 0x0014;
    static const int WM_KEYDOWN = 0x0100;
    static const int WM_LBUTTONDOWN = 0x0201;
    static const int WM_RBUTTONDOWN = 0x0204;
    static const int WM_MOUSEWHEEL = 0x020A;
    static const int VK_ESCAPE = 0x1B;
    static const int IDC_ARROW = 32512;
    static const int DIB_RGB_COLORS = 0;
    static const int BI_RGB = 0;
    static const int SRCCOPY = 0x00CC0020;

    // Function declarations
    HBRUSH GetSysColorBrush(int nIndex);
    HICON LoadCursorA(HINSTANCE hInstance, LPCSTR lpCursorName);
    BOOL RegisterClassW(const WNDCLASSW* lpWndClass);
    HWND CreateWindowExW(
        DWORD dwExStyle,
        LPCWSTR lpClassName,
        LPCWSTR lpWindowName,
        DWORD dwStyle,
        int X, int Y, int nWidth, int nHeight,
        HWND hWndParent, HMENU hMenu,
        HINSTANCE hInstance, LPVOID lpParam
    );
    BOOL GetMessageW(MSG* lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax);
    BOOL TranslateMessage(const MSG* lpMsg);
    LRESULT DispatchMessageW(const MSG* lpMsg);
    LRESULT DefWindowProcW(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
    HDC BeginPaint(HWND hWnd, PAINTSTRUCT* lpPaint);
    BOOL EndPaint(HWND hWnd, const PAINTSTRUCT* lpPaint);
    void PostQuitMessage(int nExitCode);
    HINSTANCE GetModuleHandleW(LPCWSTR lpModuleName);
    BOOL GetClientRect(HWND hWnd, RECT* lpRect);
    BOOL InvalidateRect(HWND hWnd, const RECT* lpRect, BOOL bErase);
    BOOL ScreenToClient(HWND hWnd, POINT* lpPoint);

    // DIB functions
    HBITMAP CreateDIBSection(HDC hdc, const BITMAPINFO* pbmi, UINT usage,
                            void** ppvBits, void* hSection, DWORD offset);
    HDC CreateCompatibleDC(HDC hdc);
    HGDIOBJ SelectObject(HDC hdc, HGDIOBJ h);
    BOOL BitBlt(HDC hdcDest, int x, int y, int cx, int cy,
                HDC hdcSrc, int x1, int y1, DWORD rop);
    BOOL DeleteDC(HDC hdc);
    BOOL DeleteObject(HGDIOBJ ho);
]]

local C = ffi.C

-- Global state
local zoom = 1.0
local center_x = -0.5
local center_y = 0.0
local max_iter = 256

-- Mandelbrot calculation
local function mandelbrot(cx, cy, max_iter)
    local x, y = 0.0, 0.0
    local xx, yy = 0.0, 0.0
    local iter = 0

    while iter < max_iter and xx + yy < 4.0 do
        y = 2.0 * x * y + cy
        x = xx - yy + cx
        xx = x * x
        yy = y * y
        iter = iter + 1
    end

    return iter
end

-- Color mapping function
local function get_color(iter, max_iter)
    if iter == max_iter then
        return 0x00000000 -- Black for points in the set
    end

    -- Smooth color gradient (BGR format for DIB)
    local t = iter / max_iter
    local r = math.floor(9 * (1 - t) * t * t * t * 255)
    local g = math.floor(15 * (1 - t) * (1 - t) * t * t * 255)
    local b = math.floor(8.5 * (1 - t) * (1 - t) * (1 - t) * t * 255)

    -- Pack as 0x00BBGGRR
    return b * 65536 + g * 256 + r
end

-- Fast render using DIB (Device Independent Bitmap)
local function render_mandelbrot(hdc, width, height)
    -- Create DIB section
    local bmi = ffi.new("BITMAPINFO")
    bmi.bmiHeader.biSize = ffi.sizeof("BITMAPINFOHEADER")
    bmi.bmiHeader.biWidth = width
    bmi.bmiHeader.biHeight = -height -- Negative for top-down
    bmi.bmiHeader.biPlanes = 1
    bmi.bmiHeader.biBitCount = 32
    bmi.bmiHeader.biCompression = 0 -- BI_RGB

    local pixels_ptr = ffi.new("void*[1]")
    local hBitmap = C.CreateDIBSection(hdc, bmi, 0, pixels_ptr, nil, 0)

    if hBitmap == nil or pixels_ptr[0] == nil then
        return
    end

    local pixels = ffi.cast("uint32_t*", pixels_ptr[0])

    -- Calculate bounds
    local x_min = center_x - 2.0 / zoom
    local x_max = center_x + 2.0 / zoom
    local y_min = center_y - 1.5 / zoom
    local y_max = center_y + 1.5 / zoom

    -- Render directly to memory
    for py = 0, height - 1 do
        for px = 0, width - 1 do
            local cx = x_min + (px / width) * (x_max - x_min)
            local cy = y_min + (py / height) * (y_max - y_min)
            local iter = mandelbrot(cx, cy, max_iter)
            pixels[py * width + px] = get_color(iter, max_iter)
        end
    end

    -- Blit to screen
    local memDC = C.CreateCompatibleDC(hdc)
    if memDC ~= nil then
        local oldBitmap = C.SelectObject(memDC, ffi.cast("HGDIOBJ", hBitmap))
        C.BitBlt(hdc, 0, 0, width, height, memDC, 0, 0, 0x00CC0020) -- SRCCOPY
        C.SelectObject(memDC, oldBitmap)
        C.DeleteDC(memDC)
    end
    C.DeleteObject(ffi.cast("HGDIOBJ", hBitmap))
end

-- Window procedure callback
local WndProc = ffi.cast("LONG_PTR (*)(HWND, UINT, WPARAM, LPARAM)", function(hwnd, msg, wParam, lParam)
    local status, result = pcall(function()
        if msg == 0x000F then -- WM_PAINT
            local ps = ffi.new("PAINTSTRUCT")
            local hdc = C.BeginPaint(hwnd, ps)

            local rect = ffi.new("RECT")
            C.GetClientRect(hwnd, rect)
            local width = rect.right - rect.left
            local height = rect.bottom - rect.top

            print(string.format("Rendering Mandelbrot... (zoom: %.2f, center: %.4f, %.4f)", zoom, center_x, center_y))
            render_mandelbrot(hdc, width, height)
            print("Done!")

            C.EndPaint(hwnd, ps)
            return 0
        elseif msg == 0x0014 then  -- WM_ERASEBKGND
            return 1               -- Don't erase
        elseif msg == 0x0100 then  -- WM_KEYDOWN
            if wParam == 0x1B then -- VK_ESCAPE
                C.PostQuitMessage(0)
                return 0
            end
        elseif msg == 0x0201 then -- WM_LBUTTONDOWN
            local rect = ffi.new("RECT")
            C.GetClientRect(hwnd, rect)
            local width = rect.right - rect.left
            local height = rect.bottom - rect.top

            local mouse_x = bit.band(tonumber(lParam), 0xFFFF)
            local mouse_y = bit.rshift(tonumber(lParam), 16)

            -- Get point in complex plane before zoom
            local x_min = center_x - 2.0 / zoom
            local x_max = center_x + 2.0 / zoom
            local y_min = center_y - 1.5 / zoom
            local y_max = center_y + 1.5 / zoom
            local point_x = x_min + (mouse_x / width) * (x_max - x_min)
            local point_y = y_min + (mouse_y / height) * (y_max - y_min)

            -- Zoom in
            local zoom_factor = 1.5
            zoom = zoom * zoom_factor

            -- Adjust center so point stays under cursor
            local new_x_min = center_x - 2.0 / zoom
            local new_x_max = center_x + 2.0 / zoom
            local new_y_min = center_y - 1.5 / zoom
            local new_y_max = center_y + 1.5 / zoom
            local new_point_x = new_x_min + (mouse_x / width) * (new_x_max - new_x_min)
            local new_point_y = new_y_min + (mouse_y / height) * (new_y_max - new_y_min)
            center_x = center_x + (point_x - new_point_x)
            center_y = center_y + (point_y - new_point_y)

            print(string.format("Zoom IN - new zoom: %.2f", zoom))
            C.InvalidateRect(hwnd, nil, 0)
            return 0
        elseif msg == 0x0204 then -- WM_RBUTTONDOWN
            local rect = ffi.new("RECT")
            C.GetClientRect(hwnd, rect)
            local width = rect.right - rect.left
            local height = rect.bottom - rect.top

            local mouse_x = bit.band(tonumber(lParam), 0xFFFF)
            local mouse_y = bit.rshift(tonumber(lParam), 16)

            -- Get point in complex plane before zoom
            local x_min = center_x - 2.0 / zoom
            local x_max = center_x + 2.0 / zoom
            local y_min = center_y - 1.5 / zoom
            local y_max = center_y + 1.5 / zoom
            local point_x = x_min + (mouse_x / width) * (x_max - x_min)
            local point_y = y_min + (mouse_y / height) * (y_max - y_min)

            -- Zoom out
            local zoom_factor = 1.5
            zoom = zoom / zoom_factor

            -- Adjust center so point stays under cursor
            local new_x_min = center_x - 2.0 / zoom
            local new_x_max = center_x + 2.0 / zoom
            local new_y_min = center_y - 1.5 / zoom
            local new_y_max = center_y + 1.5 / zoom
            local new_point_x = new_x_min + (mouse_x / width) * (new_x_max - new_x_min)
            local new_point_y = new_y_min + (mouse_y / height) * (new_y_max - new_y_min)
            center_x = center_x + (point_x - new_point_x)
            center_y = center_y + (point_y - new_point_y)

            print(string.format("Zoom OUT - new zoom: %.2f", zoom))
            C.InvalidateRect(hwnd, nil, 0)
            return 0
        elseif msg == 0x020A then              -- WM_MOUSEWHEEL
            local delta = bit.rshift(bit.band(tonumber(wParam), 0xFFFF0000), 16)
            delta = ffi.cast("int16_t", delta) -- Signed conversion

            local rect = ffi.new("RECT")
            C.GetClientRect(hwnd, rect)
            local width = rect.right - rect.left
            local height = rect.bottom - rect.top

            local pt = ffi.new("POINT")
            pt.x = bit.band(tonumber(lParam), 0xFFFF)
            pt.y = bit.rshift(tonumber(lParam), 16)
            C.ScreenToClient(hwnd, pt)

            -- Get point in complex plane before zoom
            local x_min = center_x - 2.0 / zoom
            local x_max = center_x + 2.0 / zoom
            local y_min = center_y - 1.5 / zoom
            local y_max = center_y + 1.5 / zoom
            local point_x = x_min + (pt.x / width) * (x_max - x_min)
            local point_y = y_min + (pt.y / height) * (y_max - y_min)

            -- Apply zoom
            local zoom_factor = 1.15
            if delta > 0 then
                zoom = zoom * zoom_factor
                print(string.format("Wheel Zoom IN - new zoom: %.2f", zoom))
            else
                zoom = zoom / zoom_factor
                print(string.format("Wheel Zoom OUT - new zoom: %.2f", zoom))
            end

            -- Adjust center so point stays under cursor
            local new_x_min = center_x - 2.0 / zoom
            local new_x_max = center_x + 2.0 / zoom
            local new_y_min = center_y - 1.5 / zoom
            local new_y_max = center_y + 1.5 / zoom
            local new_point_x = new_x_min + (pt.x / width) * (new_x_max - new_x_min)
            local new_point_y = new_y_min + (pt.y / height) * (new_y_max - new_y_min)
            center_x = center_x + (point_x - new_point_x)
            center_y = center_y + (point_y - new_point_y)

            C.InvalidateRect(hwnd, nil, 0)
            return 0
        elseif msg == 0x0002 then -- WM_DESTROY
            C.PostQuitMessage(0)
            return 0
        end

        return C.DefWindowProcW(hwnd, msg, wParam, lParam)
    end)

    if not status then
        print("ERROR in WndProc: " .. tostring(result))
        return C.DefWindowProcW(hwnd, msg, wParam, lParam)
    end
    return result or 0
end)

-- Helper function to convert string to wide string
local function to_wchar(str)
    local len = #str + 1
    local wstr = ffi.new("wchar_t[?]", len)
    for i = 1, #str do
        wstr[i - 1] = string.byte(str, i)
    end
    wstr[#str] = 0
    return wstr
end

-- Main function
local function main()
    local hInstance = C.GetModuleHandleW(nil)

    local wc = ffi.new("WNDCLASSW")
    wc.style = 0x0002 + 0x0001 -- CS_HREDRAW | CS_VREDRAW
    wc.lpszClassName = ffi.cast("LPCWSTR", to_wchar("Mandelbrot"))
    wc.hInstance = hInstance
    wc.hbrBackground = nil                                     -- No background to prevent flicker
    wc.lpfnWndProc = ffi.cast("LONG_PTR", WndProc)
    wc.hCursor = C.LoadCursorA(nil, ffi.cast("LPCSTR", 32512)) -- IDC_ARROW

    C.RegisterClassW(wc)

    local title = to_wchar("Mandelbrot Explorer (Lua version) - Wheel/Click: Zoom, ESC: Exit")

    C.CreateWindowExW(
        0,
        wc.lpszClassName,
        ffi.cast("LPCWSTR", title),
        0x00CF0000 + 0x10000000, -- WS_OVERLAPPEDWINDOW | WS_VISIBLE
        100, 100, 800, 600,
        nil, nil, hInstance, nil
    )

    local msg = ffi.new("MSG")
    while C.GetMessageW(msg, nil, 0, 0) ~= 0 do
        C.TranslateMessage(msg)
        C.DispatchMessageW(msg)
    end

    return msg.wParam
end

-- Run the program
print("Starting Mandelbrot Explorer...")
print("Controls:")
print("  - Mouse Wheel: Smooth zoom in/out")
print("  - Left Click: Zoom in 1.5x")
print("  - Right Click: Zoom out 1.5x")
print("  - ESC: Exit")
main()
