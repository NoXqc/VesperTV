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
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A part-time channel's guide lists only its events (owner's photo,
/// 2026-11-26: ESPN 4K rows blank in the Timeline guide). The stretches of
/// the window without a programme get the "No program data available"
/// placeholder, and Down lands on it instead of on an event hours away.
final _full = Channel(
    id: 'p::full.ca',
    rawId: 'full.ca',
    playlistId: 'p',
    name: 'Full channel',
    group: 'Sports',
    url: 'http://host:80/live/u/pw/21.ts');
final _event = Channel(
    id: 'p::event.ca',
    rawId: 'event.ca',
    playlistId: 'p',
    name: 'Event channel 4K',
    group: 'Sports',
    url: 'http://host:80/live/u/pw/22.ts');

const _hole = 'No program data available';

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> get channels => [_full, _event];
  @override
  List<M3uGroup> get tvGroups => [
        M3uGroup(title: 'Sports', playlistId: 'p', channels: [_full, _event])
      ];
  @override
  List<Channel> visibleChannels(
          {String? playlistId, String? groupTitle, required String category}) =>
      [_full, _event];
  @override
  bool isPlaylistEnabled(String playlistId) => true;
  @override
  List<Channel> catchupLiveChannels() => const [];
}

/// Half-hour programmes around the clock on the full channel; the event
/// channel has one game, 3 to 4 h from now.
class _Epg extends EpgService {
  _Epg(super.storage);
  final Map<String, List<EpgProgram>> _rows = {};

  @override
  List<EpgProgram> getPrograms(String channelId) =>
      _rows.putIfAbsent(channelId, () {
        final now = DateTime.now();
        final hour = DateTime(now.year, now.month, now.day, now.hour);
        if (channelId == 'event.ca') {
          return [
            EpgProgram(
                channelId: channelId,
                title: 'The big game',
                start: hour.add(const Duration(hours: 3)),
                stop: hour.add(const Duration(hours: 4))),
          ];
        }
        final base = hour.subtract(const Duration(hours: 6));
        return [
          for (var i = 0; i < 36; i++)
            EpgProgram(
                channelId: channelId,
                title: 'Show #$i',
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

void main() {
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
    });
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    prefs.guideViewMode = 'timeline';
    prefs.guideFullVideo = false;
    final playlist = _Playlist(storage);
    final playback = PlaybackService(storage, playlist);
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
    await tester.tap(find.text('Sports'));
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
    await tester.pumpAndSettle();
  }

  String focusedScope() {
    final primary = FocusManager.instance.primaryFocus!;
    return FocusScope.of(primary.context!).debugLabel ?? '';
  }

  /// The label inside the block that has the remote.
  Finder inFocusedBlock(String text) => find.descendant(
      of: find.byWidgetPredicate((w) =>
          w is Focus && w.focusNode == FocusManager.instance.primaryFocus),
      matching: find.text(text));

  testWidgets('an event-only row shows the placeholder around its event',
      (tester) async {
    await pumpHome(tester);
    // Before the game and after it, inside the 6 h window.
    expect(find.text(_hole), findsNWidgets(2));
    expect(find.text('The big game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Down from a programme lands on the placeholder under it',
      (tester) async {
    await pumpHome(tester);
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedScope(), 'timeline-grid');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedScope(), 'timeline-grid');
    expect(inFocusedBlock(_hole), findsOneWidget,
        reason: 'the stretch under the focused programme, not the game');
    expect(inFocusedBlock('The big game'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
