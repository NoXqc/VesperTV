// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
// VesperTV patch: Multiview's frame saver (see ThinningVideoRenderer).
package io.flutter.plugins.videoplayer;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Switch + counter shared by Dart (StatsBridge `setFrameThinning`, main thread) and one player's
 * {@link ThinningVideoRenderer} (playback thread).
 */
public final class FrameThinning {
  private volatile boolean on;
  private volatile boolean strong;
  private final AtomicLong thinned = new AtomicLong();

  public void setOn(boolean value) {
    on = value;
  }

  /**
   * Keep 1 skippable frame in 3 instead of 1 in 2 (3-4 screens: the screen with the sound kept
   * dropping half its frames, Homatics 2026-11-17).
   */
  public void setStrong(boolean value) {
    strong = value;
  }

  public boolean isStrong() {
    return strong;
  }

  public boolean isOn() {
    return on;
  }

  /** Frames skipped before decoding since the player was created. */
  public long thinned() {
    return thinned.get();
  }

  void countThinned() {
    thinned.incrementAndGet();
  }
}
