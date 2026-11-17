# Movie / episode buffering in Send log (2026-11-17, Claude)

Owner: viewers of one IPTV server (Blcktv, "Dom" playlist) report buffering on high-bitrate
movies; another app's dev says running VLC natively helps remuxes. Before choosing a player
change, find out where the time goes. The old `VodPlaybackTrace` (`VesperPlayback` logcat lines)
only covers 5 minutes after a start or seek, and logcat rolls over, so a freeze at minute 40
left nothing in Send log.

## What Send log now says (`VodBuffer:` lines, Android)

`lib/services/vod_stall_log.dart` polls the player's stats (`vespertv/stats` getStats) every 5 s
while a movie or episode plays (`VodBuffering.appliesTo`: not live, not catch-up/trailers).
`VodStallTracker` (pure, tested in `test/vod_stall_log_test.dart`) prints:

- once: the file's average bitrate (size from the player's own HTTP headers / duration) and the
  buffer cap (64 MB under 2.5 GB RAM, else media3's default ~140 MB);
- each freeze: length, position, seconds buffered when it began, download speed over the last
  10 s / 60 s against the file's bitrate, and a verdict:
  - buffered > 3 s when it froze -> decoder or audio, not the network;
  - 60 s download < 95 % of the file's bitrate -> the source or the network is too slow
    (no player fixes that, VLC included);
  - otherwise -> download kept up on average: a bitrate peak bigger than the buffer, or a slow
    reconnect (this is where a bigger buffer helps);
- seek waits of 2 s+ (buffering within 2 s of a seek is no longer counted as a freeze, live too);
- failed loads (ExoPlayer retries them), audio underruns, bursts of dropped frames (throttled
  to one line per 30 s);
- a summary every 5 minutes of playing.

Native side: `VideoPlayer.stallCounter` keeps `lastStallPosMs`, `lastStallAheadMs`,
`seekWaits`, `lastSeekWaitMs` (a seek = `onPositionDiscontinuity` SEEK / SEEK_ADJUSTMENT);
`VodPlaybackTrace` counts `underruns`, `loadErrors`, `lastLoadError` for the whole stream;
`StatsBridge.getStats` passes them plus `smallRam` (`BufferBudget.isSmallDeviceKnown`).
Native test: `VideoPlayerTest.bufferingRightAfterASeekIsASeekWaitNotAFreeze`.

## Bigger movie buffer on boxes with memory (same branch)

Owner: do the VLC-like improvements that cost nothing. VLC's main remux advantage is a bigger
read-ahead (native memory); ExoPlayer's buffer is Java heap. The main player's byte cap was
media3's default (~140 MB = 11 s of a 100 Mbit/s remux); the 90 s time target is never reached at
that bitrate, so bytes decide. `BufferBudget.onDemandBytes`: half the Java heap limit
(`Runtime.maxMemory`, largeHeap), at most 256 MB (~21 s), only when bigger than media3's default
and never on small devices (< 2.5 GB RAM keep 64 MB: the Fire Stick OOM). `OnDemandLoadControl`
applies it to movies / episodes only (Dart's `setOnDemandBuffering`), under the 90 s time target,
when the delegate stopped on its own byte cap. Live, catch-up, Multiview / texture players
unchanged. Send log's first `VodBuffer:` line names the cap and the heap.
Test: `OnDemandLoadControlTest.moviesKeepLoadingPastTheDelegatesByteCapUpToTheirOwn`.

Not done (they cost something; owner to decide): disk read-ahead (~45 GB/hour written to the
box's flash at 100 Mbit/s), starting H.264 live channels on any keyframe
(`FLAG_ALLOW_NON_IDR_KEYFRAMES`: faster starts on some channels, a few garbled frames possible,
risky on boxes with zap-frame quirks), rebasing live timestamp jumps the way VLC resyncs (A/V sync
risk, needs a stream that does it).
