import 'package:flutter/gestures.dart';
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

/// Unbeaten82 (Discord, 2026-11-21, two TV photos of the full-video
/// guide): (1) the bottom channel was always cut off: the rows sat a few
/// pixels off, the top one cut and the next one peeking under the last;
/// (2) the guide only went 6 hours ahead (an hour back to five ahead).
List<Channel> _make(int count) => [
      for (var i = 0; i < count; i++)
        Channel(
            id: 'p::c$i',
            rawId: 'c$i',
            playlistId: 'p',
            name: 'Channel $i',
            group: 'News',
            url: 'http://host:80/live/u/pw/$i.ts'),
    ];
var _channels = _make(30);

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> get channels => _channels;
  @override
  List<M3uGroup> get tvGroups =>
      [M3uGroup(title: 'News', playlistId: 'p', channels: _channels)];
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      _channels;
  @override
  bool isPlaylistEnabled(String playlistId) => true;
}

/// Every channel: a programme on now, then two-hour ones for two days.
/// Channel 9's guide ended 40 minutes ago (its only programme is left of
/// the view, so focusing it scrolls the view sideways; the rest of its row
/// is the "No program data available" placeholder).
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
            title: '$title $channelId',
            start: base.add(Duration(minutes: from)),
            stop: base.add(Duration(minutes: to)));
        if (channelId == 'c9') {
          final end = now.subtract(const Duration(minutes: 40));
          return [
            EpgProgram(
                channelId: channelId,
                title: 'Ended c9',
                start: end.subtract(const Duration(minutes: 20)),
                stop: end),
          ];
        }
        return [
          p('On now', -60, 60),
          for (var h = 0; h < 24; h++)
            p('Show ${h + 1}', 60 + h * 120, 180 + h * 120),
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
      {int channels = 30,
      String uiSize = 'normal',
      bool rowDetails = false}) async {
    _channels = _make(channels);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyShowClock: false,
    });
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    prefs.guideViewMode = 'timeline';
    prefs.guideFullVideo = true;
    prefs.guideRowDetails = rowDetails;
    prefs.uiSize = uiSize;
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

  /// The guide grid's vertical scroll (the one the programme blocks are in).
  ScrollPosition gridRows() {
    final block = FocusManager.instance.primaryFocus!.context!;
    return Scrollable.of(block, axis: Axis.vertical).position;
  }

  testWidgets('rows stay whole when focus lands on a programme off the view',
      (tester) async {
    await pumpHome(tester);
    await key(tester, LogicalKeyboardKey.arrowRight, times: 2);
    expect(focusedScope(), 'timeline-grid');
    await key(tester, LogicalKeyboardKey.arrowDown, times: 9);
    // Down keeps the time: the placeholder after the guide's end, then
    // Left to the old programme off the view.
    expect(focusedTitle(), 'No program data available');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusedTitle(), startsWith('Ended c9'));
    final rows = gridRows();
    expect(rows.pixels % 64, 0,
        reason: 'the view scrolled sideways to the old programme, never '
            'to a few pixels inside a row');
    expect(rows.pixels, 7 * 64.0,
        reason: 'the row stays the bottom one of three');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(gridRows().pixels, 8 * 64.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Right goes past the first six hours, Left comes back',
      (tester) async {
    await pumpHome(tester);
    await key(tester, LogicalKeyboardKey.arrowRight, times: 2);
    expect(focusedScope(), 'timeline-grid');
    expect(focusedTitle(), startsWith('On now c0'));
    // On now, then two-hour shows: Show 5 starts 9 h after the current
    // half-hour, past the old window (1 h back, 5 h ahead).
    await key(tester, LogicalKeyboardKey.arrowRight, times: 5);
    expect(focusedTitle(), startsWith('Show 5 c0'));
    await key(tester, LogicalKeyboardKey.arrowRight, times: 6);
    expect(focusedTitle(), startsWith('Show 11 c0'), reason: 'a day ahead');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedTitle(), startsWith('Show 11 c1'),
        reason: 'Down keeps the time');
    await key(tester, LogicalKeyboardKey.arrowLeft, times: 11);
    expect(focusedTitle(), startsWith('On now c1'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short group in Compact: every row lines up with its name',
      (tester) async {
    await pumpHome(tester, channels: 3, uiSize: 'compact', rowDetails: true);
    await key(tester, LogicalKeyboardKey.arrowRight, times: 2);
    expect(focusedScope(), 'timeline-grid');
    void linedUp(String why) {
      for (var i = 0; i < 3; i++) {
        final name = tester.getCenter(find.text('Channel $i').first).dy;
        final block = tester.getCenter(find.text('On now c$i').first).dy;
        expect((name - block).abs(), lessThan(2), reason: '$why: row $i');
      }
    }

    linedUp('on entry');
    // The highlight rests: the details open under the row, then close.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowDown);
    linedUp('after the details');
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    // To the last channel, then twice Down: the wrap takes a second press.
    await key(tester, LogicalKeyboardKey.arrowDown, times: 3);
    linedUp('after wrapping to the first');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sideways wheel goes past the first six hours too',
      (tester) async {
    await pumpHome(tester);
    await key(tester, LogicalKeyboardKey.arrowRight, times: 2);
    final at = tester.getCenter(find.text('On now c0').first);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(at));
    // Show 5 starts nine hours after the current half-hour.
    for (var i = 0; i < 12 && find.text('Show 5 c0').evaluate().isEmpty; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(1500, 0)));
      await tester.pumpAndSettle();
    }
    expect(find.text('Show 5 c0'), findsWidgets,
        reason: 'the wheel at the edge opens the hours after');
    for (var i = 0; i < 12 && find.text('On now c0').evaluate().isEmpty; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(-1500, 0)));
      await tester.pumpAndSettle();
    }
    expect(find.text('On now c0'), findsWidgets, reason: 'and back');
    expect(tester.takeException(), isNull);
  });
}
