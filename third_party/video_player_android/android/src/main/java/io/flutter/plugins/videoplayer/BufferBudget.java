// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
// VesperTV patch: memory budget for the player's buffer (see the callers in
// PlatformViewVideoPlayer and TextureVideoPlayer).
package io.flutter.plugins.videoplayer;

import android.app.ActivityManager;
import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DefaultLoadControl;

/**
 * Caps how many bytes a player may buffer on small-RAM devices. The buffer
 * is Java heap: with only the duration limits, a 4K remux (50-100 Mbit/s)
 * kept ExoPlayer's default ~140 MB cap full on a 1.7 GB Fire TV Stick, the
 * whole device ran out of memory and VesperTV was closed as not
 * responding (Media Hub 4K movie, 2026-10-21). Bigger devices keep
 * media3's own default.
 */
@OptIn(markerClass = UnstableApi.class)
public final class BufferBudget {
  private BufferBudget() {}

  /** Devices under this much RAM get a byte cap. */
  private static final long SMALL_RAM_BYTES = 2_500L * 1024 * 1024;

  /** The full-screen player: ~6 s of a 4K remux, ~20 s of 4K live TV. */
  public static final int MAIN_PLAYER_BYTES = 64 * 1024 * 1024;

  /** Each texture player (Multiview screens, Compatibility video). */
  public static final int TEXTURE_PLAYER_BYTES = 32 * 1024 * 1024;

  private static Boolean small;

  static synchronized boolean isSmallDevice(@NonNull Context context) {
    if (small == null) {
      boolean result = false;
      ActivityManager am = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
      if (am != null) {
        ActivityManager.MemoryInfo info = new ActivityManager.MemoryInfo();
        am.getMemoryInfo(info);
        result = am.isLowRamDevice() || info.totalMem < SMALL_RAM_BYTES;
      }
      small = result;
    }
    return small;
  }

  /** Movies / episodes on the main player: never more than this (~21 s of a 100 Mbit/s remux). */
  private static final long ON_DEMAND_MAX_BYTES = 256L * 1024 * 1024;

  /** Media3's own default for a video + audio + text player, what bigger devices get today. */
  private static final long MEDIA3_DEFAULT_BYTES = 144L * 1024 * 1024;

  /**
   * The main player's byte cap for movies / episodes (OnDemandLoadControl), 0 = unchanged. Not on
   * small devices (they keep 64 MB). Elsewhere half the app's Java heap limit, at most 256 MB:
   * the buffer is Java heap, and the app's own heap use is small (Flutter's images and Dart heap
   * live in native memory). A 512 MB heap (largeHeap on 3-4 GB boxes) gives 256 MB.
   */
  public static long onDemandBytes(@NonNull Context context) {
    if (isSmallDevice(context)) return 0;
    long bytes = Math.min(ON_DEMAND_MAX_BYTES, Runtime.getRuntime().maxMemory() / 2);
    return bytes > MEDIA3_DEFAULT_BYTES ? bytes : 0;
  }

  /** Send log: whether the byte cap applies (false until a player was built). */
  static synchronized boolean isSmallDeviceKnown() {
    return small != null && small;
  }

  /** Applies [bytes] as the buffer cap on a small device; no-op otherwise. */
  public static void apply(
      @NonNull Context context, @NonNull DefaultLoadControl.Builder builder, int bytes) {
    if (!isSmallDevice(context)) return;
    builder.setTargetBufferBytes(bytes);
    // Bytes win over the duration limits (media3's default, made explicit).
    builder.setPrioritizeTimeOverSizeThresholds(false);
  }
}
