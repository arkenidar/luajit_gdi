local ffi = require("ffi")

ffi.cdef [[
    typedef struct HWND__* HWND;
    typedef struct HDC__* HDC;
    typedef struct HINSTANCE__* HINSTANCE;
    typedef struct HICON__* HICON;
    typedef struct HBRUSH__* HBRUSH;
    typedef struct HMENU__* HMENU;
    typedef void* LPVOID;
    typedef const char* LPCSTR;
    typedef const wchar_t* LPCWSTR;
    typedef char* LPSTR;
    typedef unsigned int UINT;
    typedef long LONG;
    typedef unsigned long DWORD;
    typedef long long LONG_PTR;
    typedef unsigned long long UINT_PTR;
    typedef UINT_PTR WPARAM;
    typedef LONG_PTR LPARAM;
    typedef LONG_PTR LRESULT;
    typedef int BOOL;

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

    // Constants
    static const int CS_HREDRAW = 0x0002;
    static const int CS_VREDRAW = 0x0001;
    static const int WS_OVERLAPPEDWINDOW = 0x00CF0000;
    static const int WS_VISIBLE = 0x10000000;
    static const int COLOR_3DFACE = 15;
    static const int WM_PAINT = 0x000F;
    static const int WM_DESTROY = 0x0002;
    static const int IDC_ARROW = 32512;

    // Function declarations
    HBRUSH GetSysColorBrush(int nIndex);
    HICON LoadCursorA(HINSTANCE hInstance, LPCSTR lpCursorName);
    BOOL RegisterClassW(const WNDCLASSW* lpWndClass);
    HWND CreateWindowExW(
        DWORD dwExStyle,
        LPCWSTR lpClassName,
        LPCWSTR lpWindowName,
        DWORD dwStyle,
        int X,
        int Y,
        int nWidth,
        int nHeight,
        HWND hWndParent,
        HMENU hMenu,
        HINSTANCE hInstance,
        LPVOID lpParam
    );
    BOOL GetMessageW(MSG* lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax);
    BOOL TranslateMessage(const MSG* lpMsg);
    LRESULT DispatchMessageW(const MSG* lpMsg);
    LRESULT DefWindowProcW(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
    HDC BeginPaint(HWND hWnd, PAINTSTRUCT* lpPaint);
    BOOL EndPaint(HWND hWnd, const PAINTSTRUCT* lpPaint);
    BOOL Rectangle(HDC hdc, int left, int top, int right, int bottom);
    void PostQuitMessage(int nExitCode);
    HINSTANCE GetModuleHandleW(LPCWSTR lpModuleName);
]]

local C = ffi.C
local user32 = ffi.load("user32")
local gdi32 = ffi.load("gdi32")

-- Window procedure callback (must be defined as a callback)
local WndProc = ffi.cast("LONG_PTR (*)(HWND, UINT, WPARAM, LPARAM)", function(hwnd, msg, wParam, lParam)
    if msg == 0x000F then -- WM_PAINT
        local ps = ffi.new("PAINTSTRUCT")
        local hdc = C.BeginPaint(hwnd, ps)

        -- Draw rectangles
        -- left, top, right, bottom
        -- width=(right-left); height=(bottom-top);
        C.Rectangle(hdc, 10 + 50, 10, 50 + (10 + 50), 150 + (10))
        C.Rectangle(hdc, 10, 10 + 50, 150 + (10), 50 + (10 + 50))

        C.EndPaint(hwnd, ps)
        return 0
    elseif msg == 0x0002 then -- WM_DESTROY
        C.PostQuitMessage(0)
        return 0
    end

    return C.DefWindowProcW(hwnd, msg, wParam, lParam)
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

    -- Create and initialize WNDCLASSW structure
    local wc = ffi.new("WNDCLASSW")
    wc.style = 0x0002 + 0x0001 -- CS_HREDRAW | CS_VREDRAW
    wc.lpszClassName = ffi.cast("LPCWSTR", to_wchar("Rectangle"))
    wc.hInstance = hInstance
    wc.hbrBackground = C.GetSysColorBrush(15)                  -- COLOR_3DFACE
    wc.lpfnWndProc = ffi.cast("LONG_PTR", WndProc)
    wc.hCursor = C.LoadCursorA(nil, ffi.cast("LPCSTR", 32512)) -- IDC_ARROW

    C.RegisterClassW(wc)

    local title = to_wchar("Rectangles")

    C.CreateWindowExW(
        0,
        wc.lpszClassName,
        ffi.cast("LPCWSTR", title),
        0x00CF0000 + 0x10000000, -- WS_OVERLAPPEDWINDOW | WS_VISIBLE
        100, 100, 300, 300,
        nil, nil, hInstance, nil
    )

    -- Message loop
    local msg = ffi.new("MSG")
    while C.GetMessageW(msg, nil, 0, 0) ~= 0 do
        C.TranslateMessage(msg)
        C.DispatchMessageW(msg)
    end

    return msg.wParam
end

-- Run the program
main()
