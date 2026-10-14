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
