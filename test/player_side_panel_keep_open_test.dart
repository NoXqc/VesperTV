import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/player_side_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_live_zap_test.dart' show ZapStorage, ZapPlaylist;

/// Settings > Playback > Live TV (a Windows keyboard viewer, 2026-11-14):
/// the side panel stays open after a pick, and can switch channels as the
/// highlight moves. Off = it closes on OK, as before.
void main() {
  Channel ch(String id) => Channel(
      id: 'p::$id',
      rawId: id,
      playlistId: 'p',
      name: id.toUpperCase(),
      group: 'Sports',
      url: 'https://example.com/$id');

  Future<void> open(WidgetTester tester,
      {bool keepOpen = false,
      bool zapOnMove = false,
      required Future<void> Function(List<String> played,
              ValueNotifier<int> closed, ValueNotifier<Channel> current)
          check}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = ZapStorage();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    prefs.panelKeepOpen = keepOpen;
    prefs.panelZapOnMove = zapOnMove;
    final playlist = ZapPlaylist(storage);
    final playback = PlaybackService(storage, playlist);
    // Most recent last: C, then B, then A were watched before Z (playing).
    for (final id in ['c', 'b', 'a']) {
      await playback.recordWatched(ch(id));
    }
    final epg = EpgService(storage);
    final current = ValueNotifier(ch('z'));
    final closed = ValueNotifier(0);
    final played = <String>[];
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<PlaybackService>.value(value: playback),
          ChangeNotifierProvider<EpgService>.value(value: epg),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: ValueListenableBuilder<Channel>(
          valueListenable: current,
          builder: (context, playing, _) => SizedBox(
            width: PlayerSidePanel.width,
            child: PlayerSidePanel(
              current: playing,
              onClose: () => closed.value++,
              onPlay: (c) async {
                played.add(c.rawId);
                current.value = c;
              },
            ),
          ),
        )))));
    await tester.pumpAndSettle();
    await check(played, closed, current);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    playback.dispose();
    playlist.dispose();
    epg.dispose();
    prefs.dispose();
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  testWidgets('off: OK plays the last channel and closes', (tester) async {
    await open(tester, check: (played, closed, _) async {
      await press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(played, ['a']);
      expect(closed.value, 1);
    });
  });

  testWidgets('Keep open: OK plays, the panel stays, rows keep their place',
      (tester) async {
    await open(tester, keepOpen: true, check: (played, closed, current) async {
      // Rows: Z (playing), A, B, C; the highlight starts on A.
      expect(find.text('WATCHING'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(played, ['a']);
      expect(closed.value, 0);
      // Down = B (not reshuffled by A now playing), OK plays it.
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(played, ['a', 'b']);
      // Up twice = Z, the channel that was playing: one step from home.
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(played, ['a', 'b', 'z']);
      // OK on what's playing: done, the panel closes.
      await press(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(closed.value, 1);
    });
  });

  testWidgets('Switch while moving: the row the highlight rests on plays',
      (tester) async {
    await open(tester, zapOnMove: true, check: (played, closed, _) async {
      await press(tester, LogicalKeyboardKey.arrowDown); // B
      await press(tester, LogicalKeyboardKey.arrowDown); // C
      await tester.pump(const Duration(milliseconds: 300));
      expect(played, isEmpty, reason: 'one stream per stop, not per step');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(played, ['c']);
      expect(closed.value, 0);
    });
  });
}
