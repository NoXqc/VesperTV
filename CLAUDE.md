# VesperTV — working notes for Claude Code

Read this first in any fresh session. It is the project's memory: what it is, how to build/ship it,
the rules that were learned the hard way, and every bug that has already been fixed (so it doesn't
get re-introduced or re-investigated).

## 1. What this is
Flutter **universal media player** for **Android phones, Android TV boxes (Formuler), Fire
Sticks, and Windows 10/11 PCs**: live IPTV (M3U + Xtream Codes, XMLTV EPG), the **Media Hub**
(user-added REST add-ons + the user's own **Jellyfin / Emby** server) and **Trakt / Simkl** watch
tracking. GPL-3.0, open source, always free, no ads, no tracking, bring-your-own sources (the app
ships no content).

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
5. Check the current state of releases: `gh release list` (latest should be `1.0.34` unless noted
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
  `device_transfer.dart` (same Wi-Fi), UI `screens/settings/transfer_screen.dart`. Backup &
  restore: `services/backup_service.dart` + `android/.../BackupStore.kt` (Download/VesperTV via
  MediaStore; Windows Documents\VesperTV), UI `screens/settings/backup_screen.dart`; Transfer and
  Restore share `screens/settings/replace_setup.dart` (clear caches, import, exit).
- `lib/screens/settings/*` — Settings screens (Add Playlist is a 3-pane LokTV-style layout).
- **Media Hub** (code name Archive — files/classes/keys stay `archive_*`): `screens/archive_screen.dart`
  (tab), `archive_detail_screen.dart` / `archive_playback.dart` (play, series via
  `SeriesDetailScreen`), `services/archive_service.dart` (sources, rows, routing per source kind),
  `archive_api_service.dart` (add-on REST schema), `media_server_api.dart` (Jellyfin/Emby),
  `tracker_api.dart` + `tracker_sync.dart` + `watch_tracker.dart` (Trakt/Simkl: rows, read-back,
  scrobbling), `screens/settings/{archive_sources,media_server,trackers}_screen.dart`. Details in
  §10 "REST/JSON Add-on Architecture" and §13.
- Multiview extras: `services/multiview_sports.dart` (picker Live now / Sports),
  `widgets/game_channel_chooser.dart`, `widgets/auto_hide_overlay.dart` (tile name bar).
- `lib/screens/welcome_add_playlist_screen.dart` — first-launch "Hey beautiful Human" prompt.
- `lib/widgets/`: `poster_card`, `hold_to_activate`, `live_resume_hint`, `tv_menu_tile`,
  `mode_button`, `pin_pad`, `sidebar`, `epg_guide`, `roll_down_menu` (the black/gold menu that
  unrolls under a button: Media Hub row hold menu, groups column Playlists menu).
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
- Android requires `versionCode` (the `+N` in `pubspec.yaml`, currently **+360**) to never go
  down, even if the visible version resets. Always bump N on every build you intend to install.
  (Currently **+388**, 1.0.34.)

## 6. Release workflow (details in `dev-notes/release.md` — read it before releasing)
Only release when the owner asks ("update the latest", "cut it", "fully release"). Outline: bump `pubspec.yaml` (versionCode `+N` must always rise) → `flutter analyze` → build APK + verify signature (§5) → build Windows + zip → **commit & push first** → `gh release upload <tag> app-release.apk VesperTV-windows-x64.zip --clobber` → `gh release edit <tag> --tag <new> --notes-file …` → make sure the tag equals HEAD → verify downloads/hashes, the OLD `NoXqc/NoXPlayer` redirect links and AFTVnews code `1760256`. The updater offers any *different* tag (`_isDifferent`), never leave two `.zip`/`.apk` assets on the latest release.

## 7. Test devices (details in `dev-notes/devices.md`)
Formuler Z11 Pro MAX `10.0.0.46:5555` (IP changes; was `192.168.1.46`), Fire Stick `192.168.1.33:5555` (2026-10-15: on USB, `adb -s G072JN0733471CJ6`). Install with `adb install -r` after verifying the signature. Not rooted: no run-as on the Formuler, but `adb logcat` works (Flutter `print` shows as tag `flutter` even in release). **Don't drive the owner's Formuler over adb to debug** (owner, 2026-10-15) — add temporary on-screen debug output and ask for a photo, or use the Fire Stick when he hooks it up. Never press Select on "Disable and exit" (was "Exit App": it disables every playlist). Hold-Select via adb needs `input swipe X Y X Y 1800`, not `--longpress`. The owner keeps the Formuler on **Dark / Gold**.

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
(MTK). Only safe while Impeller stays off (Skia/GL). Also added (1.0.18): **`SubtitleBridge.java`**
(MethodChannel `vespertv/subtitles` + EventChannel `vespertv/subtitles/cues`, attached in
`VideoPlayerPlugin.registerPlayerInstance`) — lists/selects embedded text tracks and streams cue text;
every player starts with text tracks disabled. Added in 1.0.24: **live closed captions**
(`HttpVideoAsset.liveCaptionExtractors`: `DefaultExtractorsFactory.setTsSubtitleFormats(CEA-608)`,
so every .ts stream lists a "CC" track, empty when the channel has none; `SubtitleBridge` flags it
`cc`), **decoder fallback** (`setEnableDecoderFallback(true)` in both players), and
`VideoPlayer.dispose` **removes its listener before `release()`**: a 4K release on the Fire
Stick passes ExoPlayer's 500 ms timeout, and the error recovery then re-prepared the released
player on the main thread (an ANR was seen once). **If `video_player_hdr` or its constraint
is ever bumped**, re-sync the vendored copy to the new version and re-apply all of these patches
plus the gradle dependency line. Migrating to `media_kit` on Android was researched and
rejected (HDR + Android-TV hardware-decode risk). Also patched (1.0.27):
`ExoPlayerEventListener.describeCause` appends `[HTTP 404 Not Found] [ERROR_CODE_…] cause: …` to
the error string; Dart reads it (`httpStatusFromPlaybackError`) and the player's error screen
always shows the details (owner: show any error so user photos can be diagnosed).
Added in 1.0.31 (**Data pool**): `StreamStats.java` (a `TransferListener` counting network bytes,
set by `HttpVideoAsset`), `StatsBridge.java` (MethodChannel `vespertv/stats` → nowMs / bytes /
rendered / dropped frames), `VideoAsset.streamStats()`, `VideoPlayer.streamStats`, and
`videoPlayer.streamStats = videoAsset.streamStats()` in both `VideoPlayerPlugin` create methods.
Uses `android.util.LongSparseArray`; new classes need `@OptIn(markerClass = UnstableApi.class)`.
Next release: **`ExoPlayerEventListener`** gives up on HTTP 404/410 at once (`isGoneError`) and after
3 failures in a row without reaching READY (`consecutiveErrors`); the 10 s window alone never fired
when each attempt took ~6.5 s to fail (endless spinner on a dead Media Hub link).
Added in 1.0.34: **`BufferBudget.java`** — on devices under 2.5 GB RAM (or `isLowRamDevice`),
`setTargetBufferBytes` 64 MB in `PlatformViewVideoPlayer` and 32 MB in `TextureVideoPlayer` (the
time limits alone let a 4K remux fill ~140 MB of Java heap; the Fire Stick ran out of memory).
**Recording (1.0.32) is NOT in this plugin** — it is app-side Kotlin (`RecorderService.kt`,
`RecorderScheduler.kt` in `android/app/.../nox_iptv/`), so a plugin re-sync doesn't touch it.

## 10. Hard-won rules (don't re-learn these)
- **Cold-start splash is deliberately slow (~20-25s with a big second playlist).** Entering the UI
  early lets remote input crash weak boxes. Do not cap/shorten it (`_bootstrap` in main.dart).
  The time is the catalog pre-load + `_waitForCategoriesToSettle`, not a timer (floor 2.6 s).
  Re-asked after the SQLite EPG (2026-10-18): owner chose to **leave it as is**. Since 1.0.31
  there is an **opt-in, device-only Fast startup** (Settings > General > Startup,
  `AppPreferences.fastStartup`): the splash loads Movies/TV Shows for at most 3.5 s, then the UI
  opens and the rest loads behind it (owner timed Formuler 30 s → 4 s, Fire Stick 4K 14 s → 5 s,
  stable). Never make it the default, never transfer it. The
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
- **Text fields on a TV box go through `TvTextFieldGate` (`widgets/tv_text_field_gate.dart`,
  1.0.24):** the field stays `readOnly` (no keyboard) until OK, so the D-pad can pass over it.
  A plain `TextField` raises the keyboard as soon as it's focused: on Fire OS that took the
  remote, and Back then cleared all focus. Never reopen the keyboard on Enter/numpadEnter,
  because Fire OS sends a numpadEnter when Back closes its keyboard (Add Playlist and the Sports
  picker did that, so Back reopened the keyboard forever). The keyboard also never follows Next
  into the next field: Fire OS reports Back as that same Next action, so it can't be told apart
  (tried, 2026-10-19: Back walked field to field). A new field on TV: wrap it, and give
  its `onSubmitted` a focus target. **Every** field is gated since 1.0.26 (EPG matching, channel
  linking, TMDB key, profiles, backup-server dialog were the last — Fire TV user report);
  dialogs/pickers without a node use `FocusNodeOwner`. `test/tv_text_field_gate_guard_test.dart`
  fails the build on any ungated `TextField`; a deliberate exception needs a
  `// tv-text-field-gate: exempt — why` comment (Timeline filter, Windows Multiview picker).
- **Sports Trak, Settings and Search keep a background live channel playing** (owner reverted the
  1.0.24 parking on all three, 2026-10-20). Movies/TV Shows/Media Hub still park it
  (`_parkLiveChannel`). The parking was added because the video stayed on screen over those pages
  on some Fire TV sticks (newer sticks on an older Fire OS build; not on the owner's updated 4K
  Max). Fix = opt-in **Settings > General > Background video** (`AppPreferences
  .hideVideoOnSports`, device-only): `_pushOverLiveVideo` removes the picture's platform view
  while the page is open, stream + sound keep going. Don't re-add the parking.
- **A `Focus(onKeyEvent: …)` wrapper around focusable children must be `canRequestFocus: false,
  skipTraversal: true`.** A plain one is itself a focus target: D-pad traversal landed on
  Multiview's invisible grid-sized wrapper instead of the next tile and the remote looked stuck
  (Fire Stick, 1.0.26 header overlay).
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
- **Windows** is a separate world: `DesktopWindow` (`services/desktop_window.dart`) creates the
  window **full screen** by default (`WindowOptions(fullScreen: true, titleBarStyle: hidden)`) or
  **windowed** (sidebar toggle, remembered); leaving full screen needs `windowManager.show()`
  after `setFullScreen(false)` or the window vanishes (§13, 1.0.23). It cannot minimize while
  fullscreen → `_minimizeWindow()` exits fullscreen first and `onWindowRestore` re-enters it
  (not when windowed);
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
- **REST/JSON Add-on Architecture (Media Hub, code name Archive):**
  The player plays HTTP(S) URLs (it has no torrent client: `infoHash`/`ytId`/`externalUrl` entries
  are skipped). Debrid-backed add-ons (Torrentio + Real-Debrid/TorBox etc.) are fine and supported —
  owner, 2026-10-21: users are worldwide, don't judge their sources. Their uncached streams
  (`[TB download]`, `[RD download]`…) 302 to a ~0.1 MB "being downloaded" clip; see
  `ArchiveReadyWatch` (Ready tag) and `DebridApi` (Settings > Media Hub > Debrid accounts).
  Two kinds of add-on source: a **stream-only** add-on on IMDb ids gets its grids/metas from
  Cinemeta (`ArchiveCatalogProvider`) and only `/stream/` goes to the add-on; an add-on with **its
  own catalogs** (any type, any id scheme — since 1.0.24) is browsed and played entirely from its
  own `/catalog/`, `/meta/`, `/stream/`. Custom types (not movie/series) keep their type string
  (`ArchiveCatalog.wireType` / `ArchiveMeta.wireType`) for requests and are browsed under Movies
  behind the genre picker's **Other** entry only (`ArchiveService.otherGenre`; kept out of the
  normal rows, search and Recently watched — adult add-ons, owner 2026-10-19).
  **Jellyfin / Emby** (1.0.24, `services/media_server_api.dart`, `screens/settings/
  media_server_screen.dart`): a server is an `ArchiveSource` with `server` (`MediaServerLogin`:
  kind, userId, token, deviceId), libraries = catalogs, direct `/Videos/{id}/stream?static=true`
  (no transcoding; key `ApiKey` Jellyfin / `api_key` Emby; auth header `Authorization` vs
  `X-Emby-Authorization`+`X-Emby-Token`; Emby tried under `/emby`). Owner added a real Emby server
  successfully on 1.0.24 (2026-10-19); Jellyfin still only mock-tested. Not done: watched-state sync, server subtitles, Quick Connect.

## 11. Known bugs & fixes (full table in `dev-notes/bugs-and-fixes.md`)
Look there before debugging. Still-open items: the **Fire OS stale launcher icon** (not fixable). The
old ~50 s EPG delay is **fixed** by the SQLite EPG store (0.5 s on the Formuler) — Windows check pending.

## 12. Features (details in `dev-notes/features.md`)
Timeline/Live guide, player secondary row + badges, Multiview, welcome prompt, hide channels, Expand catalog, backup servers, palettes, **viewer profiles** (never rewrite Main's storage keys), **languages** (EN/FR/ES/IT/EL), **Transfer to another device** (Wi-Fi + internet vault, built to grow into cloud sync). Read the file before changing any of these.

## 13. Status & open items (as of 2026-10-21)
- **Unreleased (next = 1.0.35):** Media Hub show page shows its source chip (`SeriesDetailScreen
  .sourceLabel`) and an hourglass on the tapped episode + Play while streams load (`_startingId`,
  extra presses ignored). **Add-on links resolved once before playing** (`services/stream_resolver.dart`
  `resolveRedirects`, `archive_playback._playUrl`; media servers skipped; `_track` keeps the original
  link for `ArchiveReadyWatch`): a 4K DV episode took 6.5 s to start on a Shield (user log) because
  every range request re-walked add-on → debrid API → CDN; measured on a TorBox remux 2.3 s → 0.65 s
  for 3 requests. **No endless retry on dead links** (§9). Shield user's 47 GB Carrie link was an
  HTTP 404 retried 18x. **Unplayable video no longer crashes the app**: a DV profile 5 episode
  (`dvhe.05.06`) on the Formuler (no DV decoder) went READY on audio alone and the platform view's
  `sendInitialized` NPE'd on the null video format (also seen on 1.0.30). `ExoPlayerEventListener
  .sendInitializedOrReportUnplayable` now pauses and errors with `[UNSUPPORTED_VIDEO: mime codecs
  size]`; `_friendlyPlaybackError` has a Dolby Vision message (owner-confirmed). DV profile 8 (and 4)
  already plays as HDR10 via media3's HEVC fallback; profile 5 can't; profile 7 could (not done).
  **CFL** in Sports Trak (Codex, merged). **Sports matching, audit items 1+2**
  (`dev-notes/sports-matcher-audit*`, harness on branch `codex/sports-matcher-audit`):
  `_usNetworkNames` (CBSSN, NFL Net, NHL Net, NBC Sports Phil, USA Net: US-tagged exact network
  only); `prepare` signature hashes every id/name/epgId (was count+first+last: stale index after a
  rename); `MatchReason.teamChannel` + labels say "no guide listing" for team-channel/broadcaster
  suggestions; `whyNoMatch`/`NoMatch` explain an empty game (only on a hidden channel — named;
  upcoming game's kickoff has under half the channels listed as now — `EpgService.guideCoverageAt`,
  not MAX(stop): a few week-long listings hid a 2-day guide; nothing names it), shown on the
  hero, game menu, live list and side panel. `prepare(hidden: playlist.hiddenLiveChannels())` at
  **every** call site (the signature includes it; mixing would re-index each time). Restricted
  viewers get no hidden list. Phone-installed `+394`; not box-tested.
- **Shipped: 1.0.34 (`+388`, 2026-10-21, latest; test builds `+386`/`+387` = pre-releases
  `1.0.34-test.386`/`.387`, `+388` owner-tested on the Fire Stick):** **list-only add-ons** (`ArchiveSource.listOnly`,
  stored `listOnly`): a manifest with movie/series catalogs on IMDb ids (or no idPrefixes) and no
  `stream` resource is accepted instead of "This source offers no streams" — rows from its own
  `/catalog/`, metas from Cinemeta, Play asks every stream-only source (same path as tracker lists).
  User's case: Streaming Catalogs (`catalog.ers.pw`, Netflix/Disney+/Prime/Apple TV+/HBO Max),
  verified live (10 rows, Cinemeta metas). `test/archive_list_only_test.dart`.
  **Global Search › Media Hub**: after the playlists' rows, a gold "Media Hub" heading, then its
  Movies / TV Shows (`ArchiveService.searchRows(underOther: false)` — no Other/adult content, doesn't
  touch the tab's own search state; 500 ms debounce; hidden with Hide Media Hub).
  **Unreadable-stream sniff** (Android, `PlaybackService._sniffUnreadable` + `sniffStream`): on
  ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED for a link the `.ts` rule doesn't cover, the first KB is
  read once per link: `#EXTM3U` = retried as HLS (`_hlsUrls`); JSON/HTML/text = the reply goes on the
  error as `[SOURCE_REPLY:kind HTTP n] text` and `_friendlyPlaybackError` shows it in plain words;
  a no-URL line goes to Send log. User case: Media Hub TV show via TorBox add-ons — couldn't reproduce
  with Torrentio+TorBox (10 episode/pack links all MKV). No stream picker = one stream, so likely a
  Jellyfin/Emby `.strm` library: a body that is only an http(s) link = `link`, played instead (address
  never shown/logged). Pre-release `1.0.34-test.386` has it. Windows: not done.
  **Add-on import** (`services/addon_import.dart`): the Media Hub sources link field takes many
  `manifest.json` links at once (`AddonImporter.linksIn`, even run together) — each checked, Media Hub
  sources saved in one go (`ArchiveService.checkSource`/`addCheckedSources`), subtitle-only ones go to
  Settings > Add-ons; summary dialog. **Import from Stremio** (`screens/settings/stremio_import_screen.dart`,
  `StremioAccount`): QR + 4-letter code from `link.stremio.com/api/v2/create`, poll `/read` every 3 s
  (error 101 = not signed in yet), `api.strem.io/api/addonCollectionGet`, checklist, then `logout`.
  Built-ins (protected, Cinemeta, 127.0.0.1) skipped. Undocumented Stremio API; the signed-in `/read`
  shape (`result.authKey`) — **owner-verified on the Fire Stick (2026-10-21)**: real sign-in, list, Streaming Catalogs added. Nuvio: needs
  Nuvio's Supabase anon key (`api.nuvio.tv`) — owner chose not to ship it (2026-10-21); paste links instead.
  **Expand catalog remembers its sort** per category (`vesper_catalog_sort_vod|series`, shown beside
  the Sort icon; a saved TMDB sort re-runs its lookups). **Data pool on VOD** (Android): OK on a
  movie/episode (provider or Media Hub) opens the Data pool card alone when the setting is on.
  **Quality badge uses width too** (`qualityLabelForTrack`): 3840x1600 films were "HD", 1920x800 had
  none. `test/video_quality_test.dart`. Not done: subtitle size setting (asked by the same user).
  **Player buffer budget** (§9 `BufferBudget.java`): a 4K remux ANR'd the 1.7 GB Fire Stick (whole
  device out of memory, kswapd 82 %, VesperTV killed as not responding). Under 2.5 GB RAM the main
  player caps its buffer at 64 MB, texture players at 32 MB. Owner: a 4K Spider-Man remux then
  played well (tiny lag at start); memory log: app ~320 MB PSS, device free RAM low point 55 MB.
  **`AGENTS.md`** added: Codex (or any agent) reads it first; it points here.
- **Shipped: 1.0.33 (`+385`, 2026-10-21; Formuler-tested):**
  - **Media Hub Ready tag** (`services/archive_ready_watch.dart`): a Media Hub stream under 90 s is a
    source's "being downloaded" clip — no resume point, no Trakt/Simkl scrobble, no auto-advance;
    on leaving the player the title is queued (persisted, device-only `vesper_hub_ready_watch`),
    checked every minute for 24 h; poster shows outlined **Fetching…**, then gold **Ready**
    (cleared on the next play). Ready = the user's debrid account lists the URL's 40-hex torrent
    hash as finished (`services/debrid_api.dart`, Real-Debrid `/torrents` + TorBox `/torrents/mylist`,
    keys in Settings > Media Hub > **Debrid accounts**), else the same URL now serves ≥50 MB and ≥4×
    the clip (Torrentio: clip `videos/downloading_v3.mp4` 0.1 MB vs TorBox CDN file). Owner saw
    Fetching… on the Formuler; the Ready flip itself not yet seen on a box.
  - **Big Sky Football / Basketball** (League bank › **College**): `SportsLeague.espnGroup` adds
    `groups=` (scoreboards) / `group=` (standings) to ESPN's whole-sport feeds (20 = Big Sky football,
    5 = men's basketball; verified live). Any other conference = one entry.
  - **AHL + ECHL** (Hockey bank, TheSportsDB 4738 / 4916, no tables). AHL matched on the Fire Stick.
  - **Remote tips**: site page `docs/remote.html` (tabs per screen, search, print = PDF), linked
    from the site nav + How to use it; Settings > General > Remote tips = QR to it. Update the page
    whenever a hold menu or remote move changes.
- **Shipped: 1.0.32 (`+384`, 2026-10-21; test build `+383` on the Formuler + Fire Stick):**
  - **Recording (Android only)** — Sports Trak games (game menu `_recordTiles`: "Record until the
    show ends" / "Record until I stop it", 4 h max) and live channels (hold menu), margins 5 min
    before / 30 after, **auto-record ONE team** (all its leagues). Native `RecorderService.kt`
    (foreground service, wake + Wi-Fi lock, HLS loop, `LiveTee`: watching the recorded channel
    plays `127.0.0.1` so both share one provider connection) + `RecorderScheduler.kt` (exact
    alarms `USE_EXACT_ALARM`, `BootReceiver`, channel `vespertv/recorder`). Dart
    `services/recording_service.dart` (device-only `recordings.json`), Recordings tab row
    (`screens/recordings_screen.dart`: game cards = both teams, **never the score**; channel
    card = logo + program at start), Settings > Recording (app storage or USB/SD), conflict popup
    when the account's connections are used. 20 GB cap, stops at 1 GB free (start needs 1.25 GB).
    **Red REC cue** (`widgets/rec_cue.dart`): dot by a recording channel on the live list +
    Timeline guide corner, "● REC" pill before the player badges, on Sports game cards (outlined
    dot = scheduled) and beside the hero's status. Fire Stick-verified: record, tee, stop,
    playback with seek. **Unverified:** scheduled start with the app closed / standby,
    HLS-behind-.ts, USB/SD, conflict popup, auto-team over days, the REC cue on a box.
    Notification text is English only. Windows: no recording.
  - **Send log** (Settings, `services/app_log.dart` capture zone + `redact`,
    `send_log_screen.dart`) → `POST pair.vespertv.app/api/log` → owner's private Discord channel
    (relay `_log_post`, webhook only in root-only `/etc/pair-relay.env` `PAIR_LOG_WEBHOOK`).
  - **NBA channel matching** (`_networkAliases`, `_callSign`, team channels step 2b): 11/11 on the
    Fire Stick. **Menus:** `widgets/tv_dialog_option.dart` replaces every `SimpleDialogOption`
    (gold focus row, `SwallowHeldActivate` — a held OK on a focused first row activated it), TV
    forces the focus highlight (`alwaysTraditional`); Formuler + Sony CEC remote recheck pending.
- **Shipped: 1.0.31 (`+382`, 2026-10-21; test builds `+374`..`+381` on the Formuler and
  the Fire Stick, all owner-tested):**
  - **Own live groups** (`services/user_groups.dart`, `UserGroups` owned by `PlaylistManager`,
    key `nox_my_groups` **per viewer, across playlists**; moves keyed by `Channel.id`, own channel
    order across playlists). Hold OK on a channel → **Move to group…** (own groups, New group…,
    Back to <provider group>) / **Remove from {group}**; hold on any live group → **New group…**;
    hold on an own group → Move Up/Down, Move to Top, New group…, Delete. Own groups are rows
    under Favourites/History (`_myGroupsId` sentinel) and are never hidden with a playlist (a
    first per-playlist version was — owner test). Sessions only know `myGroupOf` → `liveGroupOf`;
    the loaded `Channel.group` stays the provider's. TV group selection is **by title**, so own
    group names are made unique against provider titles. Not done (owner: fine as is): hiding an
    own group, Search by own group, kid-profile allowlist.
  - **Settings = left panel + right pane** (`settings_menu_screen.dart`): Playlists & guide /
    Media Hub (sources, Add-ons, Trakt & Simkl, TMDB) / Interface (Theme, Tabs, Background video,
    Data pool, Favourites, Multiview, Resume reminder) / General (Language, Startup, History) /
    Device & data (Transfer, Backup, Updates). The focused category's description + rows show on
    the right; Right/OK enters, Left/Back returns (each column its own `FocusScope`, plain default
    Up/Down inside); phone = list → category page. `GeneralSettingsScreen(sections:, title:)`
    shows one section without its header.
  - **Fast startup** (opt-in, §10).
  - **Data pool** (Settings > Interface > Data pool, off by default): OK on a live channel opens a
    second card with resolution, fps, codecs, declared + measured bitrate, variants, audio tracks,
    buffer, HDR, dropped frames, playing-for timer (`widgets/data_pool_card.dart`, native §9).
    Never shows the server host; no channel probing.
  - **Black-flash fix** on channel change (`PlaybackService.switching` + `VideoPlayerPane`
    spinner; `switching` is set before `_teardown()`, `currentChannel` is not).
  - **Greek football club names** (`greekBroadcastNames`, 197 clubs) — confirmed by Black1914.
  - **Media Hub**: the floating bar starts with **Search** (+ Clear); rows no longer lose the
    selector after ~15 Rights (`_cardExtent` missed PosterCard's own 6 px padding → 12 px short per
    step; now exact + `itemExtent`).
  - **Transfer** already carried all Sports Trak data (test proves it); its text now says so.
    Settings row subtitle: "Copy all of your data to another device".
  - **Faster channel changes: not done.** The main player already starts at
    `bufferForPlaybackMs` 500; time each step on the Fire Stick before changing anything (reusing
    one ExoPlayer would be the big win — ask first).
  - Site: dedicated Sports Trak / Media Hub sections (`#sports`, `#media-hub`) + new screenshots.
    Never show a piracy add-on's name in a site screenshot (the Media Hub shot's source chip was
    painted out).
- **Shipped: 1.0.30 (`+373`, 2026-10-20, latest; test `+372` = pre-release `1.0.29-test.372`,
  confirmed by the Greek user — Nova Sports found):**
  - **Greek-only guide titles:** Strong8K's Nova guide says `Live: Μπάσκετ: Χάποελ Τελ Αβίβ -
    Βίρτους Μπολόνια` (EuroLeague only in the description, which isn't searched).
    `greekForeignTeamNames` (greek_sports_names.dart): 19 EuroLeague clubs' Greek spellings from
    Nova's listings, same shape as the Greek clubs; `greekTeamFor` searches both lists.
  - `_foldAccents`: č ć š ž đ ş ğ ı ł ą ę ń ś ź ż ő ű ř ě ů ț ș ă ("Beşiktaş" split words).
  - **App language Greek → GR channels rank first** for every league (`_languageTags`, +20 like
    `homeTags`). Only Greek: the other languages' viewers mostly watch North American feeds.
  - Strong8K test account for guide checks: the disabled "dom OG" playlist in the Windows app.
- **Shipped: 1.0.29 (`+371`, 2026-10-20, latest; test builds `+369`/`+370`, pre-release
  `1.0.28-test.370` for a Greek Discord user) — released before that user finished testing
  (owner: best we can do for now):**
  - **Greek:** UI language `lib/l10n/el.dart` (machine-authored, not native-reviewed); leagues
    Super League 2 (`gre.2`), EuroLeague, Greek Basket League (TheSportsDB; basketball has no
    free tables → `hasStandings: false`); `SportsLeague.homeTags` ranks a league's own-country
    channels first; `greek_sports_names.dart` transliterates Greek guide titles and maps 23 clubs.
  - **TheSportsDB day cap:** the free `eventsday` returns at most **3 games per league/day**
    (SL2 user: games missing). A capped day now loads its whole round(s) from `eventsround`
    (uncapped) and keeps that UTC day. `eventsseason` caps at 15 and `eventsnextleague` at 1.
  - **Matching:** `sportsDbShortName` strips BC/SK/FC/Basket/Baloncesto/Pallacanestro… (feed
    names never matched guides); EuroLeague `seriesPhrases` incl. raw Greek spellings — team
    leagues accept a series-only guide title unless it names another game. Unconfirmed on a
    real Greek guide (Nova Sports).
  - **Box score** (`_BoxTable`): trailing columns that don't fit are dropped, names keep 96 px
    (NBA's 7 columns overlapped the other team on the Formuler). Owner-checked.
  - **Windows:** Media Hub detail had no back arrow at wide widths — arrow at every width + Esc.
    Owner-confirmed.
- **Shipped: 1.0.28 (`+368`, 2026-10-20, latest; test builds `+361`..`+367`, pre-release
  `1.0.28-test.362` for a Fire OS 6 user):**
  - **Sports Trak:** Romanian Liga I/II, Croatian HNL, Serbian SuperLiga, Bulgarian First League
    from **TheSportsDB** (`SportsLeague.sportsDbId`, `services/sports_db_source.dart`; ESPN has
    none of them, its `rou.1` is frozen in 2025). Free public key `123` (shared, not a secret).
    Free tier: day's games + scores, next game, **top 5** of the table, no live minute/box
    score. Rate limit ~10 quick requests then 429 with a growing `Retry-After`, so one day per
    league (not 3), a token bucket in `SportsDbSource.get`, live refresh 2 min.
  - **HLS behind a `.ts` URL** (Strong8K via `live.flixnest.app`): `.ts` 302s to an `.m3u8`, and
    ExoPlayer picks its reader from the URL → ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED.
    `learnHlsHost` retries once with `formatHint: hls` and `streamController` opens that host's
    live `.ts` as HLS for the session (player + Multiview). Owner-confirmed on the Formuler.
  - **Compatibility video** (Settings > General > Background video, `AppPreferences.compatVideo`,
    device-only): main player as a **texture** instead of the platform view. Default on for
    Android 7 and older (`DeviceTypeService.sdkInt`): a 1st-gen Fire TV Stick 4K (Fire OS 6.7)
    showed the picture twice, stripes, and the guide stuck on screen after Back. Unconfirmed
    (the user hasn't tested yet). Texture players use Multiview's buffer policy (§9).
  - **Media Hub:** Favourites row per category (hold OK on any poster toggles; Recently watched
    keeps hold = remove), `keyArchiveFavorites`; **stream-only regression fix**: an IMDb stream
    add-on with only custom-type catalogs was read as "own catalogs" since 1.0.24 (only its row
    under Other) — it's stream-only again (Cinemeta grids), stored sources re-checked once per
    launch (`_recheckCustomOnlySources`); custom-only add-ons without IMDb streams stay in Other
    (owner-checked with an adult add-on). **Whole source under Other**: an own-catalog add-on
    with any custom-type catalog (`ArchiveSource.autoOther`) goes entirely under Other — its
    plain "series" shows too (adult add-on report), TV Shows gets an Other filter — and every
    add-on source has a **"Show under Other"** switch (Settings > Media Hub sources,
    `otherChoice`, stored as `other`) so either direction can be undone; Refresh after changing.
    Floating bar under Other starts with **Back to main**. PosterCard's InkWell focus highlight
    is off (it showed as a stray box under the zoomed card). Owner-confirmed.
  - **Real 4K tag** (`services/real_4k_channels.dart`, `widgets/real_4k_tag.dart`): a live
    channel that decoded at 2160p (Android at 4 s / 12 s, Multiview at 6 s, Windows from mpv's
    height) gets a gold 4K tag on the live list and the Timeline guide (corner badge); lower
    playback removes it. Never from the name. Not in search / side panel yet.
  - **Windows:** volume slider + mute in the player bar (M key too), remembered per PC
    (`keyDesktopVolume`/`keyDesktopMuted`). Owner-confirmed.
  - Playlists menu eye icon on non-TV devices (owner-confirmed on the phone); `/pickup` command.
  - **Trailers: on hold** (owner). Only safe way = open the YouTube link in the YouTube app /
    browser, button hidden when nothing can open it; never extract YouTube streams in-app.
- **Shipped: 1.0.27 (`+360`, 2026-10-20, latest; test builds `+351`..`+359` were on the Formuler and
  the Fire Stick):** playback error codes on screen (§9); hold OK on a live channel
  (guide or list) = menu with **Move Up / Down** inside its group (`PlaylistSession.moveChannel`,
  `nox_channel_order`; the plain list's hold now opens that menu instead of favouriting);
  Settings > General **collapsible sections** (`_section`), **Mix playlists in Favourites**
  (A-Z across playlists), **Background video** opt-in (§10); **Backup & restore** (§3; Android
  11+ can't list another install's files, Fire TV has no file picker — only Fire OS 7 sticks see
  old backups after a reinstall); Media Hub sources show "Use the Other filter…" under sources
  with custom-type catalogs; Jellyfin/Emby **From phone** (`PairingKind.mediaServer`; it and the
  link kind are **Wi-Fi only** — the relay's deployed pair.html predates them, redeploy only if
  the owner asks); Media Hub **hold a row button = roll-down menu** (Expand catalog =
  `screens/archive_catalog_screen.dart` grid, Go to row); groups column **Playlists ▾** row under
  History (What's New/Favourites/All in Movies/Shows): jump to a playlist, Right = **Hide/Show
  that playlist's groups in this tab only** (`keyHiddenPlaylistGroups`, per viewer, channels stay
  in Search/Favourites); Multiview stuck-focus fix (§10). Owner said "very good" to the menus,
  From phone and the jump; owner confirmed the Multiview fix and Backup save + restore on the Formuler (2026-10-20). Unconfirmed: restore after a full uninstall, error screen, move, Windows.
- **Open (2026-10-19 evening):** no real Trakt/Simkl account has signed in yet (all mock-tested +
  live endpoint/client-id checks) — first user reports are the real test. Jellyfin only
  mock-tested (owner confirmed a real Emby server). Windows Multiview has no header-overlay /
  full-screen fade (hover controls instead) — do it only if asked.
- **Shipped: 1.0.26 (`+350`, 2026-10-19, latest, commit `e3c3f51`):** every text field gated + guard test (see §10, Fire TV report).
  **Multiview header = overlay** (user report: it squashed the 2x2): grid fills the screen; header
  slides down on Up from the top row (`_onGridKey` → `_revealHeader(focus: true)`, `_headerFirst`),
  Down returns to tile 0, hides 1.5 s after focus leaves (`_headerScope` listener), shown 4 s on
  entry; touch/mouse get a top-centre handle. Multiview **full screen**: name + back arrow fade
  after 4 s, any key/tap reveals; while hidden the first OK only reveals (Back always works).
  **Trakt/Simkl read-back** (`services/tracker_sync.dart`): history (watched episodes per show,
  watched movies, paused items; Trakt `/sync/watched/*` + `/sync/playback`, Simkl
  `/sync/all-items/... extended=full` + `/sync/playback`) cached 5 min, merged across accounts,
  matched by IMDb (Media Hub) or provider TMDB id (IPTV `Channel.tmdbId` / `XtreamSeries.tmdbId`)
  and written into the saved positions (only fills in: never clears a mark or overwrites a local
  resume). Unknown length → `StorageService.setResumeFraction` (1e6 scale + flag; `PlaybackService`
  converts on start). Applied on opening a series/movie page and to the whole VOD catalog 20 s
  after startup / on connect (`syncCatalog`). "Continue watching on Trakt/Simkl" rows (`*.playback`,
  re-derived for old accounts in `ArchiveService.sources`). IPTV plays now scrobble too (TMDB),
  hold-OK episode toggle pushes to `/sync/history(/remove)`. IPTV *shows* don't join the TV tab's
  Continue Watching until opened once (episode ids need `get_series_info`). Mock-tested + live
  401 path checks; no real account yet.
- **Shipped: 1.0.25 (`+349`, 2026-10-19)** — everything in the next bullet (was the
  "unreleased" list). Owner trusted the mock tests; real Trakt/Simkl sign-in still unconfirmed.
- **1.0.25 contents:** Multiview quad tiles **fill** their quarter
  (`_MaybeAspect`, no aspect lock — owner: black side bands on a landscape phone); **portrait
  phone = always 2 screens** (`_portraitDual`: toggle hidden, screens 3-4 paused, audio moved).
  Picker **Live now** = one row per game, OK opens every matched channel
  (`widgets/game_channel_chooser.dart`), the choice saved as the game's pick
  (`MultiviewSports.rememberPick` → Sports Trak uses it too). **Tennis** (`SportsKind.tennis`,
  `_parseTennis`: main-draw singles only, score = sets won, matched like fights) — ATP + WTA,
  and **NCAA men's/women's soccer** in the league bank. README rewritten for the universal player.
  Game stats **Goals** section now lists every hockey goal (from ESPN `plays`, type `goal`:
  period, clock, scorer, assists, running score) — the box score keeps only the top 3 per position,
  so a 4-0 showed two scorers (owner photo, 2026-10-19).
  **Trakt & Simkl** (Settings > Trakt & Simkl, `screens/settings/trackers_screen.dart`,
  `services/tracker_api.dart`, `services/watch_tracker.dart`): device-code sign-in (code + QR on
  the TV); an account is an `ArchiveSource` with `tracker` (`TrackerLogin`) whose catalogs are its
  lists (Trakt watchlist/trending, Simkl watching/plan-to-watch) by IMDb id, metas from Cinemeta,
  Play via stream-only add-ons. Scrobbling: `playArchiveTitle` registers the channel →
  `PlaybackService.play`/`_teardown` and `DesktopPlayerScreen` report start / stop (≥80 % = watched,
  else pause). Jellyfin/Emby items carry `ProviderIds` IMDb (`ArchiveMeta.imdbId`). **No secret,
  no relay:** the Trakt app (developer.trakt.tv, owner's GitHub-linked account, Production,
  redirect `https://vespertv.app/trakt`) is a public client — device token + refresh take only
  `kTraktClientId` (verified against the live API 2026-10-19). Simkl = **AUTH V2** app of type "TV,
  devices & command line" (V1 /oauth/pin retired ~2027; V2 = `POST /oauth2/device` + `/oauth2/token`
  device grant, 7-day tokens refreshed with the client id, QR opens `verification_uri_complete`); both client ids set (verified live). Credits: Settings footer + Trakt & Simkl screen +
  README "Credits". Mock-tested plus a live Trakt device-code check; no real sign-in yet.
- **Shipped: 1.0.24 (`+348`, 2026-10-19).** Archive/Extras tab renamed **Media Hub**
  (user-facing only; code/files/keys still `archive_*`); site repositioned as a "universal media
  player"; add-ons with their own catalogs of any type/ids (Other filter); **Jellyfin / Emby**
  sources (see §10 REST/JSON); Multiview name bar auto-hides after 4 s (`widgets/auto_hide_overlay.dart`,
  it covered the NHL score bug; speaker dot bottom-right meanwhile) and the Multiview picker got
  **Live now** (Sports Trak games playing now + matched channel) and **Sports** shortcuts
  (`services/multiview_sports.dart`; Windows: chips). Also live CC captions, decoder fallback,
  ANR fix on 4K release, `TvTextFieldGate`, Fit/Fill screen, parking live on Sports/Settings/Search.
- Donations will go through GitHub Sponsors (pending approval). After approval: `FUNDING.yml`,
  site/README links and an About row. Relay `X-VesperTV-App` enforcement (`PAIR_REQUIRE_APP=1`) is
  ON since 2026-10-17 (service file backed up on the VPS as `pair-relay.service.bak-*`).
- **Shipped: 1.0.23 (`+346`, 2026-10-18).** +340 (owner: "perfect"):
  Extras rail is now only Movies / TV Shows / Refresh / Extras sources; the row jumps (Popular /
  New / Featured / Recently watched, not search results) moved into the floating bar before
  Search + Genre (`_barRows`, `_barRowNodes`; bar scrolls sideways, `_focusBarNode` keeps the
  focused button visible; Up from a row lands on that row's button). The "big library" crash
  reporter says his library now loads fine (not reproduced by us; the lazy-rows idea stays a
  fallback if it comes back).
  **+342:** picker sheets scroll (Audio Track was a plain Column, ran off screen with ~12 tracks;
  subtitle sheets not lazy so the autofocused language exists; `TvMenuTile` reveals itself on
  focus, `test/menu_sheet_scroll_test.dart`). **Channel-change flash fixed** (owner-confirmed on the
  Formuler): `PlaybackService.play` now notifies + waits a frame and 250 ms *before* `play()`, so
  the platform view's surface exists first — playing surface-less then attaching mid-stream made
  the box's decoder restart (one frame, black until the next keyframe, picture).
  **+343:** the old phone `HomeScreen` is **gone** (+ its orphans `sidebar`, `channel_list_tile`,
  `mini_player_bar`); `TvHomeScreen` is the only home, Settings > Theme > Layout = Auto / TV
  (a saved 'phone' reads as 'auto'). Portrait phone bottom bar always has **Extras** (after the tabs,
  before Sports Trak; Hide Extras removes it) and the More page no longer lists it.
  **+345 (phone, owner: "very good"):** fullscreen player on touch: a left-edge tab (with the bars) and
  swipe right open `PlayerSidePanel` (live only), swipe left / tap the video closes it, panel max
  88% wide. Landscape touch Pull stats = full height right against the panel, 64 px tap-out strip
  on the right, `useSafeArea: false` (TV unchanged). **Taps on a video:** a `GestureDetector`
  *around* the platform view never fired on a phone — use `widgets/video_tap_layer.dart` (invisible
  layer *over* it): TV-tab preview (off while the pane shows an error) and the Sports hero
  (tap = `_play` full screen, also Windows click).
  **Windows (+346):** sidebar **Windowed / Full screen** row (`services/desktop_window.dart`, live
  switch, remembered with the window bounds, both keys skip Transfer). **window_manager gotcha:** an
  app *started* full screen saved its style before the first show (no `WS_VISIBLE`), so
  `setFullScreen(false)` hid the window (frozen ghost frame, window-less process, style
  `0x04CF0000`) — `show()` right after fixes it. Fullscreen player: `PlayerSidePanel` (tab on the
  left edge, Left key when the bar isn't focused, Esc / click closes, `onPlay: _switchTo`); Pull
  stats on Windows = its own card (≤980 wide, 88% high) beside the panel, not the phone layout.
- **1.0.22 (`+339`, 2026-10-18):** Extras **genre filter**
  (Search + Genre in a floating pill at the top centre, per category — owner didn't want them in the
  rail with Movies/TV Shows; Up from the first row reaches it; genre picker + search are `_FloatingPanel` dialogs in the same style; **Recently watched** row per category from `ArchiveService.recordWatched` (on play, `vesper_archive_history`, hold OK = remove) and per-category **recent searches** (`vesper_archive_recent_searches`), both Extras transfer keys. Open: a user's "big library" source sent the app to the launcher — not reproduced; suspect memory: every row is built at once and each catalog fetches 2 pages: `ArchiveCatalog.genres` from the manifest's `genre` options, Cinemeta's
  list for provider rows, `withGenre`; "New" hides while a genre is picked; genre labels translated
  under `genre.` keys — "History" alone is watch history). **Favourite league** (League manager: hold
  OK on any of your leagues = menu: favourite on/off, send back; per viewer
  `vesper_sports_favorite_league`, `favoriteSportsLeague()`): Sports Trak opens filtered to it, its
  live games lead the side panel's Live now. **Pull stats**: hold OK on a game in the fullscreen side
  panel = `SportsGameDetailsDialog(overStream:)` see-through, right of the panel (hold = key repeat,
  like `HoldToActivate`). Phone tab bar labels scale down (FittedBox) instead of "Sports T…". Portrait
  phone: the resume pill hides while the TV preview shows (`_syncPreviewHint`, released when a
  screen is pushed). **Windows parity:** one-row player bar (`DesktopPlayerScreen._buildBar`),
  subtitles (`widgets/desktop_subtitles.dart`: file tracks + add-ons + per-series memory, media_kit
  draws them; Settings > Add-ons now shown on Windows), Sports hero mini player via
  `DesktopMiniPlayer` (second click/Enter = hero, again = full screen on the same session, Back
  returns to the hero). Owner tested the Android side on the Formuler; Windows untested.
- **1.0.21 (`+335`, 2026-10-18)** — **Extras tab** (code name
  Archive: `archive_*` files, `ArchiveService`, storage keys unchanged): user-added Stremio-schema
  add-on sources; a stream-only source on IMDb ids gets Popular / New (this year) / Featured rows,
  search and metas from Cinemeta (`ArchiveCatalogProvider`), Play asks every stream-only source's
  `/stream/` and shows "Choose a stream" when there are several (direct http(s) only). Shows open
  the regular `SeriesDetailScreen` (its `loadEpisodes`/`playEpisode`/`showFavorite` hooks, see
  `archive_playback.dart`); episode queue = URL-less placeholders resolved when due
  (`PlaybackService.setUpNextQueue(resolve:)`, `DesktopPlayerScreen.resolveQueued`), keeping the
  picked source + stream name. Search = server + loaded rows, word-prefix ranked
  (`ArchiveService.rankSearch`). Rows page in as focus nears the end (own scroll controller per
  row — focusing an unbuilt lazy card does nothing). Back from the rail fixed (PopScope canPop was
  stale). Extras sits under TV Shows in the tabs column; Settings > General > Tabs: Hide Extras,
  **Hide Multiview** (row + player button). Transfer: "Include Extras tab data" (off = payload
  marker, receiver keeps its own Archive keys). Phone "send a link" (`pair.html` `#…link`) is
  **Wi-Fi only on purpose** (owner, 2026-10-18): the VPS relay's `pair.html` is deliberately
  left without link mode — don't redeploy it unless the owner asks (revisit if users request it).
- 1.0.20 (`+330`, 2026-10-17) — the Sports tab is renamed
  **Sports Trak** (`AppConstants.sportsTabName`, a brand: never translated, `{tab}` placeholder in
  sentences); **live games list** ("See all · stats" beside Live now with 2+ live games: dense rows
  with situation + top players, OK = stats pop-up with box score / injuries / team stats /
  standings from ESPN `summary`, ▶❚❚ or hold > Play = full screen, Back = list, league logo
  backdrop); channel search much faster (guide scan: one team's names per game, superstring terms
  dropped, 15 min cache keyed by `EpgService.lastUpdated`, one app-wide
  `SportsChannelMatcher.shared`, hub shows last visit's channels at once); explicit Left/Right on
  the game rows (fast scrolling jumped rows). Details: `dev-notes/sports-tab.md` (Live games list).
- 1.0.19 (`+320`, 2026-10-17) — relay app check ON (Transfer over
  the internet / From phone need 1.0.16+, announced as a privacy change); hold OK on an episode =
  mark watched/unwatched (watched episodes restart from 0); **Neon Green** palette (`vivid` flag,
  `#2FD414`); portrait phone: bottom tab bar (TV/Movies/TV Shows/Sports/More, page 0 = "More"),
  live preview drawn once above the phone pages (shown on groups too), full-width Multiview picker;
  Sports: OK on another card while the hero plays = its details beside the same video (`_heroPick`),
  "WATCHING" pill on the playing card; Multiview 4 screens touch (tiles aligned to centre, 1.08
  boost). Formuler-only green 4K HDR Multiview tile = won't fix (bugs-and-fixes.md).
- 1.0.18 (`+309`, 2026-10-18) — **subtitles**: embedded MKV/MP4
  text tracks (Subtitles button, native `SubtitleBridge`, Flutter `SubtitleOverlay`) and **online
  subtitles from Stremio-protocol add-ons** (Settings > Add-ons, official OpenSubtitles v3 listed off,
  recent online languages one press away;
  a choice made on an episode carries to the rest of that series (movies manual). Player bar = one row
  (title | buttons | badges + time; slim seek bar above for VOD), Down focuses Play/Pause, pickers use
  `TvMenuTile`, OK in fullscreen live = info card, Sports game menu "Play here", coloured Live-now
  scores, Audio-track button retries, What's New skips disabled playlists + rebuilds a stale TMDB list,
  Search keeps the keyboard closed after picking a recent search. Details: `dev-notes/features.md`
  (Subtitles & add-ons). Windows: none of the player/subtitle work (separate player).
- 1.0.17 (`+294`, 2026-10-18) — Sports hero controls reworked
  (owner-tested Fire Stick/Formuler/phone): OK on a card only selects it, ▶❚❚ plays it in the hero,
  OK on the playing game = fullscreen at once; phone = tap focuses / tap plays in hero / tap
  fullscreen; phone Sports page scrolls as one + portrait hero; white play/pause icons in hints
  (`_KeyHintText`); `HoldToActivate` needs a key repeat to count a hold (first OK on the Fire Stick's
  Favourites opened "Clear favourites?"). Details: `dev-notes/sports-tab.md` (Hero mini player).
- 1.0.16 (`+289`, 2026-10-17) — **Sports hero mini player** (Android: Play/Pause on a game card plays its channel in the hero, video left + small VS layout right; OK = fullscreen on the same stream, Back stops it; see `dev-notes/sports-tab.md` "Hero mini player"); **unique channel ids** for channels sharing an EPG id (`Channel.withUniqueIds`, `epgKey`; fixed favourites/hide hitting every ESPN copy); hold OK on a tab's Favourites row = clear that tab's favourites (`PlaylistManager.clearFavorites`); What's New full-screen backdrop + default view; launch update prompt; Search/EPG-overlap/Transfer-focus fixes; relay app header; `TRADEMARKS.md`. Windows: no Sports preview yet.
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
  uses it on phones — the old `HomeScreen` was deleted in +343), touch/mouse group pick collapses the side columns, Add Playlist / My Teams stack
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
- **User logs:** the owner saves users' Send-log files in `Logs/` (repo root, git-ignored) for the agents
  to read, e.g. `Logs/LOG-F28YBG.txt`. Read them from there; never commit or quote secrets from them.
- **Two agents:** Claude and Codex share this repo. `AGENTS.md` is the entry point for Codex (and its
  hard rules, branch etiquette, task split and handoff/pickup steps); `CLAUDE.md` stays the single
  rulebook. Only one agent works at a time; commit before switching; Codex works on `codex/*` branches.
- **One task per session.** Long sessions get lossy compaction and re-read the whole history after the
  1-hour prompt-cache expires. Finish a task, commit, then start fresh (`/clear` or a new session).
- **Hand off, don't drag.** Before a session ends or compacts, run `/handoff` (project command in
  `.claude/commands/handoff.md`): it writes `HANDOFF.md` (git-ignored). **If `HANDOFF.md` exists, read it
  first**, then delete or overwrite it once its contents are done/obsolete.
- Don't read giant files whole (`tv_home_screen.dart` is huge): `Grep` for the symbol, then `Read` only
  the needed line range. Use the `dev-notes/` files on demand, not all at once.
- Keep CLAUDE.md lean: put details in `dev-notes/`, put in-progress state in `HANDOFF.md`, and
  record only lessons that prevent a repeat mistake.
