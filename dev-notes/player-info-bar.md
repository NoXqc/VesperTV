# One bottom info bar for the live player (built 2026-11-17, test +823)

Owner: "Build the bottom bar" after the Discord poll (~90 % for "at the bottom"). Branch
`claude/player-info-bar` (worktree `VesperTV-claude-infobar`).

## What was built (+823)
- `PlayerControls(liveInfoBar: true)` -> `_buildLiveInfoBar` (player_controls.dart): one bar,
  `PlayerControls.liveInfoBarHeight` = 112 at 1x (225 px at 1080p), the same in both states.
  Line 1: `PlayerBarClock` | logo, channel name (max 26 % of the width), playlist `GoldTag` |
  programme (or "No program data available") ... "N min left", `RecPill`, quality / FPS / sound
  as `GoldTag`s (`_QualityBadge(gold)`, `_AudioChannelBadge(gold)`). Line 2: `_LiveTimeline`
  with the accent fill (catch-up channels: Up from the buttons, Left/Right into catch-up, as
  before). Line 3: the description (whitespace folded to one line), lined up with the progress
  bar by invisible start / end times; two lines since +825 (owner photo).
- `PlayerScreen`: `_infoBar` = remote (`!_touch`) and `channel.isLive`. A zap (`_zapTo`, CH+/-,
  Up/Down, Right = last channel) shows the bar display only (`_zapInfoVisible`, still
  ExcludeFocus'd: Up/Down keep zapping); OK (`_bottomVisible`) adds `_InfoBarButton`s ☆ /
  Play-Pause (`_playFocus`) / Channel schedule (`_openSchedule`). Down = options row, Back =
  hide, 6 s = hide, as before. The top info card (`LiveChannelInfoCard`) stays for catch-up and
  touch only; Up no longer goes to its chip in info-bar mode.
- `_InfoBarButton` acts on KeyDown only (swallows the Homatics' late OK repeat, which would
  have paused the channel the OK just opened the bar on).
- Subtitles move up over the bar while it shows (`AnimatedPositioned`), the top-right clock pill
  hides while the bar shows (the bar has its own clock), the Watch game pill sits on the bar.
- Not changed: catch-up (old card + bar with its controls), movies / episodes, phones / tablets,
  Windows (`DesktopPlayerScreen`, later).
- Tests: `test/player_info_bar_test.dart`, `test/live_channel_info_card_test.dart` (actual
  player flow: OK, Up stays, Right = Channel schedule, OK = panel, Back).

## Why
Users suggested moving the live player's top info card (logo, channel, playlist tag, Channel
schedule, programme, times + progress, description) into the bottom bar, like other IPTV apps
(owner's example: a French app's one-row bar with clock, logo, channel, programme, progress,
star, pause, PROGRAMMES, time left, FHD / 25 FPS). Today the channel name, the times and the
progress show twice (card + bar), and the two take ~370 px at 1080p.

## Mockups
`C:\Users\aarse\VesperTV-mockups\vesper_bar_zap.png` (channel up/down) and `vesper_bar_ok.png`
(after OK), rendered with Flutter over a real frame (CNews), 1920x1080. Not in git (images).

## Planned layout (logical px at 960x540, the box's 1080p)
- Line 1 (34): clock | channel logo | channel name + playlist GoldTag | programme title
  .......... "24 min left" + quality / FPS GoldTags.
- Line 2: start time ─── gold progress ─── end time.
- Line 3: programme description, one line (owner: viewers want it on a zap too).
  - Channel up/down: full width, display only (nothing focused: Up/Down keep zapping),
    hides after a few seconds.
  - OK: the line shortens and ☆ / Play-Pause / Channel schedule appear at its right; the
    bar doesn't change height. Down = the options row as today.
- Height: 225 px at 1080p in both states (vs ~370 px for card + bar today). Owner: subtitles /
  CC don't need moving for that much; check they sit above it while it shows.

## Still open
- Windows (`DesktopPlayerScreen`).
- No setting to bring the old top card back (the poll wasn't split).
