# VesperTV — working notes for Claude Code

Read this first in any fresh session. It is the project's memory: what it is, how to build/ship it,
the rules that were learned the hard way, and every bug that has already been fixed (so it doesn't
get re-introduced or re-investigated).

## 1. What this is
Flutter IPTV player (M3U + Xtream Codes, XMLTV EPG) for **Android phones, Android TV boxes
(Formuler), Fire Sticks, and Windows 10/11 PCs**. GPL-3.0, open source, always free, no ads, no
tracking, bring-your-own playlist (the app ships no channels).

- **Name:** VesperTV (formerly **NoXPlayer**; "NoX TV Player" in some UI text). Renamed in Oct 2026
  because "NoXPlayer" collided with a well-known Android emulator that had a malware scandal.
  "Vesper" = evening star; brand is **black + gold**, logo is a gold "V" with a four-point star.
- **Repo:** https://github.com/NoXqc/VesperTV (renamed from `NoXqc/NoXPlayer`; GitHub auto-redirects
  web/API/git/download URLs from the old name — **never create a new repo called `NoXPlayer`**, it
  would break those redirects for every old install and link).
- **Site:** https://vespertv.app (GitHub Pages from `docs/`, HTTPS enforced). DNS is at Cloudflare,
  4 `A` records (185.199.108-111.153) on the apex + `www` CNAME → `noxqc.github.io`, all
  **DNS only / grey cloud** (an orange proxy cloud breaks Pages' certificate issuance). `docs/CNAME`
  = `vespertv.app`. The old `noxplayertv.com` *marketing site* is gone, but **keep that domain registered** - it is still used by other infrastructure (details are in a private notes file on the owner's PC, outside the repo).
- **Community:** Discord https://discord.gg/DDeGDHvFY, Reddit r/VesperTV. **Downloader (AFTVnews) code: `1760256`**.
- **Package / identifiers deliberately NOT renamed** (renaming would orphan every install's data and
  break in-place updates): Android `applicationId` `com.nox.nox_iptv`, Dart package `nox_iptv`,
  Windows exe `VesperTV.exe` (was `nox_iptv.exe` until the post-3.53.1 build; CMake `BINARY_NAME`; `ProductName`/`CompanyName` in Runner.rc stay `nox_iptv`/`com.nox` because they name the user-data folder), signing alias `noxplayer`, SharedPreferences keys, cache names like
  `noxplayer_posters`. Only user-visible strings, icons, URLs and docs were renamed.

**The owner** tests on real devices and sends phone photos/screenshots of the TV. Most bugs only show
up on real boxes (weak CPUs, D-pad remotes, Fire OS quirks) — emulators/tests are not a substitute.
Keep replies short; make routine calls yourself; **confirm before anything destructive or
outward-facing** (deleting releases, force-pushes, posting). Only commit/release when asked.

## 2. Start-here checklist for a clean session
1. `git pull`, then `git status` (ignore the untracked `*-windows-x64.zip` and
   `third_party/video_player_android/pubspec.lock` — local artifacts).
2. Machine facts (Windows PC): repo `C:\Users\aarse\NoXPlayer`; Flutter `C:\src\flutter`; JDK 17;
   Android SDK `C:\Android\Sdk`; apksigner `C:\Android\Sdk\build-tools\36.0.0\apksigner.bat`;
   keystore `C:\Users\aarse\keystores\noxplayer-release.jks` via git-ignored `android\key.properties`
   (originals also on drive `E:\`). Files are CRLF here (autocrlf) — "LF will be replaced by CRLF"
   warnings are normal. `flutter pub get` dirties generated plugin files under linux/macos/windows —
   `git checkout` them before committing.
   **VPS** (NOX-VPS, `ssh root@107.175.31.191`, key auth from `~/.ssh/id_ed25519`, works from the
   Bash tool): runs the pairing relay + transfer vault (`tools/pair_relay/`, `pair.vespertv.app`)
   **and the owner's streams (Tuliprox) behind the same nginx** — back up first, `nginx -t`, then
   `systemctl reload nginx` (never restart). Deploy steps: `tools/pair_relay/README.md`.
3. Use Bash (Git Bash) or PowerShell. In Git Bash, **prefix adb commands that take `/sdcard`-style
   paths with `MSYS_NO_PATHCONV=1`** (it mangles them). Big multi-line heredocs sometimes break the
   Bash tool — write a script file with the Write tool and run that instead.
4. `flutter analyze` must report the baseline **17** info-level issues (no errors). Don't add new ones.
5. Check the current state of releases: `gh release list` (latest should be `1.0.16` unless noted
   in §11).

## 3. Layout (what matters)
- `lib/main.dart` — bootstrap + splash, layout choice (TV vs phone), welcome/add-playlist prompt for
  new users, Windows `window_manager` init, post-splash auto-resume of the last channel.
- `lib/screens/tv_home_screen.dart` — the whole TV UI (tabs, groups, live list, Timeline guide,
  Movies/TV Shows browse + hero, Windows Minimize/Close rows). Huge file, full of load-bearing
  comments. Read them.
- `lib/screens/player_screen.dart` + `lib/widgets/player_controls.dart` — Android/TV fullscreen
  player (primary row, chevron-revealed secondary row, quality/FPS/audio-channel badges).
- `lib/screens/multiview_screen.dart` — Multiview, 2 stacked or 4 (2x2) screens (remembered),
  connection-tip popup with "Don't show again", channel picker with group+search+EPG-now subtitle. Windows has its own `desktop_multiview_screen.dart`.
- `lib/screens/desktop_player_screen.dart`, `lib/services/desktop_mini_player.dart`,
  `lib/widgets/desktop_live_resume_hint.dart` — the **entirely separate Windows playback stack**
  (`media_kit`). Android uses `video_player_hdr` + `PlaybackService`/`PlayerScreen`. Changes to one do
  not affect the other; features must be built twice.
- `lib/services/playlist_manager.dart` / `playlist_session.dart` — per-playlist state, catalog
  loading, hidden groups/channels, backup-server failover. `playback_service.dart`,
  `epg_service.dart` + `epg_database.dart` (guide in sqflite), `catalog_database.dart` (sqflite), `storage_service.dart` (prefs/cache),
  `app_update_service.dart` (GitHub release updater). Transfer to another device:
  `cloud_transfer.dart` (internet, encrypted upload to the relay's vault — the main Send path) +
  `device_transfer.dart` (same Wi-Fi), UI `screens/settings/transfer_screen.dart`.
- `lib/screens/settings/*` — Settings screens (Add Playlist is a 3-pane LokTV-style layout).
- `lib/screens/welcome_add_playlist_screen.dart` — first-launch "Hey beautiful Human" prompt.
- `lib/widgets/`: `poster_card`, `hold_to_activate`, `live_resume_hint`, `tv_menu_tile`,
  `mode_button`, `pin_pad`, `sidebar`, `epg_guide`.
- Palettes: `lib/utils/constants.dart` (`cyberpunkPalettes`, `AppConstants.appName`),
  `lib/models/cyberpunk_palette.dart`, `lib/utils/tv_theme.dart`.
- `third_party/video_player_android` — **vendored, patched** ExoPlayer plugin (see §9).
- `assets/icon/` — logo sources; `gen_icon.py` regenerates all icons + the TV banner (§8).
- `docs/index.html` — the entire marketing site (single file) + `docs/assets/` screenshots (§8).
- `windows/runner/main.cpp`, `Runner.rc` — Windows runner (window title "VesperTV").

## 4. Build / check
- `flutter analyze` — baseline **17** info issues, none errors. `flutter test` — `test/device_transfer_test.dart` (real LAN sockets).
- Android: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` (~68 MB).
- Windows: **kill the running app first** (`Get-Process VesperTV | Stop-Process -Force`) or the link
  step fails with `LNK1104: cannot open VesperTV.exe`. Then `flutter build windows --release`
  (output `build\windows\x64\runner\Release\VesperTV.exe`) and zip the **whole Release folder** as
  `VesperTV-windows-x64.zip` (the exe needs the DLLs/`data` folder beside it — a bare .exe will
  not run, which is why the site links the zip, not the exe).
- Only run `dart format` on files you edited (`dart format lib` reformats unrelated files).
- Don't launch the Windows exe from an automated PowerShell session to test it — it can show a blank
  white window there (proven unrelated to `window_manager`); the owner launching it normally works.

## 5. Signing (READ BEFORE BUILDING A RELEASE)
- `android/key.properties` + the `.jks` keystore are **git-ignored secrets**. Alias `noxplayer`.
  `storeFile` is an absolute path for that machine (Windows: forward slashes).
- If key.properties is missing/wrong the build **silently signs with the debug key** — that APK
  cannot install over a real install. Always verify:
  `apksigner verify --print-certs app-release.apk` → SHA-256 must be
  `c92a346ac5b6191a373b3572fa0fbd72abdd5f64db497bd321617b8cc4562431`.
- Never commit the keystore/passwords. Losing the key = existing installs can never update.
- Android requires `versionCode` (the `+N` in `pubspec.yaml`, currently **+289**) to never go
  down, even if the visible version resets. Always bump N on every build you intend to install.

## 6. Release workflow (details in `dev-notes/release.md` — read it before releasing)
Only release when the owner asks ("update the latest", "cut it", "fully release"). Outline: bump `pubspec.yaml` (versionCode `+N` must always rise) → `flutter analyze` → build APK + verify signature (§5) → build Windows + zip → **commit & push first** → `gh release upload <tag> app-release.apk VesperTV-windows-x64.zip --clobber` → `gh release edit <tag> --tag <new> --notes-file …` → make sure the tag equals HEAD → verify downloads/hashes, the OLD `NoXqc/NoXPlayer` redirect links and AFTVnews code `1760256`. The updater offers any *different* tag (`_isDifferent`), never leave two `.zip`/`.apk` assets on the latest release.

## 7. Test devices (details in `dev-notes/devices.md`)
Formuler Z11 Pro MAX `10.0.0.46:5555` (IP changes; was `192.168.1.46`), Fire Stick `192.168.1.33:5555` (2026-10-15: on USB, `adb -s G072JN0733471CJ6`). Install with `adb install -r` after verifying the signature. Not rooted: no run-as on the Formuler, but `adb logcat` works (Flutter `print` shows as tag `flutter` even in release). **Don't drive the owner's Formuler over adb to debug** (owner, 2026-10-15) — add temporary on-screen debug output and ask for a photo, or use the Fire Stick when he hooks it up. Never press Select on "Exit App". Hold-Select via adb needs `input swipe X Y X Y 1800`, not `--longpress`. The owner keeps the Formuler on **Dark / Gold**.

## 8. Branding & website (details in `dev-notes/branding-and-site.md`)
Brand = black + gold, gold "V" + star logo. Regenerate icons with `python assets/icon/gen_icon.py` then `dart run flutter_launcher_icons`. Default Platinum theme accent = gold. Site is the single file `docs/index.html` (carousel, hero sky). Fire OS keeps old launcher icons after updates — known, unfixable in-app.

## 9. Vendored ExoPlayer plugin
`third_party/video_player_android` is a patched copy of `video_player_android` **2.12.2** (matches
what `video_player_hdr ^1.2.0` resolves to), wired in through `dependency_overrides`. Patch adds
`org.jellyfin.media3:media3-ffmpeg-decoder` with `EXTENSION_RENDERER_MODE_ON` (was PREFER until
`dbc88fc` — PREFER software-decoded plain AAC) plus a context-less `AudioSink` (so `setVolume`
works, no HDMI passthrough) in `PlatformViewVideoPlayer.java` **and** `TextureVideoPlayer.java`,
fixing silent **AC3/E-AC3 5.1** audio on boxes without a licensed Dolby decoder. Also patched:
Multiview-only buffer sizes + 4 s stuck-playing detection (`TextureVideoPlayer`), in-place
error/ENDED/frozen-video recovery (`ExoPlayerEventListener`, delayed + frozen-video watchdog only for
texture players), and **`VideoPlayerPlugin.createForTextureView` forces the SurfaceTexture-backed
producer** (`FlutterRenderer.debugForceSurfaceProducerGlTextures`) — the ImageReader producer
ignores the decoder's crop rect, which showed 720p Multiview tiles with a green area on a Fire Stick
(MTK). Only safe while Impeller stays off (Skia/GL). **If `video_player_hdr` or its constraint
is ever bumped**, re-sync the vendored copy to the new version and re-apply all of these patches
plus the gradle dependency line. Migrating to `media_kit` on Android was researched and
rejected (HDR + Android-TV hardware-decode risk).

## 10. Hard-won rules (don't re-learn these)
- **Cold-start splash is deliberately slow (~20-25s with a big second playlist).** Entering the UI
  early lets remote input crash weak boxes. Do not cap/shorten it (`_bootstrap` in main.dart). The
  Android last-channel auto-resume after the splash was once removed (decoder start + the old ~25 s
  EPG decode made cold start sluggish); since the SQLite EPG it's back, **on by default** behind
  Settings > General > Startup: "Resume last channel in full screen" or "…with the guide open"
  (plays in the preview box / Windows mini player); at most one on, both off = nothing plays
  (Android shows the "Hold > to resume" pill). Both platforms honor it (Windows used to always
  resume full screen). Settings > General > Tabs can hide Movies/TV Shows (`AppPreferences
  .hideMoviesShows`: tabs column and search).
- **D-pad focus:** default directional traversal is unreliable across differently shaped columns/
  rows — use explicit dispatch (`_moveColumnFocus`, the Timeline guide's own Up/Down/Left/Right,
  one `FocusScopeNode` per zone + `CallbackShortcuts`). No per-row `FocusScope`. Any programmatic
  scroll uses `jumpTo`, never `animateTo` (caused an ANR-length freeze on a big list). Pause periodic
  timers when covered (`RouteAware`). Remote "hold Select" = `HoldToActivate`; `InkWell.onLongPress`
  is touch-only.
- **Fire OS's on-screen keyboard swallows the physical Back button — known, unfixable limitation.**
  Confirmed via a raw `getevent` capture (clean `KEY_BACK`) plus Flutter-side logging of
  `logicalKey.keyId`: pressing Back on a Fire TV remote while the on-screen keyboard has D-pad
  focus never reaches the app as Back/Escape/browserBack at all. Fire OS's own keyboard overlay
  intercepts it first and resynthesizes it as ordinary keyboard-internal D-pad navigation
  (arrowRight/arrowDown moving the on-screen selector) immediately followed by a synthetic
  `numpadEnter` — indistinguishable, by the time Flutter sees it, from the user genuinely
  navigating the keyboard and pressing Enter on purpose. That synthetic Enter is what fires
  `TextField.onSubmitted`/`TextInputAction.next`, advancing focus to the next field instead of
  closing the keyboard. No app-level fix exists. A Formuler box does not have this problem (Back
  closes its keyboard normally).
- **A plain focusable widget (not a text field) competes with Flutter's own default directional
  traversal — `HardwareKeyboard.instance.addHandler` loses that race.** `add_playlist_screen.dart`'s
  `_handleFieldEscapeKey` reliably overrides arrow keys while a *text field* has focus only because
  `EditableText` swallows arrow keys internally. For a non-text-field widget (e.g. `ModeButton`,
  `TvMenuTile`), default traversal still runs and overrides a raw handler's `requestFocus()`. Use
  `CallbackShortcuts` for that case — it intercepts before default traversal.
- **EPG lives in `EpgDatabase`, never fully in memory.** `EpgService` getters stay synchronous:
  now/next from a preloaded ~4 h slice, `getPrograms` loads Timeline rows on demand and signals via
  `guideRowsLoaded` (not `notifyListeners` — `TvHomeScreen` watches the whole service, so that would
  rebuild the entire TV screen per scrolled row). Don't reintroduce a whole-guide load or save.
- **`requestFocus` on an item a lazy `ListView` hasn't built does nothing** (off-screen chip/tile
  has no context). Jumping focus to "the selected one" needs a non-lazy row
  (`SingleChildScrollView`) + `Scrollable.ensureVisible`, or a target that is on screen.
- **Never call `notifyListeners()` mid-build.** `PlaylistManager.notifyListeners` defers anything
  fired during the build phase (fixed Group Management checkmarks not repainting).
- Composite `Channel.id` (`playlistId::rawId`) vs raw `Channel.rawId`: EPG lookups and
  `Channel.isLiveId` need **rawId**. EPG lookups go through `Channel.epgId` (override → `epgKey` →
  rawId). Channel ids come from the provider's EPG id, which copies share (ESPN 4K/HD/FHD), so
  every live-list load path runs `Channel.withUniqueIds` — add it to any new load path.
- Back button: walks content → groups → tabs, exits the app only from the tabs column (`PopScope`
  in TvHomeScreen).
- The "live island" pill / mini player share **one controller** across preview/fullscreen/pill; see
  the comments before touching `PlaybackService`.
- **Multiview audio swap = `setVolume` only (confirmed on Formuler + Fire Stick).** Never toggle
  audio *tracks* in place (`setAudioTrackTypeDisabled`) — tried twice, worse both times (frozen
  frame + looping audio, stalls). The "recreate both controllers on every swap" workaround
  reconnected two streams per Select press and fought the provider's connection limit; it's gone.
- **Multiview needs one provider connection per screen — that was the real cause of the old
  "freezes every ~40-60 s".** Most accounts behind the owner's Tuliprox really allow **1**
  connection (provider `user_info`), whatever Tuliprox's `max_connections` says. Two tiles on one
  such account kick each other; Tuliprox reconnects and splices the new upstream into the same
  socket (TS sync lost, timestamps jump back 15-26 s) → ExoPlayer audio discontinuity → freeze.
  No player can fix that; don't chase it again. One tile per account, or a 2+-connection provider,
  ran clean 25+ min. The popup on entering Multiview explains this to users.
- **"Open in Multiview" from the player must `await _playback.stop()` before pushing**, otherwise
  the fullscreen stream and its audio keep playing underneath.
- **Windows** is a separate world: `window_manager` makes the app **always fullscreen** at launch
  (`WindowOptions(fullScreen: true, titleBarStyle: hidden)`); it cannot minimize while fullscreen →
  `_minimizeWindow()` exits fullscreen first and `WindowListener.onWindowRestore` re-enters it;
  `SystemNavigator.pop()` does nothing on Windows → use `windowManager.close()`; mouse "hold" needs
  the pointer `LongPressGestureRecognizer` inside `HoldToActivate` (keyboard Enter-hold alone did not
  work for mouse users); the last live channel is saved in `DesktopPlayerScreen`
  (`setLastChannelId`) because nothing else writes it on Windows.
- **Every user-visible string goes through `tr()` with a French entry in `lib/l10n/fr.dart`**
  (same `{placeholders}`). Never `tr()` a string that is also an id in logic (tab ids, 'All'/
  'Favorites' group entries, standings column labels) — translate at the display site. Details in
  `dev-notes/features.md` (Languages).
- **A screen that swaps its focused widget for another (keypad → summary) must give the new view
  a focus target** (`autofocus` + key handling); otherwise the remote has nothing focused and
  looks frozen (Transfer "Ready to copy", 2026-10-16).
- **`CallbackShortcuts` must be an ancestor of the focused node.** If it wraps only the body, it
  misses an AppBar `TextField`, so wrap the whole Scaffold (Search screen).
- Open-source principle: **no embedded API keys.** Anything needing a key (TMDB, a future
  OpenSubtitles) is bring-your-own-key in Settings.

## 11. Known bugs & fixes (full table in `dev-notes/bugs-and-fixes.md`)
Look there before debugging. Still-open items: the **Fire OS stale launcher icon** (not fixable). The
old ~50 s EPG delay is **fixed** by the SQLite EPG store (0.5 s on the Formuler) — Windows check pending.

## 12. Features (details in `dev-notes/features.md`)
Timeline/Live guide, player secondary row + badges, Multiview, welcome prompt, hide channels, Expand catalog, backup servers, palettes, **viewer profiles** (never rewrite Main's storage keys), **languages** (EN/FR/ES/IT), **Transfer to another device** (Wi-Fi + internet vault, built to grow into cloud sync). Read the file before changing any of these.

## 13. Status & open items (as of 2026-10-17)
- Donations will go through GitHub Sponsors (pending approval). After approval: `FUNDING.yml`,
  site/README links and an About row. Relay `X-VesperTV-App` enforcement is OFF until old installs
  update (see HANDOFF.md).
- **Shipped: 1.0.16 (`+289`, 2026-10-17, latest on GitHub)** — **Sports hero mini player** (Android: Play/Pause on a game card plays its channel in the hero, video left + small VS layout right; OK = fullscreen on the same stream, Back stops it; see `dev-notes/sports-tab.md` "Hero mini player"); **unique channel ids** for channels sharing an EPG id (`Channel.withUniqueIds`, `epgKey`; fixed favourites/hide hitting every ESPN copy); hold OK on a tab's Favourites row = clear that tab's favourites (`PlaylistManager.clearFavorites`); What's New full-screen backdrop + default view; launch update prompt; Search/EPG-overlap/Transfer-focus fixes; relay app header; `TRADEMARKS.md`. Windows: no Sports preview yet.
- 1.0.15 (`+284`, 2026-10-16) — Favorites tab removed: favourites live behind one **Favourites** entry per tab (Movies/TV Shows: starred rows per playlist + favourited groups; TV: starred + favourited groups' channels); playlist labels with 2+ playlists (Search cards, TV Favourites list + Timeline guide); 12/24 h clock (Settings > General); splash greeting bank of compliments (one per cold start); phone: header search icon, tap shows both player bars, rotate button in the top bar, browse posters tap = preview / tap again = open. Details: `dev-notes/features.md` (1.0.15).
- 1.0.14 (`+271`, 2026-10-16) — **Transfer over the internet**: Send = encrypted upload to the relay's vault for 1 h / 24 h / 7 days, 16-digit code, works any number of times until expiry or Delete now; the Wi-Fi transfer is the "Both devices on the same Wi-Fi?" tile on that screen; Receive takes 9 or 16 digits. Relay deployed on the VPS (`tools/pair_relay`, vault on disk in `/var/lib/pair-relay`). Built to grow into cloud sync later. Also the +268 provider-duration + browse-banner title fix. Details: `dev-notes/features.md` (Transfer over the internet). Owner tested Fire Stick ↔ phone: "flawless and superfast".
- 1.0.13 (`+267`, 2026-10-15) — redesigned TV Show + movie detail pages (`series_detail_screen.dart`, `movie_detail_screen.dart`, shared `widgets/detail_header.dart`, `utils/display_title.dart` title cleanup; per-episode progress from existing saved positions, watched = >=95%); HD images (`utils/image_urls.dart` keyless TMDB size upgrade, `widgets/hd_network_image.dart` decode caps, provider backdrops via `get_vod_info`/`get_series_info`, `CatalogDatabase` v8); hero/carousel go dark -> backdrop (no poster flash, `_focusedArtPending`); hold the Sports RedZone pill to pick its channel; Back-from-guide focus safety net. Next keyless artwork option if wanted: TVmaze (series/episodes, CC BY-SA, no key).
- 1.0.12 (`+261`, 2026-10-15) — Android player CH+/CH- (and PgUp/PgDn) zap through the list the channel was picked from (`PlaybackService.zapList`, skips same-id duplicates) with a 3 s info card; hold OK on History = delete watched history; Add Playlist button black until focused; site shows the translucent guide. Windows: no CH zapping.
- 1.0.11 (`+259`, 2026-10-15) — Settings > General: hide Movies/TV Shows tabs, Startup = full screen / guide-preview / nothing (Android + Windows); Sports: watching another listed channel becomes that game's pick, glowing NFL RedZone pill, opens on the league row; Movies/TV Shows hero backdrop fades behind the first row, focused poster title no longer clipped.
- 1.0.10 (`+254`, 2026-10-14, 4 Formuler screenshots attached) —
  **full-screen video behind the Timeline guide** (Theme toggle, 3-row translucent guide, side
  columns hidden in the guide, corner description card), **fullscreen side panel** on Left (Last
  channels / My Teams / Live now; Left no longer exits the player — Back only), and Movies/TV Shows
  stopping a background live channel but keeping it resumable. All Android only — Windows parity
  not done. Details: `dev-notes/features.md`. **Next:** ask the owner.
- 1.0.9 (`+246`, 2026-10-14) — **Select = preview, Select again =
  fullscreen** on the Timeline guide + Live list (Android and Windows, `_previewOrOpenChannel`,
  `DesktopMiniPlayer.play`; see `dev-notes/features.md`), **event sports** in the League bank
  (golf PGA/LPGA/DP World/LIV, UFC/PFL, F1/NASCAR/IndyCar — leaderboard cards, F1 per session,
  fight cards = main event) and **racing championship standings** (drivers + F1 constructors).
  Details: `dev-notes/sports-tab.md` (Event sports). Not done: UFC rankings / golf points race
  (no usable free data), wrestling / horse racing (only an EPG-based idea). **Next:** ask the owner.
- 1.0.8 (`+240`, 2026-10-14) — **Spanish + Italian** (es.dart/it.dart,
  same 614 keys as fr.dart), **Transfer to another device** (Settings, last row: copies the
  whole setup over the home network, `services/device_transfer.dart` +
  `screens/settings/transfer_screen.dart`, see `dev-notes/features.md` → Transfer), Settings menu
  lost its Add Playlist row (it's in Playlist Manager). Owner prefers **batched releases** (a few
  features per cut). **Next:** ask the owner.
- 1.0.7 (`+235`, 2026-10-14) — Sports **League manager**
  (replaces the Edit leagues dialog): 13 base leagues + a bank of 63 ESPN leagues
  (`kSportsLeagueBank`, add / hold-to-send-back, per viewer), cups without a table kept out of
  Standings, and an empty single-league day offers "Next game: <date>". Details:
  `dev-notes/sports-tab.md` (League manager).
- 1.0.6 (`+232`, 2026-10-14) — **phone mode**: `TvHomeScreen`
  adapts to portrait phones (one column at a time, `_compact`/`_phonePage`; "auto" layout now
  uses it on phones — the old `HomeScreen` is only reachable via Layout = "Phone" and is slated
  for deletion), touch/mouse group pick collapses the side columns, Add Playlist / My Teams stack
  in portrait, Standings scrolls sideways on touch. Details: `dev-notes/features.md` (Phone mode).
- 1.0.5 (`+230`, 2026-10-14) — Sports on Windows: back arrow + Esc
  on the Sports screens, the whole Sports UI scales up on big displays (`SportsScreenFrame`,
  design width 1440, never shrinks — owner checked on a 4K monitor), and mouse ‹ › arrows on the
  game-card rows (`SportsRowArrows`). All Windows-only / no-ops on TV boxes.
- 1.0.4 (`+229`, 2026-10-14) — French + language picker (Settings > General > Language,
  `lib/l10n/`, see `dev-notes/features.md`) and the "Hey beautiful Human" splash greeting.
  Releases are announced on Discord (gold embed, `.github/workflows/discord-release.yml`, run by
  hand after an in-place release — `dev-notes/release.md` step 8).
- 1.0.3 (`+226`, 2026-10-14, tag on `d02200e`) — the Sports tab:
  scores, channel matching, Standings, **My Teams** (see `dev-notes/sports-tab.md`), plus Add
  Playlist "From phone" and the resume-pill fixes/switch (details below). Site + README advertise it
  with Formuler screenshots (`docs/assets/shot-sports.jpg`, `shot-my-teams.jpg`,
  `shot-standings.png`, `shot-follow.png`). Sports on Windows checked + fixed in
  1.0.5. **Later:** the "Not yet" list in `dev-notes/sports-tab.md` (Sports
  Multiview, phone layout, BYOK providers) — ask the owner which first.
- 1.0.2 (`+207`, 2026-10-13) — TV tab focused at launch, Settings >
  General History clearing (also on Windows). 1.0.1 (`+206`) added Settings > General (resume last
  channel at startup, Multiview tip toggle). The 1.0.0 release was retagged in place each time; tag `1.0.0`
  (`+204`) remains. 1.0.0 restarted the version numbers and included
  the SQLite EPG store, visible playlist password and the Multiview fixes (volume-only audio swap,
  auto-recovery, SurfaceTexture green fix, wakelock, connection-tip popup, 2/4-screen layout; see
  §9-§10). Releases/tags older than 3.52 were deleted; their history is in `previousreleases.md`.
  Tags 3.52.0-3.53.3 and the 3.53.3 release remain. Apps on ≤3.52.3 can't see 1.0.0 (old updater
  wants a higher number) — they reinstall from vespertv.app / Downloader `1760256`.
  Still to check: SQLite EPG on Windows. (Fire Stick "Update EPG Now" confirmed fixed by the owner,
  2026-10-13.)
- **What went into 1.0.3:** Sports v1 + Standings + **My Teams** (follow from Standings,
  starred/first games, team details screen; owner happy with it 2026-10-14). Site: carousel slides
  2-4, features cluster 04 / SPORTS, a Sports how-to group. Also fixed the "Hold > to resume" pill rendering with
  Flutter's yellow-underline debug text (no Material ancestor; Android + Windows), and the pill is
  now **hidden while Sports is open** (`LiveResumeHint.hideWhileMounted()` — a counter both pills
  watch; hold-Right still resumes), plus a Settings > General switch to turn the pill off. Also
  **Add Playlist > "From phone"** (QR → phone form; Wi-Fi path tested on the Formuler, VPS relay
  live at `https://pair.vespertv.app`, both paths verified with the real TV) — see `dev-notes/features.md`.
  Owner tested Sports on 2026-10-14 and the feedback round is in (OK plays / hold = menu, league
  reorder by hold, gold focus look).
- **Test builds** for the owner's Fire Stick go to a GitHub **pre-release** (skipped by the updater
  and `/latest`), sideloaded via Downloader with the direct asset URL; delete it once shipped.
- **Roadmap (owner, 2026-10-12):** ~~fix Multiview~~ (done 2026-10-13). **Next:** a **Sports tab** (design draft: `dev-notes/sports-tab.md`)
  with live scores, BYOK supporting **two** sports APIs (user picks/pastes a key in Settings; hard
  part is matching games to channels).
- **Ideas discussed, not started:** OpenSubtitles integration (BYO key); Windows player-controls
  secondary-row parity; widen `epgPastRetention` for catch-up later (owner wants it, after basics/
  stability); (done) EPG speed rework; (done) rename of `nox_iptv.exe`→`VesperTV.exe`
  (CMake `BINARY_NAME`; user data location is unaffected).
- Competitor reference: **LokTV** (paid) — cached EPG, sports tab, multiview, simple add-playlist.

## 14. Git
- Commit only when asked; end commit messages with the attribution trailer Claude Code provides.
- Never `--no-verify`, never force-push `main` (force-moving a **tag** to HEAD is the one sanctioned
  exception, §6.4).
- Local junk is git-ignored/untracked on purpose (`nox_*.png` screenshots, `*.apk`, `*-windows-x64.zip`).

## 15. Session hygiene (token efficiency)
- **One task per session.** Long sessions get lossy compaction and re-read the whole history after the
  1-hour prompt-cache expires. Finish a task, commit, then start fresh (`/clear` or a new session).
- **Hand off, don't drag.** Before a session ends or compacts, run `/handoff` (project command in
  `.claude/commands/handoff.md`): it writes `HANDOFF.md` (git-ignored). **If `HANDOFF.md` exists, read it
  first**, then delete or overwrite it once its contents are done/obsolete.
- Don't read giant files whole (`tv_home_screen.dart` is huge): `Grep` for the symbol, then `Read` only
  the needed line range. Use the `dev-notes/` files on demand, not all at once.
- Keep CLAUDE.md lean: put details in `dev-notes/`, put in-progress state in `HANDOFF.md`, and
  record only lessons that prevent a repeat mistake.
