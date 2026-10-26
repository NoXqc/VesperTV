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
