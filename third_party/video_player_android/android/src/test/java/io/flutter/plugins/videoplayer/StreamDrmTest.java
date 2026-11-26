// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).

package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import android.net.Uri;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.datasource.DefaultHttpDataSource;
import androidx.media3.exoplayer.source.MediaSource;
import androidx.test.core.app.ApplicationProvider;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

/** VesperTV patch: the playlist's DRM header becomes ExoPlayer's DRM setup, never a request header. */
@RunWith(RobolectricTestRunner.class)
public final class StreamDrmTest {
  // What Dart's StreamDrm.encode() sends for RTP 1 (m3upt.com, 2026-11-22).
  private static final String CLEARKEY =
      "{\"system\":\"clearkey\",\"license\":{\"keys\":[{\"kty\":\"oct\","
          + "\"kid\":\"-ANRoRe6Pxeibg6M1NwAxA\",\"k\":\"oiJt70vI8kneLa82t8ErHg\"}],"
          + "\"type\":\"temporary\"}}";
  private static final String MPD =
      "https://streaming-live.rtp.pt/liverepeater/rtpClean1HD.smil/manifest.mpd";

  private static DefaultHttpDataSource.Factory mockHttpFactory() {
    DefaultHttpDataSource.Factory httpFactory = mock(DefaultHttpDataSource.Factory.class);
    when(httpFactory.setUserAgent(any())).thenReturn(httpFactory);
    when(httpFactory.setAllowCrossProtocolRedirects(anyBoolean())).thenReturn(httpFactory);
    when(httpFactory.setDefaultRequestProperties(anyMap())).thenReturn(httpFactory);
    return httpFactory;
  }

  @Test
  public void clearKeyHeaderBecomesTheMediaItemsDrmAndIsNeverSent() {
    Map<String, String> headers = new HashMap<>();
    headers.put("Origin", "https://www.rtp.pt");
    headers.put(StreamDrm.HEADER, CLEARKEY);
    VideoAsset asset =
        VideoAsset.fromRemoteUrl(MPD, VideoAsset.StreamingFormat.UNKNOWN, headers, null);

    MediaItem.DrmConfiguration drm =
        Objects.requireNonNull(asset.getMediaItem().localConfiguration).drmConfiguration;
    assertNotNull(drm);
    assertEquals(C.CLEARKEY_UUID, drm.scheme);
    assertNull(drm.licenseUri);
    assertTrue(drm.playClearContentWithoutKey);

    DefaultHttpDataSource.Factory mockFactory = mockHttpFactory();
    ((HttpVideoAsset) asset)
        .getMediaSourceFactory(ApplicationProvider.getApplicationContext(), mockFactory);
    Map<String, String> sent = new HashMap<>();
    sent.put("Origin", "https://www.rtp.pt");
    verify(mockFactory).setDefaultRequestProperties(sent);
  }

  @Test
  public void clearKeyDashSourceIsBuiltWithTheDrmSessions() {
    Map<String, String> headers = new HashMap<>();
    headers.put(StreamDrm.HEADER, CLEARKEY);
    VideoAsset asset =
        VideoAsset.fromRemoteUrl(MPD, VideoAsset.StreamingFormat.UNKNOWN, headers, null);

    MediaSource source =
        asset
            .getMediaSourceFactory(ApplicationProvider.getApplicationContext())
            .createMediaSource(asset.getMediaItem());
    assertEquals(
        Uri.parse(MPD), Objects.requireNonNull(source.getMediaItem().localConfiguration).uri);
    assertTrue(source.getClass().getSimpleName().contains("Dash"));
  }

  @Test
  public void licenseServerGoesOnTheMediaItemWithItsHeaders() {
    Map<String, String> headers = new HashMap<>();
    headers.put(
        StreamDrm.HEADER,
        "{\"system\":\"widevine\",\"url\":\"https://license.example/wv\","
            + "\"headers\":{\"X-Token\":\"abc\"}}");
    VideoAsset asset =
        VideoAsset.fromRemoteUrl(MPD, VideoAsset.StreamingFormat.UNKNOWN, headers, null);

    MediaItem.DrmConfiguration drm =
        Objects.requireNonNull(asset.getMediaItem().localConfiguration).drmConfiguration;
    assertNotNull(drm);
    assertEquals(C.WIDEVINE_UUID, drm.scheme);
    assertEquals(Uri.parse("https://license.example/wv"), drm.licenseUri);
    assertEquals("abc", drm.licenseRequestHeaders.get("X-Token"));
    asset
        .getMediaSourceFactory(ApplicationProvider.getApplicationContext())
        .createMediaSource(asset.getMediaItem());
  }

  @Test
  public void brokenHeaderIsDroppedAndPlaysWithoutDrm() {
    Map<String, String> headers = new HashMap<>();
    headers.put(StreamDrm.HEADER, "not json");
    assertNull(StreamDrm.take(headers));
    assertFalse(headers.containsKey(StreamDrm.HEADER));

    Map<String, String> unknown = new HashMap<>();
    unknown.put(StreamDrm.HEADER, "{\"system\":\"fairplay\",\"url\":\"https://x\"}");
    VideoAsset asset =
        VideoAsset.fromRemoteUrl(MPD, VideoAsset.StreamingFormat.UNKNOWN, unknown, null);
    assertNull(Objects.requireNonNull(asset.getMediaItem().localConfiguration).drmConfiguration);
  }

  @Test
  public void streamWithoutDrmIsUnchanged() {
    VideoAsset asset =
        VideoAsset.fromRemoteUrl(
            "https://flutter.dev/video.mp4",
            VideoAsset.StreamingFormat.UNKNOWN,
            new HashMap<>(),
            null);
    assertNull(Objects.requireNonNull(asset.getMediaItem().localConfiguration).drmConfiguration);
  }
}
