import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/screens/sports_my_teams_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/game_reminders.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/sports_follows.dart';
import 'package:nox_iptv/services/sports_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'handoff_sports_regression_test.dart' show channel, game;

class _Playlist extends PlaylistManager {
  _Playlist(super.storage, super.catalog);
  @override
  Future<void> ensureLiveChannelsLoaded() async {}
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      [channel('preferred', 'Regional TV')];
}

class _Guide extends EpgService {
  _Guide(super.storage);
  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
          DateTime from, DateTime to, List<String> terms) async =>
      [];
  @override
  Future<double?> guideCoverageAt(DateTime at) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'team defaults need no game, merge current picks and retain match overrides',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final old = SportsChannelPicks.load(storage);
    final latest = SportsChannelPicks.load(storage);
    final g = game('game', DateTime.now().toUtc());
    await latest.pickForGame(g, 'p::event');
    await old.setPreferredChannel('nfl', 'a', 'p::team');
    final picks = SportsChannelPicks.load(storage);
    expect(picks.preferredChannel('nfl', 'a'), 'p::team');
    expect(picks.channelIdFor(g), 'p::event');
    expect(picks.channelIdFor(game('other', g.start)), 'p::team');
    expect(
        storage
            .exportForTransfer()
            .keys
            .any((k) => k.contains('sports_channel_picks')),
        true);
    await storage.setActiveViewerId('other');
    expect(SportsChannelPicks.load(storage).preferredChannel('nfl', 'a'), null);
    await storage.setActiveViewerId('main');
    await SportsChannelPicks.load(storage)
        .setPreferredChannel('nfl', 'a', null);
    expect(SportsChannelPicks.load(storage).preferredChannel('nfl', 'a'), null);
    expect(SportsChannelPicks.load(storage).channelIdFor(g), 'p::event');
  });

  test('a team preference ranks first only while that channel is visible',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final guide = _Guide(storage);
    final matcher = SportsChannelMatcher(guide);
    final preferred = channel('preferred', 'Regional TV');
    final picks = SportsChannelPicks.load(storage);
    await picks.setPreferredChannel('nfl', 'a', preferred.id);
    final g = game('game', DateTime.now().toUtc());
    await matcher.prepare([preferred]);
    expect((await matcher.matchDay([g], picks)).values.single.first.channel.id,
        preferred.id);
    await matcher.prepare([]);
    expect((await matcher.matchDay([g], picks)).values.single, isEmpty);
    guide.dispose();
  });

  testWidgets(
      'hold a team with no upcoming games, pick a channel, then reset to automatic',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    final follows = SportsFollows.load(storage);
    await follows.follow('nfl', 'a');
    final playlist = _Playlist(storage, CatalogDatabase());
    final guide = _Guide(storage);
    final reminders = GameReminders(storage);
    final sports =
        SportsService.forTesting(MockClient((request) async => http.Response(
            jsonEncode(request.url.path.endsWith('/schedule')
                ? {
                    'team': {
                      'id': 'a',
                      'displayName': 'Buffalo Bills',
                      'abbreviation': 'BUF'
                    },
                    'events': [],
                  }
                : {}),
            200)));
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: storage),
          ChangeNotifierProvider.value(value: prefs),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<EpgService>.value(value: guide),
          ChangeNotifierProvider.value(value: reminders),
        ],
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: SportsMyTeamsScreen(
                leagues: [sportsLeagueById('nfl')!],
                follows: follows,
                hideScores: false,
                service: sports,
                matchGames: (_) async => {},
                onActivate: (_, __) async {},
                onMenu: (_, __) async {}))));
    // Team schedules parse on a worker isolate, outside fake test time.
    await tester.runAsync(() async {
      for (var i = 0;
          i < 50 &&
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    Future<void> openMenu() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('Set preferred channel'), findsOneWidget);
      await tester.tap(find.text('Set preferred channel'));
      await tester.pumpAndSettle();
    }

    await openMenu();
    await tester.tap(find.text('Regional TV').last);
    await tester.pumpAndSettle();
    expect(SportsChannelPicks.load(storage).preferredChannel('nfl', 'a'),
        'p::preferred');
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        'myteams-team-${follows.teams.single.key}');
    await openMenu();
    await tester.tap(find.text('Automatic channel'));
    await tester.pumpAndSettle();
    expect(SportsChannelPicks.load(storage).preferredChannel('nfl', 'a'), null);
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        'myteams-team-${follows.teams.single.key}');
    expect(tester.takeException(), isNull);
    // A team menu left open across a profile change cannot open the old
    // viewer's channel editor in the new viewer.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    await storage.setActiveViewerId('other');
    await tester.tap(find.text('Set preferred channel'));
    await tester.pumpAndSettle();
    expect(find.text('Preferred channel for Buffalo Bills'), findsNothing);
    expect(SportsChannelPicks.load(storage).preferredChannel('nfl', 'a'), null);
    await tester.pumpWidget(const SizedBox());
    prefs.dispose();
    playlist.dispose();
    guide.dispose();
    reminders.dispose();
  });
}
