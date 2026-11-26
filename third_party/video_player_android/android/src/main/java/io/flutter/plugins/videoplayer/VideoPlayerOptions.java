// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
// Changed by VesperTV contributors (2026): those changes are under the GNU GPL v3
// (see LICENSE-VESPERTV.md); Flutter's original code here stays under the BSD LICENSE.

package io.flutter.plugins.videoplayer;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import android.view.SurfaceHolder;

public class VideoPlayerOptions {
  public boolean mixWithOthers;
  public boolean allowEncodedAudio;
  public boolean effectivePassthrough;

  /**
   * The duration of the back buffer in milliseconds, used to configure ExoPlayer's load control.
   */
  @Nullable public Long backBufferDurationMs;

  // Per-player only: the opt-in native beta's real output before prepare.
  @Nullable public SurfaceHolder nativeSurfaceHolder;

  public VideoPlayerOptions() {}

  /** Copy constructor to ensure all options are reliably copied. */
  public VideoPlayerOptions(@NonNull VideoPlayerOptions other) {
    this.mixWithOthers = other.mixWithOthers;
    this.allowEncodedAudio = other.allowEncodedAudio;
    this.effectivePassthrough = other.effectivePassthrough;
    this.backBufferDurationMs = other.backBufferDurationMs;
    this.nativeSurfaceHolder = other.nativeSurfaceHolder;
  }
}
