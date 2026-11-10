import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/archive_playback_sources.dart';
import 'package:nox_iptv/services/desktop_player_control.dart';

/// A full-screen player for the registry (never asked for its mpv player).
class _Fake extends DesktopPlayerControl {
  _Fake(this.name);
  final String name;
  @override
  Channel get channel => Channel(
      id: 'p::$name',
      rawId: name,
      playlistId: 'p',
      name: name,
      group: 'g',
      url: 'u');
  @override
  Player get player => throw UnimplementedError();
  @override
  bool get fullScreen => true;
  @override
  bool get inCatchup => false;
  @override
  Channel? get nextEpisode => null;
  @override
  Channel? get previousEpisode => null;
  @override
  ArchivePlaybackSources? get sources => null;
  @override
  Future<void> stop() async {}
  @override
  Future<void> seekBy(Duration amount) async {}
  @override
  Future<bool> catchupFrom(DateTime at) async => false;
  @override
  Future<void> backToLive() async {}
  @override
  Future<void> playOther(Channel channel) async {}
  @override
  Future<void> replaceStream(Channel replacement) async {}
}

void main() {
  test('Vesper AI drives the newest full-screen player, else nothing', () {
    expect(DesktopPlayerControl.current, isNull);
    final a = _Fake('a'), b = _Fake('b');
    DesktopPlayerControl.register(a);
    DesktopPlayerControl.register(b);
    expect(DesktopPlayerControl.current, same(b));
    DesktopPlayerControl.unregister(b);
    expect(DesktopPlayerControl.current, same(a));
    expect(DesktopPlayerControl.current!.playingId, 'p::a');
    DesktopPlayerControl.unregister(a);
    expect(DesktopPlayerControl.current, isNull);
  });
}
