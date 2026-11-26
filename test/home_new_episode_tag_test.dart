import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/episode_alerts.dart';
import 'package:nox_iptv/services/home_rows.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_live_zap_test.dart' show ZapStorage;
import 'wide_guide_back_test.dart' show GuidePlaylist;

/// Owner + Kal-el23 (Discord, 2026-11-25): no New episodes row; a "Notify me"
/// show's new episode is a NEW tag on its Continue Watching card.
void main() {
  testWidgets('a new episode tags the Continue Watching card, no extra row',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    SharedPreferences.setMockInitialValues({});
    final storage = ZapStorage();
    await storage.init();
    // An old saved order still naming the New episodes row.
    await storage.setHomeRows([
      'continue',
      'new_episodes',
      for (final kind in HomeRowKind.values)
        if (kind != HomeRowKind.continueWatching) '-${kind.id}',
    ]);
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    String day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    await storage.setEpisodeAlerts(jsonEncode({
      'shows': [
        for (final (id, title) in [
          (7, 'Show Seven'),
          (8, 'Show Eight'),
          (9, 'Show Nine'),
        ])
          {
            ...FollowedShow(
                    key: FollowedShow.iptvKey('p', id),
                    title: title,
                    playlistId: 'p',
                    seriesId: id,
                    lastSeason: 1,
                    lastEpisode: 3)
                .toJson(),
            if (id == 9) ...{'next': day(tomorrow), 'ns': 1, 'ne': 4},
          },
      ],
      'notices': [
        EpisodeNotice(
                showKey: FollowedShow.iptvKey('p', 7),
                title: 'Show Seven',
                season: 1,
                episode: 3,
                at: now)
            .toJson(),
        // Watched to the end: no card of its own.
        EpisodeNotice(
                showKey: FollowedShow.iptvKey('p', 8),
                title: 'Show Eight',
                season: 2,
                episode: 1,
                at: now.subtract(const Duration(hours: 1)))
            .toJson(),
      ],
    }));
    final playlist = GuidePlaylist(storage);
    final playback = PlaybackService(storage, playlist);
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    final viewers = ViewerProfileService(storage, playlist, playback);
    final epg = EpgService(storage);
    final archive = ArchiveService(storage);
    final alerts = EpisodeAlerts(storage);
    Channel episode(int series, String name) => Channel(
        id: 'p::xt_ep_$series',
        rawId: 'xt_ep_$series',
        playlistId: 'p',
        name: name,
        group: 'Shows',
        url: 'https://example.com/$series',
        seriesId: series,
        seriesName: 'Show ${series == 7 ? 'Seven' : 'Nine'}');
    final seven = episode(7, 'S1 E2'), nine = episode(9, 'S1 E3');
    // Show Nine played last: without the notice it would come first.
    for (final c in [seven, nine]) {
      await playback.recordWatched(c);
      await storage.setLastPosition(c.id, 60000);
    }
    await tester.pumpWidget(MultiProvider(providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
      ChangeNotifierProvider<PlaybackService>.value(value: playback),
      ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
      ChangeNotifierProvider<EpgService>.value(value: epg),
      ChangeNotifierProvider<ArchiveService>.value(value: archive),
      ChangeNotifierProvider<EpisodeAlerts>.value(value: alerts),
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();

    expect(find.text('New episodes'), findsNothing);
    expect(find.text('Continue Watching'), findsOneWidget);
    // The row's cards, in order, named by their titles.
    final cards = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_HomeCard',
        description: 'Home card');
    Finder card(String title) => find.ancestor(
        of: find.descendant(of: cards, matching: find.text(title)),
        matching: cards);
    List<String> order() => [
          for (final e in cards.evaluate())
            for (final t in ['Show Seven', 'Show Eight', 'Show Nine'])
              if (find
                  .descendant(
                      of: find.byElementPredicate((x) => x == e),
                      matching: find.text(t))
                  .evaluate()
                  .isNotEmpty)
                t
        ];
    Finder inCard(String title, String text) =>
        find.descendant(of: card(title), matching: find.text(text));

    // Newest notice first, then the finished show's, then the others.
    expect(order(), ['Show Seven', 'Show Eight', 'Show Nine']);
    expect(inCard('Show Seven', 'NEW'), findsOneWidget);
    expect(inCard('Show Seven', 'S1 E3 is available'), findsOneWidget);
    expect(inCard('Show Eight', 'NEW'), findsOneWidget);
    expect(inCard('Show Eight', 'S2 E1 is available'), findsOneWidget);
    expect(inCard('Show Nine', 'Airs tomorrow'), findsOneWidget);
    expect(inCard('Show Nine', 'NEW'), findsNothing);

    // Dismissing the notice (opening the show) takes the tag away and the
    // card goes back to its place.
    await alerts.dismiss(FollowedShow.iptvKey('p', 7));
    await tester.pumpAndSettle();
    expect(inCard('Show Seven', 'NEW'), findsNothing);
    expect(order(), ['Show Eight', 'Show Nine', 'Show Seven']);

    await tester.pumpWidget(const SizedBox.shrink());
    alerts.dispose();
    viewers.dispose();
    playback.dispose();
    playlist.dispose();
    epg.dispose();
    archive.dispose();
    prefs.dispose();
  });
}
