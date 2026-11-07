import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/services/sports_service.dart';

String _ts(DateTime utc) => utc.toIso8601String().substring(0, 19);
String _date(DateTime utc) => _ts(utc).substring(0, 10);

void main() {
  test('UTC dates of a local day: two away from UTC, one at UTC', () {
    // Eastern (UTC-5): local Nov 9 = 05:00Z Nov 9 .. 05:00Z Nov 10.
    expect(
        SportsService.utcDatesBetween(
            DateTime.utc(2026, 11, 9, 5), DateTime.utc(2026, 11, 10, 5)),
        [DateTime(2026, 11, 9), DateTime(2026, 11, 10)]);
    // Athens (UTC+2): local Nov 9 = 22:00Z Nov 8 .. 22:00Z Nov 9.
    expect(
        SportsService.utcDatesBetween(
            DateTime.utc(2026, 11, 8, 22), DateTime.utc(2026, 11, 9, 22)),
        [DateTime(2026, 11, 8), DateTime(2026, 11, 9)]);
    // UTC itself: one date, one request.
    expect(
        SportsService.utcDatesBetween(
            DateTime.utc(2026, 11, 9), DateTime.utc(2026, 11, 10)),
        [DateTime(2026, 11, 9)]);
  });

  test('an evening show filed under the next UTC date is on its local day',
      () async {
    final wwe = sportsLeagueById('wrestling.wwe')!;
    final day = DateTime(2026, 11, 9);
    // In the viewer's own zone, whatever the test machine's zone is.
    final events = {
      'raw': DateTime(2026, 11, 9, 19).toUtc(),
      'noon': DateTime(2026, 11, 9, 12).toUtc(),
      'nextDay': DateTime(2026, 11, 10, 19).toUtc(),
      'dayBefore': DateTime(2026, 11, 8, 19).toUtc(),
    };
    final asked = <String>[];
    final client = MockClient((request) async {
      final d = request.url.queryParameters['d']!;
      asked.add(d);
      return http.Response(
          jsonEncode({
            'events': [
              for (final MapEntry(:key, :value) in events.entries)
                if (_date(value) == d)
                  {
                    'idEvent': key,
                    'strTimestamp': _ts(value),
                    'strEvent': key,
                    'strStatus': 'NS',
                  }
            ]
          }),
          200);
    });
    final service = SportsService.forTesting(client);
    final games = await service.gamesForDay([wwe], day);
    expect(games.map((g) => g.id).toSet(), {'raw', 'noon'});
    expect(asked.length, lessThanOrEqualTo(2));
    expect(service.hasReliableSchedule(wwe, day), isTrue);
  });
}
