import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/screens/home_screen.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/home_rows.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'native_live_zap_test.dart' show ZapStorage;
import 'wide_guide_back_test.dart' show GuidePlaylist, GuideEpg;

void main() {
  for (final startupHome in [false, true]) {
    for (final hidden in [false, true]) {
      for (final back in ['system', 'key', 'duplicate']) {
        testWidgets(
            'Home Back returns to TV without Exit: startup=$startupHome hidden=$hidden, $back',
            (tester) async {
          tester.view.physicalSize = const Size(1920, 1080);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          SharedPreferences.setMockInitialValues(
              {AppConstants.keyShowClock: false});
          final storage = ZapStorage();
          await storage.init();
          await storage.setHomeRows(
              [for (final kind in HomeRowKind.values) '-${kind.id}']);
          await storage.setHideProfiles(hidden);
          final prefs = AppPreferences(storage);
          await prefs.init();
          prefs.isTelevision = true;
          final playlist = GuidePlaylist(storage);
          final playback = PlaybackService(storage, playlist);
          final epg = GuideEpg(storage);
          final viewers = ViewerProfileService(storage, playlist, playback);
          final archive = ArchiveService(storage);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMessageHandler(
                  'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
                  (_) async =>
                      const StandardMessageCodec().encodeMessage([null]));
          await tester.pumpWidget(MultiProvider(
              providers: [
                Provider<StorageService>.value(value: storage),
                ChangeNotifierProvider<AppPreferences>.value(value: prefs),
                ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
                ChangeNotifierProvider<PlaybackService>.value(value: playback),
                ChangeNotifierProvider<EpgService>.value(value: epg),
                ChangeNotifierProvider<ViewerProfileService>.value(
                    value: viewers),
                ChangeNotifierProvider<ArchiveService>.value(value: archive),
              ],
              child: MaterialApp(
                  navigatorObservers: [appRouteObserver],
                  onGenerateInitialRoutes: startupHome
                      ? (_) => [
                            MaterialPageRoute<void>(
                                builder: (_) => const TvHomeScreen(
                                    startupBrowseCovered: true)),
                            MaterialPageRoute<void>(
                                builder: (_) => const HomeScreen()),
                          ]
                      : null,
                  routes: {'/': (_) => const TvHomeScreen()})));
          await tester.pumpAndSettle();
          if (!startupHome) {
            await tester.tap(find.text('Home'));
            await tester.pumpAndSettle();
          }
          expect(find.byType(HomeScreen), findsOneWidget);
          if (back == 'system') {
            await tester.binding.handlePopRoute();
          } else {
            await tester.sendKeyEvent(LogicalKeyboardKey.goBack,
                physicalKey: PhysicalKeyboardKey.escape);
            if (back == 'duplicate') {
              await tester.pumpAndSettle();
              await tester.binding.handlePopRoute();
            }
          }
          await tester.pumpAndSettle();
          expect(find.byType(HomeScreen), findsNothing);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text('TV').hitTestable(), findsOneWidget);
          // A deliberate later Back on TV still opens the existing Exit prompt.
          await tester.pump(const Duration(milliseconds: 750));
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          Navigator.of(tester.element(find.byType(AlertDialog))).pop(false);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 20));
          await tester.pumpWidget(const SizedBox());
          viewers.dispose();
          playback.dispose();
          playlist.dispose();
          prefs.dispose();
          epg.dispose();
          archive.dispose();
          await tester.pump();
        });
      }
    }
  }
}
