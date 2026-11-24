# DRM (ClearKey / Widevine / PlayReady) from M3U playlists

Branch `claude/drm-clearkey` (2026-11-22). Asked by a user with
`https://m3upt.com/iptv`: 964 Portuguese channels, 67 of them DASH `.mpd`
with ClearKey keys in Kodi `#KODIPROP` lines (RTP 1/2, SIC, …).

## What the playlist says

```
#EXTINF:-1 group-title="TV" tvg-id="RTP1.pt" …,RTP 1
#EXTVLCOPT:http-user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:152.0) …"
#EXTVLCOPT:http-origin=https://www.rtp.pt
#EXTVLCOPT:http-referrer=https://www.rtp.pt/play/direto/rtp1
#KODIPROP:inputstream.adaptive.license_type=org.w3.clearkey
#KODIPROP:inputstream.adaptive.license_key=<kid hex>:<key hex>
https://streaming-live.rtp.pt/liverepeater/rtpClean1HD.smil/manifest.mpd
```

The manifests are live DASH, CENC (`urn:mpeg:dash:mp4protection:2011` with a
`cenc:default_KID`, plus Widevine and PlayReady entries). ExoPlayer turns the
default_KID into a common PSSH, which ClearKey matches.

Before this branch the parser ignored every `#EXTVLCOPT` line except
`sub-file=` and every `#KODIPROP`, so these channels had neither keys nor
headers.

## How it flows

1. `M3uParser` (`_ParseState`): `#EXTVLCOPT:http-user-agent / http-referrer
   / http-referer / http-origin / http-cookie` (quotes stripped), `#EXTHTTP:{json}`,
   `#KODIPROP:inputstream.adaptive.{stream,manifest,common}_headers` become
   headers; the other `inputstream.adaptive.*` props go to
   `StreamDrm.fromKodiProps`. Props may sit before or after `#EXTINF`; they
   reset after the URL line.
2. `StreamDrm` (`lib/models/stream_drm.dart`) reads `license_type` +
   `license_key`, Kodi 21 `drm_legacy` and `drm` JSON. ClearKey keys: `kid:key`
   pairs (hex, UUID or base64url), `{"kid":"key"}`, or a JWK set. A URL =
   license server (Widevine/PlayReady/ClearKey; `url|headers|…`, only the plain
   raw-challenge kind). Encoded as JSON under the reserved header
   **`X-VesperTV-DRM`**.
3. `Channel.playlistHeaders` (new, saved as `headers` in toJson) holds what the
   entry declared incl. the DRM header; `Channel.httpHeaders` = playlist headers
   + app-added ones (Dispatcharr X-API-Key, add-on proxy headers), **not saved**:
   recently-played files sync through the relay. `copyWith(httpHeaders:)` = the
   whole set (another copy's stream), playlist headers dropped.
4. Every path already moves url + httpHeaders together (Sources, copy fallback,
   desktop recovery), and `_reuseNativeLive` already skips channels with headers
   (replaceLive takes only the URL). Multiview now passes `channel.httpHeaders`
   (it passed none).
5. Android: `StreamDrm.java` — `HttpVideoAsset` takes the header out before any
   request (`StreamDrm.take`), sets `MediaItem.DrmConfiguration`
   (playClearContentWithoutKey) and a `DrmSessionManagerProvider`: ClearKey keys =
   `DefaultDrmSessionManager` + `LocalMediaDrmCallback(JWK set)` (no server);
   license server = `DefaultDrmSessionManagerProvider` over the stream's HTTP
   factory (same UA/Referer/Origin). logcat tag `VesperDrm`.
6. Errors: `ERROR_CODE_DRM_*` -> "This channel is protected (DRM) and couldn't be
   unlocked…" (7 languages). An **empty reply** (RTP outside Portugal: `204`, no
   body -> MANIFEST_MALFORMED): `sniffStream` kind `empty` only for a success status
   (< 400) with zero bytes, asked with the player's headers (UA `ExoPlayer` + channel
   headers, DRM marker removed) -> "The server sent an empty answer instead of the
   video. This channel may only play in its own country." (+959). The sniff now runs
   on every parse failure (and after Reload); only the HLS / link retries stay once
   per link. Owner: RTP 1 plays on a Portugal VPN.

## Not done / limits

- **Windows / macOS / Linux / iOS / Apple TV: DRM channels are not opened**
  (`openDesktopStream` logs `DesktopPlayer: … is DRM-protected`). The bundled
  Windows libmpv (mpv 0.36, FFmpeg n6.0, 2023) has dashdec's
  `cenc_decryption_key` (one key), but it **segfaulted on both test manifests
  (RTP 1, SIC), with or without the key**; a clear HLS stream played in the same
  ctypes harness. So plain `.mpd` links may crash the desktop player today
  regardless of DRM (not checked in the app). A newer libmpv (FFmpeg 7.1+:
  `cenc_decryption_keys` per KID) would be the way.
- Pipe headers on the URL (`url|User-Agent=…&Referer=…`) are still not parsed.
- M3U movies/episodes stored in the catalog DB (big M3U) don't keep headers/DRM
  (live channels do: they go through Channel.toJson).
- A playlist added before this build needs one Update Content to pick up the
  headers / keys (the saved live list has none).
- Widevine works only where the box has Widevine and the license server takes a
  raw challenge; `B{SSM}` / JSON-wrapped licenses are not handled.

## Tested

- Emulator (API 34, `vesper_bg_test`, +958): m3upt playlist added, **SIC (ClearKey
  DASH, CloudFront) plays**; logcat `VesperDrm: stream DRM: clearkey (playlist keys)`,
  Android starts `vendor.drm-clearkey-service`. RTP 1 failed only because RTP's
  server started answering **`204 Unknown Error` with no body** to every request from
  this PC (curl too, same request that returned the MPD an hour earlier) and to the VPS (US,
  never used before): RTP refuses outside Portugal (geo), not a rate limit. Owner's Xiaomi phone
  (+958): SIC plays, RTP 1 = MANIFEST_MALFORMED (that empty 204).

## Tests

`test/stream_drm_test.dart` (parser, every key spelling, JWK, save/restore,
copies), native `StreamDrmTest` (header never sent, ClearKey/Widevine media item,
DASH source builds).
