// Copyright (C) 2026 VesperTV contributors
// SPDX-License-Identifier: GPL-3.0-only
// VesperTV's own file: GNU GPL v3 with the App Store exception, not BSD (see
// LICENSE-VESPERTV.md in the video_player_android folder).

package io.flutter.plugins.videoplayer;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.media3.common.C;
import androidx.media3.common.MediaItem;
import androidx.media3.common.util.UnstableApi;
import androidx.media3.datasource.DataSource;
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager;
import androidx.media3.exoplayer.drm.DefaultDrmSessionManagerProvider;
import androidx.media3.exoplayer.drm.DrmSessionManagerProvider;
import androidx.media3.exoplayer.drm.FrameworkMediaDrm;
import androidx.media3.exoplayer.drm.LocalMediaDrmCallback;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * VesperTV patch: DRM a playlist entry declares (Kodi {@code #KODIPROP} lines, parsed by Dart's
 * {@code StreamDrm}). Dart sends it as the reserved header {@link #HEADER} (JSON); {@link #take}
 * removes it before any request is made, so it never reaches a server.
 *
 * <p>ClearKey with the keys in the playlist (m3upt.com's RTP / SIC DASH channels): ExoPlayer's
 * {@link LocalMediaDrmCallback} answers every key request with the playlist's JWK set, so no
 * license server is involved. Widevine / PlayReady / ClearKey with a license server go through
 * ExoPlayer's own HTTP callback, over the stream's data source (same User-Agent, Referer, Origin).
 */
@OptIn(markerClass = UnstableApi.class)
final class StreamDrm {
  static final String HEADER = "X-VesperTV-DRM";

  @NonNull final UUID scheme;
  /** ClearKey's JWK set ({"keys":[{"kty":"oct","kid":…,"k":…}]}), or null for a server. */
  @Nullable private final byte[] clearKeyLicense;

  @Nullable private final String licenseUrl;
  @NonNull private final Map<String, String> licenseHeaders;

  private StreamDrm(
      @NonNull UUID scheme,
      @Nullable byte[] clearKeyLicense,
      @Nullable String licenseUrl,
      @NonNull Map<String, String> licenseHeaders) {
    this.scheme = scheme;
    this.clearKeyLicense = clearKeyLicense;
    this.licenseUrl = licenseUrl;
    this.licenseHeaders = licenseHeaders;
  }

  /** Removes {@link #HEADER} from {@code headers} and reads it; null without one (or broken). */
  @Nullable
  static StreamDrm take(@NonNull Map<String, String> headers) {
    String raw = headers.remove(HEADER);
    if (raw == null) return null;
    try {
      JSONObject json = new JSONObject(raw);
      UUID scheme = schemeOf(json.optString("system"));
      if (scheme == null) return null;
      JSONObject license = json.optJSONObject("license");
      String url = json.has("url") ? json.getString("url") : null;
      Map<String, String> licenseHeaders = new HashMap<>();
      JSONObject h = json.optJSONObject("headers");
      if (h != null) {
        for (Iterator<String> it = h.keys(); it.hasNext(); ) {
          String name = it.next();
          licenseHeaders.put(name, h.getString(name));
        }
      }
      byte[] clearKey =
          license == null ? null : license.toString().getBytes(StandardCharsets.UTF_8);
      if (clearKey == null && url == null) return null;
      if (clearKey != null && !C.CLEARKEY_UUID.equals(scheme)) return null;
      return new StreamDrm(scheme, clearKey, url, Collections.unmodifiableMap(licenseHeaders));
    } catch (JSONException e) {
      android.util.Log.w("VesperDrm", "unreadable DRM header: " + e.getMessage());
      return null;
    }
  }

  @Nullable
  private static UUID schemeOf(@NonNull String system) {
    switch (system) {
      case "clearkey":
        return C.CLEARKEY_UUID;
      case "widevine":
        return C.WIDEVINE_UUID;
      case "playready":
        return C.PLAYREADY_UUID;
      default:
        return null;
    }
  }

  /** What the media item says about its DRM (the license server, when there is one). */
  @NonNull
  MediaItem.DrmConfiguration configuration() {
    MediaItem.DrmConfiguration.Builder builder =
        new MediaItem.DrmConfiguration.Builder(scheme)
            // Live DASH often starts with clear segments: play them while the keys load.
            .setPlayClearContentWithoutKey(true);
    if (licenseUrl != null) {
      builder.setLicenseUri(licenseUrl).setLicenseRequestHeaders(licenseHeaders);
    }
    return builder.build();
  }

  /** The DRM sessions for this stream; license requests use {@code http} (the stream's headers). */
  @NonNull
  DrmSessionManagerProvider sessionManagers(@NonNull DataSource.Factory http) {
    final byte[] license = clearKeyLicense;
    if (license != null) {
      return item ->
          new DefaultDrmSessionManager.Builder()
              .setUuidAndExoMediaDrmProvider(C.CLEARKEY_UUID, FrameworkMediaDrm.DEFAULT_PROVIDER)
              .build(new LocalMediaDrmCallback(license));
    }
    DefaultDrmSessionManagerProvider provider = new DefaultDrmSessionManagerProvider();
    provider.setDrmHttpDataSourceFactory(http);
    return provider;
  }

  /** Send log / logcat: the scheme and whether keys or a server, never the keys. */
  @NonNull
  @Override
  public String toString() {
    String name =
        C.CLEARKEY_UUID.equals(scheme)
            ? "clearkey"
            : C.WIDEVINE_UUID.equals(scheme) ? "widevine" : "playready";
    return name + (clearKeyLicense != null ? " (playlist keys)" : " (license server)");
  }
}
