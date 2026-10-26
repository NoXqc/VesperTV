import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_live_zap_test.dart' show ZapStorage, ZapPlaylist, ZapController;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // dispose releases the screen wake lock even when no switch was confirmed.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]));

  test('Media Hub replacement file bypasses the same-title playback guard',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = ZapStorage();
    await storage.init();
    final playlist = ZapPlaylist(storage);
    final playback = PlaybackService(storage, playlist);
    final channel = Channel(
        id: 'archive::arc_vod_title',
        rawId: 'arc_vod_title',
        playlistId: 'archive',
        name: 'Movie',
        group: '',
        url: 'https://example.com/a');
    playback.currentChannel = channel;
    playback.controller = ZapController();
    var opens = 0;
    PlaybackService.confirmOpen = (_) async {
      opens++;
      return false;
    };
    try {
      await playback.play(channel);
      expect(opens, 0);
      await playback.play(channel.copyWith(url: 'https://example.com/b'));
      expect(opens, 1);
      // No confirmed switch: the existing stream remains selected.
      expect(playback.currentChannel, same(channel));
    } finally {
      PlaybackService.confirmOpen = null;
      playback.dispose();
      playlist.dispose();
    }
  });
}
