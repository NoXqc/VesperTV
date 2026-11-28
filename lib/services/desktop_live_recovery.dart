import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show AppLifecycleState;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:media_kit/media_kit.dart';

import '../l10n/l10n.dart';
import '../models/channel.dart';
import '../models/playlist_profile.dart';
import 'channel_copy_fallback.dart';
import 'desktop_audio.dart';
import 'desktop_stream_setup.dart';
import 'live_backup_servers.dart';
import 'mpv_freeze_guard.dart';

/// Windows live TV recovery, one per mpv [Player] ([of]), so it follows the
/// stream when full screen hands it to the mini player and back.
///
/// Before (1.0.45): a live stream the provider closed was reopened at once,
/// with no wait, no retry and no logging. A provider still closing the old
/// connection refused the new one, and the picture stayed black (LOG-FZXE2W,
/// 2026-11-03: two "completed" reopens, no video after). A stream handed to
/// the mini player had no recovery at all. Android has had waits, retries and
/// copy failover since 1.0.47 / 1.0.54.
///
/// Now: ended / error / stuck buffering / frozen picture -> "Reconnecting..."
/// -> wait (2, 4, 8, 15, 30 s) -> reopen. Tries 1 and 2 reopen the same
/// address; from the third, the playlist's other servers one by one
/// ([BackupServerWalk]: the server that last worked, the primary, the
/// backups, like Android's `PlaybackService._retryOnBackupServers`, 3 s
/// apart; one that plays is remembered for the playlist, [rememberServer]),
/// then the channel's other copies (4K -> FHD -> HD, Settings' automatic
/// failover) when there are any, then its own address again. Success =
/// playback moving again; after 8 tries the message says so and a retry
/// still runs every 30 s while the channel stays on screen.
///
/// While a live channel is watched, [MpvFreezeGuard] (Android's
/// LiveFreezeGuard rules on mpv's properties) catches a picture that stops
/// without an error or buffering: Pause/Play, then this reopen.
class DesktopLiveRecovery {
  DesktopLiveRecovery._(this.player) {
    _subs = [
      player.stream.completed.listen((done) {
        if (done) _trouble('ended');
      }),
      player.stream.error.listen((_) => _onError()),
      player.stream.buffering.listen(_onBuffering),
      player.stream.position.listen(_onPosition),
    ];
  }

  static final _byPlayer = Expando<DesktopLiveRecovery>();

  /// The recovery of [player] (created on first use).
  static DesktopLiveRecovery of(Player player) =>
      _byPlayer[player] ??= DesktopLiveRecovery._(player);

  /// Disposes [player] and its recovery (use instead of `player.dispose()`).
  static void disposePlayer(Player? player) {
    if (player == null) return;
    _byPlayer[player]?.dispose();
    _byPlayer[player] = null;
    DesktopAudio.forget(player);
    unawaited(disposeDesktopPlayer(player));
  }

  /// Set by main.dart on Windows: a live channel's other copies, best
  /// first, or empty when automatic failover is off.
  static List<Channel> Function(Channel channel) copiesOf = (_) => const [];

  /// Set by main.dart: the playlist a channel comes from (its backup
  /// servers), null = unknown.
  static PlaylistProfile? Function(String playlistId) playlistOf = (_) => null;

  /// Set by main.dart: a server that played the channel again, tried first
  /// next time (`PlaylistManager.rememberWorkingServer`, as on Android).
  static void Function(String playlistId, String server) rememberServer =
      (_, __) {};

  final Player player;
  late final List<StreamSubscription<Object?>> _subs;

  /// "Reconnecting…" while a reconnect is pending or running; null = fine.
  final status = ValueNotifier<String?>(null);

  /// The channel on screen (the copy playing may differ), null = not live.
  Channel? _channel;
  Channel? _playing;
  final _fallback = ChannelCopyFallback();
  final _servers = BackupServerWalk();

  /// The server the last reopen tried, null = it wasn't another server.
  String? _server;
  bool _noServersNoted = false;
  int _attempt = 0;
  Timer? _retry;
  Timer? _bufferingTimer;
  Timer? _errorCheck;
  DateTime? _reopenedAt;
  DateTime? _troubleAt;
  bool _recovering = false;

  /// Opens of a live stream on this player (watch + reopens): the freeze
  /// guard starts over on each.
  int _opens = 0;

  late final _freeze = MpvFreezeGuard(
    target: _freezeTarget,
    read: _readProperty,
    nudge: _nudge,
    reload: () async => _trouble('frozen'),
  );

  static const _waits = [2, 4, 8, 15, 30];
  static const _giveUpAfter = 8;

  /// Between two backup servers: Android's `_backupServerDelay` (don't
  /// fire every hostname of a provider at once).
  static const serverWaitSeconds = 3;

  /// iPhone: the first reopen after a live channel ended goes at once. An
  /// HLS channel there ends on one failed playlist reload (see
  /// desktopLavfOptions); with the 2 s wait each cut was 3.4 s of black,
  /// every 20-30 s (LOG-SKRVK2, 2026-11-20). The wait is for Windows: a
  /// provider still closing the old .ts connection refused the new one
  /// (LOG-FZXE2W). Later tries keep the waits.
  static bool quickFirstReopenAfterEnd = Platform.isIOS;

  /// Seconds before reconnect [attempt] (1 = first) for [reason]; [server]:
  /// that reconnect tries another server of the playlist.
  @visibleForTesting
  static int waitFor(String reason, int attempt,
      {required bool quick, bool server = false}) {
    if (server) return serverWaitSeconds;
    if (quick && attempt == 1 && reason == 'ended') return 0;
    return _waits[(attempt - 1).clamp(0, _waits.length - 1)];
  }

  /// What reconnect [attempt] opens: [playing] (else [channel]) for tries 1
  /// and 2; from the third the playlist's other servers one per try
  /// ([servers], [channel]'s own path on that server, as Android swaps
  /// it), then [channel]'s own address with its other copies first
  /// ([nextCopy], given the address that failed), then that address again.
  /// [lastWasServer]: the previous try was one of those servers.
  @visibleForTesting
  static ({Channel target, String? server, Channel? copy}) pickTarget({
    required Channel channel,
    required Channel? playing,
    required int attempt,
    required BackupServerWalk servers,
    required PlaylistProfile? profile,
    required bool lastWasServer,
    required Channel? Function(Channel failed) nextCopy,
  }) {
    var target = playing ?? channel;
    if (attempt < 3) return (target: target, server: null, copy: null);
    final server = servers.next(profile, target.url);
    if (server != null) {
      return (
        target: channel.copyWith(
            url: LiveBackupServers.swapOrigin(channel.url, server)),
        server: server,
        copy: null,
      );
    }
    // Every other server tried (or none): back on the channel's own
    // address, its other copies first.
    if (lastWasServer) target = channel;
    final copy = nextCopy(target);
    if (copy != null) {
      return (
        target: channel.copyWith(url: copy.url, httpHeaders: copy.httpHeaders),
        server: null,
        copy: copy,
      );
    }
    return (target: target, server: null, copy: null);
  }

  /// [server]'s place in [profile] for Send log, never its address.
  @visibleForTesting
  static String serverRole(PlaylistProfile? profile, String server) {
    if (profile == null) return 'unknown';
    final backup = profile.backupServers.indexOf(server);
    final role = server == profile.xtreamServer
        ? 'primary'
        : backup >= 0
            ? 'backup ${backup + 1} of ${profile.backupServers.length}'
            : 'other';
    return server == profile.lastWorkingServer ? '$role, last worked' : role;
  }

  /// Call after opening [channel] (live) on [player]; null for a movie,
  /// an episode or nothing.
  void watch(Channel? channel) {
    _retry?.cancel();
    _bufferingTimer?.cancel();
    _errorCheck?.cancel();
    _attempt = 0;
    _recovering = false;
    _channel = channel != null && channel.isLive && !channel.transientPlayback
        ? channel
        : null;
    _playing = _channel;
    _servers.reset();
    _server = null;
    _noServersNoted = false;
    _troubleAt = null;
    _opens++;
    status.value = null;
    if (_channel != null) {
      _freeze.start();
    } else {
      _freeze.stop();
    }
  }

  void stop() => watch(null);

  void _onBuffering(bool buffering) {
    _bufferingTimer?.cancel();
    if (!buffering || _channel == null || _recovering) return;
    // Stuck for 25 s: mpv's own reconnect gave up without saying so.
    _bufferingTimer = Timer(const Duration(seconds: 25), () {
      if (player.state.buffering) _trouble('stalled');
    });
  }

  /// mpv reports many errors it gets past by itself: "Cannot seek in this
  /// stream" on every live open, a TCP read error its own reconnect
  /// handles, a corrupt frame. Reopening on each one showed
  /// "Reconnecting..." every 30-40 s on a stream that was still playing
  /// (macOS, 2026-11-07). Reopen only when playback hasn't moved 6 s later.
  void _onError() {
    if (_channel == null || _recovering || (_errorCheck?.isActive ?? false)) {
      return;
    }
    final at = player.state.position;
    _errorCheck = Timer(const Duration(seconds: 6), () {
      if (_channel == null || _recovering) return;
      if (player.state.position > at && !player.state.completed) return;
      _trouble('error');
    });
  }

  void _onPosition(Duration position) {
    if (!_recovering || _reopenedAt == null) return;
    if (position < const Duration(seconds: 1)) return;
    // Playing again.
    final took = DateTime.now().difference(_reopenedAt!).inMilliseconds;
    final since = _troubleAt == null
        ? ''
        : ', ${_secondsSinceTrouble()} s since it stopped';
    debugPrint('DesktopLive: playing again after try $_attempt '
        '(${(took / 1000).toStringAsFixed(1)} s$since)');
    final channel = _channel;
    final server = _server;
    if (channel != null && server != null) {
      final profile = playlistOf(channel.playlistId);
      debugPrint('BackupServer: "${channel.name}" plays on server '
          '${_servers.tried} of ${_servers.total} '
          '(${serverRole(profile, server)}) after try $_attempt, '
          'tried first next time for this playlist');
      rememberServer(channel.playlistId, server);
    }
    _server = null;
    _servers.reset();
    _recovering = false;
    _attempt = 0;
    _troubleAt = null;
    _retry?.cancel();
    status.value = null;
  }

  void _trouble(String reason) {
    // A reconnect is starting: a pending error check would compare the
    // reopened stream's position (a few s) with the old one and reconnect a
    // stream that just recovered.
    _errorCheck?.cancel();
    final channel = _channel;
    if (channel == null || (_retry?.isActive ?? false)) return;
    _attempt++;
    _recovering = true;
    _troubleAt ??= DateTime.now();
    final failed = (_playing ?? channel).url;
    final profile = playlistOf(channel.playlistId);
    final toServer = _attempt >= 3 && _servers.hasNext(profile, failed);
    final wait = waitFor(reason, _attempt,
        quick: quickFirstReopenAfterEnd, server: toServer);
    // How long it played and what mpv thought its length was: a live HLS
    // list the server ends (#EXT-X-ENDLIST) has a length and ends right at
    // it, a failed playlist reload ends anywhere (HLS warning lines before).
    final played = reason == 'ended'
        ? ' after ${_seconds(player.state.position)} s'
            ' (length ${_seconds(player.state.duration)} s)'
        : '';
    final on = _server == null
        ? ''
        : ' on server ${_servers.tried} of ${_servers.total}';
    final next = _attempt < 3
        ? 'the same address'
        : toServer
            ? 'server ${_servers.tried + 1} of ${_servers.total}'
            : 'another copy or its own address';
    debugPrint('DesktopLive: $reason$played$on, reconnect $_attempt in '
        '$wait s (next: $next)');
    status.value = _attempt > _giveUpAfter
        ? tr('The channel stopped. Still trying to reconnect...')
        : tr('Reconnecting...');
    _retry = Timer(Duration(seconds: wait), () => _reopen(channel));
  }

  Future<void> _reopen(Channel channel) async {
    if (_channel?.id != channel.id) return;
    final profile = playlistOf(channel.playlistId);
    final lastWasServer = _server != null;
    final pick = pickTarget(
      channel: channel,
      playing: _playing,
      attempt: _attempt,
      servers: _servers,
      profile: profile,
      lastWasServer: lastWasServer,
      nextCopy: (failed) => _fallback.next(failed, copiesOf(channel)),
    );
    final server = pick.server;
    _server = server;
    if (server != null) {
      debugPrint('BackupServer: try $_attempt on "${channel.name}": server '
          '${_servers.tried} of ${_servers.total} '
          '(${serverRole(profile, server)})');
      status.value = tr(
          'Trying to reconnect on backup servers ({p}/{candidates})...',
          {'p': _servers.tried, 'candidates': _servers.total});
    } else if (_attempt >= 3) {
      if (lastWasServer) {
        debugPrint('BackupServer: none of the ${_servers.total} other '
            'server(s) played "${channel.name}", back to its own address');
      } else if (_servers.total == 0 && !_noServersNoted) {
        _noServersNoted = true;
        debugPrint('BackupServer: no other server for "${channel.name}" '
            '(${profile == null ? 'playlist not found' : !profile.isXtream ? 'M3U playlist' : 'no backup servers added'})');
      }
      final copy = pick.copy;
      if (copy != null) {
        debugPrint('DesktopLive: trying another copy (${copy.name})');
        status.value = tr('Trying another copy: {name}', {'name': copy.name});
      }
    }
    _playing = pick.target;
    _reopenedAt = null;
    _opens++;
    final openedAt = DateTime.now();
    final what = server != null
        ? 'server ${_servers.tried} of ${_servers.total}'
        : pick.copy != null
            ? 'copy ${pick.copy!.name}'
            : _attempt >= 3 && pick.target.url == channel.url
                ? 'its own address'
                : 'the same address';
    try {
      await openDesktopStream(player, pick.target);
      debugPrint('DesktopLive: try $_attempt opened ($what) in '
          '${DateTime.now().difference(openedAt).inMilliseconds} ms, '
          'waiting up to 15 s for the picture');
    } catch (e) {
      debugPrint('DesktopLive: reopen failed (${e.runtimeType}), try '
          '$_attempt ($what)');
    }
    // Positions from before this open don't count as playing again.
    _reopenedAt = DateTime.now();
    // No movement within 15 s = another try.
    _retry = Timer(const Duration(seconds: 15), () {
      if (_recovering && _channel?.id == channel.id) _trouble('no video');
    });
  }

  /// The freeze guard's view: the live stream while it isn't reconnecting
  /// and the app is on screen (iPhone / Apple TV park the video in the
  /// background; desktop windows keep playing behind other windows).
  MpvFreezeTarget? _freezeTarget() {
    final channel = _channel;
    if (channel == null || _recovering) return null;
    final life = SchedulerBinding.instance.lifecycleState;
    if (life == AppLifecycleState.hidden || life == AppLifecycleState.paused) {
      return null;
    }
    return (
      key: '$_opens',
      label: channel.name,
      playing: player.state.playing,
      buffering: player.state.buffering,
    );
  }

  Future<String> _readProperty(String name) async {
    final native = player.platform;
    if (native is! NativePlayer) return '';
    return native.getProperty(name);
  }

  /// Pause/Play, as Android's LiveFreezeGuard nudge.
  Future<void> _nudge() async {
    await player.pause();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_channel == null || _recovering) {
      debugPrint('LiveFreeze: no Play after the pause '
          '(channel left or reconnecting)');
      return;
    }
    await player.play();
  }

  String _secondsSinceTrouble() =>
      (DateTime.now().difference(_troubleAt!).inMilliseconds / 1000)
          .toStringAsFixed(1);

  static String _seconds(Duration d) =>
      (d.inMilliseconds / 1000).toStringAsFixed(1);

  void dispose() {
    _freeze.stop();
    _retry?.cancel();
    _bufferingTimer?.cancel();
    _errorCheck?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    status.dispose();
  }
}
