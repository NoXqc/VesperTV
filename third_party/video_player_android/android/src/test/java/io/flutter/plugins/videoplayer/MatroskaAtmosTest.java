package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNotSame;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.DataReader;
import androidx.media3.common.Format;
import androidx.media3.common.MimeTypes;
import androidx.media3.common.util.ParsableByteArray;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.extractor.DefaultExtractorsFactory;
import androidx.media3.extractor.Extractor;
import androidx.media3.extractor.ExtractorsFactory;
import androidx.media3.extractor.TrackOutput;
import androidx.media3.extractor.mkv.MatroskaExtractor;
import androidx.media3.extractor.text.SubtitleParser;
import androidx.media3.test.utils.FakeExtractorOutput;
import androidx.media3.test.utils.FakeTrackOutput;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.Arrays;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

@RunWith(RobolectricTestRunner.class)
@OptIn(markerClass = UnstableApi.class)
public class MatroskaAtmosTest {
  /** An E-AC-3 independent frame (48 kHz, 5.1), with or without the JOC (Atmos) flag. */
  private static byte[] eac3Frame(boolean joc) {
    Bits b = new Bits(1536);
    b.put(0x0B77, 16).put(0, 2).put(0, 3).put(767, 11); // syncword, strmtyp, substreamid, frmsiz
    b.put(0, 2).put(3, 2).put(7, 3).put(1, 1); // fscod, numblkscod (6 blocks), acmod 3/2, lfeon
    b.put(16, 5).put(31, 5).put(0, 1); // bsid, dialnorm, compre
    b.put(0, 1).put(0, 1); // mixmdate, infomdate
    if (joc) {
      b.put(1, 1).put(1, 6).put(1, 8).put(16, 8); // addbsie, addbsil, JOC flag, complexity
    } else {
      b.put(0, 1);
    }
    return b.data;
  }

  private static final class Bits {
    final byte[] data;
    int pos;

    Bits(int size) {
      data = new byte[size];
    }

    Bits put(int value, int count) {
      for (int i = count - 1; i >= 0; i--, pos++) {
        if (((value >> i) & 1) != 0) data[pos / 8] |= (byte) (0x80 >> (pos % 8));
      }
      return this;
    }
  }

  private static Format eac3() {
    return new Format.Builder()
        .setId("2")
        .setSampleMimeType(MimeTypes.AUDIO_E_AC3)
        .setChannelCount(6)
        .setSampleRate(48000)
        .build();
  }

  private static Format hevc() {
    return new Format.Builder().setId("1").setSampleMimeType(MimeTypes.VIDEO_H265).build();
  }

  private static void write(TrackOutput track, byte[] sample, long timeUs) {
    track.sampleData(new ParsableByteArray(sample), sample.length);
    track.sampleMetadata(timeUs, C.BUFFER_FLAG_KEY_FRAME, sample.length, 0, null);
  }

  @Test
  public void readsTheJocFlagFromTheFrameHeader() {
    assertTrue(MatroskaAtmos.isJoc(eac3Frame(true)));
    assertFalse(MatroskaAtmos.isJoc(eac3Frame(false)));
    assertFalse(MatroskaAtmos.isJoc(new byte[1536]));
    assertFalse(MatroskaAtmos.isJoc(Arrays.copyOf(eac3Frame(true), 4)));
  }

  @Test
  public void atmosTrackGetsTheAtmosCodecsAndKeepsEverySample() {
    FakeExtractorOutput fake = new FakeExtractorOutput();
    MatroskaAtmos.Output out = new MatroskaAtmos.Output(fake);
    TrackOutput audio = out.track(2, C.TRACK_TYPE_AUDIO);
    audio.format(eac3());
    FakeTrackOutput real = fake.trackOutputs.get(2);
    assertNull(real.lastFormat); // held until the first frame

    byte[] first = eac3Frame(true);
    byte[] second = eac3Frame(true);
    second[1535] = 7;
    write(audio, first, 0);
    write(audio, second, 32000);

    assertEquals(MatroskaAtmos.ATMOS_CODECS, real.lastFormat.codecs);
    assertEquals(MimeTypes.AUDIO_E_AC3, real.lastFormat.sampleMimeType); // playback unchanged
    real.assertSampleCount(2);
    assertArrayEquals(first, real.getSampleData(0));
    assertArrayEquals(second, real.getSampleData(1));
    assertEquals(32000, real.getSampleTimeUs(1));

    audio.format(eac3()); // a repeated format keeps the verdict
    assertEquals(MatroskaAtmos.ATMOS_CODECS, real.lastFormat.codecs);
  }

  @Test
  public void plainEac3KeepsItsFormat() {
    FakeExtractorOutput fake = new FakeExtractorOutput();
    TrackOutput audio = new MatroskaAtmos.Output(fake).track(2, C.TRACK_TYPE_AUDIO);
    audio.format(eac3());
    write(audio, eac3Frame(false), 0);
    FakeTrackOutput real = fake.trackOutputs.get(2);
    assertNull(real.lastFormat.codecs);
    real.assertSampleCount(1);
  }

  @Test
  public void otherTracksPassStraightThrough() {
    FakeExtractorOutput fake = new FakeExtractorOutput();
    TrackOutput video = new MatroskaAtmos.Output(fake).track(1, C.TRACK_TYPE_VIDEO);
    video.format(hevc());
    assertEquals(MimeTypes.VIDEO_H265, fake.trackOutputs.get(1).lastFormat.sampleMimeType);
  }

  @Test
  public void aFrameReadFromTheFileWithBytesOfTheNextSampleAfterIt() throws IOException {
    FakeExtractorOutput fake = new FakeExtractorOutput();
    TrackOutput audio = new MatroskaAtmos.Output(fake).track(2, C.TRACK_TYPE_AUDIO);
    audio.format(eac3());
    byte[] frame = eac3Frame(true);
    byte[] file = Arrays.copyOf(frame, frame.length + 3);
    ByteArrayInputStream in = new ByteArrayInputStream(file);
    DataReader reader = (buffer, offset, length) -> {
      int n = in.read(buffer, offset, Math.min(length, 100)); // short reads, like the network
      return n < 0 ? C.RESULT_END_OF_INPUT : n;
    };
    int left = file.length;
    while (left > 0) left -= audio.sampleData(reader, left, false);
    audio.sampleMetadata(0, C.BUFFER_FLAG_KEY_FRAME, frame.length, 3, null);

    FakeTrackOutput real = fake.trackOutputs.get(2);
    assertEquals(MatroskaAtmos.ATMOS_CODECS, real.lastFormat.codecs);
    assertArrayEquals(frame, real.getSampleData(0));
  }

  @Test
  public void aHeldTrackGivesUpWhenItsFrameDoesNotCome() {
    FakeExtractorOutput fake = new FakeExtractorOutput();
    MatroskaAtmos.Output out = new MatroskaAtmos.Output(fake);
    TrackOutput video = out.track(1, C.TRACK_TYPE_VIDEO);
    TrackOutput audio = out.track(2, C.TRACK_TYPE_AUDIO);
    video.format(hevc());
    audio.format(eac3());
    for (int i = 0; i < MatroskaAtmos.GIVE_UP_SAMPLES; i++) write(video, new byte[] {1, 2}, i);
    Format released = fake.trackOutputs.get(2).lastFormat;
    assertNotNull(released);
    assertNull(released.codecs);
  }

  @Test
  public void aSeekDropsAHalfWrittenHeldSample() {
    FakeExtractorOutput fake = new FakeExtractorOutput();
    MatroskaAtmos.Output out = new MatroskaAtmos.Output(fake);
    TrackOutput audio = out.track(2, C.TRACK_TYPE_AUDIO);
    audio.format(eac3());
    audio.sampleData(new ParsableByteArray(new byte[] {9, 9, 9}), 3);
    out.dropPartialSamples();
    byte[] frame = eac3Frame(true);
    write(audio, frame, 0);
    FakeTrackOutput real = fake.trackOutputs.get(2);
    assertEquals(MatroskaAtmos.ATMOS_CODECS, real.lastFormat.codecs);
    assertArrayEquals(frame, real.getSampleData(0));
  }

  /**
   * The start of a TrueHD access unit with a major sync (48 kHz): [substreams] in the high nibble
   * of byte 20, [substreamInfo] in byte 21 (top bit = 16-channel presentation, Atmos).
   */
  private static byte[] trueHdFrame(int substreams, int substreamInfo) {
    byte[] f = new byte[64];
    f[0] = 0x40; // check nibble + access unit length (in 16-bit words)
    f[4] = (byte) 0xF8;
    f[5] = 0x72;
    f[6] = 0x6F;
    f[7] = (byte) 0xBA; // TrueHD (0xBB = MLP)
    f[12] = (byte) 0xB7;
    f[13] = 0x52; // signature
    f[20] = (byte) (substreams << 4);
    f[21] = (byte) substreamInfo;
    return f;
  }

  private static Format trueHd() {
    return new Format.Builder()
        .setId("2")
        .setSampleMimeType(MimeTypes.AUDIO_TRUEHD)
        .setChannelCount(8)
        .setSampleRate(48000)
        .build();
  }

  @Test
  public void readsTheSixteenChannelPresentationFromTheTrueHdMajorSync() {
    assertTrue(MatroskaAtmos.isTrueHdAtmos(trueHdFrame(4, 0x80 | 0x40)));
    assertFalse(MatroskaAtmos.isTrueHdAtmos(trueHdFrame(3, 0x40))); // plain 7.1
    assertFalse(MatroskaAtmos.isTrueHdAtmos(trueHdFrame(2, 0x80))); // no 4th substream
    byte[] mlp = trueHdFrame(4, 0x80);
    mlp[7] = (byte) 0xBB;
    assertFalse(MatroskaAtmos.isTrueHdAtmos(mlp));
    byte[] badSignature = trueHdFrame(4, 0x80);
    badSignature[13] = 0;
    assertFalse(MatroskaAtmos.isTrueHdAtmos(badSignature));
    assertFalse(MatroskaAtmos.isTrueHdAtmos(Arrays.copyOf(trueHdFrame(4, 0x80), 21)));
  }

  @Test
  public void trueHdAtmosTrackGetsItsCodecsAndKeepsItsMimeType() {
    FakeExtractorOutput fake = new FakeExtractorOutput();
    TrackOutput audio = new MatroskaAtmos.Output(fake).track(2, C.TRACK_TYPE_AUDIO);
    audio.format(trueHd());
    FakeTrackOutput real = fake.trackOutputs.get(2);
    assertNull(real.lastFormat); // held until the first frame
    byte[] frame = trueHdFrame(4, 0xC0);
    write(audio, frame, 0);
    assertEquals(MatroskaAtmos.TRUEHD_ATMOS_CODECS, real.lastFormat.codecs);
    assertEquals(MimeTypes.AUDIO_TRUEHD, real.lastFormat.sampleMimeType);
    assertArrayEquals(frame, real.getSampleData(0));
  }

  @Test
  public void plainTrueHdKeepsItsFormat() {
    FakeExtractorOutput fake = new FakeExtractorOutput();
    TrackOutput audio = new MatroskaAtmos.Output(fake).track(2, C.TRACK_TYPE_AUDIO);
    audio.format(trueHd());
    write(audio, trueHdFrame(3, 0x40), 0);
    FakeTrackOutput real = fake.trackOutputs.get(2);
    assertNull(real.lastFormat.codecs);
    real.assertSampleCount(1);
  }

  @Test
  public void onlyTheMatroskaExtractorIsWrapped() {
    Extractor[] extractors =
        MatroskaAtmos.wrap(new DefaultExtractorsFactory()).createExtractors();
    int wrapped = 0;
    for (Extractor e : extractors) {
      if (e.getUnderlyingImplementation() instanceof MatroskaExtractor) {
        assertNotSame(e, e.getUnderlyingImplementation());
        wrapped++;
      }
    }
    assertEquals(1, wrapped);
  }

  @Test
  public void subtitleSettingsReachTheRealFactory() {
    ExtractorsFactory real = mock(ExtractorsFactory.class);
    SubtitleParser.Factory parsers = mock(SubtitleParser.Factory.class);
    ExtractorsFactory wrapped = MatroskaAtmos.wrap(real);
    assertSame(wrapped, wrapped.setSubtitleParserFactory(parsers));
    assertSame(wrapped, wrapped.experimentalSetTextTrackTranscodingEnabled(true));
    verify(real).setSubtitleParserFactory(parsers);
    verify(real).experimentalSetTextTrackTranscodingEnabled(true);
  }
}
