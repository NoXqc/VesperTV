import '../l10n/l10n.dart';

/// Audio delay / A/V sync limits and wording, shared by Settings and the
/// player's Audio sync button. Positive = sound later (picture earlier);
/// the vendored `AudioDelay.java` clamps to the same range.
class AudioDelay {
  /// ±5 s: some providers' sports feeds are seconds out of sync (Shield
  /// user, tennis channel, same in TiviMate; 2026-11-05).
  static const maxMs = 5000;
  static const stepMs = 25;

  /// Holding Left/Right speeds up: 25 ms steps, then 100, then 250 ms, so
  /// seconds of delay take one hold instead of hundreds of presses.
  static int stepFor(int repeats) => repeats < 8
      ? stepMs
      : repeats < 20
          ? 100
          : 250;

  /// "+150 ms · sound later", "-75 ms · sound earlier", "Off".
  static String label(int ms) {
    if (ms == 0) return tr('No delay');
    final value = '${ms > 0 ? '+' : '-'}${ms.abs()} ms';
    return ms > 0
        ? tr('{value} · sound later', {'value': value})
        : tr('{value} · sound earlier', {'value': value});
  }

  static int step(int ms, int direction, {int by = stepMs}) =>
      (ms + direction * by).clamp(-maxMs, maxMs);
}
