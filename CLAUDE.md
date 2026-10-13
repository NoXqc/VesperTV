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
- **Community:** Discord https://discord.gg/DDeGDHvFY. **Downloader (AFTVnews) code: `1760256`**.
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
3. Use Bash (Git Bash) or PowerShell. In Git Bash, **prefix adb commands that take `/sdcard`-style
   paths with `MSYS_NO_PATHCONV=1`** (it mangles them). Big multi-line heredocs sometimes break the
   Bash tool — write a script file with the Write tool and run that instead.
4. `flutter analyze` must report the baseline **22** info-level issues (no errors). Don't add new ones.
5. Check the current state of releases: `gh release list` (latest should be `1.0.1` unless noted
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
  `app_update_service.dart` (GitHub release updater).
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
- `flutter analyze` — baseline **22** info issues, none errors.
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
- Android requires `versionCode` (the `+N` in `pubspec.yaml`, currently **+206**) to never go
  down, even if the visible version resets. Always bump N on every build you intend to install.

## 6. Release workflow (details in `dev-notes/release.md` — read it before releasing)
Only release when the owner asks ("update the latest", "cut it", "fully release"). Outline: bump `pubspec.yaml` (versionCode `+N` must always rise) → `flutter analyze` → build APK + verify signature (§5) → build Windows + zip → **commit & push first** → `gh release upload <tag> app-release.apk VesperTV-windows-x64.zip --clobber` → `gh release edit <tag> --tag <new> --notes-file …` → make sure the tag equals HEAD → verify downloads/hashes, the OLD `NoXqc/NoXPlayer` redirect links and AFTVnews code `1760256`. The updater offers any *different* tag (`_isDifferent`), never leave two `.zip`/`.apk` assets on the latest release.

## 7. Test devices (details in `dev-notes/devices.md`)
Formuler Z11 Pro MAX `192.168.1.46:5555` (IP changes; also seen `10.0.0.46`), Fire Stick `192.168.1.33:5555`. Install with `adb install -r` after verifying the signature. Not rooted: no logcat/run-as on the Formuler. Never press Select on "Exit App". Hold-Select via adb needs `input swipe X Y X Y 1800`, not `--longpress`. The owner keeps the Formuler on **Dark / Gold**.

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
  Settings > General > "Resume last channel at startup" (off = the "Hold > to resume" pill).
  **Windows** always auto-resumes.
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
- **Never call `notifyListeners()` mid-build.** `PlaylistManager.notifyListeners` defers anything
  fired during the build phase (fixed Group Management checkmarks not repainting).
- Composite `Channel.id` (`playlistId::rawId`) vs raw `Channel.rawId`: EPG lookups and
  `Channel.isLiveId` need **rawId**.
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
- Open-source principle: **no embedded API keys.** Anything needing a key (TMDB, a future
  OpenSubtitles) is bring-your-own-key in Settings.

## 11. Known bugs & fixes (full table in `dev-notes/bugs-and-fixes.md`)
Look there before debugging. Still-open items: the **Fire OS stale launcher icon** (not fixable). The
old ~50 s EPG delay is **fixed** by the SQLite EPG store (0.5 s on the Formuler) — Windows check pending.

## 12. Features (details in `dev-notes/features.md`)
Timeline/Live guide, player secondary row + badges, Multiview, welcome prompt, hide channels, Expand catalog, backup servers, palettes, **viewer profiles** (never rewrite Main's storage keys). Read the file before changing any of these.

## 13. Status & open items (as of 2026-10-13)
- **Shipped: 1.0.1 (`+206`, 2026-10-13, latest on GitHub)** — adds Settings > General (resume last
  channel at startup, Multiview tip toggle). The 1.0.0 release was retagged in place; tag `1.0.0`
  (`+204`) remains. 1.0.0 restarted the version numbers and included
  the SQLite EPG store, visible playlist password and the Multiview fixes (volume-only audio swap,
  auto-recovery, SurfaceTexture green fix, wakelock, connection-tip popup, 2/4-screen layout; see
  §9-§10). Releases/tags older than 3.52 were deleted; their history is in `previousreleases.md`.
  Tags 3.52.0-3.53.3 and the 3.53.3 release remain. Apps on ≤3.52.3 can't see 1.0.0 (old updater
  wants a higher number) — they reinstall from vespertv.app / Downloader `1760256`.
  Still to check: SQLite EPG on Windows, Fire Stick "Update EPG Now" crash.
- **Test builds** for the owner's Fire Stick go to a GitHub **pre-release** (skipped by the updater
  and `/latest`), sideloaded via Downloader with the direct asset URL; delete it once shipped.
- **Roadmap (owner, 2026-10-12):** ~~fix Multiview~~ (done 2026-10-13). **Next:** a **Sports tab**
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
