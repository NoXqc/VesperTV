import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/services/channel_name_events.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Event channels whose provider guide is empty get a listing from their
/// own name (USA | NBA / NBA League Pass, 2026-11-07).
void main() {
  final nov7 = DateTime.utc(2026, 11, 7, 22);
  final march = DateTime.utc(2026, 3, 1);

  DateTime? startOf(String name, [DateTime? now]) =>
      parseChannelNameEvent(name, now: now ?? nov7)?.start;

  group('parse', () {
    test('NBA: title and start, Eastern standard time', () {
      final e = parseChannelNameEvent(
          'NBA 01: Nuggets vs. Pacers @ 7 Nov 04:58 PM ET',
          now: nov7)!;
      expect(e.title, 'Nuggets vs. Pacers');
      expect(e.start, DateTime.utc(2026, 11, 7, 21, 58));
      expect(e.stop, DateTime.utc(2026, 11, 8, 0, 58));
      expect(e.note, isNull);
    });

    test('League Pass keeps the feed in the title', () {
      expect(
          parseChannelNameEvent(
                  'NBA League Pass 01: Pacers vs Nuggets (Pacers In-Arena) '
                  '@ 7 Nov 05:00 PM ET',
                  now: nov7)!
              .title,
          'Pacers vs Nuggets (Pacers In-Arena)');
    });

    test('Eastern daylight time before the first Sunday of November', () {
      expect(
          startOf('WNBA 01: Atlanta Dream at Golden State Valkyries '
              '@ 31 Oct 08:00 PM ET'),
          DateTime.utc(2026, 11, 1));
      // US DST 2026 starts Sunday 8 March.
      expect(startOf('X 01: A vs B @ 7 Mar 08:00 PM ET', march),
          DateTime.utc(2026, 3, 8, 1));
      expect(startOf('X 01: A vs B @ 8 Mar 08:00 PM ET', march),
          DateTime.utc(2026, 3, 9));
    });

    test('month first, am/pm without a space', () {
      expect(
          startOf('ESPN+ 50: Old Dominion vs. Coastal Carolina '
              '@ Nov 07 1:00PM ET'),
          DateTime.utc(2026, 11, 7, 18));
      expect(startOf('ESPN+ 08: Salem vs. VMI @ Nov 07 10:00AM ET'),
          DateTime.utc(2026, 11, 7, 15));
      expect(startOf('X 01: A vs B @ 7 Nov 12:00 AM ET'),
          DateTime.utc(2026, 11, 7, 5));
      expect(startOf('X 01: A vs B @ 7 Nov 12:30 PM ET'),
          DateTime.utc(2026, 11, 7, 17, 30));
    });

    test('European city zones follow EU summer time', () {
      expect(
          parseChannelNameEvent(
                  'DAZN UK 03: RWS: Wukong vs. Chaila @ 7 Nov 12:10 PM London',
                  now: nov7)!
              .title,
          'RWS: Wukong vs. Chaila');
      expect(startOf('DAZN UK 03: A vs B @ 7 Nov 12:10 PM London'),
          DateTime.utc(2026, 11, 7, 12, 10));
      expect(startOf('ViaPlay NO 03: NHL On The Fly @ 6 Nov 01:55 PM Oslo'),
          DateTime.utc(2026, 11, 6, 12, 55));
      final aug = DateTime.utc(2026, 8, 20);
      expect(startOf('X 01: A vs B @ 25 Aug 07:55 PM Stockholm', aug),
          DateTime.utc(2026, 8, 25, 17, 55));
      expect(startOf('X 01: A vs B @ 25 Aug 07:55 PM London', aug),
          DateTime.utc(2026, 8, 25, 18, 55));
      // EU summer time 2026 starts Sunday 29 March.
      expect(startOf('X 01: A vs B @ 28 Mar 03:00 PM CET', march),
          DateTime.utc(2026, 3, 28, 14));
      expect(startOf('X 01: A vs B @ 29 Mar 03:00 PM CET', march),
          DateTime.utc(2026, 3, 29, 13));
    });

    test('fixed GMT offsets and 24-hour times', () {
      expect(startOf('TOD EN 02: Premier Padel @ 7 Nov 01:30 PM GMT-5'),
          DateTime.utc(2026, 11, 7, 18, 30));
      expect(startOf('X 01: A vs B @ 7 Nov 19:00 PT'),
          DateTime.utc(2026, 11, 8, 3));
      expect(startOf('X 01: A vs B @ 7 Nov 19:00 Amsterdam'),
          DateTime.utc(2026, 11, 7, 18));
    });

    test('text after the time becomes the description', () {
      final e = parseChannelNameEvent(
          'NFL Game Pass 02: Jacksonville Jaguars vs Baltimore Ravens '
          '@ Nov 05 08:15 PM ET - Prime Feed',
          now: nov7)!;
      expect(e.title, 'Jacksonville Jaguars vs Baltimore Ravens');
      expect(e.note, 'Prime Feed');
      expect(e.start, DateTime.utc(2026, 11, 6, 1, 15));
    });

    test('the year nearest to now', () {
      expect(
          startOf(
              'X 01: A vs B @ 2 Jan 07:00 PM ET', DateTime.utc(2026, 12, 30)),
          DateTime.utc(2027, 1, 3));
      expect(
          startOf(
              'X 01: A vs B @ 30 Dec 07:00 PM ET', DateTime.utc(2027, 1, 2)),
          DateTime.utc(2026, 12, 31));
    });

    test('no date, no zone or no event: nothing', () {
      for (final name in [
        'NBA 08: NO EVENT',
        'US: NBA ATLANTA HAWKS FHD',
        // No zone: the time can't be placed.
        'Clubber 03: Parteen v Canovee (Munster Club) - @ Nov 7 13:15',
        'MonoMAX 18: TAURON Liga vs ZAKSA @ 7 Nov 12:20 PM',
        // No date.
        'Soccer03: Barcelona vs Paris FC ( OneSoccer Feed ) @ 3:00 pm',
        // "@" as "at".
        'QMJHL 11: Cape Breton @ Quebec - #519 | Fri 7th 12:00AM',
        'X 01: A vs B @ 7 Nov 25:00 ET',
        'X 01: A vs B @ 7 Nov 13:00 PM ET',
        'X 01: A vs B @ 31 Feb 01:00 PM ET',
        '@ 7 Nov 04:58 PM ET',
      ]) {
        expect(parseChannelNameEvent(name, now: nov7), isNull, reason: name);
      }
    });
  });

  group('merge', () {
    final event =
        ChannelNameEvent('Nets vs. Hawks', DateTime.utc(2026, 11, 8, 0, 28));
    EpgProgram p(String title, int fromH, int toH) => EpgProgram(
        channelId: 'id',
        title: title,
        start: DateTime.utc(2026, 11, 7, fromH).toLocal(),
        stop: DateTime.utc(2026, 11, 7, toH).toLocal());

    test('fills an empty guide', () {
      final out = mergeChannelNameEvent(const [], event, 'id');
      expect(out.single.title, 'Nets vs. Hawks');
      expect(out.single.start, event.start.toLocal());
      expect(out.single.stop, event.stop.toLocal());
    });

    test('keeps earlier fillers and cuts the one it covers', () {
      final out = mergeChannelNameEvent([
        p('Signing Off', 8, 12),
        p('Signing Off', 12, 16),
        p('Signing Off', 16, 24)
      ], event, 'id');
      expect(out.map((e) => e.title).toList(),
          ['Signing Off', 'Signing Off', 'Signing Off', 'Nets vs. Hawks']);
      expect(out[2].stop, DateTime.utc(2026, 11, 7, 24).toLocal(),
          reason: 'ends before the game');
    });

    test('a filler running through the game is split around it', () {
      final long = EpgProgram(
          channelId: 'id',
          title: 'NO EVENT',
          start: DateTime.utc(2026, 11, 7, 20).toLocal(),
          stop: DateTime.utc(2026, 11, 8, 6).toLocal());
      final out = mergeChannelNameEvent([long], event, 'id');
      expect(out.map((e) => e.title).toList(),
          ['NO EVENT', 'Nets vs. Hawks', 'NO EVENT']);
      expect(out[0].stop, event.start.toLocal());
      expect(out[2].start, event.stop.toLocal());
    });

    test("the provider's real listing wins", () {
      final real = [p('NBA: Nets at Hawks', 23, 27)];
      expect(identical(mergeChannelNameEvent(real, event, 'id'), real), isTrue);
    });
  });

  group('EpgService', () {
    late EpgService epg;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      epg = EpgService(storage);
    });

    test('now, next and the guide row come from the name', () {
      final now = DateTime.now().toUtc();
      final events = {
        'bosssports.nba.01': ChannelNameEvent(
            'Nuggets vs. Pacers', now.subtract(const Duration(minutes: 30))),
        'bosssports.nba.02': ChannelNameEvent(
            'Nets vs. Hawks', now.add(const Duration(hours: 2))),
      };
      epg.nameEventsProvider = () => events;

      expect(epg.getCurrentProgram('BossSports.NBA.01')?.title,
          'Nuggets vs. Pacers');
      expect(epg.getCurrentProgram('BossSports.NBA.02'), isNull);
      expect(epg.getNextProgram('BossSports.NBA.02')?.title, 'Nets vs. Hawks');
      final row = epg.getPrograms('BossSports.NBA.01');
      expect(row.single.title, 'Nuggets vs. Pacers');
      expect(identical(epg.getPrograms('BossSports.NBA.01'), row), isTrue,
          reason: 'the same list on every build');
      expect(epg.hasPrograms('BossSports.NBA.01'), isFalse,
          reason: "hasPrograms stays the provider's own guide");
      expect(epg.getPrograms('BossSports.NBA.03'), isEmpty);
    });
  });
}
