import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/player_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/archive_playback_sources.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/route_observer.dart';
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

void main() {
  for (final lateSelection in [false, true]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'Drawer Back retains playback: late selection=$lateSelection, text scale=$scale',
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
        final controller = _Controller();
        final channel = Channel(
            id: 'archive::arc_vod_movie',
            rawId: 'arc_vod_movie',
            playlistId: 'archive',
            name: 'Movie',
            group: '',
            url: 'https://example.com/one');
        final playback = PlaybackService(storage, playlist)
          ..controller = controller
          ..currentChannel = channel;
        final epg = EpgService(storage);
        const source = ArchiveSource(
            manifestUrl: 'https://example.com/manifest.json', name: 'Provider');
        const first = ArchiveStreamOption(
            source: source,
            stream: ArchiveStream(
                url: 'https://example.com/one',
                name: '[TB+] 4K source',
                title: '2160p HDR10 HEVC BluRay release file',
                sizeBytes: 26300000000));
        const second = ArchiveStreamOption(
            source: source,
            stream: ArchiveStream(
                url: 'https://example.com/two',
                name: 'Other 4K',
                title: 'HDR10 HEVC',
                sizeBytes: 40000000000));
        final pendingSelection = Completer<Channel?>();
        final sources = ArchivePlaybackSources(
            load: (_) async => [first, second],
            current: (_) => first,
            select: (_, o) async => lateSelection
                ? await pendingSelection.future
                : channel.copyWith(url: o.stream.url),
            remember: (_, __) async {});
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(
                'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
                (_) async =>
                    const StandardMessageCodec().encodeMessage([null]));
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
                builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                home: Builder(
                    builder: (context) => Scaffold(
                        body: TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => PlayerScreen(
                                        channel: channel, sources: sources))),
                            child: const Text('Open player')))))));
        await tester.tap(find.text('Open player'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        final drawer = find.byKey(const ValueKey('media-hub-source-drawer'));
        expect(drawer, findsOneWidget);
        expect(tester.getSize(drawer).width, lessThanOrEqualTo(960 * .33));
        expect(find.text('File size: 26.3 GB'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // The same physical Back can arrive as a key and then a platform pop.
        if (lateSelection) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          await tester.binding.handlePopRoute();
          await tester.pump(const Duration(milliseconds: 10));
          pendingSelection.complete(channel.copyWith(url: second.stream.url));
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.goBack,
              physicalKey: PhysicalKeyboardKey.escape);
        }
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(drawer, findsNothing);
        expect(find.byType(PlayerScreen), findsOneWidget);
        expect(playback.currentChannel, same(channel));
        expect(controller.disposed, isFalse);
        // After dismissal settles, a new intentional Back may leave playback.
        await tester.pump(const Duration(milliseconds: 750));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(PlayerScreen), findsNothing);
        expect(find.text('Open player'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        playback.dispose();
        playlist.dispose();
        epg.dispose();
        prefs.dispose();
        await tester.pump();
      });
    }
  }
}
