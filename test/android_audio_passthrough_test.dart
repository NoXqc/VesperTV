import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/playback_service.dart';
import 'package:video_player_android/video_player_android.dart';
import 'package:video_player_android/src/messages.g.dart';
import 'package:video_player_hdr/video_player_hdr.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _AudioApi extends AndroidVideoPlayerApi {
  final created = <CreationOptions>[];
  bool passthrough = false;

  @override
  Future<TexturePlayerIds> createForTextureView(CreationOptions options) async {
    created.add(options);
    return TexturePlayerIds(
        playerId: created.length, textureId: created.length);
  }

  @override
  Future<bool> isAudioPassthroughEnabled(int playerId) async => passthrough;

  @override
  Future<void> dispose(int playerId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encoded audio permission reaches creation and survives serialization',
      () async {
    final api = _AudioApi();
    final player = AndroidVideoPlayer(
      pluginApi: api,
      videoEventStreamProvider: (_) => const Stream.empty(),
    );
    final original = VideoPlayerOptions(
      mixWithOthers: true,
      allowBackgroundPlayback: true,
      backBufferDurationMs: 30000,
    );
    final main = AndroidVideoPlayerOptions(
      allowEncodedAudio: true,
      options: original,
    );
    expect(main.mixWithOthers, isTrue);
    expect(main.allowBackgroundPlayback, isTrue);
    expect(main.backBufferDurationMs, 30000);
    for (final options in [
      main,
      AndroidVideoPlayerOptions(allowEncodedAudio: false, options: original),
      original,
    ]) {
      final id = await player.createWithOptions(VideoCreationOptions(
        dataSource: DataSource(
          sourceType: DataSourceType.network,
          uri: 'https://example.com/live.ts',
        ),
        viewType: VideoViewType.textureView,
        videoPlayerOptions: options,
      ));
      final decoded = CreationOptions.decode(api.created.last.encode());
      expect(decoded.allowEncodedAudio, options == main);
      expect(decoded.backBufferDurationMs, 30000);
      await player.dispose(id!);
    }
  });

  test('Multiview handover rejects a sink that permits passthrough', () async {
    final previous = VideoPlayerPlatform.instance;
    final api = _AudioApi();
    VideoPlayerPlatform.instance = AndroidVideoPlayer(pluginApi: api);
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    final controller = VideoPlayerHdrController.networkUrl(
      Uri.parse('https://example.com/live.ts'),
    );
    api.passthrough = true;
    expect(await PlaybackService.canHandOverToMultiview(controller), isFalse);
    api.passthrough = false;
    expect(await PlaybackService.canHandOverToMultiview(controller), isTrue);
  });
}
