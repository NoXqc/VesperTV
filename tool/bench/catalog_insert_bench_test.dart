// Catalog insert cost: four ways to save the same catalog (uzumaki's size:
// 163,760 movies in 512 categories, 43,771 shows in 278), on SQLite through
// sqflite_common_ffi without the worker isolate (the database's own cost).
//
//   today   - one INSERT OR REPLACE per row in a batch (CatalogDatabase now)
//   lean    - same, without the two single-column indexes the
//             (playlist_id, category_name) index already covers
//   multi   - many rows per INSERT OR REPLACE (chunks of BENCH_CHUNK rows)
//   both    - lean + multi
//
//   BENCH_SCALE=0.25 flutter test tool/bench/catalog_insert_bench_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _playlist = 'p1';

List<int> _sizes(int total, int categories,
    {int big = 30, int bigSize = 2000}) {
  final rest = total - big * bigSize;
  final small = categories - big;
  return [
    for (var i = 0; i < categories; i++)
      i < big ? bigSize : (rest ~/ small) + (i < rest % small + big ? 1 : 0),
  ];
}

Map<String, Object?> _movieRow(int category, int n, int i) =>
    CatalogDatabase.vodRow(
        'Category $category',
        Channel(
          id: '$_playlist::xt_vod_$n',
          rawId: 'xt_vod_$n',
          playlistId: _playlist,
          name: 'Movie title number $n (${1990 + i % 35}) 4K',
          group: 'Category $category',
          url: 'http://provider.example.com:8080/movie/user123/pass456/$n.mkv',
          logoUrl: 'https://image.tmdb.org/t/p/w600_and_h900_bestv2/'
              '${n.toRadixString(36).padLeft(24, 'x')}.jpg',
          onDemand: true,
          rating: '${5 + i % 5}.${i % 10}',
          addedAt: DateTime(2026, 1, 1).add(Duration(minutes: n)),
          tmdbId: '${100000 + n}',
          releaseDate: DateTime(1990 + i % 35, 1 + i % 12, 1),
        ));

Map<String, Object?> _showRow(int category, int n, int i) =>
    CatalogDatabase.seriesRow(
        'Shows $category',
        XtreamSeries(
          seriesId: n,
          playlistId: _playlist,
          name: 'Show title number $n',
          categoryId: 'Shows $category',
          coverUrl: 'https://image.tmdb.org/t/p/w600_and_h900_bestv2/'
              '${n.toRadixString(36).padLeft(24, 'y')}.jpg',
          rating: '${5 + i % 5}.${i % 10}',
          addedAt: DateTime(2026, 1, 1).add(Duration(minutes: n)),
          tmdbId: '${200000 + n}',
        ));

/// Saves one category the way [CatalogDatabase] does (delete, then insert),
/// [chunk] rows per INSERT (1 = today's one statement per row).
Future<void> _save(Database db, String table, String category,
    List<Map<String, Object?>> rows, int chunk) async {
  final batch = db.batch();
  batch.delete(table,
      where: 'category_name = ? AND playlist_id = ?',
      whereArgs: [category, _playlist]);
  if (chunk <= 1) {
    for (final r in rows) {
      batch.insert(table, r, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  } else {
    final columns = rows.first.keys.toList();
    final one = '(${List.filled(columns.length, '?').join(',')})';
    for (var start = 0; start < rows.length; start += chunk) {
      final part = rows.sublist(start, (start + chunk).clamp(0, rows.length));
      batch.rawInsert(
          'INSERT OR REPLACE INTO $table (${columns.join(',')}) VALUES '
          '${List.filled(part.length, one).join(',')}',
          [for (final r in part) ...columns.map((c) => r[c])]);
    }
  }
  await batch.commit(noResult: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('insert cost', () async {
    final scale =
        double.tryParse(Platform.environment['BENCH_SCALE'] ?? '') ?? 1;
    final chunkSize =
        int.tryParse(Platform.environment['BENCH_CHUNK'] ?? '') ?? 100;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final movieSizes = _sizes((163760 * scale).round(), (512 * scale).ceil(),
        big: (30 * scale).ceil());
    final showSizes =
        _sizes((43771 * scale).round(), (278 * scale).ceil(), big: 0);
    // Rows built once, outside the timing: only the database is measured.
    var n = 0;
    final movies = [
      for (var c = 0; c < movieSizes.length; c++)
        [for (var i = 0; i < movieSizes[c]; i++) _movieRow(c, n++, i)],
    ];
    n = 0;
    final shows = [
      for (var c = 0; c < showSizes.length; c++)
        [for (var i = 0; i < showSizes[c]; i++) _showRow(c, n++, i)],
    ];
    final total = n + movies.fold<int>(0, (s, l) => s + l.length);

    for (final (name, lean, chunk) in [
      ('today', false, 1),
      ('lean', true, 1),
      ('multi', false, chunkSize),
      ('both', true, chunkSize),
    ]) {
      final dir = await Directory.systemTemp.createTemp('vesper_ins_');
      final path = '${dir.path}/catalog.db';
      // The real schema, indexes and pragmas.
      final catalog = CatalogDatabase(databasePath: path);
      await catalog.getVodCategoryCount(_playlist, 'x');
      await catalog.close();
      final db = await openDatabase(path, onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.rawQuery('PRAGMA synchronous=NORMAL');
      });
      if (lean) {
        for (final index in const [
          'idx_vod_category',
          'idx_vod_playlist',
          'idx_series_category',
          'idx_series_playlist',
        ]) {
          await db.execute('DROP INDEX IF EXISTS $index');
        }
      }
      // Twice: the first fill, then a refresh (every category replaced).
      final times = <int>[];
      var biggest = 0;
      for (var round = 0; round < 2; round++) {
        final sw = Stopwatch()..start();
        for (var c = 0; c < movies.length; c++) {
          final b = Stopwatch()..start();
          await _save(db, 'vod_channels', 'Category $c', movies[c], chunk);
          if (round == 0 && b.elapsedMilliseconds > biggest) {
            biggest = b.elapsedMilliseconds;
          }
        }
        for (var c = 0; c < shows.length; c++) {
          await _save(db, 'series_items', 'Shows $c', shows[c], chunk);
        }
        times.add(sw.elapsedMilliseconds);
      }
      final count =
          (await db.rawQuery('SELECT (SELECT COUNT(*) FROM vod_channels) + '
                  '(SELECT COUNT(*) FROM series_items) AS n'))
              .first['n'];
      await db.close();
      await dir.delete(recursive: true);
      // ignore: avoid_print
      print('INSERT $name chunk=$chunk rows=$total(saved $count) '
          'first=${times[0]}ms (${(times[0] * 1000 / total).round()}us/row, '
          'biggest batch ${biggest}ms) refresh=${times[1]}ms '
          '(${(times[1] * 1000 / total).round()}us/row)');
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
