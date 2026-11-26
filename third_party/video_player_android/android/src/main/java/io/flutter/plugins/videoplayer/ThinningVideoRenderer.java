// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
// VesperTV patch: Multiview's frame saver.
package io.flutter.plugins.videoplayer;

import android.content.Context;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.Format;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.container.NalUnitUtil;
import androidx.media3.decoder.DecoderInputBuffer;
import androidx.media3.exoplayer.DecoderReuseEvaluation;
import androidx.media3.exoplayer.ExoPlaybackException;
import androidx.media3.exoplayer.FormatHolder;
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer;
import java.nio.ByteBuffer;

/**
 * Halves what a silent Multiview screen decodes when {@link FrameThinning} is on: frames no
 * other frame depends on (H.264 nal_ref_idc 0, HEVC sub-layer non-reference) are skipped before
 * the decoder, evenly, so a 50/60 fps channel plays at ~25/30 fps. A box's hardware decoder has a
 * fixed budget shared by every screen: on a Homatics Box R 4K Plus (S905X4) three 1080p50 H.264
 * screens + one HEVC showed 6-7 fps each with full buffers, closing one = all 50 fps
 * (2026-11-15). Measured on real channels: 40-74 % of H.264 frames are droppable (BBC One /
 * BBC News 74 %, ESPN 40 %, TSN 49 %), HEVC channels often none.
 *
 * <p>Untouched: streams at 40 fps or less (already cheap; thinner looks choppy), interlaced
 * H.264 (dropping half of a field pair would break the picture), keyframes and anything the
 * frame's first slice says is depended on.
 */
@OptIn(markerClass = UnstableApi.class)
public final class ThinningVideoRenderer extends MediaCodecVideoRenderer {
  private final FrameThinning thinning;
  @Nullable private Format format;
  private boolean interlaced;

  /** Recent sample timestamps (any order), for the stream's frame rate. */
  private final long[] recent = new long[32];
  private int recentCount;
  private int recentNext;

  /** Even spacing: +0.5 per frame, a frame is kept when the credit reaches 1. */
  private double credit;

  private byte[] scratch = new byte[0];

  /** Send-log counters (VesperFrameSaver): samples, kept by the credit, keyframes, depended on. */
  private int seen, keptByCredit, keyframes, dependedOn, thinnedHere, gatedOff;

  public ThinningVideoRenderer(@NonNull Builder builder, @NonNull FrameThinning thinning) {
    super(builder);
    this.thinning = thinning;
    Log.i("VesperFrameSaver", "renderer created");
  }

  @Nullable
  @Override
  protected DecoderReuseEvaluation onInputFormatChanged(@NonNull FormatHolder holder)
      throws ExoPlaybackException {
    format = holder.format;
    interlaced = isInterlacedH264(format);
    recentCount = 0;
    credit = 0;
    Format f = format;
    Log.i("VesperFrameSaver", "format " + (f == null ? "null" : f.sampleMimeType + " "
        + f.width + "x" + f.height + " fps " + f.frameRate + " initData "
        + f.initializationData.size() + " interlaced " + interlaced));
    return super.onInputFormatChanged(holder);
  }

  @Override
  protected boolean shouldDiscardDecoderInputBuffer(@NonNull DecoderInputBuffer buffer) {
    if (super.shouldDiscardDecoderInputBuffer(buffer)) return true;
    Format f = format;
    if (f == null || buffer.data == null || buffer.isEncrypted()) return false;
    recent[recentNext] = buffer.timeUs;
    recentNext = (recentNext + 1) % recent.length;
    if (recentCount < recent.length) recentCount++;
    if (++seen % 1500 == 0 && thinning.isOn()) {
      Log.i("VesperFrameSaver", "on " + thinning.isOn() + " strong " + thinning.isStrong()
          + " interlaced " + interlaced
          + " fps " + Math.round(fps()) + " | last 1500: gated " + gatedOff + ", credit "
          + keptByCredit + ", key " + keyframes + ", depended " + dependedOn + ", thinned "
          + thinnedHere + " | size " + buffer.data.position() + " limit " + buffer.data.limit());
      gatedOff = keptByCredit = keyframes = dependedOn = thinnedHere = 0;
    }
    if (!thinning.isOn() || interlaced || fps() <= 40) {
      credit = 0;
      gatedOff++;
      return false;
    }
    // Strong: ~1/3 kept (a 60 fps channel near 20 fps), as far as its reference frames allow.
    credit += thinning.isStrong() ? 1.0 / 3 : 0.5;
    if (credit >= 1) {
      credit -= 1;
      keptByCredit++;
      return false;
    }
    if (buffer.isKeyFrame()) keyframes++;
    else if (isDependedOn(buffer.data, f)) dependedOn++;
    if (buffer.isKeyFrame() || isDependedOn(buffer.data, f)) {
      // Can't skip this one: it counts as kept (the credit goes negative, the next droppable
      // frames make up for it), capped so a run of reference frames doesn't bank drops.
      credit = Math.max(credit - 1, -1);
      return false;
    }
    buffer.clear();
    thinnedHere++;
    thinning.countThinned();
    return true;
  }

  /** Frames a second from the recent timestamps (B-frames arrive out of order). */
  private double fps() {
    if (recentCount < 8) return 0;
    long min = Long.MAX_VALUE, max = Long.MIN_VALUE;
    for (int i = 0; i < recentCount; i++) {
      min = Math.min(min, recent[i]);
      max = Math.max(max, recent[i]);
    }
    return max > min ? (recentCount - 1) * 1_000_000.0 / (max - min) : 0;
  }

  /** Whether the frame's first slice is referenced by another frame (true when unsure). */
  private boolean isDependedOn(ByteBuffer data, Format f) {
    boolean avc = MimeTypes.VIDEO_H264.equals(f.sampleMimeType);
    boolean hevc = MimeTypes.VIDEO_H265.equals(f.sampleMimeType);
    if (!avc && !hevc) return true;
    ByteBuffer d = data.asReadOnlyBuffer();
    d.flip();
    int n = d.remaining();
    if (scratch.length < n) scratch = new byte[n + n / 4];
    d.get(scratch, 0, n);
    for (int i = 0; i + 3 < n; i++) {
      if (scratch[i] != 0 || scratch[i + 1] != 0 || scratch[i + 2] != 1) continue;
      int h = i + 3;
      int type = avc ? scratch[h] & 0x1f : (scratch[h] >> 1) & 0x3f;
      boolean slice = avc ? type == 1 || type == 5 : type <= 31;
      if (!slice) continue;
      int end = h + 1;
      while (end + 2 < n && !(scratch[end] == 0 && scratch[end + 1] == 0
          && (scratch[end + 2] == 1 || scratch[end + 2] == 0))) {
        end++;
      }
      if (end + 2 >= n) end = n;
      return NalUnitUtil.isDependedOn(scratch, h, end - h, f);
    }
    return true;
  }

  /** H.264 coded as fields (frame_mbs_only_flag 0), from the format's SPS. */
  private static boolean isInterlacedH264(@Nullable Format f) {
    if (f == null || !MimeTypes.VIDEO_H264.equals(f.sampleMimeType)) return false;
    if (f.initializationData.isEmpty()) return true;
    byte[] sps = f.initializationData.get(0);
    int header = 0;
    for (int i = 0; i + 3 < sps.length; i++) {
      if (sps[i] == 0 && sps[i + 1] == 0 && sps[i + 2] == 1) {
        header = i + 3;
        break;
      }
    }
    if (header >= sps.length || (sps[header] & 0x1f) != 7) return true;
    try {
      return !NalUnitUtil.parseSpsNalUnit(sps, header, sps.length).frameMbsOnlyFlag;
    } catch (RuntimeException e) {
      return true;
    }
  }

  /** Context-free factory for the renderers factory. */
  public static ThinningVideoRenderer create(
      Context context,
      androidx.media3.exoplayer.mediacodec.MediaCodecAdapter.Factory adapterFactory,
      androidx.media3.exoplayer.mediacodec.MediaCodecSelector selector,
      boolean fallback,
      @Nullable android.os.Handler handler,
      @Nullable androidx.media3.exoplayer.video.VideoRendererEventListener listener,
      long joiningMs,
      FrameThinning thinning) {
    return new ThinningVideoRenderer(
        new Builder(context)
            .setCodecAdapterFactory(adapterFactory)
            .setMediaCodecSelector(selector)
            .setEnableDecoderFallback(fallback)
            .setAllowedJoiningTimeMs(joiningMs)
            .setEventHandler(handler)
            .setEventListener(listener)
            .setMaxDroppedFramesToNotify(50),
        thinning);
  }
}
