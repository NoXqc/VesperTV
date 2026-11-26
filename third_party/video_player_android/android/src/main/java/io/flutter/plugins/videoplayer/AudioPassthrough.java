// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
// VesperTV patch: opt-in HDMI audio passthrough for the main player (MethodChannel
// "vespertv/audio", Settings > Interface > Audio). Off by default: every player is built with a
// context-less DefaultAudioSink, so Dolby audio is always decoded to PCM and setVolume() keeps
// working (Multiview audio bleed, 2026-10-07; see PlatformViewVideoPlayer). On, the main
// player's sink gets the Context, detects what the TV/receiver accepts over HDMI
// and sends AC3 / E-AC3 (incl. Dolby Atmos) / DTS untouched — the app's volume and mute then no
// longer affect that audio. Compatibility video opts in per player; Multiview stays PCM-only.
// Read when a player is created, so it applies from the next channel.
package io.flutter.plugins.videoplayer;

import androidx.annotation.NonNull;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public final class AudioPassthrough implements MethodChannel.MethodCallHandler {
  private static volatile boolean enabled = false;

  public static boolean isEnabled() {
    return enabled;
  }

  private final MethodChannel methods;

  AudioPassthrough(@NonNull BinaryMessenger messenger) {
    methods = new MethodChannel(messenger, "vespertv/audio");
    methods.setMethodCallHandler(this);
  }

  void dispose() {
    methods.setMethodCallHandler(null);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    if ("setAudioDelay".equals(call.method)) {
      Integer ms = call.argument("ms");
      AudioDelay.setDelayMs(ms == null ? 0 : ms);
      result.success(null);
      return;
    }
    if (!"setPassthrough".equals(call.method)) {
      result.notImplemented();
      return;
    }
    Boolean on = call.argument("enabled");
    enabled = Boolean.TRUE.equals(on);
    result.success(null);
  }
}
