import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Swallows the rest of a held key's press (its repeats and its release)
/// before any focused widget sees them, once a hold already acted on it.
///
/// The player's arrow holds (Settings > Backup & devices > Remote) run
/// their action while the arrow is still down. Hold Left = Back to the
/// guide closed the player, and the arrow's repeats then went to the
/// guide: each one a programme further back, hours into catch-up by the
/// release, and the guide only drew once the repeats stopped (owner,
/// 2026-11-24). A drawer or a sheet opened by a hold took the repeats the
/// same way.
///
/// An early focus handler, not a HardwareKeyboard one: a HardwareKeyboard
/// handler can't keep a key from the focused widget (CLAUDE.md §10).
/// HardwareKeyboard handlers still see the release (the player's own
/// hold watcher ends the hold on it).
class HeldKeySwallow {
  HeldKeySwallow._();

  static final _held = <LogicalKeyboardKey>{};
  static bool _registered = false;
  static Timer? _safety;

  /// Starts swallowing [key] until its release; nothing if it isn't held.
  static void restOfPress(LogicalKeyboardKey key) {
    if (!HardwareKeyboard.instance.logicalKeysPressed.contains(key)) return;
    _held.add(key);
    if (!_registered) {
      FocusManager.instance.addEarlyKeyEventHandler(_handle);
      _registered = true;
    }
    // A release can be lost (focus or window change): never keep
    // swallowing an arrow for good.
    _safety?.cancel();
    _safety = Timer(const Duration(seconds: 5), _stop);
  }

  static KeyEventResult _handle(KeyEvent event) {
    if (!_held.contains(event.logicalKey)) return KeyEventResult.ignored;
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    _held.remove(event.logicalKey);
    if (_held.isEmpty) _stop();
    // The release ends the press; a new key-down is a new press.
    return event is KeyUpEvent
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  static void _stop() {
    _held.clear();
    _safety?.cancel();
    _safety = null;
    if (_registered) {
      FocusManager.instance.removeEarlyKeyEventHandler(_handle);
      _registered = false;
    }
  }

  /// Tests: whether a press is being swallowed.
  static bool get active => _registered;
}
