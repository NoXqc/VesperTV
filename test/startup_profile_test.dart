import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/viewer_profile.dart';
import 'package:nox_iptv/screens/settings/general_settings_screen.dart';
import 'package:nox_iptv/screens/startup_profile_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/parental_pin.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/startup_routes.dart';
import 'package:nox_iptv/utils/tv_theme.dart';
import 'package:nox_iptv/widgets/profile_card.dart';

class StartupStorage extends StorageService {
  @override
  Future<String?> readCacheFile(String name) async => null;
}

class StartupPlayback extends PlaybackService {
  StartupPlayback(super.storage, super.manager);
  int stops = 0;
  Completer<void>? hold;
  bool fail = false;
  @override
  Future<void> stop() async {
    stops++;
    if (hold != null) await hold!.future;
    if (fail) throw StateError('fixture failure');
  }
}

class StartupFixture {
  final storage = StartupStorage();
  late final prefs = AppPreferences(storage);
  late final manager = PlaylistManager(storage, CatalogDatabase());
  late final playback = StartupPlayback(storage, manager);
  late final viewers = ViewerProfileService(storage, manager, playback,
      onViewerChanged: prefs.reloadPaletteForViewer);
  late final pin = ParentalPin(storage);
  int launches = 0;
  String? launchedViewer;
  final routes = StartupRoutes();

  Future<void> init(
      {int count = 3, String active = 'main', bool kid = false}) async {
    SharedPreferences.setMockInitialValues({});
    await storage.init();
    await storage.setViewerProfiles([
      ViewerProfile.main(),
      for (var i = 1; i < count; i++)
        ViewerProfile(
            id: 'p$i',
            name: 'Viewer $i',
            colorIndex: i % 6,
            isRestricted: kid && i == 1,
            createdAt: DateTime(2026)),
    ]);
    await storage.setActiveViewerId(active);
    await prefs.init();
  }

  Widget wrap(Widget child,
          {bool reduceMotion = false, double textScale = 1}) =>
      MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          Provider.value(value: pin),
          ChangeNotifierProvider.value(value: prefs),
          ChangeNotifierProvider.value(value: viewers),
        ],
        child: MaterialApp(
          theme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              colorScheme:
                  buildPaletteColorScheme(prefs.palette, Brightness.dark)),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                disableAnimations: reduceMotion,
                textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: child,
        ),
      );

  Widget picker({bool reduceMotion = false, double textScale = 1}) =>
      wrap(StartupProfileScreen(onSelected: () {
        launches++;
        launchedViewer = storage.getActiveViewerId();
      }), reduceMotion: reduceMotion, textScale: textScale);

  void dispose() {
    routes.dispose();
    viewers.dispose();
    prefs.dispose();
    manager.dispose();
    playback.dispose();
  }
}

Finder card(String id) => find.byKey(ValueKey('startup-profile-$id'));
ProfileCard profileCard(WidgetTester tester, String id) =>
    tester.widget<ProfileCard>(card(id));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
  });
  test(
      'selector defaults off, persists per device, backups keep it and transfers do not',
      () async {
    final f = StartupFixture();
    await f.init();
    addTearDown(f.dispose);
    expect(f.prefs.launchWithProfiles, isFalse);
    f.prefs.setLaunchWithProfiles(true);
    final reopened = StorageService();
    await reopened.init();
    expect(reopened.getLaunchWithProfiles(), isTrue);
    await reopened.setActiveViewerId('p1');
    expect(reopened.getLaunchWithProfiles(), isTrue);
    expect(reopened.exportForBackup(),
        contains(AppConstants.keyLaunchWithProfiles));
    expect(reopened.exportForTransfer(),
        isNot(contains(AppConstants.keyLaunchWithProfiles)));
    await reopened
        .importForTransfer({AppConstants.keyLaunchWithProfiles: false});
    expect(reopened.getLaunchWithProfiles(), isTrue);
  });

  testWidgets('Startup settings toggle is opt-in and persists on tap',
      (tester) async {
    final f = StartupFixture();
    await f.init();
    addTearDown(f.dispose);
    await tester
        .pumpWidget(f.wrap(const GeneralSettingsScreen(sections: {'startup'})));
    expect(f.prefs.launchWithProfiles, isFalse);
    await tester.tap(find.text('Launch with profiles selector'));
    await tester.pumpAndSettle();
    expect(f.prefs.launchWithProfiles, isTrue);
    await tester.tap(find.text('Launch with profiles selector'));
    await tester.pumpAndSettle();
    expect(f.prefs.launchWithProfiles, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('last viewer focused, Back cannot skip, same viewer can continue',
      (tester) async {
    final f = StartupFixture();
    await f.init(active: 'p1');
    addTearDown(f.dispose);
    await tester.pumpWidget(f.picker());
    await tester.pumpAndSettle();
    expect(profileCard(tester, 'p1').focusNode.hasFocus, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(f.launches, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(f.launchedViewer, 'p1');
    expect(f.playback.stops, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'switch finishes before animation and launch; repeat taps are ignored',
      (tester) async {
    final f = StartupFixture();
    await f.init();
    addTearDown(f.dispose);
    f.playback.hold = Completer<void>();
    await f.storage.setSportsMode(true);
    await f.storage.setActiveViewerId('p1');
    await f.storage.setSportsMode(false);
    await f.storage.setPaletteId('aqua');
    await f.storage.setActiveViewerId('main');
    await tester.pumpWidget(f.picker());
    await tester.pumpAndSettle();
    await tester.tap(card('p1'));
    await tester.tap(card('p1'), warnIfMissed: false);
    await tester.pump();
    expect(f.launches, 0);
    expect(f.viewers.active.id, 'main');
    expect(f.playback.stops, 1);
    f.playback.hold!.complete();
    await tester.pump();
    expect(f.viewers.active.id, 'p1');
    expect(f.prefs.palette.id, 'aqua');
    expect(f.prefs.sportsMode, isFalse);
    expect(f.launches, 0);
    expect(find.text('Welcome, Viewer 1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(f.launches, 0);
    await tester.pumpAndSettle();
    expect(f.launches, 1);
    expect(f.launchedViewer, 'p1');
    final generated = f.routes.generate(
        preferences: f.prefs,
        storage: f.storage,
        rootBuilder: (_) => const SizedBox(),
        destinations: {});
    expect(generated.length, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'restricted last viewer still needs PIN; cancellation restores focus',
      (tester) async {
    final f = StartupFixture();
    await f.init(active: 'p1', kid: true);
    addTearDown(f.dispose);
    await f.pin.setPin('1234');
    await tester.pumpWidget(f.picker());
    await tester.pumpAndSettle();
    await tester.tap(card('main'));
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsOneWidget);
    expect(f.launches, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(f.viewers.active.id, 'p1');
    expect(profileCard(tester, 'main').focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    for (final key in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(f.launchedViewer, 'main');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'failed switch stays in picker and can retry; reduced motion skips delay',
      (tester) async {
    final f = StartupFixture();
    await f.init();
    addTearDown(f.dispose);
    f.playback.fail = true;
    await tester.pumpWidget(f.picker(reduceMotion: true));
    await tester.pumpAndSettle();
    await tester.tap(card('p1'));
    await tester.pumpAndSettle();
    expect(find.text('Could not switch profile. Please try again.'),
        findsOneWidget);
    expect(f.launches, 0);
    f.playback.fail = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(f.launchedViewer, 'p1');
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(1280, 720),
    const Size(390, 844),
    const Size(740, 360)
  ]) {
    testWidgets('all viewers reachable by remote at $size with large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = StartupFixture();
      await f.init(count: 12);
      addTearDown(f.dispose);
      await tester.pumpWidget(f.picker(textScale: 1.5));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileCard), findsNWidgets(12));
      expect(profileCard(tester, 'main').focusNode.hasFocus, isTrue);
      final reached = <String>{'main'};
      // Sweep each row; Down from its final column must reach a partial row.
      for (var row = 0; row < 12; row++) {
        for (var column = 0; column < 5; column++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          reached.add(tester
              .widgetList<ProfileCard>(find.byType(ProfileCard))
              .firstWhere((p) => p.focusNode.hasFocus)
              .profile!
              .id);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        for (var column = 0; column < 5; column++) {
          reached.add(tester
              .widgetList<ProfileCard>(find.byType(ProfileCard))
              .firstWhere((p) => p.focusNode.hasFocus)
              .profile!
              .id);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.pumpAndSettle();
        }
      }
      expect(reached, hasLength(12));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        variant: const TargetPlatformVariant(
            {TargetPlatform.android, TargetPlatform.windows}));
  }
}
