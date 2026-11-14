import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A computer keyboard's Esc or Backspace = the remote's Back (a Windows
/// viewer with a K400 keyboard, 2026-11-14: Esc did nothing in full screen,
/// only a click on the top back arrow left it).
///
/// A late key handler: it only runs when no focused widget took the key, so
/// a screen's own Esc (side panel, source drawer, Multiview, Sports) and a
/// text field's Backspace keep working. It asks the root navigator to
/// `maybePop`, exactly like Android's Back, so every screen's `PopScope`
/// (TV home walking its columns, the player handing a live channel to the
/// mini player) decides what Back means there.
class DesktopBackKey {
  DesktopBackKey._();

  static GlobalKey<NavigatorState>? _navigator;

  /// Once, at startup, on Windows / macOS / Linux only.
  static void install(GlobalKey<NavigatorState> navigator) {
    if (_navigator != null) return;
    _navigator = navigator;
    FocusManager.instance.addLateKeyEventHandler(handle);
  }

  /// Test hook: the late handler itself.
  @visibleForTesting
  static KeyEventResult handle(KeyEvent event) {
    final key = event.logicalKey;
    final backspace = key == LogicalKeyboardKey.backspace;
    if (key != LogicalKeyboardKey.escape && !backspace) {
      return KeyEventResult.ignored;
    }
    // A read-only field (or one whose Backspace did nothing) still means
    // editing text to the viewer: never leave the page from there.
    if (backspace && _inTextField()) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      final nav = _navigator?.currentState;
      if (nav != null) unawaited(nav.maybePop());
    }
    return KeyEventResult.handled;
  }

  static bool _inTextField() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @visibleForTesting
  static void reset() {
    if (_navigator == null) return;
    FocusManager.instance.removeLateKeyEventHandler(handle);
    _navigator = null;
  }
}
