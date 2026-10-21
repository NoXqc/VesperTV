import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/channel.dart';
import '../models/playlist_profile.dart';
import '../utils/constants.dart';
import 'playlist_manager.dart';
import 'real_4k_channels.dart';
import 'storage_service.dart';
import 'archive_ready_watch.dart';
import 'archive_service.dart';
import 'watch_tracker.dart';
import '../l10n/l10n.dart';

/// Owns the single, app-wide [VideoPlayerHdrController] for whatever channel
/// is currently playing.
///
/// Was a plain `VideoPlayerController` (the stock `video_player` package) —
/// switched after a long, evidence-backed diagnosis of a real bug: on
/// Android, going fullscreen showed solid black while the exact same
/// stream played fine in a smaller inline preview elsewhere in the app,
/// even though the decoder logs showed successful decoding the entire
/// time (confirmed via logcat on real Formuler and Firestick hardware). A
/// side-by-side comparison against a native player app on the same
/// hardware showed identical MediaCodec-level success in both — the
/// difference was specifically in how each *displays* the decoded frame,
/// not decoding itself. `video_player`'s Android implementation renders
/// through a GPU-texture path that has a known, documented weakness here;
/// `video_player_hdr` is a drop-in-API fork that can render through a
/// platform view instead, closer to how a native app's own `SurfaceView`
/// works. `EnableImpeller` (Flutter's newer renderer, which fixes this
/// properly) can't be turned on here — it crashes on startup on this
/// hardware's GPU driver (see AndroidManifest.xml) — so this is the
/// practical way to get the same effective fix without it.
///
/// Previously each screen (the inline pane, the fullscreen player) created
/// and disposed its own controller, so navigating back from fullscreen on a
/// phone killed playback entirely — there was nothing left to resume into.
/// Hoisting the controller up here means any number of presentation widgets
/// (the inline pane, the fullscreen screen, a mini-player bar) can all watch
/// the same live controller — switching between them is just a different
/// wrapper around the same video, never a restart.
class PlaybackService extends ChangeNotifier {
  /// Set by the app (main.dart): asked before a channel opens; false =
  /// don't play (a recording holds the playlist's only connection).
  static Future<bool> Function(Channel channel)? confirmOpen;

  /// Set by the app: a different URL to open [channel] from (the
  /// recorder's local tap while that channel records), or null.
  static Future<String?> Function(Channel channel)? openUrlFor;

  PlaybackService(this._storage, this._playlistManager);

  static const _recentlyPlayedCacheKey = 'recently_played';
  static const _maxRecentlyPlayed = 30;

  /// Main keeps the bare `recently_played` cache file name an upgrading
  /// install already has — every other viewer gets its own, so "Continue
  /// Watching" doesn't mix one viewer's history into another's. Same
  /// suffix convention as `StorageService`'s per-viewer prefs keys, just
  /// applied to a cache *file* name instead of a prefs key, since this
  /// list has always lived in the file cache, not SharedPreferences.
  String get _recentlyPlayedCacheKeyForViewer {
    final viewerId = _storage.getActiveViewerId();
    return viewerId == AppConstants.mainViewerId
        ? _recentlyPlayedCacheKey
        : '${_recentlyPlayedCacheKey}_vp_$viewerId';
  }

  final StorageService _storage;
  final PlaylistManager _playlistManager;

  Channel? currentChannel;

  /// The live list the user last picked a channel from (TvHomeScreen's
  /// Live list / Timeline guide, Favourites included) — what the player's
  /// CH+/CH- step through. Plain field, no notify; PlayerScreen falls back
  /// to the channel's own group when the playing channel isn't in it.
  List<Channel>? zapList;
  VideoPlayerHdrController? controller;

  /// When the current channel was tuned (the Data pool's "Playing for"; a
  /// live stream's position doesn't advance). Kept across a server retry.
  DateTime? playingSince;

  /// True from the start of [play] until the new controller exists. The
  /// old player's release can take most of a second (4K decoders), and a
  /// pane built meanwhile — the guide mounts a fresh one per channel — saw
  /// no controller and drew its empty black state, then the spinner: the
  /// "black flash before the loading circle" (owner, 2026-10-20). With
  /// this the pane shows the spinner from the first frame.
  bool switching = false;
  Future<void>? initFuture;
  String? error;

  /// Set while a failed live stream is being retried against this
  /// playlist's backup servers (see [PlaylistProfile.backupServers]) —
  /// shown by `PlayerControls` in place of the dead-end playback error it
  /// would otherwise land on immediately. Null whenever no such retry is
  /// in progress, which is the overwhelmingly common case.
  String? reconnectStatus;

  /// True while `PlayerScreen` is actually mounted and showing this
  /// channel fullscreen — set/cleared by that screen's own
  /// `initState`/`dispose` via [setFullscreenActive]. `LiveResumeHint`
  /// reads this both to stop the global hold-Right gesture from firing
  /// again on top of an already-showing fullscreen view, and to hide its
  /// own reminder text while fullscreen is already showing.
  bool isFullscreenActive = false;

  /// A plain field assignment here wouldn't notify `LiveResumeHint`,
  /// which listens via [addListener] — confirmed on real hardware as the
  /// cause of its reminder text still showing the just-left channel's
  /// name for a moment right after entering fullscreen for a *different*
  /// one, since nothing had told it anything changed yet.
  void setFullscreenActive(bool value) {
    if (isFullscreenActive == value) return;
    isFullscreenActive = value;
    notifyListeners();
  }

  /// The live channel a previous session was last playing, surfaced by
  /// `LiveResumeHint` as a pill the user can act on — never auto-played.
  /// Cold launch used to start this playing silently in the background
  /// (`main.dart`'s old `_autoResumeLastChannel`), which was itself enough
  /// extra concurrent work (a decoder opening, an EPG fetch queued up) to
  /// make the whole first 10-20s of a cold start feel sluggish, on top of
  /// catalog loading that was already the slow part. Reported directly.
  /// Set once at launch (see `main.dart`'s `_autoResumeLastChannel`, now
  /// just a lookup) and cleared the moment *any* real [play] call happens
  /// — whether the user actually resumed this exact channel or picked a
  /// different one instead, the pending state has nothing left to offer
  /// once real playback has started.
  Channel? pendingResumeChannel;

  void setPendingResumeChannel(Channel? channel) {
    pendingResumeChannel = channel;
    notifyListeners();
  }

  Timer? _positionSaveTimer;

  /// Ordered episodes the currently playing channel came from (e.g. a
  /// whole series, season-by-season) — set by `SeriesDetailScreen` when an
  /// episode is opened, so playback can auto-advance near the end (see the
  /// position timer in [play]). Left in place across a switch rather than
  /// cleared, so advancing repeatedly through a season/series just keeps
  /// working — a channel that isn't actually in here (a movie, a live
  /// channel picked afterward) simply finds no match in [_nextInQueue] and
  /// this becomes a no-op until the next episode is opened.
  List<Channel>? _upNextQueue;

  /// Turns a queued episode with no URL yet (Archive: its stream is only
  /// looked up when it's about to play) into a playable one — see [play].
  /// Null for queues whose episodes already carry their URL.
  Future<Channel?> Function(Channel)? _upNextResolver;
  bool _resolvingQueued = false;

  void setUpNextQueue(List<Channel>? queue,
      {Future<Channel?> Function(Channel)? resolve}) {
    _upNextQueue = queue;
    _upNextResolver = resolve;
  }

  Channel? get _nextInQueue {
    final queue = _upNextQueue;
    final current = currentChannel;
    if (queue == null || current == null) return null;
    final index = queue.indexWhere((c) => c.id == current.id);
    if (index < 0 || index + 1 >= queue.length) return null;
    return queue[index + 1];
  }

  /// Public alias of [_nextInQueue] — lets the "Up Next" bubble in
  /// [PlayerScreen] show what's coming without duplicating the lookup.
  Channel? get nextUpChannel => _nextInQueue;

  Channel? get _previousInQueue {
    final queue = _upNextQueue;
    final current = currentChannel;
    if (queue == null || current == null) return null;
    final index = queue.indexWhere((c) => c.id == current.id);
    if (index <= 0) return null;
    return queue[index - 1];
  }

  /// Public alias of [_previousInQueue] — lets [PlayerControls]' explicit
  /// "Previous episode" button jump back without duplicating the lookup.
  /// Null (button hidden) for a movie/live channel — anything not actually
  /// in [_upNextQueue] — the same way [nextUpChannel] already behaves.
  Channel? get previousUpChannel => _previousInQueue;

  /// Set when the user dismisses the "Up Next" bubble — reset on every
  /// [play] call, so it only ever suppresses auto-advance for the episode
  /// it was dismissed on, not every episode after it.
  bool _autoAdvanceDismissed = false;

  void dismissAutoAdvance() {
    _autoAdvanceDismissed = true;
    notifyListeners();
  }

  List<Channel> _recentlyPlayed = [];

  /// Most-recently-played items, newest first — the raw material for a
  /// "Continue Watching" row. Filter by id prefix (`xt_vod_`/`xt_ep_`) and
  /// [StorageService.getLastPosition] to find what's actually resumable.
  List<Channel> get recentlyPlayed => _recentlyPlayed;

  bool get isPlayingSomething => currentChannel != null;

  Future<void> init() async {
    final raw = await _storage.readCacheFile(_recentlyPlayedCacheKeyForViewer);
    if (raw == null) return;
    try {
      _recentlyPlayed = (jsonDecode(raw) as List)
          .map((e) => Channel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _recentlyPlayed = [];
    }
  }

  /// Called by `ViewerProfileService.switchTo` after the active viewer has
  /// already changed — re-reads whichever viewer's recently-played list is
  /// now active (same logic as [init], just callable again later) and
  /// re-stamps `isFavorite` on every item against the newly-active
  /// viewer's own favorites, since these [Channel] objects don't live long
  /// enough to go through `PlaylistSession.restampFavorites`' own pass
  /// over its in-memory catalog lists.
  Future<void> reloadForViewer() async {
    await init();
    for (final c in _recentlyPlayed) {
      c.isFavorite = _playlistManager.isChannelFavorited(c.id);
    }
    notifyListeners();
  }

  /// The last [limit] distinct *live* channels watched, newest first — the
  /// TV layout's "History" popup. [recentlyPlayed] also carries movies/
  /// episodes (Continue Watching), so it's filtered here.
  List<Channel> recentLiveChannels({int limit = 10}) {
    final seen = <String>{};
    final result = <Channel>[];
    for (final c in _recentlyPlayed) {
      if (!Channel.isLiveId(c.rawId) || !seen.add(c.id)) continue;
      result.add(c);
      if (result.length >= limit) break;
    }
    return result;
  }

  /// Records [channel] in [recentlyPlayed] without playing it — for the
  /// Windows player, which never goes through [play] (see
  /// `DesktopPlayerScreen`'s doc comment) but should still feed History.
  Future<void> recordWatched(Channel channel) => _recordRecentlyPlayed(channel);

  /// Settings > General history clearing, for the active viewer. [live]
  /// true drops the live channels (the "History" popup); false drops the
  /// movies/episodes (Continue Watching) plus their saved positions.
  Future<void> clearRecentlyPlayed({required bool live}) async {
    _recentlyPlayed.removeWhere((c) => Channel.isLiveId(c.rawId) == live);
    await _storage.writeCacheFile(
      _recentlyPlayedCacheKeyForViewer,
      jsonEncode(_recentlyPlayed.map((c) => c.toJson()).toList()),
    );
    if (!live) await _storage.clearPlaybackPositions();
    notifyListeners();
  }

  Future<void> _recordRecentlyPlayed(Channel channel) async {
    _recentlyPlayed.removeWhere((c) => c.id == channel.id);
    _recentlyPlayed.insert(0, channel);
    if (_recentlyPlayed.length > _maxRecentlyPlayed) {
      _recentlyPlayed = _recentlyPlayed.sublist(0, _maxRecentlyPlayed);
    }
    await _storage.writeCacheFile(
      _recentlyPlayedCacheKeyForViewer,
      jsonEncode(_recentlyPlayed.map((c) => c.toJson()).toList()),
    );
    notifyListeners();
  }

  /// Starts playing [channel]. No-ops if it's already the current channel
  /// (so re-opening the fullscreen view for the channel the mini-player is
  /// already showing doesn't restart it).
  /// Main player as a texture instead of a native (platform) view — the
  /// Settings > General "Compatibility video" switch, on by default for
  /// Android 7 and older (see AppPreferences.compatVideo). Read when a
  /// channel starts, so a change applies from the next channel.
  static bool textureVideo = false;

  static VideoViewType get _viewType =>
      textureVideo ? VideoViewType.textureView : VideoViewType.platformView;

  Future<void> play(Channel channel) async {
    // A queued episode whose stream isn't known yet (Archive Next / auto-
    // advance): resolve it first. Guarded, so the position timer's repeat
    // calls near the end don't start a second lookup.
    if (channel.url.isEmpty) {
      final resolve = _upNextResolver;
      if (resolve == null || _resolvingQueued) return;
      _resolvingQueued = true;
      Channel? resolved;
      try {
        resolved = await resolve(channel);
      } catch (e) {
        debugPrint('PlaybackService: up-next lookup failed: $e');
      } finally {
        _resolvingQueued = false;
      }
      if (resolved == null || resolved.url.isEmpty) {
        error = tr('No playable stream for this title.');
        notifyListeners();
        return;
      }
      channel = resolved;
    }
    // Archive titles and recordings belong to no playlist (see
    // ArchiveService, RecordingService).
    if (!Channel.isArchiveId(channel.rawId) &&
        !Channel.isRecordingId(channel.rawId) &&
        !_playlistManager.isPlaylistEnabled(channel.playlistId)) {
      error = tr(
          'This playlist is disabled on this device — enable it in Settings > Playlist Manager to watch.');
      notifyListeners();
      return;
    }
    if (currentChannel?.id == channel.id && controller != null) return;

    // A recording uses this playlist's only connection: ask first (the
    // app shows the Stop recording / Cancel popup, see main.dart).
    final confirm = confirmOpen;
    if (confirm != null && !await confirm(channel)) return;
    // The channel being recorded plays from the recorder's local tap, so
    // both share one provider connection.
    final openUrl = await openUrlFor?.call(channel) ?? channel.url;

    // Before the teardown: it reads currentChannel for the old title's
    // resume save, so only the flag changes here.
    switching = true;
    await _teardown();
    currentChannel = channel;
    error = null;
    reconnectStatus = null;
    _autoAdvanceDismissed = false;
    // Real playback has started — whatever cold-launch pill this might
    // have been about has nothing left to offer, whether this is the same
    // channel or a different one the user picked instead.
    pendingResumeChannel = null;
    notifyListeners();
    unawaited(_recordRecentlyPlayed(channel));

    // Confirmed on real hardware as the cause of a live channel looking
    // "stuck paused": a live id can carry a *stale* saved position from
    // a completely unrelated past session (the periodic save below used
    // to write one unconditionally, live or not), and seeking a live
    // stream to an old position lands outside its actual sliding DVR
    // window — the player then just sits there buffering/frozen instead
    // of joining live. A live channel has no meaningful "resume point" at
    // all, so this is skipped entirely rather than trying to validate the
    // saved value.
    // rawId, not the composite `id` — Channel.isLiveId documents that it
    // expects the raw, unprefixed id. Confirmed as a real regression:
    // with `id` here this always read false for a real live channel,
    // silently reintroducing the exact "stuck paused" bug described
    // above (a live channel getting treated as if it had a saved VOD
    // resume position).
    final isLive = Channel.isLiveId(channel.rawId);
    final savedPositionMs = isLive ? 0 : _storage.getLastPosition(channel.id);
    final newController = streamController(
      openUrl,
      closedCaptionFile: channel.subtitleUrl != null
          ? _loadCaptions(channel.subtitleUrl!)
          : null,
    );
    controller = newController;
    switching = false;
    playingSince = DateTime.now();

    initFuture = newController.initialize(viewType: _viewType).then((_) async {
      if (savedPositionMs > 0) {
        var seekMs = savedPositionMs;
        // A Trakt/Simkl resume point saved as a fraction (length unknown
        // until now): the real time, then the flag goes.
        if (_storage.isResumeFraction(channel.id)) {
          seekMs = (savedPositionMs /
                  StorageService.resumeFractionScale *
                  newController.value.duration.inMilliseconds)
              .round();
          await _storage.clearResumeFraction(channel.id);
        }
        await newController.seekTo(Duration(milliseconds: seekMs));
      }
      // Surface first, then play. The video view (a platform view) is only
      // built once this controller reads as initialized; playing before
      // that meant the decoder started with no surface and got one
      // mid-stream, which some TV boxes' decoders answer with a restart:
      // one frame, black until the next keyframe, then the picture
      // (Formuler, Timeline guide, owner 2026-10-18).
      if (controller == newController) {
        notifyListeners();
        await SchedulerBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      // Switched channel meanwhile: this controller is already disposed.
      if (controller != newController) return;
      await newController.play();
      // Fire TV/Android TV boxes otherwise sleep the screen mid-stream on
      // idle-input timeout, exactly like they would for any non-video app —
      // there was nothing here telling the OS playback is active.
      unawaited(WakelockPlus.enable());
      // Trakt/Simkl, for Media Hub titles (a no-op otherwise).
      unawaited(WatchTracker.instance.started(channel.id));
      if (isLive) unawaited(_recordRealResolution(newController, channel));
      await _storage.setLastChannelId(channel.id);
      // Live streams report zero/unknown duration — that's fine, it just
      // means StorageService.getWatchedFraction has nothing to compute a
      // percentage from for those, which is the correct outcome (a live
      // channel doesn't have a "% watched").
      final duration = newController.value.duration;
      if (duration > Duration.zero) {
        await _storage.setLastDuration(channel.id, duration.inMilliseconds);
      }
      notifyListeners();
    }).catchError((e) async {
      // A `.ts` that was really HLS: once more as HLS, through [play]
      // (clearing currentChannel lets it past its same-channel guard).
      if (learnHlsHost(channel.url, e) && currentChannel?.id == channel.id) {
        currentChannel = null;
        unawaited(play(channel));
        return;
      }
      // Any other link the player couldn't read: what did it really serve?
      final sniff = await _sniffUnreadable(channel, e);
      if (currentChannel?.id != channel.id) return;
      // A `.strm`-style reply (Jellyfin/Emby debrid libraries): the body
      // is just the real link — play that.
      if (sniff?.kind == 'link') {
        currentChannel = null;
        unawaited(play(channel.copyWith(url: sniff!.text)));
        return;
      }
      if (sniff?.kind == 'hls') {
        _hlsUrls.add(channel.url);
        currentChannel = null;
        unawaited(play(channel));
        return;
      }
      if (await _retryOnBackupServers(channel, e)) return;
      error = sniff == null ? e.toString() : '$e\n${sniff.tag}';
      notifyListeners();
    });

    _positionSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final c = controller;
      final ch = currentChannel;
      // See the doc comment above `isLive` — never persist a "resume
      // point" for a live channel in the first place, not just skip
      // reading one back.
      if (c != null &&
          ch != null &&
          c.value.isInitialized &&
          !Channel.isLiveId(ch.rawId) &&
          // A "being downloaded" clip: no resume point, and no auto-advance
          // (its last 30 s are all of it).
          !ArchiveReadyWatch.instance.isClip(ch.id, c.value.duration)) {
        _storage.setLastPosition(ch.id, c.value.position.inMilliseconds);
        final duration = c.value.duration;
        if (duration > Duration.zero) {
          _storage.setLastDuration(ch.id, duration.inMilliseconds);
          // Auto-advance a season/series near the end.
          final remaining = duration - c.value.position;
          if (remaining <= const Duration(seconds: 30) &&
              !_autoAdvanceDismissed) {
            final next = _nextInQueue;
            if (next != null) unawaited(play(next));
          }
        }
      }
    });

    notifyListeners();
  }

  /// The live list's 4K tag ([Real4kChannels]): what [channel] really
  /// decodes at, read a few seconds in (the size is 0 until the first
  /// frame) and again later (adaptive streams settle on their top
  /// rendition).
  Future<void> _recordRealResolution(
      VideoPlayerHdrController c, Channel channel) async {
    for (final wait in const [Duration(seconds: 4), Duration(seconds: 12)]) {
      await Future<void>.delayed(wait);
      if (controller != c || !c.value.isInitialized) return;
      final size = c.value.size;
      Real4kChannels.record(
          channel.id, size.width.round(), size.height.round());
    }
  }

  /// True while a manual [reloadCurrentChannel] is in flight — guards
  /// against mashing the button mid-reload starting a second overlapping
  /// swap.
  bool _reloadingCurrentChannel = false;

  /// Manually relaunches the current live channel against the exact same
  /// URL — the "Reload" button in [PlayerControls], for a channel that's
  /// silently stalled (frozen frame, no spinner, no error — see
  /// `_checkStall`'s removal from this file in git history for why that
  /// can't be detected and fixed automatically). A fresh connection is a
  /// new "initial open" as far as a reverse-proxying relay is concerned,
  /// which is what actually recovers a stream stuck on a dead connection
  /// the relay never retries mid-session on its own.
  ///
  /// Deliberately manual rather than automatic: an automatic watchdog
  /// tried this and made things worse — relaunching within seconds of a
  /// detected stall raced the relay's own per-user connection limit (the
  /// dead connection wasn't reaped on the relay's side yet, so the new one
  /// got rejected outright). A human noticing and pressing a button
  /// naturally takes longer than that race window, which is the entire
  /// reason this is safe as a manual action when the automatic version
  /// wasn't.
  Future<void> reloadCurrentChannel() async {
    final channel = currentChannel;
    if (channel == null ||
        controller == null ||
        !Channel.isLiveId(channel.rawId) ||
        _reloadingCurrentChannel) {
      return;
    }
    _reloadingCurrentChannel = true;
    reconnectStatus = tr('Reconnecting...');
    error = null;
    notifyListeners();

    final newController =
        streamController(await openUrlFor?.call(channel) ?? channel.url);
    try {
      final future = newController.initialize(viewType: _viewType);
      initFuture = future;
      await future;
      if (currentChannel?.id != channel.id) {
        unawaited(newController.dispose());
        return;
      }
      // Same "build the replacement fully before touching the old one"
      // technique as [_retryOnBackupServers] — disposing the dead
      // controller before the new one is proven just guarantees a black
      // screen if this attempt fails too.
      final previous = controller;
      controller = newController;
      await newController.play();
      unawaited(previous?.dispose());
      reconnectStatus = null;
      error = null;
      notifyListeners();
    } catch (e) {
      unawaited(newController.dispose());
      reconnectStatus = null;
      error = e.toString();
      notifyListeners();
    } finally {
      _reloadingCurrentChannel = false;
    }
  }

  /// Same spacing as `PlaylistSession`'s catalog-side fallback, for the
  /// same reason — don't fire every one of a provider's hostnames at once.
  static const _backupServerDelay = Duration(seconds: 3);

  /// A live stream that failed to open gets retried against this
  /// playlist's configured backup servers before the viewer is shown a
  /// dead end. Returns true if one of them took over, in which case the
  /// caller leaves [error] alone.
  ///
  /// Deliberately narrow about when it even tries:
  /// * live only — a VOD/episode URL is a specific file on a specific
  ///   server, not a channel every mirror of an account carries.
  /// * connection-shaped failures only — see [isDecoderPlaybackError]. No
  ///   number of alternate hostnames makes a decoder that can't handle
  ///   4K HDR HEVC suddenly handle it, and cycling servers for half a
  ///   minute before admitting that is strictly worse than saying so.
  Future<bool> _retryOnBackupServers(Channel channel, Object failure) async {
    if (!Channel.isLiveId(channel.rawId)) return false;
    if (isDecoderPlaybackError(failure.toString())) return false;

    PlaylistProfile? profile;
    for (final p in _playlistManager.profiles) {
      if (p.id == channel.playlistId) {
        profile = p;
        break;
      }
    }
    if (profile == null || !profile.isXtream) return false;

    final currentOrigin = _originOf(channel.url);
    final candidates = profile.serverCandidates
        .where((s) => _originOf(s) != currentOrigin)
        .toList();
    if (candidates.isEmpty) return false;

    for (var i = 0; i < candidates.length; i++) {
      // Still the current channel? A viewer who changed channel (or
      // backed out entirely) while this was retrying has already said
      // what they want, and hijacking that with a late reconnect would
      // be worse than the failure being retried. [reconnectStatus] is
      // deliberately left alone on these bail-outs — whoever took over
      // (`play`/`stop`) has already cleared it, and clearing it here
      // could stomp a status that now belongs to *their* attempt.
      if (currentChannel?.id != channel.id) return false;

      final server = candidates[i];
      reconnectStatus = tr(
          'Trying to reconnect on backup servers ({p}/{candidates})...',
          {'p': i + 1, 'candidates': candidates.length});
      error = null;
      notifyListeners();
      await Future<void>.delayed(_backupServerDelay);
      if (currentChannel?.id != channel.id) return false;

      final retryUrl = _swapOrigin(channel.url, server);
      final retryController = streamController(retryUrl);
      try {
        final future = retryController.initialize(viewType: _viewType);
        initFuture = future;
        await future;
        // Initialising took real time, and the viewer may have moved on
        // during it — handing them a channel they've already left would
        // be worse than the failure this is recovering from. Dispose the
        // one nobody asked for rather than installing it.
        if (currentChannel?.id != channel.id) {
          unawaited(retryController.dispose());
          return false;
        }
        // Only now is the old one safe to drop — disposing before the
        // replacement is proven just guarantees a black screen if this
        // candidate turns out to be down too.
        final previous = controller;
        controller = retryController;
        await retryController.play();
        unawaited(previous?.dispose());
        reconnectStatus = null;
        error = null;
        unawaited(_playlistManager.rememberWorkingServer(profile.id, server));
        notifyListeners();
        return true;
      } catch (_) {
        unawaited(retryController.dispose());
      }
    }

    reconnectStatus = null;
    notifyListeners();
    return false;
  }

  /// The `scheme://host:port` of a URL, with nothing after it — what has
  /// to change to point the same stream at a different server.
  static String _originOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    return uri.hasPort
        ? '${uri.scheme}://${uri.host}:${uri.port}'
        : '${uri.scheme}://${uri.host}';
  }

  /// Rebuilds a stream URL against [server], keeping the whole path
  /// (`/live/user/pass/12345.ts`) as-is — a backup server for the same
  /// account serves the same stream ids under the same credentials, so
  /// only the origin ever differs.
  static String _swapOrigin(String url, String server) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    var base = server.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '$base${uri.path}$query';
  }

  Future<void> stop() async {
    await _teardown();
    currentChannel = null;
    reconnectStatus = null;
    // Otherwise `LiveResumeHint` reads "currentChannel is null" as "show
    // the cold-launch pending-resume pill" unconditionally — reported
    // directly as the pill reappearing inside Multiview (which calls stop()
    // on entry specifically to free the main tab's decode session, but
    // never touches this field since it never calls play() either): a
    // pending channel set once at cold launch and never consumed by a real
    // play() call would otherwise keep surfacing long after it's stale,
    // anywhere else in the app that also calls stop().
    pendingResumeChannel = null;
    notifyListeners();
  }

  /// Once per link: when the player couldn't read [channel]'s stream at
  /// all (ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED), what the link really
  /// served — an HLS playlist (retried as HLS), or a source's error reply
  /// instead of the file (a debrid service's plan limit, an expired
  /// account… — Media Hub TV show, user photo 2026-10-21). Logged without
  /// the link, for Send log.
  Future<StreamSniff?> _sniffUnreadable(Channel channel, Object error) async {
    if (!error
            .toString()
            .contains('ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED') ||
        channel.url.startsWith('/') ||
        !_sniffedUrls.add(channel.url)) {
      return null;
    }
    final sniff = await sniffStream(channel.url);
    final what = Channel.isLiveId(channel.rawId)
        ? 'live'
        : channel.playlistId == ArchiveService.playlistId
            ? 'media hub'
            : 'vod';
    final path = Uri.tryParse(channel.url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    final ext = dot > path.lastIndexOf('/') ? path.substring(dot) : 'none';
    debugPrint('PlaybackService: unreadable $what stream (extension $ext): '
        'served ${sniff?.tag ?? 'nothing (request failed)'}');
    return sniff;
  }

  Future<ClosedCaptionFile> _loadCaptions(String url) async {
    final response = await http.get(Uri.parse(url));
    final content = response.body;
    if (url.toLowerCase().endsWith('.vtt')) {
      return WebVTTCaptionFile(content);
    }
    return SubRipCaptionFile(content);
  }

  Future<void> _teardown() async {
    _positionSaveTimer?.cancel();
    _positionSaveTimer = null;
    // A final exact-position save before disposing — the periodic timer
    // above only runs every 5 seconds, so without this, stopping shortly
    // after the last tick could leave Continue Watching up to 5 seconds
    // stale instead of reflecting exactly where playback actually left
    // off. Same isLive guard as the periodic save: never persist a
    // "resume point" for a live channel in the first place.
    final ch = currentChannel;
    final old = controller;
    if (ch != null &&
        old != null &&
        old.value.isInitialized &&
        !Channel.isLiveId(ch.rawId) &&
        // A Media Hub source's "being downloaded" clip: no resume point
        // and no Trakt/Simkl "watched" for it.
        !ArchiveReadyWatch.instance.ended(ch.id, old.value.duration)) {
      await _storage.setLastPosition(ch.id, old.value.position.inMilliseconds);
      final duration = old.value.duration;
      if (duration > Duration.zero) {
        await _storage.setLastDuration(ch.id, duration.inMilliseconds);
        // Watched / paused at, for Trakt/Simkl (Media Hub titles only).
        unawaited(
            WatchTracker.instance.stopped(ch.id, old.value.position, duration));
      }
    }
    controller = null;
    playingSince = null;
    initFuture = null;
    unawaited(WakelockPlus.disable());
    await old?.dispose();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }
}

/// True for the one failure class that's about this device rather than
/// the stream's source: a `MediaCodecVideoRenderer` giving up on a format
/// (in practice 4K HDR HEVC 10-bit on a box whose decoder claims support
/// it doesn't actually have). Shared deliberately rather than pattern-
/// matched separately in each place that cares — `PlayerControls` uses it
/// to explain the limitation, `PlaybackService` uses it to *not* waste
/// the viewer's time cycling backup servers over something no server
/// change can fix, and those two must agree on what counts.
/// The HTTP status the stream's server answered with, when the native
/// player put one in its error (`... [HTTP 404 Not Found]`, appended by
/// `ExoPlayerEventListener.describeCause` in the vendored plugin) — the
/// usual reason a stream won't start is the provider, not the app.
/// Null for anything else (decoder, network, unknown).
int? httpStatusFromPlaybackError(String raw) {
  final match = RegExp(r'\[HTTP (\d{3})').firstMatch(raw);
  return match == null ? null : int.parse(match.group(1)!);
}

bool isDecoderPlaybackError(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('mediacodecvideorenderer') ||
      lower.contains('[unsupported_video:') ||
      (lower.contains('hevc') && lower.contains('10bit'));
}

/// Hosts whose live `.ts` URLs answer with an HLS playlist instead of a TS
/// stream (a 302 to `….m3u8`: Strong8K behind live.flixnest.app, user
/// photo 2026-10-20). ExoPlayer picks its reader from the URL, so it read
/// the playlist text as video: ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED
/// ("None of the available extractors…"). TiviMate goes by the response.
/// Learned per host on the first such failure, for the app session.
final Set<String> _hlsHosts = {};

/// Links of any shape found to serve an HLS playlist ([sniffStream]),
/// opened as HLS for the app session.
final Set<String> _hlsUrls = {};

/// Links already sniffed after a read failure — one look each.
final Set<String> _sniffedUrls = {};

/// What a stream link really served, from its first bytes ([sniffStream]).
class StreamSniff {
  const StreamSniff(this.kind, {this.text, this.status});

  /// `hls`, `link` (the body is only another http(s) link: a `.strm`
  /// file), `json`, `html`, `text` (a reply, not a video) or `binary`
  /// (media data the player has no reader for).
  final String kind;

  /// The reply's own words: a JSON `error`/`message`/`detail`, a page's
  /// `<title>`, or the start of a plain text (one line, ≤160 chars).
  final String? text;
  final int? status;

  /// Appended to the player's error: shown under "Technical details",
  /// read back by the error screen (`_friendlyPlaybackError`). A `link`'s
  /// address is never shown (it may carry a token).
  String get tag =>
      '[SOURCE_REPLY:$kind${status == null ? '' : ' HTTP $status'}]'
      '${text == null || kind == 'link' ? '' : ' $text'}';
}

/// The first KB of [url] (redirects followed), classified. Null when the
/// request itself failed.
Future<StreamSniff?> sniffStream(String url, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final req = http.Request('GET', Uri.parse(url))
      ..headers['Range'] = 'bytes=0-1023';
    final r = await c.send(req).timeout(const Duration(seconds: 10));
    final bytes = <int>[];
    await for (final chunk in r.stream.timeout(const Duration(seconds: 10))) {
      bytes.addAll(chunk);
      if (bytes.length >= 1024) break;
    }
    final status = r.statusCode >= 400 ? r.statusCode : null;
    final type = (r.headers['content-type'] ?? '').toLowerCase();
    final body = utf8
        .decode(bytes.take(1024).toList(), allowMalformed: true)
        .replaceFirst('\uFEFF', '')
        .trimLeft();
    String oneLine(String s) {
      final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
      return t.length > 160 ? '${t.substring(0, 160)}…' : t;
    }

    if (body.startsWith('#EXTM3U')) return StreamSniff('hls', status: status);
    final link = RegExp(r'^https?://\S+$').firstMatch(body.trim())?.group(0);
    if (link != null && status == null) return StreamSniff('link', text: link);
    if (type.contains('json') || body.startsWith('{') || body.startsWith('[')) {
      final m = RegExp(
              r'"(?:error_message|error|message|detail|msg)"\s*:\s*"([^"]{1,300})"')
          .firstMatch(body);
      return StreamSniff('json',
          text: oneLine(m?.group(1) ?? body), status: status);
    }
    if (type.contains('html') || body.startsWith('<')) {
      final title = RegExp(r'<title[^>]*>([^<]{1,300})', caseSensitive: false)
          .firstMatch(body)
          ?.group(1);
      return StreamSniff('html',
          text: title == null ? null : oneLine(title), status: status);
    }
    final printable = body.runes
        .where((r) => r == 9 || r == 10 || r == 13 || (r >= 32 && r != 0xFFFD))
        .length;
    if (body.isNotEmpty && printable / body.runes.length > 0.95) {
      return StreamSniff('text', text: oneLine(body), status: status);
    }
    return StreamSniff('binary', status: status);
  } catch (e) {
    debugPrint('sniffStream failed: $e');
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// A network controller for [url], told to expect HLS when [url] is a
/// live `.ts` on a host [learnHlsHost] has seen redirect to HLS. VOD files
/// on the same host keep the normal detection.
VideoPlayerHdrController streamController(
  String url, {
  Future<ClosedCaptionFile>? closedCaptionFile,
  VideoPlayerOptions? videoPlayerOptions,
}) {
  // A recording (RecordingService.channelFor): a local .ts file.
  if (url.startsWith('/')) {
    return VideoPlayerHdrController.file(File(url),
        closedCaptionFile: closedCaptionFile,
        videoPlayerOptions: videoPlayerOptions);
  }
  final uri = Uri.parse(url);
  final hls = _hlsUrls.contains(url) ||
      (_hlsHosts.contains(uri.host) && uri.path.toLowerCase().endsWith('.ts'));
  return VideoPlayerHdrController.networkUrl(
    uri,
    formatHint: hls ? VideoFormat.hls : null,
    closedCaptionFile: closedCaptionFile,
    videoPlayerOptions: videoPlayerOptions,
  );
}

/// True (once per host) when [error] says [url]'s live `.ts` was not a TS
/// stream: the caller then retries it, and [streamController] opens that
/// host's channels as HLS from now on.
bool learnHlsHost(String url, Object error) {
  if (!error.toString().contains('ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED')) {
    return false;
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.path.toLowerCase().endsWith('.ts')) return false;
  return _hlsHosts.add(uri.host);
}
