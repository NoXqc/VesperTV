import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/profile_copy.dart';
import 'package:nox_iptv/models/sports.dart';
import 'package:nox_iptv/screens/settings/settings_menu_screen.dart';
import 'package:nox_iptv/screens/settings/sports_playlist_settings_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/sports_channel_matcher.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';
import 'handoff_sports_regression_test.dart' show game;

Channel feed(String playlist, String id, String name) => Channel(
    id: '$playlist::$id',
    rawId: id,
    playlistId: playlist,
    name: name,
    group: 'Sports',
    url: '');

class _Guide extends EpgService {
  _Guide(super.storage, this.programmes);
  final List<EpgProgram> programmes;
  int calls = 0;
  @override
  Future<List<EpgProgram>> findProgrammesByTitle(
      DateTime from, DateTime to, List<String> terms) async {
    calls++;
    return programmes;
  }

  @override
  Future<double?> guideCoverageAt(DateTime at) async => null;
}

PlaylistProfile profile(String id, {bool enabled = true}) => PlaylistProfile(
    id: id,
    name: 'Provider $id',
    mode: 'm3u',
    enabled: enabled,
    sortOrder: 0,
    createdAt: DateTime.utc(2026));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  setUp(() async {
    L10n.code = 'en';
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  test(
      'playlist outranks country and quality among the same valid game matches',
      () async {
    final g = game('one', DateTime.now().toUtc());
    final live = [
      feed('a', 'us', 'US - ESPN HD'),
      feed('b', 'ca', 'TSN 4K'),
      feed('b', 'wrong', 'TSN 2 HD')
    ];
    final guide = _Guide(storage, [
      for (final c in live)
        EpgProgram(
            channelId: c.rawId,
            title: c.rawId == 'wrong'
                ? 'Unrelated game'
                : '${g.home.name} vs ${g.away.name}',
            start: g.start,
            stop: g.start.add(const Duration(hours: 3)))
    ]);
    final matcher = SportsChannelMatcher(guide);
    await matcher.prepare(live);
    final picks = SportsChannelPicks.load(storage);
    await storage.setSportsPreferredCountries(['CA']);
    final before = (await matcher.matchDay([g], picks)).values.single;
    expect(before.first.channel.playlistId, 'b');
    final queries = guide.calls;
    await storage.setSportsPreferredPlaylist('a');
    final after = (await matcher.matchDay([g], picks)).values.single;
    expect(after.first.channel.playlistId, 'a');
    expect(after.map((m) => m.channel.id).toSet(),
        before.map((m) => m.channel.id).toSet());
    expect(after.map((m) => m.channel.id), isNot(contains('b::wrong')));
    expect({for (final m in after) m.channel.id: (m.score, m.reason, m.detail)},
        {for (final m in before) m.channel.id: (m.score, m.reason, m.detail)});
    expect(guide.calls, queries);
    await storage.setSportsPreferredPlaylist(null);
    expect(
        (await matcher.matchDay([g], picks))
            .values
            .single
            .map((m) => m.channel.id),
        before.map((m) => m.channel.id));
    guide.dispose();
  });

  test(
      'playlist preference retains explicit choices, evidence and fallback order',
      () async {
    final a = feed('a', 'a', 'TSN HD'), b = feed('b', 'b', 'US - ESPN 4K');
    final picks = SportsChannelPicks.load(storage);
    await storage.setSportsPreferredPlaylist('a');
    final evidence = ChannelMatch(b, MatchReason.guide, 80, gameEvidence: true);
    final generic = ChannelMatch(a, MatchReason.network, 50);
    expect(picks.orderMatches([generic, evidence]).first, evidence);
    final explicit = ChannelMatch(b, MatchReason.pick, 1000);
    expect(
        picks.orderMatches([
          ChannelMatch(a, MatchReason.guide, 80, gameEvidence: true),
          explicit
        ]).first,
        explicit);
    final added = ChannelMatch(b, MatchReason.pick, 950);
    expect(
        picks.orderMatches([
          ChannelMatch(a, MatchReason.guide, 80, gameEvidence: true),
          added
        ]).first,
        added);
    final matches = [evidence, generic];
    await storage.setSportsPreferredPlaylist('deleted-or-disabled');
    expect(picks.orderMatches(matches), preferSportsSources(matches));
    await storage.setSportsPreferQuality(false);
    expect(identical(picks.orderMatches(matches), matches), true);
    await storage.setSportsPreferredPlaylist(null);
    expect(identical(picks.orderMatches(matches), matches), true);
  });

  test('preferred broadcaster reaches the three-suggestion cap', () async {
    final base = game('one', DateTime.now().toUtc());
    final g = SportsGame(
        id: base.id,
        league: base.league,
        start: base.start,
        state: base.state,
        statusText: '',
        home: base.home,
        away: base.away,
        broadcasts: ['ESPN']);
    final live = [
      for (var i = 0; i < 5; i++) feed('b', 'b$i', 'US - ESPN FHD'),
      feed('a', 'a', 'US - ESPN HD')
    ];
    final guide = _Guide(storage, []);
    final matcher = SportsChannelMatcher(guide);
    await matcher.prepare(live);
    final picks = SportsChannelPicks.load(storage);
    expect(
        (await matcher.matchDay([g], picks))
            .values
            .single
            .any((m) => m.channel.playlistId == 'a'),
        false);
    await storage.setSportsPreferredPlaylist('a');
    final result = (await matcher.matchDay([g], picks)).values.single;
    expect(result.first.channel.playlistId, 'a');
    expect(result.length, 3);
    expect(result.every((m) => m.reason == MatchReason.network), true);
    expect(result.any((m) => m.channel.playlistId == 'b'), true);
    guide.dispose();
  });

  test('preferred series feed reaches the capped suggestions', () async {
    final base = game('race', DateTime.now().toUtc());
    final g = SportsGame(
        id: base.id,
        league: sportsLeagueById('racing.f1')!,
        start: base.start,
        state: base.state,
        statusText: '',
        home: base.home,
        away: base.away);
    final live = [
      for (var i = 0; i < 5; i++) feed('b', 'b$i', 'UK - Sky Sports F1 HD'),
      feed('a', 'a', 'UK - Sky Sports F1 HD')
    ];
    final guide = _Guide(storage, []);
    final matcher = SportsChannelMatcher(guide);
    await matcher.prepare(live);
    final picks = SportsChannelPicks.load(storage);
    expect(
        (await matcher.matchDay([g], picks))
            .values
            .single
            .any((m) => m.channel.playlistId == 'a'),
        false);
    await storage.setSportsPreferredPlaylist('a');
    final result = (await matcher.matchDay([g], picks)).values.single;
    expect(result.first.channel.playlistId, 'a');
    expect(result.length, 3);
    guide.dispose();
  });

  test(
      'preferred playlist is viewer-scoped, copyable and survives backup/transfer',
      () async {
    await storage.setSportsPreferredPlaylist('a');
    final payload = storage.exportForTransfer();
    expect(
        storage
            .exportForBackup()
            .keys
            .any((k) => k.contains('sports_preferred_playlist')),
        true);
    await storage.copyMainToViewer('copy', {ProfileCopy.sports},
        restricted: false);
    await storage.setActiveViewerId('other');
    expect(storage.getSportsPreferredPlaylist(), null);
    await storage.setSportsPreferredPlaylist('b');
    await storage.setActiveViewerId('copy');
    expect(storage.getSportsPreferredPlaylist(), 'a');
    await storage.setActiveViewerId('main');
    await storage.setSportsPreferredPlaylist(null);
    await storage.importForTransfer(payload);
    expect(storage.getSportsPreferredPlaylist(), 'a');
  });

  for (final size in [const Size(1280, 720), const Size(390, 760)]) {
    testWidgets(
        'Sports settings opens preferred playlist, selects with D-pad and resets at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await storage.setPlaylists([profile('a'), profile('b')]);
      final prefs = AppPreferences(storage);
      await prefs.init();
      await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: storage),
            ChangeNotifierProvider.value(value: prefs)
          ],
          child: MaterialApp(
              theme: ThemeData.dark(), home: const SettingsMenuScreen())));
      await tester.pumpAndSettle();
      final category = find.widgetWithText(TvMenuTile, 'Sports Trak');
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      final entry = find.widgetWithText(TvMenuTile, 'Preferred playlist');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(SportsPlaylistSettingsScreen), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferredPlaylist(), 'a');
      final focus = FocusManager.instance.primaryFocus;
      expect(focus?.context?.findAncestorWidgetOfExactType<TvMenuTile>()?.key,
          const ValueKey('sports-playlist-a'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferredPlaylist(), null);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SportsPlaylistSettingsScreen), findsNothing);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      prefs.dispose();
    });
  }

  for (final lang in ['en', 'fr', 'es', 'it', 'el']) {
    testWidgets(
        'playlist settings large text, unavailable preference and stale viewer in $lang',
        (tester) async {
      L10n.code = lang;
      addTearDown(() => L10n.code = 'en');
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await storage
          .setPlaylists([profile('disabled', enabled: false), profile('a')]);
      await storage.setSportsPreferredPlaylist('disabled');
      await tester.pumpWidget(Provider.value(
          value: storage,
          child: MaterialApp(
              theme: ThemeData.dark(),
              home: const MediaQuery(
                  data: MediaQueryData(
                      size: Size(390, 760), textScaler: TextScaler.linear(1.4)),
                  child: SportsPlaylistSettingsScreen()))));
      await tester.pumpAndSettle();
      expect(
          find.text(tr(
              'Your preferred playlist is unavailable or disabled. Other matching playlists will be used.')),
          findsOneWidget);
      final disabled = find.byKey(const ValueKey('sports-playlist-disabled'));
      await tester.scrollUntilVisible(disabled, 160);
      expect(tester.widget<TvMenuTile>(disabled).enabled, false);
      final a = find.byKey(const ValueKey('sports-playlist-a'));
      await tester.scrollUntilVisible(a, 160);
      await tester.ensureVisible(a);
      await tester.pumpAndSettle();
      await tester.tap(a);
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferredPlaylist(), 'a');
      await storage.setActiveViewerId('other');
      await tester.tap(a);
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferredPlaylist(), null);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
