import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/models/epg_program.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/widgets/player_controls.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_live_zap_test.dart' show ZapStorage, ZapPlaylist, ZapController;

final _channel = Channel(
    id: 'p::one',
    rawId: 'one',
    playlistId: 'p',
    name: 'Channel One',
    group: 'TV',
    url: 'https://example.test/live');

class _Epg extends EpgService {
  _Epg(super.storage);
  bool hasGuide = true;
  String title = 'Police Justice';
  late final now = DateTime.now();
  late final programme = EpgProgram(
      channelId: 'one',
      title: title,
      start: now.subtract(const Duration(minutes: 30)),
      stop: now.add(const Duration(minutes: 24, seconds: 30)),
      description: 'Faits divers,\n enquêtes et décisions de justice.');
  @override
  EpgProgram? getCurrentProgram(String id) => hasGuide ? programme : null;
  @override
  List<EpgProgram> getPrograms(String id) => hasGuide ? [programme] : [];
}

class _Playlist extends ZapPlaylist {
  _Playlist(super.storage);
  @override
  String playlistNameFor(String id) => 'Blcktv';
}

class _Controller extends ZapController {
  @override
  bool isVideoTrackSupportAvailable() => false;
  @override
  bool isAudioTrackSupportAvailable() => false;
}

/// The live player's one bottom bar (owner's Discord poll, 2026-11-17):
/// a zap shows it display only, OK adds ☆ / Play-Pause / Channel schedule
/// without changing its height.
void main() {
  late ZapStorage storage;
  late _Playlist playlist;
  late _Epg epg;
  late AppPreferences prefs;
  late FocusNode play;
  setUp(() async {
    L10n.code = 'en';
    SharedPreferences.setMockInitialValues({});
    storage = ZapStorage();
    await storage.init();
    playlist = _Playlist(storage);
    epg = _Epg(storage);
    prefs = AppPreferences(storage);
    await prefs.init();
    play = FocusNode(debugLabel: 'fixture-play');
  });
  tearDown(() {
    play.dispose();
    playlist.dispose();
    epg.dispose();
    prefs.dispose();
  });

  Future<void> bar(WidgetTester tester,
      {required bool buttons,
      VoidCallback? onSchedule,
      Channel? channel}) async {
    final live = channel ?? _channel;
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<EpgService>.value(value: epg),
        ],
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
                body: Align(
                    alignment: Alignment.bottomCenter,
                    child: PlayerControls(
                      controller: _Controller(),
                      title: live.name,
                      channelId: live.epgId,
                      isLive: true,
                      channel: live,
                      isFavorite: false,
                      onToggleFavorite: () {},
                      playFocusNode: play,
                      liveInfoBar: true,
                      infoBarButtons: buttons,
                      onSchedule: onSchedule ?? () {},
                    ))))));
    await tester.pump();
  }

  final barKey = find.byKey(const ValueKey('live-info-bar'));

  testWidgets('a zap: everything on one bar, nothing to focus', (tester) async {
    await bar(tester, buttons: false);
    expect(tester.getSize(barKey),
        const Size(960, PlayerControls.liveInfoBarHeight));
    expect(find.text('Channel One'), findsOneWidget);
    expect(find.text('Blcktv'), findsOneWidget);
    expect(find.text('Police Justice'), findsOneWidget);
    expect(find.text('24 min left'), findsOneWidget);
    // One line, the guide's line breaks folded.
    expect(find.text('Faits divers, enquêtes et décisions de justice.'),
        findsOneWidget);
    expect(find.text('Channel schedule'), findsNothing);
    expect(play.context, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OK: same height, the buttons at the end of the description',
      (tester) async {
    await bar(tester, buttons: false);
    final zapDescription = tester
        .getRect(find.text('Faits divers, enquêtes et décisions de justice.'));
    var opened = 0;
    await bar(tester, buttons: true, onSchedule: () => opened++);
    expect(tester.getSize(barKey),
        const Size(960, PlayerControls.liveInfoBarHeight));
    final description = tester
        .getRect(find.text('Faits divers, enquêtes et décisions de justice.'));
    expect(description.left, zapDescription.left);
    final schedule = tester.getRect(find.text('Channel schedule'));
    expect(schedule.left, greaterThan(description.right));
    expect((schedule.center.dy - description.center.dy).abs(), lessThan(2));
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    // Play/Pause takes the remote; Right reaches Channel schedule.
    play.requestFocus();
    await tester.pump();
    expect(play.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('Channel schedule'))).hasFocus,
        isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, 1);
    // A late OK repeat (the Homatics remote) does nothing.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(opened, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no guide: says so, the bar keeps its height', (tester) async {
    epg.hasGuide = false;
    await bar(tester, buttons: true);
    expect(tester.getSize(barKey),
        const Size(960, PlayerControls.liveInfoBarHeight));
    expect(find.text('No program data available'), findsOneWidget);
    expect(find.text('Channel schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long name and programme fit, in French too', (tester) async {
    L10n.code = 'fr';
    addTearDown(() => L10n.code = 'en');
    epg.title = 'Le grand débat du soir avec tous les invités de la semaine';
    final long = Channel(
        id: 'p::long',
        rawId: 'long',
        playlistId: 'p',
        name: 'FR | CANAL+ SPORT 360 FHD HEVC (backup 2)',
        group: 'TV',
        url: 'https://example.test/long');
    await bar(tester, buttons: true, channel: long);
    expect(tester.getSize(barKey),
        const Size(960, PlayerControls.liveInfoBarHeight));
    expect(find.text('Programme de la chaîne'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
