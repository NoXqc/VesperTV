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

## Not done / open

- Windows / Mac / Linux / Apple TV (mpv): the Skip buttons setting applies; live pause & rewind
  not yet (mpv's cache: `demuxer-max-back-bytes`, `cache-on-disk` — the macOS sandbox needs
  `cache-dir` in the container).
- HLS live channels.
- Storage wear: ~1 MB/s written while a live HD channel plays (cheap sticks); Off in Settings.
- Not box-tested yet (emulator only, see the HANDOFF block).

## Tests

Native `TimeshiftTest` (9): index times / keyframes, takeover without a gap, pause, jump to the
keyframe + back to live, reopen after a server close, memory-only cap, window trim of files, not
MPEG-TS, switched off -> network. Dart `live_timeshift_test.dart` (14).
