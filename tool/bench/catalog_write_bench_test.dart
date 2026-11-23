// Catalog write benchmark for Windows / Linux (sqflite_common_ffi), not part
// of the normal test run. uzumaki (Discord, 2026-11-22, Linux): playlist
// loading very slow; his log had `SlowDb: upsertVod n=1610 541ms` (about
// 0.35 ms per movie) with 163,760 movies and 43,771 shows.
//
// Saves a catalog that size the way the Xtream warm-up does (one batch per
// category: delete its rows, insert each one) while a reader asks one small
// count every 25 ms, as the TV / guide / Movies pages do, and reports how
// long the writes took and how long the reads waited.
//
//   BENCH_MODE=shared  - today: every database on the one sqflite FFI worker
//   BENCH_MODE=direct  - no worker: SQLite on this isolate (the raw cost)
//   BENCH_MODE=split   - writes on their own isolate + connection (WAL),
//                        reads on the shared worker
//   BENCH_SCALE=0.25   - a quarter of the catalog (quick runs)
//
//   flutter test tool/bench/catalog_write_bench_test.dart
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/xtream_series.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/utils/title_search.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _playlist = 'p1';

/// Category sizes like a big Xtream panel: a few huge categories (uzumaki's
/// slow batches were 1,396-2,102 movies), the rest a few hundred.
List<int> _sizes(int total, int categories,
    {int big = 30, int bigSize = 2000}) {
  final rest = total - big * bigSize;
  final small = categories - big;
  return [
    for (var i = 0; i < categories; i++)
      i < big ? bigSize : (rest ~/ small) + (i < rest % small + big ? 1 : 0),
  ];
}

List<Channel> _movies(int category, int count, int start) => [
      for (var i = 0; i < count; i++)
        Channel(
          id: '$_playlist::xt_vod_${start + i}',
          rawId: 'xt_vod_${start + i}',
          playlistId: _playlist,
          name: 'Movie title number ${start + i} (${1990 + i % 35}) 4K',
          group: 'Category $category',
          url: 'http://provider.example.com:8080/movie/user123/pass456/'
              '${start + i}.mkv',
          logoUrl: 'https://image.tmdb.org/t/p/w600_and_h900_bestv2/'
              '${(start + i).toRadixString(36).padLeft(24, 'x')}.jpg',
          onDemand: true,
          rating: '${5 + i % 5}.${i % 10}',
          addedAt: DateTime(2026, 1, 1).add(Duration(minutes: start + i)),
          tmdbId: '${100000 + start + i}',
          releaseDate: DateTime(1990 + i % 35, 1 + i % 12, 1),
        ),
    ];

List<XtreamSeries> _shows(int category, int count, int start) => [
      for (var i = 0; i < count; i++)
        XtreamSeries(
          seriesId: start + i,
          playlistId: _playlist,
          name: 'Show title number ${start + i}',
          categoryId: 'Shows $category',
          coverUrl: 'https://image.tmdb.org/t/p/w600_and_h900_bestv2/'
              '${(start + i).toRadixString(36).padLeft(24, 'y')}.jpg',
          rating: '${5 + i % 5}.${i % 10}',
          addedAt: DateTime(2026, 1, 1).add(Duration(minutes: start + i)),
          tmdbId: '${200000 + start + i}',
        ),
    ];

/// Writes the whole catalog through [db]; per-batch ms back.
Future<List<int>> _writeAll(CatalogDatabase db, double scale) async {
  final batches = <int>[];
  final movieSizes = _sizes((163760 * scale).round(), (512 * scale).ceil(),
      big: (30 * scale).ceil());
  var n = 0;
  for (var c = 0; c < movieSizes.length; c++) {
    final items = _movies(c, movieSizes[c], n);
    n += items.length;
    final sw = Stopwatch()..start();
    await db.upsertVodCategory(_playlist, 'Category $c', items);
    batches.add(sw.elapsedMilliseconds);
  }
  final showSizes =
      _sizes((43771 * scale).round(), (278 * scale).ceil(), big: 0);
  n = 0;
  for (var c = 0; c < showSizes.length; c++) {
    final items = _shows(c, showSizes[c], n);
    n += items.length;
    final sw = Stopwatch()..start();
    await db.upsertSeriesCategory(_playlist, 'Shows $c', items);
    batches.add(sw.elapsedMilliseconds);
  }
  return batches;
}

/// The split writer: its own isolate, its own connection, no FFI worker.
Future<List<int>> _writeInIsolate(String path, double scale) =>
    Isolate.run(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final db = CatalogDatabase(databasePath: path);
      try {
        return await _writeAll(db, scale);
      } finally {
        await db.close();
      }
    });

String _stats(String label, List<int> values) {
  if (values.isEmpty) return '$label: none';
  final s = [...values]..sort();
  int at(double q) => s[math.min(s.length - 1, (q * s.length).floor())];
  return '$label: n=${s.length} sum=${s.fold<int>(0, (a, b) => a + b)} p50=${at(.5)} p95=${at(.95)} '
      'max=${s.last} over100ms=${s.where((v) => v > 100).length}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog writes vs reads', () async {
    final mode = Platform.environment['BENCH_MODE'] ?? 'shared';
    final scale =
        double.tryParse(Platform.environment['BENCH_SCALE'] ?? '') ?? 1;
    sqfliteFfiInit();
    databaseFactory =
        mode == 'direct' ? databaseFactoryFfiNoIsolate : databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('vesper_bench_');
    final path = '${dir.path}/catalog.db';
    final db = CatalogDatabase(databasePath: path);
    // Open + create the tables before timing anything.
    await db.getVodCategoryCount(_playlist, 'Category 0');
    await db.upsertVodCategory(_playlist, 'Category 0', _movies(0, 1, 0));

    // Dart's share: building the rows (search key, maps) without SQLite.
    final build = Stopwatch()..start();
    var built = 0;
    for (var c = 0; c < (64 * scale).ceil(); c++) {
      for (final m in _movies(c, 320, c * 320)) {
        built += CatalogDatabase.vodRow('Category $c', m).length;
      }
    }
    final buildUs = build.elapsedMicroseconds / ((64 * scale).ceil() * 320);
    final sample = _movies(0, 20000, 0);
    final rowSw = Stopwatch()..start();
    for (final m in sample) {
      built += CatalogDatabase.vodRow('Category 0', m).length;
    }
    final rowUs = rowSw.elapsedMicroseconds / sample.length;
    final keySw = Stopwatch()..start();
    for (final m in sample) {
      built += TitleSearch.key(m.name).length;
    }
    final keyUs = keySw.elapsedMicroseconds / sample.length;
    // ignore: avoid_print
    print('ROWBUILD ${buildUs.toStringAsFixed(1)}us per movie incl. making it; '
        'vodRow ${rowUs.toStringAsFixed(1)}us, of which search key '
        '${keyUs.toStringAsFixed(1)}us ($built)');

    final reads = <int>[];
    var writing = true;
    Future<void> reader() async {
      while (writing) {
        final sw = Stopwatch()..start();
        await db.getVodCategoryCount(_playlist, 'Category 1');
        reads.add(sw.elapsedMilliseconds);
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }

    final total = Stopwatch()..start();
    final readerDone = reader();
    final batches = mode == 'split'
        ? await _writeInIsolate(path, scale)
        : await _writeAll(db, scale);
    final ms = total.elapsedMilliseconds;
    writing = false;
    await readerDone;
    final rows = (163760 * scale).round() + (43771 * scale).round();
    // ignore: avoid_print
    print('RESULT mode=$mode scale=$scale cpus=${Platform.numberOfProcessors} '
        'rows=$rows total=${ms}ms perRow=${(ms * 1000 / rows).round()}us\n'
        '  ${_stats('write batch ms', batches)}\n'
        '  ${_stats('read wait ms', reads)}');
    await db.close();
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
