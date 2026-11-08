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
- The full-screen player is the desktop one (mouse-first bar); touch works but it was laid
  out for a PC. A touch-sized bar is the likely next step.
- `kDesktopStreamUserAgent` still says "VesperTV Windows".
- Store listing, privacy labels, review demo content, GPL exception
  (dev-notes/apple-platforms.md on the owner's checkout) — before any App Store upload.
- Apple TV: Flutter has no tvOS support.
