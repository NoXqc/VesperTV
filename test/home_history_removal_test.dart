import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wide_guide_back_test.dart' show GuidePlaylist;

class _Storage extends StorageService {
  final files = <String, String>{};
  @override
  Future<void> writeCacheFile(String name, String content) async =>
      files[name] = content;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Home removes only the chosen title or series, keeps progress and persists history',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    SharedPreferences.setMockInitialValues({});
    final storage = _Storage();
    await storage.init();
    final playlist = GuidePlaylist(storage);
    final playback = PlaybackService(storage, playlist);
    addTearDown(playlist.dispose);
    addTearDown(playback.dispose);
    Channel channel(String id, {int? series}) => Channel(
        id: 'p::$id',
        rawId: id,
        playlistId: 'p',
        name: id,
        group: 'Test',
        url: 'https://example.com/$id',
        seriesId: series);
    final one = channel('xt_ep_1', series: 42),
        two = channel('xt_ep_2', series: 42);
    final other = channel('xt_ep_3', series: 99), live = channel('live');
    for (final c in [one, two, other, live]) {
      await playback.recordWatched(c);
    }
    await storage.setLastPosition(one.id, 120000);
    await playback.removeFromHistory(one);
    expect(playback.recentlyPlayed.map((c) => c.id), [live.id, other.id]);
    expect(storage.getLastPosition(one.id), 120000);
    final persisted = jsonDecode(storage.files['recently_played']!) as List;
    expect(persisted, hasLength(2));
    await playback.removeFromHistory(live);
    expect(playback.recentlyPlayed.single.id, other.id);
  });
}
