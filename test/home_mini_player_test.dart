import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/home_rows.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/widgets/player_controls.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_live_zap_test.dart' show ZapStorage;
import 'wide_guide_back_test.dart' show GuidePlaylist;

/// Records what Home asks to play instead of opening a stream.
class _MiniPlayback extends PlaybackService {
  _MiniPlayback(super.storage, super.playlist);
  final plays = <(String, bool)>[];
  int stops = 0;

  @override
  Future<void> play(Channel channel, {bool recordHistory = true}) async {
    plays.add((channel.id, recordHistory));
    currentChannel = channel;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stops++;
    currentChannel = null;
    notifyListeners();
  }
}

/// Cache files in memory, so a second PlaybackService reads the first's.
class _FileStorage extends ZapStorage {
  final files = <String, String>{};
  @override
  Future<void> writeCacheFile(String name, String content) async =>
      files[name] = content;
  @override
  Future<String?> readCacheFile(String name) async => files[name];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home opened before the launch reads history fills its rows',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = _FileStorage();
    await storage.init();
    await storage.setHomeRows([
      for (final kind in HomeRowKind.values)
        kind == HomeRowKind.recentChannels ? kind.id : '-${kind.id}',
    ]);
    final playlist = GuidePlaylist(storage);
    // Last session's history, on disk.
    final earlier = PlaybackService(storage, playlist);
    await earlier.recordWatched(playlist.live);
    earlier.dispose();
    // This launch's service: history not read yet (main.dart reads it
    // after the UI shows).
    final playback = PlaybackService(storage, playlist);
    final prefs = AppPreferences(storage);
    await prefs.init();
    final viewers = ViewerProfileService(storage, playlist, playback);
    final epg = EpgService(storage);
    final archive = ArchiveService(storage);
    await tester.pumpWidget(MultiProvider(providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
      ChangeNotifierProvider<PlaybackService>.value(value: playback),
      ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
      ChangeNotifierProvider<EpgService>.value(value: epg),
      ChangeNotifierProvider<ArchiveService>.value(value: archive),
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Recent channels'), findsNothing);

    await playback.init();
    await tester.pumpAndSettle();
    expect(find.text('Recent channels'), findsOneWidget);
    expect(find.text(playlist.live.name), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    viewers.dispose();
    playback.dispose();
    playlist.dispose();
    epg.dispose();
    archive.dispose();
    prefs.dispose();
  });

  test('Home mini player defaults on, per viewer', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    expect(storage.getHomeMiniPlayer(), isTrue);
    await storage.setHomeMiniPlayer(false);
    await storage.setActiveViewerId('other');
    expect(storage.getHomeMiniPlayer(), isTrue);
    await storage.setActiveViewerId('main');
    expect(storage.getHomeMiniPlayer(), isFalse);
  });

  // Resting on a card plays it only with Preview on highlight on (owner,
  // 2026-11-10); Play/Pause works either way.
  for (final (label, size, on, highlight) in [
    ('rests on a live card', const Size(1920, 1080), true, true),
    ('switched off', const Size(1920, 1080), false, true),
    ('on a phone', const Size(420, 900), true, true),
    ('Preview on highlight off', const Size(1920, 1080), true, false),
  ]) {
    testWidgets('Home mini player: $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final storage = ZapStorage();
      await storage.init();
      await storage.setHomeRows([
        for (final kind in HomeRowKind.values)
          kind == HomeRowKind.recentChannels ? kind.id : '-${kind.id}',
      ]);
      final playlist = GuidePlaylist(storage);
      final playback = _MiniPlayback(storage, playlist);
      final prefs = AppPreferences(storage);
      await prefs.init();
      prefs.setHomeMiniPlayer(on);
      prefs.setGuideFocusPreview(highlight);
      final viewers = ViewerProfileService(storage, playlist, playback);
      final epg = EpgService(storage);
      final archive = ArchiveService(storage);
      final first = playlist.live;
      final second = Channel(
          id: 'p::two',
          rawId: 'two',
          playlistId: 'p',
          name: 'Second channel',
          group: 'Test group',
          url: 'https://example.com/two');
      await playback.recordWatched(second);
      await playback.recordWatched(first);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
              'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
              (_) async => const StandardMessageCodec().encodeMessage([null]));
      await tester.pumpWidget(MultiProvider(providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
        ChangeNotifierProvider<PlaybackService>.value(value: playback),
        ChangeNotifierProvider<AppPreferences>.value(value: prefs),
        ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
        ChangeNotifierProvider<EpgService>.value(value: epg),
        ChangeNotifierProvider<ArchiveService>.value(value: archive),
      ], child: const MaterialApp(home: HomeScreen())));
      await tester.pumpAndSettle();

      // Focus landing on the first card by itself plays nothing.
      await tester.pump(const Duration(seconds: 2));
      expect(playback.plays, isEmpty);
      expect(find.byType(VideoPlayerPane), findsNothing);

      // A quick pass over the card doesn't play it; resting does.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 500));
      expect(playback.plays, isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      if (!on || size.width < HomeScreen.miniPlayerMinWidth) {
        expect(playback.plays, isEmpty);
        expect(find.byType(VideoPlayerPane), findsNothing);
      } else if (!highlight) {
        // Resting plays nothing, however long.
        await tester.pump(const Duration(seconds: 2));
        expect(playback.plays, isEmpty);
        expect(find.byType(VideoPlayerPane), findsNothing);
        // OK plays the card in the mini player (not full screen)...
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(playback.plays, [(second.id, false)]);
        expect(find.byType(VideoPlayerPane), findsOneWidget);
        expect(find.byType(HomeScreen), findsOneWidget);
        // ...moving on doesn't switch it...
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump(const Duration(seconds: 2));
        expect(playback.plays, hasLength(1));
        // ...OK there plays that one...
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump();
        expect(playback.plays.last.$1, first.id);
        // ...and Play/Pause turns it off, on any card.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(seconds: 1));
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
        await tester.pump();
        expect(playback.stops, 1);
        expect(find.byType(VideoPlayerPane), findsNothing);
        // With nothing playing, Play/Pause plays the card.
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
        await tester.pump();
        expect(playback.plays.last.$1, second.id);
      } else {
        expect(playback.plays, [(second.id, false)]);
        expect(find.byType(VideoPlayerPane), findsOneWidget);
        // History only once it has played a while.
        expect(playback.recentlyPlayed.first.id, first.id);
        await tester.pump(const Duration(seconds: 10));
        expect(playback.recentlyPlayed.first.id, second.id);
        // Moving on and coming straight back plays nothing new.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(seconds: 1));
        expect(playback.plays, [(second.id, false)]);

        // Play/Pause on the playing card turns the mini player off, and it
        // stays off while the remote rests there.
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
        await tester.pump();
        expect(playback.stops, 1);
        expect(playback.currentChannel, isNull);
        expect(find.byType(VideoPlayerPane), findsNothing);
        await tester.pump(const Duration(seconds: 2));
        expect(playback.plays, hasLength(1));
        expect(find.byType(HomeScreen), findsOneWidget);
        // Off stays off: resting on another channel plays nothing.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump(const Duration(seconds: 2));
        expect(playback.plays, hasLength(1));
        expect(find.byType(VideoPlayerPane), findsNothing);

        // Play/Pause plays the card at once (no wait) and turns it back on.
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
        await tester.pump();
        expect(playback.plays.last.$1, first.id);
        expect(find.byType(VideoPlayerPane), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(seconds: 1));
        expect(playback.plays.last.$1, second.id);
        await tester.sendKeyEvent(LogicalKeyboardKey.mediaStop);
        await tester.pump();
        expect(playback.stops, 2);
        expect(find.byType(VideoPlayerPane), findsNothing);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
      viewers.dispose();
      playback.dispose();
      playlist.dispose();
      epg.dispose();
      archive.dispose();
      prefs.dispose();
    });
  }

  // A phone on its side (owner, 2026-11-13): no hero, the mini player in the
  // profiles row with a button that turns it off and back on.
  testWidgets('phone on its side: mini player button', (tester) async {
    tester.view.physicalSize = const Size(800, 380);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = ZapStorage();
    await storage.init();
    await storage.setHomeRows([
      for (final kind in HomeRowKind.values)
        kind == HomeRowKind.recentChannels ? kind.id : '-${kind.id}',
    ]);
    final playlist = GuidePlaylist(storage);
    final playback = _MiniPlayback(storage, playlist);
    final prefs = AppPreferences(storage);
    await prefs.init();
    final viewers = ViewerProfileService(storage, playlist, playback);
    final epg = EpgService(storage);
    final archive = ArchiveService(storage);
    await playback.recordWatched(playlist.live);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    await tester.pumpWidget(MultiProvider(providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
      ChangeNotifierProvider<PlaybackService>.value(value: playback),
      ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
      ChangeNotifierProvider<EpgService>.value(value: epg),
      ChangeNotifierProvider<ArchiveService>.value(value: archive),
    ], child: const MaterialApp(home: HomeScreen())));
    await tester.pumpAndSettle();

    final off = find.byTooltip('Turn off the mini player');
    expect(off, findsOneWidget);
    expect(find.byType(VideoPlayerPane), findsNothing);
    // A channel playing (back from full screen) shows in the row.
    await playback.play(playlist.live);
    await tester.pump();
    expect(find.byType(VideoPlayerPane), findsOneWidget);
    // Off: the channel stops, the switch is off, the button turns it on.
    await tester.tap(off);
    await tester.pump();
    expect(prefs.homeMiniPlayer, isFalse);
    expect(playback.stops, 1);
    expect(find.byType(VideoPlayerPane), findsNothing);
    await tester.tap(find.byTooltip('Turn on the mini player'));
    await tester.pump();
    expect(prefs.homeMiniPlayer, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
    viewers.dispose();
    playback.dispose();
    playlist.dispose();
    epg.dispose();
    archive.dispose();
    prefs.dispose();
  });
}
