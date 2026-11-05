import '../l10n/l10n.dart';

/// Audio delay / A/V sync limits and wording, shared by Settings and the
/// player's Audio sync button. Positive = sound later (picture earlier);
/// the vendored `AudioDelay.java` clamps to the same range.
class AudioDelay {
  static const maxMs = 1000;
  static const stepMs = 25;

  /// "+150 ms · sound later", "-75 ms · sound earlier", "Off".
  static String label(int ms) {
    if (ms == 0) return tr('No delay');
    final value = '${ms > 0 ? '+' : '-'}${ms.abs()} ms';
    return ms > 0
        ? tr('{value} · sound later', {'value': value})
        : tr('{value} · sound earlier', {'value': value});
  }

  static int step(int ms, int direction) =>
      (ms + direction * stepMs).clamp(-maxMs, maxMs);
}
