package io.flutter.plugins.videoplayer;

import static org.junit.Assert.*;

import org.junit.Test;

/** The frame rate from the first frames' timestamps (FrameRateProbe.fromTimes). */
public class FrameRateProbeTest {
  private static long[] times(long... gapsUs) {
    long[] t = new long[gapsUs.length + 1];
    for (int i = 0; i < gapsUs.length; i++) t[i + 1] = t[i] + gapsUs[i];
    return t;
  }

  @Test
  public void evenFiftyIsFifty() {
    long[] g = new long[15];
    java.util.Arrays.fill(g, 20_000);
    assertEquals(50.0, FrameRateProbe.fromTimes(times(g)), 0.01);
  }

  @Test
  public void unevenTimestampsAverageToTheRealRate() {
    // LOG-EVPPYN (Fire TV, 2026-11-19): a 50 fps channel read 58.8 fps from the median gap.
    long[] g = new long[15];
    for (int i = 0; i < g.length; i++) g[i] = i % 2 == 0 ? 17_000 : 23_000;
    assertEquals(50.0, FrameRateProbe.fromTimes(times(g)), 1.0);
  }

  @Test
  public void aDroppedFrameDoesNotSkewIt() {
    long[] g = new long[15];
    java.util.Arrays.fill(g, 16_683);
    g[5] = 33_366; // one frame missing
    assertEquals(59.94, FrameRateProbe.fromTimes(times(g)), 0.05);
  }

  @Test
  public void gapsTextIsInMilliseconds() {
    assertEquals("17.0 23.0", FrameRateProbe.gapsText(times(17_000, 23_000)));
  }
}
