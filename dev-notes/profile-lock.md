# Profile lock (2026-11-23)

Users asked (via the owner): a kid who leaves the app, or starts it in the morning, lands in Main or
an adult profile. Kids profiles already needed the PIN to *leave*; nothing guarded *entering* an
adult profile, and VesperTV reopened the last profile used.

## What it does

- **Settings > Profiles > a profile > Lock with PIN** (any non-kids profile, Main included;
  `ViewerProfile.isLocked`, saved in the profile list, so it syncs / transfers with the PIN).
  Turning it on or off asks the household PIN (one is set up first if none exists); turning it off
  with no PIN set needs nothing (`ViewerProfileService.setLocked`).
- Opening a locked profile asks the PIN everywhere a switch happens: Who is watching?, Home's
  profile cards, the profile page's Switch, Vesper's `profiles` tool (`needsPinFor`, `switchTo`).
  Its Settings > Profiles page asks the PIN too when another profile is in use
  (`openProfileEditor`): it can rename, unlock or delete it.
- **A start with a locked profile in use** shows Who is watching? (main.dart `_bootstrap`:
  `lockActive()`, even with Launch with profiles selector off); picking that profile asks the PIN.
- **Back after time away**: `AppLifecycleListener` (`_lockLifecycle`, registered before the other
  listeners) stamps `_leftAt` on hide and, on resume, `_relockIfDue` sends a locked profile in use
  behind Who is watching? when `profileRelockDue(away, minutes)`. **Settings > Profiles & startup >
  Lock profiles again**: Every time VesperTV is left (0) / After 1 / 5 / 15 / 30 minutes / After
  1 hour; 5 until chosen; device-only (`vesper_profile_relock`, in `_syncSkipExact`). It sets
  `_profileSelection` synchronously so the warm-return resume (`AppExit.afterWarm`) waits for the pick;
  picking the same profile again resumes its channel (`_resumeIfViewer`).
- Back at the root to Who is watching? (Launch with profiles selector on) also locks a locked
  profile in use (`_returnToProfiles`).
- Cards: the padlock badge now means "locked"; kids profiles show a child icon instead.

## Not covered

- Only "hidden" counts as leaving (Home button, another app, minimised, screen off). A dialog or the
  notification shade (inactive) never relocks; phone picture-in-picture keeps the app visible.
- Settings itself is not behind the PIN in an unlocked adult profile (as before); a kid is meant to
  be on a kids profile, where Settings already asks the PIN.

## Tests

`test/profile_lock_test.dart`: relock time, JSON, `needsPinFor`, the PIN pad on a locked switch,
`lockActive` + same profile asks again, wrong PIN keeps it shut, unlocked / kids never locked out.
