// DiceX: the main window waits for the native splash (flutter/windows/runner/splash.cpp).
//
// Owner's request, 2026-10-01: the app must not appear behind the splash. So Dart tells the
// splash the app is ready, the splash finishes its minimum time and fades out, and only then is
// the main window shown.

import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

/// Same values as splash.cpp.
const String _kSplashClass = 'DiceXRemoteSplash';
const int _kSplashReadyMessage = 0x8000 + 1; // WM_APP + 1

/// This process's splash window, or 0 when there is none (a start with arguments shows none).
int _splashWindow() {
  final className = _kSplashClass.toNativeUtf16();
  final owner = calloc<Uint32>();
  try {
    final pid = win32.GetCurrentProcessId();
    var hwnd = 0;
    while (true) {
      hwnd = win32.FindWindowEx(0, hwnd, className, nullptr);
      if (hwnd == 0) return 0;
      win32.GetWindowThreadProcessId(hwnd, owner);
      if (owner.value == pid) return hwnd;
    }
  } finally {
    calloc.free(className);
    calloc.free(owner);
  }
}

/// Tells the splash the app is ready. With [waitUntilGone], returns once it has faded out, so the
/// main window can be shown after it. Never waits more than a few seconds.
Future<void> diceXSplashReady({bool waitUntilGone = false}) async {
  if (!Platform.isWindows) return;
  final hwnd = _splashWindow();
  if (hwnd == 0) return;
  win32.PostMessage(hwnd, _kSplashReadyMessage, 0, 0);
  if (!waitUntilGone) return;
  // The splash stays at least 2 s from its start and then fades for 0.3 s.
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (win32.IsWindow(hwnd) != 0 && DateTime.now().isBefore(deadline)) {
    await Future.delayed(const Duration(milliseconds: 40));
  }
}
