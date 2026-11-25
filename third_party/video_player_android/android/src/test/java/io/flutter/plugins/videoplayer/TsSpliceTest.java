package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.common.util.Util;
import androidx.media3.extractor.Extractor;
import androidx.media3.extractor.PositionHolder;
import androidx.media3.extractor.TrackOutput;
import androidx.media3.extractor.ts.TsExtractor;
import androidx.media3.test.utils.FakeExtractorInput;
import androidx.media3.test.utils.FakeExtractorOutput;
import androidx.media3.test.utils.FakeTrackOutput;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

/**
 * TsSplice against media3's own TS reader, with streams spliced like Tuliprox does: a new PAT/PMT
 * (versions continued), then the next source's packets with their own PIDs and timestamps.
 */
@RunWith(RobolectricTestRunner.class)
@OptIn(markerClass = UnstableApi.class)
public class TsSpliceTest {
  private static final int FRAMES = 60;
  /** One AAC frame at 48 kHz in 90 kHz ticks (21.33 ms). */
  private static final long FRAME_TICKS = 1920;

  /** A Tuliprox-like stream: source A, then source B spliced in at a new PAT/PMT. */
  private static byte[] spliced(int pidA, int pidB, long ptsA, long ptsB) {
    Ts ts = new Ts();
    ts.pat(0, 0x1000).pmt(0x1000, 0, pidA, 0x0F);
    for (int i = 0; i < FRAMES; i++) ts.adts(pidA, ptsA + i * FRAME_TICKS);
    // Source B: other PMT PID when the audio PID changes too, versions continued.
    int pmtB = pidB == pidA ? 0x1000 : 0x1001;
    ts.cc.clear();
    ts.pat(1, pmtB).pmt(pmtB, 1, pidB, 0x0F);
    for (int i = 0; i < FRAMES; i++) ts.adts(pidB, ptsB + i * FRAME_TICKS);
    return ts.bytes();
  }

  private static FakeTrackOutput onlyTrack(FakeExtractorOutput output) {
    assertEquals(1, output.numberOfTracks);
    return output.trackOutputs.valueAt(0);
  }

  private static FakeExtractorOutput extract(Extractor extractor, byte[] data, boolean live)
      throws IOException {
    FakeExtractorOutput output = new FakeExtractorOutput();
    extractor.init(output);
    FakeExtractorInput input =
        new FakeExtractorInput.Builder()
            .setData(data)
            .setSimulateUnknownLength(live)
            .setSimulatePartialReads(true)
            .build();
    PositionHolder position = new PositionHolder();
    int result = Extractor.RESULT_CONTINUE;
    while (result != Extractor.RESULT_END_OF_INPUT) {
      result = extractor.read(input, position);
      if (result == Extractor.RESULT_SEEK) input.setPosition((int) position.position);
    }
    return output;
  }

  private static TsSplice.SplicingExtractor splicing(StreamStats stats) {
    return new TsSplice.SplicingExtractor(new TsExtractor(), stats);
  }

  /** Every sample after the first continues the one before by about a frame. */
  private static void assertContinuous(FakeTrackOutput track, int samples) {
    assertEquals(samples, track.getSampleCount());
    for (int i = 1; i < samples; i++) {
      long step = track.getSampleTimeUs(i) - track.getSampleTimeUs(i - 1);
      assertTrue("sample " + i + " steps " + step + " us", step > 15_000 && step < 30_000);
    }
  }

  @Test
  public void mediaThreeAloneJumpsBackWhenTheSourceChanges() throws IOException {
    // What froze the Homatics: same PIDs, the next source 15 s behind.
    FakeTrackOutput track =
        onlyTrack(extract(new TsExtractor(), spliced(0x101, 0x101, 9_000_000, 7_650_000), true));
    assertEquals(2 * FRAMES, track.getSampleCount());
    long step = track.getSampleTimeUs(FRAMES) - track.getSampleTimeUs(FRAMES - 1);
    assertTrue("jumped " + step, step < -14_000_000);
  }

  @Test
  public void aJumpBackContinuesRightAfterTheLastSample() throws IOException {
    StreamStats stats = new StreamStats(null);
    TsSplice.SplicingExtractor extractor = splicing(stats);
    FakeTrackOutput track =
        onlyTrack(extract(extractor, spliced(0x101, 0x101, 9_000_000, 7_650_000), true));
    assertContinuous(track, 2 * FRAMES);
    assertEquals(1, stats.tsSplices.get());
    assertEquals(1, stats.tsJumps.get());
  }

  @Test
  public void aJumpAheadContinuesToo() throws IOException {
    FakeTrackOutput track =
        onlyTrack(extract(splicing(null), spliced(0x101, 0x101, 9_000_000, 90_000_000), true));
    assertContinuous(track, 2 * FRAMES);
  }

  @Test
  public void mediaThreeAloneLosesASourceWithOtherPids() throws IOException {
    FakeTrackOutput track =
        onlyTrack(extract(new TsExtractor(), spliced(0x101, 0x201, 9_000_000, 7_650_000), true));
    assertEquals(FRAMES, track.getSampleCount());
  }

  @Test
  public void otherPidsArePlayedOnTheSameTrack() throws IOException {
    StreamStats stats = new StreamStats(null);
    FakeTrackOutput track =
        onlyTrack(extract(splicing(stats), spliced(0x101, 0x201, 9_000_000, 7_650_000), true));
    assertContinuous(track, 2 * FRAMES);
    assertEquals(1, stats.tsSplices.get());
  }

  /** AAC (type 0x0F) then MPEG audio (type 0x03) on the same PID, then AAC again. */
  private static byte[] codecChanges() {
    Ts ts = new Ts();
    ts.pat(0, 0x1000).pmt(0x1000, 0, 0x101, 0x0F);
    for (int i = 0; i < FRAMES; i++) ts.adts(0x101, 9_000_000 + i * FRAME_TICKS);
    ts.cc.clear();
    ts.pat(1, 0x1000).pmt(0x1000, 1, 0x101, 0x03);
    // 1152 samples a frame at 48 kHz = 24 ms = 2160 ticks.
    for (int i = 0; i < FRAMES; i++) ts.mp2(0x101, 7_650_000 + i * 2160L);
    ts.cc.clear();
    ts.pat(2, 0x1000).pmt(0x1000, 2, 0x101, 0x0F);
    for (int i = 0; i < FRAMES; i++) ts.adts(0x101, 30_000_000 + i * FRAME_TICKS);
    return ts.bytes();
  }

  @Test
  public void anotherCodecGetsANewReaderOnTheSameTrack() throws IOException {
    // Owner's Homatics: Sky Sports News HD hevc -> HD (H.264): picture, then sound stopped.
    StreamStats stats = new StreamStats(null);
    TsSplice.SplicingExtractor extractor = splicing(stats);
    FakeExtractorOutput output = extract(extractor, codecChanges(), true);
    FakeTrackOutput track = onlyTrack(output);
    assertEquals(3 * FRAMES, track.getSampleCount());
    for (int i = 1; i < track.getSampleCount(); i++) {
      long step = track.getSampleTimeUs(i) - track.getSampleTimeUs(i - 1);
      assertTrue("sample " + i + " steps " + step + " us", step > 15_000 && step < 30_000);
    }
    assertEquals(2, extractor.newReaders);
    assertEquals(2, stats.tsSplices.get());
    // The track's format followed: AAC, MPEG audio, AAC.
    assertEquals(MimeTypes.AUDIO_AAC, track.lastFormat.sampleMimeType);
  }

  @Test
  public void mediaThreeAloneStopsAtAnotherCodec() throws IOException {
    FakeTrackOutput track = onlyTrack(extract(new TsExtractor(), codecChanges(), true));
    assertTrue(track.getSampleCount() < 3 * FRAMES);
  }

  @Test
  public void aSwitchWithoutAJumpChangesNothing() throws IOException {
    // Two copies of one feed: the next source's clock carries straight on.
    StreamStats stats = new StreamStats(null);
    long next = 9_000_000 + FRAMES * FRAME_TICKS;
    byte[] data = spliced(0x101, 0x101, 9_000_000, next);
    FakeTrackOutput plain = onlyTrack(extract(new TsExtractor(), data, true));
    FakeTrackOutput spliced = onlyTrack(extract(splicing(stats), data, true));
    assertEquals(plain.getSampleCount(), spliced.getSampleCount());
    for (int i = 0; i < plain.getSampleCount(); i++) {
      assertEquals(plain.getSampleTimeUs(i), spliced.getSampleTimeUs(i));
    }
    assertEquals(1, stats.tsSplices.get());
    assertEquals(0, stats.tsJumps.get());
  }

  @Test
  public void aFileIsLeftAlone() throws IOException {
    byte[] data = spliced(0x101, 0x101, 9_000_000, 7_650_000);
    FakeTrackOutput plain = onlyTrack(extract(new TsExtractor(), data, false));
    FakeTrackOutput spliced = onlyTrack(extract(splicing(null), data, false));
    assertEquals(plain.getSampleCount(), spliced.getSampleCount());
    for (int i = 0; i < plain.getSampleCount(); i++) {
      assertEquals(plain.getSampleTimeUs(i), spliced.getSampleTimeUs(i));
    }
  }

  @Test
  public void aDamagedTableIsIgnored() {
    TsSplice.ProgramFollower programs = new TsSplice.ProgramFollower(null);
    Ts ts = new Ts();
    ts.pat(0, 0x1000).pmt(0x1000, 0, 0x101, 0x0F);
    byte[] good = ts.bytes();
    programs.process(good, 0);
    programs.process(good, 188);
    // The next source's PMT with a broken CRC: no new program, no mapping.
    Ts next = new Ts();
    next.pmt(0x1000, 1, 0x201, 0x0F);
    byte[] bad = next.bytes();
    bad[20] ^= 0x01;
    programs.process(bad, 0);
    assertEquals(0, programs.changes);
    assertEquals(0x201, programs.remappedPid(0x201));
  }

  // --- The timeline alone (video in decode order, an audio gap, a late sample) ---

  private static final class Av {
    final TsSplice.Timeline timeline;
    final FakeTrackOutput videoOut;
    final FakeTrackOutput audioOut;
    final TrackOutput video;
    final TrackOutput audio;
    int videoSamples;
    int audioSamples;

    Av() {
      FakeExtractorOutput output = new FakeExtractorOutput();
      timeline = new TsSplice.Timeline(output, null);
      timeline.active = true;
      video = timeline.track(1, C.TRACK_TYPE_VIDEO);
      audio = timeline.track(2, C.TRACK_TYPE_AUDIO);
      video.format(new Format.Builder().setSampleMimeType(MimeTypes.VIDEO_H264).build());
      audio.format(new Format.Builder().setSampleMimeType(MimeTypes.AUDIO_AAC).build());
      videoOut = output.trackOutputs.get(1);
      audioOut = output.trackOutputs.get(2);
    }

    long video(long timeUs) {
      video.sampleMetadata(timeUs, 0, 0, 0, null);
      return videoOut.getSampleTimeUs(videoSamples++);
    }

    long audio(long timeUs) {
      audio.sampleMetadata(timeUs, 0, 0, 0, null);
      return audioOut.getSampleTimeUs(audioSamples++);
    }
  }

  @Test
  public void decodeOrderAndAnAudioGapAreNoJumps() {
    Av av = new Av();
    // I P B B, 40 ms frames: decode order steps back a few frames.
    long[] video = {0, 120_000, 40_000, 80_000, 280_000, 160_000, 200_000, 240_000};
    for (long t : video) assertEquals(t, av.video(t));
    for (long t = 0; t < 300_000; t += 21_333) assertEquals(t, av.audio(t));
    // Sound missing for 4 s while the picture went on: no jump, nothing moved.
    for (long t = 280_000; t < 4_400_000; t += 40_000) assertEquals(t, av.video(t));
    assertEquals(4_300_000, av.audio(4_300_000));
    assertEquals(0, av.timeline.jumps);
  }

  @Test
  public void aLateSampleOfTheOldSourceKeepsItsTime() {
    Av av = new Av();
    for (long t = 0; t <= 1_000_000; t += 40_000) av.video(t);
    for (long t = 0; t <= 1_000_000; t += 20_000) av.audio(t);
    // The next source's sound, 20 s back: continued right after the newest sample.
    long jumped = av.audio(-19_000_000);
    assertTrue(jumped > 1_000_000 && jumped < 1_100_000);
    assertEquals(1, av.timeline.jumps);
    // The old source's last picture, finished only now: still on its own time.
    assertEquals(1_040_000, av.video(1_040_000));
    // Then the next source's picture: on the new time, next to its sound.
    long picture = av.video(-19_000_000);
    assertTrue(Math.abs(picture - jumped) < 50_000);
    assertEquals(1, av.timeline.jumps);
  }

  /** TS packets: PAT, PMT (one stream), ADTS audio in PES. */
  private static final class Ts {
    private final ByteArrayOutputStream out = new ByteArrayOutputStream();
    final android.util.SparseIntArray cc = new android.util.SparseIntArray();

    byte[] bytes() {
      return out.toByteArray();
    }

    private int nextCc(int pid) {
      int c = cc.get(pid, 0);
      cc.put(pid, (c + 1) & 0xF);
      return c;
    }

    private void psi(int pid, byte[] section) {
      byte[] p = new byte[188];
      java.util.Arrays.fill(p, (byte) 0xFF);
      p[0] = 0x47;
      p[1] = (byte) (0x40 | (pid >> 8));
      p[2] = (byte) pid;
      p[3] = (byte) (0x10 | nextCc(pid));
      p[4] = 0; // pointer_field
      System.arraycopy(section, 0, p, 5, section.length);
      out.write(p, 0, 188);
    }

    private static byte[] withCrc(byte[] body) {
      int crc = Util.crc32(body, 0, body.length, 0xFFFFFFFF);
      byte[] s = java.util.Arrays.copyOf(body, body.length + 4);
      s[body.length] = (byte) (crc >> 24);
      s[body.length + 1] = (byte) (crc >> 16);
      s[body.length + 2] = (byte) (crc >> 8);
      s[body.length + 3] = (byte) crc;
      return s;
    }

    Ts pat(int version, int pmtPid) {
      byte[] body = {
        0x00, (byte) 0xB0, 13, 0x00, 0x01, (byte) (0xC1 | (version << 1)), 0x00, 0x00,
        0x00, 0x01, (byte) (0xE0 | (pmtPid >> 8)), (byte) pmtPid
      };
      psi(0, withCrc(body));
      return this;
    }

    Ts pmt(int pmtPid, int version, int esPid, int streamType) {
      byte[] body = {
        0x02, (byte) 0xB0, 18, 0x00, 0x01, (byte) (0xC1 | (version << 1)), 0x00, 0x00,
        (byte) (0xE0 | (esPid >> 8)), (byte) esPid, (byte) 0xF0, 0x00,
        (byte) streamType, (byte) (0xE0 | (esPid >> 8)), (byte) esPid, (byte) 0xF0, 0x00
      };
      psi(pmtPid, withCrc(body));
      return this;
    }

    /** One PES with one MPEG-1 Layer II frame (32 kbit/s, 48 kHz, mono: 96 bytes) at [pts]. */
    Ts mp2(int pid, long pts) {
      byte[] frame = new byte[96];
      frame[0] = (byte) 0xFF;
      frame[1] = (byte) 0xFD;
      frame[2] = (byte) 0x14;
      frame[3] = (byte) 0xC0;
      return pes(pid, pts, frame);
    }

    /** One PES with one ADTS frame (AAC LC, 48 kHz, stereo) at [pts]. */
    Ts adts(int pid, long pts) {
      int frame = 7 + 16;
      byte[] adts = new byte[frame];
      adts[0] = (byte) 0xFF;
      adts[1] = (byte) 0xF1;
      adts[2] = (byte) 0x4C;
      adts[3] = (byte) (0x80 | ((frame >> 11) & 0x3));
      adts[4] = (byte) (frame >> 3);
      adts[5] = (byte) (((frame & 0x7) << 5) | 0x1F);
      adts[6] = (byte) 0xFC;
      return pes(pid, pts, adts);
    }

    private Ts pes(int pid, long pts, byte[] adts) {
      int frame = adts.length;
      int pesLength = 3 + 5 + frame;
      byte[] pes = new byte[6 + pesLength];
      pes[2] = 0x01;
      pes[3] = (byte) 0xC0;
      pes[4] = (byte) (pesLength >> 8);
      pes[5] = (byte) pesLength;
      pes[6] = (byte) 0x80;
      pes[7] = (byte) 0x80;
      pes[8] = 5;
      pes[9] = (byte) (0x21 | ((pts >> 29) & 0x0E));
      pes[10] = (byte) (pts >> 22);
      pes[11] = (byte) (((pts >> 14) & 0xFE) | 1);
      pes[12] = (byte) (pts >> 7);
      pes[13] = (byte) (((pts << 1) & 0xFE) | 1);
      System.arraycopy(adts, 0, pes, 14, frame);
      byte[] p = new byte[188];
      p[0] = 0x47;
      p[1] = (byte) (0x40 | (pid >> 8));
      p[2] = (byte) pid;
      p[3] = (byte) (0x30 | nextCc(pid));
      int stuffing = 188 - 4 - 1 - pes.length;
      p[4] = (byte) stuffing;
      if (stuffing > 0) {
        p[5] = 0x00;
        for (int i = 6; i < 5 + stuffing; i++) p[i] = (byte) 0xFF;
      }
      System.arraycopy(pes, 0, p, 5 + stuffing, pes.length);
      out.write(p, 0, 188);
      return this;
    }
  }
}
