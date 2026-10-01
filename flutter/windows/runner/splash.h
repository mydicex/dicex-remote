// DiceX: native splash for DiceX Remote.
//
// Shown from early in process start until the Flutter main window becomes visible, so people
// see the product immediately instead of nothing while the engine and Dart start up. It is a
// layered window drawn from a premultiplied 32-bit bitmap (resources/splash_*.bmp, made by
// brand/tools/make-splash.ps1), so it needs no painting code and stays on screen even while
// the main thread is busy starting Flutter.
#ifndef RUNNER_SPLASH_H_
#define RUNNER_SPLASH_H_

#include <windows.h>

namespace dicex_splash {

// Shows the splash centred on the primary monitor's work area. Returns immediately.
// Does nothing if the bitmap cannot be loaded.
void Show(HINSTANCE instance);

// The splash fades out once it has been up for at least two seconds and the app is ready: Dart
// posts WM_APP + 1 to it (lib/dicex/splash_win.dart) and shows the main window only after the
// splash is gone. |main_window| becoming visible counts as ready too. A timeout closes it
// regardless, so it can never outlive a start-up that keeps the main window hidden.
void CloseWhenVisible(HWND main_window);

}  // namespace dicex_splash

#endif  // RUNNER_SPLASH_H_
