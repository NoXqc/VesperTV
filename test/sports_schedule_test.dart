import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/screens/sports_schedule_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/game_reminders.dart';
import 'package:nox_iptv/services/sports_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';

// Arsenal's season from ESPN's `soccer/all` team schedule: league games
// and cups mixed, each event naming its competition.

Map<String, dynamic> _team(String id, String name, {bool home = false}) => {
      'homeAway': home ? 'home' : 'away',
      'team': {
        'id': id,
        'displayName': name,
        'shortDisplayName': name,
        'abbreviation': name.substring(0, 3).toUpperCase(),
      },
    };

Map<String, dynamic> _event(
        String id, DateTime start, String opponent, Map<String, dynamic> league,
        {String state = 'pre'}) =>
    {
      'id': id,
      'date': start.toUtc().toIso8601String(),
      'league': league,
      'competitions': [
        {
          'competitors': [
            _team('359', 'Arsenal', home: true),
            _team('9$id', opponent),
          ],
          'status': {
            'type': {'state': state, 'shortDetail': 'FT'}
          },
        }
      ],
    };

const _premier = {'slug': 'eng.1', 'name': 'English Premier League'};
const _carabao = {
  'slug': 'eng.league_cup',
  'name': 'English Carabao Cup',
  'abbreviation': 'Carabao Cup',
  'alternateId': '41',
};
const _unknownCup = {
  'slug': 'eng.trophy',
  'name': 'EFL Trophy',
  'abbreviation': 'EFL Trophy',
  'alternateId': '99',
};

DateTime _localDay(int offset) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + offset, 20);
}

SportsService _service(List<String> asked) =>
    SportsService.forTesting(MockClient((r) async {
      asked.add(r.url.toString());
      final fixtures = r.url.queryParameters['fixture'] == 'true';
      return http.Response(
          jsonEncode({
            'team': {
              'id': '359',
              'displayName': 'Arsenal',
              'abbreviation': 'ARS',
              'recordSummary': '7-0-1',
            },
            'events': fixtures
                ? [
                    _event('1', _localDay(1), 'Chelsea', _premier),
                    _event('2', _localDay(8), 'Brentford', _carabao),
                    _event('3', _localDay(15), 'Barnet', _unknownCup),
                  ]
                : const [],
          }),
          200);
    }));

void main() {
  final league = sportsLeagueById('eng.1')!;

  test('soccer season reads soccer/all: cups keep their competition', () async {
    final asked = <String>[];
    final s = await _service(asked).teamSeason(league, '359');
    expect(asked, hasLength(2));
    expect(asked.every((u) => u.contains('/soccer/all/teams/359/schedule')),
        isTrue);
    final byOpponent = {
      for (final g in s!.games)
        g.home.id == '359' ? g.away.name : g.home.name: g
    };
    expect(byOpponent['Chelsea']!.league.id, 'eng.1');
    expect(byOpponent['Brentford']!.league.id, 'eng.league_cup');
    expect(byOpponent['Brentford']!.league.name, 'Carabao Cup');
    final unknown = byOpponent['Barnet']!.league;
    expect(unknown.id, 'eng.trophy');
    expect(unknown.espnPath, 'soccer/eng.trophy');
    expect(unknown.logoUrl, endsWith('/soccer/500/99.png'));
  });

  test('other sports keep the league team schedule', () async {
    final asked = <String>[];
    await _service(asked).teamSeason(sportsLeagueById('nhl')!, '10');
    expect(asked.single, contains('/hockey/nhl/teams/10/schedule'));
  });

  testWidgets('calendar: D-pad selects days, details show the cup',
      (tester) async {
    // Decorative logos use the image cache asynchronously. Provide its
    // platform paths so a late cache open cannot fail after this test exits.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.path);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final reminders =
        GameReminders(storage, loadSchedule: (_, __) async => null);
    addTearDown(reminders.dispose);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<GameReminders>.value(value: reminders),
        ChangeNotifierProvider<AppPreferences>.value(
            value: AppPreferences(storage)
              ..layoutMode = 'auto'
              ..palette = AppConstants.cyberpunkPalettes.first),
      ],
      child: MaterialApp(
        home: SportsScheduleScreen(
          league: league,
          teamId: '359',
          hideScores: false,
          service: _service([]),
        ),
      ),
    ));
    // The season parses on a background isolate: let real time run.
    await tester.runAsync(() async {
      for (var i = 0;
          i < 50 &&
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('No game this day.'), findsOneWidget);
    // The next game is offered while today has none.
    expect(find.text('vs Chelsea'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('No game this day.'), findsNothing);
    expect(find.text('English Premier League'), findsNothing);
    expect(find.text('Premier League'), findsOneWidget);

    // A week down from tomorrow: the Carabao Cup game.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('vs Brentford'), findsOneWidget);
    expect(find.text('Carabao Cup'), findsOneWidget);

    // CH-/PgDn changes month and keeps the calendar focused.
    final month = DateTime(_localDay(8).year, _localDay(8).month);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    final shown = find.byWidgetPredicate((w) =>
        w is Text &&
        w.data != null &&
        w.data!.contains('${DateTime(month.year, month.month + 1).year}'));
    expect(shown, findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(find.text('vs Brentford'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  });
}
