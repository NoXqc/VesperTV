import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/player_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/route_observer.dart';
import 'package:nox_iptv/utils/video_fit.dart';
import 'package:nox_iptv/widgets/player_controls.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'native_live_zap_test.dart' show ZapController, ZapStorage, ZapPlaylist;

/// The player's picture button (owner, 2026-11-11, like Nuvio): each press
/// is the next way to size the picture, named at the top for a moment.
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

void main() {
  testWidgets('the options row cycles the picture mode and names it',
      (tester) async {
    final previousPlatform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = _VideoPlatform();
    addTearDown(() => VideoPlayerPlatform.instance = previousPlatform);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = ZapStorage();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    final playlist = ZapPlaylist(storage);
    final channel = Channel(
        id: 'p::vod_1',
        rawId: 'vod_1',
        playlistId: 'p',
        name: 'Movie',
        group: 'Movies',
        url: 'https://example.com/movie.mkv',
        onDemand: true);
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
            navigatorObservers: [appRouteObserver],
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    PlayerScreen(channel: channel))),
                        child: const Text('Open player')))))));
    await tester.tap(find.text('Open player'));
    await tester.pumpAndSettle();

    VideoFit paneFit() =>
        tester.widget<VideoPlayerPane>(find.byType(VideoPlayerPane)).fit;
    expect(paneFit(), VideoFit.fit);

    // OK shows the bar, Down the options row (TV); only when it has hidden:
    // OK on the focused picture button would press it.
    Future<Finder> button(String name) async {
      var found = find.text(name).hitTestable();
      if (found.evaluate().isEmpty) {
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        found = find.text(name).hitTestable();
      }
      return found;
    }

    final names = [for (final f in VideoFit.values) f.label];
    for (var i = 1; i <= names.length; i++) {
      // The pill has no pointer, so this is the button's label.
      final pressed = await button(names[i - 1]);
      expect(pressed, findsOneWidget, reason: names[i - 1]);
      await tester.tap(pressed);
      await tester.pump(const Duration(milliseconds: 300));
      final now = VideoFit.values[i % names.length];
      expect(prefs.videoFit, now);
      expect(paneFit(), now);
      // The button's new label and the pill over the video.
      expect(find.text(now.label), findsNWidgets(2), reason: now.label);
      await tester.pump(const Duration(seconds: 2));
      final pill = tester
          .widget<AnimatedOpacity>(find.byKey(const ValueKey('video-fit-pill')));
      expect(pill.opacity, 0, reason: 'the name fades after a moment');
    }
    expect(prefs.videoFit, VideoFit.fit);
    expect(storage.getVideoFit(), 'fit');

    await tester.pumpWidget(const SizedBox());
    playback.dispose();
    playlist.dispose();
    epg.dispose();
    prefs.dispose();
    await tester.pump();
  });
}
