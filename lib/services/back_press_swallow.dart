import 'dart:async';

import 'package:flutter/services.dart';

/// Swallows the rest of a Back press (its key repeats and its release)
/// after a screen already acted on its key-down.
///
/// Home closes on Back's key-down, and focus moves to the TV home beneath
/// it. When the press lasted past the remote's repeat delay, the repeats
/// and the release reached Android unhandled: Android starts tracking Back
/// on a repeat and turns the release into a second, system Back. That
/// arrived after the TV home's 700 ms return guard, so it walked on to
/// Who's watching (or left the app). Owner, 2026-11-10: "sometimes hitting
/// Back from Home brings us to Who's watching, like it gets registered
/// twice". Marking the rest of the press handled keeps Android out of it.
class BackPressSwallow {
  BackPressSwallow._();

  static final backKeys = {
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.browserBack,
  };

  static final _held = <LogicalKeyboardKey>{};
  static bool _registered = false;
  static Timer? _safety;

  /// Starts swallowing every Back key held right now, until its release.
  /// Nothing held (a touch or system Back) = nothing to do.
  static void restOfPress() {
    final keyboard = HardwareKeyboard.instance;
    final held = keyboard.logicalKeysPressed.where(backKeys.contains);
    if (held.isEmpty) return;
    _held.addAll(held);
    if (!_registered) {
      keyboard.addHandler(_handle);
      _registered = true;
    }
    // A release can be lost (focus or window change): never keep
    // swallowing Back for good.
    _safety?.cancel();
    _safety = Timer(const Duration(seconds: 5), _stop);
  }

  static bool _handle(KeyEvent event) {
    if (!_held.contains(event.logicalKey)) return false;
    if (event is KeyRepeatEvent) return true;
    _held.remove(event.logicalKey);
    if (_held.isEmpty) _stop();
    // The release ends the press; a new key-down is a new press.
    return event is KeyUpEvent;
  }

  static void _stop() {
    _held.clear();
    _safety?.cancel();
    _safety = null;
    if (_registered) {
      HardwareKeyboard.instance.removeHandler(_handle);
      _registered = false;
    }
  }

  /// Tests: whether a press is being swallowed.
  static bool get active => _registered;
}
