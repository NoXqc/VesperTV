# Apple TV: closing the gaps with Android TV (plan)

Written 2026-11-23 by Claude (Fable 5.2) for the session that will write the code. Owner: "It seems
like there is a lot of things missing from our android version into Apple tv" -> a ranked list of 7
points -> "layout the plan to add all of your 7 missing points. When ready I'll point opus to the
code itself".

**Status (2026-11-23): built, uncommitted, nothing tried on an Apple TV** (owner: "Build all steps.
TvOS testers will wait whatever it takes", Apple TV pulled from TestFlight until he has a test box).
What was built and how it differs from the plan: "Built" at the end of this file. Every item ends
with what a tester has to confirm.

**This file is untracked in the main checkout.** When you make the worktree, MOVE it (don't copy)
into the worktree's `dev-notes/` and commit it with the branch, or a later merge into main stops on
"untracked file would be overwritten".

Read first: `CLAUDE.md` (rules: `tr()` + 7 languages fr/de/es/it/el/pl/uk, analyze baseline 16, only
commit / push / release when the owner asks, end reports with where it goes), `dev-notes/apple-tv.md`
(engine, libmpv, remote, storage, TestFlight), `dev-notes/icloud-backups.md` (in the
`VesperTV-claude-welcomesync` worktree), HANDOFF.md top block.

## Why libmpv stays

Apple's player (AVPlayer, `video_player_tvos`, still in the build as the fallback when libmpv
doesn't load) can't open raw `.ts` live streams or MKV files. The Apple TV build runs the computer /
iPhone stack (`DesktopPlayerScreen`, `DesktopMiniPlayer`, `DesktopMultiviewScreen`, media_kit) with
`AppPreferences.isTelevision` true. Android's own stack (`PlayerScreen`, vendored ExoPlayer, Kotlin
channels) never runs there, so anything built in Kotlin has to be rebuilt in Swift.

## Two corrections to the list the owner saw

1. **Point 2 (picture modes) already exists.** `_tvOptionsRow` in
   `lib/screens/desktop_player_screen.dart` (~line 2438) has
   `tile(prefs.videoFit.icon, tr(prefs.videoFit.label), _cycleFit)`. My grep missed it because the
   label isn't a string literal. Nothing to build: confirm on the box and tell the owner.
2. **Point 1 is frame rate only, not HDR.** The picture reaches the screen as an 8-bit BGRA Flutter
   texture (`third_party/media_kit_video_tvos`: libmpv -> OpenGL ES -> `kCVPixelFormatType_32BGRA`
   CVPixelBuffer). mpv tone-maps HDR to SDR before Flutter sees it, so asking tvOS for an HDR mode
   would show SDR pixels in an HDR mode: wrong colours. Always ask for SDR + the frame rate. Real
   HDR / Dolby Vision output needs another video path (a native layer under Flutter, 10-bit
   buffers): a separate, big project, not in this plan. I told the owner HDR switching would
   "probably" come along: it won't. Say so in the report.

## Order of work and branches

| Step | What | Branch | Needs the owner first |
|---|---|---|---|
| A | 1 frame rate, 3 buffer, 4 surround diagnostics, 6 tile order, 2 verify | `claude/appletv-parity` from main (worktree `C:\Users\aarse\VesperTV-claude-appletv-parity`) | nothing |
| B | 7 iCloud backups + Phase 0 (entitlements survive the Apple TV export) | `claude/welcome-sync` (exists, uncommitted) | iCloud portal steps (HANDOFF) |
| C | 5 Top Shelf | `claude/appletv-topshelf` from main after B is merged | App Group portal steps (below) |

A doesn't touch entitlements, so it can go to TestFlight whether or not the portal steps are done.
C is the risky one (a second Xcode target, made without a Mac): its own branch so it can't hold up
A or B. One TestFlight build can carry A + B: branch `claude/tvos-testflight-<N>` from main with both
merged, like 952 / 954 / 962. Still unmerged from earlier: `claude/appletv-search-focus` 10e5528 (the
text-field fix, TestFlight 962 only): ask the owner whether it rides along.

Build number: higher than every number in HANDOFF.md and every `VesperTV-test-*.apk` (was > 964 on
2026-11-23).

---

## Point 1. Match frame rate (step A)

**Now:** `DisplayMatch` (`lib/services/display_match.dart`) is Android only (`DisplayModes.kt`,
channel `vespertv/display`). Settings shows "Frame rate & resolution" only on Android
(`settings_catalog.dart` ~line 892). The Apple TV plays everything at its menu rate (usually
60 Hz): judder on 50 Hz channels and 24 fps films.

**tvOS API (AVKit):** `UIWindow.avDisplayManager` -> `AVDisplayManager`:
- `preferredDisplayCriteria: AVDisplayCriteria?` (set = ask for a mode, nil = the TV's own mode back)
- `isDisplayCriteriaMatchingEnabled` = the viewer's Settings > Video and Audio > Match Content >
  Match Frame Rate / Dynamic Range switches. Off: setting criteria does nothing.
- `isDisplayModeSwitchInProgress`, notifications `AVDisplayManagerModeSwitchStart` / `End`.
- Public initializer: `AVDisplayCriteria(refreshRate: Float, formatDescription: CMFormatDescription)`,
  **tvOS 17+**. Deployment target is 15: guard with `if #available(tvOS 17.0, *)`, older = no match.
  Do NOT use the private `initWithRefreshRate:videoDynamicRange:` (App Store build).

**Native** (`tvos/Runner/AppDelegate.swift`, new class `VesperDisplay`, registered next to
`VesperMenu.register`; channel name `vespertv/display` like Android):
- `match {fps: Double, width: Int, height: Int}` -> on the main thread: tvOS < 17 -> `"unsupported"`;
  no window / manager -> `"unsupported"`; `!isDisplayCriteriaMatchingEnabled` -> `"off"`; else build an
  **SDR** format description (`CMVideoFormatDescriptionCreate`, `kCMVideoCodecType_H264`, extensions
  `kCVImageBufferColorPrimariesKey` = ITU_R_709_2, `kCVImageBufferTransferFunctionKey` = ITU_R_709_2,
  `kCVImageBufferYCbCrMatrixKey` = ITU_R_709_2), set
  `preferredDisplayCriteria = AVDisplayCriteria(refreshRate: Float(fps), formatDescription: desc)`,
  answer `"asked <fps>"`.
- `reset` -> `preferredDisplayCriteria = nil`.
- `status` -> `{supported, enabled, switching}` for the Send log and Settings' help line.
- Window: the key window of the connected `UIWindowScene` (there is a `SceneDelegate.swift`).

**Dart** (new `lib/services/apple_tv_display.dart`, class `AppleTvDisplayMatch`; keep `DisplayMatch`
Android-only, its API takes a `VideoPlayerHdrController`):
- `start(StorageService, Player, bool Function() isCurrent)`: only when `isAppleTv` and
  `storage.getMatchFrameRate()`. Poll every 150 ms for up to 6 s (same shape as Android's loop):
  `container-fps` through `(player.platform as NativePlayer).getProperty` (see
  `widgets/desktop_quality_badges.dart` for the reading pattern); if it is missing or not near a
  standard rate, `estimated-vf-fps` once it has run ~1.5 s. Snap to 23.976 / 24 / 25 / 29.97 / 30 /
  50 / 59.94 / 60 (within 0.5), else don't match. Apply "Only switch between 50 and 60 Hz"
  (`getMatch5060Only`) with the same rule as `DisplayModes.kt`: read it and mirror it.
- `reset()`.
- Log like Android: `debugPrint('DisplayMatch: video WxH F fps after N ms -> <answer>')`.

**Call sites** (`lib/screens/desktop_player_screen.dart`): after each open / zap of the full-screen
player (`_openMedia` and the live zap path; `isCurrent` = same channel id and still mounted).
Reset rule: **keep the mode while a main player plays**, or Back to the guide would black out the TV
for 1-2 s every time. Reset when (a) the full-screen player closes without handing its channel to
`DesktopMiniPlayer`, (b) the mini player is cleared / stopped, (c) the setting is switched off
(`AppPreferences.setMatchFrameRate`, beside the existing `DisplayMatch.reset()` calls). tvOS gives
the TV its own mode back by itself when the app leaves the screen. v1: no match from Multiview
(Android does rate-only from the screen with the sound: optional later) or trailers.

**Settings** (`settings_catalog.dart`): show the section on Apple TV too with only **Match frame
rate** and **Only switch between 50 and 60 Hz** (no Match resolution: tvOS has no such thing). Apple
TV needs its own help text (never name Android there), 7 languages, something like: "Switches the TV
to the video's frame rate for smooth motion. Also turn on Match Frame Rate in the Apple TV's
Settings > Video and Audio > Match Content. The screen goes black for a second or two while the TV
switches." **Default on for Apple TV** (`getMatchFrameRate()`: unset = `isAppleTv`; Android stays
off): Apple's own switch is off by default and is the real master, so a viewer who turned that on
expects apps to follow. The key is device-only already.

**Tests:** unit test for the snap / 50-60 rule and the polling with a fake property reader
(`test/apple_tv_display_test.dart`); a settings test that the section shows on Apple TV without
Match resolution. Swift is only compiled by CI (`tvos-build.yml`).

**Box check:** Match Frame Rate on in tvOS; a 50 fps channel -> TV info shows 50 Hz; a 24 fps film ->
24 Hz (or stays with the 50/60 switch on); Back to the guide -> no blackout; leave the player with
nothing playing -> back to the menu rate; Send log has the `DisplayMatch:` line. Watch for: does
Flutter's own drawing stay smooth at 50 / 24 Hz (the flutter-tvos engine's frame timer in a new
mode is untested).

## Point 2. Picture modes: already there (verify only)

See the correction above. Box check: options row > Fit / Stretched / Crop / zooms cycles and the
name pill shows. If a tester says it's missing, look at why the tile is hidden for them, don't
re-add it.

## Point 3. Bigger buffer for big movies (step A)

**Now:** `newDesktopPlayer(bigCache:)` in `lib/services/desktop_stream_setup.dart`:
`final big = bigCache && !Platform.isIOS && !Platform.isAndroid;` so Apple TV gets media_kit's
32 MiB read-ahead like an iPhone: 3-6 s of a 40-80 Mbit/s 4K remux. Computers get
`kDesktopMainCacheBytes` (256 MiB).

**Change:** Apple TV is `Platform.isIOS` too, so split it: `isAppleTv` gets a new
`kAppleTvMainCacheBytes = 128 * 1024 * 1024` (Apple TV 4K: 3 GB (2021) / 4 GB (2022) of memory, but
tvOS kills apps that take too much, so half the computers' size), back buffer stays 32 MiB, and keep
`logLevel: MPVLogLevel.warn` in the same `PlayerConfiguration`. Full screen + mini player only (the
existing `bigCache` callers); Multiview tiles and trailers unchanged. Check
`lib/services/device_memory_service.dart` (it already knows Apple TV): if it reports RAM, use 128
only at >= 3 GB.

**Tests:** existing desktop-player tests still pass; nothing new worth faking.

**Box check:** a 50 GB+ 4K remux from a media server for 15 min on Wi-Fi: fewer stalls, and the app
is not killed (a kill shows as the app restarting from the splash). If it is killed: 64 MiB.

## Point 4. Surround sound (step A = find out; fix depends on the answer)

**Now:** Settings > Playback > Audio > "Surround passthrough (Dolby Atmos)" shows on Apple TV
(`usesMediaKit`) and sets mpv's `audio-spdif` (`lib/services/desktop_audio.dart`). Nobody has
checked what the Apple TV's audio output does with it, or whether 5.1 arrives as 5.1.
`tvos/Runner/AppDelegate.swift` sets no `AVAudioSession` options: mpv's audio output does its own.

**Step 1, read:** find the mpv version inside MPVKit 1.0.0 (`tools/tvos/build_mpv_framework.sh`) and
read that tag's `audio/out/ao_audiounit.m` and `audio/out/ao_avfoundation.m`: which one is the
default on tvOS, does it call `setPreferredOutputNumberOfChannels`, does it accept spdif (compressed)
formats.

**Step 2, diagnostics (ship in the same TestFlight):** add `current-ao`,
`audio-params/channel-count`, `audio-out-params/channel-count`, `audio-out-params/format`,
`audio-codec-name` to the Stream info card's property list
(`lib/widgets/desktop_data_pool_card.dart`) and one Send-log line per stream on Apple TV
(`AppleTvAudio: ao=… in=6ch eac3 out=…ch …`).

**Step 3, act on what step 1 says:**
- Output is stereo for a 5.1 source: in `tvos/Runner/AppDelegate.swift` at launch set the session to
  `.playback` / `.moviePlayback`, `setSupportsMultichannelContent(true)` (tvOS 15+) and
  `setPreferredOutputNumberOfChannels(min(maximumOutputNumberOfChannels, 8))`; and / or mpv
  `audio-channels=auto` on Apple TV in `configureDesktopStreamPlayer`.
- The audio output can't take spdif: `audio-spdif` then means silence or a failed audio open. Hide
  the switch on Apple TV (`settings_catalog.dart`) and make `DesktopAudio.applyTo` never set
  `audio-spdif` when `isAppleTv` (don't rewrite the saved value: it may come from a Transfer).
- It can (some builds have an AVFoundation output): try `ao=avfoundation` on Apple TV behind the
  switch and ask a tester with an Atmos soundbar.

Expectation to give the owner honestly: 5.1 as PCM should be reachable; **Dolby Atmos probably
isn't** with libmpv (Apple passes Atmos only from its own player pipeline).

**Box check:** a 5.1 film on a receiver that shows the incoming format: "Multichannel PCM 5.1" (good)
or "PCM 2.0" (bad); the Send-log line; passthrough on and off.

## Point 6. Options row order: hold OK to move a tile (step A)

**Now:** Android's row wraps its tiles in `ReorderableOptionTiles`
(`lib/widgets/player_options_order.dart`, used by `PlayerControls._buildOptionsRow`, ids saved per
viewer in `vesper_player_options_order`, never renamed). Apple TV's `_tvOptionsRow` hands
`PlayerOptionsPill` a plain list. Transparency is already shared (`PlayerOptionsPill` reads
`playerOptionsTransparency`).

**Change** (`lib/screens/desktop_player_screen.dart`):
- `tiles: [ReorderableOptionTiles(active: _tvOptions, onActivity: _armTvBarIdle, tiles: [(id, widget), …])]`
  with **the same ids as Android** so an order saved on a box means the same on Apple TV (it goes
  with Transfer / sync). Copy them from `_actionTiles` in `lib/widgets/player_controls.dart`
  (`recall`, `start_over`, `reload`, `audio`, `subtitles`, `audio_sync`, the linked-channel tile's
  id, `multiview`) and the `PlayerOption(id: …)` list in `lib/screens/player_screen.dart`
  (`channels`, `live_sources`, `stream_info`, `sources`, `picture`, `search`). Android's `buffer`
  tile has no Apple TV counterpart: leave it out.
- Back: in the player's back handler, before closing the row:
  `if (_tvOptions && PlayerOptionsOrder.isMoving) { PlayerOptionsOrder.endMove(); return; }`
  (Android: `player_screen.dart` ~line 1860).
- Holding OK works on Apple TV since TestFlight 952 (`held_ok_repeat.dart`).

**Tests:** the existing `ReorderableOptionTiles` tests cover the widget; the desktop player has no
widget test (media_kit needs libmpv), so add the hold + move to the CI tour
(`lib/services/ci_tour.dart`) if it can reach the row.

**Box check:** hold OK on a tile, Left / Right moves it, OK or Menu ends, order is kept next launch.

---

## Phase 0. Entitlements must survive the Apple TV export (step B, before 7 and 5)

**Problem:** `tvos-build.yml` archives with `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`
(automatic signing wanted a registered device for a development profile) and lets
`xcodebuild -exportArchive` sign for App Store Connect. Entitlements live in the code signature: an
unsigned archive has none, so the export most likely signs with the profile's bare minimum and
iCloud (point 7) and the App Group (point 5) silently don't exist in the uploaded build. The app
doesn't crash (`VesperICloud.entitled` guard) but says "iCloud backups aren't available in this
build yet." BallerMC's request was for an Apple TV: this is what makes it work there.

**Try first (small):** archive ad-hoc signed so the entitlements file is embedded, then export as
now. Replace the two `CODE_SIGNING_*=NO` settings with
`CODE_SIGN_IDENTITY=- AD_HOC_CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER= DEVELOPMENT_TEAM=`.
Pods must still build (they need no profile with ad-hoc signing).

**Verify in CI, never by hoping:** after the archive,
`codesign -d --entitlements :- "$ARCHIVE/Products/Applications/Runner.app"` must print
`com.apple.developer.icloud-services`; fail the step otherwise. To see what the EXPORT signed with,
switch `tvos/ExportOptions.plist` to `destination` = `export`, run the same `codesign -d` on the
exported `.ipa`'s app, then upload with `xcrun altool --upload-app -t tvos` and the same API key.

**Fallback (bigger):** manual signing. Create an App Store provisioning profile per bundle id through
the App Store Connect API (the workflow already has the key and the distribution certificate in a
temporary keychain), install it, and set `CODE_SIGN_STYLE=Manual`, `CODE_SIGN_IDENTITY=Apple
Distribution`, `PROVISIONING_PROFILE_SPECIFIER` on the Runner target only (a small `xcodeproj` Ruby
script in CI: command-line build settings would hit the Pods targets too).

The iPhone workflow (`ios-build.yml`) signs its archive normally and needs none of this.

## Point 7. Backup & restore through iCloud (step B)

Built on `claude/welcome-sync` (worktree `C:\Users\aarse\VesperTV-claude-welcomesync`, uncommitted):
"Also save to iCloud" + "Restore from iCloud" on iPhone / iPad / Apple TV, first-launch "From another
device". Design and files: that worktree's `dev-notes/icloud-backups.md`.

Left to do:
1. **Owner:** the 4 Apple portal + CloudKit steps at the top of HANDOFF.md.
2. Phase 0 above, on this branch (it adds `tvos/Runner/Runner.entitlements`).
3. When the owner says so: commit, merge with main, analyze + tests, push, run `ios-build.yml` and
   `tvos-build.yml` with TestFlight.

**Box check (Apple TV):** Settings > Backup & devices > Backup & restore > Restore from iCloud must
NOT say "aren't available in this build yet"; turn on Also save to iCloud, delete the app,
reinstall, first launch > From another device > Restore from iCloud > the Apple TV's own backup.

## Point 5. Top Shelf rows (step C)

**What it is:** when VesperTV sits in the Apple TV home screen's top row, the area above the icons
shows what the app publishes: tvOS's version of Android's Watch Next / Favourite channels launcher
rows (`lib/services/launcher_channels.dart`, `LauncherChannels.kt`, channel `vespertv/launcher`,
dev-notes/launcher-channels.md).

**Pieces:**
1. **Dart:** `LauncherChannels._supported` is `Platform.isAndroid && isTelevision`: add Apple TV.
   The payload (`publish`: `watchNext` + `channels[]`, each card `toMap()`: key, kind, type, title,
   image, aspect, position, duration) and the link protocol (`hasLink`, `takeLink`, native -> Dart
   `link`, key in the link's `k` query parameter, opened by `screens/launcher_open.dart`) stay as
   they are. **No "Live now in Sports" row on Apple TV in v1:** Android re-sends it every 3 minutes
   with the app closed; tvOS can't run our Dart code closed, so scores would go stale. Leave the
   `live` channel out there and hide its Settings switch.
   Settings > Interface > "Show on the TV home screen" (`settings_catalog.dart` ~line 538): show on
   Apple TV with its own wording ("Top Shelf", "when VesperTV is in the top row of the Apple TV's
   home screen"; never Projectivy / Android), 7 languages.
2. **Native in the app** (`tvos/Runner/AppDelegate.swift`, class `VesperTopShelf` on
   `vespertv/launcher`): `publish` trims the payload (drop descriptions; at most ~40 cards) and
   writes it as JSON to `UserDefaults(suiteName: "group.app.vespertv.player")` (tvOS allows little
   in defaults: keep it well under 100 KB), then `TVTopShelfContentProvider.topShelfContentDidChange()`;
   answers a small report map like Android (`{watchNext: n, channels: n}`) for the Send log.
   `liveAlive` = no-op. Links: add URL scheme `vespertv` to `tvos/Runner/Info.plist`
   (`CFBundleURLTypes`; there is none today), take `vespertv://launcher?k=<key>` in the scene
   delegate (`scene(_:openURLContexts:)` and the launch `connectionOptions.urlContexts`), keep it
   for `hasLink` / `takeLink`, send `link`.
3. **The extension** (new target `TopShelf`, bundle id `app.vespertv.player.TopShelf`, extension
   point `com.apple.tv-top-shelf`, principal class a `TVTopShelfContentProvider`): 
   `loadTopShelfContent` reads the JSON and answers `TVTopShelfSectionedContent`: one
   `TVTopShelfItemCollection` per row ("Continue watching" / Watch list from `watchNext`, "Favourite
   channels"), each `TVTopShelfSectionedItem` with `identifier` = key, `title`, `imageShape`
   (`.poster` for `aspect: poster`, else `.hdtv`), `setImageURL` (http(s) only: the Dart side's
   `safeImage` already filters), `playbackProgress` from position / duration, `displayAction` and
   `playAction` = `TVTopShelfAction(url:)` with the link above. Nothing published = `nil` content
   (tvOS then shows the static Top Shelf image that already ships).
4. **Entitlements:** `com.apple.security.application-groups` = `group.app.vespertv.player` in
   `tvos/Runner/Runner.entitlements` (from step B) and a new `tvos/TopShelf/TopShelf.entitlements`.
   Needs Phase 0, for both the app and the extension.
5. **The Xcode target, without a Mac:** don't hand-edit `project.pbxproj`. Write
   `tools/tvos/add_topshelf_target.rb` with the `xcodeproj` gem (it comes with CocoaPods on the
   GitHub macOS runners): idempotent; adds the target (`com.apple.product-type.tv-app-extension`),
   its Swift file, Info.plist and entitlements, tvOS 15 deployment target, the same version / build
   as the app (base its configs on the Flutter xcconfig so `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`
   resolve; an extension whose version differs from the app is rejected on upload), an "Embed
   Foundation Extensions" copy phase + target dependency on Runner. Run it in `tvos-build.yml` right
   after "Generate tvos/ when missing". Once a CI run is green, download the changed `project.pbxproj`
   from the run's artifacts and commit it, so the project in git is the real one.
   Unknown: whether `flutter-tvos build` copes with a second target in the Runner scheme. The
   simulator build in CI answers that before any signing is involved.

**Owner steps for C (browser, developer.apple.com > Certificates, IDs & Profiles > Identifiers):**
1. **+** > App Groups > `group.app.vespertv.player` ("VesperTV Top Shelf").
2. App ID `app.vespertv.player` > tick **App Groups** > Configure > tick the group > Save.
3. **+** > App IDs > App > bundle id `app.vespertv.player.TopShelf` (description "VesperTV Top
   Shelf") > tick **App Groups** > Configure > tick the group > Register.

**Tests:** Dart: `launcher_channels` tests with the platform switch (payload for Apple TV has no live
row). Swift: CI compile + simulator. The extension can be exercised in the simulator by putting the
app in the top row; a screenshot step is optional.

**Box check:** move VesperTV to the top row, watch part of a film, press TV / Home: the row shows
it with a progress bar; OK on it opens the app on that title; turning the Settings switch off empties
the row.

---

## Not in this plan (said to the owner on 2026-11-23)

- Not possible on tvOS: recording / downloads / network folder (apps are suspended off screen and
  may only keep purgeable files), alerts with the app closed (no notification banners on tvOS),
  YouTube trailers (no web view), the Siri button for Vesper.
- Android box workarounds with no Apple TV counterpart: learned remote buttons, Ask before exiting,
  native video surface, Multiview frame saver / 720p copies.
- Hidden by App Store rules on purpose (`appStoreBuild`): add-ons, Debrid, Discord, Support, Check
  for Updates.
- Real HDR / Dolby Vision output, and Atmos (see points 1 and 4): own projects, only if testers ask.
- Frame match from Multiview, DRM (ClearKey), updates with the app closed (BGAppRefreshTask): later.

## Done means

- `flutter analyze` = 16, `flutter test` green, `dart format` only on edited files, generated
  linux / macos / windows plugin files reverted before a commit.
- `tvos-build.yml` green (simulator build, UI tour, player smoke test, release compile), then a
  TestFlight run when the owner asks.
- `dev-notes/apple-tv.md` gets a section per shipped point; HANDOFF.md top block and the memory file
  `project_vespertv_appletv_parity.md` updated; the report to the owner ends with
  "→ Apple TV TestFlight".

## Built (2026-11-23, Claude, `claude/appletv-parity`, uncommitted)

One branch for A + Phase 0 + C (not three): the Apple TV is off TestFlight until the owner has a test
box, so nothing waits on one part. Analyze 16; `test/apple_tv_display_test.dart` (11),
`test/apple_tv_top_shelf_test.dart` (3). **No Swift was compiled** (no Mac): the first
`tvos-build.yml` run checks it.

- **1 Frame rate:** `lib/services/apple_tv_display.dart` (`AppleTvDisplayMatch`: `detect`, `snap`,
  `refreshFor`, `start`, `reset` with a 3 s delay, `logAudio`), `VesperDisplay` in
  `tvos/Runner/AppDelegate.swift` (`vespertv/display`: match / reset / status, SDR BT.709 format
  description, tvOS 17+). Called from `DesktopPlayerScreen._matchDisplay` (every `_openMedia`, plus a
  taken preview player or a catch-up start); reset in its `dispose` unless handed to the preview, in
  `DesktopMiniPlayer.clear`, and at once when the setting goes off. Default on for Apple TV
  (`StorageService.getMatchFrameRate`). Settings > Playback > Frame rate (Match frame rate + Only 50 /
  60 Hz; no Match resolution). Send log: `DisplayMatch: video WxH F fps after N ms -> R Hz: <answer>`
  (answer = `asked …`, `off in the Apple TV's Settings (Match Content)`, `unsupported (tvOS 16 or
  older)`).
- **2 Picture modes:** already there, nothing changed.
- **3 Buffer:** `kAppleTvMainCacheBytes` = 128 MiB in `newDesktopPlayer(bigCache: true)` on Apple
  TV (full screen + preview), back buffer 32 MiB, warn-level mpv log kept.
- **4 Surround:** mpv 0.41 (MPVKit 1.0.0) on tvOS has `audiounit` (default) and `avfoundation`. Both
  ask AVAudioSession for the stream's channel count (`setPreferredOutputNumberOfChannels`), so 5.1
  should leave as 5.1 PCM; `avfoundation` refuses SPDIF and `audiounit` forces stereo for it. So:
  the passthrough switch is hidden on Apple TV and `DesktopAudio.applyTo` never sets `audio-spdif`
  there. Stream info gets a "Sound out" row (`audio-out-params/channel-count` + `current-ao`); Send
  log `AppleTvAudio: ao=… in=6ch eac3 out=6ch floatp` once per stream. No Atmos.
- **6 Tile order:** `_tvOptionsRow` wraps its tiles in `ReorderableOptionTiles` with Android's ids;
  Back during a move ends it.
- **Phase 0:** `tvos-build.yml` signs the archive ad hoc with `tvos/Runner/Runner.entitlements` and
  `tvos/TopShelf/TopShelf.entitlements` (frameworks, extension, app), checks every key is in the
  signature, then exports once locally (`destination` = export) and checks the exported app and
  extension the same way before the real upload export. A missing key fails the run.
- **5 Top Shelf:** `LauncherChannels` runs on Apple TV (`_supported`), sends `topShelf(...)` rows
  (Continue Watching = in progress + next episodes, New episodes, Watch list, Favourite channels; no
  live games row), publishes 300 ms after the app hides (2 s on Android). `VesperTopShelf` in
  AppDelegate.swift writes them to the App Group defaults (`vesper_top_shelf`, at most 40 items) and
  receives `vespertv://launcher?k=` links through `registrar.addSceneDelegate` (Flutter's plugin
  scene hook: no SceneDelegate override). Extension: `tvos/TopShelf/` (ContentProvider.swift,
  Info.plist, TopShelf.entitlements, TopShelf.xcconfig), added to the project in CI by
  `tools/tvos/add_topshelf_target.rb` (xcodeproj gem; embed phase right after Resources). Settings >
  Interface > Tabs > Show on the TV home screen now shows on Apple TV with its own help text.
- **Entitlements file:** `tvos/Runner/Runner.entitlements` (iCloud + App Group) is byte-identical on
  this branch and `claude/welcome-sync`, and both add the same three `CODE_SIGN_ENTITLEMENTS` lines,
  so the branches merge without a conflict. A signed Apple TV build from either needs BOTH portal
  step sets (iCloud: HANDOFF; App Group: "Owner steps for C" above).

**Unverified, watch on the first CI run / test box:** Swift compile of all three classes and the
extension; `xcodeproj` gem on the runner; whether `flutter-tvos build` keeps and builds the second
target (simulator step prints `TopShelf.appex in the build: …`); the ad-hoc archive signing +
export; whether a cold start from a Top Shelf item reaches `scene(_:willConnectTo:options:)` before
our scene delegate registers (else the app just opens normally); Flutter frames at 50 / 24 Hz; the
128 MiB buffer under tvOS memory limits; 5.1 on a real receiver.
