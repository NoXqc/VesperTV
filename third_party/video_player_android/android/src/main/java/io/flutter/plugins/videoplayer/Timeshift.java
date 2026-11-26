// VesperTV patch: live pause and rewind on the player's one connection (owner + cillfog on
// Discord, 2026-11-25: "live pause for channels without catch-up, without a second connection").
//
// The app becomes the only reader of a live MPEG-TS stream: a writer thread reads the provider's
// connection all the time and appends it to a rolling copy (16 MB files in the app's cache, or
// 2 MB blocks in memory when storage is short); the player reads that copy
// (TimeshiftDataSource). Pausing stops the player, not the download, so the connection never
// stalls and Play carries on from the paused frame. An index (time from the stream's PCR,
// keyframes from the random-access flag on the PCR PID) turns "N seconds back" into a byte
// offset: a jump sets that offset and reopens the player's load there (VideoPlayer
// .timeshiftJump). Oldest data is dropped past the window (Settings, minutes) or the storage cap.
//
// A dropped connection (server close or read error) is reopened by the writer and the new bytes
// follow the old ones; TsSplice keeps the timestamps continuous and follows a new program, as for
// a Tuliprox source switch. Only for the main player's live streams (Dart arms it per channel).
package io.flutter.plugins.videoplayer;

import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.annotation.VisibleForTesting;
import androidx.media3.common.C;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DataSpec;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InterruptedIOException;
import java.io.RandomAccessFile;
import java.net.SocketTimeoutException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@OptIn(markerClass = UnstableApi.class)
final class Timeshift {
  static final String TAG = "VesperTimeshift";
  /** {@link #read}: switched off or released; the reader goes back to the network. */
  static final int STOPPED = -2;

  static final int DISK_CHUNK = 16 * 1024 * 1024;
  static final int MEMORY_CHUNK = 2 * 1024 * 1024;
  /** Left free on the box's storage (the system and other apps need it). */
  static final long DISK_RESERVE = 1024L * 1024 * 1024;
  /** At most this much of a stream on storage (60 min of a 13 Mbit/s channel). */
  static final long MAX_DISK = 6L * 1024 * 1024 * 1024;
  /** Under this much room on storage: memory only. */
  static final long MIN_DISK = 256L * 1024 * 1024;
  /** Memory only: ~30 s of an 8 Mbit/s channel (a replay, a short pause). */
  static final long MEMORY_CAP = 32L * 1024 * 1024;
  /** A reader waits this long for new bytes before failing (the writer reconnects first). */
  static final long READ_WAIT_MS = 40_000;
  /** No new byte for this long: the connection counts as stuck (a new copy reopens it). */
  static final long STALL_MS = 5_000;
  /** "Back to live" starts this far behind the newest byte, at a keyframe. */
  static final long LIVE_START_BEHIND_US = 1_000_000;
  /** A jump that lands closer than this to the newest byte is "back to live". */
  static final long LIVE_EDGE_US = 3_000_000;

  private static final Set<File> activeDirs = new HashSet<>();
  private static boolean cleaned;
  private static final java.util.concurrent.atomic.AtomicInteger nextId =
      new java.util.concurrent.atomic.AtomicInteger();

  private final File root;
  private final DataSource.Factory upstreamFactory;
  @Nullable private final StreamStats stats;
  private final Object lock = new Object();
  /** Tests: the clock (ms) and storage room. */
  @VisibleForTesting Clock clock = System::currentTimeMillis;
  @VisibleForTesting long usableOverride = -1;

  interface Clock {
    long nowMs();
  }

  // ---------------------------------------------------------------- state (under lock)
  private volatile boolean armed;
  private volatile boolean released;
  /**
   * Released because the player moves on (a channel change, a movie, closing), not switched off:
   * the reading load is about to be cancelled, so it waits for that instead of reconnecting.
   */
  private boolean leaving;

  /**
   * How long a load of a copy released by [release] waits for its cancel before it reconnects
   * anyway (the old behaviour).
   */
  @VisibleForTesting long leaveWaitMs = 3_000;
  private long windowUs;
  private long capBytes;
  private boolean memoryOnly;
  private boolean diskFailed;
  @Nullable private File dir;

  private final ArrayList<Chunk> chunks = new ArrayList<>();
  /** The block being written (the newest), kept open. */
  @Nullable private FileChannel writeChannel;
  @Nullable private File writeFile;
  private long tail;
  private long head;
  private long sinceSpaceCheck;

  @Nullable private Thread writer;
  private int writerGen;
  @Nullable private DataSource writerSource;
  @Nullable private DataSpec liveSpec;
  @Nullable private IOException failure;
  private long lastWriteMs;
  private boolean started;
  private Map<String, List<String>> headers = Collections.emptyMap();

  /** Newest byte handed to the player (the next one it reads). */
  private long readerPos;
  private long pendingStart = -1;

  final TsIndex index = new TsIndex();
  private int reconnects;
  private int trims;
  @Nullable private String note;

  private static final class Chunk {
    final long start;
    int len;
    @Nullable final byte[] mem;
    @Nullable final File file;

    Chunk(long start, @Nullable byte[] mem, @Nullable File file) {
      this.start = start;
      this.mem = mem;
      this.file = file;
    }

    int capacity() {
      return mem != null ? mem.length : DISK_CHUNK;
    }
  }

  /** One reader's place in the copy (and its open file). */
  static final class Cursor {
    long pos;
    @Nullable private File openFile;
    @Nullable private FileChannel channel;

    Cursor(long pos) {
      this.pos = pos;
    }

    FileChannel channelFor(File f) throws IOException {
      if (f.equals(openFile) && channel != null) return channel;
      close();
      channel = new RandomAccessFile(f, "r").getChannel();
      openFile = f;
      return channel;
    }

    void close() {
      FileChannel c = channel;
      channel = null;
      openFile = null;
      if (c != null) {
        try {
          c.close();
        } catch (IOException ignored) {
          // Closing a read-only file.
        }
      }
    }
  }

  Timeshift(@NonNull File cacheDir, @NonNull DataSource.Factory upstreamFactory,
      @Nullable StreamStats stats) {
    this.root = new File(cacheDir, "timeshift");
    this.upstreamFactory = upstreamFactory;
    this.stats = stats;
  }

  // ---------------------------------------------------------------- arming

  /**
   * Switches the rolling copy on for this stream, keeping [minutes] at most. Null when on, else
   * why not. The copy starts at the player's next read (its connection becomes the writer's).
   */
  @Nullable
  String arm(int minutes) {
    synchronized (lock) {
      if (released) return "released";
      if (minutes <= 0) return "off";
      windowUs = minutes * 60L * 1_000_000L;
      if (armed) return null;
      cleanOldRings();
      long usable = usable();
      long room = usable - DISK_RESERVE;
      if (room >= MIN_DISK) {
        memoryOnly = false;
        capBytes = Math.min(MAX_DISK, room);
        File d = new File(root, "ring-" + nextId.incrementAndGet() + "-" + clock.nowMs());
        if (!d.mkdirs() && !d.isDirectory()) {
          memoryOnly = true;
        } else {
          dir = d;
          synchronized (activeDirs) {
            activeDirs.add(d);
          }
        }
      } else {
        memoryOnly = true;
      }
      if (memoryOnly) {
        capBytes = Math.min(MEMORY_CAP, Runtime.getRuntime().maxMemory() / 8);
        note = "memory only (" + (usable / (1024 * 1024)) + " MB free on storage)";
      }
      armed = true;
      Log.i(TAG, String.format(Locale.ROOT, "on: %d min, %s, cap %d MB", minutes,
          memoryOnly ? "memory" : "storage", capBytes / (1024 * 1024)));
      return null;
    }
  }

  boolean isArmed() {
    return armed && !released;
  }

  /** Armed and holding the stream (the player reads the copy). */
  boolean isActive() {
    synchronized (lock) {
      return armed && !released && started;
    }
  }

  private long usable() {
    if (usableOverride >= 0) return usableOverride;
    File probe = root.getParentFile() != null ? root.getParentFile() : root;
    return probe.getUsableSpace();
  }

  /** Rings left by an earlier run (killed app): deleted once per process. */
  private void cleanOldRings() {
    synchronized (activeDirs) {
      if (cleaned) return;
      cleaned = true;
      File[] old = root.listFiles();
      if (old == null) return;
      for (File f : old) {
        if (!activeDirs.contains(f)) deleteDir(f);
      }
    }
  }

  private static void deleteDir(File d) {
    File[] files = d.listFiles();
    if (files != null) {
      for (File f : files) {
        //noinspection ResultOfMethodCallIgnored
        f.delete();
      }
    }
    //noinspection ResultOfMethodCallIgnored
    d.delete();
  }

  // ---------------------------------------------------------------- writer

  /**
   * The player's open connection becomes the writer's (no reconnect); the reader goes on at the
   * copy's newest byte. [spec] reopens the stream from "now" after a drop.
   */
  Cursor adopt(@NonNull DataSource source, @NonNull DataSpec spec,
      @NonNull Map<String, List<String>> responseHeaders) {
    synchronized (lock) {
      liveSpec = spec.buildUpon().setPosition(0).setLength(C.LENGTH_UNSET).build();
      headers = responseHeaders;
      started = true;
      startWriter(source);
      readerPos = head;
      return new Cursor(head);
    }
  }

  /** Under lock: a writer thread for [source] (an open connection). */
  private void startWriter(@NonNull DataSource source) {
    final int gen = ++writerGen;
    writerSource = source;
    failure = null;
    lastWriteMs = clock.nowMs();
    index.resync();
    Thread t = new Thread(() -> writeLoop(gen, source), "vesper-timeshift");
    t.setDaemon(true);
    writer = t;
    t.start();
  }

  /** A new connection from "now" (blocking open on the caller's thread), then its writer. */
  private void restartWriter(@NonNull String why) throws IOException {
    DataSource old;
    DataSpec spec;
    synchronized (lock) {
      old = writerSource;
      writerSource = null;
      writerGen++;
      writer = null;
      spec = liveSpec;
    }
    if (old != null) closeQuietly(old);
    if (spec == null) throw new IOException("timeshift: no stream to reopen");
    Log.i(TAG, "reopening the stream (" + why + ")");
    DataSource fresh = upstreamFactory.createDataSource();
    try {
      fresh.open(spec);
    } catch (IOException e) {
      closeQuietly(fresh);
      synchronized (lock) {
        failure = e;
        lock.notifyAll();
      }
      throw e;
    }
    synchronized (lock) {
      if (released) {
        closeQuietly(fresh);
        throw new IOException("timeshift released");
      }
      reconnects++;
      headers = fresh.getResponseHeaders();
      startWriter(fresh);
    }
  }

  /**
   * The writer thread. Nothing may escape it: an uncaught exception on any thread ends the app
   * (cillfog, OnePlus CPH2449, LOG-PESV4J, 2026-11-26: "crash (java)" on every channel change with
   * the copy on). Anything unexpected counts as a connection that failed for good: the reader's
   * next load reopens it ([openReader] -> [restartWriter]).
   */
  private void writeLoop(int gen, DataSource first) {
    try {
      writeLoopUnguarded(gen, first);
    } catch (Throwable t) {
      Log.e(TAG, "writer stopped", t);
      synchronized (lock) {
        if (!released && gen == writerGen) {
          failure = t instanceof IOException ? (IOException) t : new IOException(t);
          writerSource = null;
          writer = null;
          note = "writer stopped: " + t.getClass().getSimpleName();
          lock.notifyAll();
        }
      }
    }
  }

  private void writeLoopUnguarded(int gen, DataSource first) {
    byte[] buf = new byte[64 * 1024];
    DataSource source = first;
    while (true) {
      int n;
      IOException error = null;
      try {
        n = source.read(buf, 0, buf.length);
      } catch (IOException e) {
        n = 0;
        error = e;
      } catch (RuntimeException e) {
        // release() / restartWriter() close this connection from another thread to unblock a
        // waiting read; media3's DefaultHttpDataSource nulls its stream there, so a read that
        // starts just after throws a NullPointerException, not an IOException.
        n = 0;
        error = new IOException("read failed: " + e, e);
      }
      synchronized (lock) {
        if (released || gen != writerGen) {
          closeQuietly(source);
          return;
        }
        if (n > 0) {
          append(buf, n);
          continue;
        }
        if (n == 0 && error == null) continue;
      }
      // The server closed the stream or the read failed: reopen from "now" (LiveReconnect's
      // retries), the new bytes follow the old ones.
      closeQuietly(source);
      String why = error == null ? "server closed" : "connection lost (" + reasonOf(error) + ")";
      Log.w(TAG, why + ", reopening");
      if (stats != null) stats.lastReconnect = "timeshift: " + why;
      if (error instanceof InterruptedIOException) {
        synchronized (lock) {
          if (released || gen != writerGen) return;
        }
      }
      try {
        Thread.sleep(error == null ? 200 : 1000);
      } catch (InterruptedException e) {
        return;
      }
      DataSpec spec;
      synchronized (lock) {
        if (released || gen != writerGen) return;
        spec = liveSpec;
      }
      DataSource fresh = upstreamFactory.createDataSource();
      try {
        if (spec == null) throw new IOException("no stream to reopen");
        fresh.open(spec);
      } catch (IOException e) {
        closeQuietly(fresh);
        synchronized (lock) {
          if (gen == writerGen) {
            failure = e;
            writerSource = null;
            writer = null;
            note = "reopen failed: " + reasonOf(e);
            lock.notifyAll();
          }
        }
        Log.w(TAG, "reopen failed: " + reasonOf(e));
        return;
      }
      synchronized (lock) {
        if (released || gen != writerGen) {
          closeQuietly(fresh);
          return;
        }
        writerSource = fresh;
        headers = fresh.getResponseHeaders();
        reconnects++;
        index.resync();
      }
      source = fresh;
    }
  }

  /** Under lock: [n] new bytes at the head. */
  private void append(byte[] buf, int n) {
    long now = clock.nowMs();
    index.feed(buf, 0, n, head, now);
    int done = 0;
    while (done < n) {
      Chunk c = chunks.isEmpty() ? null : chunks.get(chunks.size() - 1);
      if (c == null || c.len >= c.capacity()) c = newChunk();
      int k = Math.min(n - done, c.capacity() - c.len);
      if (!writeChunk(c, buf, done, k)) {
        // Storage refused (full): this block goes to memory and so does the rest.
        c = newChunk();
        k = Math.min(n - done, c.capacity() - c.len);
        writeChunk(c, buf, done, k);
      }
      c.len += k;
      head += k;
      done += k;
    }
    lastWriteMs = now;
    sinceSpaceCheck += n;
    if (!memoryOnly && !diskFailed && sinceSpaceCheck >= 64L * 1024 * 1024) {
      sinceSpaceCheck = 0;
      // Other apps fill the storage too: never take its last gigabyte.
      long room = usable() - DISK_RESERVE;
      if (room < 0) capBytes = Math.max(DISK_CHUNK, head - tail + room);
    }
    trim();
    lock.notifyAll();
  }

  private Chunk newChunk() {
    Chunk c;
    File d = dir;
    if (memoryOnly || diskFailed || d == null) {
      c = new Chunk(head, new byte[MEMORY_CHUNK], null);
    } else {
      c = new Chunk(head, null, new File(d, head + ".ts"));
    }
    chunks.add(c);
    return c;
  }

  private boolean writeChunk(Chunk c, byte[] buf, int off, int k) {
    if (c.mem != null) {
      System.arraycopy(buf, off, c.mem, c.len, k);
      return true;
    }
    File f = c.file;
    try {
      FileChannel ch = writeChannel;
      if (ch == null || !f.equals(writeFile)) {
        closeWriteChannel();
        ch = new RandomAccessFile(f, "rw").getChannel();
        writeChannel = ch;
        writeFile = f;
      }
      ByteBuffer bb = ByteBuffer.wrap(buf, off, k);
      long p = c.len;
      while (bb.hasRemaining()) p += ch.write(bb, p);
      return true;
    } catch (IOException e) {
      Log.w(TAG, "storage write failed, memory from now on: " + e);
      closeWriteChannel();
      diskFailed = true;
      note = "storage full: memory only";
      capBytes = Math.min(capBytes, head - tail + MEMORY_CAP);
      if (c.len == 0) {
        chunks.remove(c);
        //noinspection ResultOfMethodCallIgnored
        f.delete();
      }
      return false;
    }
  }

  /** Under lock. */
  private void closeWriteChannel() {
    FileChannel ch = writeChannel;
    writeChannel = null;
    writeFile = null;
    if (ch != null) {
      try {
        ch.close();
      } catch (IOException ignored) {
        // Already gone.
      }
    }
  }

  /** Under lock: drops the oldest blocks past the window or the byte cap. */
  private void trim() {
    long newest = index.newestUs();
    while (chunks.size() > 1) {
      Chunk first = chunks.get(0);
      long end = first.start + first.len;
      boolean overBytes = head - tail > capBytes;
      long endUs = index.timeAt(end);
      boolean tooOld = newest != C.TIME_UNSET && endUs != C.TIME_UNSET
          && newest - endUs > windowUs;
      if (!overBytes && !tooOld) break;
      chunks.remove(0);
      if (first.file != null) {
        //noinspection ResultOfMethodCallIgnored
        first.file.delete();
      }
      tail = end;
      trims++;
    }
    index.dropBefore(tail);
  }

  // ---------------------------------------------------------------- reading

  /**
   * Where a player load reading the copy starts: [loadablePosition] 0 = a new load (a jump's
   * offset, else where the last load stopped; a stuck connection is reopened first), more = the
   * same load reopened after an error ([base] + position).
   */
  Cursor openReader(long loadablePosition, long base) throws IOException {
    boolean restart = false;
    String why = null;
    synchronized (lock) {
      if (released || !armed) throw new IOException("timeshift off");
      if (writer == null) {
        restart = true;
        why = failure == null ? "no connection" : "after " + reasonOf(failure);
      } else if (loadablePosition == 0 && pendingStart < 0
          && clock.nowMs() - lastWriteMs > STALL_MS && readerPos >= head) {
        restart = true;
        why = "no data for " + (clock.nowMs() - lastWriteMs) / 1000 + " s";
      }
    }
    if (restart) restartWriter(why);
    synchronized (lock) {
      long start;
      if (loadablePosition == 0) {
        if (pendingStart >= 0) {
          start = pendingStart;
          pendingStart = -1;
        } else {
          start = readerPos;
        }
      } else {
        start = base + loadablePosition;
      }
      if (start > head) start = head;
      if (start < tail) start = index.startAtOrAfter(tail);
      readerPos = start;
      return new Cursor(start);
    }
  }

  /** Bytes at the cursor, waiting for the writer at the head; END never (a drop reopens). */
  int read(Cursor c, byte[] buffer, int offset, int length) throws IOException {
    if (length == 0) return 0;
    while (true) {
      Chunk chunk;
      int inChunk;
      int avail;
      synchronized (lock) {
        long deadline = 0;
        long leaveDeadline = 0;
        while (true) {
          if (released || !armed) {
            if (!leaving) return STOPPED;
            // The player is moving on and cancels this load (an interrupt). Reconnecting here
            // reopened the OLD channel while the new one opened: two connections at once, and
            // with Dispatcharr in Redirect mode both go straight to the provider (cillfog,
            // 2026-11-26). After [leaveWaitMs] without a cancel: the network, as before.
            long now = clock.nowMs();
            if (leaveDeadline == 0) leaveDeadline = now + leaveWaitMs;
            if (now >= leaveDeadline) return STOPPED;
            try {
              lock.wait(Math.min(250, leaveDeadline - now));
            } catch (InterruptedException e) {
              Thread.currentThread().interrupt();
              throw new InterruptedIOException();
            }
            continue;
          }
          if (c.pos < tail) {
            long to = index.startAtOrAfter(tail);
            Log.i(TAG, "paused past the window: on from the oldest part kept");
            c.pos = Math.max(to, tail);
          }
          if (c.pos < head) break;
          if (writer == null && failure != null) {
            throw new IOException("timeshift: " + reasonOf(failure), failure);
          }
          long now = clock.nowMs();
          if (deadline == 0) deadline = now + READ_WAIT_MS;
          if (now >= deadline) {
            throw new SocketTimeoutException(
                "timeshift: no data for " + READ_WAIT_MS / 1000 + " s");
          }
          try {
            lock.wait(Math.min(250, deadline - now));
          } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new InterruptedIOException();
          }
        }
        chunk = chunkAt(c.pos);
        inChunk = (int) (c.pos - chunk.start);
        avail = (int) Math.min(length, Math.min(chunk.len - inChunk, head - c.pos));
      }
      int n;
      if (chunk.mem != null) {
        System.arraycopy(chunk.mem, inChunk, buffer, offset, avail);
        n = avail;
      } else {
        try {
          n = c.channelFor(chunk.file).read(ByteBuffer.wrap(buffer, offset, avail), inChunk);
        } catch (FileNotFoundException gone) {
          c.close();
          lostFile(chunk);
          continue;
        }
      }
      if (n <= 0) continue;
      c.pos += n;
      synchronized (lock) {
        readerPos = c.pos;
      }
      return n;
    }
  }

  /**
   * A block's file is missing: dropped from the window meanwhile (the next pass moves on to the
   * oldest part kept), or the system cleared the app's cache (storage low): everything up to it
   * goes and the rest is kept in memory.
   */
  private void lostFile(Chunk chunk) {
    synchronized (lock) {
      int at = chunks.indexOf(chunk);
      if (at < 0) return;
      Log.w(TAG, "a storage block disappeared: memory only from now on");
      diskFailed = true;
      note = "cache cleared: memory only";
      capBytes = Math.min(capBytes, MEMORY_CAP);
      for (int i = 0; i <= at; i++) {
        Chunk gone = chunks.remove(0);
        if (gone.file != null && gone.file.equals(writeFile)) closeWriteChannel();
        tail = gone.start + gone.len;
      }
      index.dropBefore(tail);
    }
  }

  /** Under lock: the block holding [pos] (tail <= pos < head). */
  private Chunk chunkAt(long pos) {
    int lo = 0;
    int hi = chunks.size() - 1;
    while (lo < hi) {
      int mid = (lo + hi + 1) >>> 1;
      if (chunks.get(mid).start <= pos) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return chunks.get(lo);
  }

  Map<String, List<String>> responseHeaders() {
    synchronized (lock) {
      return headers;
    }
  }

  // ---------------------------------------------------------------- jumps and state

  /**
   * Moves what the player shows by [deltaMs] (negative = back; past the newest byte = live).
   * [bufferedMs] = what the player holds ahead of the picture. Sets the next load's start and
   * returns how far behind live it lands (ms), or -1 when there is nothing to jump in.
   */
  long jump(long deltaMs, long bufferedMs) {
    synchronized (lock) {
      if (!armed || released || !started || index.isEmpty()) return -1;
      long newest = index.newestUs();
      long oldest = index.timeAt(index.startAtOrAfter(tail));
      long shown = shownUs(bufferedMs);
      long target = shown + deltaMs * 1000;
      if (target >= newest - LIVE_EDGE_US) target = newest - LIVE_START_BEHIND_US;
      if (target < oldest) target = oldest;
      long start = index.startFor(target, tail);
      pendingStart = start;
      readerPos = start;
      long landed = index.timeAt(start);
      Log.i(TAG, String.format(Locale.ROOT, "jump %+.1f s: %.1f s behind live",
          deltaMs / 1000.0, (newest - landed) / 1e6));
      return Math.max(0, (newest - landed) / 1000);
    }
  }

  /** Under lock: the stream time on screen. */
  private long shownUs(long bufferedMs) {
    long at = index.timeAt(readerPos);
    if (at == C.TIME_UNSET) at = index.newestUs();
    return at - Math.max(0, bufferedMs) * 1000;
  }

  /** For Dart: on, how far behind live the picture is, how much can be rewound. */
  Map<String, Object> state(long bufferedMs) {
    java.util.HashMap<String, Object> m = new java.util.HashMap<>();
    synchronized (lock) {
      boolean on = armed && !released && started && !index.isEmpty();
      m.put("on", on);
      m.put("armed", armed && !released);
      if (note != null) m.put("note", note);
      m.put("memory", memoryOnly || diskFailed);
      if (!on) return m;
      long newest = index.newestUs();
      long oldest = index.timeAt(index.startAtOrAfter(tail));
      long shown = Math.max(oldest, shownUs(bufferedMs));
      m.put("behindMs", Math.max(0, (newest - shown) / 1000));
      m.put("availableMs", Math.max(0, (newest - oldest) / 1000));
      m.put("windowMs", windowUs / 1000);
      m.put("storedMb", (head - tail) / (1024 * 1024));
      m.put("reconnects", reconnects);
      m.put("connected", writer != null);
      m.put("keyframes", index.keyframes());
    }
    return m;
  }

  /**
   * The player moves on (a channel change, a movie, closing): the writer stops, its connection
   * closes, the files go; a load still reading the copy waits for its cancel ([leaving]).
   */
  void release() {
    release(true);
  }

  /** Switched off while the channel plays: as [release], and the player's load goes back to the network. */
  void switchOff() {
    release(false);
  }

  private void release(boolean leaving) {
    DataSource source;
    File d;
    synchronized (lock) {
      if (released) return;
      released = true;
      this.leaving = leaving;
      armed = false;
      writerGen++;
      source = writerSource;
      writerSource = null;
      writer = null;
      d = dir;
      dir = null;
      chunks.clear();
      closeWriteChannel();
      lock.notifyAll();
    }
    // Closing a connection may touch the network: not on the caller's (main) thread.
    final DataSource close = source;
    final File drop = d;
    Thread t = new Thread(() -> {
      try {
        if (close != null) closeQuietly(close);
        if (drop != null) {
          deleteDir(drop);
          synchronized (activeDirs) {
            activeDirs.remove(drop);
          }
        }
      } catch (RuntimeException e) {
        // Never end the app over a cleanup (see writeLoop).
        Log.w(TAG, "release cleanup: " + e);
      }
    }, "vesper-timeshift-release");
    t.setDaemon(true);
    t.start();
  }

  boolean isReleased() {
    synchronized (lock) {
      return released;
    }
  }

  @VisibleForTesting
  long head() {
    synchronized (lock) {
      return head;
    }
  }

  @VisibleForTesting
  long tail() {
    synchronized (lock) {
      return tail;
    }
  }

  @VisibleForTesting
  boolean memoryOnly() {
    synchronized (lock) {
      return memoryOnly || diskFailed;
    }
  }

  @VisibleForTesting
  void appendForTest(byte[] buf, int n) {
    synchronized (lock) {
      started = true;
      append(buf, n);
    }
  }

  @VisibleForTesting
  long readerPos() {
    synchronized (lock) {
      return readerPos;
    }
  }

  private static void closeQuietly(@Nullable DataSource s) {
    if (s == null) return;
    try {
      s.close();
    } catch (IOException | RuntimeException ignored) {
      // Closing a dead connection (or one another thread is closing / reading).
    }
  }

  @NonNull
  static String reasonOf(@Nullable IOException e) {
    if (e == null) return "?";
    Throwable cause = e.getCause() != null ? e.getCause() : e;
    String m = e.getMessage();
    return cause.getClass().getSimpleName() + (m == null ? "" : ": " + m);
  }

  // ---------------------------------------------------------------- index

  /**
   * Byte offset -> stream time. Time comes from the PCR (on the first PID carrying one; a jump or
   * a gap counts as the wall-clock time between the two, so a source switch doesn't break it),
   * or from the wall clock when the stream has no PCR. An entry every 200 ms of stream time, and
   * one at each keyframe (random-access flag at a packet that starts a PES on the PCR PID).
   */
  static final class TsIndex {
    private static final int TS = 188;
    private static final long EVERY_US = 200_000;
    private static final long MAX_STEP_US = 3_000_000;
    private static final long NO_PCR_AFTER_MS = 3_000;

    private long[] offs = new long[1024];
    private long[] times = new long[1024];
    private boolean[] keys = new boolean[1024];
    private int first;
    private int count;
    private int keyCount;

    private final byte[] pkt = new byte[TS];
    private int fill;
    private long pktStart;

    private int pcrPid = -1;
    private long lastPcr = -1;
    private long lastPcrMs;
    private long mediaUs;
    private long lastEntryUs = Long.MIN_VALUE;
    private boolean sawPcr;
    private long startMs = -1;

    boolean isEmpty() {
      return count == 0;
    }

    int keyframes() {
      return keyCount;
    }

    /** A new connection: a partial packet is dropped, the PCR starts over (time goes on). */
    void resync() {
      fill = 0;
      lastPcr = -1;
      pcrPid = -1;
    }

    long newestUs() {
      return count == 0 ? C.TIME_UNSET : mediaUs;
    }

    void feed(byte[] b, int off, int n, long offsetOfB, long nowMs) {
      if (startMs < 0) startMs = nowMs;
      for (int i = 0; i < n; i++) {
        if (fill == 0) {
          if (b[off + i] != 0x47) continue;
          pktStart = offsetOfB + i;
        }
        pkt[fill++] = b[off + i];
        if (fill == TS) {
          fill = 0;
          packet(nowMs);
        }
      }
    }

    private void packet(long nowMs) {
      int b1 = pkt[1] & 0xFF;
      if ((b1 & 0x80) != 0) return;
      boolean pusi = (b1 & 0x40) != 0;
      int pid = ((b1 & 0x1F) << 8) | (pkt[2] & 0xFF);
      int afc = (pkt[3] >> 4) & 3;
      boolean key = false;
      if ((afc & 2) != 0 && (pkt[4] & 0xFF) > 0) {
        int afLen = pkt[4] & 0xFF;
        int flags = pkt[5] & 0xFF;
        if ((flags & 0x10) != 0 && afLen >= 7) {
          if (pcrPid == -1 || (pid != pcrPid && nowMs - lastPcrMs > 3_000)) {
            // The first PCR PID, or the old one went quiet (another program): follow this one.
            pcrPid = pid;
            lastPcr = -1;
          }
          if (pid == pcrPid) pcr(pcrBase(), nowMs);
        }
        key = (flags & 0x40) != 0 && pusi && pid == pcrPid;
      }
      if (!sawPcr) {
        if (nowMs - startMs < NO_PCR_AFTER_MS) {
          // No time yet: the first entry waits for a PCR (most streams have one within 0.1 s).
          return;
        }
        mediaUs = (nowMs - startMs) * 1000;
      }
      if (key || mediaUs - lastEntryUs >= EVERY_US || count == 0) add(pktStart, mediaUs, key);
    }

    private long pcrBase() {
      return ((pkt[6] & 0xFFL) << 25) | ((pkt[7] & 0xFFL) << 17) | ((pkt[8] & 0xFFL) << 9)
          | ((pkt[9] & 0xFFL) << 1) | ((pkt[10] & 0xFFL) >> 7);
    }

    private void pcr(long base, long nowMs) {
      if (!sawPcr) {
        // Wall-clock time so far (a PCR only after 3 s) carries on from where it is.
        sawPcr = true;
        if (count == 0) mediaUs = 0;
      } else if (lastPcr < 0) {
        mediaUs += clampStep((nowMs - lastPcrMs) * 1000);
      } else {
        long d = base - lastPcr;
        if (d < -(1L << 32)) d += 1L << 33;
        long us = d * 100 / 9;
        if (us < 0 || us > MAX_STEP_US) us = clampStep((nowMs - lastPcrMs) * 1000);
        mediaUs += us;
      }
      lastPcr = base;
      lastPcrMs = nowMs;
    }

    private static long clampStep(long us) {
      return Math.max(0, Math.min(MAX_STEP_US, us));
    }

    private void add(long off, long us, boolean key) {
      if (count > 0 && offs[(first + count - 1)] >= off) {
        // Same packet (a keyframe flag on an entry already made): mark it.
        if (key && !keys[first + count - 1]) {
          keys[first + count - 1] = true;
          keyCount++;
        }
        return;
      }
      if (first + count == offs.length) {
        if (first > offs.length / 2) {
          System.arraycopy(offs, first, offs, 0, count);
          System.arraycopy(times, first, times, 0, count);
          System.arraycopy(keys, first, keys, 0, count);
          first = 0;
        } else {
          offs = java.util.Arrays.copyOf(offs, offs.length * 2);
          times = java.util.Arrays.copyOf(times, times.length * 2);
          keys = java.util.Arrays.copyOf(keys, keys.length * 2);
        }
      }
      int i = first + count++;
      offs[i] = off;
      times[i] = us;
      keys[i] = key;
      if (key) keyCount++;
      lastEntryUs = us;
    }

    void dropBefore(long tail) {
      while (count > 1 && offs[first + 1] <= tail) {
        if (keys[first]) keyCount--;
        first++;
        count--;
      }
      if (count == 1 && offs[first] < tail) {
        // Keep the time, move the entry onto the oldest byte.
        offs[first] = tail;
      }
    }

    /** Index (absolute) of the last entry at or before [off], else -1. */
    private int floor(long off) {
      int lo = first;
      int hi = first + count - 1;
      if (count == 0 || offs[lo] > off) return -1;
      while (lo < hi) {
        int mid = (lo + hi + 1) >>> 1;
        if (offs[mid] <= off) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      return lo;
    }

    /** Stream time at byte [off] (the entry before it), TIME_UNSET when empty. */
    long timeAt(long off) {
      if (count == 0) return C.TIME_UNSET;
      int i = floor(off);
      return times[i < 0 ? first : i];
    }

    /** A packet start at or after [tail]: the first keyframe within 10 s, else the first entry. */
    long startAtOrAfter(long tail) {
      if (count == 0) return tail;
      int i = floor(tail);
      if (i < 0 || offs[i] < tail) i = i < 0 ? first : i + 1;
      if (i >= first + count) return tail;
      long t0 = times[i];
      for (int j = i; j < first + count && times[j] - t0 <= 10_000_000; j++) {
        if (keys[j]) return offs[j];
      }
      return offs[i];
    }

    /** Where to start for time [us]: the last keyframe at or before it (within 8 s), else the
     * last entry at or before it; never before [tail]. */
    long startFor(long us, long tail) {
      if (count == 0) return tail;
      int lo = first;
      int hi = first + count - 1;
      if (times[lo] > us) return startAtOrAfter(tail);
      while (lo < hi) {
        int mid = (lo + hi + 1) >>> 1;
        if (times[mid] <= us) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      for (int j = lo; j >= first && us - times[j] <= 8_000_000; j--) {
        if (keys[j] && offs[j] >= tail) return offs[j];
      }
      return offs[lo] >= tail ? offs[lo] : startAtOrAfter(tail);
    }
  }
}
