import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/channel.dart';
import 'desktop_audio.dart';
import 'recording_service.dart';
import 'live_stream_format.dart';
import 'vod_buffering.dart';

/// Every media_kit player open in this process: full screen, the mini
/// player, Multiview tiles, automatic trailers.
final Set<Player> _openPlayers = {};

/// A new media_kit [Player] that [disposeAllDesktopPlayers] closes when the
/// app quits. Release it with [disposeDesktopPlayer], never `dispose()`.
Player newDesktopPlayer() {
  final player = Player();
  _openPlayers.add(player);
  _IosBackgroundVideo.ensure();
  return player;
}

/// iPhone / iPad: media_kit draws video with OpenGL ES, which iOS forbids
/// in the background. Home or the lock screen froze the video output, the
/// sound stopped with it (mpv waits for video), and back in the app a 4K
/// remux stuttered until restarted: the hardware decoder had been dropped
/// (owner's iPhone 8, 2026-11-09). Off screen, every open player turns its
/// video track off and keeps the sound going (UIBackgroundModes audio);
/// back on screen the same track comes back with a fresh decoder (mpv
/// refreshes the picture at the current position).
class _IosBackgroundVideo with WidgetsBindingObserver {
  static _IosBackgroundVideo? _instance;

  static void ensure() {
    if (!Platform.isIOS || _instance != null) return;
    WidgetsBinding.instance.addObserver(_instance = _IosBackgroundVideo());
  }

  /// Players whose video is off for the background, with the track to
  /// give back.
  final Map<Player, VideoTrack> _parked = {};

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _park();
      case AppLifecycleState.resumed:
        _restore();
      default:
        break;
    }
  }

  void _park() {
    for (final player in _openPlayers) {
      if (_parked.containsKey(player)) continue;
      final track = player.state.track.video;
      if (track.id == 'no') continue;
      _parked[player] = track;
      unawaited(player
          .setVideoTrack(VideoTrack.no())
          .catchError((Object e) => debugPrint('IosBackground: park $e')));
    }
    if (_parked.isNotEmpty) {
      debugPrint('IosBackground: video off for ${_parked.length} player(s)');
    }
  }

  void _restore() {
    if (_parked.isEmpty) return;
    final parked = Map.of(_parked);
    _parked.clear();
    for (final MapEntry(key: player, value: track) in parked.entries) {
      // Closed while the app was away.
      if (!_openPlayers.contains(player)) continue;
      unawaited(player
          .setVideoTrack(track)
          .catchError((Object e) => debugPrint('IosBackground: restore $e')));
    }
    debugPrint('IosBackground: video back for ${parked.length} player(s)');
  }
}

/// Every player streaming from the network, by provider account: a
/// download waits while the app uses its account's last connection and
/// slows down while anything plays ([RecordingService.multiviewChanged]
/// takes the whole list on Windows).
final Map<Player, String> _streamAccounts = {};

void _reportStreams() {
  if (!RecordingService.downloadsSupported) return;
  RecordingService.instance.multiviewChanged(_streamAccounts.values.toList());
}

/// Disposes [player] once: a screen closing after quitting already
/// disposed it does nothing (media_kit throws on a second dispose).
Future<void> disposeDesktopPlayer(Player player) {
  if (_streamAccounts.remove(player) != null) _reportStreams();
  if (!_openPlayers.remove(player)) return Future.value();
  return player.dispose();
}

/// Quitting (AppExit.beforeQuit): stops and disposes every open player
/// before the window goes away. mpv's event thread wakes the Dart side
/// through a callback that lives in the Dart VM; closing the window with
/// players still open shut the VM down under it, and mpv's next wakeup
/// jumped into freed memory: a segfault in libmpv on every close (Steam
/// Machine, Linux, 2026-11-08). Disposing a player clears that callback
/// and frees its video output first. Each player gets 2 s, so a stuck one
/// never keeps the window open.
Future<void> disposeAllDesktopPlayers() async {
  final players = _openPlayers.toList();
  if (players.isEmpty) return;
  debugPrint('AppExit: closing ${players.length} player(s)');
  await Future.wait([
    for (final player in players)
      disposeDesktopPlayer(player)
          .timeout(const Duration(seconds: 2))
          .catchError((Object e) {
        debugPrint('AppExit: player close failed (${e.runtimeType})');
      }),
  ]);
}

/// What the Windows player says it is. mpv's own "libmpv" is on many IPTV
/// panels' blocked list for live streams: a Windows user had black live TV
/// (no picture, no sound, no error) while VOD, Media Hub and the same
/// playlist on their phone all worked (LOG-HCLSJZ, 2026-11-02). Android's
/// player identifies as Dalvik, which panels accept.
const kDesktopStreamUserAgent =
    'Dalvik/2.1.0 (Linux; U; Android 11; VesperTV Windows)';

/// The shared mpv setup for every Windows stream player (full screen, mini
/// player, Multiview): reconnect tuning, the User-Agent above, mpv errors
/// into Send log (a refused stream used to fail silently), and Settings >
/// Playback > Audio ([DesktopAudio]; never passthrough in Multiview).
void configureDesktopStreamPlayer(Player player, String tag) {
  final native = player.platform as NativePlayer;
  DesktopAudio.track(player, multiview: tag == 'multiview');
  // Software video: decode on the CPU too (no GPU surfaces at all).
  if (desktopSoftwareVideo) native.setProperty('hwdec', 'no');
  // See DesktopPlayerScreen.initState for the reconnect story.
  // rw_timeout 30 s (was 15): some IPTV servers send live .ts in bursts
  // with 3-9.5 s gaps on a healthy line; Android's 8 s timeout reconnected
  // on them and replayed the start burst (8125351). Same 30 s here.
  native.setProperty('demuxer-lavf-o',
      'reconnect=1,reconnect_at_eof=1,reconnect_streamed=1,reconnect_delay_max=5,rw_timeout=30000000');
  // mpv's network-timeout (media_kit sets 5 s) becomes ffmpeg's tcp
  // `timeout`, which overrides rw_timeout above: those bursty servers timed
  // out after 5 s ("tcp: ffurl_read returned" -60 on macOS, -138 on
  // Windows), then reconnected or ended every 30-40 s. Same 30 s.
  native.setProperty('network-timeout', '30');
  // media_kit turns on cache-on-disk; inside the macOS sandbox mpv can't
  // create its cache folder ("Failed to create file cache"). iPhone apps are
  // sandboxed the same way. The demuxer cache stays in memory
  // (demuxer-max-bytes).
  if (Platform.isMacOS || Platform.isIOS) {
    native.setProperty('cache-on-disk', 'no');
  }
  native.setProperty('user-agent', kDesktopStreamUserAgent);
  // Broadcast closed captions (EIA-608 inside the video, like Android's CC
  // track): listed in the Subtitles menu from the start. mpv marks the
  // track default and would show it by itself; it stays off until the
  // viewer picks it ([desktopCaptionsWanted]), then follows them on zaps.
  native.setProperty('sub-create-cc-track', 'yes');
  player.stream.track.listen((t) {
    if (isClosedCaptionTrack(t.subtitle) &&
        desktopCaptionsWanted[player] != true) {
      unawaited(player.setSubtitleTrack(SubtitleTrack.no()));
    }
  });
  player.stream.error.listen((e) => debugPrint('DesktopPlayer[$tag]: $e'));
  player.stream.log.listen((log) {
    if (log.level == 'error' || log.level == 'fatal') {
      debugPrint('DesktopPlayer[$tag] mpv ${log.prefix}: ${log.text.trim()}');
    }
  });
}

/// The viewer picked the closed captions track on this player (set by the
/// Subtitles menu and Vesper's subtitle command).
final desktopCaptionsWanted = Expando<bool>('desktopCaptionsWanted');

/// mpv's closed captions track ([configureDesktopStreamPlayer]).
bool isClosedCaptionTrack(SubtitleTrack? t) =>
    t?.codec?.toLowerCase() == 'eia_608';

/// Shows [track] (null = off) and remembers whether captions were wanted.
Future<void> setDesktopSubtitle(Player player, SubtitleTrack? track) {
  desktopCaptionsWanted[player] = isClosedCaptionTrack(track);
  return player.setSubtitleTrack(track ?? SubtitleTrack.no());
}

/// Opens [channel] on [player] the way every Windows player does: the
/// playlist's HLS stream format ([LiveStreamFormat]), and for live TV the
/// Settings > Playback > Live buffer (mpv waits until that much is cached
/// before it starts; Gradual has no mpv equivalent and plays as Off).
Future<void> openDesktopStream(Player player, Channel channel,
    {Duration? start, bool play = true}) async {
  final native = player.platform as NativePlayer;
  // A download plays from its file (the network folder's through
  // Windows' own share path); anything else from the network first asks
  // a download on the same account to give its connection back.
  final downloaded = Channel.isRecordingId(channel.rawId);
  var url = channel.url;
  if (downloaded) {
    url = await RecordingService.instance.playbackUrl(channel) ?? url;
    if (_streamAccounts.remove(player) != null) _reportStreams();
  } else {
    await RecordingService.instance.yieldConnection(channel);
    _streamAccounts[player] = channel.playlistId;
    _reportStreams();
  }
  final live = channel.isLive && !channel.transientPlayback;
  final ms = live ? VodBuffering.liveBufferMs : 0;
  await native.setProperty('cache-pause-initial', ms > 0 ? 'yes' : 'no');
  if (ms > 0) {
    await native.setProperty(
        'cache-pause-wait', (ms / 1000).toStringAsFixed(1));
  }
  await player.open(
      Media(live ? LiveStreamFormat.urlFor(url) : url,
          start: start,
          httpHeaders:
              channel.httpHeaders.isEmpty ? null : channel.httpHeaders),
      play: play);
}

/// Settings > Playback > Software video (Windows; StorageService
/// getDesktopSoftwareVideo, set at startup and on change). For PCs where the
/// GPU video path stays black while the stream plays (decoder reports the
/// picture, screen shows nothing): some HDR / two-GPU / driver setups.
/// Applies to players created after the change.
bool desktopSoftwareVideo = false;

/// Every Windows player's [VideoController] (full screen, mini player,
/// Multiview, trailers).
VideoController desktopVideoController(Player player) => VideoController(player,
    configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !desktopSoftwareVideo));
