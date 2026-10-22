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
    await tester.pumpWidget(MultiProvider(providers: [
      Provider.value(value: storage),
      ChangeNotifierProvider.value(value: prefs),
      ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
      ChangeNotifierProvider.value(value: playback),
      ChangeNotifierProvider<EpgService>.value(value: epg),
      ChangeNotifierProvider.value(value: viewers),
    ], child: const MaterialApp(home: TvHomeScreen())));
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
    });
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
  });

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
  });

  testWidgets('real TV keeps remote navigation without a header back button',
      (tester) async {
    await pumpHome(tester, const Size(1920, 1080), television: true);
    await tester.tap(find.text('Test group'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back'), findsNothing);
  });
}
