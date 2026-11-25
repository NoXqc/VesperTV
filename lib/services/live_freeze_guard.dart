import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// What [LiveFreezeGuard] watches: the live player now ([key] = player +
/// channel, a new key starts over), whether it plays and whether it waits
/// for data.
typedef LiveFreezeTarget = ({
  Object player,
  String key,
  bool playing,
  bool buffering
});

/// A live picture stuck while the sound plays on: the stream's timestamps
/// jumped (a server switched or reopened the source, the provider restarted
/// its encoder) and ExoPlayer holds every frame (Homatics, owner 2026-11-24:
/// Sky Sports News 14 s back in time with no switch, Tuliprox refusing a
/// switch and reopening the old source; only a reload helped).
///
/// Polls the player's frame count every second while a live channel plays.
/// After [stuckFor] without a new frame, with video shown before and at
/// least a second buffered (data comes, it isn't a stall), it gives
/// Pause/Play once; still stuck after another [stuckFor], one reload, at
/// most [maxReloads] per [reloadWindow] (an automatic reload races the
/// provider's connection limit, see `reloadCurrentChannel`). Never while
/// paused or waiting for data, before the channel showed a picture or for
/// audio-only channels.
///
/// Also the player stuck waiting while data keeps coming (owner's Homatics,
/// 2026-11-24, ESPN News 110 s behind live: one track went silent, the
/// other filled the memory, "Target buffer size reached with less than
/// 500ms", buffering for good): no new frame for [starvedFor] polls while
/// [starvedBytes] arrived and under a second is buffered = a reload (same
/// limit). Android only.
class LiveFreezeGuard {
  LiveFreezeGuard({
    required this.target,
    required this.stats,
    required this.nudge,
    required this.reload,
    DateTime Function()? clock,
    this.interval = const Duration(seconds: 1),
    this.stuckFor = 3,
    this.starvedFor = 10,
    this.starvedBytes = 2 * 1024 * 1024,
    this.maxReloads = 2,
    this.reloadWindow = const Duration(minutes: 5),
  }) : _clock = clock ?? DateTime.now;

  /// The live player to watch, null when nothing should be watched.
  final LiveFreezeTarget? Function() target;

  /// The native player's stats (`rendered`, `height`, `bufferedMs`).
  final Future<Map<Object?, Object?>?> Function(Object player) stats;

  /// Pause/Play on the player.
  final Future<void> Function() nudge;

  /// Reload the channel (same as the player's Reload).
  final Future<void> Function() reload;

  final DateTime Function() _clock;
  final Duration interval;

  /// Polls (seconds) without a new frame before acting.
  final int stuckFor;

  /// Polls without a new frame, data arriving, before a reload.
  final int starvedFor;

  /// Network bytes that must arrive meanwhile (it isn't the network).
  final int starvedBytes;
  final int maxReloads;
  final Duration reloadWindow;

  Timer? _timer;
  String? _key;
  int? _lastFrames;
  bool _hadPicture = false;
  int _stuck = 0;
  int _step = 0;
  int _starved = 0;
  int? _starvedFromBytes;
  bool _busy = false;
  final List<DateTime> _reloads = [];

  void start() {
    // The real OS, not defaultTargetPlatform: widget tests run as Android.
    if (kIsWeb || !Platform.isAndroid) return;
    _timer ??= Timer.periodic(interval, (_) => unawaited(tick()));
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _restart(String? key) {
    _key = key;
    _lastFrames = null;
    _hadPicture = false;
    _stuck = 0;
    _step = 0;
    _starved = 0;
    _starvedFromBytes = null;
  }

  /// A reload unless [maxReloads] happened within [reloadWindow].
  Future<bool> _reload(String why) async {
    final now = _clock();
    _reloads.removeWhere((at) => now.difference(at) > reloadWindow);
    if (_reloads.length >= maxReloads) {
      debugPrint('LiveFreeze: $why, $maxReloads reloads in '
          '${reloadWindow.inMinutes} min already, leaving it');
      return false;
    }
    _reloads.add(now);
    debugPrint('LiveFreeze: $why, reloading');
    await reload();
    _lastFrames = null;
    return true;
  }

  @visibleForTesting
  Future<void> tick() async {
    if (_busy) return;
    final t = target();
    if (t == null) {
      _restart(null);
      return;
    }
    if (t.key != _key) _restart(t.key);
    if (!t.playing) {
      _stuck = 0;
      _starved = 0;
      return;
    }
    Map<Object?, Object?>? m;
    try {
      m = await stats(t.player);
    } catch (_) {
      return; // player gone between the check and the call
    }
    if (m == null || target()?.key != _key) return;
    final frames = (m['rendered'] as num?)?.toInt();
    if (frames == null) return;
    final last = _lastFrames;
    _lastFrames = frames;
    // First reading, or the counters started over (a reused player).
    if (last == null || frames < last) {
      _stuck = 0;
      _starved = 0;
      return;
    }
    if (frames > last) {
      if (_step > 0) debugPrint('LiveFreeze: picture moving again');
      _hadPicture = true;
      _stuck = 0;
      _step = 0;
      _starved = 0;
      return;
    }
    final height = (m['height'] as num?)?.toInt() ?? 0;
    final buffered = (m['bufferedMs'] as num?)?.toInt() ?? 0;
    final bytes = (m['bytes'] as num?)?.toInt();
    if (_hadPicture && buffered < 1000 && bytes != null) {
      if (_starved++ == 0) _starvedFromBytes = bytes;
      final arrived = bytes - (_starvedFromBytes ?? bytes);
      if (_starved >= starvedFor) {
        _starved = 0;
        if (arrived >= starvedBytes && _step < 2) {
          _busy = true;
          try {
            if (await _reload('no picture for ${starvedFor}s while '
                '${arrived ~/ 1024} KB arrived (player stuck waiting)')) {
              _step = 2;
            } else {
              _step = 3;
            }
          } finally {
            _busy = false;
          }
          return;
        }
      }
    } else {
      _starved = 0;
    }
    if (t.buffering) {
      _stuck = 0;
      return;
    }
    if (!_hadPicture || height <= 0 || buffered < 1000) {
      _stuck = 0;
      return;
    }
    if (++_stuck < stuckFor) return;
    _stuck = 0;
    _busy = true;
    try {
      final secs = (buffered / 1000).toStringAsFixed(1);
      if (_step == 0) {
        _step = 1;
        debugPrint('LiveFreeze: picture stuck ${stuckFor}s, $secs s buffered, '
            'Pause/Play');
        await nudge();
      } else if (_step == 1) {
        _step = await _reload('still stuck after Pause/Play') ? 2 : 3;
      }
      // Step 2 (reloaded) / 3 (gave up): nothing more until it moves.
    } finally {
      _busy = false;
    }
  }
}
