# Live pause & rewind (timeshift on one connection) + Skip buttons setting

Owner, 2026-11-25, after cillfog on Discord (#improvment-suggestions): live pause / rewind on
channels without catch-up, without a second provider connection ("AerioTV did it on one").
Then: "Also add a *replay highlight* with a back or forward jump that a user can manually chose
like -30/+30 or -15/+15 it could also apply to our normal -/+10 skip button".

## How it works (Android, vendored ExoPlayer)

- `Timeshift.java`: once Dart arms it for a live channel, the player's open connection becomes
  a **writer thread** (no reconnect: `TimeshiftDataSource` hands it over at its next read). The
  writer reads the provider all the time and appends to a rolling copy: 16 MB files in
  `cacheDir/timeshift/ring-*` (memory blocks of 2 MB, 32 MB at most, when storage has under
  1 GB + 256 MB free, or a write fails / the system clears the cache). The player reads the copy.
  - Pause = the player stops reading; the writer doesn't, so the connection never stalls (before,
    a long pause on a channel without catch-up stalled the socket and the provider dropped it).
  - Index: stream time from the **PCR** (first PID that carries one; a jump/gap/new connection
    counts as the wall-clock time between, clamped to 3 s), an entry every 200 ms and at each
    **keyframe** (random-access flag + PES start on the PCR PID; the audio PID's RAI is ignored).
    No PCR within 3 s: wall-clock time.
  - Jump: `VideoPlayer.timeshiftJump(deltaMs)` -> `Timeshift.jump` picks the last keyframe at or
    before (picture time + delta), within 8 s, sets it as the next load's start, then
    `exoPlayer.seekTo(0)`: a live progressive stream can't seek, so any seek resets its load and
    the new load opens the copy there (`openReader`). At position 0 the seek would be dropped
    ("already there"), so then `stop()` + `prepare()` does the reset.
  - Picture time = time at the player's read position minus what ExoPlayer holds ahead
    (`getTotalBufferedDuration`). Behind live = newest PCR time - picture time.
  - Far ahead = live: the keyframe ~1 s before the newest byte.
  - Dropped connection (server close or read error): the writer reopens from "now" (through
    `LiveReconnectDataSource`'s retries) and the new bytes follow the old ones; **TsSplice**
    keeps times continuous / follows a new program (built for Tuliprox switches, same pattern).
    Reopen fails: the reader at the head throws it, ExoPlayer's retry reopens through
    `openReader` (restarts the writer). A new load with no data for 5 s (the live-copy stall
    path, `liveStallCheck`) restarts the writer.
  - Trim: blocks older than the window (setting minutes) or over the byte cap (min(6 GB, free -
    1 GB), rechecked every 64 MB written) go. Paused past the window: the player carries on from
    the oldest part kept (its next keyframe).
  - Released on zap (`replaceNativeStream`), new stats, VOD/catch-up (`setOnDemandBuffering(true)`),
    switch-off and dispose: the writer's connection closes on a background thread, files deleted.
    Old rings from a killed app are deleted at the first arm of the process.
- Not for: HLS (`.m3u8`, no progressive source), non-MPEG-TS (first byte not 0x47), files with a
  length, Multiview / texture tiles (`reconnectLiveStreams()` false), catch-up (`finite`).
- MethodChannel `vespertv/stats`: `setTimeshift {playerId, on, minutes}` -> `{on, reason?}`,
  `timeshiftJump {playerId, deltaMs}`, `timeshiftState {playerId}` -> `{on, behindMs,
  availableMs, windowMs, storedMb, memory, note?, reconnects, connected, keyframes}`.

## Dart

- `LiveTimeshift` (services/live_timeshift.dart): setting minutes (0/10/30/60, default 30,
  `vesper_live_rewind_min`, device-only, kept by a backup), arm / state / jump.
- `PlaybackService`: arms after `VodBuffering.configure` (fresh live player, not catch-up) and
  after a native zap; polls `timeshiftState` every second into `timeshift` (ValueNotifier).
  `timeshiftNudge(delta)` gathers presses for 700 ms (`timeshiftTarget` shows where it lands)
  then one jump; past the copy on a catch-up channel -> `playCatchup(now - target)`.
  `timeshiftGoTo(behind)` (the timeline scrub), `timeshiftToLive()`. Play after a pause: the copy
  covers it -> plain play (no catch-up switch after 90 s any more).
- UI: live info bar line 3 = -N / Play-Pause / +N / LIVE (when behind); "−1:23" gold tag on line 1;
  the timeline is focusable and scrubs the copy (and catch-up past it); remote Rewind / FF on
  live = ScrubSteps steps through `timeshiftNudge`; `TimeshiftCue` mid-screen while presses
  gather; phones: -N / +N around the round Play/Pause.
- **Skip buttons** (Settings > Playback > Player): 5/10/15/30/60 s (`vesper_skip_seconds`, synced).
  `SkipStep` (utils/skip_step.dart): `SkipHoldButton` tap + hold ticks, `ScrubSteps` tap (held
  ladder never below it), desktop -/+ buttons and arrows. `SkipIcon`: Material replay_5/10/30 /
  forward_5/10/30, else the round arrow with the number (15, 60).

## Send log lines

`Timeshift: on, 30 min kept` / `Timeshift: off (<reason>)` / `Timeshift: jump -30 s -> 42 s behind
live` / `Timeshift: back to live` / `Timeshift: <note>` (memory only, storage full, cache cleared,
reopen failed) / `Timeshift: N s back is past the copy (M s), catch-up`. Native logcat tag
`VesperTimeshift` (took over the live connection, jump, reopening, paused past the window).

## Computers / iPhone / Apple TV (mpv, 2026-11-28, `claude/atv-timeshift`)

Same setting (Settings > Playback > Live TV, shown on media_kit too, its own help text), built on
mpv's demuxer cache instead of a copy of the stream: `services/desktop_timeshift.dart`
(`DesktopTimeshift.of(player)`, per player like `DesktopLiveRecovery`). Only
`DesktopPlayerScreen` arms it, for a live channel (not catch-up, Multiview, the preview, trailers).

- **mpv options** (set before the stream opens in `_openMedia`, or on a stream taken from the
  preview: they apply to an open stream): `cache=yes`, `demuxer-seekable-cache=yes`,
  `cache-on-disk=yes`, `demuxer-cache-dir=<getTemporaryDirectory()>/vesper_timeshift`,
  `demuxer-donate-buffer=no`, `demuxer-max-back-bytes=<minutes x 2 MiB, at least 16 MiB>`, and
  `demuxer-max-bytes` raised to the same when it is lower (the iPhone's 32 MiB would stop reading
  a paused channel after ~25 min). Each is read back and Send log names one this libmpv didn't
  take; mpv's own values are read once per player and put back when it stops (with
  `cache-on-disk=no`).
- **Measured** on the app's Windows libmpv 0.36 (Python ctypes harness + a real `Player` in a
  flutter test, local ffmpeg live MPEG-TS and HLS, 2026-11-28):
  - media_kit's `cache-on-disk=yes` did nothing before: `demuxer-cache-dir` defaults to empty, so
    the cache was memory only (and the macOS / iOS sandboxes can't create mpv's own folder: why
    `configureDesktopStreamPlayer` sets it off there).
  - With the folder: an unlinked temporary file (invisible, freed when the stream closes or the
    app dies); the process stayed at ~100 MiB while the file grew ~0.4 MB/s at 3 Mbit/s.
  - With the disk cache `demuxer-max-bytes` / `-max-back-bytes` limit the packet **index** only
    (~19 KB/s at 25 fps + AAC = ~70 MB an hour); `demuxer-donate-buffer=no` or the back buffer
    borrows the whole forward limit (128 / 256 MiB). The file is **append-only**: pruned packets
    don't give space back.
  - `seekable=no` on a live stream, yet seeks inside the cached range work (instant); outside it
    "Cannot seek in this stream" and nothing moves. A negative absolute seek counts from the end.
    HLS: a seek past the newest keyframe of `seekable-ranges` (~2 s before `cache-end`) is refused,
    so LIVE seeks to `seekable-ranges[].end - 0.1 s`.
  - Paused, mpv keeps reading (`cache-end` grows, `fw-bytes` grows); Play carries on from the
    paused frame. `cache-on-disk=no` on an open stream stops writing at once (file frozen, new
    packets in memory).
- **State**: `demuxer-cache-state` JSON every second (`MpvKeptRange`: the range the picture is in,
  `cache-end` = now, oldest = max(mpv's oldest keyframe + 0.5 s, newest - the setting's minutes)),
  Android's `TimeshiftState` for the UI. Skips gather 700 ms then one seek (`nudge`), LIVE,
  `goTo(behind)`: inside what's kept / past it on a catch-up channel = catch-up / else the oldest.
  Play after a pause: still kept = play; past the minutes = catch-up from the pause or the oldest.
- **Disk**: copy limit (`budgetBytes`) Apple TV 6 GiB, iPhone 3 GiB, computers 16 GiB, never more
  than free space minus 2 / 4 GiB (Windows: GetDiskFreeSpaceExW, off under 1 GiB of room;
  elsewhere statvfs, only shrinks it). Past it the channel opens again at live (at live and
  playing; anywhere past +25 %). An mpv "failed to write" cache line = off for 10 min + reopen.
  Back to the preview: behind live -> LIVE first, then off (`cache-on-disk=no`); a file over
  1 GiB (Apple TV / iPhone) or 4 GiB (computers) is freed by opening the channel again at live.
  Leftover files in the folder are deleted at the first arm and when the player closes.
- **UI** (DP): computer bar -N / +N + LIVE + gold "−1:23" tag; Apple TV info bar line 3 -N /
  Play-Pause / +N / LIVE (fixed slots: Play keeps its focus), tag on line 1, `TimeshiftCue`
  mid-screen while presses gather; iPhone: the round -N / +N around Play, tag + LIVE. Options row
  Skip tile on live too. Vesper's back to live / seek go through it.
- **Live timeline (remote)**: `widgets/desktop_live_timeline.dart` replaces `_TvLiveProgress`:
  focusable on a catch-up channel or with the copy on (Up from line 3, explicit in DP's key
  handler), Left / Right = `ScrubSteps` (held repeats grow), the target floats above the bar,
  OK = `_liveScrubGo` (what's kept first, then catch-up), Back (PopScope asks
  `LiveScrubController.cancel` first) / Down / focus leaving cancel. No guide listing: the kept
  minutes are the bar.
- Send log: `Timeshift: on for <channel> (<why>), N min kept · <device> · cache dir …/Temp/
  vesper_timeshift · free X · copy limit Y · mpv k=v … (all set | NOT TAKEN: …) · before: …`,
  `Timeshift: off (<why>) · had … kept …`, `Timeshift: kept 0:12:34 of 30 min (a-b s, seek end
  c s), behind 0:00:01, copy 512 MB, index 12 MB (ahead 0.2 MB) · playing` (every 10 s),
  `Timeshift: pause at …`, `Timeshift: play after 0:01:20 paused, …`, `Timeshift: skip -30 s ->
  lands …`, `Timeshift: <why>: 0:00:08 -> 0:00:38 behind live (seek x s, kept a-b s)`,
  `Timeshift: seek landed elsewhere: asked x s, got y s (+z s)`, `Timeshift: …: catch-up from
  HH:MM:SS`, `Timeshift: copy file … over its … limit …`, `LiveScrub: focus in (…)` / `focus out`
  / `step -10 s -> HH:MM:SS (m:ss behind live)` / `OK at …` / `-> what is kept | -> catch-up from
  … | -> stays live (…)` / `cancelled (Back | Down | focus left | catch-up)`. Repeats: one a second.
- Tests: `test/desktop_timeshift_test.dart` (32: parse, ranges, landings, resume, limits, the
  controller on a fake mpv), `test/desktop_live_timeline_test.dart` (10). Not on a real Apple TV
  yet (mpv 0.41 there: the read-back line says whether every option was taken).

## Not done / open

- HLS live channels on Android (mpv's cache covers HLS on the other players).
- Storage wear: ~1 MB/s written while a live HD channel plays (cheap sticks); Off in Settings.
- Not box-tested yet (emulator only, see the HANDOFF block).

## Tests

Native `TimeshiftTest` (9): index times / keyframes, takeover without a gap, pause, jump to the
keyframe + back to live, reopen after a server close, memory-only cap, window trim of files, not
MPEG-TS, switched off -> network. Dart `live_timeshift_test.dart` (14).
