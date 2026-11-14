import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/services/epg_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// More guides for one playlist (a Windows viewer, 2026-11-14): guides load
/// in order and a channel an earlier guide fills keeps it, so a second
/// guide only fills the gaps instead of mixing two schedules in one row.
void main() {
  sqfliteFfiInit();

  final now = DateTime.now().toUtc();
  String t(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}'
        '${two(d.hour)}${two(d.minute)}${two(d.second)} +0000';
  }

  /// Programmes on [ch] starting [offsetMin] minutes past the hour, so two
  /// guides' rows for one channel don't share a start (they would replace
  /// each other in the database instead of mixing).
  String feed(Map<String, String> titleByChannel, {int offsetMin = 0}) {
    final b = StringBuffer('<?xml version="1.0"?><tv>');
    final hour = DateTime.utc(now.year, now.month, now.day, now.hour);
    titleByChannel.forEach((ch, title) {
      for (var h = -1; h < 3; h++) {
        final start = hour.add(Duration(hours: h, minutes: offsetMin));
        b.write('<programme start="${t(start)}" '
            'stop="${t(start.add(const Duration(hours: 1)))}" '
            'channel="$ch"><title>$title $h</title></programme>');
      }
    });
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

  Future<EpgService> refreshAll(
      List<EpgSource> sources, Map<String, String> bodies,
      {List<String>? requested}) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final service = EpgService(storage, database: epgDb)
      ..startAutoRefresh(24 * 60, () => sources)
      ..stopAutoRefresh();
    await http.runWithClient(
        service.refreshAll,
        () => MockClient((request) async {
              requested?.add(request.url.toString());
              return http.Response(bodies[request.url.toString()]!, 200);
            }));
    return service;
  }

  Future<Set<String>> titles(String channel) async {
    final rows = await epgDb.programmesFor([channel], 0);
    return {for (final r in rows[channel] ?? const <dynamic>[]) r.title};
  }

  test('the first guide keeps its channels; the next one fills the gaps',
      () async {
    final s = await refreshAll([
      (url: 'http://main/x.xml', knownChannelIds: const <String>{}),
      (url: 'http://extra/ca.xml', knownChannelIds: const <String>{}),
    ], {
      'http://main/x.xml': feed({'tsn1.ca': 'Main'}),
      'http://extra/ca.xml':
          feed({'tsn1.ca': 'Extra', 'cbc.ca': 'CBC'}, offsetMin: 30),
    });
    expect((await titles('tsn1.ca')).every((t) => t.startsWith('Main')), isTrue,
        reason: 'no Extra row mixed into a channel the main guide fills');
    expect(await titles('cbc.ca'), isNotEmpty,
        reason: 'the extra guide fills a channel the main one lacks');
    s.dispose();
  });

  test('order is the priority', () async {
    final s = await refreshAll([
      (url: 'http://extra/ca.xml', knownChannelIds: const <String>{}),
      (url: 'http://main/x.xml', knownChannelIds: const <String>{}),
    ], {
      'http://main/x.xml': feed({'tsn1.ca': 'Main'}),
      'http://extra/ca.xml':
          feed({'tsn1.ca': 'Extra', 'cbc.ca': 'CBC'}, offsetMin: 30),
    });
    expect(
        (await titles('tsn1.ca')).every((t) => t.startsWith('Extra')), isTrue);
    s.dispose();
  });

  test('two playlists sharing a guide: one download, both keep their channels',
      () async {
    final requested = <String>[];
    final s = await refreshAll([
      (url: 'http://shared/x.xml', knownChannelIds: {'a.us'}),
      (url: 'http://shared/x.xml', knownChannelIds: {'b.us'}),
    ], {
      'http://shared/x.xml': feed({'a.us': 'A', 'b.us': 'B', 'c.us': 'C'}),
    }, requested: requested);
    expect(requested, ['http://shared/x.xml']);
    expect(await titles('a.us'), isNotEmpty);
    expect(await titles('b.us'), isNotEmpty,
        reason: 'the second pass used to drop the first one as stale');
    expect(await titles('c.us'), isEmpty);
    s.dispose();
  });
}
