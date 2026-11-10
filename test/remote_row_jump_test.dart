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

/// Remote fast-forward / rewind in the channel list and the Timeline guide:
/// 10 channels at a time. Preview on highlight shows where the cursor
/// stopped (it plays the highlighted channel).
/// The groups-column test: 25 groups instead of one.
var manyGroups = false;

final _all = [
  for (var i = 0; i < 30; i++)
    Channel(
        id: 'p::c$i.ca',
        rawId: 'c$i.ca',
        playlistId: 'p',
        name: 'Channel ${i.toString().padLeft(2, '0')}',
        group: 'News',
        url: 'http://host:80/live/u/pw/${100 + i}.ts'),
];

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> get channels => _all;
  @override
  List<M3uGroup> get tvGroups => manyGroups
      ? [
          for (var i = 0; i < 25; i++)
            M3uGroup(
                title: 'Group ${i.toString().padLeft(2, '0')}',
                playlistId: 'p',
                channels: [_all[i]]),
        ]
      : [M3uGroup(title: 'News', playlistId: 'p', channels: _all)];
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
    await tester.tap(find.text(manyGroups ? 'Group 00' : 'News'));
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

  /// A remote key, then a quarter second of frames: the jump moves one
  /// row per frame.
  Future<void> jump(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await settle(tester);
  }

  for (final mode in ['timeline', 'live']) {
    testWidgets('fast-forward / rewind jump 10 channels ($mode)',
        (tester) async {
      await pumpHome(tester, viewMode: mode);
      await intoChannels(tester);
      expect(playback.currentChannel?.id, _all[0].id);
      await jump(tester, LogicalKeyboardKey.mediaFastForward);
      expect(playback.currentChannel?.id, _all[10].id);
      await jump(tester, LogicalKeyboardKey.mediaFastForward);
      expect(playback.currentChannel?.id, _all[20].id);
      // Past the end: stops on the last channel.
      await jump(tester, LogicalKeyboardKey.mediaFastForward);
      expect(playback.currentChannel?.id, _all[29].id);
      await jump(tester, LogicalKeyboardKey.mediaRewind);
      expect(playback.currentChannel?.id, _all[19].id);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await settle(tester);
      expect(playback.currentChannel?.id, _all[18].id,
          reason: 'plain Up still moves one');
      expect(tester.takeException(), isNull);
      await finish(tester);
    });

    testWidgets('rewind near the top stops on the first channel ($mode)',
        (tester) async {
      await pumpHome(tester, viewMode: mode);
      await intoChannels(tester);
      for (var i = 0; i < 3; i++) {
        await key(tester, LogicalKeyboardKey.arrowDown);
      }
      await settle(tester);
      expect(playback.currentChannel?.id, _all[3].id);
      await jump(tester, LogicalKeyboardKey.mediaRewind);
      expect(playback.currentChannel?.id, _all[0].id);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  }

  /// The name shown in the focused row.
  String? focusedText(WidgetTester tester) {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    final texts = tester.widgetList<Text>(find.descendant(
        of: find.byElementPredicate((e) => e == context),
        matching: find.byType(Text)));
    return texts.map((t) => t.data ?? '').join(' ');
  }

  testWidgets('fast-forward / rewind jump 10 groups', (tester) async {
    manyGroups = true;
    addTearDown(() => manyGroups = false);
    await pumpHome(tester, viewMode: 'live', focusPreview: false);
    await key(tester, LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    // Past Favourites / History / ... to the first real group.
    for (var i = 0;
        i < 8 && !(focusedText(tester) ?? '').contains('Group');
        i++) {
      await key(tester, LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    final first = focusedText(tester);
    expect(first, contains('Group'), reason: 'in the groups column');
    final start = int.parse(RegExp(r'Group (\d+)').firstMatch(first!)![1]!);
    await jump(tester, LogicalKeyboardKey.mediaFastForward);
    expect(focusedText(tester),
        contains('Group ${(start + 10).toString().padLeft(2, '0')}'));
    await jump(tester, LogicalKeyboardKey.mediaRewind);
    expect(focusedText(tester),
        contains('Group ${start.toString().padLeft(2, '0')}'));
    expect(tester.takeException(), isNull);
    await finish(tester);
  });
}
