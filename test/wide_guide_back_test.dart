import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/m3u_group.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuidePlaylist extends PlaylistManager {
  GuidePlaylist(StorageService storage) : super(storage, CatalogDatabase());

  final live = Channel(
      id: 'p::one',
      rawId: 'one',
      playlistId: 'p',
      name: 'Test channel',
      group: 'Test group',
      url: 'https://example.com/live');

  @override
  List<Channel> get channels => [live];

  @override
  List<M3uGroup> get tvGroups => [
        M3uGroup(title: 'Test group', playlistId: 'p', channels: [live])
      ];

  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      [live];
}

class GuideEpg extends EpgService {
  GuideEpg(super.storage);

  @override
  List<EpgProgram> getPrograms(String channelId) => [];
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
  });
  Future<void> pumpHome(WidgetTester tester, Size size,
      {bool television = false}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyShowClock: false,
    });
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = television;
    prefs.guideViewMode = 'timeline';
    prefs.guideFullVideo = true;
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
          ChangeNotifierProvider(create: (_) => ArchiveService(storage)),
        ],
        child: MaterialApp(
            navigatorObservers: [appRouteObserver],
            home: const TvHomeScreen())));
    await tester.pumpAndSettle();
    // Drain the one-off launch-update delay/timeout in virtual test time.
    // Widget tests block HTTP; no real update request is made.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 16));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      playback.dispose();
      viewers.dispose();
      playlist.dispose();
      prefs.dispose();
      epg.dispose();
      await tester.pump();
    });
  }

  testWidgets('cold focus loss recovers a concrete TV tab selector',
      (tester) async {
    await pumpHome(tester, const Size(1280, 720), television: true);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv-tab-TV');
    expect(tester.takeException(), isNull);
  });

  testWidgets('return from Media Hub focuses TV with the guide closed',
      (tester) async {
    await pumpHome(tester, const Size(1280, 720), television: true);
    await tester.tap(find.text('Media Hub'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'tv-tab-TV');
    expect(find.byType(TvHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty movie carousel keeps a real group selector',
      (tester) async {
    await pumpHome(tester, const Size(1280, 720), television: true);
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, isNot(isA<FocusScopeNode>()));
    expect(FocusManager.instance.primaryFocus?.context, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(720, 720),
    const Size(840, 960),
    const Size(1024, 600)
  ]) {
    testWidgets('wide non-TV guide has working Back at $size', (tester) async {
      await pumpHome(tester, size);
      expect(find.byTooltip('Back'), findsNothing);
      await tester.tap(find.text('Test group'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      // First Back opens groups; second opens tabs, without exiting.
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsNothing);
      expect(find.byType(TvHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        variant: const TargetPlatformVariant(
            {TargetPlatform.android, TargetPlatform.windows}));
  }

  for (final systemBack in [false, true]) {
    testWidgets(
        '${systemBack ? 'System' : 'Touch'} Back reopens columns when focus cannot move during resize',
        (tester) async {
      await pumpHome(tester, const Size(840, 960));
      await tester.tap(find.text('Test group'));
      await tester.pumpAndSettle();
      final columns = tester
          .widgetList<FocusScope>(find.byType(FocusScope))
          .map((w) => w.focusNode)
          .whereType<FocusScopeNode>()
          .where((n) => n.debugLabel == 'tv-col1' || n.debugLabel == 'tv-tabs')
          .toList();
      expect(columns, hasLength(2));
      // Touch navigation must work even while the newly laid-out column
      // cannot accept focus (for example during fold/unfold reparenting).
      for (final node in columns) {
        node.canRequestFocus = false;
      }
      await tester.pump();
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.text('Test group').hitTestable(), findsNothing);
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Test group').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsNothing);
      expect(find.byType(TvHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('compact portrait retains its existing single back arrow',
      (tester) async {
    await pumpHome(tester, const Size(400, 850));
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byType(TvHomeScreen), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('folding and unfolding keeps a way back from the guide',
      (tester) async {
    await pumpHome(tester, const Size(840, 960));
    await tester.tap(find.text('Test group'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    tester.view.physicalSize = const Size(400, 850);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    tester.view.physicalSize = const Size(840, 960);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Test group').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'expanded Timeline uses full height, persists and keeps guide state and Back',
      (tester) async {
    await pumpHome(tester, const Size(1920, 1080));
    await tester.tap(find.text('Test group'));
    await tester.pumpAndSettle();
    final guide = find
        .byWidgetPredicate((w) => w.runtimeType.toString() == '_TimelineGuide');
    final originalState = tester.state(guide);
    final collapsedHeight = tester.getSize(guide).height;
    final context = tester.element(find.byType(TvHomeScreen));
    final prefs = context.read<AppPreferences>();
    expect(prefs.guideExpanded, isFalse);
    prefs.setGuideExpanded(true);
    await tester.pumpAndSettle();
    expect(tester.getSize(guide).height, greaterThan(collapsedHeight * 1.8));
    expect(tester.state(guide), same(originalState));
    final restored = AppPreferences(context.read<StorageService>());
    await restored.init();
    expect(restored.guideExpanded, isTrue);
    restored.dispose();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Test group').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('real TV keeps remote navigation without a header back button',
      (tester) async {
    await pumpHome(tester, const Size(1920, 1080), television: true);
    await tester.tap(find.text('Test group'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
