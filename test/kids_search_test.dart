import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/user_groups.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Discord, 2026-11-23: on a kids profile, with the adult group hidden, a
/// quick search showed adult content and played it. A kids profile sees
/// only the groups a parent allowed; anything its playlist didn't list
/// counted as shown (movies left under a renamed / dropped category,
/// unlisted categories, editor renames, every group before the list loaded).
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
  late _DirStorage storage;
  late CatalogDatabase catalog;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('vesper_kids_');
    addTearDown(() => temp.delete(recursive: true));
    storage = _DirStorage(temp);
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(catalog.close);
    manager = PlaylistManager(storage, catalog);
    addTearDown(manager.dispose);
    final file = File('${temp.path}/p.m3u');
    await file.writeAsString([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="tsn1" group-title="SPORTS",TSN 1',
      'http://x/1.ts',
      '#EXTINF:-1 tvg-id="cnn" group-title="NEWS",CNN',
      'http://x/2.ts',
      '#EXTINF:-1 tvg-id="hot" group-title="XXX",Hot TV',
      'http://x/3.ts',
      '',
    ].join('\n'));
    await manager.addPlaylist(PlaylistProfile(
        id: 'p',
        name: 'Home',
        mode: 'm3u',
        m3uUrl: Uri.file(file.path).toString(),
        sortOrder: 0,
        createdAt: DateTime(2026)));
    await manager.loadPlaylist('p');
    // Movies the catalog still holds under a category the list no longer
    // has (the provider renamed or dropped it).
    await catalog.upsertVodCategory('p', 'LATE | OLD', [
      Channel(
          id: 'p::m1',
          rawId: 'm1',
          playlistId: 'p',
          name: 'Hot Movie',
          group: 'LATE | OLD',
          url: 'http://x/m1.mp4',
          onDemand: true),
    ]);
    await storage.setViewerProfiles([
      ViewerProfile.main(),
      ViewerProfile(
          id: 'kid',
          name: 'Kid',
          colorIndex: 1,
          isRestricted: true,
          createdAt: DateTime(2026)),
    ]);
  });

  Future<void> asKid(Set<String> allowed) async {
    await storage.setActiveViewerId('kid');
    await storage.setShownGroups('p', allowed);
    manager.applyActiveViewer();
  }

  List<String> live() =>
      [for (final c in manager.visibleChannels(category: 'tv')) c.name];

  Future<List<String>> movies(String q) async => [
        for (final c in await manager.searchVisibleVod(q, ['p'])) c.name
      ];

  test('a kids profile never finds what its playlist no longer lists',
      () async {
    // Main hides nothing it wasn't told to.
    expect(await movies('hot'), ['Hot Movie']);
    expect(live(), ['TSN 1', 'CNN', 'Hot TV']);

    await asKid({'SPORTS'});
    expect(live(), ['TSN 1']);
    expect(await movies('hot'), isEmpty,
        reason: 'a category the kid was never allowed');

    await storage.setShownGroups('p', {'SPORTS', 'LATE | OLD'});
    manager.applyActiveViewer();
    expect(await movies('hot'), ['Hot Movie'], reason: 'allowed by a parent');
  });

  test('a group renamed on the kids profile keeps its allowlist', () async {
    await asKid({'SPORTS'});
    expect(
        await manager.renameLiveGroup('p', 'XXX', 'Late night'), 'Late night');
    expect(await manager.renameLiveGroup('p', 'SPORTS', 'Sport'), 'Sport');
    manager.applyActiveViewer();
    expect(live(), ['TSN 1'],
        reason: 'the renamed hidden group stays hidden, the allowed one shows');
  });

  test('an own group with an allowed channel still shows', () async {
    await asKid({'SPORTS'});
    final title = await manager.createUserGroup('Picks');
    final tsn = manager
        .editorSession('p')!
        .allLiveChannels
        .firstWhere((c) => c.name == 'TSN 1');
    final hot = manager
        .editorSession('p')!
        .allLiveChannels
        .firstWhere((c) => c.name == 'Hot TV');
    await manager.placeChannels([tsn, hot], GroupRef.own(title), copy: false);
    expect([
      for (final c
          in manager.visibleChannels(groupTitle: title, category: 'tv'))
        c.name
    ], [
      'TSN 1'
    ]);
    expect(live(), ['TSN 1']);
  });

  // Discord, LOG-GT8TZG (2026-11-24): Show All, then only the TV tab's
  // adult group hidden; search still found the adult movies.
  group('adult-named groups on a kids profile', () {
    setUp(() async {
      await catalog.upsertVodCategory('p', '|EN| ADULT 18+', [
        Channel(
            id: 'p::m2',
            rawId: 'm2',
            playlistId: 'p',
            name: 'Hot Night',
            group: '|EN| ADULT 18+',
            url: 'http://x/m2.mp4',
            onDemand: true),
      ]);
    });

    test('stay hidden after Show All', () async {
      expect(await movies('hot night'), ['Hot Night'], reason: 'Main');
      await asKid({});
      await manager.setGroupsHidden('p',
          ['SPORTS', 'NEWS', 'XXX', 'LATE | OLD', '|EN| ADULT 18+'], false);
      expect(live(), ['TSN 1', 'CNN']);
      expect(await movies('hot'), ['Hot Movie']);
      expect(await movies('hot night'), isEmpty);
      expect(storage.getShownGroups('p'), isNot(contains('XXX')),
          reason: 'never saved as allowed');
      expect(storage.getShownGroups('p'), contains('NEWS'));
    });

    test('an allowlist saved before this build still hides them', () async {
      await asKid({'SPORTS', 'XXX', '|EN| ADULT 18+'});
      expect(live(), ['TSN 1']);
      expect(await movies('hot night'), isEmpty);
      expect(storage.viewerGroupCount('p', 'kid', allowed: true), 1);
    });

    test('renamed in the editor, still hidden', () async {
      await asKid({'SPORTS', 'XXX'});
      expect(await manager.renameLiveGroup('p', 'XXX', 'Late night'),
          'Late night');
      manager.applyActiveViewer();
      expect(live(), ['TSN 1']);
    });

    test('a regular profile keeps its own choice', () async {
      expect(live(), ['TSN 1', 'CNN', 'Hot TV']);
      expect(await movies('hot night'), ['Hot Night']);
    });
  });

  test('a kids profile is closed before its list has loaded', () async {
    await storage.setActiveViewerId('kid');
    await storage.setShownGroups('q', {'SPORTS'});
    final s = PlaylistSession(
        profile: PlaylistProfile(
            id: 'q',
            name: 'q',
            mode: 'm3u',
            m3uUrl: 'http://127.0.0.1:9/none.m3u',
            sortOrder: 1,
            createdAt: DateTime(2026)),
        storage: storage,
        catalogDb: catalog,
        favoriteIds: () => {},
        favoriteSeriesIds: () => {},
        isRestrictedViewer: () => true,
        onNotify: () {});
    expect(s.hiddenGroups.contains('XXX'), isTrue);
    expect(s.hiddenGroups.contains('SPORTS'), isFalse);
    expect(() => s.hiddenGroups.add('NEWS'), throwsUnsupportedError);
  });
}
