import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/sports_service.dart';

SportsGame _game(SportsLeague league, {String id = '1'}) => SportsGame(
      id: id,
      league: league,
      start: DateTime(2026, 11, 10),
      state: GameState.live,
      statusText: 'Live',
      home: const SportsTeam(
          id: 'h', name: 'Home', shortName: 'Home', abbreviation: 'H'),
      away: const SportsTeam(
          id: 'a', name: 'Away', shortName: 'Away', abbreviation: 'A'),
    );

const _nhl = SportsLeague(
    id: 'nhl',
    espnPath: 'hockey/nhl',
    name: 'NHL',
    shortName: 'NHL',
    logoUrl: '');

void main() {
  test('tennis never asks ESPN for a summary (it answers HTTP 400)', () async {
    var requests = 0;
    final service = SportsService.forTesting(MockClient((_) async {
      requests++;
      return http.Response('{}', 400);
    }));
    final atp = kSportsLeagueBank.firstWhere((l) => l.id == 'tennis.atp');
    expect(atp.kind, SportsKind.tennis);
    final summary = await service.gameSummary(_game(atp));
    expect(summary, isNotNull);
    expect(summary!.isEmpty, isTrue);
    expect(requests, 0);
  });

  test('a 4xx summary is not retried nor asked again soon', () async {
    var requests = 0;
    final service = SportsService.forTesting(MockClient((_) async {
      requests++;
      return http.Response('{"code":400}', 400);
    }));
    final game = _game(_nhl);
    // Null: a goal alert stops waiting for a scorer.
    expect(await service.gameSummary(game), isNull);
    expect(requests, 1, reason: 'no second try after a 4xx');
    expect(await service.gameSummary(game), isNull);
    expect(requests, 1, reason: 'not asked again in the refresh window');
    await service.gameSummary(game, fresh: true);
    expect(requests, 2, reason: 'fresh (goal alerts) still asks');
  });

  test('a 5xx is still retried once', () async {
    var requests = 0;
    final service = SportsService.forTesting(MockClient((_) async {
      requests++;
      return http.Response('busy', 503);
    }));
    final summary = await service.gameSummary(_game(_nhl, id: '2'));
    expect(summary, isNull);
    expect(requests, 2);
  });
}
