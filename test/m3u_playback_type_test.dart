import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/m3u_parser.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/player_controls.dart';

const _playlist = '#EXTM3U\n'
    '#EXTINF:-1 tvg-id="film-42" group-title="EN Movies",Movie\n'
    'https://example.com/movie.mp4\n'
    '#EXTINF:-1 group-title="TV Shows",Episode\n'
    'https://example.com/episode.mkv\n'
    '#EXTINF:120 tvg-id="station" group-title="Live",Station\n'
    'https://example.com/live.m3u8\n';

class _CacheStorage extends StorageService {
  _CacheStorage(this.path);
  final String path;
  @override
  Future<String?> cacheFilePath(String name) async => path;
}

class _SeekController extends VideoPlayerHdrController {
  _SeekController() : super.networkUrl(Uri.parse('https://example.com/movie')) {
    value = const VideoPlayerHdrValue(
        duration: Duration(hours: 2),
        position: Duration(minutes: 5),
        isInitialized: true,
        size: Size(1920, 1080));
  }
  @override
  bool isVideoTrackSupportAvailable() => false;
  @override
  bool isAudioTrackSupportAvailable() => false;
  Duration? sought;
  @override
  Future<void> seekTo(Duration position) async {
    sought = position;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'M3U catalog type enables VOD without rewriting IDs or inferring duration',
      () {
    final entries = M3uParser.parse(_playlist, playlistId: 'p');
    expect(entries.map((c) => c.isLive), [false, false, true]);
    expect(entries.map((c) => c.id), ['p::film-42', 'p::ch_2', 'p::station']);
    expect(entries.first.rawId, 'film-42');
    expect(entries.first.epgId, 'film-42');
    expect(M3uParser.groupCategory('VOD TV Series'), 'series');
    expect(M3uParser.groupCategory('MOVIES'), 'vod');
    expect(M3uParser.groupCategory('News'), 'tv');
  });

  test('type survives cache JSON, copies and duplicate EPG IDs', () {
    final movie = M3uParser.parse(_playlist, playlistId: 'p').first;
    final restored = Channel.fromJson(
        jsonDecode(jsonEncode(movie.toJson())) as Map<String, dynamic>);
    final copies = Channel.withUniqueIds([
      restored.copyWith(isFavorite: true),
      restored.copyWith(url: 'https://example.com/other.mp4'),
    ]);
    expect(copies.every((c) => !c.isLive), isTrue);
    expect(copies.first.isFavorite, isTrue);
    expect(copies.first.epgId, 'film-42');
    expect(copies.last.epgId, 'film-42');
  });

  test('Xtream live groups named Movies stay live; VOD prefixes still work',
      () {
    Channel item(String raw) => Channel(
        id: 'p::$raw',
        rawId: raw,
        playlistId: 'p',
        name: 'Test',
        group: 'Movies 24/7',
        url: 'https://example.com/file.mp4');
    expect(item('xt_live_1').isLive, isTrue);
    for (final raw in [
      'xt_vod_1',
      'xt_ep_1',
      'arc_vod_1',
      'arc_ep_1',
      'rec_1'
    ]) {
      expect(item(raw).isLive, isFalse, reason: raw);
    }
  });

  test('existing M3U cache upgrades on startup without refresh or ID changes',
      () async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('m3u_type_test_');
    addTearDown(() => temp.delete(recursive: true));
    final entries = M3uParser.parse(_playlist, playlistId: 'p');
    final oldJson = entries.map((c) => c.toJson()..remove('onDemand')).toList();
    final file =
        await File('${temp.path}/old.json').writeAsString(jsonEncode(oldJson));
    final storage = _CacheStorage(file.path);
    await storage.init();
    final session = PlaylistSession(
      profile: PlaylistProfile(
          id: 'p',
          name: 'M3U',
          mode: 'm3u',
          m3uUrl: 'https://example.invalid/never-requested',
          sortOrder: 0,
          createdAt: DateTime(2026)),
      storage: storage,
      catalogDb: CatalogDatabase(),
      favoriteIds: () => {'p::film-42'},
      favoriteSeriesIds: () => {},
      isRestrictedViewer: () => false,
      onNotify: () {},
    );
    await session.restoreOrLoad();
    final movies = session.visibleChannels(category: 'vod');
    expect(movies.single.id, 'p::film-42');
    expect(movies.single.isFavorite, isTrue);
    expect(movies.single.isLive, isFalse);
    expect(session.visibleChannels(category: 'tv').single.isLive, isTrue);
    expect(session.error, isNull);
  });

  testWidgets('M3U movie player shows a working seek bar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    final controller = _SeekController();
    final movie = M3uParser.parse(_playlist, playlistId: 'p').first;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: prefs,
      child: MaterialApp(
          home: Scaffold(
              body: PlayerControls(
        controller: controller,
        title: movie.name,
        channelId: movie.epgId,
        isLive: movie.isLive,
      ))),
    ));
    expect(find.byType(Slider), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(600000);
    await tester.pump();
    expect(controller.sought, const Duration(minutes: 10));
    await tester.pumpWidget(const SizedBox());
    await controller.dispose();
    prefs.dispose();
  });
}
