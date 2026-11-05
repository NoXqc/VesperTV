# TV goal alerts outside VesperTV - Phase 1 proposal

Codex, 2026-11-05. Base: `main` at `514863f`; branch: `codex/tv-goal-overlay`.
**Status: investigation and proposal only. No service, permission, settings, player,
launcher integration or version change is implemented by this branch.**
Current source/installed Formuler package: 1.0.56+615 (min SDK 24, target SDK 36).
Public Android release remains 1.0.56+606; public Windows remains 1.0.45.

## 1. What runs today

| Location | Current behavior |
| --- | --- |
| `lib/main.dart`, `_bootstrap`, provider list, `MaterialApp.builder` | Creates `GoalsAlerts`, exposes it through Provider, and places `GoalsAlertOverlay` above the Navigator. This covers VesperTV routes, not other Android apps. |
| `lib/services/goals_alerts.dart`, `GoalsAlerts.poll` | Detects integer score increases for My Teams, individually subscribed matches and subscribed leagues. It is a callable Dart service, not an Android Service or autonomous timer. |
| `lib/widgets/goals_alert_overlay.dart`, `_refresh`, `didChangeAppLifecycleState` | Polls again 30 seconds after each completed check, only while resumed. Leaving the app cancels timers, clears notices and resets the score baseline; resume establishes a silent new baseline. |
| Same widget, `_showNext`, `_lookupScorer`, `build` | Non-interactive, top-left Flutter popup, nominally 8 seconds. ESPN scorer retries can keep it visible for roughly 40 seconds plus request time; a found scorer gets another 6 seconds. It deliberately renders nothing while inactive. |
| `lib/services/sports_service.dart`, `gamesForDay`, `_CacheEntry.isStale` | Cached public feeds, not push notifications: live/starting-soon ESPN days expire after 50 seconds, TheSportsDB after 120 seconds; quiet days usually after 10 minutes. ESPN queries neighboring calendar dates, then filters/deduplicates. CFL has its own source. A 30-second timer does not mean fresh network scores every 30 seconds. |
| `lib/models/sports.dart` | `FollowedTeam` stores `leagueId\|teamId`; `SportsGame` carries stable league/game IDs, UTC start, state and both `SportsTeam.score` strings. `SportsGameSummary.goals` and `.scoringPlays` support optional scorer detail; no background execution lives here. |
| Settings > Interface > Goals alert | `settings_menu_screen.dart` opens the `goals` section in `general_settings_screen.dart`: My Teams toggle, Transparent popups, Show a test popup. `AppPreferences` delegates to `StorageService`. The preview is also Flutter-only. |
| `StorageService`, `AppConstants`, `game_score_alert_menu_tile.dart` | Per-viewer opt-in `vesper_goals_alert`, followed teams, `vesper_match_score_alerts` and `vesper_league_goal_alerts`. Match/league subscriptions can enable alerts without the My Teams toggle. Hide scores suppresses every real alert. |

Existing semantics worth retaining: silent first observation/new subscription,
no pregame or downward-correction alerts, bounded recent final update after live,
no stale previous-viewer responses, temporary-failure baseline preservation,
overnight games, and no focus/playback changes. See `test/goals_alerts_test.dart`
and `test/goals_alert_overlay_test.dart`, especially the background/resume test.

The manifest declares `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`,
`FOREGROUND_SERVICE_SPECIAL_USE`, notifications and boot permissions. Its only
foreground service is `.RecorderService` (`dataSync|specialUse`), with a subtype
specifically describing DVR. Recorder selects specialUse on API 34+, dataSync on
29-33; `BootReceiver` only re-arms recordings. These are useful implementation
examples, not a goal-alert worker. **`SYSTEM_ALERT_WINDOW` is absent.**

## 2. Proposed execution owner

Recommend a separate native Kotlin `GoalAlertService`, non-exported, in the normal
app process (no `android:process`), independent of `RecorderService`, owning a bounded
polling loop and a tiny native window.
Starting this service while VesperTV is visible lets it continue when the Activity
is backgrounded by YouTube or the launcher, or normally destroyed. The OS/user
can still stop its host process; this does not mean immortal execution.

| Option | Assessment |
| --- | --- |
| Native service + worker thread/coroutines + native popup | Recommended: no Activity/Flutter engine dependency, lower expected memory overhead on weak TV boxes, normal Android lifecycle/notification controls. Port a small score-feed/delta subset, with parity fixtures against Dart behavior. Measure rather than promise a memory saving. |
| Foreground service hosting a headless FlutterEngine | Possible alternative to share Dart parsing: explicit background entrypoint, engine/plugin initialization and independent storage are needed. It cannot reuse widget Providers, UI timers or UI-isolate state. Extra engine/memory/lifecycle complexity makes it a second choice here. |
| Keep the existing widget timer running, or use a normal periodic WorkManager task | Neither solves this requirement: the widget explicitly stops on background; periodic WorkManager has a minimum 15-minute interval and inexact execution. It can help with coarse schedule refresh, not timely scores. See [work requests](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work). |

Future Flutter/native bridge in `MainActivity.kt`: publish a versioned, bounded
configuration snapshot when subscriptions, active viewer, Hide scores, language,
consent or popup preferences change. Persist an atomic native-owned private file
containing only this allowlisted data, public feed IDs/metadata and schedule times.
Do not copy the entire preferences store, stream URLs, credentials or tracker keys.
Do not have native writes compete with Flutter's cached SharedPreferences values.

The native process must reconstruct its watch set from that snapshot after an
ordinary service recreation without needing a live MethodChannel or widget tree.
Profile generation IDs invalidate in-flight replies. Export the last active viewer
only, with explicit opt-in for that viewer; changing viewer cancels the old queue.
Localize future UI through `tr()` and FR/ES/IT/EL/DE as usual; export translated
native popup templates/configuration rather than adding hardcoded English Kotlin.

**One owner for each watched score stream:** when the native feature is enabled,
it owns those subscriptions even while the Activity is resumed and delivers notices
to the Flutter presenter there; use the system popup only while VesperTV is not
resumed. The current foreground-only league-alert path may remain for leagues not
exported. Deduplicate overlapping subscriptions and handoffs by viewer/game/team
and observation identity; never run two independently baselined pollers for the
same background watch. Flutter's lifecycle `_clear()` must not reset native state.

Keep a small persistent checkpoint/outbox for duplicate suppression. Only resume a
recent, validated baseline; a cold start, profile change, long network gap or reboot
starts silently. Do not replay all goals missed while the service was stopped.

## 3. Watch scope, polling and battery

Proposed external scope: games involving My Teams when their Goals alert opt-in is
on, plus matches explicitly subscribed through the existing game alert menu. An
all-league subscription alone remains in-app: do not turn the user's entire enabled
league bank into background traffic. Deduplicate two followed teams in one game.
This scope is a proposal for owner review, not a change to existing subscriptions.

Discover and retain the relevant game IDs/start times from the followed teams and
explicit match watches. Native discovery must also work after the Activity goes
away; passing only today's already-loaded cards would miss future fixtures. Keep
the local-day/neighboring-feed-date and overnight-final rules from Dart. If a provider
only offers a whole league/day scoreboard, fetch just the watch set's unique
league/days, then discard unrelated games. That is a transport limitation, not
permission to alert for every game. Prefer measured batching over assuming a
per-game endpoint is cheaper; never fetch every enabled league or scrape channels.

Suggested initial defaults to validate, not promised delivery times:

| Situation | Proposed cadence/action |
| --- | --- |
| Relevant live ESPN/CFL games, screen interactive | One polling cycle per 60 seconds, plus jitter; per-provider batching, at most two concurrent requests, timeouts and one in-flight cycle. CFL requires its own parity check. |
| TheSportsDB games | At least 120 seconds; preserve its shared rate limiting, Retry-After and capped-day/round behavior. Its feed may not supply live scores at all. |
| Relevant kickoff within 30 minutes | 60-120 seconds to notice actual start; no score notices before live. |
| No live/nearby watched game | Coarse 15-30 minute schedule discovery; no 60-second heartbeat across empty leagues. A later worker can assist discovery, but cannot guarantee permission to start an FGS from background. |
| Offline/429/5xx | Back off approximately 2/5/15 minutes, respect Retry-After; preserve recent checkpoints, silently rebaseline after a long outage. |
| Screen off, standby or locked | Remove popup and pause fast polling. No waking the display, continuous partial wake/Wi-Fi lock, or exact alarm every minute. Resume interactive checks with a fresh baseline after a long gap. |
| User opts out, Hide scores, empty watch set, overlay access revoked | Remove window, cancel work and stop this service. Keep ordinary foreground alerts available when their original settings permit. |

A live 60-second cycle gives roughly 60 polls/hour per unique transport bucket,
before discovery/date expansion, retries or detail requests; measure bytes, CPU,
requests and battery/thermal impact on an older Stick. Provider latency adds to our
poll interval. Do not label this instant or push delivery. Cache bounded-size logos
and reuse HTTP connections; keep decoding/network IO off the main thread.

The external popup should show the score promptly and last about **6 seconds total**.
Scorer data is optional: do not inherit the in-app 8+40-second waiting behavior or
poll all summaries every five seconds. A detail already available in this six-second
window may update the same card; it must not create a second alert or extend its life.

### Foreground-service type and start/stop limits

Create a new service declaration/subtype describing user-requested outside-app score
monitoring; do not reuse the DVR subtype text. Android 14+ requires an appropriate
FGS type. `specialUse` is the proposed candidate for ongoing, user-visible score
monitoring only if its use case is justified; it needs its own explanatory property
and store review when distributed through Play. It is not an exemption from OS
restrictions. See [service types](https://developer.android.com/develop/background-work/services/fgs/service-types#special-use).

For Android 15+ with target 35+, **dataSync has a shared six-background-hours per
24 hours allowance** and cannot start from BOOT_COMPLETED. VesperTV targets 36,
so declaring dataSync is not a 24/7 solution. Handle `Service.onTimeout` by stopping;
if a dataSync fallback is chosen, expose its session limit and account for other
services using the same budget. Avoid selecting both types at runtime under the
assumption specialUse cancels dataSync's restrictions.
[Android 15 changes](https://developer.android.com/about/versions/15/behavior-changes-15#datasync-timeout).

Start from the visible, user-operated enable/test flow and promptly call
`startForeground` with an ongoing notification and Stop action. Android 12+ limits
background FGS starts; on Android 15+, overlay permission alone is insufficient for
that exemption unless an overlay is already visible. A transient goal popup cannot
bootstrap an indefinitely stopped poller. Catch start denial and report it next
open rather than crashing or launching VesperTV over another app.
[Background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).

Normal Home/YouTube switching should leave the service running. A later implementation
may request sticky recreation, but restart is best effort. User Stop/force-stop must
win; reboot, OEM killing and OS task-manager stops are distinct from a hidden Activity.
Initial proposal requires reopening VesperTV after reboot/explicit stop, with a clear
status. Boot auto-resume would need a separate allowed-start design and device QA.
[User stopping an FGS](https://developer.android.com/develop/background-work/services/fgs/handle-user-stopping).

Notification permission is separate from overlay access. Android 13+ can deny
POST_NOTIFICATIONS without denying FGS startup, but the FGS must still supply a
notification. Include Stop in VesperTV's settings too, because TV notification
surfaces differ. No guaranteed heads-up popup fallback on all TV launchers.
[Notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission).

## 4. Overlay and permission flow

Later opt-in entry: Settings > Interface > Goals alert > outside-app alerts
(default off), with explicit status, grant access, native test popup and Stop.
Do not silently repurpose the existing My Teams toggle. Detect actual TV hardware
using the existing device-type service; leave phones and Windows on their current
path unless separately requested.

Declare `android.permission.SYSTEM_ALERT_WINDOW`. API 26+: use
`WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY`; API 24-25 (including Fire OS 6)
needs a separately tested legacy `TYPE_PHONE` branch, or an explicit feature-level
unsupported state. Do not raise the whole app's min SDK just for this experiment.
The OS can hide/reposition overlays; they are below critical system UI.
[Overlay window contract](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#TYPE_APPLICATION_OVERLAY).

Native view: absolute top-right, small wrap-content card, about 320dp maximum width,
20-24dp safe margins, score/team/league logo, six-second removal timer; no full-screen
transparent window. Use NOT_FOCUSABLE and NOT_TOUCHABLE, no remote interception,
no audio focus, sound, Activity launch or playback access. Android 12+ can block
underlying touches through untrusted overlays: honor the platform's obscuring-opacity
limit (default 0.8), combined alpha and real window bounds, and test mouse/touch
as well as D-pad input. [Android 12 touch restrictions](https://developer.android.com/about/versions/12/behavior-changes-all#untrusted-touch-events).

Recheck `Settings.canDrawOverlays(applicationContext)` before adding a view and on
return to Settings; handle SecurityException/add/remove races, permission revocation,
display-size changes and service destruction. Remove windows promptly in every stop
path. Other apps can deliberately hide non-system overlays on Android 12+; even a
granted permission cannot promise display over every protected window.
[Window.setHideOverlayWindows](https://developer.android.com/reference/android/view/Window#setHideOverlayWindows(boolean)).

Capability flow to implement later:

1. Query actual overlay grant. If granted, offer the bounded native test; do not
   infer grant from a checkbox, manufacturer, AppOps output alone or intent success.
2. Resolve ACTION_MANAGE_OVERLAY_PERMISSION with `package:com.nox.nox_iptv`, then
   the generic action. Account for package-visibility queries so a filtered resolver
   does not become a false unsupported result. Catch missing/security-blocked
   activities at launch. Android 11+ may show the general list rather than our app's
   page; explain selecting VesperTV and returning. See [Settings API](https://developer.android.com/reference/android/provider/Settings#ACTION_MANAGE_OVERLAY_PERMISSION).
3. On resume, query the grant again. An exported settings activity does not prove
   its OEM screen includes our app, is usable with D-pad, or can change the grant.
   If unavailable/ineffective, offer manual settings guidance and an optional
   advanced ADB route. Record `granted`, `settings available / awaiting grant`,
   `ADB may be required`, or `unsupported/error` with SDK/model/build and short
   error category; no installed-app inventory or credentials in logs.
4. Only after access is confirmed and the user enables monitoring, start the FGS
   while the Activity is visible. Granting access alone must not start monitoring.

**ADB support fallback, documentation only; NOT executed in Phase 1.** After a
future APK declares the permission, the owner may use an authorized debugging
connection to the selected device (never automatic app self-grant):

```text
adb -s <serial> shell appops get com.nox.nox_iptv android:system_alert_window
adb -s <serial> shell appops set com.nox.nox_iptv android:system_alert_window allow
```

Reopen our settings and recheck canDrawOverlays/test the popup. Preserve the prior
mode for rollback; `appops set ... android:system_alert_window default` restores a
clean default when that was the prior state. This is an AppOp, not an ordinary
runtime `pm grant` flow. Shell syntax is supported by [AOSP's command implementation](https://android.googlesource.com/platform/frameworks/base/+/3f7dac5a1ccf5d464070c1a067d1d50741bdbd0e/cmds/appops/src/com/android/commands/appops/AppOpsCommand.java);
OEM builds may reject it. Do not require root, accessibility or device-owner mode.

## 5. Read-only device probe and compatibility gaps

On the owner's connected **Formuler Z11 Pro MAX, Android 11/API 30**, queried
model/SDK, installed package version, two activity resolutions and one AppOps mode.
Both package-scoped and generic overlay actions resolved to:
`com.android.tv.settings/.device.apps.specialaccess.SystemAlertActivity`.
AppOps reported `No operations. Default mode: default`. Installed +615 does not
declare SYSTEM_ALERT_WINDOW. **Only settings-route availability is established**;
no screen was opened, permission changed, overlay added, app installed or UI driven.

| Device family | What can be proposed / what still needs verification |
| --- | --- |
| Formuler | Settings resolver exists on the tested Z11; owner must verify the actual grant UI and popup over launcher/YouTube after a separately authorized implementation/build. Other models/builds remain unknown. |
| Android TV / Google TV | Capability-test each OS/build, especially API 34/35/36 FGS behavior. Sideloading is not overlay consent. Test remote navigation through special app access, notifications, protected windows and OEM process management. No Google TV device was probed here. |
| Android-based Fire TV | Feature-detect leanback/SDK as well as Amazon model. Never assume the standard overlay management page exists: if it is missing or ineffective, explain the optional ADB path and possible unsupported result. No Amazon primary documentation found guaranteeing third-party overlay grants across firmware; this remains a device-test question, not a confirmed universal ADB fix. |
| Fire OS generations | Amazon documents Android-derived API levels: Fire OS 6 API 25; 7 API 28; 8 API 29/30; newer 14/16 families span newer Android levels. Gate by actual SDK, not a single Fire OS version assumption. Fire OS 5/API 22 is already below this APK's minimum. |
| Vega-based Fire TV | Amazon lists Vega devices separately with no Android API level. An Android Kotlin/SAW service proposal does not support those devices; a separate platform implementation would be needed. |

Amazon source: [Fire OS overview and device table](https://developer.amazon.com/docs/fire-tv/fire-os-overview.html).
Measure sustained behavior with VesperTV hidden, screen awake, and another app
playing; permission resolution alone does not demonstrate reliable delivery.

## 6. Phase 2 idea: launcher live-game cards (later, no implementation)

The same bounded native watch-set/schedule cache could later feed a TvProvider
publisher, with stable viewer/game IDs, team artwork, kickoff/live status and an
explicit VesperTV game-detail deep link. Keep launcher writes infrequent (status
changes / minute-scale updates), remove expired/unfollowed cards, respect Hide
scores, profile privacy and user dismissal, and never publish private playback URLs.
Do not keep fast polling alive solely to repaint a launcher row.

**Watch Next eligibility is a real blocker for arbitrary followed live-game cards.**
Google's app guidelines restrict additions to movies/TV shows, and TV-provider rules
cover resumable program items rather than channels; following a team is not itself
a qualifying watch history. Explore only genuinely eligible unfinished/resumable
content there, without fabricating resume timestamps, content types or watch history.
The live discovery idea may instead need an app-owned preview channel on launchers
that support it, subject to its separate content rules and user channel approval.
[App guidelines](https://developer.android.com/training/tv/discovery/guidelines-app-developers),
[TV-provider guidelines](https://developer.android.com/training/tv/discovery/guidelines-tv-providers).

An insert into TvProvider is not a guarantee of a visible row. Google TV's Continue
watching integration requires quality certification; launchers control presentation.
Fire TV uses a different launcher/discovery ecosystem, and Formuler launchers may
ignore TvProvider. Probe provider availability and launcher acceptance separately;
show unsupported status rather than promising one cross-device Watch Next feature.
[Google TV integration guidance](https://developer.android.com/training/tv/get-started/google-tv),
[Watch Next API](https://developer.android.com/training/tv/discovery/watch-next-add-programs).

## 7. Later implementation gates (not authorized by this proposal)

- Owner reviews scope/default cadence, the specialUse justification and device
  support limits before asking for feature code. Keep implementation out of player
  code and away from DVR behavior; existing manifest permissions are not blanket
  approval to run a new permanent service.
- First native capability test: owner-granted overlay, synthetic six-second popup
  over launcher and YouTube, no focus/audio/playback effects. Measure on Formuler,
  Google TV API 34+ and available Fire OS 6/7/8/newer devices. Owner drives Formuler.
- Then implement bounded watch-set polling and parity tests: fresh baseline,
  scoring/final/correction, duplicate subscription/handoff, profile change, Hide
  scores/opt-out, offline/recovery, midnight/DST, screen-off, revoked permission,
  process death, force-stop/reboot, FGS start denial/timeout and notification denial.
- Run a multi-hour outside-app session, measure CPU/RAM/bytes and delivery latency,
  and test Stop/reopen. Record actual model/SDK/firmware outcomes; do not claim all
  Android/Google/Fire TV devices are supported before those results exist.
- Watch Next/preview-channel feasibility is a separate later phase and should not
  block validating the external popup path.

Phase 1 stops with this document and a CODEX PICKUP block in root HANDOFF.md.
No feature, permission mutation, APK build/install, version bump, push or release.
