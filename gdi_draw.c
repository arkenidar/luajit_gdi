#include <windows.h>
#include <math.h>
#include <stdio.h>

// Global state for Mandelbrot rendering
static double g_zoom = 1.0;
static double g_centerX = -0.5;
static double g_centerY = 0.0;
static int g_maxIter = 256;

// Mandelbrot calculation
static int mandelbrot(double cx, double cy, int max_iter)
{
    double x = 0.0, y = 0.0;
    double xx = 0.0, yy = 0.0;
    int iter = 0;

    while (iter < max_iter && xx + yy < 4.0)
    {
        y = 2.0 * x * y + cy;
        x = xx - yy + cx;
        xx = x * x;
        yy = y * y;
        iter++;
    }

    return iter;
}

// Color mapping function
static COLORREF getColor(int iter, int max_iter)
{
    if (iter == max_iter)
    {
        return RGB(0, 0, 0); // Black for points in the set
    }

    // Smooth color gradient
    double t = (double)iter / max_iter;
    int r = (int)(9 * (1 - t) * t * t * t * 255);
    int g = (int)(15 * (1 - t) * (1 - t) * t * t * 255);
    int b = (int)(8.5 * (1 - t) * (1 - t) * (1 - t) * t * 255);

    return RGB(r, g, b);
}

// Fast render using DIB (Device Independent Bitmap) - renders to memory then blits
static void renderMandelbrot(HDC hdc, int width, int height)
{
    // Create a DIB section for fast rendering
    BITMAPINFO bmi = {0};
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = width;
    bmi.bmiHeader.biHeight = -height; // Negative for top-down bitmap
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    DWORD *pixels = NULL;
    HBITMAP hBitmap = CreateDIBSection(hdc, &bmi, DIB_RGB_COLORS, (void **)&pixels, NULL, 0);
    if (!hBitmap || !pixels)
        return;

    // Calculate bounds
    double x_min = g_centerX - 2.0 / g_zoom;
    double x_max = g_centerX + 2.0 / g_zoom;
    double y_min = g_centerY - 1.5 / g_zoom;
    double y_max = g_centerY + 1.5 / g_zoom;

    // Render directly to memory (fast!)
    for (int py = 0; py < height; py++)
    {
        for (int px = 0; px < width; px++)
        {
            // Map pixel to complex plane
            double cx = x_min + (px / (double)width) * (x_max - x_min);
            double cy = y_min + (py / (double)height) * (y_max - y_min);

            // Compute iterations
            int iter = mandelbrot(cx, cy, g_maxIter);

            // Get color and write directly to bitmap memory
            pixels[py * width + px] = getColor(iter, g_maxIter);
        }
    }

    // Blit the bitmap to screen (instant!)
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP oldBitmap = SelectObject(memDC, hBitmap);
    BitBlt(hdc, 0, 0, width, height, memDC, 0, 0, SRCCOPY);
    SelectObject(memDC, oldBitmap);
    DeleteDC(memDC);
    DeleteObject(hBitmap);
}

LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);

int APIENTRY WinMain(HINSTANCE hInstance, HINSTANCE hInstPrev, PSTR cmdline, int cmdshow)
{
    MSG msg;
    WNDCLASSW wc = {0};

    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpszClassName = L"Mandelbrot";
    wc.hInstance = hInstance;
    wc.hbrBackground = NULL;
    wc.lpfnWndProc = WndProc;
    wc.hCursor = LoadCursor(0, IDC_ARROW);

    RegisterClassW(&wc);
    CreateWindowW(wc.lpszClassName, L"Mandelbrot Explorer (C version) - Wheel/Click: Zoom, ESC: Exit",
                  WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                  100, 100, 800, 600, NULL, NULL, hInstance, NULL);

    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return (int)msg.wParam;
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg,
                         WPARAM wParam, LPARAM lParam)
{

    HDC hdc;
    PAINTSTRUCT ps;
    RECT rect;

    switch (msg)
    {

    case WM_PAINT:
        hdc = BeginPaint(hwnd, &ps);

        // Get client area dimensions
        GetClientRect(hwnd, &rect);
        int width = rect.right - rect.left;
        int height = rect.bottom - rect.top;

        // Render Mandelbrot set
        printf("Rendering Mandelbrot... (zoom: %.2f, center: %.4f, %.4f)\n",
               g_zoom, g_centerX, g_centerY);
        renderMandelbrot(hdc, width, height);
        printf("Done!\n");

        EndPaint(hwnd, &ps);
        break;

    case WM_ERASEBKGND:
        return 1; // Don't erase, we'll paint everything

    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE)
        {
            PostQuitMessage(0);
            return 0;
        }
        break;

    case WM_LBUTTONDOWN:
    {
        // Left click - zoom in
        GetClientRect(hwnd, &rect);
        int width = rect.right - rect.left;
        int height = rect.bottom - rect.top;

        // Extract mouse coordinates
        int mouse_x = LOWORD(lParam);
        int mouse_y = HIWORD(lParam);

        // Get point in complex plane before zoom
        double x_min = g_centerX - 2.0 / g_zoom;
        double x_max = g_centerX + 2.0 / g_zoom;
        double y_min = g_centerY - 1.5 / g_zoom;
        double y_max = g_centerY + 1.5 / g_zoom;
        double point_x = x_min + (mouse_x / (double)width) * (x_max - x_min);
        double point_y = y_min + (mouse_y / (double)height) * (y_max - y_min);

        // Zoom in
        double zoom_factor = 1.5;
        g_zoom *= zoom_factor;

        // Adjust center so point stays under cursor
        double new_x_min = g_centerX - 2.0 / g_zoom;
        double new_x_max = g_centerX + 2.0 / g_zoom;
        double new_y_min = g_centerY - 1.5 / g_zoom;
        double new_y_max = g_centerY + 1.5 / g_zoom;
        double new_point_x = new_x_min + (mouse_x / (double)width) * (new_x_max - new_x_min);
        double new_point_y = new_y_min + (mouse_y / (double)height) * (new_y_max - new_y_min);
        g_centerX += (point_x - new_point_x);
        g_centerY += (point_y - new_point_y);

        printf("Zoom IN - new zoom: %.2f\n", g_zoom);

        // Trigger repaint
        InvalidateRect(hwnd, NULL, FALSE);
        break;
    }

    case WM_RBUTTONDOWN:
    {
        // Right click - zoom out
        GetClientRect(hwnd, &rect);
        int width = rect.right - rect.left;
        int height = rect.bottom - rect.top;

        // Extract mouse coordinates
        int mouse_x = LOWORD(lParam);
        int mouse_y = HIWORD(lParam);

        // Get point in complex plane before zoom
        double x_min = g_centerX - 2.0 / g_zoom;
        double x_max = g_centerX + 2.0 / g_zoom;
        double y_min = g_centerY - 1.5 / g_zoom;
        double y_max = g_centerY + 1.5 / g_zoom;
        double point_x = x_min + (mouse_x / (double)width) * (x_max - x_min);
        double point_y = y_min + (mouse_y / (double)height) * (y_max - y_min);

        // Zoom out
        double zoom_factor = 1.5;
        g_zoom /= zoom_factor;

        // Adjust center so point stays under cursor
        double new_x_min = g_centerX - 2.0 / g_zoom;
        double new_x_max = g_centerX + 2.0 / g_zoom;
        double new_y_min = g_centerY - 1.5 / g_zoom;
        double new_y_max = g_centerY + 1.5 / g_zoom;
        double new_point_x = new_x_min + (mouse_x / (double)width) * (new_x_max - new_x_min);
        double new_point_y = new_y_min + (mouse_y / (double)height) * (new_y_max - new_y_min);
        g_centerX += (point_x - new_point_x);
        g_centerY += (point_y - new_point_y);

        printf("Zoom OUT - new zoom: %.2f\n", g_zoom);

        // Trigger repaint
        InvalidateRect(hwnd, NULL, FALSE);
        break;
    }

    case WM_MOUSEWHEEL:
    {
        // Get wheel delta (positive = zoom in, negative = zoom out)
        int delta = GET_WHEEL_DELTA_WPARAM(wParam);

        // Get client area dimensions
        GetClientRect(hwnd, &rect);
        int width = rect.right - rect.left;
        int height = rect.bottom - rect.top;

        // Get mouse position (in screen coordinates, need to convert to client)
        POINT pt;
        pt.x = LOWORD(lParam);
        pt.y = HIWORD(lParam);
        ScreenToClient(hwnd, &pt);

        // Get point in complex plane before zoom
        double x_min = g_centerX - 2.0 / g_zoom;
        double x_max = g_centerX + 2.0 / g_zoom;
        double y_min = g_centerY - 1.5 / g_zoom;
        double y_max = g_centerY + 1.5 / g_zoom;
        double point_x = x_min + (pt.x / (double)width) * (x_max - x_min);
        double point_y = y_min + (pt.y / (double)height) * (y_max - y_min);

        // Apply zoom
        if (delta > 0)
        {
            g_zoom *= 1.15; // Zoom in
        }
        else
        {
            g_zoom /= 1.15; // Zoom out
        }

        // Adjust center so point stays under cursor
        double new_x_min = g_centerX - 2.0 / g_zoom;
        double new_x_max = g_centerX + 2.0 / g_zoom;
        double new_y_min = g_centerY - 1.5 / g_zoom;
        double new_y_max = g_centerY + 1.5 / g_zoom;
        double new_point_x = new_x_min + (pt.x / (double)width) * (new_x_max - new_x_min);
        double new_point_y = new_y_min + (pt.y / (double)height) * (new_y_max - new_y_min);
        g_centerX += (point_x - new_point_x);
        g_centerY += (point_y - new_point_y);

        printf("Wheel Zoom - new zoom: %.2f\n", g_zoom);

        // Trigger repaint
        InvalidateRect(hwnd, NULL, FALSE);
        break;
    }

    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}
