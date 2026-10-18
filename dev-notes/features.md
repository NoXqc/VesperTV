# Features worth knowing (behaviour that is easy to break)

Read before changing guide/Multiview/profiles/palettes/backup-server logic.

## 12. Features worth knowing
- **Timeline guide** (Settings > Theme > Live TV guide = `guideViewMode` 'live'|'timeline'):
  `_TimelineGuide*` in tv_home_screen.dart. Left/Right step 30-minute slots (`moveHorizontal`),
  Up/Down keep the time column (live "now" for a currently-airing block), entering from groups and
  returning from fullscreen restore focus at the current time, long blocks keep a sticky label, rows
  with no EPG show a placeholder, hold-Select opens a favourite/hide menu. "Live" = compact
  now/next list with details below.
- **Select = preview, Select again = fullscreen (1.0.9+246):** on the Timeline guide and the plain
  Live list (remote, touch, mouse alike) `TvHomeScreen._previewOrOpenChannel` plays the channel
  in the corner preview box; pressing the *now-playing* channel again goes fullscreen. Owner's
  request (changing channel meant fullscreen + back). Deliberately **not** a timed double-press
  (would delay every press ~300 ms, remotes misread timing); a quick double press still works
  as two presses. `_previewChannelId/_previewFuture` make a fast second press await the first
  `play()` (black-screen race). The plain list hands the playing row `_currentChannelFocusNode`,
  so focus is re-requested after the swap. Windows: `DesktopMiniPlayer.play()` starts the stream
  in the holder (reuses its `Player`, own completed→reopen), fullscreen = `take()` + push
  `DesktopPlayerScreen(existingPlayer:)` — no restart. History dialog / Continue Watching still
  go straight to fullscreen (`_selectChannel`).
- **Full-screen video behind the guide (1.0.10, Android only):** Settings > Theme, shown when
  the guide is Timeline (`guideFullVideo`, key `vesper_guide_full_video`, off by default).
  `TvHomeScreen._fullVideo` (TV tab, landscape, not Windows — playing or not): the video is one
  `Positioned.fill` layer behind the whole screen and the corner box is left **empty** (never two
  views of the same controller — the filter bar skips its box too). Guide = 3 rows at the bottom
  (SafeArea bottom 4), `_fullVideoScrim` (same wrapper always, only the colour changes, so columns
  never remount), lighter "now" blocks (`translucent`), tabs/groups columns hidden completely at
  depth > their own (`_collapsible` width 0, child laid out at >= 56 px and clipped), description =
  small card pinned top-right (`_buildFullVideoNowCard`, pending-resume channel when idle).
- **Fullscreen side panel (1.0.10, Android):** Left in `PlayerScreen` (live, no bar focused) opens
  `PlayerSidePanel` — Last channels / My Teams (today's games of followed teams) / Live now (live
  games of active leagues). Left no longer exits: **Back only** (PopScope closes the panel first).
  Explicit key dispatch from one Focus (Left/Right tabs, Up/Down rows, OK plays the channel or the
  game's best match). `savedSportsLeagues()` is shared with the Sports tab; one static
  `SportsChannelMatcher` per session.
- **Movies/TV Shows tab stops a background live channel (1.0.10, Android):**
  `_parkLiveChannel` stops it and makes it the pending-resume channel, so the pill + hold-Right
  restart it. Windows not done (its pill only resumes a running session).
- **Player controls:** a primary row plus a secondary row revealed by pressing Down again (a chevron
  hints it exists); every icon button has a text label; top row shows quality (HD/FHD/4K), FPS and
  audio-channel (e.g. 5.1) badges. "Multiview" button opens Multiview with this channel preloaded.
- **Multiview:** 2 stacked screens or 4 (2x2), toggled by the "2 screens / 4 screens" button in
  the top bar (Up from the top row; remembered in `vesper_multiview_quad`). On entry a popup
  explains one-connection-per-screen, with "Don't show this again" (`vesper_multiview_hide_tips`).
  Select = move audio (volume only), hold Select = Full screen / Reload / Change channel / Remove.
  Keeps the screen awake. Channel picker: group list + search + the current programme under each
  channel; Right from a group lands on the first channel (not the search field — Fire OS keyboard).
- **Settings > General** (`general_settings_screen.dart`): Android-only "Resume last channel at
  startup" (default on, `vesper_resume_last_channel_at_startup`) and "Show the Multiview tip"; on
  every platform a **History** section: "Clear search & channel history" (recent searches + live
  channels in History) and "Clear Movies & TV Shows history" (VOD/episode entries in the recently-
  played file + the active viewer's saved positions/durations). Active viewer only. Home
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
  with translucent-white glass focus; `trueBlack` (Dark / Gold) = hand-built scheme; `vivid`
  (Neon Green, id `neon_green`) = seeded like Neon Purple but keeps the raw neon as `primary`
  with black text on it (seeding turned it pale mint).
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

- **Add Playlist > "From phone"** (test build +216, uncommitted): the TV shows a QR code; the phone
  fills `assets/pair/pair.html` and the details land in the M3U/Xtream fields (nothing is saved
  until the user presses Add Playlist). `PhonePairingSession` (`lib/services/phone_pairing_service.dart`),
  UI `widgets/phone_pair_panel.dart`. **Wi-Fi path (default):** a one-session `HttpServer` on the
  TV's private IPv4, random port, 8-char token URL `http://<ip>:<port>/p/<token>`; deliver the
  result only *after* the HTTP response is closed (closing the server force-drops the connection —
  the phone showed a failure for a send that worked). **Relay path** (button "Phone not on this
  Wi-Fi?"): QR = `kPairRelayBase/p#<sessionId>.<key>`; the phone AES-GCM-encrypts in WebCrypto
  (needs HTTPS), PUTs ciphertext; the TV polls every 2 s only while that code is shown and decrypts
  with `cryptography`. Relay server = `tools/pair_relay/` (stdlib Python, memory-only, no logs), live at
  `https://pair.vespertv.app` since 2026-10-13 (own nginx block + cert; see that folder's README).
  An HTTPS page can't call the TV's plain-HTTP LAN address (mixed content), so the two paths need
  two codes — no automatic fallback. The panel hides the Status pane and the resume pill.
- **Resume pill switch:** Settings > General > "Show the 'Hold > to resume' reminder"
  (`vesper_show_resume_pill`, device-wide, default on) → `LiveResumeHint.pillEnabled`; screens hide
  it temporarily with `LiveResumeHint.hideWhileMounted()` (Sports, the phone-pairing panel). Both
  pills check `LiveResumeHint.pillAllowed`. Hold-Right still resumes when hidden.
- **Languages (English + French 1.0.4+227; Spanish + Italian added 2026-10-14, +236, unreleased):** es.dart/it.dart mirror fr.dart's 588 keys (check with a key/placeholder diff); `{s}` plural strings are rephrased in es/it (canal/canales, giorno/giorni don't take an 's'); `trSports` has per-language words/ordinals (`_sportsLanguages`); `trPlural` treats 0 as singular only in French. `lib/l10n/l10n.dart` — English text in
  the code is the key: `tr('Settings')`, placeholders `tr('Season {season}', {'season': n})`,
  `trPlural(n, one, other)` (French treats 0 as singular), `trSports()` pattern-translates ESPN's
  English statuses/standing lines ("Final/OT" → "Fin/Prol.", "Top 5th" → "Haut 5e").
  `lib/l10n/fr.dart` (`kFr`) holds the French; a missing key falls back to English. Not gen-l10n
  on purpose: many strings live in services/dialogs without a BuildContext. Setting: Settings >
  General > Language (Automatic / English / Français), device-wide key `vesper_language`, applied in
  `main()` before `runApp` (splash is translated too). Changing it pops to home, and main.dart keys
  home on `viewerId|L10n.code` so the whole UI remounts. `Intl.defaultLocale` follows it (dates via
  `DateFormat.MMMEd()`/`jm()` are locale-aware; French gets 24 h). `flutter_localizations` (needed
  `intl` ^0.20) translates Flutter's own widgets. **Rules:** wrap every new user-visible string in
  `tr()` and add its French to `fr.dart` (same placeholders); never `tr()` a string that is also an
  id in logic (tab ids 'TV'/'Movies'/…, group 'All'/'Favorites', standings column labels, palette
  labels) — translate those at the display site (`Text(tr(tab))`). Québec French, short forms on
  narrow TV labels (MAJ, PJ/V/D/DP, NIP). Data from providers/ESPN (channel, team, league names)
  stays as-is.
- **Phone mode (1.0.6+232, 2026-10-14):** one APK for everything — no separate phone build
  (same `applicationId`, one updater asset, one Downloader code). `TvHomeScreen` adapts:
  portrait + width < 600 (`_compact`) shows one column at a time via an `IndexedStack`
  (`_phonePage` 0 tabs / 1 groups / 2 content, keeps scroll positions), a "← title" header, Back
  walks 2→1→0 then asks to exit; tab tap → groups, group tap → content; starts (and lands after
  rotating to portrait) on the content page. Live region in portrait = 16:9 video on top, list or
  Timeline below. Landscape phone = the TV layout; on touch/mouse (`!isTelevision`) picking a group
  moves focus into the content so the tabs/groups collapse, and tapping a collapsed strip expands
  it (`_collapsible`, wrappers always present so the column never remounts). Layout "auto" now
  always uses `TvHomeScreen`; only Layout = "Phone" still shows the old `HomeScreen` (to delete).
  Add Playlist stacks its 3 panes in one scroll page when width < 600; My Teams stacks list over
  details; Standings keeps every column and scrolls sideways on touch (TV still drops columns —
  a remote can't scroll sideways). Tested on the owner's Xiaomi (`2509FPN0BC`, 1200x2608 @480dpi,
  adb serial `4ec647bc`). Ideas not done: narrower Timeline channel column in portrait, hide the
  resume pill when the preview already plays that channel, other Sports screens in portrait,
  delete `HomeScreen`.
- **Transfer to another device (1.0.8+240, 2026-10-14):** Settings (last row) > Transfer to another
  device > Send / Receive. No account, no VPS: the sender runs a one-time HTTP server
  (`TransferSendSession`, ports 47821-47825, 10 min, one use) on its LAN IPv4. Code = 9 digits:
  last octet of the sender's IPv4 (3) + a 6-digit secret; the receiver assumes its own first three
  octets. **Two-router homes** (owner: PC on TP-Link 192.168.1.x, Formuler on Helix 10.0.0.x) break
  that assumption → after "Couldn't find the other device" the receiver offers "Type the address
  instead" (keypad gets a dot key; the sender shows "This device: <ip>"). Crypto: receiver sends an
  X25519 public key + HMAC(code); sender checks it (5 wrong → session ends), replies with its key +
  HMAC + AES-GCM payload keyed by HKDF(X25519 shared secret, code). Payload =
  `StorageService.exportForTransfer()` (every SharedPreferences key, type-tagged) minus device-only
  keys (`_transferSkipExact`/`_transferSkipPrefixes`: layout mode, legacy enabled flag, PIN lockout,
  EPG/What's New caches, full-sync timestamps). Receiving: clearCache + EPG + catalog DB wiped,
  `importForTransfer` replaces every transferable key, then `exit(0)` (services hold old state;
  a fresh start is the clean reload). Real-world size: ~0.8 MB for the owner's setup (channel links
  + hidden groups across several playlists). Tested: unit tests (round trip, wrong code, lockout) +
  Formuler → PC send. The **receive UI on a real box and the replace step on a real device are not
  yet tested** — watch for reports.
- **Transfer over the internet (1.0.14+271, 2026-10-16; relay deployed to the VPS 2026-10-16, backup in
  `/root/backup-pair-20261016-084326`, live round trip passed):** Transfer > Send
  is now the internet path (the Wi-Fi one is a "Both devices on the same Wi-Fi?" tile at the
  bottom of that screen — kept so transfers work without our relay) → pick 1 h / 24 h / 7 days → the setup (same export) is gzipped,
  AES-GCM-encrypted and PUT to the relay's **vault** (`tools/pair_relay/relay.py`, `/api/v/<id>`,
  on disk in `/var/lib/pair-relay`, ≤7 days, 8 MB/blob, 2 GB total, pruned every 5 min). Code =
  16 digits → PBKDF2 (60k) → HKDF → blob id + write token (relay keeps its SHA-256) + AES key, so
  the relay can't read it or find its code. Receive takes 9 (Wi-Fi) or 16 (internet) digits and
  picks the path by length; the download works any number of times until expiry. The sender keeps
  `{code, expires}` in `vesper_cloud_transfer` (device-only, excluded from transfers) to show it
  again with Done / Upload again (deletes the old one) / Delete now. `lib/services/cloud_transfer.dart`,
  test `test/cloud_transfer_test.dart` (runs relay.py locally). **Cloud sync later** reuses the
  vault as is: linked devices share a random master secret (`VaultKeys.fromMaster`), re-upload on
  change with a refreshed long TTL (raise `VAULT_MAX_TTL`), envelope `kind` = 'sync'.
- **1.0.15 (+284, 2026-10-16) — favourites per tab, playlist labels, phone touches:**
  - **No Favorites tab any more** (`_tabs` = TV / Movies / TV Shows). Movies/TV Shows group column:
    What's New, **Favourites**, All, groups. Favourites (`_showFavorites`, same lifecycle as
    `_showWhatsNew`) shows starred titles (one row per playlist, "Favourites · name", pseudo-group
    title `__favorites__` so it reuses the row key / first-poster node machinery) then only the
    favourited groups (" · playlist" suffix when mixed). TV's Favourites entry =
    `PlaylistManager.favoriteLiveChannelsWithGroups` (starred + every channel of a favourited live
    group, per playlist). Owner rejected "pin favourited groups to the top of the list" — keep
    favourites behind the one entry.
  - **Playlist labels** with 2+ playlists: Search result cards (`PosterCard.sourceLabel`), TV
    Favourites live list (`_PlaylistDividerRow` inside the first row's item, so row indexes stay),
    Timeline guide (gold tag inside the channel cell, `_playlistTagFor`, never an extra row).
  - **12/24 h clock** (Settings > General, `TimeFormat` in `lib/utils/time_format.dart`, device-wide,
    default 24 h); every time display goes through `TimeFormat.hm/dateTime/dayTime`.
  - **Splash greeting bank** (`lib/utils/splash_greeting.dart`): 15 compliments (owner: positive
    reinforcement, not jokes), cycled one per cold start, index in `vesper_splash_greeting`
    (device-only). Add one = one line + fr/es/it.
  - **Phone:** search icon in the phone header bar; tapping the video in `PlayerScreen` toggles both
    bars on any touch device (`_touch` = `!isTelevision` — `_isTvLayout` is true for a phone held
    sideways, that hid the top bar); hidden top bar ignores taps; **rotate** button in the top bar
    (`_toggleRotation`, forces landscape/portrait without the system lock, released on leaving). Owner
    wants it in the top bar, not floating. Browse posters on Android touch: tap = preview in the hero,
    tap again / double tap = open (`PosterCard.tapToPreview`, Windows already did this).

- **Subtitles & add-ons (1.0.18+309, 2026-10-18; Windows since +336 — `widgets/desktop_subtitles.dart`:
  media_kit tracks + add-on files loaded as data, `Video` draws them, same per-series memory via
  `SubtitleTracks.seriesChoiceFor`):**
  - **Embedded tracks:** the vendored plugin's `SubtitleBridge.java` (see CLAUDE.md §9) lists text
    tracks (PGS/VobSub/DVB image subs skipped) and selects one; cues arrive on an EventChannel and
    `widgets/subtitle_overlay.dart` draws them over `PlayerScreen` (bottom 48, tags stripped). Text
    tracks start **disabled** on every player (Multiview, live). Dart side: `services/subtitle_tracks.dart`
    (`SubtitleTracks`, `languageName`). The player id is the controller's `textureId`
    (`SubtitleTracks.playerIdOf`, the one place with the visible-for-testing ignore).
  - **Online (add-ons):** `services/addon_service.dart` — Stremio protocol, **subtitles resource only**
    (owner: no stream/debrid add-ons). Settings > Add-ons (`screens/settings/addons_screen.dart`,
    hidden on Windows) lists the official OpenSubtitles v3 add-on **off** by default; users can add any
    subtitle add-on by manifest link (hold OK = remove). Title → IMDb id via Cinemeta search
    (keyless; Xtream movies `xt_vod_` + episodes `xt_ep_` only; episode = `tt:season:episode` from the
    `S{n}E{n}` name prefix, series name/year from `channel.group`). Downloaded SRT/VTT goes through
    `controller.setClosedCaptionFile` (`SubtitleTracks.useExternal`); the overlay then draws
    `value.caption`. Results sorted app language, English, rest.
  - **Memory:** last 3 online languages (`addOnlineSubtitleLang`) shown in the Subtitles list as
    one-press "Online" entries. A choice made during an episode is saved per series
    (`SubtitleTracks.rememberForSeries`, key `playlistId::group`) and reapplied on every later episode
    by the overlay (`applyForSeries`: same language + label for embedded, first add-on match for
    online); Off forgets it. Movies never auto-apply (owner).
  - Audio: no "audio add-ons" exist (the protocol has catalog/meta/stream/subtitles only); other-language
    audio has to be in the provider's file — the Audio track picker shows it (verified on a
    French/English MobLand file).
- **Player bar (1.0.18):** one row — title left, buttons centred (capped at 60 % width, scale down,
  `VisualDensity.compact`), badges + time right; VOD seek bar above it is 24 px. The old
  chevron-revealed second row is gone (`showMore`/`onToggleMore` now only mean "fullscreen caller").
  Down opens the bar **with Play/Pause focused** (`PlayerScreen._focusBottomBar`, `playFocusNode`).
  Picker sheets (audio, subtitles, online results, Recall) use `TvMenuTile` (ListTile showed a pastel
  focus fill on TV). OK with no bar focused on a live channel toggles the CH+/- info card (4 s,
  45 % black).
