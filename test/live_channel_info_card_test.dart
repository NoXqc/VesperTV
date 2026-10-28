import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/screens/player_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/channel_schedule_panel.dart';
import 'package:nox_iptv/widgets/live_channel_info_card.dart';
import 'native_live_zap_test.dart' show ZapStorage, ZapPlaylist, ZapController;

final _channel = Channel(
    id: 'p::one',
    rawId: 'one',
    playlistId: 'p',
    name: 'Channel One',
    group: 'TV',
    url: 'https://example.test/live',
    epgIdOverride: 'resolved.epg');

class _Epg extends EpgService {
  _Epg(super.storage);
  final now = DateTime.now();
  bool hasGuide = true;
  String? requested;
  late final rows = [
    EpgProgram(
        channelId: 'resolved.epg',
        title: 'Previous programme',
        start: now.subtract(const Duration(hours: 2)),
        stop: now.subtract(const Duration(hours: 1)),
        description: 'Earlier description'),
    EpgProgram(
        channelId: 'resolved.epg',
        title: 'Current programme',
        start: now.subtract(const Duration(minutes: 30)),
        stop: now.add(const Duration(minutes: 30)),
        description:
            'A longer programme description that should fit in just one compact line without covering more of the video.'),
  ];
  @override
  EpgProgram? getCurrentProgram(String id) {
    requested = id;
    return hasGuide ? rows.last : null;
  }

  @override
  List<EpgProgram> getPrograms(String id) {
    requested = id;
    return hasGuide ? rows : [];
  }
}

class _Playlist extends ZapPlaylist {
  _Playlist(super.storage);
  @override
  String playlistNameFor(String id) => 'My playlist';
}

class _Controller extends ZapController {
  @override
  bool isVideoTrackSupportAvailable() => false;
  @override
  bool isAudioTrackSupportAvailable() => false;
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
  late ZapStorage storage;
  late _Playlist playlist;
  late _Epg epg;
  late FocusNode scheduleFocus;
  setUp(() async {
    L10n.code = 'en';
    SharedPreferences.setMockInitialValues({});
    storage = ZapStorage();
    await storage.init();
    playlist = _Playlist(storage);
    epg = _Epg(storage);
    scheduleFocus = FocusNode(debugLabel: 'fixture-schedule');
  });
  tearDown(() {
    scheduleFocus.dispose();
    playlist.dispose();
    epg.dispose();
    L10n.code = 'en';
  });
  Future<void> card(WidgetTester tester,
      {double width = 960,
      double scale = 1,
      DateTime? at,
      bool touch = false,
      VoidCallback? onTap}) async {
    tester.view.physicalSize = Size(width, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<EpgService>.value(value: epg)
        ],
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 540),
                    textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                    body: Align(
                        alignment: Alignment.topCenter,
                        child: LiveChannelInfoCard(
                            channel: _channel,
                            at: at,
                            touch: touch,
                            scheduleFocus: scheduleFocus,
                            onSchedule: onTap ?? () {},
                            onScheduleKey: (_, e) {
                              if (e is KeyDownEvent &&
                                  e.logicalKey == LogicalKeyboardKey.select) {
                                onTap?.call();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            })))))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'TV card contains schedule in its header and stays compact on focus/guide updates',
      (tester) async {
    await card(tester);
    final bg = find.byKey(const ValueKey('live-info-card'));
    final action = find.byKey(const ValueKey('player-schedule-control'));
    final rect = tester.getRect(bg), control = tester.getRect(action);
    expect(rect.width, lessThanOrEqualTo(660));
    expect(rect.height, lessThan(125));
    expect(rect.contains(control.topLeft), isTrue);
    expect(rect.contains(control.bottomRight), isTrue);
    expect(
        (tester.getCenter(find.text('Channel One')).dy - control.center.dy)
            .abs(),
        lessThan(2));
    expect(find.text('My playlist'), findsOneWidget);
    expect(epg.requested, 'resolved.epg');
    scheduleFocus.debugLabel = null;
    scheduleFocus.requestFocus();
    await tester.pump();
    expect(tester.getSize(bg), rect.size);
    expect(scheduleFocus.hasFocus, isTrue);
    epg.notifyListeners();
    await tester.pump();
    expect(scheduleFocus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('catch-up retains programme/time progress for the playhead',
      (tester) async {
    await card(tester,
        at: epg.rows.first.start.add(const Duration(minutes: 30)));
    expect(find.text('Previous programme'), findsOneWidget);
    expect(find.text('Current programme'), findsNothing);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        .5);
    expect(epg.requested, 'resolved.epg');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'missing guide leaves the embedded action usable by touch and remote',
      (tester) async {
    epg.hasGuide = false;
    var opened = 0;
    await card(tester, onTap: () => opened++);
    expect(find.text('No program data available'), findsOneWidget);
    scheduleFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.tap(find.text('Channel schedule'));
    expect(opened, 2);
    await tester.pumpWidget(const SizedBox());
  });
  for (final locale in ['fr', 'el']) {
    testWidgets(
        'narrow $locale large-text layout keeps action inside the box and a touch target',
        (tester) async {
      L10n.code = locale;
      await card(tester, width: 360, scale: 1.8, touch: true);
      final bg = tester.getRect(find.byKey(const ValueKey('live-info-card')));
      final action =
          tester.getRect(find.byKey(const ValueKey('player-schedule-control')));
      expect(bg.contains(action.bottomRight), isTrue);
      expect(action.height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'actual player: lowered info, OK Up OK schedule, Down/Back exits control',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previous = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _Platform();
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    final controller = _Controller();
    final playback = PlaybackService(storage, playlist)
      ..controller = controller
      ..currentChannel = _channel;
    await tester.pumpWidget(MultiProvider(providers: [
      Provider<StorageService>.value(value: storage),
      ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
      ChangeNotifierProvider<EpgService>.value(value: epg),
      ChangeNotifierProvider<PlaybackService>.value(value: playback)
    ], child: MaterialApp(home: PlayerScreen(channel: _channel))));
    await tester.pumpAndSettle();
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    await press(LogicalKeyboardKey.select);
    final bg = find.byKey(const ValueKey('live-info-card'));
    expect(tester.getTopLeft(bg).dy, greaterThanOrEqualTo(48));
    await press(LogicalKeyboardKey.arrowUp);
    expect(
        FocusManager.instance.primaryFocus?.debugLabel, 'player-schedule-chip');
    await press(LogicalKeyboardKey.arrowDown);
    expect(FocusManager.instance.primaryFocus?.debugLabel,
        isNot('player-schedule-chip'));
    await press(LogicalKeyboardKey.arrowUp);
    await press(LogicalKeyboardKey.select);
    expect(find.byType(ChannelSchedulePanel), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ChannelSchedulePanel), findsNothing);
    expect(playback.controller, same(controller));
    await tester.pumpWidget(const SizedBox());
    playback.dispose();
    prefs.dispose();
  });
}
