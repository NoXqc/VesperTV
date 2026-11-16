# Update while VesperTV is closed (Android)

Settings > Profiles & startup > Startup > **Update while VesperTV is closed**. Off by default,
device-only (`vesper_content_updates`: not transferred or synced). Request relayed by the owner,
2026-11-16: "content updates in the background whilst an Android TV box is inactive".

## What it does
An hourly WorkManager job (`ContentUpdateWorker.kt`, constraints: network, battery and storage
not low) refreshes, on the app's own schedules:
1. the guide, when it's older than Settings > EPG refresh interval;
2. each enabled Xtream playlist due for a full sync (its "Update content every"), one at a time.

M3U playlists aren't synced (the app never syncs them automatically either).

## How
- `ContentDue` (content_updates.dart) decides from prefs alone. Each run writes the next due time
  to `vesper_content_next_due`; the worker reads it natively and skips the run without starting an
  engine until then. The app clears it (= check at the next run) at every launch and when the switch
  changes, and rewrites it each time the app goes to the background.
- **App process alive** (Back > Exit is a warm exit): the worker calls `runInApp` on the app's own
  engine (`ContentUpdates.attachApp`, set up after the bootstrap). No second catalog in memory.
- **No app engine**: a headless engine (SharedPreferences, Sqflite, Jni = path_provider; no
  GeneratedPluginRegistrant, so no player) runs `contentUpdateBackgroundMain`. It must stay in a
  library main.dart imports: a release build leaves out the rest, and the engine then fails with
  "Could not resolve main entrypoint" (seen in the first emulator run).
- Stops: the app coming on screen ends the gate lease (`EpisodeWorkGate`, polled every second),
  Android stopping the job, or 8 minutes (Android's limit is 10). The guide stops at its next
  batch (`EpgService.shouldStop`: like a failed download, old rows kept); a playlist stops between
  categories and stays due (`PlaylistSession.runFullCatalogSync(stop:)` returns false and doesn't
  save the sync time). What's left runs next hour.
- The app waits up to 5 s at launch for a headless run to stop (`waitForBackgroundRun`, then
  reloads prefs). Both engines share sqflite's native connection (static per file in
  SqflitePlugin), so it's safe either way, but **neither side may close the databases**.

## Send log
`ContentUpdateBg: on=true lastCheck=MM-dd HH:mm nextDue=...` then the last 6 runs:
`11-17 11:42 closed result=ok guide=updated playlists=1/1 took=6s`. Results: ok, partial,
nothing_due, stopped(app_opened|android|time), error(...). The headless side prints nothing
(provider errors carry private URLs).

## Testing it on an emulator
`C:\Android\Sdk\emulator` + AVD `vesper_bg_test` (API 34 google_apis, rootable) were installed
2026-11-16. Write `FlutterSharedPreferences.xml` as root (playlist pointing at a fake provider on
`10.0.2.2`), move the clock with `date`, and force the job with
`cmd jobscheduler run -f -n androidx.work.systemjobscheduler com.nox.nox_iptv <id>` (find the id in
`dumpsys jobscheduler`; WorkManager refuses a periodic run before its hour is up).
