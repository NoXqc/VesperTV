// KeyMessage / keyEventManager.keyMessageHandler are deprecated, but in
// Flutter 3.47 (this PC 3.47.5, flutter-tvos 3.47.9) they are still the only
// way into the focus tree's own dispatch (early handlers, focused node and
// ancestors, late handlers). If a Flutter update removes them, send the
// repeat to FocusManager.instance.primaryFocus and its ancestors' onKeyEvent.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../widgets/hold_to_activate.dart' show isActivateKey;

/// Apple TV: a held OK repeats, as on an Android remote.
///
/// Every "hold OK" in the app (game stats, game menus, guide menus,
/// Multiview enlarge, options-row moves...) waits for the remote's own key
/// repeats ([HoldToActivate], the Sports Mode feed, the player side panel):
/// a busy Fire Stick could deliver a quick click's key-up late, and only a
/// real hold sends repeats. The Siri Remote's click sends none: flutter-tvos
/// auto-repeats held arrows only (its native `keyRepeatInitialDelay` is "on a
/// held arrow/page button"), so on Apple TV no hold ever opened (Mycue66,
/// Discord 2026-11-21: Sports Mode's hold OK for stats did nothing).
///
/// While an activate key ([isActivateKey]) is down, this sends Flutter the
/// repeats Android would: the first after [initialDelay], then one every
/// [interval], through [HardwareKeyboard] and the focus tree like a real key
/// event, until the key-up. A press the platform repeats itself (a real
/// [KeyRepeatEvent]) is left alone. A tick that comes late (the app was
/// busy) sends nothing, so a queued key-up gets in first and a quick click
/// never turns into a hold.
class HeldOkRepeat {
  HeldOkRepeat({
    HardwareKeyboard? keyboard,
    bool Function(KeyMessage message)? dispatch,
    this.initialDelay = const Duration(milliseconds: 500),
    this.interval = const Duration(milliseconds: 50),
  })  : _keyboard = keyboard ?? HardwareKeyboard.instance,
        _dispatch = dispatch ?? _toFocusTree;

  /// Android's long-press timeout: its first repeat comes about this late.
  final Duration initialDelay;

  /// Android's key repeat rate is about 20 a second.
  final Duration interval;

  final HardwareKeyboard _keyboard;
  final bool Function(KeyMessage message) _dispatch;

  static HeldOkRepeat? _installed;

  /// Starts it for the app (Apple TV only: main.dart).
  static void install() {
    _installed ??= HeldOkRepeat()..attach();
  }

  KeyDownEvent? _held;
  Timer? _timer;
  int _lastTick = 0;
  bool _sending = false;

  void attach() => _keyboard.addHandler(_onKey);

  void detach() {
    _stop();
    _keyboard.removeHandler(_onKey);
  }

  /// The same path the engine's key events take after [HardwareKeyboard]:
  /// early handlers, then the focused node and its ancestors.
  static bool _toFocusTree(KeyMessage message) =>
      ServicesBinding.instance.keyEventManager.keyMessageHandler
          ?.call(message) ??
      false;

  bool _onKey(KeyEvent event) {
    if (_sending) return false; // one of ours
    final held = _held;
    if (event is KeyDownEvent) {
      // Another key down ends the repeats, as on Android.
      _stop();
      if (isActivateKey(event.logicalKey)) _start(event);
    } else if (held != null && event.physicalKey == held.physicalKey) {
      // Key-up, or the platform repeats this key itself.
      _stop();
    }
    return false;
  }

  void _start(KeyDownEvent event) {
    _held = event;
    _lastTick = 0;
    _timer = Timer.periodic(interval, _onTick);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _held = null;
  }

  void _onTick(Timer timer) {
    final held = _held;
    final onTime = timer.tick == _lastTick + 1;
    _lastTick = timer.tick;
    if (held == null || !onTime || interval * timer.tick < initialDelay) {
      return;
    }
    // Key-up missed (focus left the app, a dialog took the keyboard...).
    if (_keyboard.lookUpLayout(held.physicalKey) != held.logicalKey) {
      _stop();
      return;
    }
    final repeat = KeyRepeatEvent(
      physicalKey: held.physicalKey,
      logicalKey: held.logicalKey,
      timeStamp: held.timeStamp + interval * timer.tick,
    );
    _sending = true;
    try {
      _keyboard.handleKeyEvent(repeat);
      _dispatch(KeyMessage(<KeyEvent>[repeat], null));
    } finally {
      _sending = false;
    }
  }

  @visibleForTesting
  bool get repeating => _timer != null;
}
