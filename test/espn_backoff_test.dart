import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/espn_backoff.dart';
import 'package:nox_iptv/services/sports_service.dart';

/// ESPN asks us to slow down (2026-11-11): a 429 / 403 pauses every ESPN
/// request from the device, the screens keep their cached scores, and a
/// 200 starts the count over.
void main() {
  final epoch = DateTime(2026, 11, 11, 12);
  late DateTime clock;
  late EspnBackoff backoff;
  late int requests;
  late http.Response Function() reply;
  late http.Client client;
  final url = Uri.parse('https://site.api.espn.com/apis/site/v2/sports/x');

  setUp(() {
    clock = epoch;
    backoff = EspnBackoff(now: () => clock);
    requests = 0;
    reply = () => http.Response('{}', 200);
    client = MockClient((_) async {
      requests++;
      return reply();
    });
  });

  Future<EspnBackoffException?> slowDown() async {
    try {
      await backoff.get(client, url);
    } on EspnBackoffException catch (e) {
      return e;
    }
    return null;
  }

  test('a 429 pauses ESPN for its Retry-After, then requests resume', () async {
    reply = () => http.Response('', 429, headers: {'retry-after': '120'});
    final first = await slowDown();
    expect(first, isNotNull);
    expect(first!.until, epoch.add(const Duration(seconds: 120)));
    expect(backoff.blocked, isTrue);
    expect(requests, 1);

    // Paused: nothing reaches the network.
    clock = epoch.add(const Duration(seconds: 119));
    expect(await slowDown(), isNotNull);
    expect(requests, 1);

    clock = epoch.add(const Duration(seconds: 121));
    expect(backoff.blocked, isFalse);
    reply = () => http.Response('{}', 200);
    final ok = await backoff.get(client, url);
    expect(ok.statusCode, 200);
    expect(requests, 2);
  });

  test('without Retry-After it starts at 90 s and doubles, up to 15 min',
      () async {
    reply = () => http.Response('', 429);
    var expected = 90;
    for (var i = 0; i < 8; i++) {
      final e = await slowDown();
      final wait = e!.until.difference(clock).inSeconds;
      expect(wait, expected, reason: 'strike ${i + 1}');
      clock = e.until.add(const Duration(seconds: 1));
      expected = (expected * 2).clamp(90, 900);
    }
    expect(expected, 900);
  });

  test('a 200 starts the count over', () async {
    reply = () => http.Response('', 429);
    var e = await slowDown();
    clock = e!.until.add(const Duration(seconds: 1));
    e = await slowDown();
    expect(e!.until.difference(clock).inSeconds, 180);
    clock = e.until.add(const Duration(seconds: 1));
    reply = () => http.Response('{}', 200);
    await backoff.get(client, url);
    reply = () => http.Response('', 429);
    e = await slowDown();
    expect(e!.until.difference(clock).inSeconds, 90);
  });

  test('Retry-After is kept between 30 s and 15 min', () async {
    reply = () => http.Response('', 429, headers: {'retry-after': '3'});
    var e = await slowDown();
    expect(e!.until.difference(clock).inSeconds, 30);
    clock = e.until.add(const Duration(seconds: 1));
    reply = () => http.Response('', 429, headers: {'retry-after': '86400'});
    e = await slowDown();
    expect(e!.until.difference(clock).inSeconds, 900);
  });

  test('a 403 is a block too', () async {
    reply = () => http.Response('', 403);
    expect(await slowDown(), isNotNull);
    expect(backoff.blocked, isTrue);
  });

  test('requests in flight together are one strike, not two', () async {
    reply = () => http.Response('', 429);
    final results = await Future.wait([
      slowDown(),
      slowDown(),
    ]);
    expect(results.every((e) => e != null), isTrue);
    expect(requests, 2, reason: 'both were already on their way');
    expect(backoff.blockedUntil, epoch.add(const Duration(seconds: 90)));
  });

  test('a 5xx or a timeout is not a request to slow down', () async {
    reply = () => http.Response('busy', 503);
    expect((await backoff.get(client, url)).statusCode, 503);
    expect(backoff.blocked, isFalse);
    final slow = MockClient((_) => Completer<http.Response>().future);
    await expectLater(
        backoff.get(slow, url, timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TimeoutException>()));
    expect(backoff.blocked, isFalse);
  });

  group('in the Sports service', () {
    const nhl = SportsLeague(
        id: 'nhl',
        espnPath: 'hockey/nhl',
        name: 'NHL',
        shortName: 'NHL',
        logoUrl: '');
    const home =
        SportsTeam(id: 'h', name: 'Home', shortName: 'Home', abbreviation: 'H');
    const away =
        SportsTeam(id: 'a', name: 'Away', shortName: 'Away', abbreviation: 'A');
    final game = SportsGame(
        id: '1',
        league: nhl,
        start: DateTime(2026, 11, 11),
        state: GameState.live,
        statusText: 'Live',
        home: home,
        away: away);

    test('a 429 on a summary is "try later", not "ESPN has none"', () async {
      reply = () => http.Response('', 429, headers: {'retry-after': '60'});
      final service = SportsService.forTesting(client, backoff: backoff);
      expect(await service.gameSummary(game), isNull);
      expect(requests, 1, reason: 'no second try during the pause');

      // Paused: even a goal alert's fresh ask stays off the network.
      expect(await service.gameSummary(game, fresh: true), isNull);
      expect(requests, 1);

      // After the pause the game is asked again (a 400 would have marked it
      // refused for the whole cache window).
      clock = epoch.add(const Duration(seconds: 61));
      reply = () => http.Response('{}', 200);
      await service.gameSummary(game);
      expect(requests, 2);
    });

    test('a day with nothing cached says why, and stops asking', () async {
      reply = () => http.Response('', 429, headers: {'retry-after': '300'});
      final service = SportsService.forTesting(client, backoff: backoff);
      final games = await service.gamesForDay([nhl], DateTime(2026, 11, 11));
      expect(games, isEmpty);
      expect(service.lastError, contains('slow down'),
          reason: 'not "check the connection"');
      expect(backoff.blocked, isTrue);
      final asked = requests;
      expect(asked, greaterThan(0));

      await service.gamesForDay([nhl], DateTime(2026, 11, 12));
      expect(requests, asked,
          reason: 'while paused no other day is requested either');

      // Once the pause ends the scores load again and the message goes.
      clock = epoch.add(const Duration(seconds: 301));
      reply = () => http.Response('{"events":[]}', 200);
      await service.gamesForDay([nhl], DateTime(2026, 11, 13));
      expect(requests, greaterThan(asked));
      expect(service.lastError, isNull);
    });
  });
}
