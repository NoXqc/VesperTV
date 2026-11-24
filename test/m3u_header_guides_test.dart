import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/m3u_parser.dart';
import 'package:nox_iptv/services/playlist_editor_epg.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// M3UPT (a user, 2026-11-22: "Vesper doesn't show its EPG"): the list names
/// its guides in its own header, `#EXTM3U url-tvg="a.xml.xz,b.xml.xz"`.
/// VesperTV read the header for catch-up only, and couldn't open `.xz`.
const _guideA = 'https://raw.example/EPG/epg-m3upt.xml.xz';
const _guideB = 'https://raw.example/EPG/epg-locomotion.xml.xz';
const _header = '#EXTM3U url-tvg="$_guideA,$_guideB"';

/// A real `.xz` (Python's lzma = xz-utils' format, CRC64 check): one
/// RTP1.pt programme from 2026 to 2030 (always on) and one after it.
/// `package:archive`'s own encoder writes a stream its decoder flags as
/// incomplete, so it can't make this.
const _xzGuide =
    '/Td6WFoAAATm1rRGAgAhARYAAAB0L+Wj4AFQAJ9dAB4Py4cR2M5mkQ+DHsr9ezPUf+m32+Os'
    'NEUh/qeUnScz1zKRVmj6EcfKBiUcZTctcQDhfSb5IiHulzkv9kU7oaFBtxmOBs+mq/F4o7oz'
    'rHvvmKXefg2VBFDcGrDV4G/c7iSP7EfCY8usW41VcoM9MOMoB60q7xfVC2+6MrFIkxCPR8r1'
    'SC8tuCQdAyOP6uEfQ6qVlfJiReUjr6EwBLb0NQAAT13OJD87qzoAAbsB0QIAAEkUVBOxxGf7'
    'AgAAAAAEWVo=';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('guideUrlsOf', () {
    test('url-tvg with two guides, in order', () {
      expect(M3uParser.guideUrlsOf(M3uParser.attributesOf(_header)),
          [_guideA, _guideB]);
    });

    test('x-tvg-url / tvg-url, spaces, repeats and non-web links', () {
      final attrs = M3uParser.attributesOf('#EXTM3U x-tvg-url=" $_guideA , '
          'ftp://x/g.xml,$_guideA" tvg-url="HTTP://Other/g.xml.gz" '
          'catchup="shift"');
      expect(M3uParser.guideUrlsOf(attrs), [_guideA, 'HTTP://Other/g.xml.gz']);
    });

    test('a header without guides', () {
      expect(
          M3uParser.guideUrlsOf(
              M3uParser.attributesOf('#EXTM3U catchup="shift"')),
          isEmpty);
    });
  });

  group('reading the list', () {
    late Directory temp;
    setUp(() async {
      HttpOverrides.global = null;
      temp = await Directory.systemTemp.createTemp('vesper_m3u_guides_');
    });
    tearDown(() => temp.delete(recursive: true));

    Future<String> list(String header) async {
      final f = File('${temp.path}/list.m3u');
      await f.writeAsString([
        header,
        '#EXTINF:-1 tvg-id="RTP1.pt" group-title="TV",RTP 1',
        'http://x/1.m3u8',
      ].join('\n'));
      return Uri.file(f.path).toString();
    }

    test('a download reports the header guides (also from its isolate)',
        () async {
      final url = await list(_header);
      List<String>? got;
      await M3uParser.fetchAndParse(url,
          playlistId: 'p', onGuides: (urls) => got = urls);
      expect(got, [_guideA, _guideB]);
      final inBackground =
          await M3uParser.fetchAndParseInBackground(url, playlistId: 'p');
      expect(inBackground.guideUrls, [_guideA, _guideB]);
      expect(inBackground.channels, hasLength(1));
    });

    test('the first line only: a BOM, blank lines, no header', () async {
      expect(await M3uParser.fetchHeaderGuideUrls(await list('﻿$_header')),
          [_guideA, _guideB]);
      expect(await M3uParser.fetchHeaderGuideUrls(await list('\n\n$_header')),
          [_guideA, _guideB]);
      expect(
          await M3uParser.fetchHeaderGuideUrls(
              await list('#EXTINF:-1,No header')),
          isEmpty);
    });

    test('the first line only: the rest of the download is not waited for',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.bufferOutput = false;
        request.response.write('$_header\n#EXTINF:-1,One\nhttp://x/1.ts\n');
        await request.response.flush();
        // A huge list still arriving: never finishes on its own.
        await Future<void>.delayed(const Duration(minutes: 5));
      });
      final watch = Stopwatch()..start();
      final urls = await M3uParser.fetchHeaderGuideUrls(
          'http://127.0.0.1:${server.port}/get.php');
      expect(urls, [_guideA, _guideB]);
      expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    });
  });

  group('PlaylistProfile', () {
    PlaylistProfile m3u({String? epgUrl, List<String>? fromList}) =>
        PlaylistProfile(
            id: 'p',
            name: 'M3UPT',
            mode: 'm3u',
            m3uUrl: 'https://m3upt.com/iptv',
            epgUrl: epgUrl,
            sortOrder: 0,
            createdAt: DateTime(2026, 11, 22),
            extraEpgUrls: ['https://extra/uk.xml.gz'],
            playlistEpgUrls: fromList);

    test('a blank EPG URL uses the guides the list names', () {
      final p = m3u(epgUrl: '', fromList: [_guideA, _guideB]);
      expect(p.mainEpgUrls, [_guideA, _guideB]);
      expect(p.guideUrls, [_guideA, _guideB, 'https://extra/uk.xml.gz']);
    });

    test('a typed EPG URL wins over the list', () {
      final p = m3u(epgUrl: 'https://mine/g.xml', fromList: [_guideA]);
      expect(p.mainEpgUrls, ['https://mine/g.xml']);
      expect(p.guideUrls, ['https://mine/g.xml', 'https://extra/uk.xml.gz']);
    });

    test('kept through JSON and copyWith; "not read yet" stays null', () {
      final p = m3u(fromList: [_guideA]);
      expect(PlaylistProfile.fromJson(p.toJson()).playlistEpgUrls, [_guideA]);
      expect(p.copyWith(name: 'x').playlistEpgUrls, [_guideA]);
      expect(
          PlaylistProfile.fromJson(m3u(fromList: const []).toJson())
              .playlistEpgUrls,
          isEmpty);
      expect(PlaylistProfile.fromJson(m3u().toJson()).playlistEpgUrls, isNull);
    });

    test('the playlist editor lists them as the main guides', () {
      final p = m3u(fromList: [_guideA, _guideB]);
      expect(editorGuideUrls(p), [_guideA, _guideB, 'https://extra/uk.xml.gz']);
      expect([for (final s in editorGuideSources(p)) s['name']],
          ['Main guide', 'Main guide 2', 'Extra guide 1']);
    });
  });

  group('PlaylistManager', () {
    late Directory temp;
    late String listUrl;

    setUp(() async {
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      temp = await Directory.systemTemp.createTemp('vesper_m3u_guides_pm_');
      final f = File('${temp.path}/list.m3u');
      await f.writeAsString([
        _header,
        '#EXTINF:-1 tvg-id="RTP1.pt" group-title="TV",RTP 1',
        'http://x/1.m3u8',
      ].join('\n'));
      listUrl = Uri.file(f.path).toString();
    });
    tearDown(() => temp.delete(recursive: true));

    Future<(PlaylistManager, List<List<EpgSource>>)> manager(
        StorageService storage) async {
      final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
      addTearDown(catalog.close);
      final found = <List<EpgSource>>[];
      final m = PlaylistManager(storage, catalog)..onGuidesFound = found.add;
      addTearDown(m.dispose);
      return (m, found);
    }

    Future<void> settle(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    test('adding the list saves its guides and loads them at once', () async {
      final storage = _DirStorage(temp);
      await storage.init();
      final (m, found) = await manager(storage);
      await m.addPlaylist(PlaylistProfile(
          id: 'p',
          name: 'M3UPT',
          mode: 'm3u',
          m3uUrl: listUrl,
          epgUrl: '',
          sortOrder: 0,
          createdAt: DateTime(2026)));
      await m.loadPlaylist('p');
      await settle(() => found.isNotEmpty);

      expect(storage.getPlaylists().single.playlistEpgUrls, [_guideA, _guideB],
          reason: 'saved, so the next start knows them');
      expect([for (final s in m.epgSources()) s.url], [_guideA, _guideB]);
      expect([for (final s in found.single) s.url], [_guideA, _guideB]);
      expect(found.single.first.knownChannelIds, {'RTP1.pt'});

      // The same list again: nothing new to load.
      await m.loadPlaylist('p');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(found, hasLength(1));
    });

    test('a typed guide wins: the list\'s are kept but not loaded', () async {
      final storage = _DirStorage(temp);
      await storage.init();
      final (m, found) = await manager(storage);
      await m.addPlaylist(PlaylistProfile(
          id: 'p',
          name: 'M3UPT',
          mode: 'm3u',
          m3uUrl: listUrl,
          epgUrl: 'https://mine/g.xml',
          sortOrder: 0,
          createdAt: DateTime(2026)));
      await m.loadPlaylist('p');
      await settle(() => storage.getPlaylists().single.playlistEpgUrls != null);
      expect(storage.getPlaylists().single.playlistEpgUrls, [_guideA, _guideB]);
      expect([for (final s in m.epgSources()) s.url], ['https://mine/g.xml']);
      expect(found, isEmpty);
    });

    test('a playlist added before this build: read once at start', () async {
      final storage = _DirStorage(temp);
      await storage.init();
      // First run: the list is stored (its catalog saved), as an older build
      // would have left it: no playlistEpgUrls.
      final (first, _) = await manager(storage);
      await first.addPlaylist(PlaylistProfile(
          id: 'p',
          name: 'M3UPT',
          mode: 'm3u',
          m3uUrl: listUrl,
          sortOrder: 0,
          createdAt: DateTime(2026)));
      await first.loadPlaylist('p');
      await settle(() => storage.getPlaylists().single.playlistEpgUrls != null);
      await storage.setPlaylists([
        PlaylistProfile.fromJson(
            storage.getPlaylists().single.toJson()..remove('playlistEpgUrls'))
      ]);
      expect(storage.getPlaylists().single.playlistEpgUrls, isNull);

      // Next start: restored from the saved catalog, header read once.
      final (m, found) = await manager(storage);
      await m.init();
      await settle(() => found.isNotEmpty);
      expect(storage.getPlaylists().single.playlistEpgUrls, [_guideA, _guideB]);
      expect([for (final s in found.single) s.url], [_guideA, _guideB]);
    });
  });

  group('.xz guides', () {
    late Database db;
    late EpgDatabase epgDb;
    setUp(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await EpgDatabase.createSchema(db);
      epgDb = EpgDatabase(database: db);
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() => db.close());

    String feed() {
      String t(DateTime d) {
        String two(int v) => v.toString().padLeft(2, '0');
        return '${d.year}${two(d.month)}${two(d.day)}'
            '${two(d.hour)}${two(d.minute)}${two(d.second)} +0000';
      }

      final now = DateTime.now().toUtc();
      final hour = DateTime.utc(now.year, now.month, now.day, now.hour);
      final b = StringBuffer('<?xml version="1.0"?><tv>'
          '<channel id="RTP1.pt"><display-name>RTP 1</display-name></channel>');
      for (var h = -1; h < 3; h++) {
        final start = hour.add(Duration(hours: h));
        b.write('<programme start="${t(start)}" '
            'stop="${t(start.add(const Duration(hours: 1)))}" '
            'channel="RTP1.pt"><title>Telejornal $h</title></programme>');
      }
      b.write('</tv>');
      return b.toString();
    }

    Future<Set<String>> titles() async {
      // Stored lower-cased (normalizeEpgId).
      final rows = await epgDb.programmesFor(['rtp1.pt'], 0);
      return {for (final r in rows['rtp1.pt'] ?? const <dynamic>[]) r.title};
    }

    Future<EpgService> service() async {
      final storage = StorageService();
      await storage.init();
      final s = EpgService(storage, database: epgDb);
      addTearDown(s.dispose);
      return s;
    }

    test('an .xml.xz guide is unpacked and stored', () async {
      final xz = base64Decode(_xzGuide);
      expect(EpgService.isXz(xz), isTrue);
      expect(EpgService.isXz(utf8.encode('<?xml version="1.0"?>')), isFalse);
      final s = await service();
      await http.runWithClient(
          () => s.refresh(_guideA, knownChannelIds: const {}),
          () => MockClient((_) async => http.Response.bytes(xz, 200)));
      expect(s.error, isNull);
      expect(await titles(), {'Telejornal'});
      final left = Directory.systemTemp
          .listSync()
          .where((e) => e.path.contains('vesper_epg_'));
      expect(left, isEmpty, reason: 'the unpacked files are deleted');
    });

    test('a damaged .xz guide fails without touching the stored guide',
        () async {
      final xz = base64Decode(_xzGuide);
      final s = await service();
      await http.runWithClient(
          () => s.refresh(_guideA, knownChannelIds: const {}),
          () => MockClient((_) async => http.Response.bytes(xz, 200)));
      await http.runWithClient(
          () => s.refresh(_guideA, knownChannelIds: const {}),
          () => MockClient((_) async =>
              http.Response.bytes(xz.sublist(0, xz.length ~/ 2), 200)));
      expect(s.error, contains('Damaged .xz guide'));
      expect(await titles(), {'Telejornal'});
    });

    test('loadAdded is not a guide update: lastUpdated stays', () async {
      final s = await service();
      await http.runWithClient(
          () => s.loadAdded([(url: _guideA, knownChannelIds: const {})]),
          () => MockClient((_) async => http.Response(feed(), 200)));
      expect(await titles(), hasLength(4));
      expect(s.lastUpdated, isNull);
    });
  });
}
