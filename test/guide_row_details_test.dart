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

/// Full-video Timeline guide: resting 1 s on a programme opens its
/// details under the row (owner's photo of TiviMate, 2026-11-20).
final _channels = [
  for (var i = 0; i < 6; i++)
    Channel(
        id: 'p::ch$i.ca',
        rawId: 'ch$i.ca',
        playlistId: 'p',
        name: 'Channel $i',
        group: 'News',
        url: 'http://host:80/live/u/pw/${10 + i}.ts'),
];

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

/// Half-hour programmes from 2 h ago to 6 h ahead, with descriptions.
class _Epg extends EpgService {
  _Epg(super.storage);
  final Map<String, List<EpgProgram>> _rows = {};

  @override
  List<EpgProgram> getPrograms(String channelId) =>
      _rows.putIfAbsent(channelId, () {
        final now = DateTime.now();
        final base = DateTime(now.year, now.month, now.day, now.hour)
            .subtract(const Duration(hours: 2));
        return [
          for (var i = 0; i < 16; i++)
            EpgProgram(
                channelId: channelId,
                title: '$channelId #$i',
                description: 'About $channelId #$i',
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

/// The programme on now, in the test EPG's numbering.
String _nowTitle(String channelId) {
  final now = DateTime.now();
  return '$channelId #${4 + (now.minute >= 30 ? 1 : 0)}';
}

void main() {
  setUp(() {
    final previousPlatform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _Platform();
    addTearDown(() => VideoPlayerPlatform.instance = previousPlatform);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
  });

  late AppPreferences prefs;

  Future<void> pumpHome(WidgetTester tester,
      {bool expanded = false, bool details = true}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      AppConstants.keyShowClock: false,
      AppConstants.keyHideCatchupGroup: true,
    });
    final storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    prefs.guideViewMode = 'timeline';
    prefs.guideFullVideo = true;
    prefs.guideExpanded = expanded;
    prefs.guideRowDetails = details;
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
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    await tester.tap(find.text('News').first);
    await tester.pumpAndSettle();
    addTearDown(() async {
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

  Finder details() => find
      .byWidgetPredicate((w) => w.runtimeType.toString() == '_GuideRowDetails');
  Finder guide() => find
      .byWidgetPredicate((w) => w.runtimeType.toString() == '_TimelineGuide');
  // The guide's channel column (the corner card names a channel too).
  Finder label(int i) => find.byWidgetPredicate((w) =>
      w.runtimeType.toString() == '_ChannelLabel' &&
      (w as dynamic).channel.name == 'Channel $i');
  // The corner card shows the focused programme's description too.
  Finder detailsText(String text) =>
      find.descendant(of: details(), matching: find.text(text));

  /// Focuses row [row]'s programme on now, as the remote would land on it.
  Future<void> focusNow(WidgetTester tester, int row) async {
    Focus.of(tester.element(find.text(_nowTitle('ch$row.ca')))).requestFocus();
    // The passed columns slide away (~0.3 s).
    await tester.pumpAndSettle();
  }

  /// The highlight rests for [ms].
  Future<void> rest(WidgetTester tester, int ms) async {
    await tester.pump(Duration(milliseconds: ms));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('details open after 1 s and close on the next move',
      (tester) async {
    await pumpHome(tester);
    await focusNow(tester, 0);
    final rowGap =
        tester.getTopLeft(label(1)).dy - tester.getTopLeft(label(0)).dy;
    await rest(tester, 100);
    expect(details(), findsNothing, reason: 'not before 1 s');
    await rest(tester, 600);
    expect(details(), findsOneWidget);
    expect(detailsText('About ${_nowTitle('ch0.ca')}'), findsOneWidget);
    expect(
        find.descendant(
            of: details(), matching: find.textContaining('min left')),
        findsOneWidget);
    // The rows under it moved down by the gap; the card sits in it.
    final opened =
        tester.getTopLeft(label(1)).dy - tester.getTopLeft(label(0)).dy;
    expect(opened, greaterThan(rowGap + 80));
    final card = tester.getRect(details());
    expect(card.top, greaterThanOrEqualTo(tester.getTopLeft(label(0)).dy));
    // Over the programmes only (owner: "the expand info is perfect").
    expect(card.left, greaterThan(tester.getTopRight(label(0)).dx - 1));
    expect(card.right, greaterThan(tester.getRect(guide()).right - 8));

    // Down: closed at once, the next row right under the first again.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    expect(details(), findsNothing);
    expect(tester.getTopLeft(label(1)).dy - tester.getTopLeft(label(0)).dy,
        rowGap);
    // ...and the new row's own details after another rest.
    await rest(tester, 1600);
    expect(details(), findsOneWidget);
    expect(detailsText('About ${_nowTitle('ch1.ca')}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('moving before 1 s never opens them', (tester) async {
    await pumpHome(tester);
    await focusNow(tester, 0);
    for (var i = 0; i < 3; i++) {
      await rest(tester, 300);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(details(), findsNothing);
    await rest(tester, 1600);
    expect(details(), findsOneWidget);
    expect(detailsText('About ${_nowTitle('ch3.ca')}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the 3-row guide grows upward and keeps its rows on screen',
      (tester) async {
    await pumpHome(tester);
    await focusNow(tester, 1);
    final before = tester.getRect(guide());
    final rows = [for (var i = 0; i < 3; i++) tester.getTopLeft(label(i)).dy];
    await rest(tester, 1600);
    expect(details(), findsOneWidget);
    final after = tester.getRect(guide());
    expect(after.bottom, before.bottom);
    final grown = after.height - before.height;
    expect(grown, greaterThan(80));
    // Rows down to the open one moved up with the top; the one under the
    // details stayed where it was.
    expect(tester.getTopLeft(label(0)).dy, rows[0] - grown);
    expect(tester.getTopLeft(label(1)).dy, rows[1] - grown);
    expect(tester.getTopLeft(label(2)).dy, rows[2]);
    // Up: back to its own height, rows where they were.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    expect(details(), findsNothing);
    expect(tester.getRect(guide()), before);
    expect(tester.getTopLeft(label(0)).dy, rows[0]);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Expand keeps the guide\'s size; the rows under move down',
      (tester) async {
    await pumpHome(tester, expanded: true);
    await focusNow(tester, 0);
    final before = tester.getRect(guide());
    final row1 = tester.getTopLeft(label(1)).dy;
    await rest(tester, 1600);
    expect(details(), findsOneWidget);
    expect(tester.getRect(guide()), before);
    expect(tester.getTopLeft(label(1)).dy, greaterThan(row1 + 80));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('switched off: no details', (tester) async {
    await pumpHome(tester, details: false);
    await focusNow(tester, 0);
    await rest(tester, 3000);
    expect(details(), findsNothing);
    // Switched on while resting: the next rest opens them.
    prefs.setGuideRowDetails(true);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await rest(tester, 1600);
    expect(details(), findsOneWidget);
    // Off again: they close.
    prefs.setGuideRowDetails(false);
    await tester.pump();
    await tester.pump();
    expect(details(), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final expanded in [false, true]) {
    testWidgets(
        'full video: the guide reaches both screen edges '
        '(expanded: $expanded)', (tester) async {
      // Owner's +909 photo: video showed past the guide at both sides.
      await pumpHome(tester, expanded: expanded);
      await focusNow(tester, 0);
      final rect = tester.getRect(guide());
      expect(rect.left, 0);
      expect(rect.right, 1280);
      // The top bar keeps its margin.
      final bar = find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_TvTopBar');
      expect(tester.getRect(bar).left, 16);
      expect(tester.getRect(bar).right, 1280 - 16);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('focus leaving the guide closes them', (tester) async {
    await pumpHome(tester);
    await focusNow(tester, 0);
    await rest(tester, 1600);
    expect(details(), findsOneWidget);
    // Up from the top row: the filter button above the channels.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        'timeline-filter-button');
    expect(details(), findsNothing);
    final guideBox = tester.getRect(guide());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(guide()), guideBox);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
