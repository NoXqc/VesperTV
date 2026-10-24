# Handoff batch, beta +431 (Codex, 2026-10-24)

Owner authorised all tasks in the main checkout's HANDOFF, then explicitly requested
the Formuler HEVC flash work, Home history removal and episode source resume.
Branch: `codex/handoff-fixes`, based on Cinemeta toggle `831c524` and native +428.
Merged `claude/diag-logs` through `37a847b` and subtitle import `cb26ac2`.
Only the existing prerelease is in scope. Main/stable and Discord remain untouched.

## Sports search and Home RangeError

- `SportsChannelMatcher.prepare` builds private indexes, publishes them atomically,
  and `matchDay` uses an immutable snapshot across every await. Previously another
  caller could replace `_channels` with a smaller list while the first caller still
  held indexes into the larger list. A regression replaces 5,000 channels with one
  during the guide await and verifies the original result without an index error.
  This reproduces a plausible cause of the reported Home row RangeError; confirming
  that user's precise stack still requires a fresh log.
- Scan only a bounded 36-hour window anchored on the first relevant game (or the
  explicitly requested future day). Mixed My Teams schedules cannot extend it to
  weeks. Opening a distant future game performs its own bounded lookup. Round query
  windows out to hours for stable keys; retain the per-game precise checks afterwards.
- Database schema version 2 preserves existing rows. The start index is created
  lazily on first Sports lookup, outside database opening / splash. This one-time
  build can still cost time on a large guide.
- Replace SQL's hundreds of `%term%` comparisons with indexed, title-only six-hour
  slices, 1,000-row keyset pages and event-loop yields. Cache six slice futures for
  15 minutes across callers regardless of term sets; invalidate on writes/deletes.
  Literal case-insensitive matching runs via `compute`, outside the UI isolate and
  sqflite connection. No whole-guide load. Result cache keys include EPG revision.
- Stale pick objects reload saved picks before editing, so saving another game no
  longer erases a newer pick. Sports reloads picks before rematching; explicit picks
  outrank manually added source suggestions. Optional per-viewer **Prefer highest
  quality** ranks quality copies of the same channel; no broadcaster-rights claims.
- Manual benchmark: `flutter test test/benchmarks/sports_scan_benchmark.dart`. Synthetic
  desktop guide: 245,000 rows, 7,705 channels, 298 terms; identical 36-hour results.
  Old SQL 270 ms; indexed cold read/match 418 ms; cached slice read with 14 terms
  33 ms. These are desktop debug timings, not a claimed Formuler/Shield speedup.
  The main gains are bounded work, shared reads and no long SQL title statement.
  Check the real `EpgDatabase: title scan` lines on both boxes before asserting a target.
- LOG-WPNY83's 11 lock warnings are under **Previous session**, not evidence of
  a remaining +430 startup lock burst. Preserve startup timing; no speculative delay.

## Media Hub / Home / Windows

- `playArchiveTitle` saves and restores stream fingerprints for episodes using the
  same episode channel ID as saved progress. Fresh links are requested; exact URL
  fingerprint or one unambiguous same-provider/full-description match is probed.
  Missing/unreachable choices fall back; tokens and playable URLs are not persisted
  in the preference. Next/auto-advance also remembers the stream for the new episode.
  Selection remains per episode and viewer; manual Restart retains the normal picker.
- Optional **Automatically play the largest file** (Media Hub sources) is per viewer,
  off by default. Structured `behaviorHints.videoSize` or a labelled size determines
  the largest known file; no size means normal picker. A saved resume choice wins.
- Home card hold menu adds **Remove from history** to Continue Watching and Recent
  channels, keeping row controls. Removes that title/series from the active viewer's
  history; saved progress and watched flags remain. Focus moves to a surviving card.
- Claude's subtitle-only single-link import fix is included; no additional semantics.
- `SportsScreenFrame` takes real layout constraints before applying its existing
  scale. Regression sizes include 2560x1440, 1706x960 and 1280x720 with stale inherited
  MediaQuery dimensions. Owner says the 27-inch 1440p user's issue occurs windowed
  and fullscreen; Windows scale / real window diagnostics remain pending.

## Blank artwork investigation

- Persistent image cache already places files in support storage and bounds decode
  width; no evidence yet justifies deleting caches or changing Shield decode sizes.
- Global image HTTP service and `HdNetworkImage` log bounded/deduplicated host,
  HTTP status, exception type and counts. Never log image URLs, paths, credentials,
  raw error messages or titles. Cache/decode failures also reach the widget hook.
- Media Hub row fetch logs hashed source key, source kind, type, item count, poster
  URL present/missing counts and fetch duration; failures log type only. The source
  name is deliberately not logged since user-defined names can include private data.
- Sam's next log and answers are needed: every poster or some, detail backdrop,
  affected catalog, network comparison. A local CDN check cannot establish his ISP/DNS
  reachability. Diagnostics are delivered; blank posters are not claimed fixed.

## Native HEVC / guide flashing

- `NativeVideoSurface` takes a bounded in-memory PixelCopy snapshot (max dimension
  1280, never written/exported) before a live swap and paints it over the native video
  until first new frame. Copy failure/absence falls back to the app logo; an 80 ms
  cap prevents a slow copy stalling a zap, and a 15-second watchdog clears a cover.
  New zaps/disposal/detach/hide cancel the previous cover. Native rectangle remains
  shared by fullscreen and guide preview. Bitmap preview is not the HDR video output.
- Native beta on **FORMULER / Formuler Z11 Pro MAX only** uses
  `FormulerVideoRenderer`. HEVC capability/initialization selection tries supported
  `OMX.realtek.video.dec.hevc` first while retaining fallbacks; other formats,
  secure/tunneled selection and other devices keep upstream behavior.
- Equivalent-HDR reuse only removes the sole colour-info discard when the actual
  HDR encoding agrees: same HEVC codec profile, 4K size, frame rate, rotation,
  transfer (PQ or HLG), primaries, range and mastering bytes. Redundant/absent
  bit-depth metadata may differ. Re-run upstream size/buffer/workaround checks.
  **Do not force reuse across HDR/SDR, PQ/HLG, unknown colour, mastering changes or
  different bit depth/profile.** Those may require new HDMI signalling / a decoder.
- Explicit new main playback hands off any old native output before preparation;
  retry candidates retain the existing output until adopted. Native attach now has
  the same API-28 paused-first-frame workaround as the platform view.
- Unit tests exercise output ownership, cover first-frame/failure clearing, decoder
  ordering and HDR guard cases on SDK 28/30. Real Formuler, Shield and Cube validation
  remains required. The whole TV's HDMI blackout cannot be proven fixed by tests.
- Upstream API review pinned to [Media3 1.9.2](https://github.com/androidx/media/tree/1.9.2),
  specifically `MediaCodecVideoRenderer`, `MediaCodecInfo` and `DefaultRenderersFactory`.

Final check/build/publication results belong in the main ignored `HANDOFF.md`.
