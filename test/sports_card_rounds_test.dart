import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/sports_db_source.dart';
import 'package:nox_iptv/services/sports_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _ts(DateTime utc) => utc.toIso8601String().substring(0, 19);

Map<String, Object?> _card(int round, DateTime utc) => {
      'idEvent': 'card$round',
      'strEvent': 'Fighter $round vs Other $round',
      'strTimestamp': _ts(utc),
      'strStatus': 'NS',
      'intRound': '$round',
      'strSeason': '2026',
      'strDescriptionEN': 'x' * 2000, // dropped from the saved copy
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boxing = sportsLeagueById('boxing')!;

  test('cardRounds: only a full fight day with one card per round', () {
    String day(List<String> rounds) => jsonEncode({
          'events': [
            for (final r in rounds)
              {'idEvent': r, 'intRound': r, 'strSeason': '2026'}
          ]
        });
    expect(SportsDbSource.cardRounds(boxing, day(['7', '8'])), isNull);
    expect(SportsDbSource.cardRounds(boxing, day(['9', '7', '8']))?.rounds,
        [7, 8, 9]);
    expect(SportsDbSource.cardRounds(boxing, day(['7', '7', '8'])), isNull);
    expect(SportsDbSource.cardRounds(boxing, day(['0', '7', '8'])), isNull);
    final team = sportsLeagueById('rou.1')!;
    expect(SportsDbSource.cardRounds(team, day(['7', '8', '9'])), isNull);
  });

  test('a full boxing day finds cards 4-5 from the next card numbers, once',
      () async {
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day + 7);
    DateTime at(int hour, {int days = 0}) =>
        DateTime(day.year, day.month, day.day + days, hour).toUtc();
    // The day call returns 3 (the free cap); 8 and 11 are the same day too.
    final rounds = {
      6: at(12, days: -7),
      7: at(10),
      8: at(11),
      9: at(12),
      10: at(13),
      11: at(14),
      12: at(12, days: 7),
    };
    final dayDate = _ts(at(10)).substring(0, 10);
    final asked = <String>[];
    MockClient client() => MockClient((request) async {
          final q = request.url.queryParameters;
          if (request.url.path.endsWith('eventsday.php')) {
            return http.Response(
                jsonEncode({
                  'events': q['d'] == dayDate
                      ? [
                          for (final r in [7, 9, 10]) _card(r, rounds[r]!)
                        ]
                      : null
                }),
                200);
          }
          final r = int.parse(q['r']!);
          asked.add('$r');
          return http.Response(
              jsonEncode({
                'events': rounds[r] == null ? null : [_card(r, rounds[r]!)]
              }),
              200);
        });

    final games =
        await SportsService.forTesting(client()).gamesForDay([boxing], day);
    expect(games.map((g) => g.id),
        ['card7', 'card8', 'card9', 'card10', 'card11']);
    // Gap 8, then up until 12 is another day, then down: 6 is too.
    expect(asked, ['8', '11', '12', '6']);

    final saved = (await SharedPreferences.getInstance())
        .getString(AppConstants.keySportsDbRounds)!;
    expect(saved, isNot(contains('xxxx')));

    // A new launch: the card numbers come from disk, not the feed.
    asked.clear();
    final again =
        await SportsService.forTesting(client()).gamesForDay([boxing], day);
    expect(again.length, 5);
    expect(asked, isEmpty);
  });
}
