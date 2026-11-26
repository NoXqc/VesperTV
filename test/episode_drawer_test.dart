import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/widgets/episode_drawer.dart';

/// Kal-el23 (Discord, 2026-11-25): pick another episode from inside the
/// player. The list opens on the episode playing; Up / Down browse, Right /
/// Left jump a season, OK plays, Back closes.
void main() {
  Channel ep(int s, int e) => Channel(
      id: 'p::xt_ep_$s$e',
      rawId: 'xt_ep_$s$e',
      playlistId: 'p',
      name: 'S0${s}E0$e - Episode $e',
      group: 'Show',
      url: 'https://example.com/$s/$e');

  final episodes = [
    for (final s in [1, 2, 3])
      for (final e in [1, 2, 3]) (s, e, ep(s, e)),
  ];

  testWidgets('opens on the episode playing; Down + OK plays the next one',
      (tester) async {
    int? picked = -1;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async =>
                        picked = await showEpisodeDrawer(context, entries: [
                          for (final (s, e, c) in episodes)
                            EpisodeEntry(
                                channel: c,
                                season: s,
                                current: s == 2 && e == 2,
                                watched: s == 1),
                        ]),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Episodes'), findsOneWidget);
    expect(find.text('Playing'), findsOneWidget);
    expect(find.text('Season 1 · Watched'), findsWidgets);

    // OK on the episode playing just closes.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(picked, isNull);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(picked, 5); // S02E03
  });

  testWidgets('Right / Left jump a season, Back closes', (tester) async {
    int? picked = -1;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> openIt(BuildContext context) async =>
        picked = await showEpisodeDrawer(context, entries: [
          for (final (s, e, c) in episodes)
            EpisodeEntry(channel: c, season: s, current: s == 2 && e == 2),
        ]);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => openIt(context),
                    child: const Text('Open'))))));
    Future<int?> pick(List<LogicalKeyboardKey> keys) async {
      picked = -1;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      for (final k in keys) {
        await tester.sendKeyEvent(k);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      return picked;
    }

    // From S02E02: Right = S03E01; Left = S02E01, Left again = S01E01.
    expect(await pick([LogicalKeyboardKey.arrowRight]), 6);
    expect(await pick([LogicalKeyboardKey.arrowLeft]), 3);
    expect(
        await pick(
            [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft]),
        0);
    expect(await pick([LogicalKeyboardKey.channelUp]), 6);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    picked = -1;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Episodes'), findsNothing);
    expect(picked, isNull);
  });

  testWidgets('one season: Left closes like the Sources drawer',
      (tester) async {
    int? picked = -1;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async =>
                        picked = await showEpisodeDrawer(context, entries: [
                          for (final (_, e, c) in episodes.take(3))
                            EpisodeEntry(channel: c, current: e == 1),
                        ]),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
        find.text('Up/Down: browse · OK: play · Back: close'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Episodes'), findsNothing);
    expect(picked, isNull);
  });
}
