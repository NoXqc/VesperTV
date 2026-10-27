// VesperTV patch: the Data pool's measured numbers (MethodChannel "vespertv/stats"). Dart samples
// getStats twice and turns the differences into a real bitrate (StreamStats' bytes) and a real
// frame rate (the video decoder's rendered/dropped counters) — live MPEG-TS declares neither.
package io.flutter.plugins.videoplayer;

import android.os.SystemClock;
import android.util.LongSparseArray;
import androidx.annotation.NonNull;
import androidx.annotation.OptIn;
import androidx.annotation.Nullable;
import androidx.media3.common.C;
import androidx.media3.common.ColorInfo;
import androidx.media3.common.Format;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.DecoderCounters;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

@OptIn(markerClass = UnstableApi.class)
final class StatsBridge implements MethodChannel.MethodCallHandler {
  private final LongSparseArray<VideoPlayer> players;
  private final MethodChannel methods;

  StatsBridge(@NonNull BinaryMessenger messenger, @NonNull LongSparseArray<VideoPlayer> players) {
    this.players = players;
    methods = new MethodChannel(messenger, "vespertv/stats");
    methods.setMethodCallHandler(this);
  }

  void dispose() {
    methods.setMethodCallHandler(null);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    boolean finite = "setFiniteMode".equals(call.method);
    if (!finite && !"getStats".equals(call.method)) {
      result.notImplemented();
      return;
    }
    Number idArg = call.argument("playerId");
    VideoPlayer player = idArg == null ? null : players.get(idArg.longValue());
    if (player == null) {
      result.error("no_player", "No player " + idArg, null);
      return;
    }
    if (finite) {
      player.setFiniteMode(Boolean.TRUE.equals(call.argument("on")));
      result.success(null);
      return;
    }
    Map<String, Object> m = new HashMap<>();
    m.put("nowMs", SystemClock.elapsedRealtime());
    @Nullable StreamStats stats = player.streamStats;
    if (stats != null) m.put("bytes", stats.bytes.get());
    @Nullable DecoderCounters video = player.getExoPlayer().getVideoDecoderCounters();
    if (video != null) {
      video.ensureUpdated();
      m.put("rendered", video.renderedOutputBufferCount);
      m.put("dropped", video.droppedBufferCount);
    }
    // The playing video format: Data pool's "Stream HDR" row and Match frame rate (Dart
    // DisplayMatch) read it. frameRate is -1 when the stream doesn't declare one (live TS).
    @Nullable Format format = player.getExoPlayer().getVideoFormat();
    if (format != null) {
      m.put("hdr", hdrKind(format));
      // Dolby Vision only: the profile (dvhe.08.06 -> 8) and the base layer a
      // non-DV device falls back to ("hdr10", "hlg" or "" when not signalled).
      int dvProfile = dvProfile(format);
      if (dvProfile >= 0) {
        m.put("dvProfile", dvProfile);
        m.put("dvBase", dvBase(format));
      }
      m.put("frameRate", (double) format.frameRate);
      m.put("width", format.width);
      m.put("height", format.height);
    }
    double ptsFps = player.frameRateProbe.fps();
    if (ptsFps > 0) m.put("ptsFps", ptsFps);
    result.success(m);
  }

  /** Dolby Vision profile from the codecs string (dvhe.08.06 -> 8), else -1. */
  static int dvProfile(@NonNull Format format) {
    String codecs = format.codecs == null ? "" : format.codecs;
    if (!"dolby_vision".equals(hdrKind(format))) return -1;
    String[] parts = codecs.split("\\.");
    if (parts.length < 2) return -1;
    try {
      return Integer.parseInt(parts[1]);
    } catch (NumberFormatException e) {
      return -1;
    }
  }

  /** The base layer's transfer as signalled by the container: "hdr10", "hlg" or "". */
  static String dvBase(@NonNull Format format) {
    @Nullable ColorInfo color = format.colorInfo;
    if (color == null) return "";
    if (color.colorTransfer == C.COLOR_TRANSFER_ST2084) return "hdr10";
    if (color.colorTransfer == C.COLOR_TRANSFER_HLG) return "hlg";
    return "";
  }

  /** "dolby_vision", "hdr10", "hlg" or "sdr" (an unknown transfer counts as SDR). */
  static String hdrKind(@NonNull Format format) {
    String codecs = format.codecs == null ? "" : format.codecs;
    if (MimeTypes.VIDEO_DOLBY_VISION.equals(format.sampleMimeType)
        || codecs.startsWith("dvhe")
        || codecs.startsWith("dvh1")
        || codecs.startsWith("dvav")
        || codecs.startsWith("dva1")) {
      return "dolby_vision";
    }
    @Nullable ColorInfo color = format.colorInfo;
    if (color != null) {
      if (color.colorTransfer == C.COLOR_TRANSFER_ST2084) return "hdr10";
      if (color.colorTransfer == C.COLOR_TRANSFER_HLG) return "hlg";
    }
    return "sdr";
  }
}
