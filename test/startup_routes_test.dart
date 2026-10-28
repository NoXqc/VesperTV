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
import 'package:nox_iptv/utils/startup_routes.dart';
import 'package:nox_iptv/utils/route_observer.dart';

import 'wide_guide_back_test.dart' show GuideEpg, GuidePlaylist;

class CountingPlayback extends PlaybackService {
  CountingPlayback(super.storage, super.playlist);
  int stopCalls = 0;
  @override
  Future<void> stop() async {
    stopCalls++;
    currentChannel = null;
  }
}

void main() {
  late StorageService storage;
  late AppPreferences prefs;
  late StartupRoutes startup;
  const pages = ['tv', 'home', 'movies', 'series', 'hub', 'sports'];
  const overlays = ['home', 'hub', 'sports'];

  setUp(() async {
    SharedPreferences.setMockInitialValues({AppConstants.keyShowClock: false});
    storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
    startup = StartupRoutes();
  });

  tearDown(() {
    startup.dispose();
    prefs.dispose();
  });

  String rootSection() {
    final section = startup.takeRootSection();
    return ['movies', 'series'].contains(section) ? section : 'tv';
  }

  Widget probeRoot(BuildContext _) =>
      Scaffold(body: Text('Page ${rootSection()}'));

  Widget app({WidgetBuilder? rootBuilder}) => MaterialApp(
        navigatorObservers: [appRouteObserver],
        routes: {'/': rootBuilder ?? probeRoot},
        onGenerateInitialRoutes: (_) => startup.generate(
          preferences: prefs,
          storage: storage,
          rootBuilder: rootBuilder ?? probeRoot,
          destinations: {
            for (final page in overlays)
              page: (_) => Scaffold(body: Text('Page $page')),
          },
        ),
      );

  for (final fast in [true, false]) {
    testWidgets('Sports Mode uses one home route; Fast startup=$fast',
        (tester) async {
      await storage.setStartSection('sports');
      await storage.setStartSectionPending(true);
      await storage.setFastStartup(fast);
      await prefs.setSportsMode(true);
      await tester.pumpWidget(
          app(rootBuilder: (_) => const Scaffold(body: Text('Sports home'))));
      expect(find.text('Sports home').hitTestable(), findsOneWidget);
      expect(find.text('Page sports'), findsNothing);
      expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse);
      expect(storage.getStartSection(), 'sports');
      expect(storage.getStartSectionPending(), isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final page in pages) {
    for (final fast in [false, true]) {
      testWidgets('$page visible in first frame; Fast startup=$fast',
          (tester) async {
        await storage.setStartSection(page);
        await storage.setFastStartup(fast);
        await tester.pumpWidget(app());
        // No settle or second pump: post-frame navigation cannot paint yet.
        expect(find.text('Page $page').hitTestable(), findsOneWidget);
        if (page != 'tv') {
          expect(find.text('Page tv').hitTestable(), findsNothing);
        }
        expect(storage.getStartSectionPending(), page != 'tv');
        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        expect(nav.canPop(), overlays.contains(page));
        if (overlays.contains(page)) {
          nav.pop();
          await tester.pumpAndSettle();
          expect(find.text('Page tv').hitTestable(), findsOneWidget);
        }
        await tester.pump(const Duration(seconds: 15));
        expect(storage.getStartSectionPending(), isFalse);
        await tester.pumpWidget(const SizedBox());
      },
          variant: const TargetPlatformVariant(
              {TargetPlatform.android, TargetPlatform.windows}));
    }
  }

  for (final page in pages.where((page) => page != 'tv')) {
    testWidgets('$page startup crash guard falls back to TV once',
        (tester) async {
      await storage.setStartSection(page);
      await storage.setStartSectionPending(true);
      await tester.pumpWidget(app());
      expect(find.text('Page tv').hitTestable(), findsOneWidget);
      expect(storage.getStartSectionPending(), isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final page in ['movies', 'series', 'hub']) {
    testWidgets('hidden $page falls back to TV before first frame',
        (tester) async {
      await storage.setStartSection(page);
      if (page == 'movies') prefs.setHideMovies(true);
      if (page == 'series') prefs.setHideShows(true);
      if (page == 'hub') prefs.setHideArchive(true);
      await tester.pumpWidget(app());
      expect(find.text('Page tv').hitTestable(), findsOneWidget);
      expect(storage.getStartSectionPending(), isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Navigator/viewer remount does not replay the startup selection',
      (tester) async {
    await storage.setStartSection('home');
    await tester.pumpWidget(app());
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    expect(find.text('Page home'), findsNothing);
    expect(find.text('Page tv').hitTestable(), findsOneWidget);
    expect(startup.takeRootSection(), 'tv');
    await tester.pumpWidget(const SizedBox());
    startup.dispose();
  });

  for (final page in ['home', 'hub', 'movies', 'series', 'sports']) {
    testWidgets('real TV root starts on $page without a TV-first transition',
        (tester) async {
      await storage.setStartSection(page);
      prefs.setHideVideoOnSports(true);
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
              'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
              (_) async => const StandardMessageCodec().encodeMessage([null]));
      final playlist = GuidePlaylist(storage);
      final playback = CountingPlayback(storage, playlist);
      if (page != 'sports') {
        playback.currentChannel = playlist.live;
      }
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
          child: app(rootBuilder: (_) {
            final section = startup.takeRootSection();
            return TvHomeScreen(
                initialTab: switch (section) {
                  'movies' => 'Movies',
                  'series' => 'TV Shows',
                  _ => 'TV',
                },
                startupSportsCovered: section == 'sports',
                startupBrowseCovered: section == 'home' || section == 'hub');
          })));
      if (overlays.contains(page)) {
        expect(find.text('Page $page').hitTestable(), findsOneWidget);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
      } else {
        expect(find.text('Nothing playing').hitTestable(), findsNothing);
      }
      await tester.pumpAndSettle();
      if (overlays.contains(page)) {
        expect(find.text('Page $page'), findsNothing);
        expect(find.text('Nothing playing').hitTestable(), findsOneWidget);
        expect(find.byType(TvHomeScreen).hitTestable(), findsOneWidget);
      } else {
        expect(
            find.text(page == 'movies'
                ? 'No recently added movies yet'
                : 'No recently added shows yet'),
            findsOneWidget);
      }
      expect(playback.stopCalls, page == 'sports' ? 0 : 1);
      if (page != 'sports') {
        expect(playback.pendingResumeChannel?.id, playlist.live.id);
      }
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 16));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      playback.dispose();
      viewers.dispose();
      playlist.dispose();
      epg.dispose();
      await tester.pump();
    },
        variant: const TargetPlatformVariant(
            {TargetPlatform.android, TargetPlatform.windows}));
  }
}
