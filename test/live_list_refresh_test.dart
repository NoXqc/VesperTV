import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/xtream_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Event channels are renamed by the provider every day; the saved live list
/// showed yesterday's games until a full update (2026-11-07).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late StorageService storage;
  late Directory temp;
  late HttpServer server;
  CatalogDatabase? catalog;
  var game = 'Nuggets vs. Pacers @ 7 Nov 04:58 PM ET';

  setUp(() async {
    HttpOverrides.global = null; // the test binding fakes HTTP otherwise
    databaseFactory = databaseFactoryFfi;
    temp = await Directory.systemTemp.createTemp('vesper-live-refresh-');
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      final action = request.uri.queryParameters['action'];
      final body = switch (action) {
        'get_live_categories' => [
            {'category_id': '175', 'category_name': 'USA | NBA'}
          ],
        'get_live_streams' => [
            {
              'stream_id': 325318,
              'name': 'NBA 01: $game',
              'epg_channel_id': 'BossSports.NBA.01',
              'category_id': '175',
              'stream_type': 'live',
            },
            {
              'stream_id': 342588,
              'name': 'US: NBA ATLANTA HAWKS FHD',
              'epg_channel_id': 'BossSports.NBA_Teams.atlantahawks',
              'category_id': '175',
              'stream_type': 'live',
            },
          ],
        _ => <Object>[],
      };
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body))
        ..close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    await catalog?.close();
    await temp.delete(recursive: true);
  });

  Future<PlaylistSession> session(Set<String> favorites) async {
    final s = PlaylistSession(
        profile: PlaylistProfile(
            id: 'p',
            name: 'p',
            mode: 'xtream',
            sortOrder: 0,
            createdAt: DateTime(2026)),
        storage: storage,
        catalogDb: catalog =
            CatalogDatabase(databasePath: '${temp.path}/catalog.db'),
        favoriteIds: () => favorites,
        favoriteSeriesIds: () => {},
        isRestrictedViewer: () => false,
        onNotify: () {});
    s.xtreamApi = XtreamApiService(
        server: 'http://127.0.0.1:${server.port}',
        username: 'u',
        password: 'p',
        playlistId: 'p');
    return s;
  }

  test('a stale list with event channels gets the day\'s names', () async {
    final first = await session({});
    expect(await first.refreshLiveList(), isFalse,
        reason: 'nothing loaded yet: the lazy load owns the first list');

    // Yesterday's list, as the saved copy would have it.
    final api = first.xtreamApi!;
    first.liveChannels = Channel.withUniqueIds(
        await api.getLiveStreams(categoryNames: {'175': 'USA | NBA'}));
    final nba = first.liveChannels.first;
    expect(nba.name, contains('Nuggets'));
    expect(first.hasEventChannels, isTrue);

    final s = await session({nba.id});
    s.liveChannels = first.liveChannels;
    s.liveListFetchedAt = DateTime.now().subtract(const Duration(hours: 20));
    expect(s.liveListOlderThan(const Duration(hours: 1)), isTrue);

    game = 'Knicks vs. Cavaliers @ 8 Nov 07:30 PM ET';
    expect(await s.refreshLiveList(), isTrue);

    final fresh = s.liveChannels.firstWhere((c) => c.rawId == nba.rawId);
    expect(fresh.name, 'NBA 01: Knicks vs. Cavaliers @ 8 Nov 07:30 PM ET');
    expect(fresh.id, nba.id,
        reason: 'same id: favourites and guide carry over');
    expect(fresh.isFavorite, isTrue);
    expect(fresh.group, 'USA | NBA');
    expect(s.liveListOlderThan(const Duration(hours: 1)), isFalse);
  });

  test('team channels alone are not event channels', () async {
    final s = await session({});
    s.liveChannels = Channel.withUniqueIds(
        await s.xtreamApi!.getLiveStreams(categoryNames: {'175': 'USA | NBA'}));
    s.liveChannels =
        s.liveChannels.where((c) => !c.name.contains('@')).toList();
    expect(s.hasEventChannels, isFalse);
  });
}
