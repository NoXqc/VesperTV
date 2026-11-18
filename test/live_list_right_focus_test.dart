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

/// Owner photo, 2026-11-18 (channel list + preview guide, not the
/// Timeline): "sometimes right arrow to the channels brings me left to the
/// main tab. Sometimes right arrow doesn't do anything."
List<Channel> _group(String name, int n) => [
      for (var i = 0; i < n; i++)
        Channel(
            id: 'p::$name$i',
            rawId: '$name$i',
            playlistId: 'p',
            name: '$name channel $i',
            group: name,
            url: 'http://host/live/u/p/$name$i.ts'),
    ];

final _alpha = _group('Alpha', 40);
final _beta = _group('Beta', 40);

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> get channels => [..._alpha, ..._beta];
  @override
  List<M3uGroup> get tvGroups => [
        M3uGroup(title: 'Alpha', playlistId: 'p', channels: _alpha),
        M3uGroup(title: 'Beta', playlistId: 'p', channels: _beta),
      ];
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      switch (groupTitle) {
        'Alpha' => _alpha,
        'Beta' => _beta,
        _ => [..._alpha, ..._beta],
      };
  @override
  bool isPlaylistEnabled(String playlistId) => true;
}

class _Epg extends EpgService {
  _Epg(super.storage);
  final Map<String, List<EpgProgram>> _rows = {};

  @override
  List<EpgProgram> getPrograms(String channelId) =>
      _rows.putIfAbsent(channelId, () {
        final now = DateTime.now();
        final base = DateTime(now.year, now.month, now.day, now.hour);
        return [
          for (var i = 0; i < 6; i++)
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
    prefs.guideViewMode = 'live';
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

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  }

  /// From the tabs, the remote's way: Right into the groups, Down to
  /// [name], OK (which opens its channels and moves into them).
  Future<void> openGroup(WidgetTester tester, String name) async {
    Focus.of(tester.element(find.text('TV'))).requestFocus();
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowRight);
    for (var i = 0; i < 8 && focusedLabel() != name; i++) {
      await key(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(focusedLabel(), name);
    await key(tester, LogicalKeyboardKey.enter);
    expect(focusedLabel(), '$name channel 0');
  }

  bool focusOnScreen() {
    final rect = FocusManager.instance.primaryFocus!.rect;
    return rect.top >= 0 && rect.bottom <= 720;
  }

  testWidgets('Right on a group with no channels stays on it', (tester) async {
    await pumpHome(tester);
    Focus.of(tester.element(find.text('TV'))).requestFocus();
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowRight);
    // Favourites is empty here: before, Right sent focus to the TV tab.
    expect(focusedLabel(), 'Favourites');
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedLabel(), 'Favourites');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Right after the list scrolled away lands on a visible row',
      (tester) async {
    await pumpHome(tester);
    await openGroup(tester, 'Alpha');
    for (var i = 0; i < 25; i++) {
      await key(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(focusedLabel(), 'Alpha channel 25');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusedLabel(), 'Alpha');
    // Something put the list back at the top meanwhile (a refresh, Back
    // from full screen jumping to the playing channel).
    Scrollable.of(tester.element(find.text('Alpha channel 25')))
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedLabel(), startsWith('Alpha channel'));
    expect(focusOnScreen(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Right back into the group returns to the row left',
      (tester) async {
    await pumpHome(tester);
    await openGroup(tester, 'Alpha');
    for (var i = 0; i < 3; i++) {
      await key(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(focusedLabel(), 'Alpha channel 3');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedLabel(), 'Alpha channel 3');
  });

  testWidgets('another group: OK opens it, Right from it lands on its rows',
      (tester) async {
    await pumpHome(tester);
    await openGroup(tester, 'Alpha');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedLabel(), 'Beta');
    await key(tester, LogicalKeyboardKey.enter);
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusedLabel(), 'Beta');
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedLabel(), startsWith('Beta channel'));
    expect(focusOnScreen(), isTrue);
  });
}
