package io.flutter.plugins.videoplayer;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;
import androidx.media3.common.C;
import androidx.media3.common.ColorInfo;
import androidx.media3.common.Format;
import androidx.media3.exoplayer.mediacodec.MediaCodecInfo;
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector;
import io.flutter.plugins.videoplayer.platformview.FormulerVideoRenderer;
import java.util.List;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {28, 30})
public class FormulerVideoRendererTest {
  private static final String REALTEK = "OMX.realtek.video.dec.hevc";
  private ColorInfo color(int transfer, int depth, byte[] mastering) {
    return new ColorInfo.Builder().setColorTransfer(transfer).setColorSpace(C.COLOR_SPACE_BT2020)
        .setColorRange(C.COLOR_RANGE_LIMITED).setLumaBitdepth(depth).setChromaBitdepth(depth)
        .setHdrStaticInfo(mastering).build();
  }
  private Format format(ColorInfo color) {
    return new Format.Builder().setSampleMimeType("video/hevc").setCodecs("hvc1.2.4.L153.B0")
        .setWidth(3840).setHeight(2160).setFrameRate(60).setColorInfo(color).build();
  }
  @Test public void redundantHdrDepthMetadataMayReuseButHdmiColourChangesMayNot() {
    Format hdr = format(color(C.COLOR_TRANSFER_ST2084, 10, new byte[]{1}));
    Format redundant = format(color(C.COLOR_TRANSFER_ST2084, Format.NO_VALUE, new byte[]{1}));
    assertTrue(FormulerVideoRenderer.equivalentHdr(REALTEK, hdr, redundant));
    assertFalse(FormulerVideoRenderer.equivalentHdr("OMX.Nvidia.h265.decode", hdr, redundant));
    assertFalse(FormulerVideoRenderer.equivalentHdr(REALTEK, hdr,
        format(color(C.COLOR_TRANSFER_SDR, 10, new byte[]{1}))));
    assertFalse(FormulerVideoRenderer.equivalentHdr(REALTEK, hdr,
        format(color(C.COLOR_TRANSFER_HLG, 10, new byte[]{1}))));
    assertFalse(FormulerVideoRenderer.equivalentHdr(REALTEK, hdr, format(null)));
    assertFalse(FormulerVideoRenderer.equivalentHdr(REALTEK, hdr,
        format(color(C.COLOR_TRANSFER_ST2084, 10, new byte[]{2}))));
    assertFalse(FormulerVideoRenderer.equivalentHdr(REALTEK, hdr,
        redundant.buildUpon().setWidth(1920).build()));
    assertFalse(FormulerVideoRenderer.equivalentHdr(REALTEK, hdr,
        redundant.buildUpon().setCodecs("hvc1.1.6.L153.90").build()));
    assertFalse(FormulerVideoRenderer.equivalentHdr(REALTEK, hdr,
        format(color(C.COLOR_TRANSFER_ST2084, 8, new byte[]{1}))));
  }
  @Test public void realtekGoesFirstWithoutRemovingFallbacksOrChangingOtherFormats() throws Exception {
    MediaCodecInfo software = MediaCodecInfo.newInstance("c2.android.hevc.decoder", "video/hevc",
        "video/hevc", null, false, true, false, false, false);
    MediaCodecInfo hardware = MediaCodecInfo.newInstance(REALTEK, "video/hevc", "video/hevc",
        null, true, false, true, false, false);
    MediaCodecSelector original = (mime, secure, tunnel) -> List.of(software, hardware);
    MediaCodecSelector selected = FormulerVideoRenderer.realtekFirst(original);
    assertEquals(List.of(hardware, software), selected.getDecoderInfos("video/hevc", false, false));
    assertEquals(List.of(software, hardware), selected.getDecoderInfos("video/avc", false, false));
    assertEquals(List.of(software, hardware), selected.getDecoderInfos("video/hevc", true, false));
    assertEquals(List.of(software, hardware), selected.getDecoderInfos("video/hevc", false, true));
  }
}
