# Downloads + network folder (Android) — `claude/downloads`, 2026-11-09

Owner request: watch offline. A download is a movie or episode saved to the
device, a USB drive / SD card, or a **network folder** (SMB share on a PC or
NAS), then played from the Recordings tab or its page's button. Recordings
can go to the network folder too.

## What the user sees
- **Download** button on IPTV movie pages (`MovieDetailScreen`), Media Hub
  movie pages (`ArchiveDetailScreen`) and show pages (`SeriesDetailScreen`:
  menu = highlighted episode, or the season's episodes not downloaded yet).
- **Sheet** (`widgets/download_sheet.dart` `confirmDownload`): a warning
  (IPTV: one provider connection, waits while you watch on a one-connection
  account, can slow Wi-Fi, some providers forbid it; Media Hub: Wi-Fi only),
  **Best: download overnight**, size/time estimate when known, where it saves.
  Focused first row **Tonight at 2:00** (Left/Right = ±30 min, touch = arrows;
  the chosen time becomes the default), then Download now, Cancel.
- Once queued the button shows the state (Download at 2:00 / Waiting /
  Downloading 45% / Downloaded / Download stopped); OK = Play, Resume,
  Download now, Stop, Delete (`downloadMenu`).
- **Recordings tab**: Downloading (oldest first = the order they run),
  Scheduled, Downloads sections; poster cards with a progress bar.
- **Settings > Recordings**: Downloads > Speed limit (Like watching /
  10 / 25 / 50 Mbit/s / No limit), Suggested start, Save to (device, USB/SD,
  network folder), Set up a network folder.
- **Network folder** (`screens/settings/network_folder_screen.dart`):
  `\\host\share` (or smb://…), folder inside it (default VesperTV), user,
  password; Test writes and deletes `.vespertv-test`; Save and use it. **From phone**
  (focused first, +700): `PairingKind.networkFolder`, pair.html `#smb` form, same Wi-Fi
  only (mode `smb`: server = share, name = folder inside, user/password may be empty);
  the fields fill in, Test runs, Save and use it is focused.

## How it works
- Dart: `RecordingService` (same `recordings.json`, device-only). A download
  is a `RecordingEntry` with `kind: 'download'`, `channelId` = the title's
  channel id (page lookup), `poster`, `durationSec`, `totalBytes`, `headers`,
  `maxConnections`, `note`. `RecState.queued` is new (waiting its turn or for
  a connection). `recordingOf` / `conflictFor` ignore downloads.
- `_push` sends downloads to the native scheduler while scheduled / queued /
  recording / interrupted (kind, account, headers, durationSec, endAt 0), so a
  reboot or killed process resumes them; native drops one from its saved list
  when it finishes or is stopped (`RecorderScheduler.remove`).
- Native `Downloader.kt`: `Download` = one HTTP GET (redirects followed each
  time, Range resume after a drop / pause / restart, 416 = complete, 200 on a
  Range = start over), one at a time (`RecorderService.turnOf`), status JSON
  queued / downloading / paused / done / stopped / failed (+ total, note).
  Refuses: text/json pages under 5 MB, HLS playlists, files under 5 MB (a
  debrid "being downloaded" clip), files over the space left.
- `DownloadPolicy`: speed limit (Like watching = 1.25 × size / duration, at
  least 4 Mbit/s; 12 Mbit/s when unknown), **5 Mbit/s max while anything plays
  from the network**, and the connection rule: a download on account A waits
  (`paused`, note `connection`) while main player + Multiview tiles +
  recordings on A use its limit (unknown limit = 1). Dart reports the player
  (`main.dart _reportPlayback`) and Multiview tiles; before the player opens a
  channel, `yieldConnection` waits (≤ 4 s) for a download on that account to
  let go. The "playing" state expires after 3 min without the 1-minute
  heartbeat, and `MainActivity.onDestroy` clears it.
- Media Hub: `archiveDownloadItems` picks like Play (Largest file, Auto-play,
  single stream, else the list), later episodes follow the first one's
  source/binge group; keeps the **add-on's own link** (not the redirect), so a
  debrid link is fresh when the download starts.
- Network folder: `NetworkFolder.kt` on **smbj 0.14.0** (SMB 2/3, NTLM,
  BouncyCastle; R8 keeps in `proguard-rules.pro`). Paths are
  `smb://host/share/folder/file`, credentials only in native prefs
  `vesper_network_folder` + recordings.json (never Transfer/Backup/sync).
  `.status` files of network items live in app storage
  (`recording_status/<id>.status`). Playback: `NetworkFolder.playUrl` = a
  127.0.0.1 HTTP server with Range (ExoPlayer seeks), wired through
  `PlaybackService.openUrlFor` → `RecordingService.playbackUrl`. A recording
  whose network folder fails at start records on the device instead
  (`fallbackPath`, status `path`). The device space cap ignores network files.

## Not verified on a device (2026-11-09)
Everything above compiles and has unit tests (`test/downloads_test.dart`), but
no download, SMB connection or network playback has run on a box yet. smbj on
Android 7 (minSdk 24) is untested; any Throwable there is caught and shown as
"Network folders don't work on this device". Windows: no downloads.

## Test checklist
1. IPTV movie > Download > Download now: progress in Recordings, file plays.
2. Same on a one-connection account while watching: download shows "Waits for
   a free connection", resumes after leaving the player; no kicked stream.
3. Tonight at … (set 2 min ahead): starts with the app closed / screen off.
4. Kill the app mid-download (or reboot): resumes on its own.
5. Media Hub movie with several streams: picker, then download; debrid
   uncached title fails with the short-clip message.
6. Season download: episodes queue in order.
7. Network folder: Test on a Windows share and a NAS; record a live channel
   there; play it back and seek; pull the NAS mid-recording (fallback/retry).

## Copy from the network folder to another device (+702, 2026-11-10)
Owner: download a few movies/shows with the box overnight, then before a trip copy them onto a tablet to
watch offline (plane, car). Each device only knows its own `recordings.json`, so the share itself is browsed:
- **Details file**: a finished download / recording in the network folder gets `dir/.vespertv/<file>.json`
  (title, show/league, poster or logo, durationSec, kind, date; `RecordingService.detailsOf`). Native writes it
  when the file finishes (`details` in the pushed item, `NetworkFolder.writeDetails`, Downloader + Recording);
  Dart backfills older/failed ones after each status read (`_saveMissingDetails`, `RecordingEntry.detailsSaved`)
  and deletes it with the file.
- **Listing** (`networkList`, `NetworkFolder.list`): videos in the saved folder and 3 levels of subfolders, with
  their details. A file named like VesperTV saves (`2026-11-10_Title_<id>.ext`) without details is still being
  written (or from a box that hasn't opened +702 yet) and is hidden; anything else (put there by hand) shows,
  titled from its file name (`services/network_files.dart`).
- **Recordings > On the network folder** (only when a network folder is set up): this device's own network
  files and ones already copied are left out. OK / hold = **Copy to this device** or **Play from the network
  folder** (`networkFileMenu`, stable `rec_net_<hash>` channel so resume follows the file).
- **Copy** = a download whose source is `smb://` (`RecordingService.copyToDevice`, `toDevice: true`: always a
  local volume, never back to the share): same queue / progress card / resume / space checks; no speed limit or
  provider-connection rule (`Download.fromNetwork`); a share that goes away is retried ~20 min, then Resume.
- **Settings > Network folder > Save only**: the tablet browses the folder while its own recordings/downloads
  stay on it (Save and use it = save there too).
Not device-tested. `test/network_files_test.dart`.
