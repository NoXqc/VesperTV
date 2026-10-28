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

## Bigger video + hidden rail (Claude, test +488, 2026-10-28)

Owner: bigger player, days out of the way, a Left-arrow menu like Live TV.
- TV (not touch/narrow/short): the rail is `Offstage` (still mounted, nodes
  focusable) unless it has focus; Left from the first control/card opens it,
  Right/any content focus closes it. A `‹`-style edge tab (`sports-mode-rail-tab`)
  marks it and opens it on click. Pushes the content, never overlays the video.
- No day strip in Sports Mode: zone 1 is empty and skipped by `_moveZone`; the
  day is the `day:menu` chip leading the tools row (zone 2, roll-down of
  Yesterday..+6 days). Normal Sports Trak keeps its strip.
- Playing hero height = content height minus tools row and one card row
  (`_Hero.playingHeight`, 168..420); at 960x540 the video is ~236x420 (was 160x284).
- +489 (owner photo: cards cut off under the wide hero): while a game plays,
  TV Sports Mode splits below the tools row: left column = the game
  (`_HeroPart.info`, the phone VS layout) above the rows, right = the video
  (`_HeroPart.video`) + its hint. Video height = min((width - card - 56)*9/16,
  height - tools - 32); ~312 px high at 960x540. Not playing = old layout.
- +490 (owner: cards slid behind the video; wanted the side panel's live
  feed): "watching" = left column is `_buildFeed` (all day sections flattened,
  headers + `_FeedRow`s, one focus node `_feedNode`, rows drawn selected),
  right = big video. Feed: Up/Down rows, Up at top = tools, Down past the end =
  "browsing" (`_modeBrowsing`: small 168 hero + full-width card rows), Up from
  the top card row (or its See all chip) = back to the feed; OK = watch in the
  video (OK on the playing one = full screen), hold OK = SportsGameDetailsDialog,
  Play/Pause toggles, Left = rail. Starting a preview resets to watching and
  moves focus to the feed; stopping from the feed refocuses the rows.
  No widget test covers watching/browsing (needs a matched, playing channel).
- +491: `_focusZone` sends any row zone to the feed while it shows (Right
  from the rail was stuck: it targeted an unmounted card). Right on a feed
  row = full screen (`_feedFullScreen`); hints say "→". Feed selection redraws
  from `_feedNode` (ListenableBuilder). Card rows get 8 px side padding in
  Sports Mode so the focused card's 1.05 zoom isn't clipped at the left.

## Live TV panel (Claude, test +495, 2026-10-28)

Owner: browse channels without leaving Sports Mode. TV layout only (touch/
narrow/short keep pushing TvHomeScreen). `widgets/sports_mode_live_panel.dart`;
TvHomeScreen untouched.
- Rail Live TV opens `SportsModeLivePanel` in the shell's `live` slot: a groups
  column (230) that pushes the page right, and on OK/Right a see-through guide
  (440, black .78) floating over the page. Rows: "Open full Live TV" (the TV
  home via `_openModePage`), Favourites, own groups, playlist groups (hidden
  playlists + live group sort honoured).
- One focus node per column with its own index (`sports-live-groups` /
  `sports-live-guide`), fixed-extent lazy lists, `jumpTo`; CH+/-/PgUp/PgDn
  move 8. Last group/channel remembered for the session (statics).
- OK on a channel: `_playLive` sets `zapList`, `_play(channel)` (ends the
  hero's game preview: one stream), full screen; Back returns to the guide and
  stops the stream (no surface on the sports home).
- Back: guide -> groups -> closed with focus on the page (rail stays hidden);
  Back from the rail closes the panel. `_liveOpen` blocks the PopScope pop.
- Not in v1: channel hold menus, History, Catch-up, Timeline. Windows untested.
  No test with a playing game preview + panel (needs a matched channel).
Owner on +495: "Open full Live TV is a very nice touch".
