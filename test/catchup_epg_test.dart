import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/epg_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Catch-up channels keep days of past programmes; every other channel
/// keeps the usual 2 h (dev-notes/catchup-plan.md, C3).
void main() {
  sqfliteFfiInit();

  final now = DateTime.now().toUtc();
  String t(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}'
        '${two(d.hour)}${two(d.minute)}${two(d.second)} +0000';
  }

  String prog(String ch, Duration startAgo, Duration length, String title) {
    final start = now.subtract(startAgo);
    return '<programme start="${t(start)}" stop="${t(start.add(length))}" '
        'channel="$ch"><title>$title</title></programme>';
  }

  String feed() {
    final b = StringBuffer('<?xml version="1.0"?><tv>');
    for (final ch in ['CU.us', 'plain.us']) {
      b
        ..write(prog(
            ch, const Duration(days: 9), const Duration(hours: 1), '$ch 9d'))
        ..write(prog(
            ch, const Duration(days: 2), const Duration(hours: 1), '$ch 2d'))
        ..write(prog(
            ch, const Duration(hours: 10), const Duration(hours: 1), '$ch 10h'))
        ..write(prog(ch, const Duration(minutes: 90), const Duration(hours: 1),
            '$ch 90m'))
        ..write(prog(ch, const Duration(minutes: 10), const Duration(hours: 1),
            '$ch now'));
    }
    b.write('</tv>');
    return b.toString();
  }

  late Database db;
  late EpgDatabase epgDb;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await EpgDatabase.createSchema(db);
    epgDb = EpgDatabase(database: db);
  });

  tearDown(() => db.close());

  Future<EpgService> refreshed() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final service = EpgService(storage, database: epgDb)
      ..catchupDaysProvider = () => {'cu.us': 3};
    await http.runWithClient(
        () => service.refresh('http://epg/x.xml', knownChannelIds: const {}),
        () => MockClient((_) async => http.Response(feed(), 200)));
    return service;
  }

  Future<List<String>> titles(EpgService s, String id) async {
    s.getPrograms(id);
    for (var i = 0; i < 50 && s.guideRowsLoaded.value == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return [for (final p in s.getPrograms(id)) p.title];
  }

  test('parse keeps a catch-up channel\'s past, not a plain one\'s', () async {
    final s = await refreshed();
    final rows = await epgDb.programmesFor(['cu.us', 'plain.us'], 0);
    expect([for (final r in rows['cu.us']!) r.title],
        ['CU.us 2d', 'CU.us 10h', 'CU.us 90m', 'CU.us now']);
    expect([for (final r in rows['plain.us']!) r.title],
        ['plain.us 90m', 'plain.us now']);
    expect(await titles(s, 'CU.us'),
        ['CU.us 2d', 'CU.us 10h', 'CU.us 90m', 'CU.us now']);
    s.dispose();
  });

  test('programsBetween returns the past window only', () async {
    final s = await refreshed();
    await titles(s, 'cu.us');
    final from = now.subtract(const Duration(hours: 12)).toLocal();
    final to = now.subtract(const Duration(hours: 2)).toLocal();
    expect([for (final p in s.programsBetween('cu.us', from, to)) p.title],
        ['CU.us 10h']);
    s.dispose();
  });

  test('prune keeps catch-up rows to their own horizon', () async {
    final ms = now.millisecondsSinceEpoch;
    const hour = 3600000;
    await epgDb.insertBatch([
      for (final ch in ['cu.us', 'plain.us'])
        for (final agoH in [100, 30, 5])
          (
            channelId: ch,
            startMs: ms - agoH * hour,
            stopMs: ms - agoH * hour + hour,
            title: '$ch $agoH',
            description: null,
          ),
    ], 'src', 1);
    await epgDb
        .deleteEndedBefore(ms - 2 * hour, keep: {'cu.us': ms - 72 * hour});
    final rows = await epgDb.programmesFor(['cu.us', 'plain.us'], 0);
    expect([for (final r in rows['cu.us']!) r.title], ['cu.us 30', 'cu.us 5']);
    expect(rows['plain.us'], isNull);
    // Without catch-up channels it is the old single delete.
    await epgDb.deleteEndedBefore(ms - 2 * hour);
    expect(await epgDb.programmesFor(['cu.us'], 0), isEmpty);
  });
}
