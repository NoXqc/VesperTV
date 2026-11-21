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

/// Timeline guide Left / Right go programme by programme and move the view
/// only when the next one would barely show (owner + Reddit, 2026-11-21: a
/// 10-minute news between two half-hour marks could never be selected, and
/// every press slid the whole guide).
final _cu = Channel(
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
final _plain = Channel(
    id: 'p::plain.ca',
    rawId: 'plain.ca',
    playlistId: 'p',
    name: 'Plain channel',
    group: 'News',
    url: 'http://host:80/live/u/pw/12.ts');

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> get channels => [_cu, _plain];
  @override
  List<M3uGroup> get tvGroups => [
        M3uGroup(title: 'News', playlistId: 'p', channels: [_cu, _plain])
      ];
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      [_cu, _plain];
  @override
  bool isPlaylistEnabled(String playlistId) => true;
  @override
  List<Channel> catchupLiveChannels() =>
      [_cu, _plain].where((c) => c.hasCatchup).toList();
}

/// Around now (base = the current half-hour): a block on now that ends
/// between two half-hour marks, a 10-minute news covering no :00 / :30
/// mark, then a half-hour, a three-hour film and two short ones after it.
class _Epg extends EpgService {
  _Epg(super.storage);
  final Map<String, List<EpgProgram>> _rows = {};

  @override
  List<EpgProgram> getPrograms(String channelId) =>
      _rows.putIfAbsent(channelId, () {
        final now = DateTime.now();
        final base = DateTime(now.year, now.month, now.day, now.hour,
            now.minute - now.minute % 30);
        EpgProgram p(String title, int from, int to) => EpgProgram(
            channelId: channelId,
            title: title,
            start: base.add(Duration(minutes: from)),
            stop: base.add(Duration(minutes: to)));
        return [
          p('On now', -90, 40),
          p('Short news', 40, 50),
          p('Half hour', 50, 80),
          p('Long film', 80, 260),
          p('After film', 260, 290),
          p('Late show', 290, 420),
        ];
      });
}

/// Host-independent video view: `flutter test` registers the host's real
/// video_player plugin (AVFoundation on macOS), whose view throws in tests.
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
      {bool fullVideo = false,
      bool hideCatchupGroup = false,
      String viewMode = 'timeline'}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyShowClock: false,
      AppConstants.keyHideCatchupGroup: hideCatchupGroup,
    });
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    prefs.guideViewMode = viewMode;
    prefs.guideFullVideo = fullVideo;
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
    // TV now starts on Favourites. These catch-up fixtures exercise News,
    // so choose that group explicitly before the existing remote sequence.
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

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k,
      {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.sendKeyEvent(k);
      await tester.pumpAndSettle();
    }
  }

  String focusedScope() {
    final primary = FocusManager.instance.primaryFocus!;
    return FocusScope.of(primary.context!).debugLabel ?? '';
  }

  /// Tabs -> groups -> guide (first row = the catch-up channel).
  Future<void> intoGuide(WidgetTester tester) async {
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedScope(), 'timeline-grid');
  }

  String focusedTitle() {
    final primary = FocusManager.instance.primaryFocus!;
    String? label;
    void visit(Element e) {
      if (label != null) return;
      final w = e.widget;
      if (w is Semantics && w.properties.label != null) {
        label = w.properties.label;
        return;
      }
      e.visitChildren(visit);
    }

    (primary.context! as Element).visitChildren(visit);
    return label ?? '';
  }

  testWidgets('Right reaches a short programme without moving the guide',
      (tester) async {
    await pumpHome(tester);
    await intoGuide(tester);
    expect(focusedTitle(), startsWith('On now'));
    final before = tester.getTopLeft(find.text('Long film').first);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedTitle(), startsWith('Short news'));
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedTitle(), startsWith('Half hour'));
    expect(tester.getTopLeft(find.text('Long film').first), before,
        reason: 'the highlight moved, the guide did not');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusedTitle(), startsWith('Short news'));
    expect(tester.getTopLeft(find.text('Long film').first), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long film is one press; walking back ends at live',
      (tester) async {
    await pumpHome(tester);
    await intoGuide(tester);
    final live = tester.getTopLeft(find.text('Half hour').first);
    await key(tester, LogicalKeyboardKey.arrowRight, times: 3);
    expect(focusedTitle(), startsWith('Long film'));
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedTitle(), startsWith('After film'),
        reason: 'one press leaves the film, however long it is');
    expect(tester.getTopLeft(find.text('After film').first).dx,
        lessThan(tester.view.physicalSize.width),
        reason: 'the view paged to show it');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusedTitle(), startsWith('Long film'));
    await key(tester, LogicalKeyboardKey.arrowLeft, times: 3);
    expect(focusedTitle(), startsWith('On now'));
    // Rows of different lengths: back on the programme airing now, the
    // view is the usual live one again, not that programme's start.
    expect(tester.getTopLeft(find.text('Half hour').first), live,
        reason: 'walking back ends at the live position');
    expect(tester.takeException(), isNull);
  });
}
