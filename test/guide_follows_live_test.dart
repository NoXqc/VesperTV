import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/catchup.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/models/m3u_group.dart';
import 'package:nox_iptv/screens/tv_home_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/viewer_profile_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// The Timeline guide opens another group at the live half-hour, wherever
/// the previous group's view was (owner photo, 2026-11-14: a new group
/// opened at 07:30 at 08:18), and leaves a catch-up window for live.
final _news = Channel(
  id: 'p::cu.ca',
  rawId: 'cu.ca',
  playlistId: 'p',
  name: 'Catchup channel',
  group: 'News',
  url: 'http://host:80/live/u/pw/11.ts',
  catchupDays: 2,
  catchupKind: CatchupKind.xc,
  streamId: '11',
);
final _sports = Channel(
    id: 'p::sports.ca',
    rawId: 'sports.ca',
    playlistId: 'p',
    name: 'Sports channel',
    group: 'Sports',
    url: 'http://host:80/live/u/pw/12.ts');

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> get channels => [_news, _sports];
  @override
  List<M3uGroup> get tvGroups => [
        M3uGroup(title: 'News', playlistId: 'p', channels: [_news]),
        M3uGroup(title: 'Sports', playlistId: 'p', channels: [_sports]),
      ];
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      switch (groupTitle) {
        'News' => [_news],
        'Sports' => [_sports],
        _ => [_news, _sports],
      };
  @override
  bool isPlaylistEnabled(String playlistId) => true;
  @override
  List<Channel> catchupLiveChannels() => [_news];
}

/// Half-hour programmes from 30 h ago to 6 h ahead.
class _Epg extends EpgService {
  _Epg(super.storage);
  final Map<String, List<EpgProgram>> _rows = {};

  @override
  List<EpgProgram> getPrograms(String channelId) =>
      _rows.putIfAbsent(channelId, () {
        final now = DateTime.now();
        final base = DateTime(now.year, now.month, now.day, now.hour)
            .subtract(const Duration(hours: 30));
        return [
          for (var i = 0; i < 72; i++)
            EpgProgram(
                channelId: channelId,
                title: '$channelId #$i',
                start: base.add(Duration(minutes: 30 * i)),
                stop: base.add(Duration(minutes: 30 * (i + 1)))),
        ];
      });
}

class _Platform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Widget buildView(int id) => const SizedBox();
  @override
  Future<void> dispose(int id) async {}
}

class _FakePlayer extends VideoPlayerHdrController {
  _FakePlayer(String url) : super.networkUrl(Uri.parse(url));
  @override
  Future<void> initialize(
      {VideoViewType viewType = VideoViewType.textureView}) async {
    value = value.copyWith(
        isInitialized: true,
        duration: const Duration(minutes: 30),
        size: const Size(1920, 1080));
  }

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);
  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);
  @override
  Future<void> seekTo(Duration position) async {}
  @override
  int get textureId => 9;
  @override
  bool isVideoTrackSupportAvailable() => false;
  @override
  bool isAudioTrackSupportAvailable() => false;
}

void main() {
  late PlaybackService playback;

  setUp(() {
    final previousPlatform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _Platform();
    addTearDown(() => VideoPlayerPlatform.instance = previousPlatform);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage([null]));
    messenger.setMockMethodCallHandler(
        const MethodChannel('vespertv/stats'), (_) async => null);
  });

  Future<void> pumpHome(WidgetTester tester,
      {Size size = const Size(1280, 720), bool television = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyShowClock: false,
      AppConstants.keyHideCatchupGroup: true,
    });
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = television;
    prefs.guideViewMode = 'timeline';
    prefs.guideFullVideo = false;
    final playlist = _Playlist(storage);
    playback = PlaybackService(storage, playlist)
      ..createController = (url, {closedCaptionFile, httpHeaders = const {}}) =>
          _FakePlayer(url);
    final epg = _Epg(storage);
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
    final tabFocus =
        television ? Focus.of(tester.element(find.text('TV'))) : null;
    // A phone opens on the Favourites page: back to the groups first.
    if (find.text('News').evaluate().isEmpty) {
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('News').first);
    await tester.pumpAndSettle();
    tabFocus?.requestFocus();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 16));
    addTearDown(() async {
      await playback.stop();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 20));
      playback.dispose();
      viewers.dispose();
      playlist.dispose();
      prefs.dispose();
      epg.dispose();
      await tester.pump();
    });
  }

  /// The programme grid's horizontal scroll (the one holding the blocks).
  double gridOffset(WidgetTester tester, String channelRawId) {
    final block = find.textContaining('$channelRawId #').first;
    final scrollable = find
        .ancestor(of: block, matching: find.byType(Scrollable))
        .evaluate()
        .map((e) => (e as StatefulElement).state as ScrollableState)
        .firstWhere((s) => s.position.axis == Axis.horizontal);
    return scrollable.position.pixels;
  }

  Future<void> openGroup(WidgetTester tester, String title) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Finder channelLabels() => find
      .byWidgetPredicate((w) => w.runtimeType.toString() == '_ChannelLabel');

  testWidgets(
      'TV guide: number + logo + name on one line (264 wide: the logo box is 1.75x wider than tall)',
      (tester) async {
    await pumpHome(tester);
    final label = channelLabels().first;
    expect((tester.widget(label) as dynamic).number, 1);
    expect(tester.getSize(label).width, 264);
  });

  testWidgets('phone guide keeps the narrow two-line channel column',
      (tester) async {
    // Owner's phone (+891): the TV's one-line column (240 wide) left the
    // programmes a sliver of a 390 px screen.
    await pumpHome(tester, size: const Size(400, 850), television: false);
    final label = channelLabels().first;
    expect((tester.widget(label) as dynamic).number, isNull);
    expect(tester.getSize(label).width, 160);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('another group opens at the live half-hour', (tester) async {
    await pumpHome(tester);
    final live = gridOffset(tester, 'cu.ca');
    // Drag the view a couple of hours ahead.
    await tester.drag(find.textContaining('cu.ca #').hitTestable().first,
        const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(gridOffset(tester, 'cu.ca'), isNot(closeTo(live, 1)));
    await openGroup(tester, 'Sports');
    expect(find.text('Sports channel'), findsWidgets);
    expect(gridOffset(tester, 'sports.ca'), closeTo(live, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('another group leaves a catch-up window for live',
      (tester) async {
    await pumpHome(tester);
    final live = gridOffset(tester, 'cu.ca');
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.textContaining('cu.ca #').hitTestable().first,
          const Offset(900, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('Now'), findsOneWidget,
        reason: 'the swipe loaded an older window');
    await openGroup(tester, 'Sports');
    await tester.pumpAndSettle();
    expect(find.text('Now'), findsNothing);
    expect(gridOffset(tester, 'sports.ca'), closeTo(live, 7),
        reason: 'a fresh window, a few seconds later');
    expect(tester.takeException(), isNull);
  });
}
