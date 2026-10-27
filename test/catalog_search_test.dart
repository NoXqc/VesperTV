import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory temp;
  late String path;
  late CatalogDatabase catalog;
  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    temp = await Directory.systemTemp.createTemp('vesper-search-');
    path = '${temp.path}/catalog.db';
    catalog = CatalogDatabase(databasePath: path);
  });
  tearDown(() async {
    await catalog.close();
    expect(
        temp.absolute.path,
        startsWith(
            '${Directory.systemTemp.absolute.path}${Platform.pathSeparator}vesper-search-'));
    await temp.delete(recursive: true);
  });

  Channel movie(String id, String name, {String playlist = 'p'}) => Channel(
      id: '$playlist::$id',
      rawId: id,
      playlistId: playlist,
      name: name,
      group: 'Movies',
      url: 'https://example.test/film',
      onDemand: true);

  test(
      'entire SQLite movie/series catalog shares separator and accent matching',
      () async {
    await catalog.upsertVodCategory('p', 'Movies', [
      movie('1', 'Spider-Man: Homecoming'),
      movie('2', 'The Amazing Spider Man'),
      movie('3', 'Élite'),
      movie('4', 'Αθήνα')
    ]);
    await catalog.upsertVodCategory(
        'disabled', 'Movies', [movie('5', 'Spider-Man', playlist: 'disabled')]);
    await catalog.upsertSeriesCategory('p', 'Shows', [
      XtreamSeries(
          seriesId: 1,
          playlistId: 'p',
          name: 'Spider-Man: The Animated Series',
          categoryId: 'Shows')
    ]);
    for (final query in ['spiderman', 'spider man', 'Spider-Man']) {
      expect((await catalog.searchVod(query, ['p'])).map((m) => m.rawId),
          ['1', '2']);
      expect((await catalog.searchSeries(query, ['p'])).single.seriesId, 1);
    }
    expect((await catalog.searchVod('homecoming spider', ['p'])).single.rawId,
        '1');
    expect((await catalog.searchVod('elite', ['p'])).single.rawId, '3');
    expect((await catalog.searchVod('αθηνα', ['p'])).single.rawId, '4');
    expect(await catalog.searchVod('spiderman', []), isEmpty);
    expect((await catalog.searchVod('spiderman', ['p'], limit: 1)).length, 1);
    expect(await catalog.searchVod('%_', ['p']), isEmpty);
  });

  test(
      'v8 upgrade preserves cached titles and backfills beyond multiple batches',
      () async {
    final legacy = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 8,
            onCreate: (db, version) async {
              await db.execute(
                  'CREATE TABLE vod_channels (id TEXT PRIMARY KEY, playlist_id TEXT, '
                  'category_name TEXT, name TEXT, url TEXT, is_favorite INTEGER DEFAULT 0)');
              await db.execute(
                  'CREATE TABLE series_items (id TEXT PRIMARY KEY, series_id INTEGER, '
                  'playlist_id TEXT, category_name TEXT, name TEXT, is_favorite INTEGER DEFAULT 0)');
            }));
    final batch = legacy.batch();
    for (var i = 0; i < 1201; i++) {
      batch.insert('vod_channels', {
        'id': 'p::$i',
        'playlist_id': 'p',
        'category_name': 'Movies',
        'name': i == 1200 ? 'Spider-Man: Homecoming' : 'Other $i',
        'url': 'https://example.test/film'
      });
    }
    batch.insert('series_items', {
      'id': 'p::7',
      'series_id': 7,
      'playlist_id': 'p',
      'category_name': 'Shows',
      'name': 'Élite'
    });
    await batch.commit(noResult: true);
    await legacy.close();
    expect((await catalog.searchVod('spiderman', ['p'])).single.rawId, '1200');
    expect((await catalog.searchSeries('elite', ['p'])).single.seriesId, 7);
    final db = await databaseFactoryFfi.openDatabase(path);
    expect(
        (await db.rawQuery('SELECT COUNT(*) AS n FROM vod_channels'))
            .single['n'],
        1201);
    expect(
        (await db
                .rawQuery("SELECT name FROM vod_channels WHERE id = 'p::1200'"))
            .single['name'],
        'Spider-Man: Homecoming');
    expect(await db.getVersion(), 9);
  });

  test('catalog replacement refreshes normalized keys with the real title',
      () async {
    await catalog.upsertVodCategory('p', 'Movies', [movie('1', 'Spider-Man')]);
    await catalog.upsertVodCategory('p', 'Movies', [movie('1', 'Batman')]);
    expect(await catalog.searchVod('spiderman', ['p']), isEmpty);
    expect((await catalog.searchVod('batman', ['p'])).single.name, 'Batman');
  });
}
