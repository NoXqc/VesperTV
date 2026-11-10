import 'package:media_kit/media_kit.dart';

import '../models/channel.dart';
import 'archive_playback_sources.dart';
import 'desktop_mini_player.dart';

/// What Vesper AI drives on a computer, where the player is media_kit and
/// not `PlaybackService` (owner, 2026-11-10: Windows up to par with
/// Android). The full-screen [DesktopPlayerScreen] registers itself while
/// it is open; without one, the mini player ([DesktopMiniPlayer]) is used.
abstract class DesktopPlayerControl {
  /// Full-screen players, most recent last (normally one).
  static final List<DesktopPlayerControl> _screens = [];

  static void register(DesktopPlayerControl c) {
    _screens.remove(c);
    _screens.add(c);
  }

  static void unregister(DesktopPlayerControl c) => _screens.remove(c);

  /// The player the AI talks to: full screen, else the mini player, else
  /// null (nothing plays).
  static DesktopPlayerControl? get current {
    if (_screens.isNotEmpty) return _screens.last;
    final mini = DesktopMiniPlayer.instance;
    return mini.channel.value != null && mini.player != null
        ? _MiniControl(mini)
        : null;
  }

  /// What plays: the live channel during catch-up.
  Channel get channel;
  Player get player;
  bool get fullScreen;
  bool get inCatchup;

  /// The show's next / previous episode (the page's queue), if any.
  Channel? get nextEpisode;
  Channel? get previousEpisode;

  /// The Media Hub sources of what plays (null for IPTV).
  ArchivePlaybackSources? get sources;

  /// The id of the title playing (an episode's own id).
  String get playingId => channel.id;

  Future<void> pause() => player.pause();
  Future<void> resume() => player.play();
  Future<void> stop();

  /// Same rules as the player's own buttons: ±seconds on a file, inside
  /// the programme during catch-up.
  Future<void> seekBy(Duration amount);

  /// Catch-up of the live channel from [at] (full screen only).
  Future<bool> catchupFrom(DateTime at);
  Future<void> backToLive();

  /// Another channel or episode in this same player.
  Future<void> playOther(Channel channel);

  /// A Media Hub stream of what plays, at the same position.
  Future<void> replaceStream(Channel replacement);
}

/// The mini player: live channels only, no catch-up.
class _MiniControl extends DesktopPlayerControl {
  _MiniControl(this.mini);
  final DesktopMiniPlayer mini;

  @override
  Channel get channel => mini.channel.value!;
  @override
  Player get player => mini.player!;
  @override
  bool get fullScreen => false;
  @override
  bool get inCatchup => false;
  @override
  Channel? get nextEpisode => null;
  @override
  Channel? get previousEpisode => null;
  @override
  ArchivePlaybackSources? get sources => null;

  @override
  Future<void> stop() async => mini.clear();

  @override
  Future<void> seekBy(Duration amount) async {
    final target = player.state.position + amount;
    await player.seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  Future<bool> catchupFrom(DateTime at) async => false;

  @override
  Future<void> backToLive() async {}

  @override
  Future<void> playOther(Channel channel) async => mini.play(channel);

  @override
  Future<void> replaceStream(Channel replacement) async =>
      mini.play(replacement);
}
