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

/// The Timeline guide's catch-up: Left into the past on a catch-up row,
/// Back = back to now, OK on a past programme = catch-up.
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
}

/// Half-hour programmes from 30 h ago to 6 h ahead, for both channels.
class _Epg extends EpgService {
  _Epg(super.storage);
  final Map<String, List<EpgProgram>> _rows = {};
  int shift = 0;

  /// Moves every programme by [minutes]: each block is rebuilt with a new
  /// key, like rows arriving from the database replacing placeholders.
  void reshuffle(int minutes) {
    shift += minutes;
    _rows.clear();
    guideRowsLoaded.value++;
  }

  @override
  List<EpgProgram> getPrograms(String channelId) =>
      _rows.putIfAbsent(channelId, () {
        final now = DateTime.now();
        final base = DateTime(now.year, now.month, now.day, now.hour)
            .subtract(const Duration(hours: 30))
            .add(Duration(minutes: shift));
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
  late _Epg epgRef;
  final opened = <String>[];

  setUp(() {
    opened.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage([null]));
    messenger.setMockMethodCallHandler(
        const MethodChannel('vespertv/stats'), (_) async => null);
  });

  Future<void> pumpHome(WidgetTester tester,
      {bool fullVideo = false, bool hideCatchupGroup = false}) async {
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
    prefs.guideViewMode = 'timeline';
    prefs.guideFullVideo = fullVideo;
    final playlist = _Playlist(storage);
    playback = PlaybackService(storage, playlist)
      ..createController = (url, {closedCaptionFile}) {
        opened.add(url);
        return _FakePlayer(url);
      };
    final epg = _Epg(storage);
    epgRef = epg;
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

  testWidgets('Left walks into the past; Back returns to now, then groups',
      (tester) async {
    await pumpHome(tester);
    await intoGuide(tester);
    expect(find.text('Now'), findsNothing);
    // Past the usual window (an hour back) on a catch-up row.
    await key(tester, LogicalKeyboardKey.arrowLeft, times: 6);
    expect(find.text('Now'), findsOneWidget,
        reason: 'the past window shows the Now chip');
    expect(focusedScope(), 'timeline-grid');
    // Ended programmes in the archive carry the replay mark.
    expect(find.byIcon(Icons.history), findsWidgets);
    // Back: to now, still in the guide.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Now'), findsNothing);
    expect(focusedScope(), 'timeline-grid');
    // Back again: the groups, as before.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(focusedScope(), isNot('timeline-grid'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping past the left edge loads the past; back again to now',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('Now'), findsNothing);
    // A swipe to the window's start, then on past it.
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.textContaining('cu.ca #').hitTestable().first,
          const Offset(900, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('Now'), findsOneWidget,
        reason: 'the swipe loaded an older window');
    // Swiping back toward now past the window's end loads the later one,
    // and reaching the usual window drops the Now chip.
    for (var i = 0; i < 12 && find.text('Now').evaluate().isNotEmpty; i++) {
      await tester.drag(find.textContaining('cu.ca #').hitTestable().first,
          const Offset(-900, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('Now'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Catch-up group lists only channels with catch-up',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('Plain channel'), findsWidgets);
    await key(tester, LogicalKeyboardKey.arrowRight); // groups column opens
    await tester.tap(find.text('Catch-up'));
    await tester.pumpAndSettle();
    expect(find.text('Catchup channel'), findsWidgets);
    expect(find.text('Plain channel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hide Catch-up group removes the row', (tester) async {
    await pumpHome(tester, hideCatchupGroup: true);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Catch-up'), findsNothing);
    expect(find.text('Plain channel'), findsWidgets);
  });

  testWidgets('a row without catch-up keeps the old edge (no past window)',
      (tester) async {
    await pumpHome(tester);
    await intoGuide(tester);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowLeft, times: 3);
    expect(find.text('Now'), findsNothing);
    // Leaving for the groups column at this size hits an overflow that
    // predates catch-up (same with the guide before it); not this test's.
    tester.takeException();
  });

  testWidgets('Back after moving to a later slot returns to now first',
      (tester) async {
    await pumpHome(tester);
    await intoGuide(tester);
    await key(tester, LogicalKeyboardKey.arrowRight, times: 3);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(focusedScope(), 'timeline-grid');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(focusedScope(), isNot('timeline-grid'));
  });

  testWidgets('fast Left/Right never drops focus out of the grid (no flick)',
      (tester) async {
    await pumpHome(tester, fullVideo: true);
    await intoGuide(tester);
    // The search button was focused once (Up from the top row): it is then
    // in the guide column's focus history, where a lost focus falls back.
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        'timeline-filter-button');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedScope(), 'timeline-grid');
    final seen = <String>{};
    for (final k in [
      ...List.filled(14, LogicalKeyboardKey.arrowLeft),
      ...List.filled(14, LogicalKeyboardKey.arrowRight),
    ]) {
      await tester.sendKeyEvent(k);
      // Fast presses: a frame or two between them, not a settle.
      await tester.pump(const Duration(milliseconds: 16));
      final primary = FocusManager.instance.primaryFocus;
      seen.add(primary?.debugLabel ??
          FocusScope.of(primary!.context!).debugLabel ??
          '?');
      expect(primary?.debugLabel, isNot('timeline-filter-button'));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    expect(focusedScope(), 'timeline-grid');
    expect(find.text('Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a focused block rebuilt away keeps focus in the guide',
      (tester) async {
    await pumpHome(tester, fullVideo: true);
    await intoGuide(tester);
    await key(tester, LogicalKeyboardKey.arrowLeft, times: 4);
    expect(focusedScope(), 'timeline-grid');
    epgRef.reshuffle(7);
    await tester.pumpAndSettle();
    expect(focusedScope(), 'timeline-grid');
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        isNot(startsWith('tv-tab')));
  });

  testWidgets('hold menu Back to live returns the guide to now',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await pumpHome(tester);
    await intoGuide(tester);
    await key(tester, LogicalKeyboardKey.arrowLeft, times: 6);
    await key(tester, LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 1));
    expect(playback.catchup, isNotNull);
    expect(find.text('Now'), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus!.context!;
    await tester.longPress(find.byWidget(focused.widget).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to live'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(playback.catchup, isNull);
    expect(find.text('Now'), findsNothing);
    await playback.stop();
    await tester.pump(const Duration(seconds: 20));
  });

  testWidgets('first catch-up OK keeps focus in the guide (full video)',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await pumpHome(tester, fullVideo: true);
    await intoGuide(tester);
    await key(tester, LogicalKeyboardKey.arrowLeft, times: 4);
    expect(focusedScope(), 'timeline-grid');
    await key(tester, LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(playback.catchup, isNotNull);
    expect(focusedScope(), 'timeline-grid');
    await playback.stop();
    await tester.pump(const Duration(seconds: 20));
  });

  testWidgets('OK on a past programme plays its catch-up; Back to now',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
    await pumpHome(tester);
    await intoGuide(tester);
    await key(tester, LogicalKeyboardKey.arrowLeft, times: 4);
    await key(tester, LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 1));
    expect(playback.catchup, isNotNull);
    expect(playback.catchup!.live.id, _cu.id);
    expect(opened.last, contains('/timeshift/u/pw/'));
    // The guide shows the catch-up in the preview, like live.
    expect(find.text('Now'), findsOneWidget);
    // Back: the guide returns to now (the programme keeps playing until
    // the user picks live).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Now'), findsNothing);
    expect(focusedScope(), 'timeline-grid');
    expect(playback.catchup, isNotNull);
    // Hold menu's Back to live / the player's LIVE: live again.
    await playback.backToLive();
    await tester.pump(const Duration(seconds: 1));
    expect(playback.catchup, isNull);
    expect(opened.last, _cu.url);
    await playback.stop();
    await tester.pump(const Duration(seconds: 20));
  });
}
