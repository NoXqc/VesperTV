# Android phone player touch lock (cdx, 2026-10-30)

On `codex/phone-touch-lock`, based on committed test 1.0.49+531.

- Tap fullscreen video, then the open padlock in the top bar to lock.
- Controls hide; taps, swipes, app Back and underlying focus are blocked.
  Video, audio, subtitles and automatic episode advancement continue.
- A 56 logical pixel closed-padlock target stays at the left inside SafeArea.
  One tap unlocks and restores both bars with their usual inactivity timeout.
- Android phones/tablets only, including landscape and forced TV layout;
  actual TV hardware and Windows do not get the button.
- Rotation and in-place episode changes retain the lock. PiP hides/suspends
  the overlay and restores it on return. Leaving the route resets the lock.
  Android Home, volume and other OS controls remain available.
- No setting, persisted preference, native-player change or version bump.
  EN/FR/ES/IT/EL labels; remote guide and generated help index updated.

`PlayerTouchLock` wraps the player's gesture detectors with AbsorbPointer
and ExcludeFocus. A barrier placed *inside* the existing video GestureDetector
would still let the ancestor receive taps. Keep the wrapper and child slots
stable across toggles so the native video stays mounted. Its PopScope blocks
Back while the nested player's callback ignores that blocked pop.

Six full-player widget regressions cover live/VOD blocking, unlock restoring
pause, persistent reminder, rotation, episode changes, route reset, PiP and
TV/desktop gating. Existing source-drawer and player tests run in the full suite.
Real-phone playback/gesture/overlay verification is still required.

Integration: main has Claude's uncommitted skip-pill focus/diagnostics and
sports-odds work. This branch intentionally starts at fcc3abf and does not
include those edits. Preserve the newer SkipSegmentButton arguments when
integrating the `if (!touchLocked)` guard. Merge remote-guide rows and
translations, then regenerate guide.json/count from the combined guide.
