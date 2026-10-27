import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player_hdr/video_player_hdr.dart';

import '../models/catchup.dart';
import '../models/channel.dart';
import '../models/epg_program.dart';
import '../models/playlist_profile.dart';
import 'catchup_url.dart';
import 'subtitle_tracks.dart';

/// One catch-up playback: a live channel replayed from [requestStart]
/// (dev-notes/catchup-plan.md §1). The playhead is a wall-clock time —
/// programmes are only markers on it — so when this request's stream ends
/// the next request simply starts where it stopped, and reaching now means
/// going back to the live channel.
class CatchupSession {
  CatchupSession(
      {required this.live,
      required this.requestStart,
      required this.channel,
      this.startOffset = Duration.zero});

  /// The live channel being replayed; Back to now plays it.
  final Channel live;

  /// The UTC minute this request starts at (Xtream links have minute
  /// granularity).
  final DateTime requestStart;

  /// The `cu_` channel actually playing (transient, never live).
  final Channel channel;

  /// Where in this request playback starts: a continuation or a seek lands
  /// between whole minutes, so the request starts at the minute before and
  /// the player seeks this far in.
  final Duration startOffset;

  /// Closer to now than this, catch-up plays the live channel instead.
  static const liveEdge = Duration(seconds: 90);

  /// One request covers at most this much (the provider answers an
  /// on-air span with only what has aired).
  static const maxSpan = Duration(hours: 6);

  /// A request that ended this early was empty: treat it as caught up
  /// rather than asking again (no request loops).
  static const minUsefulPlay = Duration(seconds: 5);

  DateTime playhead(Duration position) => requestStart.add(position);

  /// The programme on at [t] in [programmes] (sorted by start), if any.
  static EpgProgram? programmeAt(List<EpgProgram> programmes, DateTime t) {
    for (final p in programmes) {
      if (!t.isBefore(p.start) && t.isBefore(p.stop)) return p;
    }
    return null;
  }

  /// The programme before / after the one on at [t].
  static EpgProgram? programmeBefore(List<EpgProgram> programmes, DateTime t) {
    EpgProgram? best;
    final current = programmeAt(programmes, t);
    final limit = current?.start ?? t;
    for (final p in programmes) {
      if (!p.start.isBefore(limit)) break;
      best = p;
    }
    return best;
  }

  static EpgProgram? programmeAfter(List<EpgProgram> programmes, DateTime t) {
    final current = programmeAt(programmes, t);
    final limit = current?.stop ?? t;
    for (final p in programmes) {
      if (!p.start.isBefore(limit)) return p;
    }
    return null;
  }

  static DateTime floorToMinute(DateTime t) {
    final u = t.toUtc();
    return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute);
  }

  /// Oldest time [live]'s catch-up reaches at [now].
  static DateTime oldest(Channel live, DateTime now) =>
      now.subtract(Duration(days: live.catchupDays));

  /// From [start] up to now, capped at [maxSpan], whole minutes, >= 1 min.
  static Duration spanFrom(DateTime start, DateTime now) {
    var span = now.difference(start);
    if (span > maxSpan) span = maxSpan;
    final minutes = (span.inSeconds / 60).ceil();
    return Duration(minutes: minutes < 1 ? 1 : minutes);
  }

  /// The transient channel that plays [url]: a `cu_` id unique per
  /// request start (so asking again from another time is a real switch),
  /// the live channel's EPG id (the player's guide line follows it), and
  /// never in history/resume/tracking.
  static Channel channelFor(Channel live, DateTime start, String url) {
    final raw = '${Channel.catchupPrefix}${live.rawId}_'
        '${start.millisecondsSinceEpoch ~/ 1000}';
    return Channel(
      id: '${live.playlistId}::$raw',
      rawId: raw,
      playlistId: live.playlistId,
      name: live.name,
      group: live.group,
      url: url,
      logoUrl: live.logoUrl,
      epgIdOverride: live.epgId,
      transientPlayback: true,
    );
  }

  /// The catch-up link for [live] from [start], or null when it can't be
  /// built. Xtream playlists supply the account; M3U `xc` entries carry it
  /// in their own link.
  static String? linkFor(Channel live, PlaylistProfile? profile,
      {required DateTime start,
      required Duration span,
      required DateTime now,
      String ext = 'm3u8'}) {
    final kind = live.catchupKind;
    if (kind == null) return null;
    final xtream = profile != null && profile.isXtream;
    final offsetMinutes = profile?.serverTimeOffsetMinutes;
    return catchupUrl(
      kind: kind,
      liveUrl: live.url,
      catchupSource: live.catchupSource,
      streamId: live.streamId,
      start: start,
      span: span,
      now: now,
      serverOffset:
          offsetMinutes == null ? null : Duration(minutes: offsetMinutes),
      // The live link's own origin: it already names whichever server
      // (primary or backup) the playlist loaded from.
      xtreamServer:
          xtream && kind == CatchupKind.xc ? _originOf(live.url) : null,
      user: xtream ? profile.xtreamUsername : null,
      pass: xtream ? profile.xtreamPassword : null,
      ext: ext,
    );
  }

  /// [url] for Send log: no host, account or token — only the path's
  /// shape, e.g. `/timeshift/*/*/140/2026-10-27:15-00/*.m3u8`. The span,
  /// timeshift dates and keywords stay; every other part is `*`.
  static String linkShape(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '?';
    final segs = uri.pathSegments;
    // Only the span right after `timeshift/<user>/<pass>/` stays a number:
    // an account can be all digits too.
    final ts = segs.indexOf('timeshift');
    final span = ts < 0 ? -1 : ts + 3;
    final parts = [
      for (var i = 0; i < segs.length; i++) _shapeOf(segs[i], i == span),
    ];
    final query = uri.queryParameters.keys.toList()..sort();
    return '${uri.scheme}://*/${parts.join('/')}'
        '${query.isEmpty ? '' : '?${query.join('&')}'}';
  }

  static String _shapeOf(String seg, bool span) {
    if (span && RegExp(r'^\d+$').hasMatch(seg)) return seg;
    final dot = seg.lastIndexOf('.');
    final stem = dot > 0 ? seg.substring(0, dot) : seg;
    final ext = dot > 0 ? seg.substring(dot) : '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}:\d{2}-\d{2}$').hasMatch(stem) ||
        const {'timeshift', 'streaming', 'timeshift.php', 'live'}
            .contains(seg) ||
        RegExp(r'^(index|video|mono|timeshift_abs)[-\d]*$').hasMatch(stem)) {
      return seg;
    }
    return '*$ext';
  }

  static String? _originOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri.origin;
  }

  static const _stats = MethodChannel('vespertv/stats');

  /// Turns the vendored player's live recovery off for [c] (Android):
  /// errors resume in place when seekable, ENDED reaches Dart.
  static Future<void> markFinite(VideoPlayerHdrController c) async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    try {
      await _stats.invokeMethod<void>('setFiniteMode',
          {'playerId': SubtitleTracks.playerIdOf(c), 'on': true});
    } catch (e) {
      debugPrint('Catchup: finite mode not set: $e');
    }
  }
}
