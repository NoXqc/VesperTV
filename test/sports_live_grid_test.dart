import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/screens/sports_live_list_screen.dart';
import 'package:nox_iptv/services/sports_follows.dart';
import 'package:nox_iptv/services/sports_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/utils/constants.dart';

class _Feed extends SportsService {
  _Feed(this.games)
      : super.forTesting(MockClient((_) async => http.Response('{}', 200)));
  final List<SportsGame> games;
  @override
  Future<List<SportsGame>> gamesForDay(
          List<SportsLeague> leagues, DateTime day) async =>
      games;
  @override
  void prefetchSummary(SportsGame game) {}
}

void main() {
  testWidgets(
      'live card grid keeps D-pad columns and handles a partial last row',
      (tester) async {
    tester.view.physicalSize = const Size(940, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final league = sportsLeagueById('nfl')!;
    final games = [
      for (var i = 0; i < 7; i++)
        SportsGame(
          id: '$i',
          league: league,
          start: DateTime(2026, 10, 25, i),
          state: GameState.live,
          statusText: 'Live',
          home: const SportsTeam(
              id: 'h', name: 'Home', shortName: 'Home', abbreviation: 'H'),
          away: const SportsTeam(
              id: 'a', name: 'Away', shortName: 'Away', abbreviation: 'A'),
        )
    ];
    await tester.pumpWidget(ChangeNotifierProvider<AppPreferences>.value(
        value: AppPreferences(storage)
          ..layoutMode = 'auto'
          ..palette = AppConstants.cyberpunkPalettes.first,
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: SportsLiveListScreen(
              leagues: [league],
              day: DateTime(2026, 10, 25),
              follows: SportsFollows.load(storage),
              hideScores: false,
              matchGames: (_) async => {},
              onWatch: (_) async {},
              onMenu: (game, matches, watch) async {},
              initialGames: games,
              service: _Feed(games),
              cardBuilder:
                  (game, match, matching, node, onFocus, onTap, onHold) =>
                      SizedBox(
                          height: 150,
                          child: OutlinedButton(
                              focusNode: node,
                              onFocusChange: (focused) {
                                if (focused) onFocus();
                              },
                              onPressed: onTap,
                              onLongPress: onHold,
                              child: Text('Game ${game.id}'))),
            ))));
    await tester.pumpAndSettle();
    String? focused() => FocusManager.instance.primaryFocus?.debugLabel;
    final first = focused();
    expect(first, endsWith(':0'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focused(), endsWith(':2'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focused(), endsWith(':2'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focused(), endsWith(':5'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focused(), endsWith(':6'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focused(), endsWith(':6'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(focused(), endsWith(':3'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
