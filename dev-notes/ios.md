# iPhone / iPad build (first pass, 2026-11-07)

Branch `claude/appstore-build`. Goal: a first VesperTV on the owner's old iPhone (then an
iPhone 16), built in the cloud because this PC has no Mac. Not App Store-ready yet.

## Build

`.github/workflows/ios-build.yml` (macos-latest, Flutter 3.47.9) runs
`flutter build ios --release --no-codesign` and uploads **VesperTV-ios** with
`VesperTV-<version>-<build>-ios-unsigned.ipa`. It runs on a push to `main` or
`claude/appstore-build`, or by hand (Actions > iOS build > Run workflow). Release only: a
debug build can't start without Xcode attached.

## TestFlight (paid account, 2026-11-10)

The owner joined the Apple Developer Program (account holder). Bundle ID **`app.vespertv.player`**
(registered as an explicit App ID, no capabilities); the project uses it and is **iPhone + iPad**
(`TARGETED_DEVICE_FAMILY = "1,2"` since 2026-11-13: an iPad tester saw the iPhone-only build in
iPadOS's iPhone window, whatever the Apple ID. App Store review will need iPad screenshots; the
iPad gets the wide touch layout, not box-tested).
`com.nox.noxIptv.9947N9` in Identifiers is Sideloadly's own, ignore it. A sideloaded build with
the old id is a separate app on the phone (its data doesn't carry over).

- **Secrets** (GitHub > Settings > Secrets and variables > Actions): `APP_STORE_CONNECT_KEY_ID`,
  `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY` (the whole text of the `.p8`,
  BEGIN/END lines included) and `APPLE_TEAM_ID` (developer.apple.com > Membership details). The key:
  App Store Connect > Users and Access > Integrations > App Store Connect API > Team Keys, **Admin**
  access (Xcode creates the distribution certificate and profile through it), downloadable once.
- **Run:** Actions > iOS build > Run workflow, branch `claude/appstore-build`, tick
  *Sign and upload to TestFlight*. `flutter build ios --config-only`, then `xcodebuild archive` +
  `-exportArchive` with `ios/ExportOptions.plist` (`app-store-connect`, `destination upload`) and
  `-allowProvisioningUpdates` + the API key. No Mac, no fastlane.
- **Build number:** pubspec's `+N`; App Store Connect refuses a number it already has for that
  version, so bump it like an Android build.
- **After the upload** (processing takes ~5-30 min): TestFlight shows "Missing Compliance" until the
  encryption question is answered in App Store Connect (the app uses HTTPS and encrypts Sync /
  Transfer data itself). Then add internal testers (App Store Connect users, up to 100, no review);
  they install from the TestFlight app. Builds expire after 90 days.
- First upload 2026-11-11: 1.0.63 (701), run 43036962320. `flutter build ios --config-only` needs
  `--no-codesign` (it looked for a local certificate; Xcode signs through the API key).

## Up to par with Android (2026-11-11, main 1.0.64 merged)

- Vesper AI drives the iPhone player (`usesMediaKit`, not `isDesktop`, in the AI tools).
- **Backup & restore:** Documents/VesperTV, visible in Files (Info.plist `UIFileSharingEnabled` +
  `LSSupportsOpeningDocumentsInPlace`); Restore from a file = Files picker (`file_selector`). No
  Import from storage (no USB).
- **Catch-up:** the Windows `DesktopCatchup` already ran on iOS. Added: the Catch-up group
  (`_showCatchupGroup`, iOS only on media_kit), a **Channel schedule** button in the touch player
  (`ChannelSchedulePanel`: past = replay, on now = live), and `ClampingScrollPhysics` on the
  Timeline grid: iOS bouncing sends no OverscrollNotification, so dragging left never reached the past.
- **Recording: not on iOS** (owner, 2026-11-11: iOS suspends apps off screen; the idea is for a
  future Apple TV build, and Flutter has no tvOS).
- Not done: downloads (Windows' `DesktopRecorder` is Windows paths/SMB; iOS would only download
  while open) and notifications with the app closed.

## Main +738 merged (2026-11-12, after TestFlight 710)

Owner: build 710 lacked the Settings revamp and the rest of Android since 1.0.64. Merged local main
(1.0.65 +732 release + the unpushed +733..+738 work: Interface size, Polish, Remote buttons, new logo).

- **Settings revamp:** `general_settings_screen.dart` and the old menu are gone; the iOS rules now
  live in `settings_catalog.dart`: no Debrid accounts / Check for Updates rows (`appStoreBuild`),
  the mpv player's sections (Audio & subtitles, TV Shows, Live TV) on `usesMediaKit`, no "Hide the
  picture behind other pages" / Multiview tip, Data pool and resume-pill texts as on a computer,
  Sports Mode clears the mini player. The Catch-up group switch stays (the group exists on iOS).
- **Picture modes on the iPhone player:** the touch top bar has Android's picture button (Fit,
  Stretched, Crop, Fit height, Fit width, Slight zoom, Cinema zoom; same `vesper_video_fit` setting)
  + the name pill. `_video` sizes the `Video` box with `VideoFit.sizeIn` from the controller's
  `rect` (fill inside it) and draws the subtitles in a separate screen-level `SubtitleView`, so a crop
  or zoom never pushes them off the bottom. Windows uses the same code with the default Fit.
- Media Hub folder pages (`hub_folder_screen.dart`, collections): back arrow on iPhone
  (`needsBackArrow`), no first-card focus on touch.
- Main committed `desktop_multiview_screen.dart` / `desktop_player_screen.dart` with CRLF in the
  blob (2f6d12a), so every merge showed them as whole-file conflicts: the multiview blob here is
  main's CRLF one + the iOS lines (clean next time); the player stays LF (main's 3 lines applied).
- iOS app icons come from main's new gold logo (RGB, no alpha: App Store-safe).

## Install from Windows (free Apple ID)

1. Install iTunes and iCloud from Apple's site (not the Microsoft Store versions), then
   Sideloadly (sideloadly.io).
2. Plug the iPhone in by USB, unlock it, tap Trust.
3. Sideloadly: drop the `.ipa`, enter the Apple ID, Start. (The free account gets a
   7-day profile; at most 3 sideloaded apps per device.)
4. iPhone: Settings > Privacy & Security > Developer Mode > On (restarts the phone), then
   Settings > General > VPN & Device Management > trust the Apple ID.
5. After 7 days the app won't open: run Sideloadly again with the same `.ipa` (data stays).

## What iOS uses

- **Player:** media_kit (mpv), the Windows/macOS stack, through `usesMediaKit` /
  `usesMediaKitTarget` (`utils/desktop_platform.dart`): `DesktopPlayerScreen`,
  `DesktopMiniPlayer` (guide preview), `DesktopMultiviewScreen`, desktop trailers. Apple's
  AVPlayer (`video_player`'s iOS backend) can't open raw `.ts` live streams or MKV files.
  `media_kit_libs_ios_video` brings libmpv. `isDesktop` still means "a computer" (window,
  mouse, Escape key, poster sizes); iOS keeps the touch layout.
- **Back arrows:** `needsBackArrow` (computer or iPhone) shows the on-screen back arrows the
  Windows build has (Media Hub, Home, Sports pages): an iPhone has no Back button.
- **Audio session:** `.playback` / `.moviePlayback` in `AppDelegate.swift` (sound with the
  silent switch on) + `UIBackgroundModes audio`.
- **Info.plist:** `NSAllowsArbitraryLoads` (plain-HTTP IPTV/add-ons/home servers),
  `NSLocalNetworkUsageDescription` (own media server, Wi-Fi transfer / From phone).
- Bundle id `com.nox.noxIptv` (Flutter default, never shipped anywhere), deployment target 15.

## App Store rules (`utils/app_store.dart`, `appStoreBuild`)

On every iOS build, or an Android build with `--dart-define=VESPER_APPSTORE=true` to
preview it on a box:

- No Settings > Media Hub > **Debrid accounts**; `ArchiveReadyWatch` gets no `DebridApi`, so
  the Ready tag uses its other check (the same stream link serving the real file).
  Debrid add-ons the user adds still play: they resolve their links themselves.
- The playback error "Check your source or debrid account…" drops "or debrid account".
- No **Check for Updates** row and no launch update check (Apple installs updates).
- iOS only: no sidebar **Exit VesperTV** row (iOS apps never quit themselves).

## Not done / expect on the first test

- Android-only features stay off on iOS (they check `Platform.isAndroid`): recording, native
  video surface, PiP, Match frame rate, Backup & restore, phone notifications, voice input.
  Some Android channel calls may log `MissingPluginException` in Send log: harmless, list them.
- Full-screen player: `DesktopPlayerScreen` with a touch layout on iOS (`_touch` =
  `isIosTarget`, 2026-11-09, after the owner's iPhone 8 showed the PC bar squeezed into a
  portrait phone): landscape on open on a phone (also with the rotation lock on) + Rotate,
  top bar back / title / Sources / Rotate, big play/pause and +-10 s in the middle, seek bar
  (seeks on release) + badges + buttons at the bottom, hides after 4 s, no volume slider.
  Computers keep the mouse bar. Not device-tested yet.
- Background (Home / lock screen): `_IosBackgroundVideo` in `desktop_stream_setup.dart` turns every
  open player's video track off on hidden/paused and gives it back on resumed. media_kit draws with
  OpenGL ES (forbidden in the background): before this the sound stopped too and a 4K remux
  stuttered after coming back (decoder dropped).
- **Keeps playing off screen (2026-11-09):** media_kit's `Video` widget pauses its player on
  AppLifecycleState.paused and never resumes (movies stopped on Home; live looked fine). Every player
  view passes `pauseUponEnteringBackgroundMode: mediaKitPausesInBackground` (false on iOS); trailers
  keep the default.
- **Voice commands (2026-11-09):** `VesperVoice` in AppDelegate.swift speaks Android's `vespertv/voice`
  protocol (SFSpeechRecognizer + AVAudioEngine, AVSpeechSynthesizer for spoken replies); Dart
  `VoiceInput` uses it on iOS too, so the mic opens straight to listening like Android. Stops 1.5 s
  after the last new words (6 s if silent, 15 s max); audio session playAndRecord while listening,
  back to playback/moviePlayback after. Info.plist NSMicrophone/NSSpeechRecognition texts. The Vesper
  panel adds the keyboard inset (typed text was hidden under the keyboard).
- **Picture-in-picture (owner chose the Apple-player handoff, 2026-11-09):** PiP button in the touch
  top bar. `_startPip` stops mpv (one provider connection), `IosPip.start` (`vespertv/pip`,
  `VesperPip` in `AppDelegate.swift`: AVPlayer on a 2x2 layer + AVPictureInPictureController)
  opens the same link and floats it. Restore button = mpv again at AVPlayer's position; X = stop
  watching (progress saved, screen closes); "Watch here" on the player = restore from the app.
  `IosPip.linkFor`: Xtream live `.ts` / short links -> `/live/u/p/id.m3u8`, other raw TS and
  MKV/AVI/WebM/FLV/WMV refused (message), MP4/unknown tried (failure = mpv back). Not automatic on
  Home (needs the AVPlayer already playing; the provider allows one connection). Full mpv PiP
  (frames into AVSampleBufferDisplayLayer) rejected: GPU is off-limits in the background, CPU
  rendering 4K on an iPhone 8 can't keep up. Not device-tested yet.
- Landscape phone guide (shared Dart, Android phones too): `_shortScreen` / `_isShortPhoneScreen` in
  `tv_home_screen.dart` (landscape, under 500 pt, not TV/computer): 4 px vertical margins, dense
  title bar, 100 pt preview row (16:9 box), Compact guide rows. Was 1 guide row on an iPhone 8 /
  Android phone. **Cherry-pick to main** for Android phones.
- Merged main (+695) on 2026-11-09: brings the desktop live reconnect fixes (`5b360ce`
  30 s network timeout + error check, `3e7b392`); `cache-on-disk no` now on iOS too (sandbox).
  Main's new player checks (Home mini player, Preview on highlight, Vesper AI media_hub /
  settings tools) use `usesMediaKit(Target)`; layout-only `isDesktop` checks stay.
- `kDesktopStreamUserAgent` still says "VesperTV Windows".
- Store listing, privacy labels, review demo content, GPL exception
  (dev-notes/apple-platforms.md on the owner's checkout) — before any App Store upload.
- Apple TV: Flutter has no tvOS support.
