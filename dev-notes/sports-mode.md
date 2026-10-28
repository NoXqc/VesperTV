# Sports Mode

Owner requested a sports home based on the Media Hub rail/floating-bar navigation,
keeping Sports Trak's existing features. Branch `codex/sports-mode`, test +487.

## Entry and saved state

- Sports Trak's **Sports Mode** pill opens a switch. The same switch has its own
  destination in Settings > Interface > Sports Mode.
- Default off; `vesper_sports_mode` is viewer-scoped using the standard storage
  suffix. Main's key is unchanged. Included in backup/transfer and the explicit
  Main-profile copy **Sports** option; viewer deletion removes the suffix normally.
- Changing the switch releases the previous player, saves the preference, and
  pops to the rebuilt root. It leaves the existing Startup > Open on choice intact.
- `main.dart` chooses the sports root for the active viewer/language. StartupRoutes
  creates one root without another Sports overlay; the old pending-overlay guard
  is cleared. Automatic last-channel playback yields to Sports Mode.
- Turning it off restores the usual TV root. On a later launch the original
  startup choice applies again. Profile changes use the existing stop/reload/remount.

## Layout and shared behavior

- Same SportsScreen instance owns feeds, matches, picks, preview, polling, hides,
  reminders/recording, standings, teams, networks, quality preference and scores.
  No alternate data layer, duplicated player or native player changes.
- First five enabled leagues in saved order form the sidebar. All remaining
  leagues, All, Edit leagues, quality, scores and Sports Mode are floating pills.
  Hold OK and Left/Right still reorder leagues, including across the fifth slot;
  OK/Back finish. No separate pinned-league preference to drift out of sync.
- Followed-team games have their own My Teams row and are removed from other rows
  to avoid duplicate focus nodes. Other games remain Live now / Later / Final.
- Day strip, Standings/My Teams/Networks/RedZone, game menus and full-screen entry
  keep their existing actions. TV keeps the hero/video fixed and scrolls the rows;
  phones/narrow or short windows scroll the whole page as the original phone UI did.
- Sidebar links respect hidden tabs. Settings still calls requireUnlock; Profiles
  uses the existing guarded profile screen. Live TV provides the usual other tools.
- Destinations close the sports preview before opening; returning releases any
  destination player with no surface on the sports home. Live TV's terminal Back
  returns to sports; its Sports Trak shortcut returns to the existing root.

## Remote navigation

- Rail: explicit Up/Down, reveal off-screen entries, Right to remembered content.
- Controls: explicit Left/Right within league/day/tool rows. Left at the first
  control returns to the rail; Up/Down follow the existing sports zones.
- Games: Left/Right handle repeats and build/scroll off-screen cards before focus;
  row changes remember cards. Left at the first card returns to the rail.
- All vertical sections are mounted (at most four), with lazy horizontal game
  lists. This keeps row destinations available without building every game card.
- Cards grow vertically with enlarged text; section headings truncate and the
  hero's information fits its available space. Native video geometry is unchanged.
- Back finishes moves, clears a picked game or stops preview as before. Browsing
  Back returns to the rail; Back there asks before exiting the sports root.
- Networks excludes the hidden games page from focus and restores its action on Back.

## Verification and device acceptance

`test/sports_mode_test.dart` covers saved state/backup/transfer, held-OK reorder
across the rail boundary, long rows, remembered cards, Networks/Live TV return,
loading/empty states, switch, FR/EL large text and the My Teams focus identity.
Startup tests cover single-root routing with Fast startup on/off. Local optional
font previews use SPORTS_MODE_PREVIEW / SPORTS_MODE_PREVIEW_FONT / SPORTS_MODE_PREVIEW_ICONS.
Exact final analyze/test/build/install results belong in root HANDOFF.md.

Owner should check both switches, cold startup, held arrows, league reorder,
preview/full-screen/Back, Standings/My Teams/Networks and returning from app links
on the Formuler. These physical checks are not replaced by widget tests.
