import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_live_zap_test.dart' show ZapStorage, ZapPlaylist, ZapController;

/// Player > Sources on a live channel plays the picked copy (or Dispatcharr
/// stream) under the same channel id. The same-channel guard swallowed it
/// from +813 to +836: "source picked" in the log and nothing else (owner
/// photo, TVA Montreal, 2026-11-18).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]));

  Channel live(String playlist, String url, String name) => Channel(
      id: '$playlist::tva',
      rawId: 'tva',
      playlistId: playlist,
      name: name,
      group: 'QC',
      url: url);

  test('a picked live source plays; the guide replaying the channel does not',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = ZapStorage();
    await storage.init();
    final playlist = ZapPlaylist(storage);
    final playback = PlaybackService(storage, playlist);
    final playing = live('p1', 'http://blcktv/live/1.ts', 'QC: TVA MONTREAL');
    playback.currentChannel = playing;
    playback.controller = ZapController();
    final opened = <String>[];
    PlaybackService.confirmOpen = (c) async {
      opened.add(c.url);
      return false;
    };
    try {
      // The guide's OK on the playing channel: nothing restarts.
      await playback.play(playing);
      await playback.play(playing.copyWith(url: 'http://elsewhere/1.ts'));
      expect(opened, isEmpty);

      // Sources > another playlist's copy: it opens, same channel id.
      await playback.playLiveSource(
          live('p2', 'http://trex/live/9.ts', 'CA| TVA MONTREAL HD'));
      expect(opened, ['http://trex/live/9.ts']);

      // Picking the stream already playing does nothing.
      await playback.playLiveSource(playing);
      expect(opened, hasLength(1));
    } finally {
      PlaybackService.confirmOpen = null;
      playback.dispose();
      playlist.dispose();
    }
  });
}
