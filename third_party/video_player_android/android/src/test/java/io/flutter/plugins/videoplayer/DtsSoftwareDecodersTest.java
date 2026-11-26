// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).
package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.mock;

import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.Format;
import androidx.media3.common.Timeline;
import androidx.media3.common.TrackGroup;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.exoplayer.RendererCapabilities;
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo;
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector;
import androidx.media3.exoplayer.source.MediaSource;
import androidx.media3.exoplayer.source.TrackGroupArray;
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector;
import androidx.media3.exoplayer.trackselection.TrackSelectorResult;
import androidx.media3.exoplayer.upstream.BandwidthMeter;
import java.util.ArrayList;
import java.util.List;
import java.util.function.ToIntFunction;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;

/**
 * DTS goes to VesperTV's own decoder (onn 4K Pro, LOG-33PC25: the box's listed DTS decoder played
 * silent); every other format, and a DTS type FFmpeg can't decode, keeps the box's decoders. The
 * track picked stays the one picked when the box decoded DTS.
 */
@RunWith(RobolectricTestRunner.class)
@OptIn(markerClass = UnstableApi.class)
public class DtsSoftwareDecodersTest {
  private static final String DTS_HD = "audio/vnd.dts.hd";

  private static MediaCodecInfo decoder(String name, String mime, boolean hardware) {
    return MediaCodecInfo.newInstance(name, mime, mime, null, hardware, !hardware, !hardware,
        false, false);
  }

  private final List<String> asked = new ArrayList<>();

  /** The box: one decoder per type, hardware like Amlogic's vendor decoders. */
  private MediaCodecSelector box(boolean hardware) {
    return (mime, secure, tunnel) -> {
      asked.add(mime);
      return List.of(decoder("c2.amlogic.audio.decoder." + mime, mime, hardware));
    };
  }

  @Test
  public void dtsSkipsTheBoxDecoderWhenFfmpegDecodesIt() throws Exception {
    MediaCodecSelector selector =
        new DtsSoftwareDecoders(mime -> !mime.equals("audio/vnd.dts.uhd"), box(true));
    for (String mime : List.of("audio/vnd.dts", DTS_HD, "audio/vnd.dts.hd;profile=lbr")) {
      assertTrue(mime, selector.getDecoderInfos(mime, false, false).isEmpty());
    }
    // Asked only to learn its rank.
    assertEquals(List.of("audio/vnd.dts", DTS_HD, "audio/vnd.dts.hd;profile=lbr"), asked);
  }

  @Test
  public void dtsFfmpegCantDecodeKeepsTheBoxDecoder() throws Exception {
    MediaCodecSelector selector =
        new DtsSoftwareDecoders(mime -> !mime.equals("audio/vnd.dts.uhd"), box(true));
    assertEquals(1, selector.getDecoderInfos("audio/vnd.dts.uhd", false, false).size());
    // No FFmpeg at all (library failed to load): the box's decoders, as before.
    MediaCodecSelector noFfmpeg = new DtsSoftwareDecoders(mime -> false, box(true));
    assertEquals(1, noFfmpeg.getDecoderInfos(DTS_HD, false, false).size());
  }

  @Test
  public void otherFormatsAreUntouched() throws Exception {
    MediaCodecSelector selector = new DtsSoftwareDecoders(mime -> true, box(true));
    for (String mime : List.of("audio/ac3", "audio/eac3", "audio/mp4a-latm", "audio/true-hd",
        "video/hevc", "video/avc")) {
      List<MediaCodecInfo> infos = selector.getDecoderInfos(mime, false, false);
      assertEquals(mime, 1, infos.size());
      assertEquals("c2.amlogic.audio.decoder." + mime, infos.get(0).name);
    }
  }

  @Test
  public void onlyDtsMimesCount() {
    assertTrue(DtsSoftwareDecoders.isDts("audio/vnd.dts"));
    assertTrue(DtsSoftwareDecoders.isDts(DTS_HD));
    assertFalse(DtsSoftwareDecoders.isDts("audio/eac3"));
    assertFalse(DtsSoftwareDecoders.isDts(null));
  }

  // --- Which track plays: an English DTS-HD 7.1 track and an English AC3 2.0 track that nothing
  // else tells apart (no default flag, no role), like a movie + its commentary.

  private static final Format DTS =
      new Format.Builder().setId("dts").setSampleMimeType(DTS_HD).setChannelCount(8)
          .setSampleRate(48000).setLanguage("en").build();
  private static final Format AC3 =
      new Format.Builder().setId("ac3").setSampleMimeType("audio/ac3").setChannelCount(2)
          .setSampleRate(48000).setLanguage("en").build();

  private static RendererCapabilities renderer(String name, ToIntFunction<Format> support) {
    return new RendererCapabilities() {
      @Override public String getName() { return name; }
      @Override public int getTrackType() { return C.TRACK_TYPE_AUDIO; }
      @Override public int supportsFormat(Format format) { return support.applyAsInt(format); }
      @Override public int supportsMixedMimeTypeAdaptation() { return ADAPTIVE_NOT_SUPPORTED; }
    };
  }

  private static int handled(boolean hardware) {
    return RendererCapabilities.create(C.FORMAT_HANDLED,
        RendererCapabilities.ADAPTIVE_NOT_SEAMLESS, RendererCapabilities.TUNNELING_NOT_SUPPORTED,
        hardware ? RendererCapabilities.HARDWARE_ACCELERATION_SUPPORTED
            : RendererCapabilities.HARDWARE_ACCELERATION_NOT_SUPPORTED,
        RendererCapabilities.DECODER_SUPPORT_PRIMARY);
  }

  /**
   * The box's renderer: AC3 decoded in hardware, DTS not at all (its decoders are skipped); with
   * passthrough both go out as bitstream through the raw (software) decoder.
   */
  private static RendererCapabilities mediaCodec(boolean passthrough) {
    return renderer("MediaCodecAudioRenderer", f -> passthrough ? handled(false)
        : f == AC3 ? handled(true)
        : RendererCapabilities.create(C.FORMAT_UNSUPPORTED_SUBTYPE));
  }

  private static final RendererCapabilities FFMPEG =
      renderer("FfmpegAudioRenderer", f -> handled(false));

  /** "renderer:mime" of the audio track the selector picks. */
  private static String pick(DefaultTrackSelector selector, RendererCapabilities... renderers)
      throws Exception {
    // A TV box plays multichannel: media3 only caps channels to the device's on phones (and in
    // Robolectric, which isn't a TV).
    selector.setParameters(
        selector.buildUponParameters().setConstrainAudioChannelCountToDeviceCapabilities(false));
    selector.init(() -> {}, mock(BandwidthMeter.class));
    TrackSelectorResult result = selector.selectTracks(renderers,
        new TrackGroupArray(new TrackGroup(DTS), new TrackGroup(AC3)),
        new MediaSource.MediaPeriodId(new Object()), Timeline.EMPTY);
    for (int r = 0; r < renderers.length; r++) {
      if (result.selections[r] != null) {
        return renderers[r].getName() + ":" + result.selections[r].getSelectedFormat().sampleMimeType;
      }
    }
    return "none";
  }

  private DtsSoftwareDecoders decodersAfterAsking(boolean boxHardware) throws Exception {
    DtsSoftwareDecoders decoders = new DtsSoftwareDecoders(mime -> true, box(boxHardware));
    decoders.getDecoderInfos(DTS_HD, false, false);
    return decoders;
  }

  @Test
  public void dtsKeepsItsRankWhenTheBoxDecoderWasHardware() throws Exception {
    // Stock media3: the hardware AC3 2.0 beats the software DTS 7.1 (the regression).
    assertEquals("MediaCodecAudioRenderer:audio/ac3", pick(
        new DefaultTrackSelector(RuntimeEnvironment.getApplication()), mediaCodec(false), FFMPEG));
    // VesperTV's selector: DTS ranks as the box's hardware decoder did, more channels win.
    assertEquals("FfmpegAudioRenderer:" + DTS_HD, pick(new DtsSoftwareDecoders.TrackSelector(
        RuntimeEnvironment.getApplication(), decodersAfterAsking(true)), mediaCodec(false), FFMPEG));
  }

  @Test
  public void noHardwareBoxDecoderMeansStockRanking() throws Exception {
    // The box had no hardware DTS decoder: DTS was software before too, so nothing changes.
    assertEquals("MediaCodecAudioRenderer:audio/ac3", pick(new DtsSoftwareDecoders.TrackSelector(
        RuntimeEnvironment.getApplication(), decodersAfterAsking(false)), mediaCodec(false), FFMPEG));
  }

  @Test
  public void passthroughPicksLikeStock() throws Exception {
    // Passthrough: the box's renderer takes DTS as bitstream; its group never reaches FFmpeg, and
    // the pick is stock media3's.
    String stock = pick(
        new DefaultTrackSelector(RuntimeEnvironment.getApplication()), mediaCodec(true), FFMPEG);
    assertEquals("MediaCodecAudioRenderer:" + DTS_HD, stock);
    assertEquals(stock, pick(new DtsSoftwareDecoders.TrackSelector(
        RuntimeEnvironment.getApplication(), decodersAfterAsking(true)), mediaCodec(true), FFMPEG));
  }

  @Test
  public void rankingLeavesTheArrayAloneWithNothingToChange() throws Exception {
    DtsSoftwareDecoders decoders = new DtsSoftwareDecoders(mime -> true, box(true));
    int[][][] supports = {{{handled(false)}}};
    // Nothing skipped yet: same array back, untouched.
    assertTrue(supports == decoders.rankLikeTheBox(null, supports));
  }
}
