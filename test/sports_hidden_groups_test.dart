import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/hidden_channel_tag.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Settings > Sports Trak > Find games in hidden groups (owner, 2026-11-25):
/// Sports Trak's channels also come from hidden live groups; channels
/// hidden one by one stay out; never on a kids profile.
class _DirStorage extends StorageService {
  _DirStorage(this.dir);
  final Directory dir;
  @override
  Future<String> rawCachePath(String name, String ext) async =>
      '${dir.path}/$name.$ext';
  @override
  Future<String?> cacheFilePath(String name) async {
    final f = File('${dir.path}/$name.json');
    return await f.exists() ? f.path : null;
  }

  @override
  Future<void> writeCacheFile(String name, String content) =>
      File('${dir.path}/$name.json').writeAsString(content);

  @override
  Future<void> deleteCacheFile(String name) async {
    final f = File('${dir.path}/$name.json');
    if (await f.exists()) await f.delete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlaylistManager manager;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_sports_hidden_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/list.m3u');
    await file.writeAsString([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="tsn1" group-title="SPORTS",TSN 1',
      'http://x/1.ts',
      '#EXTINF:-1 tvg-id="rds" group-title="SPORTS",RDS',
      'http://x/2.ts',
      '#EXTINF:-1 tvg-id="espn01" group-title="EVENTS",ESPN+ 01',
      'http://x/3.ts',
      '#EXTINF:-1 tvg-id="espn02" group-title="EVENTS",ESPN+ 02',
      'http://x/4.ts',
      '#EXTINF:-1 tvg-id="cnn" group-title="NEWS",CNN',
      'http://x/5.ts',
      '',
    ].join('\n'));
    storage = _DirStorage(temp);
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(catalog.close);
    manager = PlaylistManager(storage, catalog);
    addTearDown(manager.dispose);
    await manager.addPlaylist(PlaylistProfile(
        id: 'p',
        name: 'Home',
        mode: 'm3u',
        m3uUrl: Uri.file(file.path).toString(),
        sortOrder: 0,
        createdAt: DateTime(2026)));
    await manager.loadPlaylist('p');
    // A group hidden to keep the TV tidy, and one channel hidden by hand
    // in a shown group and one in the hidden group.
    await manager.setGroupHidden('p', 'EVENTS', true);
    Channel named(String name) => manager
        .visibleChannels(category: 'tv')
        .followedBy(manager.hiddenLiveChannels())
        .firstWhere((c) => c.name == name);
    await manager.toggleChannelHidden(named('RDS'));
    await manager.toggleChannelHidden(named('ESPN+ 02'));
  });

  List<String> names(List<Channel> list) => [for (final c in list) c.name];

  test('off (the default): only what the TV shows', () {
    expect(storage.getSportsSearchHiddenGroups(), isFalse);
    expect(manager.sportsSearchesHiddenGroups, isFalse);
    expect(names(manager.sportsChannels()), ['TSN 1', 'CNN']);
    expect(names(manager.sportsHiddenChannels()),
        unorderedEquals(['RDS', 'ESPN+ 01', 'ESPN+ 02']),
        reason: 'Sports Trak can say a game is on a hidden channel');
  });

  test('on: hidden groups are searched, channels hidden one by one are not',
      () async {
    await storage.setSportsSearchHiddenGroups(true);
    expect(manager.sportsSearchesHiddenGroups, isTrue);
    final channels = manager.sportsChannels();
    expect(names(channels), ['TSN 1', 'CNN', 'ESPN+ 01']);
    expect({for (final c in channels) c.id}, hasLength(channels.length));
    expect(names(manager.sportsHiddenChannels()),
        unorderedEquals(['RDS', 'ESPN+ 02']));
    // The TV itself is unchanged.
    expect(names(manager.visibleChannels(category: 'tv')), ['TSN 1', 'CNN']);
  });

  test('a kids profile never searches hidden groups', () async {
    await storage.setViewerProfiles([
      ViewerProfile.main(),
      ViewerProfile(
          id: 'kid',
          name: 'Kid',
          colorIndex: 1,
          isRestricted: true,
          createdAt: DateTime(2026)),
    ]);
    await storage.setActiveViewerId('kid');
    await storage.setShownGroups('p', {'SPORTS'});
    await storage.setSportsSearchHiddenGroups(true);
    manager.applyActiveViewer();
    expect(manager.sportsSearchesHiddenGroups, isFalse);
    expect(names(manager.sportsChannels()),
        names(manager.visibleChannels(category: 'tv')));
    expect(names(manager.sportsChannels()), isNot(contains('ESPN+ 01')));
    expect(manager.sportsHiddenChannels(), isEmpty);
  });

  test('channels from a hidden group are told apart (the Hidden tag)',
      () async {
    await storage.setSportsSearchHiddenGroups(true);
    final byName = {for (final c in manager.sportsChannels()) c.name: c};
    expect(manager.isInHiddenGroup(byName['ESPN+ 01']!), isTrue);
    expect(manager.isInHiddenGroup(byName['TSN 1']!), isFalse);
    expect(manager.isInHiddenGroup(byName['CNN']!), isFalse);
  });

  testWidgets('the Hidden tag reads Hidden', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: HiddenChannelTag()))));
    expect(find.text('Hidden'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  test('saved for each viewer', () async {
    await storage.setSportsSearchHiddenGroups(true);
    await storage.setActiveViewerId('other');
    expect(storage.getSportsSearchHiddenGroups(), isFalse);
  });
}
