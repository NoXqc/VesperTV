import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import 'subtitle_tracks.dart';
import 'vod_buffering.dart';

/// Where the live picture is in Live pause & rewind's copy.
@immutable
class TimeshiftState {
  const TimeshiftState({
    required this.on,
    this.behind = Duration.zero,
    this.available = Duration.zero,
    this.window = Duration.zero,
    this.memoryOnly = false,
    this.note,
  });

  factory TimeshiftState.fromMap(Map<Object?, Object?> m) {
    Duration ms(String k) =>
        Duration(milliseconds: (m[k] as num?)?.toInt() ?? 0);
    return TimeshiftState(
      on: m['on'] == true,
      behind: ms('behindMs'),
      available: ms('availableMs'),
      window: ms('windowMs'),
      memoryOnly: m['memory'] == true,
      note: m['note'] as String?,
    );
  }

  /// The copy is running (a live MPEG-TS channel on the Android player).
  final bool on;

  /// How far behind live the picture is (0 at live, plus the player's own
  /// few seconds of buffer).
  final Duration behind;

  /// How far back it can go (grows to the window).
  final Duration available;

  /// The setting's minutes.
  final Duration window;
  final bool memoryOnly;
  final String? note;

  /// Behind by no more than the player's normal start buffer: "live".
  bool get atLive => behind <= liveEdge;

  static Duration get liveEdge => Duration(
      milliseconds: 6000 +
          (VodBuffering.liveBufferMs > 0 ? VodBuffering.liveBufferMs : 0));

  @override
  bool operator ==(Object other) =>
      other is TimeshiftState &&
      other.on == on &&
      other.behind.inSeconds == behind.inSeconds &&
      other.available.inSeconds == available.inSeconds &&
      other.memoryOnly == memoryOnly;

  @override
  int get hashCode =>
      Object.hash(on, behind.inSeconds, available.inSeconds, memoryOnly);
}

/// Live pause & rewind (Android; owner + cillfog on Discord, 2026-11-25):
/// the native player keeps a rolling copy of a live channel filled by its
/// one connection (vendored `Timeshift.java`). Pause keeps reading, Play
/// carries on from the paused frame, the skip buttons jump inside the copy.
/// Settings > Playback > Live TV > Pause & rewind live TV.
class LiveTimeshift {
  LiveTimeshift._();

  static const _stats = MethodChannel('vespertv/stats');

  static const choices = [0, 10, 30, 60];
  static const defaultMinutes = 30;

  /// Minutes kept (0 = off). Set from [StorageService.getLiveRewindMinutes]
  /// at startup and on change; applies from the next channel.
  static int minutes = defaultMinutes;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Switches the copy on for [c]'s live channel. Null when on, else why not
  /// (for Send log).
  static Future<String?> arm(VideoPlayerHdrController c) async {
    if (!supported) return 'not on this device';
    try {
      final r = await _stats.invokeMapMethod<Object?, Object?>('setTimeshift', {
        'playerId': SubtitleTracks.playerIdOf(c),
        'on': minutes > 0,
        'minutes': minutes,
      });
      if (r == null) return 'no answer';
      return r['on'] == true ? null : (r['reason'] as String? ?? 'off');
    } on MissingPluginException {
      return 'not in this player';
    } on PlatformException catch (e) {
      return e.code;
    }
  }

  static Future<TimeshiftState?> state(VideoPlayerHdrController c) async {
    if (!supported) return null;
    try {
      final r = await _stats.invokeMapMethod<Object?, Object?>(
          'timeshiftState', {'playerId': SubtitleTracks.playerIdOf(c)});
      return r == null ? null : TimeshiftState.fromMap(r);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Moves the picture by [delta] (negative = back; far ahead = live).
  static Future<TimeshiftState?> jump(
      VideoPlayerHdrController c, Duration delta) async {
    if (!supported) return null;
    try {
      final r =
          await _stats.invokeMapMethod<Object?, Object?>('timeshiftJump', {
        'playerId': SubtitleTracks.playerIdOf(c),
        'deltaMs': delta.inMilliseconds,
      });
      return r == null ? null : TimeshiftState.fromMap(r);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// "−1:23" for [d] behind live.
  static String behindLabel(Duration d) {
    final s = d.inSeconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '−$h:${m.toString().padLeft(2, '0')}:$sec' : '−$m:$sec';
  }
}
