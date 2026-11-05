# macOS desktop

Status: works on an Apple Silicon Mac (macOS 26, Flutter 3.47.9). Debug and
Release builds tested: live, VOD, guide and Esc. Distributed as an
**unsigned** zip from CI, not attached to releases (see "Updater" below).

## Approach

macOS reuses the **Windows desktop stack** (media_kit/mpv,
`DesktopPlayerScreen`, `DesktopMiniPlayer`, window_manager, mouse layouts),
not the Android one.

- `lib/utils/desktop_platform.dart`:
  - `isDesktop` = Windows or macOS (dart:io). Every `Platform.isWindows`
    that meant "computer" now uses it.
  - `isDesktopTarget` is the same test on `defaultTargetPlatform`, for the
    layout checks that use the target platform so widget tests can exercise
    either layout on any host.
  - On Windows and Android, both helpers equal the old checks, so behaviour
    there is unchanged.
- `Platform.isWindows` stays only for what is really Windows: drive letters
  in storage import, WebView2 in `youtube_platform_view`, the sqflite FFI
  factory (macOS has native sqflite), the `Documents\VesperTV` label.
- `main.dart`:
  - `MediaKit.ensureInitialized()` runs on macOS too.
  - On macOS, Esc (`DismissIntent`) falls back to `Navigator.maybePop`
    (`MaterialApp.actions`). Dialogs, menus and screens with their own Esc
    handling still win.
- `pubspec.yaml`: `media_kit_libs_macos_video`. CocoaPods integration lives
  in `macos/` (Podfile, workspace). Three plugins have no Swift Package
  Manager support on macOS: media_kit_video, media_kit_libs_macos_video and
  flutter_inappwebview_macos.
- App name `VesperTV.app` (`PRODUCT_NAME`). The bundle id stays
  `com.nox.noxIptv`, because it keys the sandbox container, settings and
  Application Support (same rule as the Windows exe rename).

## Sandbox

The sandbox stays on. `Release.entitlements` grants:

- `network.client`: streams, guides, add-ons.
- `network.server`: Transfer, From phone, the playlist editor.
- `files.user-selected.read-write`: open and save panels.

`Info.plist` has `NSLocalNetworkUsageDescription` (macOS 15+ local network
privacy).

- **Backup:** regular backups live in the hidden container
  (`~/Library/Containers/com.nox.noxIptv/Data/Documents/VesperTV`), so the
  label reads "the app's own storage". macOS-only *Export a backup* uses the
  save panel, and *Restore from a file* uses the open panel.
- **Import from storage:** on macOS, *Choose a folder* uses the open panel,
  and there is no `/` root.
  - Known limit: access to the folder lasts for the session only. Relative
    paths inside an imported M3U stop resolving after a relaunch unless
    security-scoped bookmarks are added.

## Updater

`AppUpdateService.pickAsset` picks the release asset per platform:

- Android takes the `.apk`.
- Windows takes a `.zip` that is not `-macos.zip`.
- macOS takes only `-macos.zip`.

`checkForUpdate` still returns null on macOS. **Never attach a Mac zip to a
release** until most Windows installs run a build with `pickAsset`: older
Windows builds take the first `.zip` they find.

## Build

Locally: `brew install cocoapods`, then
`LANG=en_US.UTF-8 flutter build macos --release`. The output is a universal
build (arm64 + x86_64), about 46 MB zipped.

CI: `.github/workflows/macos-build.yml` runs on `macos-latest`, on push to
`main` or by hand. It uploads `VesperTV-macos.zip` and the build log as
artifacts.

The build is unsigned. Since macOS 15, right-click > Open no longer gets
past Gatekeeper: after the first blocked launch, users open System Settings >
Privacy & Security > Open Anyway (or remove the quarantine attribute).

DMG: `tools/macos_dmg/build.sh` (after the Release build) writes
`build/dmg/VesperTV-<version>-macos.dmg` with a black + gold background,
a drag-to-Applications layout and the gold volume icon.

- `make_background.py` reuses `assets/icon/gen_icon.py` and writes a 1x
  and a @2x image.
- `settings.py` is the dmgbuild layout.
- Pillow and dmgbuild go into a private venv in `build/`.
- Finder draws icon labels black in light mode and white in dark mode, so
  the icons sit on a mid-tone gold shelf that keeps both readable.

## Not done

- **Signing and notarization:** needs an Apple Developer account
  (Developer ID). The release build currently carries `get-task-allow` from
  local signing, which notarization rejects: sign with a Developer ID and
  the hardened runtime in CI.
- **A Mac release asset and updater:** once signed, and once Windows installs
  have `pickAsset`.
- **Not yet checked by hand on the Mac:** Multiview, trailers (WKWebView),
  subtitles, Transfer.
- **Mac conventions:** the menu bar items, and the native full-screen button
  behaviour versus the app's own Windowed / Full screen row.
- **iOS:** not covered. `isDesktop` mixes "uses media_kit" and "is a
  computer". An iOS port would split it; most sites are player-stack choices.
