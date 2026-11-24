import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Rows are read and replaced by playlist + category: with many playlists
/// the category-only index scanned every playlist's copy (LOG-6LYY3R).
void main() {
  sqfliteFfiInit();
  late Directory temp;
  late CatalogDatabase catalog;
  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    temp = await Directory.systemTemp.createTemp('vesper-index-');
    catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
  });
  tearDown(() async {
    await catalog.close();
    await temp.delete(recursive: true);
  });

  test('simultaneous first reads share one open (LOG-2L5D3S)', () async {
    final logs = <String>[];
    final print = debugPrint;
    debugPrint = (m, {wrapWidth}) => logs.add('$m');
    try {
      final reads = await Future.wait(
          List.generate(50, (i) => catalog.getVodCategory('p', 'C$i')));
      expect(reads.every((r) => r.isEmpty), isTrue);
    } finally {
      debugPrint = print;
    }
    expect(logs.where((l) => l.contains('reopening from scratch')), isEmpty);
  });

  test('row reads and replaces use the playlist + category index', () async {
    await catalog.upsertVodCategory('p', 'Movies', [
      Channel(
          id: 'p::1',
          rawId: '1',
          playlistId: 'p',
          name: 'A film',
          group: 'Movies',
          url: 'https://example.test/1',
          onDemand: true),
    ]);
    expect((await catalog.getVodCategory('p', 'Movies')).single.name, 'A film');

    final db = await databaseFactoryFfi.openDatabase('${temp.path}/catalog.db');
    try {
      Future<String> plan(String sql) async =>
          (await db.rawQuery('EXPLAIN QUERY PLAN $sql', ['Movies', 'p']))
              .map((r) => r['detail'])
              .join(' ');
      for (final table in ['vod_channels', 'series_items']) {
        final index = table == 'vod_channels'
            ? 'idx_vod_playlist_cat'
            : 'idx_series_playlist_cat';
        expect(
            await plan(
                'SELECT * FROM $table WHERE category_name = ? AND playlist_id = ?'),
            contains(index));
        expect(
            await plan(
                'DELETE FROM $table WHERE category_name = ? AND playlist_id = ?'),
            contains(index));
      }
    } finally {
      await db.close();
    }
  });

  // uzumaki (Linux, 2026-11-22): Update Content saved each movie with its own
  // statement into the table and five indexes. Now many rows per INSERT (as
  // the M3U import) and two fewer indexes: 2.4x faster on a slow CPU.
  Channel movie(int n, String group) => Channel(
      id: 'p::$n',
      rawId: '$n',
      playlistId: 'p',
      name: 'Film $n',
      group: group,
      url: 'https://example.test/$n',
      onDemand: true,
      rating: '7.$n',
      addedAt: DateTime(2026, 1, 1).add(Duration(minutes: n)));

  test('a big category is saved whole, many rows per statement', () async {
    // More rows than one statement takes (999 values / columns).
    await catalog.upsertVodCategory(
        'p', 'Action', [for (var i = 0; i < 250; i++) movie(i, 'Action')]);
    expect(await catalog.getVodCategoryCount('p', 'Action'), 250);
    final rows = await catalog.getVodCategory('p', 'Action');
    final f42 = rows.firstWhere((c) => c.id == 'p::42');
    expect(f42.rating, '7.42');
    expect(f42.addedAt, DateTime(2026, 1, 1).add(const Duration(minutes: 42)));

    // A refresh replaces the category: removed titles go, new ones come.
    await catalog.upsertVodCategory(
        'p', 'Action', [for (var i = 100; i < 160; i++) movie(i, 'Action')]);
    expect(await catalog.getVodCategoryCount('p', 'Action'), 60);

    // A title listed in two categories ends where it was saved last, as
    // before (INSERT OR REPLACE on the id).
    await catalog.upsertVodCategory('p', 'Drama', [movie(120, 'Drama')]);
    expect(await catalog.getVodCategoryCount('p', 'Action'), 59);
    expect(await catalog.getVodCategoryCount('p', 'Drama'), 1);
  });

  test('shows are saved whole too', () async {
    final shows = [
      for (var i = 0; i < 180; i++)
        XtreamSeries(
            seriesId: i,
            playlistId: 'p',
            name: 'Show $i',
            categoryId: 'Kids',
            rating: '6.$i')
    ];
    await catalog.upsertSeriesCategory('p', 'Kids', shows);
    expect(await catalog.getSeriesCategoryCount('p', 'Kids'), 180);
    final again = await catalog.getSeriesCategory('p', 'Kids');
    expect(again.firstWhere((s) => s.seriesId == 7).rating, '6.7');
  });

  // LOG-GT8TZG (Onn box, 277k movies): every profile switch's "Recently
  // added" read and sorted every row of the enabled playlists (3-4.5 s each,
  // queued 3-4 deep: rows and search waited up to a minute).
  test('recently added reads each playlist newest first, no full sort',
      () async {
    Channel film(String playlist, int n, String group) => Channel(
        id: '$playlist::$n',
        rawId: '$n',
        playlistId: playlist,
        name: 'Film $playlist$n',
        group: group,
        url: 'https://example.test/$playlist/$n',
        onDemand: true,
        addedAt: DateTime(2026, 1, 1).add(Duration(minutes: n)));
    await catalog.upsertVodCategory('a', 'Action',
        [for (var i = 0; i < 30; i++) film('a', i * 2, 'Action')]);
    await catalog.upsertVodCategory('b', 'Drama',
        [for (var i = 0; i < 30; i++) film('b', i * 2 + 1, 'Drama')]);
    await catalog
        .upsertVodCategory('b', 'XXX Night', [film('b', 999, 'XXX Night')]);
    await catalog.upsertVodCategory('c', 'Off', [film('c', 500, 'Off')]);

    final newest = await catalog.getRecentlyAddedVod(['a', 'b'], limit: 5);
    expect([for (final c in newest) c.id],
        ['b::59', 'a::58', 'b::57', 'a::56', 'b::55'],
        reason: 'both playlists merged by date; the adult category and the '
            'playlist not asked for left out');

    await catalog.upsertSeriesCategory('a', 'Kids', [
      for (var i = 0; i < 4; i++)
        XtreamSeries(
            seriesId: i,
            playlistId: 'a',
            name: 'Show $i',
            categoryId: 'Kids',
            addedAt: DateTime(2026, 2, i + 1)),
    ]);
    expect([
      for (final s in await catalog.getRecentlyAddedSeries(['a'])) s.seriesId
    ], [
      3,
      2,
      1,
      0
    ]);

    final db = await databaseFactoryFfi.openDatabase('${temp.path}/catalog.db');
    try {
      for (final (table, index) in [
        ('vod_channels', 'idx_vod_playlist_added'),
        ('series_items', 'idx_series_playlist_added'),
      ]) {
        final plan = (await db.rawQuery(
                'EXPLAIN QUERY PLAN SELECT * FROM $table WHERE playlist_id = ? '
                "AND added_at IS NOT NULL AND category_name NOT LIKE '%XXX%' "
                'ORDER BY added_at DESC LIMIT 800',
                ['a']))
            .map((r) => r['detail'])
            .join(' ');
        expect(plan, contains(index));
        expect(plan, isNot(contains('TEMP B-TREE')));
      }
    } finally {
      await db.close();
    }
  });

  test('the single-column indexes are gone, also from an older database',
      () async {
    await catalog.getVodCategoryCount('p', 'x');
    await catalog.close();
    // An install from before: put them back as the old code had them.
    var db = await databaseFactoryFfi.openDatabase('${temp.path}/catalog.db');
    await db.execute(
        'CREATE INDEX idx_vod_category ON vod_channels(category_name)');
    await db.execute(
        'CREATE INDEX idx_series_playlist ON series_items(playlist_id)');
    await db.execute('CREATE INDEX idx_vod_added ON vod_channels(added_at)');
    await db.close();

    catalog = CatalogDatabase(databasePath: '${temp.path}/catalog.db');
    await catalog.getVodCategoryCount('p', 'x');
    db = await databaseFactoryFfi.openDatabase('${temp.path}/catalog.db');
    try {
      final names = [
        for (final r in await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type = 'index' "
                "AND name LIKE 'idx_%'"))
          r['name'] as String
      ];
      expect(names,
          containsAll(['idx_vod_playlist_cat', 'idx_series_playlist_cat']));
      expect(
          names,
          isNot(anyOf(
              contains('idx_vod_category'),
              contains('idx_vod_playlist'),
              contains('idx_series_category'),
              contains('idx_series_playlist'),
              contains('idx_vod_added'),
              contains('idx_series_added'))));
      expect(names,
          containsAll(['idx_vod_playlist_added', 'idx_series_playlist_added']));
      // Playlist-only reads still use an index (a covering one's prefix).
      final plan = (await db.rawQuery(
              'EXPLAIN QUERY PLAN SELECT playlist_id, COUNT(*) FROM vod_channels '
              'GROUP BY playlist_id'))
          .map((r) => r['detail'])
          .join(' ');
      expect(plan, matches(RegExp('idx_vod_playlist_(cat|added)')));
    } finally {
      await db.close();
    }
  });
}
