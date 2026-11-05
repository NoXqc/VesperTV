# Android episode alerts while the app is closed

Owner-approved CODEX PICKUP, 2026-11-05. Local implementation only; no APK or
installation in this task. Windows, goal polling, overlays and launcher rows are
out of scope. Notify me remains the only opt-in; no new settings or UI strings.

## Scheduling and engine

- `EpisodeAlertsWork` enqueues unique `vespertv-episode-alerts` periodic work with
  KEEP on app startup and from the existing BootReceiver. WorkManager persists
  its own schedule across process death and reboot. Initial delay and period are
  three hours; CONNECTED is required, not unmetered or charging.
- Uses AndroidX WorkManager 2.10.5 directly, with a small native Worker rather
  than another Dart scheduling dependency. It creates a headless FlutterEngine
  with auto-registration disabled and registers only SharedPreferencesPlugin.
  The kept entrypoint is `episodeAlertsBackgroundMain` in
  `package:nox_iptv/services/episode_alerts_background.dart`.
- No Activity, runApp, normal main/bootstrap, player plugin, catalog initialization,
  EPG or app SQLite connection. WorkManager's own internal database is separate.
  Storage is initialized without migrations and with a local viewer override;
  the user's active viewer preference is never switched or written.
- IPTV fetches only `get_series_info` for followed shows using the stored enabled
  playlist and configured backup servers; no authentication/catalog scans.
  Media Hub fetches the followed show's metadata only, through existing routing,
  with identity-registration writes disabled. Existing air-date lookup is reused.
- Existing `EpisodeAlerts.checkAll` performs comparison, silent first baseline,
  Home notices and checkedAt persistence. The same exact three-hour due rule is
  used by foreground/background; the former five-minute allowance is removed.
- Per-lookup timeout45s, whole worker cap7min; errors retry with exponential
  backoff starting at30min. Ordinary periodic work is inexact and can be delayed
  by Doze, standby, offline constraints or the manufacturer's power policy.
  No wake-loop, exact alarm, persistent foreground service or battery exemption.

## Races, notifications and privacy

- Native `EpisodeWorkGate` grants one worker lease. MainActivity.onStart
  invalidates it permanently; even immediately closing the app again cannot
  resurrect an old lease. Foreground timer checks also verify the app is visible
  after lookup, so a still-alive UI engine cannot race the headless worker.
- Background commits compare the original per-viewer JSON against current disk,
  verify that the viewer still exists, and validate the lease in the same main
  loop turn. Changed/deleted follows, profile changes or a foreground visit reject
  stale writes. Only the episode-alert preference is writable through this path.
- Foreground checks and resume reload preferences from disk (legacy preferences
  cache is per engine). Refresh avoids replacing in-memory edits made while the
  reload was pending. Baselines/notices are persisted before system notification,
  so the next engine observes the checkpoint before it can alert again.
- Check all viewers' follows. Each gets its own checkpoint and Home notice; the
  same show/episode across viewers posts once per run. Notification content is
  the show name and existing translated episode text, never the viewer name.
- EpisodeNotifier accepts Context, keeping the existing `episodes` channel.
  A deterministic per-show FNV id replaces runtime hashCode so updates replace
  earlier notifications across engines/restarts. Denied notification permission
  leaves the Home notice intact; no permission prompt from a background worker.
- Notification taps carry a Home intent. Cold and warm launches retain a pending
  tap until startup/profile selection is ready, refresh notices, then open Home.
  They do not choose a viewer or bypass profile selection. Suppress startup
  auto-resume for this launch so playback does not cover the notification page.
- A crash after checkpoint persistence but before OS post can lose the system
  notification; the persisted Home card survives. This deliberately favors no
  repeat notifications over attempting transactional OS delivery.

## Diagnostics and platform limits

- Separate native preference retains `EpisodeAlertsBg: lastRun=<epoch ms>
  result=ok|running|skipped(...)|error(...) shows=N new=M`. Printed at next app
  startup and read fresh for Send log, so previous-process work is visible.
  Counts contain no titles, viewer names, addresses, credentials or tokens.
  `new` counts new notices passed to the notifier, not guaranteed OS delivery.
- An offline job is held by CONNECTED and does not start; lastRun consequently
  remains the previous attempt. Mid-run constraint loss is logged as stopped.
  Provider failures leave that show's checkedAt/baseline untouched for retry.
- Android Settings Force stop / adb am force-stop cancels or prevents scheduled
  work until a user launches the app again. A forced JobScheduler run does not
  make force-stop a supported operating mode. Manufacturer task killers may
  impose similar restrictions. Formuler, Google TV and Fire TV need real tests;
  no claims of bypassing power management or guaranteed notification banners.

## Checks and owner acceptance (later test build)

Unit coverage: foreground/recent/no-follow skips, exact due boundary, all viewers,
unchanged active viewer, cross-viewer deduplication, background-to-foreground
checkpoint reuse, invalidated commit, failed lookup, save-before-notify, direct
IPTV request, Media Hub aired-only metadata without preference writes, translated
notification ids, and pending tap readiness/consumption. Native gate tests cover
exclusivity and irreversible invalidation; existing overlay tests remain intact.

1. Build/install only when the owner asks; next versionCode must exceed619.
2. Follow a show with an upcoming episode. For a debug fixture, lower its saved
   baseline and age checkedAt beyond3h; never manipulate real credentials.
3. Press Home to leave VesperTV; close/kill its background process without Force
   stop. Use owner-operated devices. Wait for work, or find the current worker's
   JobScheduler id using `adb shell dumpsys jobscheduler` (do not guess an id),
   then `adb shell cmd jobscheduler run -f com.nox.nox_iptv <id>`.
4. Confirm notification; tap into Home after any profile chooser, verify New
   episodes row, and verify opening the app does not post the same alert again.
5. Reopen during an in-flight job, unfollow/change viewer, and confirm no stale
   preference overwrite. Test offline recovery, reboot, notification permission
   denied, and two viewers following the same show. Inspect Send log status.
6. Separately Force stop: expect no work until manual launch, then verify the
   retained WorkManager schedule recovers. This is a platform-limit test.

References: [WorkManager requests and constraints](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work),
[2.10.5 release](https://developer.android.com/jetpack/androidx/releases/work#2.10.5),
[Flutter named library entrypoint](https://api.flutter.dev/javadoc/io/flutter/embedding/engine/dart/DartExecutor.DartEntrypoint.html),
[AndroidX force-stop recovery implementation](https://android.googlesource.com/platform/frameworks/support/+/f2e05c341382db64d127118a13451dcaa554b702/work/workmanager/src/main/java/androidx/work/impl/utils/ForceStopRunnable.java).
