import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/player_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/remote_buttons.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/widgets/player_side_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'native_live_zap_test.dart' show ZapController, ZapStorage, ZapPlaylist;

class _VideoPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Widget buildView(int textureId) => const SizedBox();
  @override
  Future<void> dispose(int textureId) async {}
}

class _Controller extends ZapController {
  @override
  bool isVideoTrackSupportAvailable() => false;
  @override
  bool isAudioTrackSupportAvailable() => false;
}

/// Remote buttons > Player arrows: the full-screen player's arrows on a
/// live channel follow the viewer's choice (owner, 2026-11-11: the side
/// drawer on Right).
void main() {
  Future<void> open(WidgetTester tester,
      {required Map<PlayerArrow, String> arrows,
      required Future<void> Function(PlaybackService playback) check,
      Map<PlayerArrow, String> holds = const {},
      bool overGuide = false}) async {
    final navigator = GlobalKey<NavigatorState>();
    final previousPlatform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _VideoPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = previousPlatform);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = ZapStorage();
    await storage.init();
    final buttons = RemoteButtons.instance..attach(storage);
    await buttons.reset();
    for (final e in arrows.entries) {
      await buttons.setArrow(e.key, e.value);
    }
    for (final e in holds.entries) {
      await buttons.setArrowHold(e.key, e.value);
    }
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    final playlist = ZapPlaylist(storage);
    final channel = Channel(
        id: 'p::tsn1',
        rawId: 'tsn1',
        playlistId: 'p',
        name: 'TSN 1',
        group: 'Sports',
        url: 'https://example.com/tsn1');
    final playback = PlaybackService(storage, playlist)
      ..controller = _Controller()
      ..currentChannel = channel;
    final epg = EpgService(storage);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider<AppPreferences>.value(value: prefs),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<PlaybackService>.value(value: playback),
          ChangeNotifierProvider<EpgService>.value(value: epg),
        ],
        child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [appRouteObserver],
            home: overGuide
                ? const Scaffold(body: Text('The guide'))
                : PlayerScreen(channel: channel))));
    await tester.pumpAndSettle();
    if (overGuide) {
      unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => PlayerScreen(channel: channel))));
      await tester.pumpAndSettle();
    }
    expect(buttons.player, isNotNull);
    await check(playback);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(buttons.player, isNull);
    await buttons.reset();
    playback.dispose();
    playlist.dispose();
    epg.dispose();
    prefs.dispose();
    await tester.pump();
  }

  testWidgets('Right can open the side drawer', (tester) async {
    await open(tester, arrows: {PlayerArrow.right: 'panel'}, check: (_) async {
      expect(find.byType(PlayerSidePanel), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerSidePanel), findsOneWidget);
    });
  });

  testWidgets('Left set to Nothing leaves the drawer closed', (tester) async {
    await open(tester, arrows: {PlayerArrow.left: 'none'}, check: (_) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerSidePanel), findsNothing);
    });
  });

  testWidgets('by default Left opens the drawer', (tester) async {
    await open(tester, arrows: const {}, check: (_) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerSidePanel), findsOneWidget);
    });
  });

  testWidgets('Left can go back to the guide, like Back', (tester) async {
    await open(tester, overGuide: true, arrows: {PlayerArrow.left: 'back'},
        check: (_) async {
      expect(find.byType(PlayerScreen), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerScreen), findsNothing);
      expect(find.byType(PlayerSidePanel), findsNothing);
      expect(find.text('The guide'), findsOneWidget);
    });
  });

  // Owner, 2026-11-21: Left = guide, hold Left = side drawer.
  testWidgets('with a hold set, a quick Left goes back to the guide',
      (tester) async {
    await open(tester,
        overGuide: true,
        arrows: {PlayerArrow.left: 'back'},
        holds: {PlayerArrow.left: 'panel'}, check: (_) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(PlayerScreen), findsOneWidget,
          reason: 'nothing until the release');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerScreen), findsNothing);
      expect(find.text('The guide'), findsOneWidget);
    });
  });

  testWidgets('holding Left opens the side drawer instead', (tester) async {
    await open(tester,
        overGuide: true,
        arrows: {PlayerArrow.left: 'back'},
        holds: {PlayerArrow.left: 'panel'}, check: (_) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerSidePanel), findsOneWidget);
      expect(find.byType(PlayerScreen), findsOneWidget,
          reason: 'the release after a hold does not go back too');
    });
  });
}
