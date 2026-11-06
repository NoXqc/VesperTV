import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../models/channel.dart';
import '../models/epg_program.dart';
import '../models/playlist_profile.dart';
import 'catchup_session.dart';
import 'desktop_stream_setup.dart';

/// Catch-up on Windows (dev-notes/catchup-plan.md, task C4): Android's
/// model on the media_kit player. A session is the live channel replayed
/// from a wall-clock time; the playhead is `requestStart + position`. A
/// request that ends carries on from where it stopped, reaching now goes
/// back to live, and with Settings > Playback > Catch-up "Keep playing"
/// off it pauses at the end of the programme it started on.
///
/// Archive streams are finite: never handed to `DesktopLiveRecovery`.
class DesktopCatchup {
  DesktopCatchup(this.player,
      {required this.profileFor,
      required this.guide,
      required this.keepPlaying,
      required this.onLive,
      DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  final Player player;
  final PlaylistProfile? Function(String playlistId) profileFor;
  final List<EpgProgram> Function(Channel live) guide;
  final bool Function() keepPlaying;

  /// Called when catch-up hands back to the live channel (caught up, Back
  /// to live, or no catch-up for that time).
  final Future<void> Function(Channel live) onLive;
  final DateTime Function() clock;

  CatchupSession? session;
  StreamSubscription<bool>? _completed;
  StreamSubscription<Duration>? _position;
  int _gen = 0;

  bool get active => session != null;

  /// The wall-clock time playing now.
  DateTime? get playhead => session?.playhead(player.state.position);

  /// The programme on at the playhead (the scrub bar's range).
  EpgProgram? get programme {
    final s = session, at = playhead;
    if (s == null || at == null) return null;
    return CatchupSession.programmeAt(guide(s.live), at);
  }

  /// The request for [live] from [at] at [now], or null when it should play
  /// live instead (no catch-up, under [CatchupSession.liveEdge] from now, or
  /// no link). Older than the channel's archive starts at its oldest time;
  /// [stopAtProgrammeEnd] stops at the end of the programme on at [at].
  static CatchupSession? plan(Channel live, DateTime at,
      {required DateTime now,
      required PlaylistProfile? profile,
      required List<EpgProgram> programmes,
      required bool stopAtProgrammeEnd}) {
    if (!live.hasCatchup || now.difference(at) < CatchupSession.liveEdge) {
      return null;
    }
    final oldest = CatchupSession.oldest(live, now);
    final from = at.isBefore(oldest) ? oldest : at;
    final start = CatchupSession.floorToMinute(from);
    final span = CatchupSession.spanFrom(start, now);
    final url = CatchupSession.linkFor(live, profile,
        start: start, span: span, now: now);
    if (url == null) {
      debugPrint('DesktopCatchup: no link for ${live.name} '
          '(${live.catchupKind})');
      return null;
    }
    return CatchupSession(
        live: live,
        requestStart: start,
        channel: CatchupSession.channelFor(live, start, url),
        startOffset: from.difference(start),
        until: stopAtProgrammeEnd
            ? CatchupSession.programmeAt(programmes, from)?.stop
            : null);
  }

  /// Plays [live] from [at]. Too close to now (or no catch-up / no link)
  /// plays the live channel instead; returns whether catch-up started.
  Future<bool> play(Channel live, DateTime at,
      {bool toProgrammeEnd = true}) async {
    final gen = ++_gen;
    final s = plan(live, at,
        now: clock(),
        profile: profileFor(live.playlistId),
        programmes: guide(live),
        stopAtProgrammeEnd: toProgrammeEnd && !keepPlaying());
    if (s == null) {
      await _goLive(live);
      return false;
    }
    session = s;
    debugPrint('DesktopCatchup: ${live.name} from '
        '${s.requestStart.toIso8601String()} +${s.startOffset.inSeconds}s · '
        '${CatchupSession.linkShape(s.channel.url)}'
        '${s.until == null ? '' : ' · stops ${s.until!.toIso8601String()}'}');
    _watch(s, gen);
    await openDesktopStream(player, s.channel,
        start: s.startOffset > Duration.zero ? s.startOffset : null);
    return true;
  }

  void _watch(CatchupSession s, int gen) {
    _completed?.cancel();
    _position?.cancel();
    final opened = clock();
    _completed = player.stream.completed.listen((done) {
      if (!done || gen != _gen || session != s) return;
      // An empty answer (ended right away) counts as caught up: no
      // request loops.
      final played = clock().difference(opened);
      final at = s.playhead(player.state.position);
      if (played < CatchupSession.minUsefulPlay ||
          clock().difference(at) < CatchupSession.liveEdge) {
        unawaited(_goLive(s.live));
        return;
      }
      // The request's span ran out: the next one starts where it stopped.
      unawaited(play(s.live, at, toProgrammeEnd: s.until != null));
    });
    _position = player.stream.position.listen((position) {
      if (gen != _gen || session != s || s.endReached) return;
      if (s.pastEnd(s.playhead(position))) {
        s.endReached = true;
        debugPrint('DesktopCatchup: programme ended, paused');
        unawaited(player.pause());
      }
    });
  }

  /// Play after the programme's end pause: carries on past it.
  void resume() {
    final s = session;
    if (s != null && s.endReached) {
      s.endReached = false;
      // No stop point any more: the viewer chose to carry on.
      session = CatchupSession(
          live: s.live,
          requestStart: s.requestStart,
          channel: s.channel,
          startOffset: s.startOffset)
        ..endReached = false;
      _watch(session!, _gen);
    }
    unawaited(player.play());
  }

  /// To wall-clock time [t]: inside this request when the stream can seek
  /// there, else a new request from [t] (always works, minute steps).
  Future<void> seekTo(DateTime t) async {
    final s = session;
    if (s == null) return;
    final inRequest = t.difference(s.requestStart);
    final duration = player.state.duration;
    if (inRequest >= Duration.zero &&
        duration > Duration.zero &&
        inRequest <= duration) {
      await player.seek(inRequest);
      return;
    }
    await play(s.live, t, toProgrammeEnd: s.until != null);
  }

  Future<void> seekBy(Duration amount) async {
    final at = playhead;
    if (at != null) await seekTo(at.add(amount));
  }

  /// Back to now.
  Future<void> backToLive() async {
    final s = session;
    if (s != null) await _goLive(s.live);
  }

  Future<void> _goLive(Channel live) async {
    _gen++;
    _completed?.cancel();
    _position?.cancel();
    session = null;
    debugPrint('DesktopCatchup: back to live ${live.name}');
    await onLive(live);
  }

  /// The screen is closing or switching to another title: stop watching.
  void dispose() {
    _gen++;
    _completed?.cancel();
    _position?.cancel();
    session = null;
  }
}
