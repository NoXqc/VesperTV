// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
// VesperTV patch: the video's frame rate from the first frames' presentation timestamps, for
// Match frame rate (Dart DisplayMatch, read through StatsBridge "ptsFps"). Live MPEG-TS declares
// no frame rate, and counting rendered frames needed ~4 s of wall clock, so the TV switched
// modes well after the picture had started (Fire TV Cube user, 2026-10-23). Timestamps give it
// within ~0.3 s of the first frame.
package io.flutter.plugins.videoplayer;

import android.media.MediaFormat;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.Format;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.video.VideoFrameMetadataListener;
import java.util.Arrays;

@OptIn(markerClass = UnstableApi.class)
final class FrameRateProbe implements VideoFrameMetadataListener {
  /** Frames used for the FPS estimate; HDR observations continue afterwards. */
  private static final int FRAMES = 16;

  private final long[] times = new long[FRAMES];
  private int count = 0;
  private volatile double fps = -1;
  /** The gaps the estimate came from, in ms, for Send log ("" until then). */
  private volatile String gapsText = "";
  // One immutable observation crosses from the playback thread to the stats reader.
  private static final class HdrSample {
    final Format input;
    final String kind;
    HdrSample(Format input, String kind) { this.input = input; this.kind = kind; }
  }
  @Nullable private volatile HdrSample hdrSample;

  /** Never use a previous adaptive format's colour info for the current format. */
  String decoderHdrKind(@NonNull Format current) {
    HdrSample sample = hdrSample;
    return sample != null && sample.input.equals(current) ? sample.kind : "unknown";
  }

  /** Frames per second, or -1 until enough frames were seen. */
  double fps() {
    return fps;
  }

  String gapsText() {
    return gapsText;
  }

  @Override
  public void onVideoFrameAboutToBeRendered(
      long presentationTimeUs,
      long releaseTimeNs,
      @NonNull Format format,
      @Nullable MediaFormat mediaFormat) {
    // Read only reported output metadata; do not configure the decoder or infer HDR
    // from HEVC, ten-bit video, BT.2020 or the display's advertised capabilities.
    String kind = StatsBridge.decoderHdrKind(mediaFormat);
    HdrSample sample = hdrSample;
    if (sample == null || sample.input != format || !sample.kind.equals(kind)) {
      hdrSample = new HdrSample(format, kind);
    }
    if (count >= FRAMES) return;
    // A seek or restart goes back in time: start over.
    if (count > 0 && presentationTimeUs <= times[count - 1]) count = 0;
    times[count++] = presentationTimeUs;
    if (count == FRAMES) {
      fps = fromTimes(times);
      gapsText = gapsText(times);
    }
  }

  /**
   * 1 s over the average gap, leaving out a dropped frame (a gap over 1.6x the median) or a
   * repeated one (under 0.6x). Was 1 s over the median gap: a 50 fps H.264 channel whose
   * timestamps alternate unevenly (e.g. 17 / 23 ms) gave a median of 17 ms = 58.8 fps, so the
   * player bar said 59 FPS while the Data pool counted 49.77 shown per second (Fire TV,
   * LOG-EVPPYN, 2026-11-19), and Match frame rate could pick a 60 Hz mode.
   */
  static double fromTimes(long[] t) {
    long[] gaps = new long[t.length - 1];
    for (int i = 1; i < t.length; i++) gaps[i - 1] = t[i] - t[i - 1];
    long[] sorted = gaps.clone();
    Arrays.sort(sorted);
    long median = sorted[sorted.length / 2];
    if (median <= 0) return -1;
    long sum = 0;
    int n = 0;
    for (long g : gaps) {
      if (g * 10 >= median * 6 && g * 10 <= median * 16) {
        sum += g;
        n++;
      }
    }
    return n > 0 && sum > 0 ? 1_000_000.0 * n / sum : -1;
  }

  /** "17.0 23.0 ..." ms, for Send log. */
  static String gapsText(long[] t) {
    StringBuilder b = new StringBuilder();
    for (int i = 1; i < t.length; i++) {
      if (b.length() > 0) b.append(' ');
      b.append(String.format(java.util.Locale.US, "%.1f", (t[i] - t[i - 1]) / 1000.0));
    }
    return b.toString();
  }
}
