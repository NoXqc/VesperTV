import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Settings > Interface > Guide > Preview on highlight: the channel the
/// remote stops on plays in the preview without OK, in both guide views.
final _a = Channel(
    id: 'p::a.ca',
    rawId: 'a.ca',
    playlistId: 'p',
    name: 'Alpha channel',
    group: 'News',
    url: 'http://host:80/live/u/pw/11.ts');
final _b = Channel(
    id: 'p::b.ca',
    rawId: 'b.ca',
    playlistId: 'p',
    name: 'Bravo channel',
    group: 'News',
    url: 'http://host:80/live/u/pw/12.ts');
final _c = Channel(
    id: 'p::c.ca',
    rawId: 'c.ca',
    playlistId: 'p',
    name: 'Charlie channel',
    group: 'News',
    url: 'http://host:80/live/u/pw/13.ts');
final _all = [_a, _b, _c];

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> get channels => _all;
  @override
  List<M3uGroup> get tvGroups =>
      [M3uGroup(title: 'News', playlistId: 'p', channels: _all)];
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      _all;
  @override
  bool isPlaylistEnabled(String playlistId) => true;
}

class _Epg extends EpgService {
  _Epg(super.storage);
  @override
  List<EpgProgram> getPrograms(String channelId) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day, now.hour);
    return [
      for (var i = -2; i < 6; i++)
        EpgProgram(
            channelId: channelId,
            title: '$channelId #$i',
            start: base.add(Duration(minutes: 30 * i)),
            stop: base.add(Duration(minutes: 30 * (i + 1)))),
    ];
  }
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
        duration: Duration.zero,
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
  final opened = <String>[];

  setUp(() {
    opened.clear();
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
      {required String viewMode, bool focusPreview = true}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({AppConstants.keyShowClock: false});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    prefs.guideViewMode = viewMode;
    prefs.guideFocusPreview = focusPreview;
    final playlist = _Playlist(storage);
    playback = PlaybackService(storage, playlist)
      ..createController = (url, {closedCaptionFile, httpHeaders = const {}}) {
        opened.add(url);
        return _FakePlayer(url);
      };
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
    await tester.tap(find.text('News'));
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

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
    await tester.pump();
  }

  /// The preview wait (0.8 s) and then the play itself.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  /// Stops playback inside the test body: live playback's own timers
  /// (resolution check, periodic save) must be gone before it ends.
  Future<void> finish(WidgetTester tester) async {
    await playback.stop();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 20));
  }

  /// Tabs -> groups -> the first channel, then the wait.
  Future<void> intoChannels(WidgetTester tester) async {
    await key(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowRight);
    await settle(tester);
  }

  for (final mode in ['timeline', 'live']) {
    testWidgets('the channel the remote stops on plays ($mode)',
        (tester) async {
      await pumpHome(tester, viewMode: mode);
      expect(playback.currentChannel, isNull);
      await intoChannels(tester);
      expect(playback.currentChannel?.id, _a.id,
          reason: 'arriving on a channel with the remote previews it');
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(playback.currentChannel?.id, _a.id,
          reason: 'nothing changes before the remote has been still');
      await settle(tester);
      expect(playback.currentChannel?.id, _b.id);
      expect(opened.where((u) => u.endsWith('/12.ts')), hasLength(1));
      // No full screen: the guide is still there.
      expect(find.text('Charlie channel'), findsWidgets);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('fast moves open only where the remote stops ($mode)',
        (tester) async {
      await pumpHome(tester, viewMode: mode);
      await intoChannels(tester);
      opened.clear();
      await key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 300));
      await key(tester, LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(playback.currentChannel?.id, _c.id);
      expect(opened.where((u) => u.endsWith('/12.ts')), isEmpty,
          reason: 'the channel passed on the way never opened');
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('off: highlighting plays nothing ($mode)', (tester) async {
      await pumpHome(tester, viewMode: mode, focusPreview: false);
      await intoChannels(tester);
      await key(tester, LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(playback.currentChannel, isNull);
      expect(opened, isEmpty);
      await finish(tester);
    });
  }

  testWidgets('OK during the wait previews once and stays in the guide',
      (tester) async {
    await pumpHome(tester, viewMode: 'timeline');
    await intoChannels(tester);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.select);
    await settle(tester);
    expect(playback.currentChannel?.id, _b.id);
    expect(opened.where((u) => u.endsWith('/12.ts')), hasLength(1));
    expect(find.text('Charlie channel'), findsWidgets,
        reason: 'the late highlight timer must not turn it into full screen');
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('a highlight the remote did not cause plays nothing',
      (tester) async {
    await pumpHome(tester, viewMode: 'live');
    await intoChannels(tester);
    expect(playback.currentChannel?.id, _a.id);
    // Real time past the last key (the gate reads the wall clock).
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 600)));
    Focus.of(tester.element(find.text('Bravo channel'))).requestFocus();
    await settle(tester);
    expect(playback.currentChannel?.id, _a.id);
    await finish(tester);
  });

  testWidgets('History only after the preview has been watched a while',
      (tester) async {
    await pumpHome(tester, viewMode: 'timeline');
    await intoChannels(tester);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(playback.currentChannel?.id, _b.id);
    expect(playback.recentlyPlayed.map((c) => c.id), isNot(contains(_b.id)));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(playback.recentlyPlayed.map((c) => c.id), contains(_b.id));
    expect(playback.recentlyPlayed.map((c) => c.id), isNot(contains(_a.id)),
        reason: 'A was replaced before it had played 10 s');
    await finish(tester);
  });
}
