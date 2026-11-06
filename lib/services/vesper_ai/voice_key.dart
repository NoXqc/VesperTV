import 'package:flutter/services.dart';

/// The remote's microphone / assistant button, when Settings > Vesper AI >
/// Remote voice button is on (off by default: it otherwise opens the
/// device's own assistant).
///
/// Remotes differ: most Android TV remotes send KEYCODE_SEARCH (Flutter's
/// browserSearch), some KEYCODE_ASSIST (launchAssistant) or
/// KEYCODE_VOICE_ASSIST (231, no Flutter name). Many systems keep ASSIST /
/// VOICE_ASSIST for themselves and never pass them to an app; Fire OS keeps
/// its Alexa button. Settings can learn any other key that does arrive.
class VoiceKey {
  VoiceKey._();

  /// Android keys Flutter has no name for: 0x11 << 32 | keycode.
  static const voiceAssistKeyId = 0x11000000e7;

  /// Set by Settings while it waits for "press your remote's button": key
  /// downs go here first; true = taken (not passed on).
  static bool Function(KeyDownEvent event)? learning;

  /// Keys that only move around / go back: never learned.
  static bool isNavigation(KeyEvent event) {
    final k = event.logicalKey;
    return k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.gameButtonA ||
        k == LogicalKeyboardKey.escape ||
        k == LogicalKeyboardKey.goBack ||
        k == LogicalKeyboardKey.browserBack;
  }

  static bool isVoice(KeyEvent event, {int? learned}) {
    final id = event.logicalKey.keyId;
    return event.logicalKey == LogicalKeyboardKey.browserSearch ||
        event.logicalKey == LogicalKeyboardKey.launchAssistant ||
        id == voiceAssistKeyId ||
        (learned != null && id == learned);
  }

  /// A name for a learned key in Settings.
  static String describe(int keyId) {
    final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
    final label = key?.debugName ?? key?.keyLabel;
    if (label != null && label.isNotEmpty) return label;
    if (keyId >> 32 == 0x11) return 'Android key ${keyId & 0xffffffff}';
    return 'Key 0x${keyId.toRadixString(16)}';
  }
}
