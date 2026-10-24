import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';

import 'startup_routes_test.dart' show CountingPlayback;
import 'wide_guide_back_test.dart' show GuideEpg, GuidePlaylist;

class BrowsePlayback extends CountingPlayback {
  BrowsePlayback(super.storage, super.playlist, this.native);
  final bool native;

  @override
  bool get usesNativeSurface => native;
}

void main() {
  for (final native in [false, true]) {
    for (final tab in ['Movies', 'TV Shows']) {
      for (final startup in [false, true]) {
        testWidgets('$tab keeps native=$native session; startup=$startup',
            (tester) async {
          tester.view.physicalSize = const Size(1920, 1080);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMessageHandler(
                  'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
                  (_) async =>
                      const StandardMessageCodec().encodeMessage([null]));
          SharedPreferences.setMockInitialValues(
              {AppConstants.keyShowClock: false});
          final storage = StorageService();
          await storage.init();
          final prefs = AppPreferences(storage);
          await prefs.init();
          final playlist = GuidePlaylist(storage);
          final playback = BrowsePlayback(storage, playlist, native)
            ..currentChannel = playlist.live;
          final epg = GuideEpg(storage);
          final viewers = ViewerProfileService(storage, playlist, playback);
          await tester.pumpWidget(MultiProvider(
              providers: [
                Provider.value(value: storage),
                ChangeNotifierProvider.value(value: prefs),
                ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
                ChangeNotifierProvider<PlaybackService>.value(value: playback),
                ChangeNotifierProvider<EpgService>.value(value: epg),
                ChangeNotifierProvider.value(value: viewers),
              ],
              child: MaterialApp(
                  home: TvHomeScreen(initialTab: startup ? tab : 'TV'))));
          await tester.pumpAndSettle();
          if (!startup) {
            await tester.tap(find.text(tab).hitTestable().first);
            await tester.pumpAndSettle();
          }
          expect(
              find.text(tab == 'Movies'
                  ? 'No recently added movies yet'
                  : 'No recently added shows yet'),
              findsOneWidget);
          expect(playback.stopCalls, native ? 0 : 1);
          expect(
              playback.currentChannel, native ? same(playlist.live) : isNull);
          expect(playback.pendingResumeChannel,
              native ? isNull : same(playlist.live));
          await tester.tap(find.text('TV').hitTestable().first);
          await tester.pumpAndSettle();
          expect(playback.stopCalls, native ? 0 : 1);
          expect(
              playback.currentChannel, native ? same(playlist.live) : isNull);
          await tester.pump(const Duration(seconds: 20));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          viewers.dispose();
          playback.dispose();
          playlist.dispose();
          epg.dispose();
          prefs.dispose();
          await tester.pump();
        });
      }
    }
  }
}
