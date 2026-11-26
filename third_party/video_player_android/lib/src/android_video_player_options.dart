// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
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
