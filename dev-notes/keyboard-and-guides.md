# Keyboard Back, Windows zapping, group browsing, more guides (+787, 2026-11-14)

A Windows viewer (Logitech K400 keyboard + trackpad, Canada, Sports Mode fan) sent 7 requests on
Discord; the owner said "great additions". All 7 are in test build +787; +788/+789 fixed what the owner found (below).

| # | Request | Where |
|---|---|---|
| 1 | Esc / Backspace = Back | `services/desktop_back_key.dart` (installed in main.dart on Windows/macOS/Linux) |
| 2 | Up / Down zap in full screen (Windows) | `DesktopPlayerScreen._zapChannel`, `_zapKeys` |
| 3a | Keep the groups column open | `TvHomeScreen._groupsHeldOpen`, Settings > Appearance > Live TV |
| 3b | Show a group's channels on highlight | `TvHomeScreen._onGroupHighlighted` (`onHighlight` on `_GroupRow` / `_SelectableRow`) |
| 4 | Several EPG URLs per playlist, in order | Settings > Playlists & sources > EPG > More guides (`_ExtraGuides`); `EpgService._runRefresh` |
| 5 | Side panel: stay open / switch while moving | `PlayerSidePanel._keepOpen` / `_zapOnMove`, Settings > Playback > Live TV |
| 6 | Resolution + FPS on the guide preview | `VideoPlayerPane.showBadges` (Android), `DesktopQualityBadges` in `_buildTimelinePreviewBox` |
| 7 | Hide the NFL RedZone button | Settings > Sports Trak > NFL RedZone button, or Hide this button in its hold menu |

## How each one works

- **Esc / Backspace (1).** A `FocusManager.addLateKeyEventHandler`: it only runs when no focused
  widget handled the key, so a screen's own Esc (side panel, source drawer, Multiview, Sports) and a
  text field's Backspace win. Backspace with focus in any `EditableText` is ignored. It calls the
  root navigator's `maybePop()` (not `handlePopRoute`: with nothing to pop, that calls
  `SystemNavigator.pop`, which can quit the app on Linux). So every page's `PopScope` decides, as
  with Android's Back. **`DesktopPlayerScreen`'s PopScope is now `canPop: false`** and routes every
  Back through `_handleBack`; a plain pop disposed a live channel instead of handing it to the mini
  player. Back order there: schedule > side panel > (focus on the bar: back to the picture) > leave.
- **Windows zapping (2).** Up / Page Up / CH+ = the channel above, Down / Page Down / CH- = below,
  with the root focused (not while arrowing the bar), live only. The list is
  `PlaybackService.zapList`; the TV home now sets it on the desktop paths too (`_selectChannel`,
  `_previewOrOpenChannel`). Otherwise the channel's own group. Same wrap and duplicate-id skip as
  Android. One stream per key-down (repeats ignored). After a zap the bar shows for 3 s if it was
  hidden (`_flashControls`). **Enter on a live channel opens the bar and focuses Play / Pause**: the
  keyboard's way into the bar now that Up / Down zap.
- **Groups (3a / 3b).** Both device-only, off by default (`vesper_keep_groups_open`,
  `vesper_groups_follow_focus`). 3a: `_collapsible(held:)`, `_columnWidth(held:)`, groups not drawn
  collapsed, TV tab only, never on a portrait phone. 3b: 300 ms after a group row gets focus (and
  the groups column still has it), `_selectedGroup` changes without moving focus, the live list
  jumps to its top, and the Timeline guide resets (it only takes focus if the grid had it). OK still
  runs `_onGroupSelected`. Remote and keyboard only in Settings (a tap already selects).
- **More guides (4).** The list already existed (`PlaylistProfile.extraEpgUrls`, at most 5, edited by
  the phone playlist editor and Vesper AI). New: the in-app list with Add / Move up / Remove, and
  **priority**. `EpgService._runRefresh` (a) merges sources that share a URL into one download with
  the union of channel ids; before, the second pass deleted the first one's rows as stale. (b) Skips,
  for each guide, the channels an earlier guide of the same refresh stored (`covered`,
  `_parseXmltvStream(skipChannelIds:)`, result `filled`). A failed guide counts its previous run's
  channels (`_filledBySource`, memory only). Order = each enabled playlist's own guide, then its
  extras, playlist by playlist (`PlaylistManager.epgSources()`, now shared by main.dart and the EPG
  page). The EPG page used to rebuild the list without the extra guides, and handed the app-wide
  timer a closure over its own `context`. Known limit: a guide that sends dummy "No information"
  rows for a channel still wins it.
- **Side panel (5).** `panelKeepOpen` / `panelZapOnMove` (device-only; zap implies keep open). Kept
  open, Last channels is frozen at open with the channel that was playing first (WATCHING tag), so
  rows don't reshuffle under the highlight. The highlight starts on row 1 (the last channel). OK on
  the playing row closes. Zap while moving: 700 ms after the last Up / Down, silent when a game has no
  channel. The panel re-takes focus after a switch.
- **Preview badges (6).** On by default (`vesper_preview_badges`). Android: `_QualityBadge` in the
  preview's top-right (`VideoPlayerPane(showBadges:)`). Windows: `DesktopQualityBadges` on the mini
  player box. Never on the full-screen video behind the guide (`badges: false`).
- **RedZone (7).** Per viewer (`vesper_sports_hide_redzone`). The hold menu's last row is Hide this
  button, and focus moves to Networks.

## After the owner's first test (+788 / +789)
- **FPS pill missing** on a .ts channel: its video track declares no frame rate. `_QualityBadge`
  (preview and full screen) now falls back to `DisplayMatch.frameRateOf` (StatsBridge: declared,
  else `ptsFps` from the vendored FrameRateProbe, which always runs).
- **Half-drawn frames** on the Timeline guide with the preview playing (and before on Home, +783).
  `dumpsys SurfaceFlinger`: video SurfaceView DEVICE, the empty app window DEVICE, and the Flutter
  SurfaceView **CLIENT**: the GPU blended the whole menu layer each frame, on top of drawing it
  (Flutter raster 32-52 ms). The box output was 4K HDR10. Owner: 8-bit + HDR off hid it. Fix: Advanced >
  Device fixes > **Draw the menus inside the app window** (`vesper_ui_texture`, read by
  `MainActivity.getRenderMode`; restart). On: a TextureView, as every box ran until +745. Layers =
  video + window, both DEVICE; raster 17-26 ms; gfxinfo median 23 ms. Owner: no tear. **On by default
  since +789**, for every Android box with the native surface. Owner asked if it should be
  per-device: no, the cause is generic (few hardware planes on TV chips). The switch stays in
  Advanced as an escape hatch.
- **Show channels while moving through groups felt very slow**: it waited 0.3 s, less than a normal
  pause between presses, so nearly every group on the way loaded (a group change costs ~645 ms on the
  Homatics). Now 0.7 s. Owner: all three good on +789.

## Tests
`test/desktop_back_key_test.dart`, `test/epg_guide_priority_test.dart`,
`test/tv_groups_keyboard_test.dart`, `test/player_side_panel_keep_open_test.dart`. Not covered: the
Windows player's zap (media_kit), the badges, the RedZone menu.

## To check on a device
Windows: Esc from full screen keeps the live channel in the preview; Up / Down zap; Enter, then Esc,
then Esc. Homatics: groups follow focus + keep open with a big playlist (frame cost), side panel
modes, badges on the Timeline preview, More guides with a real second XMLTV.
