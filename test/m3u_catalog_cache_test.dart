import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/m3u_parser.dart';
import 'package:nox_iptv/services/playlist_edits.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/user_groups.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A plain M3U's groups, tab lists and per-group lookups are built once
/// per loaded list (LOG-QKPTCP: a 320k-entry M3U rescanned every entry on
/// each call, ~1.4 s per TV home build on an onn 4K Pro). They must give
/// exactly what a scan of every entry gives.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Channel ch(String rawId, String group) => Channel(
        id: 'p::$rawId',
        rawId: rawId,
        playlistId: 'p',
        name: 'Channel $rawId',
        group: group,
        url: 'http://x/$rawId.ts',
      );

  Future<PlaylistSession> session(List<Channel> channels,
      {UserGroups? mine}) async {
    final storage = StorageService();
    await storage.init();
    final s = PlaylistSession(
      profile: PlaylistProfile(
          id: 'p',
          name: 'p',
          mode: 'm3u',
          sortOrder: 0,
          createdAt: DateTime(2026)),
      storage: storage,
      catalogDb: CatalogDatabase(),
      favoriteIds: () => {},
      favoriteSeriesIds: () => {},
      isRestrictedViewer: () => false,
      onNotify: () {},
      myGroupOf: mine == null ? null : (c) => mine.groupOf(c.id),
    );
    s.channels = channels;
    return s;
  }

  List<String> ids(Iterable<Channel> list) => [for (final c in list) c.id];

  /// The old full scan, kept here as the reference.
  List<String> scan(PlaylistSession s, String group, String category) =>
      ids(s.channels.where((c) =>
          (category == 'tv' ? s.liveGroupOf(c) : c.group) == group &&
          (category != 'tv' || !s.isLiveHidden(c.rawId))));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final mixed = [
    ch('1', 'US| Sports'),
    ch('2', 'VOD| Action'),
    ch('3', 'US| News'),
    ch('4', 'SERIES| Netflix'),
    ch('5', 'US| Sports'),
    ch('6', 'VOD| Action'),
    ch('7', 'SERIES| Netflix'),
    ch('8', 'US| News'),
  ];

  test('per-group lookups equal a scan of every entry', () async {
    final mine = UserGroups();
    final s = await session(mixed, mine: mine);
    s.hiddenChannels.add('8');
    mine.move('p::5', 'My picks');
    for (final (group, category) in [
      ('US| Sports', 'tv'),
      ('US| News', 'tv'),
      ('My picks', 'tv'),
      ('VOD| Action', 'vod'),
      ('SERIES| Netflix', 'series'),
      ('Missing', 'vod'),
    ]) {
      expect(ids(s.visibleChannels(groupTitle: group, category: category)),
          scan(s, group, category),
          reason: '$category / $group');
    }
    expect(ids(s.visibleChannels(groupTitle: 'US| Sports', category: 'tv')),
        ['p::1']);
    expect(ids(s.visibleChannels(groupTitle: 'My picks', category: 'tv')),
        ['p::5']);
  });

  test('a renamed group still gathers every source group', () async {
    final s = await session(mixed);
    s.edits = PlaylistEdits(groupNames: {'US| News': 'US| Sports'});
    expect(ids(s.visibleChannels(groupTitle: 'US| Sports', category: 'tv')),
        ['p::1', 'p::3', 'p::5', 'p::8']);
  });

  test('tab lists keep playlist order and follow a new load', () async {
    final s = await session(mixed);
    expect(ids(s.allLiveChannels), ['p::1', 'p::3', 'p::5', 'p::8']);
    expect(ids(s.m3uEntriesOf('vod')), ['p::2', 'p::6']);
    expect(ids(s.m3uEntriesOf('series')), ['p::4', 'p::7']);
    expect(s.allGroups.map((g) => g.title),
        ['US| Sports', 'VOD| Action', 'US| News', 'SERIES| Netflix']);
    for (final c in s.channels) {
      expect(s.m3uEntriesOf(M3uParser.groupCategory(c.group)), contains(c));
    }

    // A reload replaces the list: nothing from the old one is served.
    s.channels = [ch('9', 'US| Kids'), ch('10', 'VOD| Drama')];
    expect(ids(s.allLiveChannels), ['p::9']);
    expect(ids(s.m3uEntriesOf('vod')), ['p::10']);
    expect(s.allGroups.map((g) => g.title), ['US| Kids', 'VOD| Drama']);
    expect(
        s.visibleChannels(groupTitle: 'US| Sports', category: 'tv'), isEmpty);
    expect(ids(s.visibleChannels(groupTitle: 'US| Kids', category: 'tv')),
        ['p::9']);
  });

  test('Xtream movie and episode links pick their tab, whatever the group',
      () async {
    // LOG-ELUGMN: 1.08M movies and episodes in groups without "movie" or
    // "series" in the title all landed in Live TV.
    Channel at(String rawId, String group, String url) => Channel(
        id: 'p::$rawId',
        rawId: rawId,
        playlistId: 'p',
        name: rawId,
        group: group,
        url: url);
    final s = await session([
      at('1', 'EN | SPORTS', 'http://h:8080/u/pw/1.ts'),
      at('2', 'EN | ACTION', 'http://h:8080/movie/u/pw/2.mkv'),
      at('3', '|EN| BREAKING BAD', 'http://h:8080/series/u/pw/3.mkv'),
      at('4', 'EN | ACTION', 'http://h:8080/movie/u/pw/4.mp4'),
      // Not an Xtream file link: by its group title, as before.
      at('5', 'Docs', 'https://cdn.example/movie/2024/docs/index.m3u8'),
      // A live and a movie category with one name keep their own entries.
      at('6', 'EN | KIDS', 'http://h:8080/u/pw/6.ts'),
      at('7', 'EN | KIDS', 'http://h:8080/movie/u/pw/7.mkv'),
    ]);
    expect(ids(s.allLiveChannels), ['p::1', 'p::5', 'p::6']);
    expect(ids(s.m3uEntriesOf('vod')), ['p::2', 'p::4', 'p::7']);
    expect(ids(s.m3uEntriesOf('series')), ['p::3']);
    expect(
        s.tvGroups.map((g) => g.title), ['EN | SPORTS', 'Docs', 'EN | KIDS']);
    expect(s.vodGroups.map((g) => g.title), ['EN | ACTION', 'EN | KIDS']);
    expect(s.seriesGroups.map((g) => g.title), ['|EN| BREAKING BAD']);
    expect(ids(s.visibleChannels(groupTitle: 'EN | ACTION', category: 'vod')),
        ['p::2', 'p::4']);
    expect(ids(s.visibleChannels(groupTitle: 'EN | KIDS', category: 'tv')),
        ['p::6']);
    expect(ids(s.visibleChannels(groupTitle: 'EN | KIDS', category: 'vod')),
        ['p::7']);

    // The parser marks them on demand too (plays as a movie, not live).
    final parsed = M3uParser.parse(
        [
          '#EXTM3U',
          '#EXTINF:-1 group-title="EN | ACTION",Film',
          'http://h:8080/movie/u/pw/2.mkv',
          '#EXTINF:-1 group-title="EN | SPORTS",Live',
          'http://h:8080/u/pw/1.ts',
        ].join('\n'),
        playlistId: 'p');
    expect([for (final c in parsed) c.isLive], [false, true]);
  });

  test('a hidden group still leaves the whole-tab list', () async {
    final s = await session(mixed);
    s.hiddenGroups.add('US| News');
    expect(ids(s.visibleChannels(category: 'tv')), ['p::1', 'p::5']);
    expect(ids(s.visibleChannels(category: 'vod')), ['p::2', 'p::6']);
  });

  test('Favourites follow every star', () async {
    final temp = await Directory.systemTemp.createTemp('m3u_cache_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/list.m3u');
    await file.writeAsString([
      '#EXTM3U',
      '#EXTINF:-1 tvg-id="one" group-title="US| Sports",One',
      'http://x/1.ts',
      '#EXTINF:-1 tvg-id="two" group-title="US| Sports",Two',
      'http://x/2.ts',
      '#EXTINF:-1 tvg-id="film" group-title="VOD| Action",Film',
      'http://x/movie/3.mkv',
      '',
    ].join('\n'));
    final storage = _DirStorage(temp);
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(catalog.close);
    final manager = PlaylistManager(storage, catalog);
    addTearDown(manager.dispose);
    final url = Uri.file(file.path).toString();
    await manager.addPlaylist(PlaylistProfile(
        id: 'p',
        name: 'p',
        mode: 'm3u',
        m3uUrl: url,
        sortOrder: 0,
        createdAt: DateTime(2026)));
    await manager.loadPlaylist('p');
    final two = manager.channels.firstWhere((c) => c.name == 'Two');
    // Movies are in the catalog database, not the live list.
    expect(manager.channels.map((c) => c.name), ['One', 'Two']);
    final film = (await catalog.getVodCategory('p', 'VOD| Action')).single;
    expect(film.isLive, isFalse);
    expect(manager.favoriteLiveChannels, isEmpty);
    expect(manager.orderedFavoriteLiveChannels(), isEmpty);
    expect(manager.favoriteMovies, isEmpty);

    await manager.toggleFavorite(two);
    await manager.toggleFavorite(film);
    expect(ids(manager.favoriteLiveChannels), [two.id]);
    expect(ids(manager.orderedFavoriteLiveChannels()), [two.id]);
    expect(ids(manager.favoriteMovies), [film.id]);
    // Callers get their own copy.
    manager.favoriteLiveChannels.clear();
    expect(ids(manager.favoriteLiveChannels), [two.id]);

    await manager.toggleFavorite(two);
    expect(manager.favoriteLiveChannels, isEmpty);
    expect(manager.orderedFavoriteLiveChannels(), isEmpty);
  });
}

/// Cache files in a temp folder instead of path_provider's.
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
  Future<void> deleteCacheFile(String name) async {
    final f = File('${dir.path}/$name.json');
    if (await f.exists()) await f.delete();
  }
}
