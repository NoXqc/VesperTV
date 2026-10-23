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
import 'package:nox_iptv/utils/startup_home_routes.dart';
import 'package:nox_iptv/utils/route_observer.dart';

import 'wide_guide_back_test.dart' show GuideEpg, GuidePlaylist;

void main() {
  late StorageService storage;
  late AppPreferences prefs;
  late StartupHomeRoutes routes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({AppConstants.keyShowClock: false});
    storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
    await storage.setStartSection('home');
    routes = StartupHomeRoutes();
  });

  tearDown(() {
    routes.dispose();
    prefs.dispose();
  });

  Widget app({WidgetBuilder? rootBuilder}) => MaterialApp(
        navigatorObservers: [appRouteObserver],
        routes: {
          '/': rootBuilder ??
              (_) => const Scaffold(body: Text('TV groups and guide')),
        },
        onGenerateInitialRoutes: (_) => routes.generate(
          preferences: prefs,
          storage: storage,
          rootBuilder: rootBuilder ??
              (_) => const Scaffold(body: Text('TV groups and guide')),
          homeBuilder: (_) => const Scaffold(body: Text('Startup Home')),
        ),
      );

  for (final fast in [false, true]) {
    testWidgets('Home is visible in the first frame; Fast startup=$fast',
        (tester) async {
      await storage.setFastStartup(fast);
      await tester.pumpWidget(app());
      // No settle or second pump: a post-frame push has not painted yet.
      expect(find.text('Startup Home').hitTestable(), findsOneWidget);
      expect(find.text('TV groups and guide').hitTestable(), findsNothing);
      expect(routes.homeHandled, isTrue);
      expect(storage.getStartSectionPending(), isTrue);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isTrue);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('TV groups and guide').hitTestable(), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      expect(storage.getStartSectionPending(), isFalse);
      await tester.pumpWidget(const SizedBox());
    },
        variant: const TargetPlatformVariant(
            {TargetPlatform.android, TargetPlatform.windows}));
  }

  testWidgets('pending startup crash guard retains the TV fallback',
      (tester) async {
    await storage.setStartSectionPending(true);
    await tester.pumpWidget(app());
    expect(find.text('TV groups and guide').hitTestable(), findsOneWidget);
    expect(find.text('Startup Home'), findsNothing);
    expect(routes.homeHandled, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  test('other destinations keep their existing root startup handling',
      () async {
    for (final section in ['tv', 'movies', 'series', 'hub', 'sports']) {
      await storage.setStartSection(section);
      final otherRoutes = StartupHomeRoutes();
      final generated = otherRoutes.generate(
        preferences: prefs,
        storage: storage,
        rootBuilder: (_) => const SizedBox(),
        homeBuilder: (_) => const SizedBox(),
      );
      expect(generated, hasLength(1));
      expect(otherRoutes.homeHandled, isFalse);
      expect(storage.getStartSectionPending(), isFalse);
      otherRoutes.dispose();
    }
  });

  testWidgets('recreating the Navigator does not reopen startup Home',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    expect(find.text('Startup Home'), findsNothing);
    expect(find.text('TV groups and guide').hitTestable(), findsOneWidget);
    expect(routes.homeHandled, isTrue);
    await tester.pumpWidget(const SizedBox());
    routes.dispose();
  });

  testWidgets('Back reaches the real TV root without reopening Home',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    final playlist = GuidePlaylist(storage);
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
      ],
      child: app(
          rootBuilder: (_) =>
              TvHomeScreen(startupHomeHandled: routes.homeHandled)),
    ));
    expect(find.text('Startup Home').hitTestable(), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Startup Home'), findsNothing);
    expect(find.byType(TvHomeScreen).hitTestable(), findsOneWidget);
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
  });
}
