# Post-seek stutter candidate — 2026-10-27 (cdx)

Owner reports repeated pause/play appearance for roughly the first five minutes
after fast-forwarding a movie or episode, in both IPTV and Media Hub. It then
recovers by itself. This explicitly concerns the shared Android player; the
accepted source-card work remains on the parent branch at9f064d7.

## Evidence and limits

Compared owner logs LOG-EW8Q8X and LOG-QHP444 from Formuler Z11 Pro MAX, Android11,
test1.0.43+475, Native video surface ON, Compatibility video OFF. The IPTV movie
uses a TrueHD/Atmos7.1 track. AudioTrack reports timestamp stall corrections;
the later session's warnings taper off by18:24:25 and playback continues until
normal disposal at18:27:13. The same selected audio track remains in use.

No repeated player recreation or fatal decoder error explains the recurrence.
The logs do not include exact native seeks, playback states or buffer-ahead,
so they cannot establish buffer starvation versus an audio-output stall. A
different add-on's HTTP530 stream-lookup failures are not evidence about the
active IPTV file. No credentials or source URLs belong in these notes.

## Candidate in test +476

The main platform/native-surface player previously resumed with only500ms
buffered after a seek or buffer depletion. `OnDemandLoadControl` wraps its
existing DefaultLoadControl and, when explicitly enabled, asks for5s of playback
time after an unbuffered seek and10s after depletion. Existing byte-budget
readiness can still start sooner; this prevents high-bitrate files on capped
devices from waiting forever for a reserve that cannot fit. The90s/120s loading
limits, allocation budgets, back buffer and load-continuation decisions remain
delegated unchanged. An already-buffered seek need not enter buffering.
Media3's readiness logic also bypasses the reserve when the final period is
fully buffered, so seeking near the end does not require nonexistent extra media.

`VodBuffering.configure` runs after initialization, before saved-position seeks
and play, including the backup-player initialization path. It uses
`!channel.isLive && !channel.transientPlayback`, covering IPTV and Media Hub
movies/episodes, including M3U group-classified VOD with ordinary IDs. No duration,
URL or track-based inference. Live playback and transient catch-up/trailers are
excluded. Native live replacement clears the flag. Windows and texture players
keep their existing policies. Initial preparation still uses the fast baseline
until Dart can classify the initialized player; the reserve applies to later
buffering transitions. No new pause/play commands or audio-selection changes.

`VodPlaybackTrace` is forwarded through the existing analytics listener. It logs
numeric local player ID, seek target, position, buffer-ahead, loading, playing,
playWhenReady and state, plus audio underruns and discontinuity reasons. It runs
for5min after configure/seek, with10s samples and at most120 event entries per
window, then stops. Disabling or disposing cancels it. It never reads media names,
URLs or tokens. Send log includes the process's logcat, including VesperPlayback.
State codes:1=IDLE,2=BUFFERING,3=READY,4=ENDED; `ready` means playWhenReady.

## Validation and device check

Native coverage exercises actual Media3 1.9.2 load control:5s/10s reserves,
playback-speed scaling, unchanged finite/live policy, stale live offset,
byte-budget escape, reset, player-scoped bridge and bounded trace/lifecycle.
The selected existing VideoPlayer/PlatformViewVideoPlayer suites also pass:
87 tests total. This is not a claim that the historically failing entire native
fixture suite is green. Dart coverage tests both catalog families, M3U explicit
classification, live/transient exclusion, bridge fallback and Windows exclusion.
Full Flutter suite:760 passed. Analyze:16 existing infos, no errors/warnings.
Exact check lines, signed artifact and installation are recorded in HANDOFF.md.

On the Formuler, reopen the same file and seek forward as before. A short wait
followed by continuous playback is the intended improvement; duration depends
on source throughput. If it still cycles, send a log while it is happening.
BUFFERING with depleted aheadMs supports starvation; READY with substantial
buffer and audioUnderrun/stall warnings points toward audio output. A sustained
source rate below playback demand cannot be repaired by a startup reserve.

References: pinned Media3 1.9.2
[LoadControl](https://github.com/androidx/media/blob/1.9.2/libraries/exoplayer/src/main/java/androidx/media3/exoplayer/LoadControl.java)
and [DefaultLoadControl](https://github.com/androidx/media/blob/1.9.2/libraries/exoplayer/src/main/java/androidx/media3/exoplayer/DefaultLoadControl.java).
End-of-media readiness is in
[ExoPlayerImplInternal.shouldTransitionToReadyState](https://github.com/androidx/media/blob/1.9.2/libraries/exoplayer/src/main/java/androidx/media3/exoplayer/ExoPlayerImplInternal.java).
