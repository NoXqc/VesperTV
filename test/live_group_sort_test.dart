import 'package:flutter/material.dart';
import 'package:nox_iptv/utils/live_group_sort.dart';
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

  test('name sorting preserves stored order and stable ties', () {
    const names = ['Zulu', 'alpha', 'Alpha', 'Beta'];
    expect(LiveGroupSort.aToZ.sorted(names, (s) => s),
        ['alpha', 'Alpha', 'Beta', 'Zulu']);
    expect(LiveGroupSort.zToA.sorted(names, (s) => s),
        ['Zulu', 'Beta', 'alpha', 'Alpha']);
    expect(LiveGroupSort.provider.sorted(names, (s) => s), names);
  });

  test('sort persists across preferences and stays off transfers', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    expect(prefs.liveGroupSort, LiveGroupSort.provider);
    prefs.setLiveGroupSort(LiveGroupSort.zToA);
    final reopened = StorageService();
    await reopened.init();
    expect(AppPreferences(reopened).liveGroupSort, LiveGroupSort.zToA);
    expect(
        storage.exportForTransfer().containsKey(AppConstants.keyLiveGroupSort),
        isFalse);
    prefs.dispose();
  });

  testWidgets('sort icon accepts D-pad activation and offers all orders',
      (tester) async {
    await pumpHome(tester, const Size(1280, 720), television: true);
    final icon = find.byTooltip('Sort groups');
    expect(icon, findsOneWidget);
    // Reach the icon using the same default Up traversal as a TV remote.
    await tester.tap(find.text('Favourites').first);
    await tester.pumpAndSettle();
    final favorite = find.text('Favourites').first;
    Focus.of(tester.element(favorite)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Provider order'), findsOneWidget);
    expect(find.text('Name A–Z'), findsOneWidget);
    expect(find.text('Name Z–A'), findsOneWidget);
    await tester.tap(find.text('Name Z–A'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
