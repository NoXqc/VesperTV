import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/epg_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The launch's "on in the next hours" slice (EpgService preloads it for
/// every channel): bounded on the (stop, start) index, no ORDER BY
/// (owner, 2026-11-19: 13 s on the Homatics before).
void main() {
  sqfliteFfiInit();

  late Database db;
  late EpgDatabase epg;
  const hour = Duration.millisecondsPerHour;
  final now = DateTime(2026, 11, 19, 12).millisecondsSinceEpoch;

  EpgRow row(String ch, int startH, int lengthH, String title) => (
        channelId: ch,
        startMs: now + startH * hour,
        stopMs: now + (startH + lengthH) * hour,
        title: title,
        description: null,
      );

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await EpgDatabase.createSchema(db);
    epg = EpgDatabase(database: db);
    await epg.insertBatch([
      row('a', -3, 1, 'ended'),
      row('a', -1, 2, 'on now'),
      row('a', 1, 1, 'next'),
      row('a', 5, 1, 'later'),
      row('b', -20, 30, 'long filler'),
      row('c', 10, 1, 'tonight'),
    ], 'src', 1);
  });

  tearDown(() => db.close());

  test('programmes overlapping the window, every channel', () async {
    final slice = await epg.programmesBetween(now, now + 4 * hour);
    expect(slice.keys.toSet(), {'a', 'b'});
    expect(slice['a']!.map((r) => r.title).toSet(), {'on now', 'next'});
    expect(slice['b']!.single.title, 'long filler');
  });

  test('the schema has the (stop, start) index, not the old stop one',
      () async {
    final names = (await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type = 'index'"))
        .map((r) => r['name'])
        .toSet();
    expect(names, contains('idx_programme_stop_start'));
    expect(names, isNot(contains('idx_programme_stop')));
  });

  test('the slice query runs on the (stop, start) index, no sort', () async {
    final plan = (await db.rawQuery(
            'EXPLAIN QUERY PLAN SELECT channel_id, start, stop, title, '
            'CASE WHEN start <= ? THEN descr END AS descr FROM programme '
            'WHERE stop > ? AND stop < ? AND start < ? '
            'AND (stop > ? OR (stop = ? AND (start > ? '
            'OR (start = ? AND channel_id > ?)))) '
            'ORDER BY stop, start, channel_id LIMIT 3000',
            [now, now, now + 52 * hour, now + 4 * hour, now, now, 0, 0, '']))
        .map((r) => '${r['detail']}')
        .join(' | ');
    expect(plan, contains('idx_programme_stop_start'));
    expect(plan, isNot(contains('TEMP B-TREE')));
  });

  test('descriptions only for what is on now', () async {
    await epg.insertBatch([
      (
        channelId: 'd',
        startMs: now - hour,
        stopMs: now + hour,
        title: 'on',
        description: 'about the show on now',
      ),
      (
        channelId: 'd',
        startMs: now + hour,
        stopMs: now + 2 * hour,
        title: 'next',
        description: 'about the next one',
      ),
    ], 'src2', 1);
    final d = (await epg.programmesBetween(now, now + 4 * hour))['d']!;
    expect({for (final r in d) r.title: r.description},
        {'on': 'about the show on now', 'next': null});
  });

  test('pages: every row once, across page boundaries', () async {
    await epg.insertBatch([
      for (var i = 0; i < 7000; i++)
        (
          channelId: 'p$i',
          startMs: now - hour,
          stopMs: now + hour + (i % 3) * 60000,
          title: 't$i',
          description: null,
        ),
    ], 'src3', 1);
    final slice = await epg.programmesBetween(now, now + 4 * hour);
    expect(slice.keys.where((k) => k.startsWith('p')).length, 7000);
    expect(slice.values.every((l) => l.length == l.toSet().length), isTrue);
  });

  test('channels with guide data still answers from the new index', () async {
    expect(await epg.channelIdsWithData(now), {'a', 'b', 'c'});
  });
}
