// VesperTV patch: DTS goes to VesperTV's own FFmpeg decoder.
package io.flutter.plugins.videoplayer;

import android.content.Context;
import android.util.Log;
import android.util.Pair;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.TrackGroup;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.decoder.ffmpeg.FfmpegLibrary;
import androidx.media3.exoplayer.ExoPlaybackException;
import androidx.media3.exoplayer.RendererCapabilities;
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo;
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector;
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil;
import androidx.media3.exoplayer.source.TrackGroupArray;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;
import androidx.media3.exoplayer.trackselection.ExoTrackSelection;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Predicate;

/**
 * DTS and DTS-HD (`audio/vnd.dts`, `audio/vnd.dts.hd`: FFmpeg's dca) are decoded by VesperTV's
 * FFmpeg decoder, never the box's.
 *
 * <p>The players ask the box's decoders first (EXTENSION_RENDERER_MODE_ON) and FFmpeg only for a
 * format the box can't decode. Amlogic firmware lists DTS decoders (c2.amlogic.audio.decoder.dts /
 * dtshd) whether or not the box carries the DTS licence behind them: on an onn 4K Pro (issue in
 * Discord, dajokahn, LOG-33PC25, 2026-11-25) a DTS-HD movie opened one and played silent, with
 * passthrough off. A licensed box (Homatics: libHwAudio_dtsx) gives the same PCM either way.
 *
 * <p>Only decoding: passthrough (Settings > Surround passthrough) never asks this selector, so DTS
 * still goes to a receiver untouched when that's on and the TV takes it. A DTS type FFmpeg doesn't
 * map (DTS Express `;profile=lbr`, DTS:X profile 2 `audio/vnd.dts.uhd`) keeps the box's decoder,
 * and so does everything when the FFmpeg library didn't load.
 *
 * <p>Track choice stays as it was ({@link TrackSelector}): media3 ranks a hardware decoder above a
 * software one before it looks at channels, so a DTS 7.1 track moved to FFmpeg would lose to an
 * AC3 track (even a 2-channel commentary) that nothing else tells apart. A DTS track whose box
 * decoder was hardware keeps that rank.
 */
@OptIn(markerClass = UnstableApi.class)
public final class DtsSoftwareDecoders implements MediaCodecSelector {
  private static final String TAG = "VesperAudio";
  private static final String FFMPEG_AUDIO_RENDERER = "FfmpegAudioRenderer";

  public static final DtsSoftwareDecoders INSTANCE =
      new DtsSoftwareDecoders(
          mime -> FfmpegLibrary.isAvailable() && FfmpegLibrary.supportsFormat(mime),
          MediaCodecSelector.DEFAULT);

  private final Predicate<String> softwareDecodes;
  private final MediaCodecSelector base;
  private final Set<String> logged = ConcurrentHashMap.newKeySet();

  /** DTS types whose skipped box decoder was a hardware one (they keep that rank). */
  private final Set<String> boxHardware = ConcurrentHashMap.newKeySet();

  DtsSoftwareDecoders(Predicate<String> softwareDecodes, MediaCodecSelector base) {
    this.softwareDecodes = softwareDecodes;
    this.base = base;
  }

  static boolean isDts(@Nullable String mimeType) {
    return mimeType != null && mimeType.startsWith("audio/vnd.dts");
  }

  @NonNull
  @Override
  public List<MediaCodecInfo> getDecoderInfos(
      @NonNull String mimeType, boolean requiresSecureDecoder, boolean requiresTunnelingDecoder)
      throws MediaCodecUtil.DecoderQueryException {
    if (isDts(mimeType) && softwareDecodes.test(mimeType)) {
      boolean hardware = false;
      try {
        List<MediaCodecInfo> box =
            base.getDecoderInfos(mimeType, requiresSecureDecoder, requiresTunnelingDecoder);
        hardware = !box.isEmpty() && box.get(0).hardwareAccelerated;
      } catch (MediaCodecUtil.DecoderQueryException e) {
        // Not knowing the box's decoder only loses the rank, never the sound.
      }
      if (hardware) boxHardware.add(mimeType);
      if (logged.add(mimeType)) {
        Log.i(TAG, "DTS (" + mimeType + "): VesperTV's own decoder, the box's DTS decoder skipped"
            + (hardware ? " (ranked as the box's hardware one)" : ""));
      }
      return Collections.emptyList();
    }
    return base.getDecoderInfos(mimeType, requiresSecureDecoder, requiresTunnelingDecoder);
  }

  /**
   * [supports] with the FFmpeg audio renderer's DTS tracks marked hardware where the box's skipped
   * decoder was; the same array when nothing changes. A DTS group on another renderer (the box's,
   * for passthrough) is left alone.
   */
  int[][][] rankLikeTheBox(
      DefaultTrackSelector.MappedTrackInfo info, int[][][] supports) {
    if (boxHardware.isEmpty()) return supports;
    int[][][] out = supports;
    for (int r = 0; r < info.getRendererCount(); r++) {
      if (info.getRendererType(r) != C.TRACK_TYPE_AUDIO
          || !FFMPEG_AUDIO_RENDERER.equals(info.getRendererName(r))) {
        continue;
      }
      TrackGroupArray groups = info.getTrackGroups(r);
      for (int g = 0; g < groups.length; g++) {
        TrackGroup group = groups.get(g);
        for (int t = 0; t < group.length; t++) {
          Format format = group.getFormat(t);
          int support = supports[r][g][t];
          if (!isDts(format.sampleMimeType)
              || !boxHardware.contains(format.sampleMimeType)
              || RendererCapabilities.getFormatSupport(support) != C.FORMAT_HANDLED
              || RendererCapabilities.getHardwareAccelerationSupport(support)
                  == RendererCapabilities.HARDWARE_ACCELERATION_SUPPORTED) {
            continue;
          }
          if (out == supports) out = copy(supports);
          out[r][g][t] =
              (support & ~RendererCapabilities.HARDWARE_ACCELERATION_SUPPORT_MASK)
                  | RendererCapabilities.HARDWARE_ACCELERATION_SUPPORTED;
        }
      }
    }
    return out;
  }

  private static int[][][] copy(int[][][] a) {
    // Slots can be null (media3 leaves room for unmapped groups).
    int[][][] c = new int[a.length][][];
    for (int i = 0; i < a.length; i++) {
      if (a[i] == null) continue;
      c[i] = new int[a[i].length][];
      for (int j = 0; j < a[i].length; j++) c[i][j] = a[i][j] == null ? null : a[i][j].clone();
    }
    return c;
  }

  /** The players' track selector: stock, except DTS keeps the box decoder's rank. */
  public static final class TrackSelector extends DefaultTrackSelector {
    private final DtsSoftwareDecoders decoders;

    public TrackSelector(Context context) {
      this(context, INSTANCE);
    }

    TrackSelector(Context context, DtsSoftwareDecoders decoders) {
      super(context);
      this.decoders = decoders;
    }

    @Nullable
    @Override
    protected Pair<ExoTrackSelection.Definition, Integer> selectAudioTrack(
        MappedTrackInfo mappedTrackInfo,
        @RendererCapabilities.Capabilities int[][][] rendererFormatSupports,
        @RendererCapabilities.AdaptiveSupport int[] rendererMixedMimeTypeAdaptationSupports,
        Parameters params)
        throws ExoPlaybackException {
      return super.selectAudioTrack(
          mappedTrackInfo,
          decoders.rankLikeTheBox(mappedTrackInfo, rendererFormatSupports),
          rendererMixedMimeTypeAdaptationSupports,
          params);
    }
  }
}
