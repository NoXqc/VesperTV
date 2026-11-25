// VesperTV patch: counts the bytes a player's HTTP data source really downloads, for the Data
// pool's measured bitrate (live MPEG-TS declares none). See StatsBridge.
package io.flutter.plugins.videoplayer;

import android.net.Uri;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.media3.common.C;
import androidx.annotation.OptIn;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DataSpec;
import androidx.media3.datasource.TransferListener;
import java.util.concurrent.atomic.AtomicLong;
import java.util.List;
import java.util.Map;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@OptIn(markerClass = UnstableApi.class)
final class StreamStats implements TransferListener {
  /** Network bytes since the player was created; written on loader threads. */
  final AtomicLong bytes = new AtomicLong();
  /** Total resource size, never downloaded bytes or an adaptive segment size. */
  final AtomicLong fileSizeBytes = new AtomicLong(-1);
  @Nullable private final Uri fileUri;
  // LiveReconnectDataSource: allowed on the main player only, never for a movie /
  // episode (onDemand) or catch-up (finite); set from VideoPlayer.
  volatile boolean allowReconnect;
  volatile boolean onDemand;
  volatile boolean finite;
  final java.util.concurrent.atomic.AtomicInteger reconnects =
      new java.util.concurrent.atomic.AtomicInteger();
  @Nullable volatile String lastReconnect;
  /** TsSplice: programs changed under the open stream (a Tuliprox source switch). */
  final java.util.concurrent.atomic.AtomicInteger tsSplices =
      new java.util.concurrent.atomic.AtomicInteger();
  /** TsSplice: timestamp jumps smoothed over (the picture would have stood still). */
  final java.util.concurrent.atomic.AtomicInteger tsJumps =
      new java.util.concurrent.atomic.AtomicInteger();
  /**
   * Tuliprox's {@code X-Tuliprox-Fallback} on the latest response ({@code
   * provider_connections_exhausted}, {@code user_connections_exhausted}, ...): the stream is the
   * server's busy / error video, not the channel (Player API, 2026-11-23). Null when absent.
   */
  @Nullable volatile String fallback;

  /// Tuliprox's {@code X-Tuliprox-Stream-Uid} of the latest answer (live MPEG-TS, Player API
  /// users, since e5704880): the stream to end with {@code DELETE /api/v1/me/streams/{uid}}.
  @Nullable volatile String streamUid;
  /** Big movie files: several connections + a memory ring (HttpVideoAsset, progressive only). */
  @Nullable volatile ReadAhead readAhead;
  /** Live pause & rewind: the rolling copy of a live stream (HttpVideoAsset, progressive only). */
  @Nullable volatile Timeshift timeshift;

  /**
   * The player's first network requests ({sent ns, answered ns, ended ns, byte position, bytes}),
   * for Send log: how long a slow catch-up panel takes per request (Fire TV, 2026-11-19: a `.ts`
   * catch-up start = the first bytes, the end of the file for its length, then back to the start).
   */
  private static final int MAX_OPENS = 8;
  private final Object opensLock = new Object();
  private final java.util.ArrayList<long[]> opens = new java.util.ArrayList<>();
  @Nullable private long[] currentOpen;

  /** "+0.00s @0 B answered 0.61s, 1.2 MB in 0.70s | ...", or "" before any request. */
  String opensText() {
    synchronized (opensLock) {
      if (opens.isEmpty()) return "";
      long t0 = opens.get(0)[0];
      StringBuilder b = new StringBuilder();
      for (long[] o : opens) {
        if (b.length() > 0) b.append(" | ");
        b.append(String.format(Locale.US, "+%.2fs @%s answered %s, %s", (o[0] - t0) / 1e9,
            sizeText(o[3]), o[1] < 0 ? "-" : String.format(Locale.US, "%.2fs", (o[1] - o[0]) / 1e9),
            sizeText(o[4])));
        if (o[2] >= 0) b.append(String.format(Locale.US, " in %.2fs", (o[2] - o[0]) / 1e9));
      }
      return b.toString();
    }
  }

  private static String sizeText(long bytes) {
    if (bytes < 1024) return bytes + " B";
    if (bytes < 1024 * 1024) return String.format(Locale.US, "%.0f KB", bytes / 1024.0);
    if (bytes < 1024L * 1024 * 1024) return String.format(Locale.US, "%.1f MB", bytes / 1048576.0);
    return String.format(Locale.US, "%.2f GB", bytes / 1073741824.0);
  }

  /** A single progressive resource (not HLS/DASH): what LiveReconnectDataSource wraps. */
  boolean isProgressive() {
    return fileUri != null;
  }

  @Nullable
  Uri fileUri() {
    return fileUri;
  }
  private static final Pattern RANGE = Pattern.compile(
      "bytes\\s+(\\d+)-(\\d+)/(\\d+)", Pattern.CASE_INSENSITIVE);

  StreamStats(@Nullable Uri fileUri) {
    this.fileUri = fileUri;
  }

  /** Read headers from the player's own progressive-file request, no extra connection. */
  static long fileSizeFromHeaders(Map<String, List<String>> headers, DataSpec spec) {
    String encoding = header(headers, "Content-Encoding");
    if (encoding != null && !encoding.equalsIgnoreCase("identity")) return -1;
    String type = header(headers, "Content-Type");
    if (type != null) {
      type = type.toLowerCase(Locale.ROOT);
      if (type.startsWith("text/") || type.contains("json") || type.contains("xml")
          || type.contains("mpegurl")) return -1;
    }
    String range = header(headers, "Content-Range");
    try {
      if (range != null) {
        Matcher match = RANGE.matcher(range.trim());
        if (!match.matches()) return -1;
        long start = Long.parseLong(match.group(1));
        long end = Long.parseLong(match.group(2));
        long total = Long.parseLong(match.group(3));
        return total > 0 && start <= end && end < total ? total : -1;
      }
      // A partial request's Content-Length is not the file's total size.
      if (spec.position != 0 || spec.length != C.LENGTH_UNSET) return -1;
      String length = header(headers, "Content-Length");
      long size = length == null ? -1 : Long.parseLong(length.trim());
      return size > 0 ? size : -1;
    } catch (NumberFormatException ignored) {
      return -1;
    }
  }

  @Nullable
  private static String header(Map<String, List<String>> headers, String name) {
    if (headers == null) return null;
    for (Map.Entry<String, List<String>> entry : headers.entrySet()) {
      if (name.equalsIgnoreCase(entry.getKey()) && entry.getValue() != null
          && !entry.getValue().isEmpty()) return entry.getValue().get(0);
    }
    return null;
  }

  @Override
  public void onTransferInitializing(
      @NonNull DataSource source, @NonNull DataSpec dataSpec, boolean isNetwork) {
    if (!isNetwork) return;
    synchronized (opensLock) {
      if (opens.size() >= MAX_OPENS) {
        currentOpen = null;
        return;
      }
      currentOpen = new long[] {System.nanoTime(), -1, -1, dataSpec.position, 0};
      opens.add(currentOpen);
    }
  }

  @Override
  public void onTransferStart(
      @NonNull DataSource source, @NonNull DataSpec dataSpec, boolean isNetwork) {
    if (isNetwork) {
      synchronized (opensLock) {
        if (currentOpen != null && currentOpen[1] < 0) currentOpen[1] = System.nanoTime();
      }
      fallback = headerValue(source.getResponseHeaders(), "x-tuliprox-fallback");
      streamUid = headerValue(source.getResponseHeaders(), "x-tuliprox-stream-uid");
    }
    if (!isNetwork || fileUri == null || !fileUri.equals(dataSpec.uri)) return;
    long size = fileSizeFromHeaders(source.getResponseHeaders(), dataSpec);
    if (size > 0) fileSizeBytes.set(size);
  }

  @Override
  public void onBytesTransferred(
      @NonNull DataSource source,
      @NonNull DataSpec dataSpec,
      boolean isNetwork,
      int bytesTransferred) {
    if (!isNetwork) return;
    bytes.addAndGet(bytesTransferred);
    synchronized (opensLock) {
      if (currentOpen != null) currentOpen[4] += bytesTransferred;
    }
  }

  @Override
  public void onTransferEnd(
      @NonNull DataSource source, @NonNull DataSpec dataSpec, boolean isNetwork) {
    if (!isNetwork) return;
    synchronized (opensLock) {
      if (currentOpen != null) {
        currentOpen[2] = System.nanoTime();
        currentOpen = null;
      }
    }
  }

  /** The first value of header [name] (any case), or null. */
  @Nullable
  static String headerValue(@Nullable Map<String, List<String>> headers, String name) {
    if (headers == null) return null;
    for (Map.Entry<String, List<String>> e : headers.entrySet()) {
      if (e.getKey() != null && e.getKey().equalsIgnoreCase(name)) {
        List<String> values = e.getValue();
        if (values != null && !values.isEmpty()) return values.get(0);
      }
    }
    return null;
  }
}
