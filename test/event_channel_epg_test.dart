import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/channel_name_events.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A provider gives one EPG id (`tsn4mel`) to 61 event channels (TSN+ 05-45,
/// ESPN+ 49, Disney+ Events 49…, 2026-11-09): every TSN+ row showed that
/// id's guide or another channel's game. Each event channel now has its own.
void main() {
  Channel ch(String rawId, String name, int stream, {String? override}) =>
      Channel(
          id: 'p::$rawId',
          rawId: rawId,
          playlistId: 'p',
          name: name,
          group: 'TSN+',
          url: 'http://h/live/u/p/$stream.ts',
          epgIdOverride: override);

  group('isEventChannelName', () {
    test('an event in the name, or a numbered slot with nothing on', () {
      for (final n in [
        'TSN+ 05: NBA on TSN: Wizards vs. Pistons @ 9 Nov 07:00 PM ET',
        'ESPN+ 49: Stetson vs. North Florida (Semifinal) @ Nov 09 7:00PM ET',
        'TSN+ 07: NO EVENT',
        'MLB 49: No Event Today',
        'CA - TSN+ 07 : ',
      ]) {
        expect(isEventChannelName(n), isTrue, reason: n);
      }
    });

    test('networks and their copies are not', () {
      for (final n in [
        'ESPN HD',
        'CA| TSN 4 FHD',
        'Sky Sports 1 | HD',
        'TSN+ 05: NBA on TSN: Wizards vs. Pistons', // no date: can't tell
        'US: Fox Sports 1',
      ]) {
        expect(isEventChannelName(n), isFalse, reason: n);
      }
    });
  });

  group('Channel.epgId', () {
    final list = Channel.withUniqueIds([
      ch('tsn4mel',
          'TSN+ 05: NBA on TSN: Wizards vs. Pistons @ 9 Nov 07:00 PM ET', 5),
      ch(
          'tsn4mel',
          'TSN+ 06: Field Pass with The Pat McAfee Show: Bills vs. Vikings @ 9 Nov 08:15 PM ET',
          6),
      ch('tsn4mel', 'TSN+ 07: NO EVENT', 7),
      ch(
          'tsn4mel',
          'Disney+ Events 49: Simpson (IA) vs. Western Illinois @ 9 Nov 07:00 PM ET',
          49),
      ch('espn.us', 'ESPN HD', 100),
      ch('espn.us', 'ESPN 4K', 101),
      ch('tsn1.ca', 'TSN 1', 200),
    ]);
    Channel named(String prefix) =>
        list.firstWhere((c) => c.name.startsWith(prefix));

    test('event channels sharing an id each get their own', () {
      final ids = [
        for (final p in ['TSN+ 05', 'TSN+ 06', 'TSN+ 07', 'Disney+'])
          named(p).epgId
      ];
      expect(ids.toSet(), hasLength(4));
      expect(ids, everyElement(isNot('tsn4mel')));
    });

    test('copies of a network keep the shared id; a unique id is unchanged',
        () {
      expect(named('ESPN HD').epgId, 'espn.us');
      expect(named('ESPN 4K').epgId, 'espn.us');
      expect(named('TSN 1').epgId, 'tsn1.ca');
    });

    test('a manual guide match still wins', () {
      final c = Channel.withUniqueIds([
        ch('tsn4mel',
            'TSN+ 05: NBA on TSN: Wizards vs. Pistons @ 9 Nov 07:00 PM ET', 5,
            override: 'tsn5.ca'),
        ch('tsn4mel', 'TSN+ 07: NO EVENT', 7),
      ]).first;
      expect(c.epgId, 'tsn5.ca');
    });

    test('each TSN+ row now gets the game in its own name', () {
      // What PlaylistManager.channelNameEventsByEpgId builds.
      final now = DateTime.utc(2026, 11, 9, 23, 50);
      final events = <String, ChannelNameEvent>{};
      for (final c in list) {
        final e = parseChannelNameEvent(c.name, now: now);
        if (e != null) events.putIfAbsent(normalizeEpgId(c.epgId), () => e);
      }
      expect(events[normalizeEpgId(named('TSN+ 05').epgId)]?.title,
          'NBA on TSN: Wizards vs. Pistons');
      expect(events[normalizeEpgId(named('TSN+ 06').epgId)]?.title,
          'Field Pass with The Pat McAfee Show: Bills vs. Vikings');
      expect(events[normalizeEpgId(named('TSN+ 07').epgId)], isNull);
    });
  });

  group('idle event slots', () {
    const idle = [
      'TSN+ 07: NO EVENT',
      'CA - TSN+ 07 : ',
      'MLB 49: No Event Today'
    ];
    const notIdle = [
      'TSN+ 05: NBA on TSN: Wizards vs. Pistons @ 9 Nov 07:00 PM ET',
      'ESPN HD',
      'Sky Sports 1 | HD',
      'US: ESPN',
      'TSN 4',
    ];

    test('only numbered slots with nothing on', () {
      for (final n in idle) {
        expect(isIdleEventChannelName(n), isTrue, reason: n);
      }
      for (final n in notIdle) {
        expect(isIdleEventChannelName(n), isFalse, reason: n);
      }
    });

    test('the quick look never misses one', () {
      for (final n in [
        ...idle,
        'X 1: Signing Off',
        'X 2: Off Air',
        'X 3: Stand by',
        'X 4: To be announced',
        'X 5: TBA',
        'X 6: n/a',
        'X 7: No Information',
      ]) {
        expect(isIdleEventChannelName(n), isTrue, reason: n);
        expect(mayBeIdleEventChannelName(n), isTrue, reason: n);
      }
      expect(mayBeIdleEventChannelName('ESPN HD'), isFalse);
      expect(mayBeIdleEventChannelName('US: ESPN'), isFalse);
    });

    test('the guide row says "No game at this time" without a guide', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final epg = EpgService(storage)
        ..nameEventsProvider = (() => const {})
        ..idleEventIdsProvider = (() => {'tsn4mel#7'});

      expect(epg.getCurrentProgram('tsn4mel#7')?.title, noGameTitle);
      final row = epg.getPrograms('tsn4mel#7');
      expect(row, hasLength(1));
      expect(row.single.start.isBefore(DateTime.now()), isTrue);
      expect(row.single.stop.difference(DateTime.now()).inHours,
          greaterThanOrEqualTo(29));
      expect(identical(epg.getPrograms('tsn4mel#7'), row), isTrue);
      expect(epg.hasPrograms('tsn4mel#7'), isFalse);
      expect(epg.getPrograms('tsn4mel#8'), isEmpty);
    });
  });
}
