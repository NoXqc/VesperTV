// VesperTV patch: faster downloads for big movie files (several connections, a memory ring).
//
// The main player's movie buffer is Java heap (OnDemandLoadControl: 192 MB on the owner's
// Homatics, ~24 s of a 65 Mbit/s 4K remux). A Media Hub remux froze twice when its source
// slowed to 51-57 Mbit/s for ~3 minutes (owner, 2026-11-21, Send log "download slower than the
// file"), although over the first 46 minutes the source had sent more than the file needed.
// The first version (+954/+955) downloaded ahead into a 4 GB ring FILE. On the Homatics the
// box's memory was full (swap 811/819 MB), the written data left the page cache before the player
// reached it, and the flash read it back at 6 MB/s while writing 15 MB/s: the 80 Mbit/s file
// froze every ~10 s with 1:30-2:40 downloaded. So the ring is memory now (64 MB of direct
// buffers, outside the Java heap), on top of the player's own buffer.
//
// The file ahead is fetched in segments (32 MB). One connection at first; while the download
// stays slower than the file needs, a second and a third connection fetch the next segments at
// the same time (TorBox allows many connections; one stream can stay well under the line's
// speed). A connection that brings no gain is dropped again. Same owner, the same evening: a
// 94.5 GB / 80 Mbit/s file got 41-65 Mbit/s on one connection.
//
// Only switched on from Dart (StatsBridge "setReadAhead") for a movie / episode whose average
// bitrate is high; never for live. The memory is freed when the player stops.
package io.flutter.plugins.videoplayer;

import android.net.Uri;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.annotation.VisibleForTesting;
import androidx.media3.common.C;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DataSpec;
import androidx.media3.datasource.HttpDataSource;
import java.io.IOException;
import java.io.InterruptedIOException;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.TreeMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.ReentrantLock;

@OptIn(markerClass = UnstableApi.class)
final class ReadAhead {
  private static final String TAG = "VesperReadAhead";
  private static final int CHUNK = 256 * 1024;

  /** Sizes and timings; tests use small ones. */
  static final class Tuning {
    long windowBytes = 64L << 20;
    /** The ring's pieces (direct buffers, allocated as they are first written). */
    int blockBytes = 1 << 20;
    /** Kept behind the reader for a small step back (an extractor re-reading a header). */
    long keepBehindBytes = 4L << 20;
    /** An open this far past what is downloaded waits for it instead of starting over. */
    long waitGapBytes = 8L << 20;
    long segmentBytes = 8L << 20;
    int maxConnections = 3;
    /** How long each speed sample lasts before deciding on another connection. */
    long sampleMs = 15_000;
    /** After a connection brought no gain, no new try for this long. */
    long noGainPauseMs = 5 * 60_000;
    long[] retryDelaysMs = {1000, 2000, 4000, 8000, 8000, 8000};
  }

  /** {@link #read}: the read-ahead was switched off, read the source directly. */
  static final int STOPPED = -2;

  private static final class Segment {
    final long start;
    long end;
    long filled;

    Segment(long start, long end) {
      this.start = start;
      this.end = end;
    }

    boolean done() {
      return filled >= end - start;
    }
  }

  private final DataSource.Factory upstreamFactory;
  @Nullable private final Uri fileUri;
  private final Tuning t;

  private final ReentrantLock lock = new ReentrantLock();
  private final Condition changed = lock.newCondition();

  // All below under lock.
  private boolean armed;
  /** The ring: [windowBytes / blockBytes] direct buffers, null until written. */
  @Nullable private ByteBuffer[] blocks;
  /** Absolute positions: [base, availableEnd) is readable from the ring. */
  private long base;
  /** Everything before it is downloaded (segments from here on are in progress or claimed). */
  private long fetchPos;
  private long readPos;
  /** The next byte no connection has claimed yet. */
  private long nextClaim;
  private long maxClaimEnd;
  private long length = C.LENGTH_UNSET;
  private final TreeMap<Long, Segment> segments = new TreeMap<>();
  @Nullable private IOException failure;
  private int generation;
  private boolean running;
  @Nullable private DataSpec template;
  private final List<DataSource> openConnections = new ArrayList<>();
  /** Connections wanted now (1..maxConnections); learned once per movie, kept across seeks. */
  private int wanted = 1;
  private double neededMbps;
  private long sampleStartMs;
  private long sampleBytes;
  private boolean sampleWaited;
  private double lastMbps;
  /** After adding a connection: the count and speed before it, to judge the gain. */
  private int stepFrom = -1;
  private double stepFromMbps;
  private long noGainUntilMs;
  private int starts;
  @Nullable private String note;

  ReadAhead(@NonNull DataSource.Factory upstreamFactory, @Nullable Uri fileUri) {
    this(upstreamFactory, fileUri, new Tuning());
  }

  @VisibleForTesting
  ReadAhead(
      @NonNull DataSource.Factory upstreamFactory,
      @Nullable Uri fileUri,
      @NonNull Tuning tuning) {
    this.upstreamFactory = upstreamFactory;
    this.fileUri = fileUri;
    this.t = tuning;
  }

  /** Switches it on; null when on, else why not (for Send log). */
  @Nullable
  String arm() {
    lock.lock();
    try {
      if (armed) return null;
      if (fileUri == null) return "not a single file";
      String host = fileUri.getHost();
      if (host == null || host.equals("127.0.0.1") || host.equals("localhost")) {
        return "already on this device";
      }
      blocks = new ByteBuffer[(int) ((t.windowBytes + t.blockBytes - 1) / t.blockBytes)];
      armed = true;
      running = false;
      failure = null;
      wanted = 1;
      Log.i(TAG, "on, " + t.windowBytes / (1 << 20) + " MB in memory");
      return null;
    } finally {
      lock.unlock();
    }
  }

  /** The file's average bitrate (from Dart): a download slower than this gets more connections. */
  void setNeededMbps(double mbps) {
    lock.lock();
    try {
      neededMbps = mbps;
    } finally {
      lock.unlock();
    }
  }

  /** Off: stops the download and deletes the file (the player stopped or changed stream). */
  void release() {
    lock.lock();
    try {
      if (!armed) return;
      armed = false;
      stopWorkersLocked();
      blocks = null;
      changed.signalAll();
      Log.i(TAG, "off after " + Math.max(0, starts - 1) + " restarts");
    } finally {
      lock.unlock();
    }
  }

  boolean isArmed() {
    lock.lock();
    try {
      return armed;
    } finally {
      lock.unlock();
    }
  }

  /**
   * A reader opens at {@code spec.position}: true = it reads from the ring (downloaded or on its
   * way), false = read the source directly (off, another resource, or a short bounded probe
   * outside what is downloaded, e.g. an index at the end of the file).
   */
  boolean openReader(@NonNull DataSpec spec) {
    lock.lock();
    try {
      if (!armed || fileUri == null || !fileUri.equals(spec.uri)) return false;
      long p = spec.position;
      boolean covered = running && failure == null && p >= base
          && p <= availableEndLocked() + t.waitGapBytes
          && (length == C.LENGTH_UNSET || p <= length);
      if (!covered) {
        if (spec.length != C.LENGTH_UNSET) return false;
        restartLocked(spec, p, null);
      }
      readPos = p;
      changed.signalAll();
      return true;
    } finally {
      lock.unlock();
    }
  }

  /**
   * The reader's own open connection, positioned at {@code spec.position}, becomes the first
   * download connection (switched on mid-read: no reconnect). {@code total} = the resource's
   * length when known. False = not taken (the reader keeps it).
   */
  boolean adopt(@NonNull DataSpec spec, @NonNull DataSource connection, long total) {
    lock.lock();
    try {
      if (!armed || fileUri == null || !fileUri.equals(spec.uri)) return false;
      if (total != C.LENGTH_UNSET) length = total;
      restartLocked(spec, spec.position, connection);
      readPos = spec.position;
      return true;
    } finally {
      lock.unlock();
    }
  }

  /** The resource's total length once known, else {@link C#LENGTH_UNSET}. */
  long length() {
    lock.lock();
    try {
      return length;
    } finally {
      lock.unlock();
    }
  }

  /**
   * Reads up to {@code len} bytes at absolute {@code pos}, waiting for the download. Returns
   * {@link C#RESULT_END_OF_INPUT} at the end, {@link #STOPPED} when switched off meanwhile.
   */
  int read(long pos, @NonNull byte[] buffer, int offset, int len) throws IOException {
    long available;
    ByteBuffer[] ring;
    lock.lock();
    try {
      while (true) {
        if (!armed) return STOPPED;
        if (pos < base) throw new IOException("read-ahead: position " + pos + " already overwritten");
        long end = availableEndLocked();
        if (end > pos) {
          available = end - pos;
          break;
        }
        if (length != C.LENGTH_UNSET && pos >= length) return C.RESULT_END_OF_INPUT;
        if (failure != null) throw failure;
        if (!running) throw new IOException("read-ahead: not downloading");
        try {
          changed.await();
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
          throw new InterruptedIOException();
        }
      }
      readPos = pos;
      changed.signalAll();
      ring = blocks;
    } finally {
      lock.unlock();
    }
    if (ring == null) return STOPPED;
    long off = pos % t.windowBytes;
    int block = (int) (off / t.blockBytes);
    int at = (int) (off % t.blockBytes);
    int n = (int) Math.min(len, Math.min(available, t.blockBytes - at));
    ByteBuffer b = ring[block];
    if (b == null) throw new IOException("read-ahead: block never written");
    ByteBuffer view = b.duplicate();
    view.position(at);
    view.get(buffer, offset, n);
    lock.lock();
    try {
      readPos = pos + n;
      changed.signalAll();
    } finally {
      lock.unlock();
    }
    return n;
  }

  // --- Send log ---

  /** Bytes downloaded ahead of the reader (contiguous). */
  long bytesAhead() {
    lock.lock();
    try {
      return armed ? Math.max(0, availableEndLocked() - readPos) : 0;
    } finally {
      lock.unlock();
    }
  }

  long windowBytes() {
    return t.windowBytes;
  }

  int restarts() {
    lock.lock();
    try {
      return Math.max(0, starts - 1);
    } finally {
      lock.unlock();
    }
  }

  /** Connections downloading now (0 when off). */
  int connections() {
    lock.lock();
    try {
      return armed && running ? wanted : 0;
    } finally {
      lock.unlock();
    }
  }

  /** The last news ("45 Mbit/s, the file needs 80: adding connection 2", "HTTP 503, retry 1"). */
  @Nullable
  String note() {
    lock.lock();
    try {
      return note;
    } finally {
      lock.unlock();
    }
  }

  // --- The download ---

  private long availableEndLocked() {
    Segment s = segments.get(fetchPos);
    return s == null ? fetchPos : s.start + s.filled;
  }

  private void restartLocked(@NonNull DataSpec spec, long position, @Nullable DataSource adopted) {
    stopWorkersLocked();
    starts++;
    final int gen = generation;
    base = fetchPos = readPos = nextClaim = maxClaimEnd = position;
    segments.clear();
    failure = null;
    running = true;
    template = spec.buildUpon().setLength(C.LENGTH_UNSET).build();
    sampleStartMs = 0;
    sampleBytes = 0;
    sampleWaited = false;
    stepFrom = -1;
    for (int i = 0; i < wanted; i++) {
      startWorkerLocked(gen, i, i == 0 ? adopted : null, position);
    }
    if (adopted != null && wanted == 0) closeLater(adopted);
  }

  private void startWorkerLocked(int gen, int index, @Nullable DataSource adopted, long at) {
    if (adopted != null) openConnections.add(adopted);
    Thread thread = new Thread(() -> workerLoop(gen, index, adopted, at),
        "VesperReadAhead-" + (index + 1));
    thread.setDaemon(true);
    thread.start();
  }

  private void stopWorkersLocked() {
    generation++;
    running = false;
    for (DataSource connection : openConnections) closeLater(connection);
    openConnections.clear();
    changed.signalAll();
  }

  /** Ends a read blocked on the network (that worker exits on its next check). */
  private static void closeLater(@NonNull DataSource connection) {
    Thread closer = new Thread(() -> closeQuietly(connection), "VesperReadAheadClose");
    closer.setDaemon(true);
    closer.start();
  }

  private void workerLoop(int gen, int index, @Nullable DataSource adopted, long adoptedAt) {
    byte[] buf = new byte[CHUNK];
    DataSource conn = adopted;
    long connPos = adopted == null ? -1 : adoptedAt;
    Segment seg = null;
    int failures = 0;
    try {
      while (true) {
        try {
          if (seg == null) {
            seg = claim(gen, index);
            if (seg == null) return;
          }
          long want = seg.start + seg.filled;
          if (conn == null || connPos != want) {
            if (conn != null) forget(conn);
            DataSource fresh = upstreamFactory.createDataSource();
            DataSpec spec;
            lock.lock();
            try {
              if (gen != generation || template == null) return;
              openConnections.add(fresh);
              spec = template;
            } finally {
              lock.unlock();
            }
            conn = fresh;
            long opened = conn.open(spec.buildUpon().setPosition(want).build());
            connPos = want;
            lock.lock();
            try {
              if (gen != generation) return;
              if (opened != C.LENGTH_UNSET && length == C.LENGTH_UNSET) length = want + opened;
            } finally {
              lock.unlock();
            }
          }
          while (true) {
            long at = seg.start + seg.filled;
            int max;
            lock.lock();
            try {
              if (gen != generation) return;
              if (at >= seg.end) break;
              max = (int) Math.min(CHUNK, seg.end - at);
            } finally {
              lock.unlock();
            }
            int r = conn.read(buf, 0, max);
            lock.lock();
            try {
              if (gen != generation) return;
              if (r == C.RESULT_END_OF_INPUT) {
                endOfFileLocked(seg, at);
                changed.signalAll();
                break;
              }
              writeLocked(at, buf, r);
              seg.filled += r;
              connPos += r;
              failures = 0;
              countLocked(r);
              advanceLocked();
              changed.signalAll();
            } finally {
              lock.unlock();
            }
          }
          seg = null;
        } catch (IOException e) {
          lock.lock();
          try {
            if (gen != generation) return;
            if (conn != null) {
              openConnections.remove(conn);
              closeLater(conn);
              conn = null;
            }
            boolean gone = isGone(e);
            if (gone || failures >= t.retryDelaysMs.length) {
              failure = e;
              noteLocked(reasonOf(e) + (gone ? "" : ", gave up after " + failures + " retries"));
              changed.signalAll();
              return;
            }
            long wait = t.retryDelaysMs[failures++];
            noteLocked(reasonOf(e) + ", retry " + failures + " in " + wait / 1000 + " s");
            // Woken early by a restart or release.
            changed.await(wait, TimeUnit.MILLISECONDS);
            if (gen != generation) return;
          } finally {
            lock.unlock();
          }
        }
      }
    } catch (InterruptedException e) {
      // Stopped.
    } finally {
      if (conn != null) forget(conn);
    }
  }

  /** The next segment for worker [index], waiting for room; null = this worker is done. */
  @Nullable
  private Segment claim(int gen, int index) throws InterruptedException {
    lock.lock();
    try {
      while (true) {
        if (gen != generation || index >= wanted) return null;
        if (length != C.LENGTH_UNSET && nextClaim >= length) return null;
        // Never past the window: that would overwrite what the reader still needs.
        long room = readPos - t.keepBehindBytes + t.windowBytes - nextClaim;
        long size = Math.min(t.segmentBytes, room);
        boolean tail = length != C.LENGTH_UNSET && size >= length - nextClaim;
        if (tail) size = length - nextClaim;
        if (size > 0 && (size == t.segmentBytes || tail)) {
          Segment s = new Segment(nextClaim, nextClaim + size);
          segments.put(s.start, s);
          nextClaim = s.end;
          maxClaimEnd = Math.max(maxClaimEnd, s.end);
          base = Math.max(base, maxClaimEnd - t.windowBytes);
          return s;
        }
        sampleWaited = true;
        changed.await();
      }
    } finally {
      lock.unlock();
    }
  }

  /** The file ends at [at] (shorter than said, or no length given). */
  private void endOfFileLocked(@NonNull Segment seg, long at) {
    length = at;
    seg.end = at;
    nextClaim = Math.min(nextClaim, at);
    segments.tailMap(at, true).clear();
    if (seg.end <= seg.start) segments.remove(seg.start);
    advanceLocked();
  }

  /** Moves [fetchPos] over every finished segment. */
  private void advanceLocked() {
    while (true) {
      Segment s = segments.get(fetchPos);
      if (s == null || !s.done()) return;
      segments.remove(fetchPos);
      fetchPos = s.end;
    }
  }

  /** Speed samples; adds a connection while slower than the file, drops one that didn't help. */
  private void countLocked(int bytes) {
    long now = System.nanoTime() / 1_000_000;
    if (sampleStartMs == 0) {
      sampleStartMs = now;
      sampleBytes = 0;
      sampleWaited = false;
    }
    sampleBytes += bytes;
    long ms = now - sampleStartMs;
    if (ms < t.sampleMs) return;
    double mbps = sampleBytes * 8.0 / ms / 1000;
    boolean waited = sampleWaited;
    sampleStartMs = now;
    sampleBytes = 0;
    sampleWaited = false;
    lastMbps = mbps;
    // Held back by the window (far enough ahead): the speed says nothing.
    if (waited) return;
    if (stepFrom >= 0) {
      if (mbps < stepFromMbps * 1.15) {
        noteLocked(String.format(Locale.US,
            "%d connections: %.0f Mbit/s, no gain over %.0f, back to %d",
            wanted, mbps, stepFromMbps, stepFrom));
        wanted = stepFrom;
        noGainUntilMs = now + t.noGainPauseMs;
        changed.signalAll();
      } else {
        noteLocked(String.format(Locale.US, "%d connections: %.0f Mbit/s (1 less: %.0f)",
            wanted, mbps, stepFromMbps));
      }
      stepFrom = -1;
      return;
    }
    if (neededMbps > 0 && mbps < neededMbps * 1.05 && wanted < t.maxConnections
        && length != C.LENGTH_UNSET && now >= noGainUntilMs
        && availableEndLocked() - readPos < t.windowBytes / 2) {
      stepFrom = wanted;
      stepFromMbps = mbps;
      wanted++;
      noteLocked(String.format(Locale.US, "%.0f Mbit/s, the file needs %.0f: adding connection %d",
          mbps, neededMbps, wanted));
      startWorkerLocked(generation, wanted - 1, null, 0);
    }
  }

  private void noteLocked(@NonNull String what) {
    note = what;
    Log.i(TAG, what);
  }

  private void forget(@NonNull DataSource connection) {
    lock.lock();
    try {
      openConnections.remove(connection);
    } finally {
      lock.unlock();
    }
    closeQuietly(connection);
  }

  private void writeLocked(long pos, @NonNull byte[] buf, int len) throws IOException {
    ByteBuffer[] ring = blocks;
    if (ring == null) throw new IOException("read-ahead: stopped");
    int done = 0;
    while (done < len) {
      long off = (pos + done) % t.windowBytes;
      int block = (int) (off / t.blockBytes);
      int at = (int) (off % t.blockBytes);
      int part = Math.min(len - done, t.blockBytes - at);
      ByteBuffer b = ring[block];
      if (b == null) b = ring[block] = ByteBuffer.allocateDirect(t.blockBytes);
      ByteBuffer view = b.duplicate();
      view.position(at);
      view.put(buf, done, part);
      done += part;
    }
  }

  private static boolean isGone(@NonNull IOException e) {
    if (!(e instanceof HttpDataSource.InvalidResponseCodeException)) return false;
    int code = ((HttpDataSource.InvalidResponseCodeException) e).responseCode;
    return code == 404 || code == 410 || code == 416;
  }

  @NonNull
  private static String reasonOf(@NonNull IOException e) {
    if (e instanceof HttpDataSource.InvalidResponseCodeException) {
      return "HTTP " + ((HttpDataSource.InvalidResponseCodeException) e).responseCode;
    }
    Throwable cause = e.getCause() != null ? e.getCause() : e;
    return cause.getClass().getSimpleName();
  }

  private static void closeQuietly(@NonNull DataSource source) {
    try {
      source.close();
    } catch (Throwable ignored) {
      // Already closed, or closed by the other thread.
    }
  }
}
