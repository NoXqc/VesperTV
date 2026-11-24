import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Per-player encoded audio permission, independent of video composition.
class AndroidVideoPlayerOptions extends VideoPlayerOptions {
  AndroidVideoPlayerOptions({
    required this.allowEncodedAudio,
    VideoPlayerOptions? options,
  }) : super(
         mixWithOthers: options?.mixWithOthers ?? false,
         allowBackgroundPlayback: options?.allowBackgroundPlayback ?? false,
         preventsDisplaySleepDuringVideoPlayback:
             options?.preventsDisplaySleepDuringVideoPlayback ?? true,
         webOptions: options?.webOptions,
         backBufferDurationMs: options?.backBufferDurationMs,
       );

  final bool allowEncodedAudio;
}
