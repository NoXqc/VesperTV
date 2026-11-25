package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import android.net.Uri;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DataSpec;
import androidx.media3.datasource.TransferListener;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

/**
 * Timeshift: live pause and rewind on the player's one connection (owner + cillfog, Discord,
 * 2026-11-25). The player's connection becomes the writer of a rolling copy; jumps start at a
 * keyframe found through the PCR / random-access index; a dropped connection reopens under it.
 */
@RunWith(RobolectricTestRunner.class)
@OptIn(markerClass = UnstableApi.class)
public class TimeshiftTest {
  private static final Uri LIVE = Uri.parse("http://example.com/live/u/p/1.ts");
  private static final int TS = 188;
  /** Packets per 40 ms: one video (PCR, keyframe every second), one audio (always "random
   * access", never a keyframe for the index), padding to make the stream bigger. */
  private static final int PER_GROUP = 4;
  private static final long GROUP_US = 40_000;

  private File cache;
  private final List<LiveTs> made = new CopyOnWriteArrayList<>();
  private final AtomicInteger opens = new AtomicInteger();
  /** Per source made by the factory: packets before the server closes (-1 = never). */
  private volatile int endAfter = -1;
  /** Packets each source may deliver before it waits (the live edge). */
  private volatile int limit = Integer.MAX_VALUE;
  private Timeshift timeshift;

  @Before
  public void setUp() throws IOException {
    cache = Files.createTempDirectory("timeshift-test").toFile();
  }

  @After
  public void tearDown() {
    if (timeshift != null) timeshift.release();
    for (LiveTs s : made) s.closed = true;
  }

  // ------------------------------------------------------------------ a live MPEG-TS stream

  /** Packet [k] of a stream whose packet counter starts at [first] and time at [baseUs]. */
  static byte[] packet(int k, int first, long baseUs) {
    byte[] p = new byte[TS];
    java.util.Arrays.fill(p, (byte) 0xFF);
    int group = k / PER_GROUP;
    int kind = k % PER_GROUP;
    int counter = first + k;
    p[0] = 0x47;
    if (kind == 0) {
      boolean key = group % 25 == 0;
      int pid = 0x100;
      p[1] = (byte) ((key ? 0x40 : 0) | (pid >> 8));
      p[2] = (byte) pid;
      p[3] = 0x30;
      p[4] = 7;
      p[5] = (byte) (0x10 | (key ? 0x40 : 0));
      long base = (baseUs + group * GROUP_US) * 9 / 100;
      p[6] = (byte) (base >> 25);
      p[7] = (byte) (base >> 17);
      p[8] = (byte) (base >> 9);
      p[9] = (byte) (base >> 1);
      p[10] = (byte) (((base & 1) << 7) | 0x7E);
      p[11] = 0;
      putInt(p, 12, counter);
    } else if (kind == 1) {
      int pid = 0x101;
      p[1] = (byte) (0x40 | (pid >> 8));
      p[2] = (byte) pid;
      p[3] = 0x30;
      p[4] = 1;
      p[5] = 0x40;
      putInt(p, 6, counter);
    } else {
      p[1] = 0x1F;
      p[2] = (byte) 0xFF;
      p[3] = 0x10;
      putInt(p, 4, counter);
    }
    return p;
  }

  private static void putInt(byte[] p, int at, int v) {
    p[at] = (byte) (v >> 24);
    p[at + 1] = (byte) (v >> 16);
    p[at + 2] = (byte) (v >> 8);
    p[at + 3] = (byte) v;
  }

  static byte[] stream(int packets, int first, long baseUs) {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    for (int k = 0; k < packets; k++) out.write(packet(k, first, baseUs), 0, TS);
    return out.toByteArray();
  }

  /** The provider's live stream: packets as fast as asked, up to [limit], then waits. */
  class LiveTs implements DataSource {
    final int first;
    final long baseUs;
    final int end;
    long produced;
    volatile boolean closed;
    private byte[] current;
    private int currentOff = TS;

    LiveTs(int first, long baseUs, int end) {
      this.first = first;
      this.baseUs = baseUs;
      this.end = end;
    }

    @Override
    public void addTransferListener(@NonNull TransferListener transferListener) {}

    @Override
    public long open(@NonNull DataSpec spec) {
      closed = false;
      return C.LENGTH_UNSET;
    }

    @Override
    public int read(@NonNull byte[] buffer, int offset, int length) throws IOException {
      int done = 0;
      while (done < length) {
        if (currentOff == TS) {
          int k = (int) produced;
          if (end >= 0 && k >= end) return done > 0 ? done : C.RESULT_END_OF_INPUT;
          while (k >= limit) {
            if (done > 0) return done;
            if (closed) throw new IOException("closed");
            try {
              Thread.sleep(5);
            } catch (InterruptedException e) {
              throw new java.io.InterruptedIOException();
            }
          }
          if (closed) throw new IOException("closed");
          current = packet(k, first, baseUs);
          currentOff = 0;
          produced++;
        }
        int n = Math.min(length - done, TS - currentOff);
        System.arraycopy(current, currentOff, buffer, offset + done, n);
        currentOff += n;
        done += n;
      }
      return done;
    }

    @Nullable
    @Override
    public Uri getUri() {
      return LIVE;
    }

    @NonNull
    @Override
    public Map<String, List<String>> getResponseHeaders() {
      return Collections.emptyMap();
    }

    @Override
    public void close() {
      closed = true;
    }
  }

  /** Each open = a new connection; the n-th one counts from n * 1,000,000. */
  private DataSource.Factory network() {
    return () -> {
      int n = opens.getAndIncrement();
      LiveTs s = new LiveTs(n * 1_000_000, n * 600_000_000L, endAfter);
      made.add(s);
      return s;
    };
  }

  private Timeshift newTimeshift(long usable) {
    Timeshift t = new Timeshift(cache, network(), null);
    t.usableOverride = usable;
    timeshift = t;
    return t;
  }

  private static DataSpec spec(long position) {
    return new DataSpec.Builder().setUri(LIVE).setPosition(position).build();
  }

  private static byte[] readFully(DataSource s, int bytes) throws IOException {
    byte[] out = new byte[bytes];
    int done = 0;
    while (done < bytes) {
      int n = s.read(out, done, bytes - done);
      if (n == C.RESULT_END_OF_INPUT) throw new IOException("ended after " + done);
      done += n;
    }
    return out;
  }

  private void waitForHead(Timeshift t, long bytes) throws InterruptedException {
    long until = System.currentTimeMillis() + 10_000;
    while (t.head() < bytes && System.currentTimeMillis() < until) Thread.sleep(5);
    assertTrue("head " + t.head() + " < " + bytes, t.head() >= bytes);
  }

  private static int counterAt(byte[] buf, int at) {
    return ((buf[at] & 0xFF) << 24) | ((buf[at + 1] & 0xFF) << 16) | ((buf[at + 2] & 0xFF) << 8)
        | (buf[at + 3] & 0xFF);
  }

  // ------------------------------------------------------------------ tests

  @Test
  public void index_timesFromPcr_keyframesOnlyOnThePcrPid() {
    Timeshift.TsIndex index = new Timeshift.TsIndex();
    byte[] s = stream(PER_GROUP * 25 * 60, 0, 0); // 60 s
    // Fed in odd pieces, like a socket.
    int at = 0;
    while (at < s.length) {
      int n = Math.min(1000 + at % 777, s.length - at);
      index.feed(s, at, n, at, 0);
      at += n;
    }
    assertEquals(59_960_000, index.newestUs());
    // Group g starts at byte g * PER_GROUP * TS; keyframes every 25 groups (1 s).
    assertEquals(10_000_000, index.timeAt(250L * PER_GROUP * TS));
    long start = index.startFor(30_500_000, 0);
    assertEquals(750L * PER_GROUP * TS, start); // the 30 s keyframe, not an audio packet
    assertEquals(60, index.keyframes());
    // From a middle byte: the next keyframe.
    assertEquals(275L * PER_GROUP * TS, index.startAtOrAfter(260L * PER_GROUP * TS + 5));
  }

  @Test
  public void takesOverTheOpenConnection_bytesCarryOnWithoutAGap() throws Exception {
    Timeshift t = newTimeshift(10L << 30);
    TimeshiftDataSource ds = new TimeshiftDataSource(network(), t);
    ds.open(spec(0));
    byte[] a = readFully(ds, 100_000);
    assertFalse(t.isActive());
    assertEquals(null, t.arm(30));
    byte[] b = readFully(ds, 400_000);
    assertTrue(t.isActive());
    assertEquals("one connection only", 1, opens.get());
    byte[] all = new byte[500_000];
    System.arraycopy(a, 0, all, 0, a.length);
    System.arraycopy(b, 0, all, a.length, b.length);
    byte[] expected = java.util.Arrays.copyOf(stream(500_000 / TS + 1, 0, 0), 500_000);
    assertArrayEquals(expected, all);
    assertFalse(t.memoryOnly());
  }

  @Test
  public void pause_theWriterKeepsReading_playResumesAtTheSameByte() throws Exception {
    Timeshift t = newTimeshift(10L << 30);
    TimeshiftDataSource ds = new TimeshiftDataSource(network(), t);
    ds.open(spec(0));
    readFully(ds, 10_000);
    t.arm(30);
    byte[] before = readFully(ds, 50_000);
    // "Paused": the player stops reading; the connection doesn't.
    waitForHead(t, 2_000_000);
    byte[] after = readFully(ds, 50_000);
    byte[] expected = stream(110_000 / TS + 1, 0, 0);
    assertArrayEquals(java.util.Arrays.copyOfRange(expected, 10_000, 60_000), before);
    assertArrayEquals(java.util.Arrays.copyOfRange(expected, 60_000, 110_000), after);
    Map<String, Object> state = t.state(0);
    assertTrue((Boolean) state.get("on"));
    assertTrue(((Long) state.get("behindMs")) > 1000);
  }

  @Test
  public void jumpBack_nextLoadStartsAtTheKeyframe_andBackToLive() throws Exception {
    limit = PER_GROUP * 25 * 90; // 90 s arrived
    Timeshift t = newTimeshift(10L << 30);
    TimeshiftDataSource ds = new TimeshiftDataSource(network(), t);
    ds.open(spec(0));
    readFully(ds, 1000);
    t.arm(30);
    readFully(ds, 1000); // the next read hands the connection over
    // The copy starts where the player was (1000 bytes in).
    waitForHead(t, (long) limit * TS - 1000);
    // The player read up to 80 s and holds 2 s ahead of the picture: 78 s on screen.
    readFully(ds, (int) (80L * 25 * PER_GROUP * TS) - 2000);
    long behind = t.jump(-30_000, 2_000);
    assertTrue("behind " + behind, behind >= 41_000 && behind <= 43_000);
    ds.close();
    ds.open(spec(0));
    byte[] first = readFully(ds, TS);
    // The next byte starts the 80 s group: 80 - 2 s held = 78 s on screen; - 30 s = 48 s: the
    // keyframe there (group 1200), not one of the audio packets flagged random access.
    assertEquals(0x47, first[0]);
    assertEquals(0x40, first[1] & 0x40);
    assertEquals(1200 * PER_GROUP, counterAt(first, 12));
    // Far ahead = live: a keyframe ~1 s before the newest byte.
    long live = t.jump(3_600_000, 0);
    assertTrue("live " + live, live <= 2_000);
    ds.close();
    ds.open(spec(0));
    byte[] edge = readFully(ds, TS);
    int group = counterAt(edge, 12) / PER_GROUP;
    assertEquals(0, group % 25);
    assertTrue("group " + group, group >= 25 * 88);
  }

  @Test
  public void aDroppedConnectionReopensUnderThePlayer() throws Exception {
    endAfter = 2000;
    Timeshift t = newTimeshift(10L << 30);
    TimeshiftDataSource ds = new TimeshiftDataSource(network(), t);
    ds.open(spec(0));
    readFully(ds, TS);
    t.arm(30);
    byte[] rest = readFully(ds, 2500 * TS);
    // The first connection's packets (1..1999), then the second's (counted from 1,000,000).
    assertEquals(1999, counterAt(rest, 1998 * TS + 4)); // packet 1999 = padding
    assertEquals(1_000_000, counterAt(rest, 1999 * TS + 12)); // its packet 0 = video
    assertTrue(opens.get() >= 2);
  }

  @Test
  public void memoryOnlyWhenStorageIsShort_andTheCapHolds() {
    Timeshift t = newTimeshift(100L * 1024 * 1024); // under the reserve
    assertEquals(null, t.arm(30));
    assertTrue(t.memoryOnly());
    byte[] s = stream(PER_GROUP * 25 * 400, 0, 0); // 400 s, ~7.5 MB
    for (int r = 0; r < 6; r++) {
      for (int at = 0; at < s.length; at += 65536) {
        t.appendForTest(java.util.Arrays.copyOfRange(s, at, Math.min(s.length, at + 65536)),
            Math.min(65536, s.length - at));
      }
    }
    long cap = Math.min(Timeshift.MEMORY_CAP, Runtime.getRuntime().maxMemory() / 8);
    assertTrue("stored " + (t.head() - t.tail()), t.head() - t.tail() <= cap);
    assertTrue(t.tail() > 0);
  }

  @Test
  public void theWindowDropsOldFiles() throws Exception {
    Timeshift t = newTimeshift(10L << 30);
    assertEquals(null, t.arm(1));
    // 100 s of a ~1.6 MB/s stream (~10 files of 16 MB): the first 40 s go.
    byte[] pad = new byte[64 * 1024];
    int groups = 25 * 100;
    for (int g = 0; g < groups; g++) {
      byte[] video = packet(g * PER_GROUP, 0, 0);
      t.appendForTest(video, TS);
      // ~120 KB per 40 ms of padding packets.
      for (int i = 0; i < 1; i++) {
        for (int p = 0; p + TS <= pad.length; p += TS) {
          pad[p] = 0x47;
          pad[p + 1] = 0x1F;
          pad[p + 2] = (byte) 0xFF;
          pad[p + 3] = 0x10;
        }
        t.appendForTest(pad, pad.length - pad.length % TS);
      }
    }
    Map<String, Object> state = t.state(0);
    long available = (Long) state.get("availableMs");
    assertTrue("available " + available, available <= 72_000 && available >= 59_000);
    File ring = new File(cache, "timeshift");
    File[] dirs = ring.listFiles();
    assertNotNull(dirs);
    int files = 0;
    for (File d : dirs) {
      File[] f = d.listFiles();
      if (f != null) files += f.length;
    }
    // 60 s of 1.6 MB/s = 98 MB: 7 files (+ the one being written).
    assertTrue("files " + files, files >= 6 && files <= 8);
  }

  @Test
  public void notMpegTs_staysOnTheNetwork() throws Exception {
    Timeshift t = newTimeshift(10L << 30);
    DataSource.Factory notTs = () -> new LiveTs(0, 0, -1) {
      @Override
      public int read(@NonNull byte[] buffer, int offset, int length) throws IOException {
        int n = super.read(buffer, offset, length);
        if (n > 0) buffer[offset] = 0x1A; // an MKV stream
        return n;
      }
    };
    TimeshiftDataSource ds = new TimeshiftDataSource(notTs, t);
    ds.open(spec(0));
    readFully(ds, 1000);
    t.arm(30);
    readFully(ds, 10_000);
    assertFalse(t.isActive());
  }

  @Test
  public void switchedOff_theReaderGoesBackToTheNetwork() throws Exception {
    Timeshift t = newTimeshift(10L << 30);
    TimeshiftDataSource ds = new TimeshiftDataSource(network(), t);
    ds.open(spec(0));
    readFully(ds, 1000);
    t.arm(30);
    readFully(ds, 10_000);
    t.release();
    byte[] after = readFully(ds, 2 * TS);
    assertEquals(2, opens.get());
    // A new connection from "now": its own first packet somewhere in the next two.
    boolean fromSecond = false;
    for (int i = 0; i + 16 <= after.length; i++) {
      if (after[i] == 0x47 && counterAt(after, i + 12) == 1_000_000) fromSecond = true;
    }
    assertTrue(fromSecond);
  }
}
