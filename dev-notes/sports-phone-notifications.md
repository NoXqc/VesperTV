# Sports phone notifications (Android)

Owner-approved pickup 2026-11-05, branch `codex/sports-phone-notifications` based
on episode-background commit `dd85d5b`. This authorizes closed-app goal polling
for phone system notifications only. No TV overlay polling/window drawing,
player changes, APK, installation, version bump, merge or publication in this task.

## Reminder mirror

- `SportsPhoneNotifications` rebuilds an all-viewer plan after persisted reminder,
  subscription or phone-setting changes, at startup and after the existing
  30-minute schedule refresh. It translates notification text in Dart. Leads
  15min/1h/1day/1week and kickoff-only retain their existing meaning.
- `SportsNotifications` saves the complete plan, but coalesces its deadlines into
  ONE next exact RTC wakeup alarm. A season of automatic team reminders therefore
  cannot exhaust a device's per-app alarm quota. Receiver consumes all due items
  and re-arms the next; BootReceiver re-arms saved future deadlines. Past reminder
  deadlines are dropped on re-arm. Late delivery beyond its validity is skipped.
- At delivery, validate current viewer, phone preference, game/start/lead, sent
  phase and expiry against canonical reminder state. No Flutter engine needed.
  Visible app: skip OS notification and let the existing popup consume the phase.
- Alarm delivery writes early/started before posting. App/scoped reminder writes
  go through the same native main-loop bridge, retaining sent flags only when
  game/start/lead are unchanged. This prevents an older in-flight schedule save
  from overwriting a delivery made while the UI was away. Cancellation/removal
  and rescheduling remain authoritative. Resume reloads before in-app polling.
- Notification tap carries only game key/start, not the viewer or saved scope.
  Startup/profile selection completes first; Sports Trak opens that league/day
  with the requested card focused. It never starts playback or switches viewers.

## Live goal session

- My Teams Goals alert plus per-match subscriptions supply scheduled game starts.
  Whole-league-only popup subscriptions are NOT a new closed-app discovery mode.
  Cached team season schedules and explicit match starts produce native alarms;
  metadata refresh runs while the UI is active, not in a perpetual closed-app job.
  Already-saved matching-scope goal plans survive offline/empty startup fetches.
  New/changed remote schedules need a successful app refresh to update alarms.
- A goal-start exact alarm launches one SportsGoalService for every overlapping
  active watch, including multiple viewers. On foreground visit its independent
  EpisodeWorkGate lease is permanently invalidated, polling stops and the UI
  overlay resumes. Leaving re-arms a current live window; rapid open/close during
  destruction also re-arms. Foreground episode-worker logic stays independent.
- Service calls startForeground immediately, then creates a headless FlutterEngine
  with automatic plugin registration OFF and SharedPreferencesPlugin only. The
  kept `sportsPhoneGoalMain` forwards into `sports_goal_background.dart`. No normal
  main/bootstrap, UI, playback, app SQLite, EPG or catalog initialization.
- Reuse GoalsAlerts.poll, SportsService.gamesForDay and summary routing. Limit
  leagues/games to active subscribed windows. Loop delay60s; source freshness
  windows and TheSportsDB token bucket/429 backoff remain in force (its live
  cache is normally120s). No per-team score polling or bypass of source limits.
- Samples are shared per viewer, with a subscription-scope fingerprint. Persist
  before returning a notice; native compare-and-set and lease reject stale writes.
  Phone background supports Hide scores; OS body is checked again natively at post.
  When viewers share a game, any active watch with Hide scores masks the OS body.
  UI resume uses only samples <=3min old, so longer gaps silently rebase rather
  than replaying old scores. Phone session samples otherwise expire at6h.
- Every observed soccer/hockey score increment has a distinct stable string tag;
  split multiple increments from a single poll (safety cap16). Other sports retain
  one scoring-update alert, rather than treating e.g. six touchdown points as six
  goals. Scorer is supplied only when a fresh summary matches that score; a
  missing/late scorer does not delay the alert or invent a name. One summary
  request per update, no five-second summary retry loop.
- Ongoing low-priority Following goals notification names games without scores.
  Stop blocks the currently active windows; future games remain scheduled. Finals
  are removed as observed, partial overlaps continue, all final stops the service.
  No subscriptions, elapsed5h-per-game windows, offline10min, missing/failed feeds
  15min, engine errors or OS timeout also stop it. Stops release engine/wake lock.
- Uses specialUse with explicit manifest subtype/property. Android15+ dataSync has
  a shared6h/24h background budget; overlapping live games could consume it even
  with each individual game capped at5h. This follows the recorder's existing
  specialUse pattern on API34+, without modifying recording behavior. This is a user-requested, visible, stoppable live
  monitoring session, not a bulk transfer. The type requires review on any future
  store submission; this task does not claim store approval or publish anything.
- A bounded partial wake lock keeps the minute loop runnable while games are
  followed, released on stop; renewal is limited by active5h game windows. This
  consumes battery during live monitoring. Doze/OEM network policy can still
  delay delivery. No battery-exemption request, exact-alarm loophole, restart loop,
  AlarmClock UI, SYSTEM_ALERT_WINDOW or launcher integration.

## Settings, permission and diagnostics

Settings > Sports Trak > Phone notifications has Game reminders and Goal alerts
(on by default, per viewer). These are delivery preferences, not automatic follows.
All new UI/channel/notification text uses tr with EN/FR/ES/IT/EL/DE entries.
Android channels: sports_reminders, sports_goals, sports_following (LOW).
Notification permission is requested once from the visible Activity when a plan
first exists; denied permission never triggers a background dialog.

Exact-alarm access is checked. Missing access falls back to inexact reminders,
with exact=false in diagnostics; it never starts the goal FGS from that fallback.
FGS start denial is logged, stops the affected active windows, and does not loop.
Force stop cancels/blocks alarms until manual relaunch. Closing normally, process
reclamation and reboot are the intended lifecycle; restricted manufacturers and
TV notification presentation require device checks. No guaranteed instant scores.

Send log reads fresh persistent SportsNotify reminders armed=N/next/exact/alarms
and GoalService lastRun/games/polls/goals/stop. Counts contain no viewer names,
URLs or credentials. Headless prints are suppressed; ordinary service diagnostics
contain only fixed reasons/counts. Checkpoint-before-post can lose an OS alert on
process death between those operations, while favoring no repeat after reopening.

## Verification and later owner test

Dart coverage includes all leads, automatic/manual add/cancel/reschedule, native
sent-flag reload, per-viewer defaults, checkpoint dedupe/CAS/handover, Hide scores,
multiple goals/scorers, active-league restriction, finals and overlap. A widget
regression opens the notified card without playback. Native policy tests cover
boot deadlines, expiry, visible/sent suppression, stop conditions and hidden text;
existing episode lease and overlay capability tests remain in the app-level run.

After an owner-requested test APK (>619): enable permission, follow a team with an
upcoming game, set a15min reminder and goals, leave via Back/Home (NOT Force stop).
Verify the advance/kickoff reminders, Following goals with Stop, goal/scorer/score,
Hide scores and tap to the right card after any profile chooser. Open/close during
fetch and confirm no repeats; try overlap/final, cancel/edit, Stop then next game,
offline/reconnect and reboot. Inspect Send log. Do not drive the Formuler remotely.

References: [FGS types and specialUse](https://developer.android.com/develop/background-work/services/fgs/service-types#special-use),
[dataSync time limits](https://developer.android.com/develop/background-work/services/fgs/timeout),
[exact alarms](https://developer.android.com/develop/background-work/services/alarms),
[background-start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).
