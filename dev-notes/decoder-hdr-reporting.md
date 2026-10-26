# Decoder HDR reporting (Codex, 2026-10-26; unreleased)

Owner's Shield log LOG-4J9MQM reports 3840x2160 HEVC with `color unknown`,
while the TV photo shows HDR. StatsBridge formerly mapped missing/unsupported
transfer information to SDR; that does not establish the source is SDR.

- FrameRateProbe already receives VideoFrameMetadataListener callbacks with both
  Media3 input Format and decoder output MediaFormat. It now observes HDR on every
  rendered-frame callback, including after the first16-frame FPS sample, without
  configuring the codec, surface, display or source. One immutable volatile sample
  crosses to the stats reader. A new probe on source replacement clears old data;
  current-input matching guards adaptive format transitions before the next frame.
- StatsBridge retains streamHdr and decoderHdr independently. Known stream evidence
  wins the existing hdr field; decoder evidence is a fallback only when stream
  metadata is unknown. hdrSource identifies stream/decoder/unknown. Both-unknown
  stays unknown. SDR requires an explicit SDR transfer; ten-bit/HEVC/BT.2020/display
  support alone does not establish HDR. Missing/malformed optional output keys are safe.
- Data pool shows Video HDR with a translated stream/decoder suffix. If both readings
  are known and disagree, Decoder HDR is shown separately (these describe different
  stages and are not proof of a playback fault). Dolby Vision profile/base-layer text
  is preserved. Unknown is translated instead of defaulting to No(SDR).
- DataPoolCard discards an asynchronous sample if its controller changed while
  tracks/stats were being read. This avoids showing an old source's result after zap.
- NativeVideoSurface diagnostics include both readings and hdrSource in Send log,
  even when Data pool is closed, so the Shield retest can distinguish missing
  container metadata from missing decoder output without relying on a photo.
- No HDMI active-HDR guarantee. Android Display HDR capabilities remain support only;
  decoder output fields can also be absent on particular codecs/devices. This change
  needs a fresh Shield test log to establish whether its decoder supplies those keys.

Primary references checked: Android MediaFormat KEY_COLOR_TRANSFER and Media3
VideoFrameMetadataListener. Tests: HdrReportingTest(Android28/30) and
video_hdr_report_test.dart, plus normal analyze/full Flutter suite (HANDOFF.md).
