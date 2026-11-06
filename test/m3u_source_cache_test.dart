import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/m3u_import.dart';
import 'package:nox_iptv/services/m3u_parser.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _playlist = '#EXTM3U\n'
    '#EXTINF:-1 tvg-id="film-42" group-title="EN Movies",Movie\n'
    'https://example.com/movie.mp4\n'
    '#EXTINF:-1 group-title="TV Shows",Episode\n'
    'https://example.com/episode.mkv\n'
    '#EXTINF:-1 tvg-id="station" group-title="Live",Station\n'
    'https://example.com/live.m3u8\n'
    '#EXTINF:-1 tvg-id="news" group-title="Live",News\n'
    'https://example.com/news.m3u8\n';

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

PlaylistSession _session(
        StorageService storage, String url, CatalogDatabase catalog) =>
    PlaylistSession(
      profile: PlaylistProfile(
          id: 'p',
          name: 'M3U',
          mode: 'm3u',
          m3uUrl: url,
          sortOrder: 0,
          createdAt: DateTime(2026)),
      storage: storage,
      catalogDb: catalog,
      favoriteIds: () => {'p::film-42'},
      favoriteSeriesIds: () => {},
      isRestrictedViewer: () => false,
      onNotify: () {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(Directory, _DirStorage, CatalogDatabase)> setUpStore() async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('m3u_source_test_');
    final storage = _DirStorage(temp);
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(() async {
      await catalog.close();
      await temp.delete(recursive: true);
    });
    return (temp, storage, catalog);
  }

  test('an M3U is stored: live in memory, movies and shows in the catalog',
      () async {
    final (temp, storage, catalog) = await setUpStore();
    final playlist = File('${temp.path}/list.m3u');
    await playlist.writeAsString(_playlist);
    // Copies of the whole list older builds kept: dropped by the load.
    final oldJson = File('${temp.path}/m3u_channels_p.json');
    await oldJson.writeAsString('[]');
    final oldText = File('${temp.path}/m3u_source_p.m3u');
    await oldText.writeAsString(_playlist);

    final url = Uri.file(playlist.path).toString();
    final first = _session(storage, url, catalog);
    await first.loadFromUrl(url);
    expect(first.error, isNull);
    expect(first.m3uCatalogInDb, isTrue);
    expect(first.channels.map((c) => c.id), ['p::station', 'p::news']);
    expect(first.lastLoadSummary, {'tv': 2, 'vod': 1, 'series': 1});
    expect(await File('${temp.path}/m3u_catalog_p.json').exists(), isTrue);
    expect(await oldJson.exists(), isFalse);
    expect(await oldText.exists(), isFalse);

    // The playlist itself is gone: only what was stored can fill this one.
    await playlist.delete();
    final second = _session(storage, url, catalog);
    await second.restoreOrLoad();
    expect(second.error, isNull);
    expect(second.channels.map((c) => c.id), ['p::station', 'p::news']);
    expect(second.tvGroups.map((g) => g.title), ['Live']);
    expect(second.vodCategories.map((c) => c.name), ['EN Movies']);
    await second.ensureCategoryLoaded('EN Movies', 'vod');
    final movie = second.visibleChannels(category: 'vod').single;
    expect(movie.id, 'p::film-42');
    expect(movie.isFavorite, isTrue);
    expect(movie.isLive, isFalse);
    expect(second.seriesCategories.map((c) => c.name), ['TV Shows']);
    await second.ensureCategoryLoaded('TV Shows', 'series');
    final show = second.visibleSeries('TV Shows').single;
    expect(show.name, 'Episode');
    final episodes = await second.loadSeriesEpisodes(show);
    expect(episodes.episodes[1]!.single.url, 'https://example.com/episode.mkv');
    expect(episodes.episodes[1]!.single.isLive, isFalse);
  });

  test('a list an older build saved as text is stored once at launch',
      () async {
    final (temp, storage, catalog) = await setUpStore();
    final oldText = File('${temp.path}/m3u_source_p.m3u');
    await oldText.writeAsString(_playlist);
    final session = _session(storage, 'http://unreachable.invalid/x', catalog);
    await session.restoreOrLoad();
    expect(session.error, isNull);
    expect(session.channels.map((c) => c.id), ['p::station', 'p::news']);
    expect(session.vodCategories.map((c) => c.name), ['EN Movies']);
    expect(await oldText.exists(), isFalse);
    expect(await File('${temp.path}/m3u_catalog_p.json').exists(), isTrue);
  });

  test('a failed refresh keeps the stored catalog', () async {
    final (temp, storage, catalog) = await setUpStore();
    final playlist = File('${temp.path}/list.m3u');
    await playlist.writeAsString(_playlist);
    final url = Uri.file(playlist.path).toString();
    await _session(storage, url, catalog).loadFromUrl(url);
    await playlist.delete();
    final failed = _session(storage, url, catalog);
    await failed.loadFromUrl(url);
    expect(failed.error, isNotNull);
    final again = _session(storage, url, catalog);
    await again.restoreOrLoad();
    expect(again.channels, hasLength(2));
    expect(await catalog.getVodCategory('p', 'EN Movies'), hasLength(1));
  });

  test('episode names give their show, season and episode', () {
    for (final (name, show, season, episode) in [
      ('Breaking Bad S01 E02', 'Breaking Bad', 1, 2),
      ('Breaking.Bad.S02E10', 'Breaking Bad', 2, 10),
      // A year as the season (owner's list: each was a show of its own).
      ('MythBusters - S2003E05 - No Episode Title', 'MythBusters', 2003, 5),
      (
        'American Pickers - S2014E25 - No Episode Title',
        'American Pickers',
        2014,
        25
      ),
      ('Jeopardy! - S1992E179 - No Episode Title', 'Jeopardy!', 1992, 179),
      ('Come Dine with Me - 2019-08-05', 'Come Dine with Me', 2019, 805),
      (
        'Come Dine with Me - S21E15 - Series 21, Episode 15',
        'Come Dine with Me',
        21,
        15
      ),
      ('Doctor Who Season 2 Episode 5', 'Doctor Who', 2, 5),
      ('Top Gear - Series 3, Ep 4', 'Top Gear', 3, 4),
      ('Plus belle la vie - Saison 1 Épisode 12', 'Plus belle la vie', 1, 12),
      ('Coronation Street - 07.07.2004', 'Coronation Street', 2004, 707),
      ('The Late Show 12/31/2004', 'The Late Show', 2004, 1231),
      ('Neighbours - 7th July 2004', 'Neighbours', 2004, 707),
      ('The Tonight Show - Jul 7, 2004', 'The Tonight Show', 2004, 707),
      ('Danger in the Ruins - Part 2', 'Danger in the Ruins', 1, 2),
      (
        'One Giant Leap: 1975-1982 - Sea Dragon Launch (1977)',
        'One Giant Leap: 1975-1982 - Sea Dragon Launch (1977)',
        1,
        1
      ),
      ('EN - The Office (US) - S3 EP4 - Title', 'EN - The Office (US)', 3, 4),
      ('Dark 1x05', 'Dark', 1, 5),
      // Daily shows by air date: one show, season = year.
      ('Emmerdale - 2004-07-07', 'Emmerdale', 2004, 707),
      ('EastEnders - 1999-10-12', 'EastEnders', 1999, 1012),
      ('The Daily Show 2024.03.05', 'The Daily Show', 2024, 305),
      ('Planet Earth - Episode 3', 'Planet Earth', 1, 3),
      ('Planet Earth Ep 4', 'Planet Earth', 1, 4),
      ('Blade Runner 2049', 'Blade Runner 2049', 1, 1),
      ('A movie-like title', 'A movie-like title', 1, 1),
    ]) {
      final e = M3uImport.episodeOf(name);
      expect((e.show, e.season, e.episode), (show, season, episode),
          reason: name);
    }
    expect(M3uImport.showIdOf('G', 'Dark'), M3uImport.showIdOf('G', 'DARK'));
    expect(M3uImport.showIdOf('G', 'Breaking.Bad'),
        M3uImport.showIdOf('G', 'breaking  bad'));
  });

  test('a failed load keeps the previous saved text', () async {
    final temp = await Directory.systemTemp.createTemp('m3u_source_test_');
    addTearDown(() => temp.delete(recursive: true));
    final saved = File('${temp.path}/saved.m3u');
    await saved.writeAsString(_playlist);
    await expectLater(
        M3uParser.fetchAndParseInBackground(
            Uri.file('${temp.path}/missing.m3u').toString(),
            playlistId: 'p',
            saveTo: saved.path),
        throwsA(anything));
    expect(await saved.readAsString(), _playlist);
    expect(await File('${saved.path}.part').exists(), isFalse);
  });

  test('entries share one group title string', () {
    final entries = M3uParser.parse(_playlist, playlistId: 'p');
    expect(identical(entries[2].group, entries[3].group), isTrue);
  });

  test('a title keeps its own commas', () {
    for (final (line, title) in [
      (
        '#EXTINF:-1 tvg-name="SNL - S12E09 - A, B" group-title="Comedy",'
            'Saturday Night Live - S12E09 - Walter Payton, Joe Montana',
        'Saturday Night Live - S12E09 - Walter Payton, Joe Montana'
      ),
      (
        '#EXTINF:-1,Crouching Tiger, Hidden Dragon',
        'Crouching Tiger, Hidden Dragon'
      ),
      ('#EXTINF:-1 tvg-id="x",Plain', 'Plain'),
      ('#EXTINF:-1 tvg-id="unclosed,Name, Two', 'Two'),
    ]) {
      expect(M3uParser.titleOf(line), title, reason: line);
    }
    final parsed = M3uParser.parse(
        [
          '#EXTM3U',
          '#EXTINF:-1 group-title="Comedy",SNL - S12E09 - A, B',
          'http://h/series/u/p/1.mkv',
        ].join('\n'),
        playlistId: 'p');
    expect(parsed.single.name, 'SNL - S12E09 - A, B');
  });

  test('the attribute scanner finds what the old regex found', () {
    // The regex it replaced (two thirds of a big list's parse time).
    final regex = RegExp(r'([a-zA-Z0-9_-]+)="([^"]*)"');
    Map<String, String> old(String line) => {
          for (final m in regex.allMatches(line))
            m.group(1)!.toLowerCase(): m.group(2)!
        };
    final lines = [
      '#EXTINF:-1 tvg-id="a.b" tvg-name="Name, with comma" '
          'tvg-logo="http://x/y.png" group-title="EN | SPORTS",Name',
      '#EXTM3U url-tvg="http://x/epg.xml" x-tvg-url="" catchup="xc"',
      '#EXTINF:-1 TVG-ID="Up" Group-Title="Mixed",Case',
      '#EXTINF:-1 tvg-name="a="b" group-title="x",value holds =" and quotes',
      '#EXTINF:-1 ="no key" k ="space" k2="",Empty',
      '#EXTINF:-1 tvg-id="unclosed,Name',
      '#EXTINF:-1 dup="1" dup="2",Last wins',
      '#EXTINF:-1 group-title="Ünïcödé 日本",Uni',
      '#EXTINF:0,Plain',
    ];
    final random = Random(3);
    const pieces = ['k', '-', '_', '=', '"', ' ', 'v', 'Ä', ',', '9'];
    for (var i = 0; i < 2000; i++) {
      lines.add('#EXTINF:-1 ${[
        for (var j = 0; j < random.nextInt(40); j++)
          pieces[random.nextInt(pieces.length)]
      ].join()}');
    }
    for (final line in lines) {
      expect(M3uParser.attributesOf(line), old(line), reason: line);
    }
  });
}
