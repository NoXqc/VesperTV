# Faster downloads for big files (was: read-ahead to storage), Android

**Now (+956): several connections into a 64 MB memory ring.** The storage version (+954/+955,
below) worked as designed but froze on the owner's Homatics: with 3 connections at 114 Mbit/s
for an 80 Mbit/s file, the box wrote the ring file at 15 MB/s but read it back at only 6 MB/s
(`/proc/vmstat` pgpgin/pgpgout over 5 s; memory full, swap 811/819 MB, so the written pages left
the page cache before the player reached them). Storage held 1:30-2:40 of the movie while the
player refilled at ~0.7x real time: 10 s playing, 10-20 s frozen. The connections were the part
that worked (56 -> 86 -> 114 Mbit/s on TorBox), so the ring moved to memory: `Tuning.windowBytes`
64 MB of 1 MB direct `ByteBuffer`s (outside the Java heap, allocated as first written, dropped on
release), segments 8 MB, 4 MB kept behind, 8 MB wait gap. No storage, no flash wear, no free-space
rule. Setting renamed **Faster downloads for big files** (same key `vesper_read_ahead`); Send log
says `read-ahead on, up to 64 MB in memory` and `+ m:ss read ahead (3 connections)`. Lost: minutes
of cushion (memory ring + the player's 192 MB = ~25 s at 80 Mbit/s). If a box with plenty of RAM
ever needs minutes again, storage only works where the page cache holds the ring.

The history below describes the storage version; the segment / connection logic is unchanged.

Owner's Homatics, 2026-11-21: a Media Hub 4K remux (52 GB, 65 Mbit/s average) froze twice at
46:18 (10.6 s) and 47:05 (19 s). Send log: "download slower than the file: source or network"
(51-57 Mbit/s over the minute before, Wi-Fi 6 at 1200 Mbit/s, so the source). The movie buffer is
Java heap: `BufferBudget.onDemandBytes` gave 192 MB (half the 384 MB heap) = ~24 s of that file,
and the slowdown lasted ~3 minutes. Over the first 46 minutes the source had sent 60-80 Mbit/s, more
than the file needed: a bigger buffer would have filled then. RAM can't give minutes (Java heap), so
the read-ahead goes to storage. Owner: "Yes" to automatic for big files + a setting.

## How it works
- `ReadAhead.java` (vendored player): one per progressive HTTP asset (`StreamStats.readAhead`,
  created in `HttpVideoAsset.getMediaSourceFactory`, files under `cacheDir/readahead/`). Off until
  armed. Armed = a ring file of 4 GB (`WINDOW_BYTES`) and a background connection
  ("VesperReadAhead" thread) downloading from the reader's position, at most one window ahead
  (`readPos - KEEP_BEHIND + window`; 32 MB kept behind for small steps back).
- The download runs in 32 MB segments (`Tuning.segmentBytes`), claimed in order, each written at
  its place in the ring; the reader sees the contiguous part (`availableEnd`). One connection keeps
  reading on while its next segment follows on.
- **More connections** (owner, same night: a 94.5 GB / 80 Mbit/s file got 41-65 Mbit/s on one
  connection; "TorBox does not limit connections"): every 15 s the download speed is sampled. Slower
  than the file needs (Dart passes `fileMbps`) and less than half the window ahead -> a second, then
  a third connection (`maxConnections` 3) fetches the next segments. The sample after each step
  decides: under 15 % more = "no gain", back to the count before and no new try for 5 minutes. A
  sample during which the window was full is ignored. Send log: `VodBuffer: read-ahead 45 Mbit/s, the
  file needs 80: adding connection 2`, then `2 connections: 88 Mbit/s (1 less: 45)` or `... no gain
  ..., back to 1`; summaries say `(2 connections)`. More connections only with a known length.
- `ReadAheadDataSource.java` wraps `LiveReconnectDataSource` (made by a factory) for progressive
  files. Armed: reads come from the ring (waits for the download; interrupts end the wait).
  Switched on mid-read: the reader's open connection is handed over (`ReadAhead.adopt`) and carries
  on as the first download connection, so there's no reconnect (the 94.5 GB test froze 8.3 s at 0:00
  partly from reconnecting 5 s in). Switched off mid-read (`ReadAhead.STOPPED`): a new direct
  connection opens at that byte.
- An open inside [base, downloaded + 16 MB] reads the ring; outside, an unbounded open (a seek)
  restarts the download there, a bounded one (an index probe at the end of the file) reads the
  network directly without restarting.
- The download's own connection comes from the same `DefaultHttpDataSource.Factory`: same headers,
  counted in `StreamStats` (Send log's download speed is the read-ahead's then). Errors retry after
  1/2/4/8/8/8 s, then the reader gets the error (ExoPlayer's load retry reopens = restart); 404 / 410
  / 416 at once.
- Released (thread stopped, file deleted) on `VideoPlayer.dispose` (after `exoPlayer.release()`),
  `replaceNativeStream` (live zap), `attachStreamStats` of another asset, and
  `setOnDemandBuffering(false)`. `arm()` deletes leftover `readahead-*` files (a crash).
- Refused (Send log reason): not a single file, a loopback host (the network folder's local server),
  under 8 GB free (`MIN_FREE_BYTES`), not a movie / episode.

## Who arms it
Dart `VodStallLog._readAhead`: once per player, when `VodStallTracker.fileMbps` (size / duration,
known ~5 s after the start) is >= 40 Mbit/s (`readAheadMbps`: remuxes; a 4K WEB-DL at 15-25 keeps
up from memory) and Settings > Playback > Movies & TV Shows > **Read ahead to storage** is on
(`vesper_read_ahead`, on by default, device-only: `_transferOnlySkipPrefixes`, kept by backups;
`VodBuffering.readAhead`). `StatsBridge` method `setReadAhead {playerId, on}` -> `{on, reason?,
windowMb}`.

## Send log
`VodBuffer: read-ahead on, up to 4096 MB on storage` / `... not used: only 6.1 GB free`; freezes and
the 5-minute summary say `buffer 23.0 s + 7:52 on storage` (getStats `readAheadOn`, `readAheadMb`,
converted with the file's bitrate); `VodBuffer: read-ahead HTTP 503, retry 1 in 1 s` when the
download has trouble (`readAheadNote`); `readAheadRestarts` = far seeks.

## Cost
Every byte of the movie is written to the box's flash once (52 GB for that remux); a 4 GB file while
playing. Accepted by the owner for big files only.

## Tests
`ReadAheadTest` (native, 11): whole file through the ring, window limit, far seek restart, bounded
probe direct, switch on mid-read keeps the same connection, retry, switch off mid-read + file
deleted, a per-connection limit gets a 2nd connection (bytes still in order), a shared limit drops
it ("no gain"), too little space, loopback. `test/vod_stall_log_test.dart`: the log lines.
+954 (one connection) box-tested: on, but the 80 Mbit/s file's source gave 41-65: froze. +955 adds
the connections and the handover.
