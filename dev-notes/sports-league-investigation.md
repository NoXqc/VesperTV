# Sports Mode league investigation (Codex, 2026-10-29)

Baseline: released 1.0.45+496, c4e2940. Branch:
`codex/sports-league-investigation`. Investigation only; no application changes,
version bump, device operation, build, push or release.

## Findings

1. **Confirmed: vertical sidebar reorder uses the wrong axis.**
   `sports_mode_shell.dart:178` handles Left/Right during move mode and consumes
   Up/Down without moving. Its indicator at line290 is `swap_vert`.
   The outer `sports_screen.dart:1504` shortcuts also bind only Left/Right.
   Narrow/horizontal layouts legitimately use Left/Right, so an eventual fix
   must distinguish orientation and preserve ordering across the fifth slot.

2. **No activation cap reproduced.** League manager `_add` (line170) and
   `_toggleShown` (line159) append enabled IDs without disabling another league.
   Diagnostic UI test added NCAA Men's Basketball from the real League bank
   with every base league, including MLB, still enabled. The new league could
   be selected and requested from the mocked feed without removing MLB.
   All enabled leagues are in the horizontal scroller: first five are in the
   sidebar (`sports_screen.dart:2093`), remainder in the top bar (line2249).
   Arrow navigation reached an initially off-screen college-basketball chip.
   Five sidebar slots and the visible top-row area are not enabled-league limits.

3. **Reproduced explanation for apparent absence: the old filter stays active.**
   A saved favourite MLB opens with the MLB filter (`sports_screen.dart:247`).
   Adding college basketball in Edit leagues leaves that still-valid filter
   selected (`_editLeagues`, line846): the feed continues requesting only MLB.
   Choosing college directly or through the All menu requests college instead,
   with both leagues still enabled. Disabling MLB would clear an MLB filter,
   but the user's exact settings/actions are unknown, so this remains an
   explanation of possible behavior, not a confirmed diagnosis of their case.

4. **Additional confirmed focus/visibility bug across the rail boundary.**
   Reordering a top-row league from sixth to fifth stores the right order and
   keeps its node focused, now under `sports-mode-rail`, while the sidebar
   remains Offstage. Moving fifth to sixth does the reverse: focus leaves the
   rail but it remains shown. Normal remote arrows plus hold OK reproduce both.
   `SportsModeShell._railFocused` only updates via its scope focus callback
   (line301); reparenting the already-focused node between bar/rail can leave
   that cached state stale. Offstage at line380 uses that stale flag. A fix
   needs to reconcile the rail and parent focus/visibility state when a moved
   league changes containers, not just change the reorder arrows.

5. **The proposed All dropdown already exists, behind hold OK.**
   `_leagueControls` line2239 binds hold All to `_openLeagueMenu` (line752).
   It lists every enabled league in saved order, including sidebar leagues,
   off-screen top-row leagues and leagues with no games (line770). Short OK
   clears the filter. Diagnostic test selected distant college basketball from
   this menu while MLB stayed enabled. There is no 10/11-league cap.

## Recommendation

Fix vertical reorder and the container-transition focus bug first. Make All's
existing menu discoverable with a visible dropdown affordance; if short OK opens
it, keep All leagues as the first menu choice. Prefer listing every enabled
league rather than changing menu membership as the viewport/scroll position
changes. Do not alter enabled-league settings or auto-disable MLB to solve this.
Exact design/implementation remains for the owner; no redesign was applied.

## Evidence

Seven temporary diagnostic widget tests: five passed; two intentionally asserted
correct rail visibility and failed, reproducing both boundary-transition bugs.
The passing cases verify the reported wrong axis, correct horizontal-axis use,
real manager addition without disabling leagues, off-screen arrow access and
the existing All menu including quiet/off-screen leagues.
The shipped Sports Mode suite still passes all23 tests; it already tests reorder
across the boundary but does not assert whether the rail is visible there.
Diagnostic source and failure logs retained locally (not permanent regression
expectations for broken behavior):
- `build/sports-league-investigation/sports_league_diagnostic_test.dart`
- `build/sports-league-investigation-tests.log`
- `build/sports-league-promotion-repro.log`
- `build/sports-mode-existing-tests.log`
- `build/sports-league-investigation-analyze.log`

## Owner-requested fix (2026-10-29)

Implemented on `codex/sports-league-fixes` after the investigation above. The
sidebar uses Up/Down, horizontal locations use Left/Right, and indicators follow
the rendered axis. Actual focused-entry membership drives rail visibility;
post-layout reconciliation updates parent Back state and the remembered entry
even when a focused node moves between containers without a focus event.
Sports Mode All now shows a dropdown arrow and opens its existing league menu
on short OK/click or hold. All leagues stays first; every enabled league stays
available. Regular Sports Trak retains tap All to clear and hold All for menu.
No activation limit, preference rewrite or automatic league disabling added.

Permanent coverage is in `test/sports_mode_test.dart`: the original boundary
case now checks both visibility and focus, plus8 new cases cover axis/repeats,
narrow layouts/orientation changes, promotion/Back, menu selection/cancel/clear,
real League manager addition with MLB retained, and normal Sports Trak parity.
The owner subsequently requested a combined build/install/commit: Formuler test
1.0.45+500 includes these fixes, matchup key stats, preview changes and the latest
Multiview changes. Physical acceptance and exact final checks: root HANDOFF.md.
No public release was requested in that follow-up.
