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
  /** Frames looked at; after that the probe stops doing anything. */
  private static final int FRAMES = 16;

  private final long[] times = new long[FRAMES];
  private int count = 0;
  private volatile double fps = -1;

  /** Frames per second, or -1 until enough frames were seen. */
  double fps() {
    return fps;
  }

  @Override
  public void onVideoFrameAboutToBeRendered(
      long presentationTimeUs,
      long releaseTimeNs,
      @NonNull Format format,
      @Nullable MediaFormat mediaFormat) {
    if (count >= FRAMES) return;
    // A seek or restart goes back in time: start over.
    if (count > 0 && presentationTimeUs <= times[count - 1]) count = 0;
    times[count++] = presentationTimeUs;
    if (count == FRAMES) fps = fromTimes(times);
  }

  /** 1 s over the median gap: a dropped or repeated frame doesn't skew it. */
  static double fromTimes(long[] t) {
    long[] gaps = new long[t.length - 1];
    for (int i = 1; i < t.length; i++) gaps[i - 1] = t[i] - t[i - 1];
    Arrays.sort(gaps);
    long median = gaps[gaps.length / 2];
    return median > 0 ? 1_000_000.0 / median : -1;
  }
}
