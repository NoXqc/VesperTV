import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import 'storage_service.dart';
import 'subtitle_tracks.dart';

/// Settings > Playback > Frame rate & resolution (Android): Match frame rate (optionally
/// only between 50 and 60 Hz) and Match resolution, like TiviMate. A few
/// seconds into the main player's stream the video's frame rate (declared,
/// else measured from rendered frames — live TS rarely declares one) and
/// size go to the app's `DisplayModes.kt`, which asks Android for the
/// closest display mode. The TV goes black for a second or two while HDMI
/// switches; a channel in the same family keeps the mode, so zapping
/// doesn't. Leaving the app gives the TV its own mode back (Android), and
/// [reset] does when playback stops. User request (Discord, Fire TV Cube,
/// 2026-10-23).
class DisplayMatch {
  static const _display = MethodChannel('vespertv/display');
  static const _stats = MethodChannel('vespertv/stats');

  /// True once a mode was asked for, so [reset] only runs when needed.
  static bool _requested = false;

  static bool enabled(StorageService storage) =>
      Platform.isAndroid &&
      (storage.getMatchFrameRate() || storage.getMatchResolution());

  /// Called once the main player started [c]; [isCurrent] says whether it
  /// is still the playing one (a channel change cancels the match).
  /// [rateOnly]: Multiview's screen with the sound sets the refresh rate but
  /// never the resolution (a small screen's 720p isn't the TV's picture).
  static Future<void> start(StorageService storage, VideoPlayerHdrController c,
      bool Function() isCurrent,
      {bool rateOnly = false}) async {
    if (!enabled(storage)) return;
    if (rateOnly && !storage.getMatchFrameRate()) return;
    try {
      final id = SubtitleTracks.playerIdOf(c);
      final wantRate = storage.getMatchFrameRate();
      // As soon as the stream says what it is: its declared frame rate, else
      // the first frames' timestamps (native FrameRateProbe, ~0.3 s after the
      // picture starts). Was 2 s + 2 s of counting, so the TV switched ~4 s
      // into the picture ("clunky", Fire TV Cube user, 2026-10-23).
      Map<Object?, Object?>? first;
      Map<Object?, Object?>? sample;
      var fps = -1.0;
      final started = DateTime.now();
      while (DateTime.now().difference(started) < const Duration(seconds: 6)) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (!isCurrent()) return;
        sample = await _sample(id);
        if (sample == null) continue;
        final w = (sample['width'] as num?)?.toInt() ?? 0;
        if (w <= 0) continue;
        first ??= sample;
        final declared = (sample['frameRate'] as num?)?.toDouble() ?? -1;
        final pts = (sample['ptsFps'] as num?)?.toDouble() ?? -1;
        fps = declared > 0 ? declared : pts;
        if (fps > 0 || !wantRate) break;
      }
      // Fallback: count rendered frames over what was sampled.
      if (fps <= 0 && wantRate && first != null) {
        fps = _measured(first, sample) ?? -1;
      }
      if (!isCurrent() || sample == null) return;
      final width = (sample['width'] as num?)?.toInt() ?? 0;
      final height = (sample['height'] as num?)?.toInt() ?? 0;
      final mode = await _display.invokeMethod<String>('match', {
        'fps': fps,
        'width': width,
        'height': height,
        'rate': storage.getMatchFrameRate(),
        'only5060': storage.getMatch5060Only(),
        'resolution': !rateOnly && storage.getMatchResolution(),
      });
      if (mode != null && mode != 'same') _requested = true;
      final gaps = sample['ptsGaps'];
      debugPrint('DisplayMatch: video ${width}x$height '
          '${fps > 0 ? fps.toStringAsFixed(2) : '?'} fps after '
          '${DateTime.now().difference(started).inMilliseconds} ms -> '
          '${mode ?? 'no matching mode'}'
          '${gaps is String && gaps.isNotEmpty ? ' · frame gaps ms $gaps' : ''}');
    } catch (e) {
      debugPrint('DisplayMatch: $e');
    }
  }

  /// Hands the display back to the TV's own mode (playback stopped, or the
  /// settings were turned off).
  static Future<void> reset() async {
    if (!Platform.isAndroid || !_requested) return;
    _requested = false;
    try {
      await _display.invokeMethod<void>('reset');
      debugPrint('DisplayMatch: back to the TV\'s mode');
    } catch (_) {}
  }

  /// The playing stream's frame rate: what it declares, else what the first
  /// frames' timestamps say (FrameRateProbe). Null while neither is known.
  /// A .ts live stream's video track rarely carries a rate, so the quality
  /// badges ask here when the track has none (owner photo, 2026-11-14).
  static Future<double?> frameRateOf(VideoPlayerHdrController c) async {
    if (!Platform.isAndroid) return null;
    try {
      final s = await _sample(SubtitleTracks.playerIdOf(c));
      if (s == null) return null;
      final declared = (s['frameRate'] as num?)?.toDouble() ?? -1;
      final pts = (s['ptsFps'] as num?)?.toDouble() ?? -1;
      final fps = declared > 0 ? declared : pts;
      return fps > 0 ? fps : null;
    } catch (_) {
      return null;
    }
  }

  /// The native player's stats for [c] (Android; null elsewhere).
  static Future<Map<Object?, Object?>?> statsOf(
      VideoPlayerHdrController c) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _sample(SubtitleTracks.playerIdOf(c));
    } catch (_) {
      return null;
    }
  }

  static Future<Map<Object?, Object?>?> _sample(int playerId) => _stats
      .invokeMapMethod<Object?, Object?>('getStats', {'playerId': playerId});

  /// Frames rendered per second between two StatsBridge samples.
  static double? _measured(Map<Object?, Object?> a, Map<Object?, Object?>? b) {
    if (b == null) return null;
    final frames = (b['rendered'] as num? ?? 0) - (a['rendered'] as num? ?? 0);
    final ms = (b['nowMs'] as num? ?? 0) - (a['nowMs'] as num? ?? 0);
    if (frames <= 0 || ms < 500) return null;
    return frames * 1000 / ms;
  }
}
