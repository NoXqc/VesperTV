# Programme reminders and scheduled recording (cdx, 2026-10-28)

Owner requested Remind me / Record for upcoming shows in Channel schedule,
with the existing +483 work in a Formuler test. Package version is +484.

## Schedule actions

OK/tap on a future programme opens a remote-friendly menu. Remind me becomes
Cancel reminder; Record becomes Cancel recording (or Stop recording if it
starts while the menu is open). Closing returns focus to the same schedule row.
Opening OK repeats/key-up cannot trigger an action. Busy actions reject repeat
requests; failures stay visible instead of claiming success. Narrow screens and
large text scroll. Past/current playback, paging and one-node list selection
remain unchanged. Eight new strings have FR/ES/IT/EL entries.

## Reminders

`ProgrammeReminders` stores programme/channel/start identity, title, time and
delivery flags in a viewer-scoped, device-local preference. It contains no stream
URLs. Transfer skips this key, matching game reminders. Cancellation and save
failure rollback are supported; corrupt entries and expired programmes are ignored.

`ProgrammeReminderOverlay` runs deadlines only while foregrounded, above routes
at bottom-right (sports alerts remain at the top). Five-minute and start notices
last12s without focusing or tuning. Close is touch/mouse accessible but excluded
from remote focus. Viewer/background changes clear pending cards; late advance
notices are skipped after1min, start notices after2min or programme end. Saved
delivery flags prevent duplicates across app restart. VesperTV must be open for
these reminders; there are no background OS reminder notifications.

## Recordings

`RecordingService.recordProgramme` uses the existing Android RecorderScheduler
and RecorderService, unchanged natively. Start/end are the exact EPG window,
without Sports' early/overtime margins. Entries are plain channel recordings,
with a persisted programmeKey for deduplication and cancellation, and show in
the existing Recordings tab. Restart/boot behavior remains the native alarm path.
The box must remain powered; Android force-stop/unsupported streams/provider
limits still apply. If exact alarms are unavailable, the menu reports that Android
may delay the start. No extra permission flow is introduced.

Storage is the chosen mounted recording volume, with the existing cap/free-space
limits. New schedules require writable metadata and successful native scheduling;
failure rolls back. Saves are serialized to avoid temp-file races. Cancellation
replaces the native schedule, stops that ID if it raced the start, and keeps a
partial recording when already running. Overlap checks sweep actual simultaneous
recordings on the same playlist, honoring its reported connection limit (unknown
=1), and allow adjacent windows. Native/status polling notices scheduled starts.

Two seconds before an upcoming programme recording, the foreground app releases
the *same live channel's* provider connection and rejoins via the existing local
recorder tap once ready. Playback generation, viewer and foreground guards keep
a later stop/channel choice from being undone. This does not tune a different
channel, alter catch-up, or change the patched player. Watching other channels
still needs sufficient provider connections, as with existing Sports recording.

## Verification and test

Tests cover reminder delivery/persistence/viewer isolation/staleness/rollback,
native schedule payload/times/storage/reload/cancel/failure/inexact result,
overlap sweeps, one-time foreground preparation, guarded playback handoff,
root overlay focus/lifecycle, held OK, menu cancel/reopen and narrow large-text
navigation. Full analyzer/test/build/install results are in root HANDOFF.md.
Analyze16, all825Flutter tests and15help tests passed. Production-signed1.0.43+484
built45.2s and installed over+482 on Formuler; version, cert, ZIP,3ABIs and installed
APK hash verified. The existing Sports calendar image-cache fixture failed once
asynchronously in a full run, passed isolated, then all825 passed on full rerun;
no unrelated Sports source/fixture changes were made.
Remote tips and the local help index describe the actions; no deployment/posting.

Formuler test: live player OK → Up → Channel schedule → OK, Down to a future show,
OK → Remind me and/or Record. Reopen to cancel. Check Recordings > Scheduled,
then let a nearby programme start and confirm the popup and recording state/file.
Also verify same-channel playback through the recorder and a later explicit stop.
Device acceptance remains pending until the owner performs these actions.

## Compact information card follow-up (+485)

Owner photo showed the separate Channel schedule chip making the large info
overlay taller. `LiveChannelInfoCard` now contains that action in its header,
with a 620px maximum width (previously 760), 40px logo (56), 12/10px padding (16/12),
compact text, and a one-line description. The player positions the combined card
48px below the safe top edge. Narrow or larger-text layouts keep the same action
inside the card on its own row; touch targets remain 44px. Time/progress stack
when necessary, avoiding narrow/large-text overflow.

The same player-owned focus node and key callbacks are passed into the card;
visibility still excludes focus/pointer events. No schedule-opening, reminder,
recording, guide lookup, catch-up, Data pool, timers or native-player behavior
changes. Existing channel/playlist labels and programme time/progress remain.
Tests verify control containment/compact TV geometry, stable focused geometry
and guide updates even without debug labels, missing guide/touch, catch-up
playhead data, FR/EL large text, and actual PlayerScreen OK/Up/OK/Down/Back flow.
Exact +485 checks/build/signature/install results are recorded in HANDOFF.md.
