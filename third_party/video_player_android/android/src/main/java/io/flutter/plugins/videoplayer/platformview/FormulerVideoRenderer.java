package io.flutter.plugins.videoplayer.platformview;

import android.content.Context;
import android.os.Build;
import android.util.Log;
import androidx.media3.common.C;
import androidx.media3.common.ColorInfo;
import androidx.media3.common.Format;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DecoderReuseEvaluation;
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo;
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector;
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil.DecoderQueryException;
import androidx.media3.exoplayer.video.MediaCodecVideoRenderer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;

/** Native-beta-only, narrowly scoped to the owner's Realtek Formuler. */
@UnstableApi
public final class FormulerVideoRenderer extends MediaCodecVideoRenderer {
  private final Context context;

  public FormulerVideoRenderer(Context context, Builder builder) {
    super(builder);
    this.context = context;
  }

  public static boolean isTargetDevice() {
    return "FORMULER".equalsIgnoreCase(Build.MANUFACTURER)
        && "Formuler Z11 Pro MAX".equalsIgnoreCase(Build.MODEL);
  }

  @Override
  protected int supportsFormat(MediaCodecSelector selector, Format format) throws DecoderQueryException {
    // Capability discovery also asks the first decoder before walking fallbacks.
    // Put Realtek first there too, rather than probing c2.android first on every zap.
    return MediaCodecVideoRenderer.supportsFormat(context, realtekFirst(selector), format);
  }

  public static MediaCodecSelector realtekFirst(MediaCodecSelector selector) {
    return (mime, secure, tunneling) -> {
      List<MediaCodecInfo> infos = selector.getDecoderInfos(mime, secure, tunneling);
      if (!MimeTypes.VIDEO_H265.equals(mime) || secure || tunneling) return infos;
      ArrayList<MediaCodecInfo> sorted = new ArrayList<>(infos);
      sorted.sort((a, b) -> Boolean.compare(isRealtek(b.name), isRealtek(a.name)));
      return sorted;
    };
  }

  @Override
  protected List<MediaCodecInfo> getDecoderInfos(
      MediaCodecSelector selector, Format format, boolean secure) throws DecoderQueryException {
    if (MimeTypes.VIDEO_H265.equals(format.sampleMimeType) && !secure) {
      List<MediaCodecInfo> available = selector.getDecoderInfos(format.sampleMimeType, false, false);
      ArrayList<MediaCodecInfo> ordered = new ArrayList<>();
      for (MediaCodecInfo info : available) {
        if (isRealtek(info.name) && info.isFormatSupported(context, format)) ordered.add(info);
      }
      if (!ordered.isEmpty()) {
        for (MediaCodecInfo info : available) if (!ordered.contains(info)) ordered.add(info);
        Log.i("VesperNativeSurface", "HEVC decoder order: supported Realtek first; fallback retained");
        return ordered;
      }
    }
    return super.getDecoderInfos(selector, format, secure);
  }

  public static boolean isRealtek(String name) {
    return "OMX.realtek.video.dec.hevc".equals(name);
  }

  /** Ignore redundant/absent bit-depth metadata only within an identical HDR encoding.
   * Transfer, primaries, range and mastering metadata remain authoritative. In particular,
   * never carry PQ into an unknown/SDR channel or keep old mastering data for a new stream.
   */
  public static boolean equivalentHdr(String decoder, Format before, Format after) {
    ColorInfo a = before.colorInfo, b = after.colorInfo;
    return isRealtek(decoder)
        && MimeTypes.VIDEO_H265.equals(before.sampleMimeType)
        && MimeTypes.VIDEO_H265.equals(after.sampleMimeType)
        && before.width >= 3800 && before.width == after.width && before.height == after.height
        && before.codecs != null && Objects.equals(before.codecs, after.codecs)
        && before.frameRate == after.frameRate && before.rotationDegrees == after.rotationDegrees
        && a != null && b != null
        && (a.colorTransfer == C.COLOR_TRANSFER_ST2084 || a.colorTransfer == C.COLOR_TRANSFER_HLG)
        && a.colorTransfer == b.colorTransfer
        && a.colorSpace != Format.NO_VALUE && a.colorSpace == b.colorSpace
        && a.colorRange != Format.NO_VALUE && a.colorRange == b.colorRange
        && Arrays.equals(a.hdrStaticInfo, b.hdrStaticInfo)
        && compatibleDepth(a.lumaBitdepth, b.lumaBitdepth)
        && compatibleDepth(a.chromaBitdepth, b.chromaBitdepth);
  }

  private static boolean compatibleDepth(int a, int b) {
    return a == b || a == Format.NO_VALUE || b == Format.NO_VALUE;
  }

  @Override
  protected DecoderReuseEvaluation canReuseCodec(MediaCodecInfo info, Format before, Format after) {
    DecoderReuseEvaluation original = super.canReuseCodec(info, before, after);
    if (original.discardReasons != DecoderReuseEvaluation.DISCARD_REASON_VIDEO_COLOR_INFO_CHANGED
        || !equivalentHdr(info.name, before, after)) return original;
    // Re-evaluate every upstream size/input-buffer/workaround limit. Keep the real new
    // format in the result so metadata and downstream HDR diagnostics remain accurate.
    DecoderReuseEvaluation equivalent = super.canReuseCodec(
        info, before, after.buildUpon().setColorInfo(before.colorInfo).build());
    if (equivalent.result == DecoderReuseEvaluation.REUSE_RESULT_NO) return original;
    Log.i("VesperNativeSurface", "reusing Realtek HEVC decoder: equivalent HDR colour metadata");
    return new DecoderReuseEvaluation(info.name, before, after, equivalent.result, 0);
  }
}
