import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/m3u_parser.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A big `get.php` list can take minutes to arrive. The download only gives
/// up when no data comes for a while, never on its total time: a 5-minute
/// cap cut a ~350k-entry list that was still arriving (LOG-HKVWLU).
void main() {
  String entry(int i) =>
      '#EXTINF:-1 tvg-id="c$i" group-title="Live",Channel $i\n'
      'http://x/$i.ts\n';

  late HttpServer server;
  late String base;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      // Sent as written, not held back until the response closes.
      final res = req.response..bufferOutput = false;
      res.write('#EXTM3U\n');
      switch (req.uri.path) {
        case '/slow':
          // 16 entries over ~1.6 s, more than the test's stall limit in
          // total but never silent for that long.
          for (var i = 0; i < 16; i++) {
            res.write(entry(i));
            await res.flush();
            await Future.delayed(const Duration(milliseconds: 100));
          }
          await res.close();
        case '/silent':
          // Two entries, then nothing (the connection stays open).
          res.write(entry(0) + entry(1));
          await res.flush();
      }
    });
  });

  tearDownAll(() => server.close(force: true));

  test('a slow list that keeps coming is never cut off', () async {
    final reports = <int>[];
    final channels = await M3uParser.fetchAndParse('$base/slow',
        playlistId: 'p',
        onBytes: reports.add,
        stall: const Duration(milliseconds: 500));
    expect(channels, hasLength(16));
    expect(reports, isNotEmpty);
    expect(reports, orderedEquals([...reports]..sort()));
  });

  test('a download that goes silent gives up and keeps the old cache',
      () async {
    final temp = await Directory.systemTemp.createTemp('m3u_download_');
    addTearDown(() => temp.delete(recursive: true));
    final cache = File('${temp.path}/list.m3u');
    await cache.writeAsString('#EXTM3U\n${entry(9)}');

    final failure = M3uParser.fetchAndParse('$base/silent',
        playlistId: 'p',
        saveTo: cache.path,
        stall: const Duration(milliseconds: 300));
    await expectLater(
        failure,
        throwsA(isA<M3uStalledError>().having((e) => e.bytes, 'bytes',
            '#EXTM3U\n${entry(0)}${entry(1)}'.length)));
    expect(await cache.readAsString(), '#EXTM3U\n${entry(9)}');
    expect(await File('${cache.path}.part').exists(), isFalse);
  });

  test('a server that hangs up says so, without the link', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(socket.close);
    socket.listen((client) {
      client.listen((_) {});
      client.close();
    });
    final url = 'http://127.0.0.1:${socket.port}/get.php'
        '?username=me&password=secret';
    await expectLater(
        M3uParser.fetchAndParseInBackground(url, playlistId: 'p'),
        throwsA(predicate((e) =>
            '$e'.contains('closed the connection without answering') &&
            !'$e'.contains('secret'))));
  });

  test('loading shows how much has arrived', () async {
    SharedPreferences.setMockInitialValues({});
    final temp = await Directory.systemTemp.createTemp('m3u_download_');
    addTearDown(() => temp.delete(recursive: true));
    final storage = _DirStorage(temp);
    await storage.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    addTearDown(catalog.close);
    final phases = <String>[];
    late final PlaylistSession s;
    s = PlaylistSession(
      profile: PlaylistProfile(
          id: 'p',
          name: 'p',
          mode: 'm3u',
          m3uUrl: '$base/slow',
          sortOrder: 0,
          createdAt: DateTime(2026)),
      storage: storage,
      catalogDb: catalog,
      favoriteIds: () => {},
      favoriteSeriesIds: () => {},
      isRestrictedViewer: () => false,
      onNotify: () {
        final phase = s.loadingPhase;
        if (phase != null && (phases.isEmpty || phases.last != phase)) {
          phases.add(phase);
        }
      },
    );
    await s.loadFromUrl('$base/slow');
    expect(s.error, isNull);
    expect(s.channels, hasLength(16));
    expect(phases.first, 'Connecting to server...');
    expect(phases, contains('Downloading playlist... 0 MB'));
    // The download's line comes before the counts, never after them.
    expect(phases.indexOf('Downloading playlist... 0 MB'),
        lessThan(phases.indexWhere((p) => p.startsWith('Finding'))));
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
