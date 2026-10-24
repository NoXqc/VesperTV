import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/sports_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Guide extends EpgService {
  _Guide(super.storage);
  final pending = Completer<List<EpgProgram>>();
  int calls = 0;
  DateTime? from, to;
  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
      DateTime from, DateTime to, List<String> terms) {
    calls++;
    this.from = from;
    this.to = to;
    return pending.future;
  }

  @override
  Future<double?> guideCoverageAt(DateTime at) async => null;
}

Channel channel(String id, [String name = 'US - ESPN HD']) => Channel(
    id: 'p::$id',
    rawId: id,
    playlistId: 'p',
    name: name,
    group: 'Sports',
    url: 'https://example.com/$id');
SportsGame game(String id, DateTime start) => SportsGame(
    id: id,
    league: sportsLeagueById('nfl')!,
    start: start,
    state: GameState.pre,
    statusText: '',
    home: const SportsTeam(
        id: 'a',
        name: 'Buffalo Bills',
        shortName: 'Bills',
        abbreviation: 'BUF'),
    away: const SportsTeam(
        id: 'b',
        name: 'Las Vegas Raiders',
        shortName: 'Raiders',
        abbreviation: 'LV'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });
  test('matching survives index replacement while awaiting guide', () async {
    final epg = _Guide(storage);
    final matcher = SportsChannelMatcher(epg);
    await matcher.prepare([for (var i = 0; i < 5000; i++) channel('$i')]);
    final g = game('one', DateTime.now().toUtc());
    final matching = matcher.matchDay([g], SportsChannelPicks.load(storage));
    await matcher.prepare([channel('other')]);
    epg.pending.complete([
      EpgProgram(
          channelId: '4999',
          title: 'Buffalo Bills at Las Vegas Raiders',
          start: g.start,
          stop: g.start.add(const Duration(hours: 3)))
    ]);
    final result = await matching;
    expect(
        result[SportsChannelPicks.eventKey(g)]!.single.channel.id, 'p::4999');
    expect(matcher.channels.single.rawId, 'other');
  });
  test('concurrent scans share a future and multi-week games stay bounded',
      () async {
    final epg = _Guide(storage);
    final matcher = SportsChannelMatcher(epg);
    await matcher.prepare([channel('1')]);
    final start = DateTime.now().toUtc();
    final games = [
      game('now', start),
      game('later', start.add(const Duration(days: 12)))
    ];
    final picks = SportsChannelPicks.load(storage);
    final a = matcher.matchDay(games, picks);
    final b = matcher.matchDay(games, picks);
    expect(epg.calls, 1);
    expect(epg.to!.difference(epg.from!).inHours, lessThanOrEqualTo(37));
    epg.pending.complete([]);
    await Future.wait([a, b]);
    await matcher.matchDay(games, picks);
    expect(epg.calls, 1);
    epg.lastUpdated = DateTime.now();
    await matcher.matchDay(games, picks);
    expect(epg.calls, 2);
  });
  test('stale picker objects preserve newer game picks', () async {
    final a = SportsChannelPicks.load(storage),
        b = SportsChannelPicks.load(storage);
    final g = game('one', DateTime.now()), other = game('two', DateTime.now());
    await a.pickForGame(g, 'p::manual');
    await b.pickForGame(other, 'p::second');
    final loaded = SportsChannelPicks.load(storage);
    expect(loaded.channelIdFor(g), 'p::manual');
    expect(loaded.channelIdFor(other), 'p::second');
  });
  test('quality offers matched 4K broadcasters first and keeps explicit picks',
      () {
    final hd =
        ChannelMatch(channel('hd', 'CA: TSN 1 HD'), MatchReason.guide, 80);
    final uhd =
        ChannelMatch(channel('4k', 'CA: TSN 1 4K'), MatchReason.guide, 80);
    final other =
        ChannelMatch(channel('other', 'US: ESPN 4K'), MatchReason.network, 50);
    expect(preferSportsSources([hd, uhd, other]), [uhd, other, hd]);
    final picked = ChannelMatch(hd.channel, MatchReason.pick, 1000);
    expect(preferSportsSources([picked, uhd, other]).first, same(picked));
  });
  test('indexed slices paginate equal starts without gaps or duplicate matches',
      () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute(
        'CREATE TABLE programme (channel_id TEXT, start INTEGER, stop INTEGER, title TEXT, descr TEXT, source_url TEXT, gen INTEGER, PRIMARY KEY(channel_id,start)) WITHOUT ROWID');
    final epg = EpgDatabase(database: db);
    final from = DateTime.utc(2026, 10, 24).millisecondsSinceEpoch;
    final rows = [
      for (var i = 0; i < 2501; i++)
        (
          channelId: '$i',
          startMs: from,
          stopMs: from + 3600000,
          title: i.isEven ? 'Bills vs Raiders' : 'Other title',
          description: null
        )
    ];
    await epg.insertBatch(rows, 'example', 1);
    final results = await Future.wait([
      epg.programmesStartingWithTitle(
          from, from + 3600000, ['bills', 'raiders']),
      epg.programmesStartingWithTitle(from, from + 3600000, ['other'])
    ]);
    expect(results[0], hasLength(1251));
    expect(results[1], hasLength(1250));
    expect(results[0].map((r) => r.channelId).toSet(), hasLength(1251));
    final plan = await db.rawQuery(
        'EXPLAIN QUERY PLAN SELECT title FROM programme INDEXED BY idx_programme_start WHERE start >= ? AND start < ?',
        [from, from + 3600000]);
    expect(plan.toString(), contains('idx_programme_start'));
    await epg.insertBatch([
      (
        channelId: 'new',
        startMs: from,
        stopMs: from + 3600000,
        title: 'BILLS',
        description: null
      )
    ], 'example', 1);
    expect(
        await epg.programmesStartingWithTitle(from, from + 3600000, ['bills']),
        hasLength(1252));
    expect(await epg.programmesStartingWithTitle(from, from + 3600000, ['%']),
        isEmpty);
  });
  for (final size in [
    const Size(2560, 1440),
    const Size(1706, 960),
    const Size(1280, 720)
  ]) {
    testWidgets('Sports fills actual $size bounds with a stale MediaQuery',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: const MediaQueryData(size: Size(3840, 2160)),
              child: SportsScreenFrame(
                  child: ColoredBox(key: key, color: Colors.red)))));
      final box = key.currentContext!.findRenderObject() as RenderBox;
      expect(box.localToGlobal(box.size.bottomRight(Offset.zero)),
          Offset(size.width, size.height));
      expect(tester.takeException(), isNull);
    });
  }
}
