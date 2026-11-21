import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Reload on a 4K channel (owner, LOG-PSBGV7, 2026-11-21): the Homatics'
/// chip has one 4K HEVC decoder, so a second player started beside the
/// first failed (NO_MEMORY) and the error screen showed. The old player now
/// goes first on 4K; HD still builds the new one before dropping the old.
final _channel = Channel(
    id: 'p::espn4k.us',
    rawId: 'espn4k.us',
    playlistId: 'p',
    name: 'ESPN 4K',
    group: 'Sports',
    url: 'http://host:80/live/u/pw/1.ts');

class _Playlist extends PlaylistManager {
  _Playlist(StorageService storage) : super(storage, CatalogDatabase());
  @override
  List<Channel> get channels => [_channel];
  @override
  bool isPlaylistEnabled(String playlistId) => true;
}

class _Platform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Widget buildView(int id) => const SizedBox();
  @override
  Future<void> dispose(int id) async {}
}

/// Logs when each player starts and is closed, in [events].
class _FakePlayer extends VideoPlayerHdrController {
  _FakePlayer(String url, this.name, this.events, this.videoSize)
      : super.networkUrl(Uri.parse(url));
  final String name;
  final List<String> events;
  final Size videoSize;

  @override
  Future<void> initialize(
      {VideoViewType viewType = VideoViewType.textureView}) async {
    events.add('start $name');
    value = value.copyWith(isInitialized: true, size: videoSize);
  }

  @override
  Future<void> dispose() async {
    events.add('close $name');
    await super.dispose();
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late PlaylistManager playlist;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    playlist = _Playlist(storage);
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
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => Directory.systemTemp.path);
  });

  Future<List<String>> reloadWith(Size size) async {
    final events = <String>[];
    var n = 0;
    final playback = PlaybackService(storage, playlist)
      ..createController = (url, {closedCaptionFile, httpHeaders = const {}}) =>
          _FakePlayer(url, '${++n}', events, size);
    await playback.play(_channel);
    await playback.reloadCurrentChannel();
    expect(playback.currentChannel?.id, _channel.id);
    expect(playback.error, isNull);
    // The first play's history save runs on its own: let it land.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await playback.stop();
    playback.dispose();
    return events;
  }

  test('4K: the old player lets go of the decoder before the new one starts',
      () async {
    final events = await reloadWith(const Size(3840, 2160));
    expect(events.indexOf('close 1'), lessThan(events.indexOf('start 2')),
        reason: 'one 4K decoder: a second player beside the first fails');
  });

  test('HD: the new player is ready before the old one goes', () async {
    final events = await reloadWith(const Size(1920, 1080));
    expect(events.indexOf('start 2'), lessThan(events.indexOf('close 1')),
        reason: 'no black screen if the new one fails');
  });
}
