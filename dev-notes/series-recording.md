# Record a show to come + series recording (Claude, 2026-11-10)

Owner: "We don't have the option to record upcoming programs in live TV, plus no
option to record series of the same program." Android only (recording is Android,
owner 2026-11-05). Branch `claude/series-recording`.

## Where the viewer finds it
- **Timeline guide, hold OK on a show to come**: the channel menu starts with
  **Record this show** (focused; Cancel recording once set) and **Record series…**.
  OK on a future block still tunes the channel (unchanged on purpose).
- Hold OK on a show on now / a past show / the plain list (= the show on now):
  **Record series…** after the other Record rows. On a show on now it also starts
  "record until the show ends" at once (`_recordSeries` → `_recordChannel(announce: false)`).
- Player > Channel schedule > OK on a show to come: the dialog
  (`widgets/programme_actions.dart`) has a Record series tile (only when the caller
  passes `upcoming`; `channel_schedule_panel.dart` does).
- Record series… asks **Every airing** / **Skip repeats** (`showSeriesChoice`).
  Stop series recording: same menus, or Recordings > Series (card, OK).
- A programme scheduled to record has a red dot in its Timeline block
  (`_ProgrammeRecMark`, listens to `RecordingService`). Series airings show a repeat
  icon on their Scheduled card.

## How it works (`services/recording_service.dart`, "series" section)
- `SeriesRule` (in `recordings.json`, device-only like recordings): channel id +
  title. Same show = `seriesTitleKey` (folded, without "(R)", "[HD]", "New:",
  "S2 E5"). Channel-only on purpose (a title on any channel would scan every row).
- `addSeries` schedules from `EpgService.upcomingPrograms(epgId)` (a DB query, not
  the Timeline's lazy cache); `refreshSeries` runs 75 s after startup and after each
  guide update (`main.dart _guideUpdatedForSeries`, EpgService `lastUpdated`).
  The guide only reaches a few days ahead: **new airings are only added while the
  app runs**; ones already scheduled fire with the app closed (native alarms).
- Each airing is a normal programme recording (`_programmeEntry`, exact guide
  window, `programmeKey`) with `seriesId` + `episode`. One save + one push per run.
- Limits: 8 days ahead, 20 upcoming airings per series (Android caps an app's
  alarms at 500). An airing needing a connection the playlist doesn't have
  (`programmeConflict`) is skipped and counted, never forced.
- Cancelling one airing (`stop` / `cancelProgramme`) records it in
  `rule.skipped`, so a refresh doesn't add it back (pruned a day after it aired).
- Guide changed: a scheduled airing whose slot now holds something else is removed
  (its new time gets added); a changed stop time updates `endAt`; a new channel URL
  reaches the scheduled ones.
- Skip repeats = same guide description (`seriesEpisodeKey`, >= 16 chars folded).
  No description = recorded. Our EPG DB doesn't keep XMLTV `<new/>` /
  `<episode-num>`: a real "new episodes only" would need those columns (DB change).

## Tests
`test/series_recording_test.dart` (title key, schedule/restart, repeats, refresh
cancel/move/relink/unloaded channel, conflicts, cap, stop),
`test/programme_actions_test.dart` (D-pad series flow, Back from the choice keeps
focus). The TV home hold menu is Android-gated (`RecordingService.supported`), so it
has no widget test on a Windows host: check it on the box.

## Box checklist
1. Timeline: Right to a show later today, hold OK > Record this show: red dot on
   the block, Recordings > Scheduled lists it. Hold again > Cancel recording.
2. Hold OK > Record series… > Every airing: snackbar "N scheduled"; Recordings >
   Series card with count + next; Scheduled cards with the repeat icon.
3. Cancel one scheduled airing, then Settings > Update EPG Now: it stays cancelled.
4. Series on a show on now: it starts recording at once.
5. Stop series recording from the Series card: scheduled ones go, recorded stay.
6. Player > Up > Channel schedule > OK on a show to come: Record series tile.
