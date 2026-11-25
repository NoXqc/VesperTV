// VesperTV patch: the Data pool's measured numbers (MethodChannel "vespertv/stats"). Dart samples
// getStats twice and turns the differences into a real bitrate (StreamStats' bytes) and a real
// frame rate (the video decoder's rendered/dropped counters) — live MPEG-TS declares neither.
package io.flutter.plugins.videoplayer;

import android.os.SystemClock;
import android.media.MediaFormat;
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
    boolean onDemand = "setOnDemandBuffering".equals(call.method);
    boolean liveBuffer = "setLiveBuffer".equals(call.method);
    boolean thin = "setFrameThinning".equals(call.method);
    boolean readAhead = "setReadAhead".equals(call.method);
    if ("setLiveBufferDefault".equals(call.method)) {
      Number ms = call.argument("ms");
      OnDemandLoadControl.setDefaultLiveReserveMs(ms == null ? 0 : ms.longValue());
      result.success(null);
      return;
    }
    if (!finite && !onDemand && !liveBuffer && !thin && !readAhead
        && !"getStats".equals(call.method)) {
      result.notImplemented();
      return;
    }
    Number idArg = call.argument("playerId");
    VideoPlayer player = idArg == null ? null : players.get(idArg.longValue());
    if (player == null) {
      result.error("no_player", "No player " + idArg, null);
      return;
    }
    if (thin) {
      // Multiview's frame saver (ThinningVideoRenderer); false for players without it.
      FrameThinning t = player.frameThinning;
      if (t != null) {
        t.setOn(Boolean.TRUE.equals(call.argument("on")));
        t.setStrong(Boolean.TRUE.equals(call.argument("strong")));
      }
      result.success(t != null);
      return;
    }
    if (finite) {
      player.setFiniteMode(Boolean.TRUE.equals(call.argument("on")));
      result.success(null);
      return;
    }
    if (liveBuffer) {
      Number ms = call.argument("ms");
      player.setLiveBuffer(ms == null ? 0 : ms.longValue());
      result.success(null);
      return;
    }
    if (onDemand) {
      player.setOnDemandBuffering(Boolean.TRUE.equals(call.argument("on")));
      result.success(null);
      return;
    }
    if (readAhead) {
      boolean on = Boolean.TRUE.equals(call.argument("on"));
      Number mbps = call.argument("fileMbps");
      String why = player.setReadAhead(on, mbps == null ? 0 : mbps.doubleValue());
      Map<String, Object> r = new HashMap<>();
      r.put("on", on && why == null);
      if (why != null) r.put("reason", why);
      ReadAhead ra = player.readAhead();
      if (ra != null) r.put("windowMb", ra.windowBytes() / (1024 * 1024));
      result.success(r);
      return;
    }
    Map<String, Object> m = new HashMap<>();
    m.put("nowMs", SystemClock.elapsedRealtime());
    @Nullable StreamStats stats = player.streamStats;
    if (stats != null) {
      m.put("bytes", stats.bytes.get());
      long fileSize = stats.fileSizeBytes.get();
      if (fileSize > 0) m.put("fileSizeBytes", fileSize);
      m.put("reconnects", stats.reconnects.get());
      m.put("tsSplices", stats.tsSplices.get());
      m.put("tsJumps", stats.tsJumps.get());
      String last = stats.lastReconnect;
      if (last != null) m.put("lastReconnect", last);
      String fallback = stats.fallback;
      if (fallback != null) m.put("fallback", fallback);
      String streamUid = stats.streamUid;
      if (streamUid != null) m.put("streamUid", streamUid);
    }
    // Live buffer diagnostics for Send log.
    m.put("bufferedMs", player.getExoPlayer().getTotalBufferedDuration());
    FrameThinning thinning = player.frameThinning;
    if (thinning != null) {
      m.put("thinning", thinning.isOn());
      m.put("thinned", thinning.thinned());
    }
    m.put("speed", (double) player.getExoPlayer().getPlaybackParameters().speed);
    m.put("gradual", player.isLiveGradual());
    m.put("cushionSlow", player.isCushionSlow());
    m.put("stalls", player.stalls);
    m.put("lastStallMs", player.lastStallMs);
    // Movie / episode buffering (Dart VodStallLog): where the last freeze began and how much
    // was buffered then, seek waits apart, audio underruns and failed loads (retried).
    m.put("lastStallPosMs", player.lastStallPosMs);
    m.put("lastStallAheadMs", player.lastStallAheadMs);
    m.put("seekWaits", player.seekWaits);
    m.put("lastSeekWaitMs", player.lastSeekWaitMs);
    m.put("underruns", player.audioUnderruns());
    m.put("loadErrors", player.loadErrors());
    String loadError = player.lastLoadError();
    if (loadError != null) m.put("lastLoadError", loadError);
    m.put("smallRam", BufferBudget.isSmallDeviceKnown());
    m.put("vodBufferMb", player.onDemandBufferBytes() / (1024 * 1024));
    ReadAhead ahead = player.readAhead();
    if (ahead != null && ahead.isArmed()) {
      m.put("readAheadOn", true);
      m.put("readAheadMb", ahead.bytesAhead() / (1024 * 1024));
      m.put("readAheadRestarts", ahead.restarts());
      m.put("readAheadConnections", ahead.connections());
      String note = ahead.note();
      if (note != null) m.put("readAheadNote", note);
    }
    m.put("heapMb", Runtime.getRuntime().maxMemory() / (1024 * 1024));
    @Nullable DecoderCounters video = player.getExoPlayer().getVideoDecoderCounters();
    if (video != null) {
      video.ensureUpdated();
      m.put("rendered", video.renderedOutputBufferCount);
      m.put("dropped", video.droppedBufferCount);
      // Multiview diagnostics: dropped before decoding (catching up to a keyframe) vs late
      // decoded frames, and how early/late frames reach the renderer on average.
      m.put("queued", video.queuedInputBufferCount);
      m.put("droppedInput", video.droppedInputBufferCount);
      m.put("droppedToKeyframe", video.droppedToKeyframeCount);
      m.put("skipped", video.skippedOutputBufferCount);
      m.put("maxConsecutiveDropped", video.maxConsecutiveDroppedBufferCount);
      m.put("offsetSumUs", video.totalVideoFrameProcessingOffsetUs);
      m.put("offsetCount", video.videoFrameProcessingOffsetCount);
    }
    // The playing video format: Data pool's "Stream HDR" row and Match frame rate (Dart
    // DisplayMatch) read it. frameRate is -1 when the stream doesn't declare one (live TS).
    @Nullable Format format = player.getExoPlayer().getVideoFormat();
    addHdrStats(m, format, player.frameRateProbe);
    if (format != null) {
      // Dolby Vision only: the profile (dvhe.08.06 -> 8) and the base layer a
      // non-DV device falls back to ("hdr10", "hlg" or "" when not signalled).
      int dvProfile = dvProfile(format);
      if (dvProfile >= 0) {
        m.put("dvProfile", dvProfile);
        m.put("dvBase", dvBase(format));
      }
      m.put("frameRate", (double) format.frameRate);
      // Multiview's log line names the codec: a box's H.264 and HEVC
      // decoders have separate limits (Homatics, 2026-11-15).
      if (format.sampleMimeType != null) m.put("mime", format.sampleMimeType);
      m.put("width", format.width);
      m.put("height", format.height);
    }
    double ptsFps = player.frameRateProbe.fps();
    if (ptsFps > 0) m.put("ptsFps", ptsFps);
    String gaps = player.frameRateProbe.gapsText();
    if (!gaps.isEmpty()) m.put("ptsGaps", gaps);
    @Nullable StreamStats requests = player.streamStats;
    if (requests != null) {
      String opens = requests.opensText();
      if (!opens.isEmpty()) m.put("opens", opens);
    }
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

  /** Keep stream metadata distinct from decoder output; either can be unavailable. */
  static void addHdrStats(Map<String, Object> stats, @Nullable Format format, FrameRateProbe probe) {
    String stream = format == null ? "unknown" : hdrKind(format);
    String decoder = format == null ? "unknown" : probe.decoderHdrKind(format);
    String kind = !"unknown".equals(stream) ? stream : decoder;
    stats.put("streamHdr", stream);
    stats.put("decoderHdr", decoder);
    stats.put("hdr", kind);
    stats.put("hdrSource", !"unknown".equals(stream) ? "stream"
        : !"unknown".equals(decoder) ? "decoder" : "unknown");
  }

  /** Only explicit transfer information establishes SDR. Missing is not SDR. */
  private static String transferKind(int transfer) {
    if (transfer == C.COLOR_TRANSFER_ST2084) return "hdr10";
    if (transfer == C.COLOR_TRANSFER_HLG) return "hlg";
    if (transfer == C.COLOR_TRANSFER_SDR) return "sdr";
    return "unknown";
  }

  static String decoderHdrKind(@Nullable MediaFormat format) {
    if (format == null) return "unknown";
    try {
      if (MimeTypes.VIDEO_DOLBY_VISION.equals(format.getString(MediaFormat.KEY_MIME))) {
        return "dolby_vision";
      }
      if (format.containsKey(MediaFormat.KEY_COLOR_TRANSFER)) {
        return transferKind(format.getInteger(MediaFormat.KEY_COLOR_TRANSFER));
      }
    } catch (RuntimeException ignored) {
      // Some device codecs omit these optional keys or return a value of the wrong type.
    }
    return "unknown";
  }

  /** Stream/container metadata, not the TV's active HDMI mode. */
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
      return transferKind(color.colorTransfer);
    }
    return "unknown";
  }
}
