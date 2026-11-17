/// How far one remote press moves a movie's seek target (the player's seek
/// bar and the Fast-forward / Rewind keys).
///
/// A tap is always 10 s. A held key grows the step with how long it has been
/// held (10 s, then 30 s, 1, 2, 5 min) and moves at most 5 times a second.
/// The steps used to grow with the number of presses: the remote's key repeat
/// (up to 20 a second) raced the target hours ahead in a few seconds, and
/// taps in a row grew too (owner, 2026-11-17: the seek line jumped minutes).
class ScrubSteps {
  ScrubSteps({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  DateTime? _holdStart;
  DateTime? _lastStep;
  DateTime? _lastPress;

  /// A held key moves at most this often.
  static const minGap = Duration(milliseconds: 200);

  /// Presses closer than this count as one held key when the caller can't
  /// tell a repeat from a new press (a shortcut callback).
  static const repeatGap = Duration(milliseconds: 350);

  /// The step for one press, or null for a key repeat that comes too soon
  /// after the last step. [repeat] null = guessed from the time since the
  /// last press.
  Duration? next({bool? repeat}) {
    final now = _clock();
    final last = _lastPress;
    _lastPress = now;
    final held = repeat ?? (last != null && now.difference(last) < repeatGap);
    if (!held || _holdStart == null) {
      _holdStart = now;
      _lastStep = now;
      return const Duration(seconds: 10);
    }
    if (now.difference(_lastStep!) < minGap) return null;
    _lastStep = now;
    final ms = now.difference(_holdStart!).inMilliseconds;
    return Duration(
        seconds: ms < 1500
            ? 10
            : ms < 3000
                ? 30
                : ms < 4500
                    ? 60
                    : ms < 6500
                        ? 120
                        : 300);
  }

  /// The seek landed (or the scrub ended): the next press is a fresh tap.
  void reset() {
    _holdStart = null;
    _lastStep = null;
    _lastPress = null;
  }
}
