// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.net.Uri;
import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.ByteArrayDataSource;
import androidx.media3.datasource.DataSource;
import androidx.media3.datasource.DataSpec;
import androidx.media3.extractor.SeekMap;
import androidx.media3.extractor.mkv.MatroskaExtractor;
import androidx.media3.test.utils.FakeExtractorOutput;
import androidx.media3.test.utils.TestUtil;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

/**
 * cillfog (Discord, LOG-JKB6RY, 2026-11-26): every skip in Marshals went back to the start. The
 * provider's MKVs (Lavf 60) start with a SeekHead that only points to a second SeekHead at the
 * end; only that one names the Cues. two_seekheads.mkv = an ffmpeg file rebuilt into that layout
 * (scratchpad make_two_seekheads.py: same bytes, the front SeekHead + Void replaced, the original
 * SeekHead appended); one_seekhead.mkv = the same file as ffmpeg wrote it.
 */
@RunWith(RobolectricTestRunner.class)
@OptIn(markerClass = UnstableApi.class)
public class MkvSeekHeadFixTest {
  private static final Uri FILE = Uri.parse("https://example.com/series/u/p/1.mkv");

  private static byte[] fixture(String name) throws IOException {
    try (InputStream in =
        MkvSeekHeadFixTest.class.getClassLoader().getResourceAsStream("mkv/" + name)) {
      assertNotNull(name, in);
      ByteArrayOutputStream out = new ByteArrayOutputStream();
      byte[] buf = new byte[8192];
      int n;
      while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
      return out.toByteArray();
    }
  }

  private static SeekMap seekMapOf(DataSource source) throws IOException {
    return TestUtil.extractSeekMap(new MatroskaExtractor(), new FakeExtractorOutput(), source, FILE);
  }

  /** The fix over [file], counting the side requests it makes. */
  private static MkvSeekHeadFix fix(byte[] file, AtomicInteger sideOpens) {
    return new MkvSeekHeadFix(new ByteArrayDataSource(file), () -> {
      sideOpens.incrementAndGet();
      return new ByteArrayDataSource(file);
    });
  }

  @Test
  public void media3Alone_secondSeekHeadOnly_isUnseekable() throws IOException {
    // The bug: MatroskaExtractor never follows the first SeekHead to the second one.
    SeekMap map = seekMapOf(new ByteArrayDataSource(fixture("two_seekheads.mkv")));
    assertFalse(map.isSeekable());
  }

  @Test
  public void withTheFix_theCuesAreFound_andSeeksLandInside() throws IOException {
    byte[] file = fixture("two_seekheads.mkv");
    AtomicInteger sideOpens = new AtomicInteger();
    SeekMap map = seekMapOf(fix(file, sideOpens));
    assertTrue(map.isSeekable());
    assertEquals("one small range request", 1, sideOpens.get());
    long middle = 5_000_000;
    SeekMap.SeekPoints points = map.getSeekPoints(middle);
    assertTrue("seek point " + points.first, points.first.timeUs > 0);
    assertTrue(points.first.timeUs <= middle);
    assertTrue(points.first.position > 0);
  }

  @Test
  public void normalLayout_passesThroughUnchanged_noSideRequest() throws IOException {
    byte[] file = fixture("one_seekhead.mkv");
    AtomicInteger sideOpens = new AtomicInteger();
    MkvSeekHeadFix source = fix(file, sideOpens);
    assertEquals(file.length, source.open(new DataSpec(FILE)));
    byte[] out = readAll(source);
    source.close();
    assertArrayEquals(file, out);
    assertEquals(0, sideOpens.get());
    assertTrue(seekMapOf(fix(file, sideOpens)).isSeekable());
  }

  @Test
  public void onlyTheEntryChanges_everyOtherByteIsTheFile() throws IOException {
    byte[] file = fixture("two_seekheads.mkv");
    MkvSeekHeadFix source = fix(file, new AtomicInteger());
    source.open(new DataSpec(FILE));
    byte[] out = readAll(source);
    source.close();
    assertEquals(file.length, out.length);
    int changed = 0;
    for (int i = 0; i < file.length; i++) {
      if (file[i] != out[i]) changed++;
    }
    assertTrue("changed " + changed, changed > 0 && changed <= 8);
    // The first SeekHead now names the Cues directly.
    MkvSeekHeadFix.Chain chain = MkvSeekHeadFix.findChain(out, MkvSeekHeadFix.HEAD_BYTES);
    assertNull("no second SeekHead left to follow", chain);
  }

  @Test
  public void notMkv_orLive_passThrough() throws IOException {
    byte[] ts = new byte[10_000];
    for (int i = 0; i < ts.length; i += 188) ts[i] = 0x47;
    AtomicInteger sideOpens = new AtomicInteger();
    MkvSeekHeadFix source = fix(ts, sideOpens);
    source.open(new DataSpec(FILE));
    assertArrayEquals(ts, readAll(source));
    source.close();
    // A live stream (no length): never read ahead.
    MkvSeekHeadFix live = new MkvSeekHeadFix(new UnknownLength(fixture("two_seekheads.mkv")),
        () -> {
          sideOpens.incrementAndGet();
          return new ByteArrayDataSource(new byte[0]);
        });
    assertEquals(C.LENGTH_UNSET, live.open(new DataSpec(FILE)));
    live.close();
    assertEquals(0, sideOpens.get());
  }

  @Test
  public void opensPastTheStart_areNotTouched() throws IOException {
    byte[] file = fixture("two_seekheads.mkv");
    AtomicInteger sideOpens = new AtomicInteger();
    MkvSeekHeadFix source = fix(file, sideOpens);
    source.open(new DataSpec.Builder().setUri(FILE).setPosition(1000).build());
    byte[] out = readAll(source);
    source.close();
    assertEquals(file.length - 1000, out.length);
    assertEquals(0, sideOpens.get());
  }

  private static byte[] readAll(DataSource source) throws IOException {
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    byte[] buf = new byte[3000];
    int n;
    while ((n = source.read(buf, 0, buf.length)) != C.RESULT_END_OF_INPUT) out.write(buf, 0, n);
    return out.toByteArray();
  }

  /** A source that doesn't say its length (a live stream). */
  private static final class UnknownLength implements DataSource {
    private final ByteArrayDataSource bytes;

    UnknownLength(byte[] data) {
      bytes = new ByteArrayDataSource(data);
    }

    @Override
    public void addTransferListener(androidx.media3.datasource.TransferListener listener) {}

    @Override
    public long open(DataSpec dataSpec) throws IOException {
      bytes.open(dataSpec);
      return C.LENGTH_UNSET;
    }

    @Override
    public int read(byte[] buffer, int offset, int length) throws IOException {
      return bytes.read(buffer, offset, length);
    }

    @Override
    public Uri getUri() {
      return bytes.getUri();
    }

    @Override
    public void close() throws IOException {
      bytes.close();
    }
  }
}
