import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/channel.dart';
import 'apple_tv_comeback.dart';
import 'apple_tv_display.dart';
import 'desktop_catchup.dart';
import 'epg_service.dart';
import 'playlist_manager.dart';
import 'storage_service.dart';
import 'desktop_live_recovery.dart';
import 'desktop_stream_setup.dart';
import 'tuliprox.dart';

/// Windows-only holder for a live channel's `Player`/`VideoController`
/// after `DesktopPlayerScreen`'s back button minimizes it — the Windows
/// equivalent of `PlaybackService` continuing to play a live channel in
/// the background once its fullscreen view is left. Exists at all because
/// `DesktopPlayerScreen` deliberately never touches `PlaybackService` (see
/// its own doc comment) — this is a second, much smaller version of the
/// same idea, holding exactly one channel's session at a time: whatever
/// was most recently minimized. A movie or episode never lands here — see
/// `DesktopPlayerScreen._handleBack`, which only hands off a *live*
/// channel; VOD still just stops on exit, same as mobile.
class DesktopMiniPlayer {
  DesktopMiniPlayer._();
  static final DesktopMiniPlayer instance = DesktopMiniPlayer._();

  /// Null when nothing is minimized — `DesktopLiveResumeHint` watches this
  /// directly to decide whether to show its resume pill at all.
  final ValueNotifier<Channel?> channel = ValueNotifier(null);

  Player? _player;
  VideoController? _controller;

  /// Read-only access for a preview surface (the Timeline guide's own
  /// mini-player box) that wants to render the actual minimized stream
  /// without taking ownership of it the way [take] does. Safe to mount a
  /// second `Video` widget against this alongside (briefly) whatever
  /// still-live widget handed it off — unlike `video_player_hdr`'s
  /// platform views (see `LiveResumeHint`'s doc comment for the real bug
  /// that caused on mobile), `media_kit`'s texture-based rendering
  /// supports multiple simultaneous `Video` widgets on one controller.
  VideoController? get controller => _controller;

  /// The session's player (Vesper AI's [DesktopPlayerControl]).
  Player? get player => _player;

  /// Catch-up playing here (the guide's OK on a past programme, or a
  /// full-screen catch-up left with Back), like Android's preview. Null =
  /// the live channel.
  DesktopCatchup? _catchup;

  /// Taken by [take] with the player, until the full-screen player that
  /// gets the player claims it ([claimCatchup]).
  DesktopCatchup? _handover;

  /// Catch-up is playing (not the live channel).
  bool get inCatchup => _catchup?.active ?? false;

  /// The guide's OK on a past programme: [live] from [at] here, OK again
  /// goes full screen on it (`TvHomeScreen._previewOrOpenCatchup`).
  void playCatchup(Channel live, DateTime at,
      {required PlaylistManager playlists,
      required EpgService epg,
      required StorageService storage}) {
    final player = _ensurePlayer();
    _completedSub?.cancel();
    _completedSub = null;
    _catchup?.dispose();
    DesktopLiveRecovery.of(player).stop();
    final catchup = DesktopCatchup.forApp(player,
        playlists: playlists, epg: epg, storage: storage, onLive: _toLive);
    _catchup = catchup;
    channel.value = live;
    unawaited(catchup.play(live, at));
  }

  /// Catch-up reached now (or Back to live): the live channel again on
  /// the same player.
  Future<void> _toLive(Channel live) async {
    _catchup?.dispose();
    _catchup = null;
    final player = _player;
    if (player == null) return;
    try {
      await openDesktopStream(player, live);
    } catch (e) {
      debugPrint('DesktopMiniPlayer: live open failed (${e.runtimeType})');
    }
    if (_player == player && channel.value?.id == live.id) {
      DesktopLiveRecovery.of(player).watch(live);
    }
  }

  /// The full-screen player that got [take]'s player takes its catch-up.
  DesktopCatchup? claimCatchup(Player player) {
    final catchup = _handover;
    _handover = null;
    if (catchup == null || catchup.player == player) return catchup;
    catchup.dispose();
    return null;
  }

  Player _ensurePlayer() {
    if (_player == null || _controller == null) {
      final created = newDesktopPlayer(bigCache: true);
      // Same reconnect tuning as DesktopPlayerScreen.initState — see its
      // comment.
      configureDesktopStreamPlayer(created, 'mini');
      _player = created;
      _controller = desktopVideoController(created);
    }
    return _player!;
  }

  /// Re-opens a live preview that reports `completed` — same app-level
  /// safety net as `DesktopPlayerScreen`'s own, since mpv's reconnect
  /// options don't catch every way a live stream ends. Only set for a
  /// session started by [play]; [take]/[clear] cancel it.
  StreamSubscription<bool>? _completedSub;

  /// Starts [ch] straight into this holder, without opening
  /// `DesktopPlayerScreen` — the guide's "first click previews, second
  /// click goes fullscreen" path. Reuses the current `Player` when there is
  /// one (just opens the new stream on it) so switching channels in the
  /// preview box never stacks up decoders.
  /// Apple TV: back from the Home screen, a live preview opens again at
  /// live (media_kit paused it, tvOS cut its connection: [AppleTvComeback]).
  /// Made with the first session (the app's bindings exist by then).
  AppLifecycleListener? _comeback;
  bool _comebackSet = false;

  void _listenForComeback() {
    if (_comebackSet) return;
    _comebackSet = true;
    _comeback ??= AppleTvComeback.listen(_onBackOnScreen);
  }

  void _onBackOnScreen(Duration away) {
    final ch = channel.value;
    final player = _player;
    if (ch == null || player == null || !ch.isLive || _catchup != null) {
      debugPrint('AppleTvComeback: back after ${away.inSeconds} s away, '
          'preview ${ch == null ? 'empty' : _catchup != null ? 'in catch-up' : 'not live'}');
      return;
    }
    debugPrint('AppleTvComeback: preview ${ch.name} opened again after '
        '${away.inSeconds} s away');
    unawaited(openDesktopStream(player, ch).then((_) {
      if (_player == player && channel.value?.id == ch.id) {
        DesktopLiveRecovery.of(player).watch(ch);
      }
    }));
  }

  void play(Channel ch) {
    _listenForComeback();
    _catchup?.dispose();
    _catchup = null;
    final player = _ensurePlayer();
    final leaving = channel.value;
    channel.value = ch;
    bool current() => _player == player && channel.value?.id == ch.id;
    unawaited(() async {
      // Leaving a Tuliprox stream ends it on the server first, so a
      // one-connection account is free for the next channel, like
      // Android's PlaybackService.play (the guide's preview zapped without
      // it on computers / iPhone / Apple TV). At most 1.5 s.
      if (leaving != null && leaving.url != ch.url) {
        final at = DateTime.now();
        await Tuliprox.instance
            .release(leaving)
            .timeout(const Duration(milliseconds: 1500), onTimeout: () {});
        final ms = DateTime.now().difference(at).inMilliseconds;
        if (ms > 50) {
          debugPrint('MiniPlayer: ${ch.name} after releasing ${leaving.name} '
              '($ms ms)');
        }
        if (!current()) return;
      }
      // Waits, retries and copies: DesktopLiveRecovery (it stays with the
      // player when full screen takes it over).
      await openDesktopStream(player, ch);
      if (!current()) return;
      DesktopLiveRecovery.of(player).watch(ch);
      if (ch.isLive) Tuliprox.instance.noteStarted(ch);
    }());
  }

  void minimize(Channel ch, Player player, VideoController controller,
      {DesktopCatchup? catchup}) {
    _listenForComeback();
    _completedSub?.cancel();
    _completedSub = null;
    if (_catchup != catchup) _catchup?.dispose();
    _catchup = catchup;
    catchup?.onLive = _toLive;
    // Only one minimized session can exist at a time (there's only one
    // pill) — if something else was already minimized, it has no other
    // reference anywhere, so it must be disposed here or it'd keep
    // decoding in the background forever with nothing left to stop it.
    if (_player != null && _player != player) {
      DesktopLiveRecovery.disposePlayer(_player);
      final old = channel.value;
      if (old != null && old.url != ch.url) {
        unawaited(Tuliprox.instance.release(old));
      }
    }
    _player = player;
    _controller = controller;
    channel.value = ch;
    // A stream handed over from full screen had no recovery here before.
    // Catch-up is finite: never reconnected as live.
    if (catchup == null) {
      DesktopLiveRecovery.of(player).watch(ch);
    } else {
      DesktopLiveRecovery.of(player).stop();
    }
  }

  /// Hands the live session back to a freshly reopened
  /// `DesktopPlayerScreen` instead of it creating a new `Player` — resuming
  /// fullscreen must not restart the stream. Clears this holder's own
  /// state since that screen now owns the session again.
  (Player, VideoController)? take() {
    final player = _player;
    final controller = _controller;
    if (player == null || controller == null) return null;
    _completedSub?.cancel();
    _completedSub = null;
    _handover?.dispose();
    _handover = _catchup;
    _catchup = null;
    _player = null;
    _controller = null;
    channel.value = null;
    return (player, controller);
  }

  /// Abandons whatever's minimized, disposing its `Player` outright —
  /// every fresh-playback entry point (`TvHomeScreen._selectChannel`,
  /// `MovieDetailScreen.play`, `SeriesDetailScreen._openEpisode`) calls
  /// this before starting something new. Reported directly: picking a
  /// *different* live channel after minimizing one left the old session
  /// quietly still running — [minimize] only disposes a previous one when
  /// minimize is called *again*, which a brand-new, unrelated channel
  /// selection never does, so the old `Player` just kept decoding/playing
  /// audio in the background forever, with the resume pill still pointed
  /// at it even though a different channel was now also playing on top.
  void clear() {
    // Its Tuliprox stream ends on the server now ([Tuliprox.release]).
    final leaving = channel.value;
    if (leaving != null) unawaited(Tuliprox.instance.release(leaving));
    _completedSub?.cancel();
    _completedSub = null;
    _catchup?.dispose();
    _catchup = null;
    _handover?.dispose();
    _handover = null;
    DesktopLiveRecovery.disposePlayer(_player);
    _player = null;
    _controller = null;
    channel.value = null;
    // Apple TV: the TV's own mode back unless something plays within a
    // few seconds (a new channel right after keeps the mode it asks for).
    AppleTvDisplayMatch.reset();
  }
}
