import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/home_screen.dart';
import 'package:nox_iptv/screens/settings/general_settings_screen.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/home_rows.dart';
import 'package:nox_iptv/services/guide_key.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wide_guide_back_test.dart' show GuideEpg, MovieGuidePlaylist;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late AppPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({AppConstants.keyShowClock: false});
    storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
  });

  tearDown(() => prefs.dispose());

  test('navigation switches persist independently; all-hidden fallback is Home',
      () async {
    expect(prefs.hideLiveTv, isFalse);
    expect(prefs.hideSportsTrak, isFalse);
    prefs.setHideLiveTv(true);
    prefs.setHideSportsTrak(true);
    prefs.setStartSection('sports');
    expect(prefs.effectiveStartSection, 'movies');
    prefs.setHideMovies(true);
    expect(prefs.effectiveStartSection, 'series');
    prefs.setHideShows(true);
    expect(prefs.effectiveStartSection, 'home');
    final reloaded = AppPreferences(storage);
    await reloaded.init();
    expect(reloaded.hideLiveTv, isTrue);
    expect(reloaded.hideSportsTrak, isTrue);
    expect(reloaded.fallbackTab, 'Home');
    reloaded.dispose();
    prefs.setHideLiveTv(false);
    expect(prefs.effectiveStartSection, 'tv');
    expect(prefs.hideSportsTrak, isTrue);
  });

  test('Sports Mode and hidden Sports Trak cannot trap each other', () async {
    await prefs.setSportsMode(true);
    prefs.setHideSportsTrak(true);
    expect(prefs.sportsMode, isFalse);
    expect(storage.getSportsMode(), isFalse);
    prefs.setHideSportsTrak(false);
    expect(prefs.sportsMode, isFalse);
    prefs.setHideSportsTrak(true);
    await prefs.setSportsMode(true);
    expect(prefs.hideSportsTrak, isFalse);
    expect(storage.getHideSportsTrak(), isFalse);
    expect(prefs.sportsMode, isTrue);
  });

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    prefs.isTelevision = size.width > 1000;
    final playlist = MovieGuidePlaylist(storage);
    final playback = PlaybackService(storage, playlist);
    final epg = GuideEpg(storage);
    final viewers = ViewerProfileService(storage, playlist, playback);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: prefs),
        ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
        ChangeNotifierProvider.value(value: playback),
        ChangeNotifierProvider<EpgService>.value(value: epg),
        ChangeNotifierProvider.value(value: viewers),
        ChangeNotifierProvider(create: (_) => ArchiveService(storage)),
      ],
      child: MaterialApp(
        navigatorObservers: [appRouteObserver],
        home: const TvHomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    // The root's once-per-launch update check starts after four seconds.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  for (final size in [const Size(1920, 1080), const Size(420, 900)]) {
    testWidgets('settings hide active Live TV and Sports Trak; size=$size',
        (tester) async {
      await pumpHome(tester, size);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(MaterialPageRoute<void>(
          builder: (_) =>
              const GeneralSettingsScreen(sections: {'tabs'}, title: 'Tabs')));
      await tester.pumpAndSettle();
      for (final label in ['Hide Live TV', 'Hide Sports Trak']) {
        await tester.ensureVisible(find.text(label));
        // ensureVisible doesn't pump: a row that had to scroll (below a
        // phone-sized screen) is only there after the next frame.
        await tester.pump();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      navigator.pop();
      await tester.pumpAndSettle();
      expect(prefs.hideLiveTv, isTrue);
      expect(prefs.hideSportsTrak, isTrue);
      expect(find.text('TV').hitTestable(), findsNothing);
      expect(find.text(AppConstants.sportsTabName), findsNothing);
      expect(find.text('Movies').hitTestable(), findsWidgets);
      expect(find.text('Test group'), findsNothing);
      (tester.state(find.byType(TvHomeScreen)) as GuideTarget).openGuide();
      await tester.pumpAndSettle();
      expect(find.text('Test group'), findsNothing);
      navigator.push(MaterialPageRoute<void>(
          builder: (_) =>
              const GeneralSettingsScreen(sections: {'tabs'}, title: 'Tabs')));
      await tester.pumpAndSettle();
      for (final label in ['Hide Live TV', 'Hide Sports Trak']) {
        await tester.ensureVisible(find.text(label));
        // ensureVisible doesn't pump: a row that had to scroll (below a
        // phone-sized screen) is only there after the next frame.
        await tester.pump();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('TV').hitTestable(), findsWidgets);
      expect(
          find.text(AppConstants.sportsTabName).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('all content tabs hidden start on usable Home; size=$size',
        (tester) async {
      prefs.setHideLiveTv(true);
      prefs.setHideMovies(true);
      prefs.setHideShows(true);
      prefs.setHideSportsTrak(true);
      await storage
          .setHomeRows([for (final kind in HomeRowKind.values) '-${kind.id}']);
      await pumpHome(tester, size);
      expect(find.byType(HomeScreen).hitTestable(), findsOneWidget);
      expect(find.text('TV'), findsNothing);
      expect(find.text(AppConstants.sportsTabName), findsNothing);
      if (size.width > 1000) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      } else {
        await tester.tap(find.text('More'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Settings').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Home').hitTestable().first);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
