// DiceX: native splash for DiceX Remote. See splash.h.
#include "splash.h"

#include "resource.h"

namespace dicex_splash {
namespace {

constexpr wchar_t kClassName[] = L"DiceXRemoteSplash";
constexpr UINT_PTR kWatchTimerId = 1;
constexpr UINT kWatchIntervalMs = 100;
constexpr UINT_PTR kFadeTimerId = 2;
constexpr UINT kFadeIntervalMs = 16;
constexpr ULONGLONG kFadeMs = 300;
// The splash stays at least this long even when the app is ready sooner (owner's request).
constexpr ULONGLONG kMinVisibleMs = 2000;
// Long enough for a slow first start, short enough that a splash can never linger.
constexpr ULONGLONG kMaxLifetimeMs = 20000;
// Posted by Dart (lib/dicex/splash_win.dart) when the app is ready to show; Dart then waits for
// the splash to go before it shows the main window, so the app never appears behind it.
constexpr UINT kReadyMessage = WM_APP + 1;

HWND g_splash = nullptr;
HWND g_main_window = nullptr;
ULONGLONG g_shown_at = 0;
ULONGLONG g_fade_started_at = 0;
bool g_app_ready = false;

void SetAlpha(HWND hwnd, BYTE alpha) {
  // With no source DC, UpdateLayeredWindow only changes the constant alpha.
  BLENDFUNCTION blend = {AC_SRC_OVER, 0, alpha, AC_SRC_ALPHA};
  ::UpdateLayeredWindow(hwnd, nullptr, nullptr, nullptr, nullptr, nullptr, 0, &blend,
                        ULW_ALPHA);
}

LRESULT CALLBACK SplashProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case kReadyMessage:
      g_app_ready = true;
      return 0;
    case WM_TIMER:
      if (wparam == kWatchTimerId) {
        const ULONGLONG elapsed = ::GetTickCount64() - g_shown_at;
        // A main window that shows without saying it is ready (an older Dart side) still ends it.
        const bool main_visible = g_main_window && ::IsWindowVisible(g_main_window);
        if (((g_app_ready || main_visible) && elapsed >= kMinVisibleMs) ||
            elapsed > kMaxLifetimeMs) {
          ::KillTimer(hwnd, kWatchTimerId);
          g_fade_started_at = ::GetTickCount64();
          ::SetTimer(hwnd, kFadeTimerId, kFadeIntervalMs, nullptr);
        }
      } else if (wparam == kFadeTimerId) {
        const ULONGLONG fading = ::GetTickCount64() - g_fade_started_at;
        if (fading >= kFadeMs) {
          ::KillTimer(hwnd, kFadeTimerId);
          ::DestroyWindow(hwnd);
        } else {
          SetAlpha(hwnd, static_cast<BYTE>(255 - (255 * fading) / kFadeMs));
        }
      }
      return 0;
    case WM_DESTROY:
      if (hwnd == g_splash) {
        g_splash = nullptr;
      }
      return 0;
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}

}  // namespace

void Show(HINSTANCE instance) {
  if (g_splash) {
    return;
  }
  // Pick the bitmap closest to the system DPI. GetDeviceCaps works on every Windows version
  // the runner supports; GetDpiForSystem would not load on Windows 7.
  int dpi = 96;
  if (HDC screen = ::GetDC(nullptr)) {
    dpi = ::GetDeviceCaps(screen, LOGPIXELSX);
    ::ReleaseDC(nullptr, screen);
  }
  const int resource_id = dpi >= 132 ? IDB_SPLASH_2X : IDB_SPLASH_1X;
  HBITMAP bitmap = static_cast<HBITMAP>(::LoadImageW(
      instance, MAKEINTRESOURCEW(resource_id), IMAGE_BITMAP, 0, 0, LR_CREATEDIBSECTION));
  if (!bitmap) {
    return;
  }
  BITMAP info = {};
  ::GetObjectW(bitmap, sizeof(info), &info);
  const SIZE size = {info.bmWidth, info.bmHeight};

  WNDCLASSEXW window_class = {};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = SplashProc;
  window_class.hInstance = instance;
  window_class.hCursor = ::LoadCursorW(nullptr, IDC_APPSTARTING);
  window_class.lpszClassName = kClassName;
  ::RegisterClassExW(&window_class);  // Fails harmlessly if already registered.

  RECT work_area = {0, 0, ::GetSystemMetrics(SM_CXSCREEN), ::GetSystemMetrics(SM_CYSCREEN)};
  ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);
  POINT position = {work_area.left + (work_area.right - work_area.left - size.cx) / 2,
                    work_area.top + (work_area.bottom - work_area.top - size.cy) / 2};

  // WS_EX_TOOLWINDOW keeps it off the taskbar and Alt+Tab.
  g_splash = ::CreateWindowExW(WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_TOPMOST, kClassName,
                               L"DiceX Remote", WS_POPUP, position.x, position.y, size.cx,
                               size.cy, nullptr, nullptr, instance, nullptr);
  if (!g_splash) {
    ::DeleteObject(bitmap);
    return;
  }

  HDC screen = ::GetDC(nullptr);
  HDC memory = ::CreateCompatibleDC(screen);
  HGDIOBJ previous = ::SelectObject(memory, bitmap);
  POINT source = {0, 0};
  BLENDFUNCTION blend = {AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
  ::UpdateLayeredWindow(g_splash, screen, &position, const_cast<SIZE*>(&size), memory, &source,
                        0, &blend, ULW_ALPHA);
  ::SelectObject(memory, previous);
  ::DeleteDC(memory);
  ::ReleaseDC(nullptr, screen);
  ::DeleteObject(bitmap);  // The layered window keeps its own copy of the pixels.

  ::ShowWindow(g_splash, SW_SHOWNOACTIVATE);
  g_shown_at = ::GetTickCount64();
  ::SetTimer(g_splash, kWatchTimerId, kWatchIntervalMs, nullptr);
}

void CloseWhenVisible(HWND main_window) {
  g_main_window = main_window;
}

}  // namespace dicex_splash
