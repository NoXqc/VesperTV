# IPTV Data pool file size (Codex, 2026-10-27)

Owner requested file sizes for IPTV movies and episodes, like Media Hub.
Owner explicitly authorised a limited patched-player exception for StreamStats,
HttpVideoAsset and StatsBridge after the automatic approval check blocked it.

- Android Data pool adds File size for non-live, non-transient playback. Uses the
  current playback channel, including M3U movies and auto-advanced episodes.
- StreamStats reads the player's own response headers on transfer start. No HEAD,
  range probe, second player, playlist scan, URL logging or extra connection.
- A valid Content-Range total wins over partial Content-Length. Without a range,
  Content-Length is accepted only for an unbounded request starting at zero.
- Unknown/malformed/zero/overflow totals, compressed responses and HTML/JSON/XML
  error/manifest replies stay unavailable. It is never downloaded bytes or a
  bitrate/duration estimate.
- HttpVideoAsset enables this only for progressive files, excluding explicit and
  URI-inferred HLS/DASH/Smooth Streaming. Only the original resource's DataSpec
  counts; redirects still work because DataSpec retains the initial request URI.
- StatsBridge returns fileSizeBytes (a Java long) only when positive. Counters are
  per asset; a new file starts unknown. Native playback configuration is unchanged.
- Data pool uses that total, then existing selected Media Hub size metadata when
  supplied, otherwise File size unavailable. Live TV/catch-up/trailers omit the row.
- MediaFileInfo.formatSize shares the existing decimal KB/MB/GB/TB formatting.
- The existing bridge is polled while the card is shown; a file whose server never
  reports a total stays unavailable (especially segmented IPTV HLS).

Verification
- test/data_pool_file_size_test.dart: movies/episodes/M3U, large sizes, unknown
  totals vs downloaded bytes, metadata fallback, hidden live row and title changes.
- Native StreamStatsTest: 13 cases, plus existing VideoAssetTest; Java21 required.
- Exact checks/commit in main-checkout HANDOFF.md. No new setting/version/APK.
