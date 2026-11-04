# macOS desktop (prototype)

Status: prototype on the `macos-desktop-prototype` branch of a fork, not released.
It builds, starts, loads a real playlist and guide on an Apple Silicon Mac
(macOS 26, Flutter 3.47.9).

## Approach

macOS reuses the **Windows desktop stack** (media_kit/mpv, `DesktopPlayerScreen`,
`DesktopMiniPlayer`, window_manager, mouse layouts), not the Android one.

- `lib/utils/desktop_platform.dart`: `isDesktop` = Windows or macOS.
  Every `Platform.isWindows` that meant "computer" now reads `isDesktop`
  (83 sites). On Windows and Android the behaviour is unchanged: `isDesktop`
  equals the old `Platform.isWindows` on both.
- `Platform.isWindows` is kept only for what is really Windows: drive letters
  in storage import, WebView2 in `youtube_platform_view`, the sqflite FFI
  factory (macOS has native sqflite), `Documents\VesperTV` label.
- `main.dart`: `MediaKit.ensureInitialized()` also on macOS.
- `pubspec.yaml`: `media_kit_libs_macos_video`.
- Entitlements (sandbox stays on): `network.client` (streams), `network.server`
  (Wi-Fi Transfer / From phone), `files.user-selected.read-write` (M3U/backup
  files picked by the user).
- Updater: `checkForUpdate` returns null on macOS (no Mac release asset yet;
  it would otherwise offer the Windows `.zip`).

## Build

Needs CocoaPods (`brew install cocoapods`): media_kit and flutter_inappwebview
have no Swift Package Manager support on macOS. Run with `LANG=en_US.UTF-8`.

```
flutter build macos --debug
```

## Not done / to check

- Playback, Multiview, trailers (WKWebView), subtitles, Backup, Transfer:
  not yet checked by hand on the Mac.
- Mac conventions: Cmd+Q, native full screen (green button), menu bar.
- Distribution: signing + notarization (Apple Developer account), a `.dmg`
  or `.zip` asset, and teaching `app_update_service.dart` to pick it.
- Storage import on macOS lists only `/` (Windows lists drive letters);
  `/Volumes` would be the Mac equivalent.
