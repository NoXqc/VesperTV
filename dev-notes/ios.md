# iPhone / iPad build (first pass, 2026-11-07)

Branch `claude/appstore-build`. Goal: a first VesperTV on the owner's old iPhone (then an
iPhone 16), built in the cloud because this PC has no Mac. Not App Store-ready yet.

## Build

`.github/workflows/ios-build.yml` (macos-latest, Flutter 3.47.9) runs
`flutter build ios --release --no-codesign` and uploads **VesperTV-ios** with
`VesperTV-<version>-<build>-ios-unsigned.ipa`. It runs on a push to `main` or
`claude/appstore-build`, or by hand (Actions > iOS build > Run workflow). Release only: a
debug build can't start without Xcode attached.

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
