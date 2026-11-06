import 'dart:async';

/// The first seconds after the splash belong to the remote.
///
/// Dart shares Android's main thread, so every background job that runs
/// right after the UI appears (catalog pre-load, update check, cloud sync,
/// recordings, TMDB refresh...) delays key presses by exactly as long as it
/// holds the isolate. The owner timed 10-15 s of a laggy, skipping remote
/// after a 3 s splash (2026-11-05); TiviMate is responsive at once because
/// it starts nothing but the player. Anything that can wait awaits [ready]
/// and starts staggered after it. The user's own actions (opening Movies,
/// Search...) never wait: they call the loaders directly.
class StartupQuiet {
  StartupQuiet._();

  /// How long the remote gets the main thread to itself after the UI shows.
  static const quietFor = Duration(seconds: 12);

  static final _done = Completer<void>();
  static Timer? _timer;

  /// Completes [quietFor] after [uiShown], or at once on [end].
  static Future<void> get ready => _done.future;

  static bool get isOver => _done.isCompleted;

  /// The real UI is on screen (the splash is gone).
  static void uiShown() {
    if (_done.isCompleted || _timer != null) return;
    _timer = Timer(quietFor, end);
  }

  static void end() {
    _timer?.cancel();
    _timer = null;
    if (!_done.isCompleted) _done.complete();
  }

  /// [ready], then [extra] more: deferred jobs start one after another
  /// instead of all together on the first idle tick.
  static Future<void> after(Duration extra) =>
      ready.then((_) => Future<void>.delayed(extra));
}
