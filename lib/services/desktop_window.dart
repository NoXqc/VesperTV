import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/constants.dart';

/// Windows only: full screen (the default, TV-style, no title bar) or a
/// normal resizable window with the system title bar — so it snaps to half
/// a screen (drag to an edge, Win+Left/Right) and resizes from its edges
/// (users asked, 2026-10-18). The choice and the window's last bounds are
/// remembered (this PC only — both keys skip Transfer).
class DesktopWindow {
  DesktopWindow._();

  /// True = windowed. Set by [init], changed by [setWindowed].
  static final windowed = ValueNotifier<bool>(false);

  static SharedPreferences? _prefs;
  static Timer? _saveTimer;

  static const _defaultSize = Size(1280, 720);
  static const _minimumSize = Size(640, 400);

  /// Before the first frame: the window is created in the saved mode, so a
  /// full-screen start has no windowed flash (see main.dart).
  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    windowed.value = prefs.getBool(AppConstants.keyWindowsWindowed) ?? false;
    await windowManager.ensureInitialized();
    final bounds = _savedBounds();
    final options = windowed.value
        ? WindowOptions(
            fullScreen: false,
            titleBarStyle: TitleBarStyle.normal,
            minimumSize: _minimumSize,
            size: bounds?.size ?? _defaultSize,
            center: bounds == null,
          )
        : const WindowOptions(
            fullScreen: true,
            titleBarStyle: TitleBarStyle.hidden,
          );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (windowed.value && bounds != null) {
        await windowManager.setBounds(bounds);
      }
      await windowManager.show();
      await windowManager.focus();
    });
    unawaited(Future<void>.delayed(
        const Duration(seconds: 3), () => logState('started')));
  }

  /// Send log: how big the window really is against the screen (a user on a
  /// 1440p monitor showed the app drawn in only part of it, 2026-10-24).
  static Future<void> logState(String why) async {
    if (!Platform.isWindows) return;
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final b = await windowManager.getBounds();
      final full = await windowManager.isFullScreen();
      final d = view.display;
      debugPrint('DesktopWindow: $why windowed=${windowed.value} '
          'fullScreen=$full window ${b.width.toInt()}x${b.height.toInt()} '
          'at ${b.left.toInt()},${b.top.toInt()}; Flutter view '
          '${view.physicalSize.width.toInt()}x'
          '${view.physicalSize.height.toInt()} px, scale '
          '${view.devicePixelRatio}; screen '
          '${d.size.width.toInt()}x${d.size.height.toInt()} px');
    } catch (e) {
      debugPrint('DesktopWindow: state failed: $e');
    }
  }

  static Timer? _logTimer;

  /// Logs the size after the window settles (resize / full screen changes).
  static void logStateSoon(String why) {
    _logTimer?.cancel();
    _logTimer = Timer(const Duration(milliseconds: 900), () => logState(why));
  }

  static Future<void> setWindowed(bool value) async {
    if (!Platform.isWindows) return;
    windowed.value = value;
    logStateSoon(value ? 'switched to windowed' : 'switched to full screen');
    await _prefs?.setBool(AppConstants.keyWindowsWindowed, value);
    if (value) {
      await windowManager.setFullScreen(false);
      // window_manager restores the window style it saved on entering full
      // screen. Started full screen, that was saved before the window was
      // first shown, so it lacks WS_VISIBLE: leaving full screen hid the
      // window (a frozen ghost of the last frame, a window-less process —
      // owner's PC, 2026-10-18, style 0x04CF0000). Show it again.
      await windowManager.show();
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(_minimumSize);
      final bounds = _savedBounds();
      if (bounds != null) {
        await windowManager.setBounds(bounds);
      } else {
        await windowManager.setSize(_defaultSize);
        await windowManager.center();
      }
      await windowManager.focus();
    } else {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setFullScreen(true);
    }
  }

  /// Back from the taskbar after Minimize: full screen again, unless the
  /// user chose a window.
  static void onRestore() {
    if (!windowed.value) windowManager.setFullScreen(true);
  }

  /// Moved or resized while windowed: remember where (debounced).
  static void onBoundsChanged() {
    logStateSoon('resized/moved');
    if (!windowed.value) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!windowed.value || await windowManager.isFullScreen()) return;
      if (await windowManager.isMinimized() ||
          await windowManager.isMaximized()) {
        return;
      }
      final b = await windowManager.getBounds();
      await _prefs?.setString(AppConstants.keyWindowsBounds,
          '${b.left},${b.top},${b.width},${b.height}');
    });
  }

  static Rect? _savedBounds() {
    final parts = _prefs?.getString(AppConstants.keyWindowsBounds)?.split(',');
    if (parts == null || parts.length != 4) return null;
    final v = parts.map(double.tryParse).toList();
    if (v.any((x) => x == null)) return null;
    if (v[2]! < _minimumSize.width || v[3]! < _minimumSize.height) return null;
    return Rect.fromLTWH(v[0]!, v[1]!, v[2]!, v[3]!);
  }
}
