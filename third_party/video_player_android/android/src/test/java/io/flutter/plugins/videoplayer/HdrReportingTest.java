package io.flutter.plugins.videoplayer;

import static org.junit.Assert.*;
import android.media.MediaFormat;
import androidx.media3.common.C;
import androidx.media3.common.ColorInfo;
import androidx.media3.common.Format;
import java.util.HashMap;
import java.util.Map;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {28, 30})
public class HdrReportingTest {
  private Format input(Integer transfer) {
    Format.Builder builder = new Format.Builder().setSampleMimeType("video/hevc")
        .setCodecs("hvc1.2.4.H153.90").setWidth(3840).setHeight(2160);
    if (transfer != null) builder.setColorInfo(new ColorInfo.Builder()
        .setColorTransfer(transfer).build());
    return builder.build();
  }
  private MediaFormat output(Integer transfer) {
    MediaFormat format = MediaFormat.createVideoFormat("video/raw", 3840, 2160);
    if (transfer != null) format.setInteger(MediaFormat.KEY_COLOR_TRANSFER, transfer);
    return format;
  }
  private void frame(FrameRateProbe probe, Format format, MediaFormat output, int n) {
    probe.onVideoFrameAboutToBeRendered(n * 40000L, 0, format, output);
  }
  private Map<String, Object> stats(Format format, FrameRateProbe probe) {
    Map<String, Object> result = new HashMap<>();
    StatsBridge.addHdrStats(result, format, probe);
    return result;
  }
  @Test public void missingUnknownAndUnsupportedTransfersAreNotSdr() {
    assertEquals("unknown", StatsBridge.hdrKind(input(null)));
    assertEquals("unknown", StatsBridge.hdrKind(input(Format.NO_VALUE)));
    assertEquals("unknown", StatsBridge.decoderHdrKind(null));
    assertEquals("unknown", StatsBridge.decoderHdrKind(output(null)));
    assertEquals("unknown", StatsBridge.decoderHdrKind(output(0)));
    assertEquals("unknown", StatsBridge.decoderHdrKind(output(999)));
    MediaFormat noMime = new MediaFormat();
    noMime.setInteger(MediaFormat.KEY_COLOR_TRANSFER, C.COLOR_TRANSFER_ST2084);
    assertEquals("hdr10", StatsBridge.decoderHdrKind(noMime));
    assertEquals("sdr", StatsBridge.hdrKind(input(C.COLOR_TRANSFER_SDR)));
    assertEquals("sdr", StatsBridge.decoderHdrKind(output(C.COLOR_TRANSFER_SDR)));
  }
  @Test public void shieldUnknownHevcInputFallsBackToActualPqDecoderOutput() {
    Format input = input(null);
    FrameRateProbe probe = new FrameRateProbe();
    frame(probe, input, output(C.COLOR_TRANSFER_ST2084), 1);
    Map<String, Object> result = stats(input, probe);
    assertEquals("unknown", result.get("streamHdr"));
    assertEquals("hdr10", result.get("decoderHdr"));
    assertEquals("hdr10", result.get("hdr"));
    assertEquals("decoder", result.get("hdrSource"));
  }
  @Test public void explicitStreamHdrAndDecoderOutputAreBothRetained() {
    Format input = input(C.COLOR_TRANSFER_ST2084);
    FrameRateProbe probe = new FrameRateProbe();
    frame(probe, input, output(C.COLOR_TRANSFER_SDR), 1);
    Map<String, Object> result = stats(input, probe);
    assertEquals("hdr10", result.get("hdr"));
    assertEquals("stream", result.get("hdrSource"));
    assertEquals("sdr", result.get("decoderHdr"));
  }
  @Test public void metadataStillUpdatesAfterFpsSamplingAndHandlesInPlaceChanges() {
    Format input = input(null);
    FrameRateProbe probe = new FrameRateProbe();
    MediaFormat output = output(C.COLOR_TRANSFER_ST2084);
    for (int i = 0; i < 20; i++) frame(probe, input, output, i);
    assertEquals(25, probe.fps(), 0.001);
    output.setInteger(MediaFormat.KEY_COLOR_TRANSFER, C.COLOR_TRANSFER_HLG);
    frame(probe, input, output, 21);
    assertEquals("hlg", stats(input, probe).get("hdr"));
    frame(probe, input, null, 22);
    assertEquals("unknown", stats(input, probe).get("hdr"));
    assertEquals("unknown", stats(input, probe).get("hdrSource"));
  }
  @Test public void adaptiveFormatAndNewPlayerDoNotReuseOldDecoderMetadata() {
    Format first = input(null);
    Format second = first.buildUpon().setWidth(1920).build();
    FrameRateProbe probe = new FrameRateProbe();
    frame(probe, first, output(C.COLOR_TRANSFER_ST2084), 1);
    assertEquals("unknown", stats(second, probe).get("hdr"));
    frame(probe, second, output(C.COLOR_TRANSFER_SDR), 2);
    assertEquals("sdr", stats(second, probe).get("hdr"));
    assertEquals("unknown", stats(second, new FrameRateProbe()).get("hdr"));
    assertEquals("unknown", stats(null, probe).get("hdr"));
  }
  @Test public void tenBitBt2020AndMalformedOutputDoNotInventHdr() {
    MediaFormat output = output(null);
    output.setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT2020);
    output.setInteger("bit-depth", 10);
    assertEquals("unknown", StatsBridge.decoderHdrKind(output));
    output.setString(MediaFormat.KEY_COLOR_TRANSFER, "bad-value");
    assertEquals("unknown", StatsBridge.decoderHdrKind(output));
  }
  @Test public void dolbyVisionIdentificationDoesNotRequireColourInfo() {
    Format dv = input(null).buildUpon().setSampleMimeType("video/dolby-vision")
        .setCodecs("dvhe.08.06").build();
    assertEquals("dolby_vision", StatsBridge.hdrKind(dv));
    assertEquals(8, StatsBridge.dvProfile(dv));
    Map<String, Object> result = stats(dv, new FrameRateProbe());
    assertEquals("dolby_vision", result.get("hdr"));
    assertEquals("stream", result.get("hdrSource"));
  }
}
