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
import 'package:nox_iptv/utils/live_group_sort.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Playlists > jump lands on the jumped-to playlist's first group as the
/// column lists it (own groups above, Sort groups A-Z), and Back from the
/// guide afterwards always lands in the groups column (JcknDew,
/// LOG-34J43F: nothing took focus and the remote went dead).
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

final _other = Channel(
    id: 'q::other.ca',
    rawId: 'other.ca',
    playlistId: 'q',
    name: 'Other channel',
    group: 'Zulu',
    url: 'http://host2:80/live/u/pw/13.ts');

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> get channels => [_news, _sports, _other];
  @override
  List<M3uGroup> get tvGroups => [
        M3uGroup(title: 'News', playlistId: 'p', channels: [_news]),
        M3uGroup(title: 'Sports', playlistId: 'p', channels: [_sports]),
        for (var i = 0; i < 120; i++)
          M3uGroup(
              title: 'Filler ${i.toString().padLeft(3, '0')}',
              playlistId: 'p',
              channels: [_sports]),
        // Provider order: Zulu first; A-Z puts it last of this playlist.
        M3uGroup(title: 'Zulu', playlistId: 'q', channels: [_other]),
        for (var i = 0; i < 60; i++)
          M3uGroup(
              title: 'Alpha ${i.toString().padLeft(3, '0')}',
              playlistId: 'q',
              channels: [_other]),
      ];
  @override
  List<String> get userGroups => [for (var i = 0; i < 3; i++) 'Mine $i'];
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      switch (groupTitle) {
        'News' => [_news],
        'Sports' => [_sports],
        'Alpha 000' || 'Zulu' => [_other],
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

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
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
    prefs.isTelevision = true;
    prefs.guideViewMode = 'timeline';
    prefs.guideFullVideo = false;
    prefs.setLiveGroupSort(LiveGroupSort.aToZ);
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
    final tabFocus = Focus.of(tester.element(find.text('TV')));
    await tester.tap(find.text('Filler 000'));
    await tester.pumpAndSettle();
    tabFocus.requestFocus();
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

  String? focusedLabel() {
    final context = FocusManager.instance.primaryFocus?.context;
    String? text;
    void walk(Element e) {
      final w = e.widget;
      if (w is Text && text == null) text = w.data;
      if (text == null) e.visitChildElements(walk);
    }

    if (context is Element) walk(context);
    return text;
  }

  testWidgets('jump lands on the first group, Back stays alive',
      (tester) async {
    await pumpHome(tester);
    // Into the groups column, then the Playlists row.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('61 groups'));
    await tester.pumpAndSettle();
    expect(focusedLabel(), 'Alpha 000');
    // Into that group's guide, then Back / Left to the groups column.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('group-row'));
    // Far from the jump, the remembered row is gone from the lazy list.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.context, isNotNull);
    expect(focusedLabel(), isNotNull);
    expect(tester.takeException(), isNull);
  });
}
