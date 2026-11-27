import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LOG-X7Z2W2 (NVIDIA SHIELD, 1.0.74-dev.1036, 2026-11-27): three "not
/// responding" in 15 minutes in Sports Trak. 32,010 live channels, 8,483
/// guide channels; after adding EuroLeague / EuroCup / BCL / boxing / WWE /
/// AEW / Greek basketball every 30 s poll held the main thread 3.2-3.5 s
/// (`MainStall ... jobs=[matcherPrepare]`, sometimes twice: 5.7 s). The
/// guide hits (4,000-6,000 rows) were checked against every game in one
/// synchronous run, each title normalized again for each game.
class _Guide extends EpgService {
  _Guide(super.storage, this.programmes);
  final List<EpgProgram> programmes;
  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
          DateTime from, DateTime to, List<String> terms) async =>
      [
        for (final p in programmes)
          if (!p.start.isBefore(from) && p.start.isBefore(to)) p
      ];

  @override
  Future<double?> guideCoverageAt(DateTime at) async => null;
}

/// The longest time the event loop was held while [body] ran: a 1 ms timer
/// notes how late each tick came.
Future<Duration> longestHold(Future<void> Function() body) async {
  var longest = Duration.zero;
  final watch = Stopwatch()..start();
  var last = watch.elapsed;
  final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
    final now = watch.elapsed;
    final gap = now - last;
    if (gap > longest) longest = gap;
    last = now;
  });
  await body();
  final tail = watch.elapsed - last;
  if (tail > longest) longest = tail;
  timer.cancel();
  return longest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  const countries = [
    'UK',
    'US',
    'CA',
    'GR',
    'DE',
    'FR',
    'ES',
    'IT',
    'NL',
    'PL'
  ];
  const words = [
    'Sports',
    'News',
    'Movies',
    'Kids',
    'Music',
    'Sky',
    'Arena',
    'Sport',
    'Cinema',
    'Action',
    'Premium',
    'Max',
    'Plus',
    'Extra',
    'Live',
    'Event',
  ];
  final leagues = [
    for (final id in [
      'basketball.euroleague',
      'basketball.eurocup',
      'basketball.bcl',
      'nba',
      'nhl',
      'eng.1',
      'esp.1',
      'ita.1',
      'ger.1',
      'fra.1',
    ])
      sportsLeagueById(id)!,
  ];

  test('one Sports Trak match of a big day never holds the app long', () async {
    final channels = [
      for (var i = 0; i < 32000; i++)
        Channel(
            id: 'p::c$i',
            rawId: 'c$i',
            playlistId: 'p',
            name: '${countries[i % countries.length]}: '
                '${words[i % words.length]} ${words[(i ~/ 16) % words.length]} '
                '${i % 7 == 0 ? 'FHD' : 'HD'} $i',
            group: countries[i % countries.length],
            url: 'https://example.com/$i'),
    ];
    final start = DateTime.now().toUtc().add(const Duration(hours: 2));
    final games = <SportsGame>[];
    for (var i = 0; i < 150; i++) {
      final league = leagues[i % leagues.length];
      games.add(SportsGame(
        id: 'g$i',
        league: league,
        start: start.add(Duration(minutes: 15 * (i % 40))),
        state: GameState.pre,
        statusText: '',
        home: SportsTeam(
            id: 'h$i',
            name: 'Homeside Club$i',
            shortName: 'Homeside$i',
            abbreviation: 'H$i'),
        away: SportsTeam(
            id: 'a$i',
            name: 'Awayside Club$i',
            shortName: 'Awayside$i',
            abbreviation: 'A$i'),
      ));
    }
    // 6,000 guide hits: each game on a few channels, plus series titles.
    final programmes = <EpgProgram>[];
    for (var i = 0; i < 6000; i++) {
      final g = games[i % games.length];
      final at = g.start.add(Duration(minutes: (i % 5) * 10 - 20));
      programmes.add(EpgProgram(
          channelId: 'c${(i * 37) % 8483}',
          title: (i ~/ games.length) % 3 == 0
              ? '${g.league.shortName} Basketball Live: Highlights and Analysis'
              : '${g.league.shortName}: ${g.home.name} v ${g.away.name} (Live)',
          start: at,
          stop: at.add(const Duration(hours: 2))));
    }
    final matcher = SportsChannelMatcher(_Guide(storage, programmes));
    await matcher.prepare(channels);
    final picks = SportsChannelPicks.load(storage);
    Map<String, List<ChannelMatch>> result = {};
    final watch = Stopwatch()..start();
    final hold = await longestHold(() async {
      result = await matcher.matchDay(games, picks);
    });
    // ignore: avoid_print
    print('matchDay: ${watch.elapsedMilliseconds} ms, longest hold '
        '${hold.inMilliseconds} ms');
    expect(result.length, games.length);
    expect(result.values.where((m) => m.isNotEmpty).length, games.length,
        reason: 'every game found on its guide channels');
    // A SHIELD is ~5-10x slower than this PC: 5 s there = an ANR.
    expect(hold, lessThan(const Duration(milliseconds: 60)));
  });
}
