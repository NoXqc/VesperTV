import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/native_video_hole.dart';
import 'wide_guide_back_test.dart' show GuidePlaylist;

class ZapStorage extends StorageService {
  @override
  Future<void> writeCacheFile(String name, String content) async {}
}

class ZapPlaylist extends GuidePlaylist {
  ZapPlaylist(super.storage);
  @override
  bool isPlaylistEnabled(String playlistId) => true;
}

class ZapController extends VideoPlayerHdrController {
  ZapController() : super.networkUrl(Uri.parse('https://example.com/old')) {
    value = const VideoPlayerHdrValue(
        duration: Duration.zero, isInitialized: true, size: Size(1920, 1080));
  }
  bool disposed = false;
  @override
  int get textureId => 55;
  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

class ZapPlayback extends PlaybackService {
  ZapPlayback(super.storage, super.playlist);
  @override
  bool get usesNativeSurface => controller is ZapController;
}

Channel channel(String name) => Channel(
    id: 'p::$name',
    rawId: name,
    playlistId: 'p',
    name: name,
    group: 'Test',
    url: 'https://example.com/$name');

void main() {
  late ZapStorage storage;
  late ZapPlaylist playlist;
  late ZapPlayback playback;
  late ZapController controller;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = ZapStorage();
    await storage.init();
    playlist = ZapPlaylist(storage);
    controller = ZapController();
    playback = ZapPlayback(storage, playlist)
      ..controller = controller
      ..currentChannel = channel('old');
    NativeVideoSurface.active = true;
    PlaybackService.textureVideo = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
            'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
            (_) async => const StandardMessageCodec().encodeMessage([null]));
  });
  tearDown(() {
    NativeVideoSurface.active = false;
    playback.dispose();
    playlist.dispose();
  });
  testWidgets('live zap keeps controller and updates channel, size and history',
      (tester) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('vespertv/native_surface'), (call) async {
      calls.add(call);
      return call.method == 'replaceLive'
          ? {'accepted': true, 'width': 3840, 'height': 2160}
          : <String, Object?>{};
    });
    await playback.play(channel('next'));
    expect(playback.controller, same(controller));
    expect(controller.disposed, isFalse);
    expect(playback.currentChannel!.rawId, 'next');
    expect(controller.value.size, const Size(3840, 2160));
    expect(playback.recentlyPlayed.first.rawId, 'next');
    expect(calls.where((c) => c.method == 'replaceLive'), hasLength(1));
    await playback.play(channel('next'));
    expect(calls.where((c) => c.method == 'replaceLive'), hasLength(1));
    await tester.pump(const Duration(seconds: 20));
  });
  testWidgets(
      'late failure from a superseded zap cannot recreate current player',
      (tester) async {
    final first = Completer<Map<String, Object?>>();
    final second = Completer<Map<String, Object?>>();
    final third = Completer<Map<String, Object?>>();
    final pending = [first, second, third].iterator;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('vespertv/native_surface'), (call) async {
      if (call.method != 'replaceLive') return <String, Object?>{};
      pending.moveNext();
      return pending.current.future;
    });
    final a = playback.play(channel('first'));
    await tester.pump();
    final b = playback.play(channel('second'));
    await tester.pump();
    // Return to the first channel before its earlier failed response arrives.
    final c = playback.play(channel('first'));
    await tester.pump();
    first.completeError(
        PlatformException(code: 'NativeLiveZap', message: 'superseded'));
    await a;
    second.completeError(
        PlatformException(code: 'NativeLiveZap', message: 'superseded'));
    await b;
    third.complete({'accepted': true, 'width': 3840, 'height': 2160});
    await c;
    expect(playback.currentChannel!.rawId, 'first');
    expect(playback.controller, same(controller));
    expect(controller.disposed, isFalse);
    await tester.pump(const Duration(seconds: 20));
  });
}
