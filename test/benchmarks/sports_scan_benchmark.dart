// Run manually: flutter test test/benchmarks/sports_scan_benchmark.dart
// Synthetic desktop timings, never a substitute for the Shield/Formuler log.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:nox_iptv/services/epg_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('245k programme synthetic guide, 298 terms', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute(
        'CREATE TABLE programme (channel_id TEXT, start INTEGER, stop INTEGER, title TEXT, descr TEXT, source_url TEXT, gen INTEGER, PRIMARY KEY(channel_id,start)) WITHOUT ROWID');
    await db.execute('CREATE INDEX idx_programme_stop ON programme(stop)');
    final from = DateTime.utc(2026, 10, 24).millisecondsSinceEpoch;
    final epg = EpgDatabase(database: db);
    for (var offset = 0; offset < 245000; offset += 1000) {
      await epg.insertBatch([
        for (var i = offset; i < offset + 1000; i++)
          (
            channelId: 'c${i % 7705}',
            startMs: from + i ~/ 7705 * 10 * 3600000,
            stopMs: from + i ~/ 7705 * 10 * 3600000 + 3600000,
            title: 'Sport programme team${i % 298} vs team${(i + 1) % 298}',
            description: null
          )
      ], 'synthetic', 1);
    }
    final terms = [for (var i = 0; i < 298; i++) 'team$i '];
    final before = Stopwatch()..start();
    final old = await db.rawQuery(
        'SELECT channel_id,start,stop,title FROM programme WHERE stop > ? AND start >= ? AND start < ? AND (${List.filled(terms.length, 'title LIKE ?').join(' OR ')})',
        [from, from, from + 36 * 3600000, for (final t in terms) '%$t%']);
    final oldMs = before.elapsedMilliseconds;
    final watch = Stopwatch()..start();
    final rows =
        await epg.programmesStartingWithTitle(from, from + 36 * 3600000, terms);
    final coldMs = watch.elapsedMilliseconds;
    watch.reset();
    final warm = await epg.programmesStartingWithTitle(
        from, from + 36 * 3600000, terms.take(14).toList());
    final warmMs = watch.elapsedMilliseconds;
    // The equivalent time window produces exactly the old matching candidates.
    final actual = rows.map((r) => (r.channelId, r.startMs)).toSet();
    final expected = old.map((r) => (r['channel_id'], r['start'])).toSet();
    expect(actual.length, expected.length);
    expect(actual.difference(expected), isEmpty);
    debugPrint('Sports benchmark: 245000 rows/298 terms: oldSQL=$oldMs ms, '
        'indexedCold=$coldMs ms, cached14Terms=$warmMs ms, '
        'matches=${rows.length}/${warm.length} (desktop synthetic)');
  });
}
