package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
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
import java.io.IOException;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

/**
 * ReadAhead: a big movie file downloads over several connections into a memory ring
 * (owner's Homatics, 2026-11-21: a 65 Mbit/s remux froze when its source slowed for minutes;
 * a 94.5 GB / 80 Mbit/s one got 41-65 Mbit/s on one connection).
 */
@RunWith(RobolectricTestRunner.class)
@OptIn(markerClass = UnstableApi.class)
public class ReadAheadTest {
  private static final Uri FILE = Uri.parse("https://example.com/movie.mkv");
  private static final int SIZE = 1 << 20;
  private static final long WINDOW = 64 * 1024;
  private static final long KEEP = 4 * 1024;

  private final byte[] data = new byte[SIZE];

  {
    new Random(7).nextBytes(data);
  }

  /** The network: every open's position, opens that fail first, speed limits (bytes/s). */
  private final List<Long> fetchOpens = new CopyOnWriteArrayList<>();
  private final AtomicInteger failOpens = new AtomicInteger();
  private volatile long perConnectionRate;
  private volatile long sharedRate;
  private final Object shared = new Object();
  private long sharedStartNs;
  private long sharedBytes;

  private final class Memory implements DataSource {
    private final List<Long> opens;
    private final boolean canFail;
    private long pos;
    private long startNs;
    private long bytes;
    boolean closed = true;

    Memory(List<Long> opens, boolean canFail) {
      this.opens = opens;
      this.canFail = canFail;
    }

    @Override
    public void addTransferListener(@NonNull TransferListener transferListener) {}

    @Override
    public long open(@NonNull DataSpec spec) throws IOException {
      opens.add(spec.position);
      if (canFail && failOpens.getAndUpdate(n -> Math.max(0, n - 1)) > 0) {
        throw new IOException("server busy");
      }
      pos = spec.position;
      closed = false;
      startNs = System.nanoTime();
      bytes = 0;
      long left = SIZE - pos;
      return spec.length == C.LENGTH_UNSET ? left : Math.min(left, spec.length);
    }

    @Override
    public int read(@NonNull byte[] buffer, int offset, int length) throws IOException {
      if (closed) throw new IOException("closed");
      if (pos >= SIZE) return C.RESULT_END_OF_INPUT;
      int n = (int) Math.min(Math.min(length, 8192), SIZE - pos);
      long dueNs = 0;
      if (perConnectionRate > 0) {
        bytes += n;
        dueNs = startNs + bytes * 1_000_000_000L / perConnectionRate;
      }
      if (sharedRate > 0) {
        synchronized (shared) {
          if (sharedStartNs == 0) sharedStartNs = System.nanoTime();
          sharedBytes += n;
          dueNs = Math.max(dueNs, sharedStartNs + sharedBytes * 1_000_000_000L / sharedRate);
        }
      }
      long waitNs = dueNs - System.nanoTime();
      if (waitNs > 0) {
        try {
          Thread.sleep(waitNs / 1_000_000, (int) (waitNs % 1_000_000));
        } catch (InterruptedException e) {
          throw new IOException(e);
        }
      }
      System.arraycopy(data, (int) pos, buffer, offset, n);
      pos += n;
      return n;
    }

    @Nullable
    @Override
    public Uri getUri() {
      return FILE;
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

  private final List<Long> directOpens = new CopyOnWriteArrayList<>();

  private ReadAhead readAhead(Uri uri) {
    ReadAhead.Tuning t = new ReadAhead.Tuning();
    t.windowBytes = WINDOW;
    t.blockBytes = 4 * 1024;
    t.keepBehindBytes = KEEP;
    t.waitGapBytes = 16 * 1024;
    t.segmentBytes = 8 * 1024;
    t.sampleMs = 300;
    t.noGainPauseMs = 60_000;
    t.retryDelaysMs = new long[] {10, 10, 10};
    return new ReadAhead(() -> new Memory(fetchOpens, true), uri, t);
  }

  private ReadAhead readAhead() {
    return readAhead(FILE);
  }

  private ReadAheadDataSource source(ReadAhead ra) {
    return new ReadAheadDataSource(() -> new Memory(directOpens, false), ra);
  }

  private static DataSpec at(long position, long length) {
    return new DataSpec.Builder().setUri(FILE).setPosition(position).setLength(length).build();
  }

  /** Reads [count] bytes (or to the end) in uneven chunks; [onRead] after each. */
  private static byte[] read(DataSource ds, int count, @Nullable Runnable onRead)
      throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    byte[] buf = new byte[10_000];
    Random r = new Random(3);
    while (out.size() < count) {
      int n = ds.read(buf, 0, Math.min(1 + r.nextInt(buf.length), count - out.size()));
      if (n == C.RESULT_END_OF_INPUT) break;
      out.write(buf, 0, n);
      if (onRead != null) onRead.run();
    }
    return out.toByteArray();
  }

  private static byte[] read(DataSource ds, int count) throws IOException {
    return read(ds, count, null);
  }

  private byte[] slice(int from, int count) {
    byte[] out = new byte[count];
    System.arraycopy(data, from, out, 0, count);
    return out;
  }

  @Test(timeout = 20_000)
  public void theWholeFileComesThroughTheRingInOrder() throws IOException {
    ReadAhead ra = readAhead();
    assertNull(ra.arm());
    ReadAheadDataSource ds = source(ra);
    ds.open(at(0, C.LENGTH_UNSET));
    assertArrayEquals(data, read(ds, Integer.MAX_VALUE));
    assertTrue("the player never used the network itself", directOpens.isEmpty());
    assertEquals(0, ra.restarts());
    ds.close();
    ra.release();
  }

  @Test(timeout = 20_000)
  public void theDownloadStaysAWindowAheadOfThePlayer() throws Exception {
    ReadAhead ra = readAhead();
    ra.arm();
    ReadAheadDataSource ds = source(ra);
    ds.open(at(0, C.LENGTH_UNSET));
    read(ds, 1000);
    long ahead = -1;
    for (int i = 0; i < 100; i++) {
      Thread.sleep(20);
      long now = ra.bytesAhead();
      if (now == ahead) break;
      ahead = now;
    }
    assertTrue("downloaded ahead: " + ahead, ahead > WINDOW / 2);
    assertTrue("never past the window: " + ahead, ahead <= WINDOW - KEEP);
    ds.close();
    ra.release();
  }

  @Test(timeout = 20_000)
  public void aFarSeekStartsTheDownloadOverThere() throws IOException {
    ReadAhead ra = readAhead();
    ra.arm();
    ReadAheadDataSource ds = source(ra);
    ds.open(at(0, C.LENGTH_UNSET));
    read(ds, 5000);
    ds.close();
    assertEquals(SIZE - 600_000, ds.open(at(600_000, C.LENGTH_UNSET)));
    assertArrayEquals(slice(600_000, 50_000), read(ds, 50_000));
    assertEquals(1, ra.restarts());
    assertTrue(fetchOpens.toString(), fetchOpens.contains(600_000L));
    assertTrue(directOpens.isEmpty());
    ds.close();
    ra.release();
  }

  @Test(timeout = 20_000)
  public void aShortProbeOutsideTheDownloadReadsTheNetworkDirectly() throws IOException {
    ReadAhead ra = readAhead();
    ra.arm();
    ReadAheadDataSource ds = source(ra);
    ds.open(at(0, C.LENGTH_UNSET));
    read(ds, 5000);
    ds.close();
    // An index near the end of the file (MKV cues): read, not a reason to start over.
    assertEquals(1000, ds.open(at(900_000, 1000)));
    assertArrayEquals(slice(900_000, 1000), read(ds, Integer.MAX_VALUE));
    ds.close();
    assertEquals(List.of(900_000L), directOpens);
    assertEquals(0, ra.restarts());
    ra.release();
  }

  @Test(timeout = 20_000)
  public void switchedOnMidReadTheSameConnectionCarriesOn() throws IOException {
    ReadAhead ra = readAhead();
    ReadAheadDataSource ds = source(ra);
    ds.open(at(0, C.LENGTH_UNSET));
    byte[] first = read(ds, 10_000);
    assertNull(ra.arm());
    byte[] rest = read(ds, Integer.MAX_VALUE);
    ByteArrayOutputStream all = new ByteArrayOutputStream();
    all.write(first);
    all.write(rest);
    assertArrayEquals(data, all.toByteArray());
    // No reconnect: the player's own connection became the download.
    assertEquals(List.of(0L), directOpens);
    assertTrue(fetchOpens.toString(), fetchOpens.isEmpty());
    ds.close();
    ra.release();
  }

  @Test(timeout = 20_000)
  public void aFailedDownloadIsRetried() throws IOException {
    failOpens.set(2);
    ReadAhead ra = readAhead();
    ra.arm();
    ReadAheadDataSource ds = source(ra);
    ds.open(at(0, C.LENGTH_UNSET));
    assertArrayEquals(data, read(ds, Integer.MAX_VALUE));
    assertNotNull(ra.note());
    assertTrue(ra.note(), ra.note().contains("retry 2"));
    ds.close();
    ra.release();
  }

  @Test(timeout = 20_000)
  public void switchedOffMidReadTheNetworkTakesOver() throws IOException {
    ReadAhead ra = readAhead();
    ra.arm();
    ReadAheadDataSource ds = source(ra);
    ds.open(at(0, C.LENGTH_UNSET));
    byte[] first = read(ds, 30_000);
    ra.release();
    assertFalse(ra.isArmed());
    byte[] rest = read(ds, Integer.MAX_VALUE);
    ByteArrayOutputStream all = new ByteArrayOutputStream();
    all.write(first);
    all.write(rest);
    assertArrayEquals(data, all.toByteArray());
    assertEquals(List.of(30_000L), directOpens);
    ds.close();
  }

  @Test(timeout = 30_000)
  public void aSlowConnectionGetsCompanyAndTheBytesStillComeInOrder() throws IOException {
    // Each connection is limited (as a long route limits one stream): two go twice as fast.
    perConnectionRate = 400 * 1024;
    ReadAhead ra = readAhead();
    ra.setNeededMbps(30);
    ra.arm();
    ReadAheadDataSource ds = source(ra);
    ds.open(at(0, C.LENGTH_UNSET));
    int[] most = {0};
    byte[] got = read(ds, Integer.MAX_VALUE, () -> most[0] = Math.max(most[0], ra.connections()));
    assertArrayEquals(data, got);
    assertTrue("connections: " + most[0] + ", " + ra.note(), most[0] >= 2);
    ds.close();
    ra.release();
  }

  @Test(timeout = 30_000)
  public void aConnectionThatBringsNoGainIsDropped() throws IOException {
    // The server's total is the limit: a second connection adds nothing.
    sharedRate = 400 * 1024;
    ReadAhead ra = readAhead();
    ra.setNeededMbps(30);
    ra.arm();
    ReadAheadDataSource ds = source(ra);
    ds.open(at(0, C.LENGTH_UNSET));
    assertArrayEquals(data, read(ds, Integer.MAX_VALUE));
    assertNotNull(ra.note());
    assertTrue(ra.note(), ra.note().contains("no gain"));
    assertEquals(1, ra.connections());
    ds.close();
    ra.release();
  }

  @Test
  public void aFileAlreadyOnThisDeviceStaysOff() {
    ReadAhead ra = readAhead(Uri.parse("http://127.0.0.1:8080/share/movie.mkv"));
    assertEquals("already on this device", ra.arm());
    assertFalse(ra.isArmed());
  }
}
