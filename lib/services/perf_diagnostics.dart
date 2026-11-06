import 'dart:async';
import 'dart:io' show ProcessInfo;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Send-log diagnostics for very large playlists (a 300k-channel user's
/// phone and Onn box froze for 1-6 s per press, LOG-ARF5AW / LOG-A2BGZA,
/// 2026-11-03). Logs only when something is slow:
/// - `MainStall:` every 10 s while the UI thread stalled (a 200 ms timer
///   firing late), with PlaylistManager notifies and TV home rebuilds in
///   that window and how long a `SELECT 1` waited on each database;
/// - `SlowDb:` a timed catalog / guide query over 500 ms ([timed]);
/// - `CatalogSize:` once, live channels and categories per playlist and
///   the catalog rows the database holds.
///
/// Launch (owner, 2026-11-05: the remote lags and skips for 10-15 s after
/// the splash; TiviMate answers at once):
/// - `StartupTiming:` once, ~30 s after launch: every [mark] with its
///   time since the process started (`splashEnd=+3512ms`);
/// - `StartupStall:` during the first 30 s, every stall of 250 ms or more
///   with the jobs running at that moment ([task]) and the longest frame
///   build in that window: what held the main thread;
/// - `StartupFrames:` with the timing line: frames drawn in the first 30 s,
///   how many took 50 ms or more to raster, and the worst one.
class PerfDiagnostics {
  PerfDiagnostics._();

  static int notifies = 0;
  static int homeBuilds = 0;

  static Timer? _tick;
  static final Stopwatch _clock = Stopwatch();
  static int _lastTickMs = 0;
  static int _stalls = 0;
  static int _maxStallMs = 0;
  static int _stallTotalMs = 0;
  static bool _lifecycleChanged = false;

  static const _tickMs = 200;
  static const _stallMs = 700;

  /// Starts the probes. [pings]: label -> a trivial query on that
  /// database (its wait = how long the database queue is).
  static void start(Map<String, Future<void> Function()> pings) {
    if (_tick != null) return;
    _clock.start();
    _lastTickMs = _clock.elapsedMilliseconds;
    // Time in the background is not a stall: the first tick after coming
    // back counted the whole pause (a 5.7 s "stall" on resume, LOG-MP44ZB).
    AppLifecycleListener(onStateChange: (_) => _lifecycleChanged = true);
    // Whether a long stall is one frame's widget build/layout or work
    // between frames (async callbacks, timers).
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        final build = t.buildDuration.inMilliseconds;
        final raster = t.rasterDuration.inMilliseconds;
        if (build > _startupMaxBuildMs) _startupMaxBuildMs = build;
        if (build > _windowMaxBuildMs) _windowMaxBuildMs = build;
        if (_startupReport != null) {
          // Raster time never delays the Dart timer above, so a skipping
          // picture (shader compiles, blur on a weak GPU) shows only here.
          _startupFrames++;
          if (raster >= 50) _startupSlowRaster++;
          if (raster > _startupMaxRasterMs) _startupMaxRasterMs = raster;
        }
        if (build >= 500 || raster >= 500) {
          debugPrint('SlowFrame: build=${build}ms raster=${raster}ms');
        }
      }
    });
    _tick = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      final now = _clock.elapsedMilliseconds;
      final late = now - _lastTickMs - _tickMs;
      _lastTickMs = now;
      final state = WidgetsBinding.instance.lifecycleState;
      final away = _lifecycleChanged ||
          (state != null && state != AppLifecycleState.resumed);
      _lifecycleChanged = false;
      if (late >= _stallMs && !away) {
        _stalls++;
        _stallTotalMs += late;
        if (late > _maxStallMs) _maxStallMs = late;
      }
      _startupStallCheck(late, away);
    });
    Timer.periodic(const Duration(seconds: 10), (_) async {
      final stalls = _stalls, max = _maxStallMs, total = _stallTotalMs;
      final n = notifies, builds = homeBuilds, maxBuild = _windowMaxBuildMs;
      final jobs = {..._active, ..._windowJobs};
      _stalls = _maxStallMs = _stallTotalMs = notifies = homeBuilds = 0;
      _windowMaxBuildMs = 0;
      _windowJobs.clear();
      final waits = <String>[];
      for (final e in pings.entries) {
        final sw = Stopwatch()..start();
        try {
          await e.value().timeout(const Duration(seconds: 30));
          waits.add('${e.key}=${sw.elapsedMilliseconds}ms');
        } catch (_) {
          waits.add('${e.key}=>30s');
        }
      }
      final dbSlow = waits.any((w) {
        final ms = int.tryParse(w.split('=').last.replaceAll('ms', ''));
        return ms == null || ms >= 1000;
      });
      if (stalls == 0 && !dbSlow) return;
      // maxBuild: a stall that is one frame's build vs work between frames;
      // jobs: [task]s running in the window; rss: memory (a big GC on a
      // full heap also freezes the remote, LOG-3B5RGF had 0.8-1.8 s stalls
      // with nothing else counted).
      debugPrint('MainStall: n=$stalls max=${max}ms total=${total}ms '
          'notifies=$n homeBuilds=$builds maxBuild=${maxBuild}ms '
          'jobs=[${jobs.join(', ')}] rss=${ProcessInfo.currentRss >> 20}MB '
          'dbWait ${waits.join(' ')}');
    });
  }

  // --- Launch timeline ------------------------------------------------------

  static final Stopwatch _launch = Stopwatch();
  static final List<String> _marks = [];
  static final Set<String> _marked = {};
  static final List<String> _active = [];
  static int _startupMaxBuildMs = 0;
  static int _windowMaxBuildMs = 0;

  /// [task]s that ran in the current `MainStall:` window.
  static final Set<String> _windowJobs = {};
  static int _startupStallLines = 0;
  static int _startupFrames = 0;
  static int _startupSlowRaster = 0;
  static int _startupMaxRasterMs = 0;
  static Timer? _startupReport;

  /// Watched window after launch for `StartupStall:` lines.
  static const _startupWindow = Duration(seconds: 30);
  static const _startupStallMs = 250;
  static const _maxStartupStallLines = 40;

  /// Call first thing in `main()`.
  static void markLaunch() {
    if (_launch.isRunning) return;
    _launch.start();
    _startupReport = Timer(_startupWindow, () {
      debugPrint('StartupTiming: ${_marks.join(' ')}');
      debugPrint('StartupFrames: n=$_startupFrames '
          'raster>=50ms=$_startupSlowRaster maxRaster=${_startupMaxRasterMs}ms');
      _startupReport = null;
    });
  }

  /// Milliseconds since [markLaunch].
  static int get sinceLaunchMs => _launch.elapsedMilliseconds;

  /// Records when [label] happened (first call wins; `videoInit` is marked
  /// on every channel start, only the launch one matters).
  static void mark(String label) {
    if (!_launch.isRunning || !_marked.add(label)) return;
    _marks.add('$label=+${_launch.elapsedMilliseconds}ms');
  }

  /// Runs [body] with [label] listed as active, so a `StartupStall:` line
  /// can name the jobs that were in flight.
  static Future<T> task<T>(String label, Future<T> Function() body) async {
    _active.add(label);
    _windowJobs.add(label);
    try {
      return await body();
    } finally {
      _active.remove(label);
    }
  }

  static void _startupStallCheck(int late, bool away) {
    if (_startupReport == null ||
        away ||
        late < _startupStallMs ||
        _startupStallLines >= _maxStartupStallLines) {
      _startupMaxBuildMs = 0;
      return;
    }
    _startupStallLines++;
    debugPrint('StartupStall: +${_launch.elapsedMilliseconds}ms '
        'late=${late}ms maxBuild=${_startupMaxBuildMs}ms '
        'active=[${_active.join(', ')}]');
    _startupMaxBuildMs = 0;
  }

  /// Runs [body] on the UI thread and logs `SlowMain: label N ms` when it
  /// took 200 ms or more (it blocked the UI that long).
  static T timedSync<T>(String label, T Function() body) {
    final sw = Stopwatch()..start();
    try {
      return body();
    } finally {
      final ms = sw.elapsedMilliseconds;
      if (ms >= 200) debugPrint('SlowMain: $label ${ms}ms');
    }
  }

  /// Runs [body] and logs `SlowDb: label N ms` when it took over 500 ms.
  static Future<T> timed<T>(String label, Future<T> Function() body) async {
    final sw = Stopwatch()..start();
    try {
      return await body();
    } finally {
      final ms = sw.elapsedMilliseconds;
      if (ms >= 500) debugPrint('SlowDb: $label ${ms}ms');
    }
  }
}
