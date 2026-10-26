import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/home_rows.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/widgets/profile_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_live_zap_test.dart' show ZapStorage;
import 'wide_guide_back_test.dart' show GuidePlaylist;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'hide profiles defaults off, persists and is independent for each viewer',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    expect(storage.getHideProfiles(), isFalse);
    await storage.setHideProfiles(true);
    final reopened = StorageService();
    await reopened.init();
    expect(reopened.getHideProfiles(), isTrue);
    await storage.setActiveViewerId('other');
    expect(storage.getHideProfiles(), isFalse);
    await storage.setHideProfiles(false);
    await storage.setActiveViewerId('main');
    expect(storage.getHideProfiles(), isTrue);
  });

  for (final populated in [false, true]) {
    testWidgets(
        'hidden strip keeps ${populated ? 'first-card' : 'empty-Home'} D-pad focus usable',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = ZapStorage();
      await storage.init();
      await storage.setHomeRows([
        for (final kind in HomeRowKind.values)
          populated && kind == HomeRowKind.recentChannels
              ? kind.id
              : '-${kind.id}',
      ]);
      final playlist = GuidePlaylist(storage);
      final playback = PlaybackService(storage, playlist);
      final prefs = AppPreferences(storage);
      await prefs.init();
      final viewers = ViewerProfileService(storage, playlist, playback);
      final epg = EpgService(storage);
      final archive = ArchiveService(storage);
      if (populated) await playback.recordWatched(playlist.live);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
              'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
              (_) async => const StandardMessageCodec().encodeMessage([null]));
      await tester.pumpWidget(MultiProvider(
          providers: [
            Provider<StorageService>.value(value: storage),
            ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
            ChangeNotifierProvider<PlaybackService>.value(value: playback),
            ChangeNotifierProvider<AppPreferences>.value(value: prefs),
            ChangeNotifierProvider<ViewerProfileService>.value(value: viewers),
            ChangeNotifierProvider<EpgService>.value(value: epg),
            ChangeNotifierProvider<ArchiveService>.value(value: archive),
          ],
          child: MaterialApp(
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                  builder: (_) => const HomeScreen())),
                          child: const Text('Open Home')))))));
      await tester.tap(find.text('Open Home'));
      await tester.pumpAndSettle();
      expect(
          find.byType(ProfileCard), findsNWidgets(viewers.profiles.length + 1));
      prefs.setHideProfiles(true);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileCard), findsNothing);
      expect(viewers.profiles.length, 1);
      final focus = FocusManager.instance.primaryFocus;
      expect(focus, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(focus));
      prefs.setHideProfiles(false);
      await tester.pumpAndSettle();
      expect(
          find.byType(ProfileCard), findsNWidgets(viewers.profiles.length + 1));
      expect(FocusManager.instance.primaryFocus, isNotNull);
      prefs.setHideProfiles(true);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileCard), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Open Home'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      viewers.dispose();
      playback.dispose();
      playlist.dispose();
      epg.dispose();
      archive.dispose();
      prefs.dispose();
    });
  }
}
