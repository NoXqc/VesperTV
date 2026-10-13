# Features worth knowing (behaviour that is easy to break)

Read before changing guide/Multiview/profiles/palettes/backup-server logic.

## 12. Features worth knowing
- **Timeline guide** (Settings > Theme > Live TV guide = `guideViewMode` 'live'|'timeline'):
  `_TimelineGuide*` in tv_home_screen.dart. Left/Right step 30-minute slots (`moveHorizontal`),
  Up/Down keep the time column (live "now" for a currently-airing block), entering from groups and
  returning from fullscreen restore focus at the current time, long blocks keep a sticky label, rows
  with no EPG show a placeholder, hold-Select opens a favourite/hide menu. "Live" = compact
  now/next list with details below.
- **Player controls:** a primary row plus a secondary row revealed by pressing Down again (a chevron
  hints it exists); every icon button has a text label; top row shows quality (HD/FHD/4K), FPS and
  audio-channel (e.g. 5.1) badges. "Multiview" button opens Multiview with this channel preloaded.
- **Multiview:** 2 stacked screens or 4 (2x2), toggled by the "2 screens / 4 screens" button in
  the top bar (Up from the top row; remembered in `vesper_multiview_quad`). On entry a popup
  explains one-connection-per-screen, with "Don't show this again" (`vesper_multiview_hide_tips`).
  Select = move audio (volume only), hold Select = Full screen / Reload / Change channel / Remove.
  Keeps the screen awake. Channel picker: group list + search + the current programme under each
  channel; Right from a group lands on the first channel (not the search field — Fire OS keyboard).
- **Settings > General** (Android only, `general_settings_screen.dart`): "Resume last channel at
  startup" (default on, `vesper_resume_last_channel_at_startup`) and "Show the Multiview tip". Home
  for future small switches (candidates: start-on tab, picture fit, audio language, 12/24 h, confirm
  on exit). Channel up/down in the player is deliberately not done yet — owner wants a better
  scheme adapted to this app first.
- **Welcome prompt:** brand-new users (no playlists) get "Hey beautiful Human, Welcome to
  VesperTV" with Add Playlist / Skip for now.
- **Hide individual live channels** (per playlist, `hiddenChannels`), unhide in
  Settings > Playlist Manager > Hidden Channels. Group hiding is separate. Hold Select on a movie/
  TV group offers **Expand catalog** (full-screen poster grid), Favourite, Hide.
- **Movies/TV Shows:** hero + poster rows; hero description fetched after a 400 ms dwell and cached
  in `PlaylistManager` (shared with the detail screens).
- **Backup servers:** connect tries last-working → main → backups (one pass); live stream *open*
  failures retry other servers. Mid-stream drops do not fail over. Sticks to last-working server.
- **Palettes:** duo-tone `primary`/`secondary`; optional `highlight` is wordmark/swatch decoration
  only (Habs uses white). Old id `green_orange` maps to `habs`. `isMinimal` (Platinum) = flat black
  with translucent-white glass focus; `trueBlack` (Dark / Gold) = hand-built scheme.
- **Viewer profiles** (`ViewerProfile`, `ViewerProfileService`): several viewers sharing one
  device's playlists, each with their own favorites/hidden-groups/watch-history. Main's data lives
  under every *existing* unsuffixed storage key, completely unchanged — never add a step that
  rewrites Main's keys on upgrade; a second-or-later viewer's keys get `__vp_<id>` appended by
  `StorageService._vk`/`_vkp` instead (position/duration keys keep the suffix at the very end, not
  after the prefix, so `clearCache()`'s `startsWith` sweep still catches every viewer's). A
  restricted ("kid") viewer uses a *shown-groups allowlist* (`keyShownGroups`), not the blocklist
  every other viewer uses — see `PlaylistSession._loadViewerScopedState`'s doc comment for why a
  new category must default to hidden for them, not visible. `CatalogDatabase`'s own `is_favorite`
  column stopped being the favorite source of truth — `PlaylistManager` injects a live callback
  (`isVodFavorite`/`isSeriesFavorite`) instead; only write that column while Main is active.
  `ViewerProfileService.requireUnlock` is the single PIN choke point for *opening Settings at all*
  from a restricted profile; any direct, non-Settings control that can un-hide something (the TV
  live-channel long-press menu's "Unhide") needs its own `requireUnlock` check. A profile switch
  (`switchTo`) stops playback *before* flipping the active viewer id, then calls
  `PlaylistManager.applyActiveViewer`/`PlaybackService.reloadForViewer`; it only shows because
  `main.dart` wraps the home screen in `Consumer<ViewerProfileService>` keyed by the active viewer's
  id, which remounts the home screen from scratch.
