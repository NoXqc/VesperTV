import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/m3u_import.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Windows / Linux: an M3U import writes from its own connection in a
/// background isolate (M3uImport). The app's own connection must be able
/// to write meanwhile (a favourite, another playlist's update) instead of
/// failing at once with "database is locked".
void main() {
  sqfliteFfiInit();
  late Directory temp;
  late CatalogDatabase catalog;
  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    temp = await Directory.systemTemp.createTemp('vesper-concurrent-');
    catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
  });
  tearDown(() async {
    await catalog.close();
    await temp.delete(recursive: true);
  });

  test('the app writes while an import writes from its own connection',
      () async {
    final list = StringBuffer('#EXTM3U\n');
    for (var n = 0; n < 60000; n++) {
      list
        ..writeln('#EXTINF:-1 tvg-id="e$n" group-title="Shows",'
            'Show ${n % 300} S01E${n ~/ 300}')
        ..writeln('http://example.test/series/u/p/$n.mkv');
    }
    final file = File('${temp.path}/list.m3u')
      ..writeAsStringSync(list.toString());

    final import = M3uImport.run(file.uri.toString(),
        playlistId: 'big',
        catalog: catalog,
        catalogPath: '${temp.path}/big_catalog.json');
    var writes = 0;
    var done = false;
    final importDone = import.whenComplete(() => done = true);
    while (!done) {
      await catalog.writeM3uRows(vod: [
        CatalogDatabase.vodRow(
            'Movies',
            Channel(
                id: 'other::m$writes',
                rawId: 'm$writes',
                playlistId: 'other',
                name: 'Movie $writes',
                group: 'Movies',
                url: 'http://example.test/movie/$writes.mkv',
                onDemand: true),
            importMark: 1)
      ]);
      writes++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final imported = await importDone;
    expect(imported.counts['series'], 60000);
    expect(writes, greaterThan(0));
    expect(await catalog.getVodCategoryCount('other', 'Movies'), writes);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
