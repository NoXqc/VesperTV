# Apple TV (tvOS)

Plan (owner's Claude Doc "VesperTV on Apple TV — plan"): (3) test build with
the community engine, (4) libmpv player on tvOS, (5) TV layout, storage,
Siri Remote, (6) TestFlight, then the App Store on the same app record as
the iPhone app. Branch `claude/tvos-test` is step 3.

## Engine

Flutter has no tvOS. [flutter-tvos](https://github.com/fluttertv/flutter-tvos)
is a CLI + prebuilt Metal-only engine; each release pins one Flutter SDK
(`v3.47.9-tvos.1.11.5` = Flutter 3.47.9, the iPhone CI's version). macOS +
Xcode only, so everything runs on the GitHub Mac runner
(`.github/workflows/tvos-build.yml`). The CLI fetches its own Flutter.

- `flutter-tvos create --org com.nox .` in this project runs Flutter's own
  create (keeps existing files) and adds `tvos/` beside `ios/`: its own
  Info.plist, AppDelegate, Podfile / SwiftPM. Never share files with `ios/`.
- Device builds must be signed with an **Apple Distribution** certificate:
  flutter-tvos signs its engine with it (ITMS-91065). Without it internal
  TestFlight works and external Beta App Review fails.
- Debug on a real Apple TV attaches over Wi-Fi (slow); the simulator is the
  fast path. Release / profile need no debugger.

## Dart side

- On tvOS `Platform.isIOS` is **true** (and `defaultTargetPlatform` is iOS);
  `Platform.operatingSystem` is `'tvos'`. `isAppleTv`
  (`utils/desktop_platform.dart`) reads `operatingSystem`, because the
  engine's own `Platform.isTvOS` doesn't exist in the stock SDK we analyse
  with. iPhone-only flags exclude it: `usesMediaKit`, `usesMediaKitTarget`,
  `isIosTarget`, `needsBackArrow`, `IosPip.available`, voice input.
- `appStoreBuild` stays true on Apple TV (same App Store rules).
- `DeviceTypeService.isTelevision()` answers true on Apple TV (no Kotlin
  channel), so the app takes the Android TV layout.
- For now Apple TV plays through the Android stack's Dart side
  (`video_player_hdr` -> `VideoPlayerPlatform`) with `video_player_tvos`
  (Apple's player: HLS and MP4, not raw .ts or MKV). Step 4 replaces it.
- A tvOS build loads only plugins with a `tvos:` entry; any other plugin
  throws `MissingPluginException` when called (the app's Kotlin channels,
  media_kit, flutter_inappwebview, file_selector). Ports in pubspec.yaml:
  shared_preferences, path_provider, sqflite, wakelock_plus,
  package_info_plus, url_launcher, video_player (`*_tvos`, fluttertv.dev).
  They declare only `tvos:`, so other platforms never load them.
- Siri Remote: swipes = arrow keys (held = repeat ~80 ms), click = Enter,
  Menu = `popRoute` (Back), Play/Pause = mediaPlayPause. Long press on
  Select is not documented: check the hold menus on a real box. Menu on the
  top screen must exit to the Apple TV Home screen (App Review).

## Player (step 4)

media_kit's iOS video code (media_kit_video `ios/Classes/plugin`: libmpv ->
OpenGL ES -> CVPixelBuffer -> FlutterTexture, plus a software path) is the
base: fork it with a `tvos:` entry. libmpv for tvOS from
[MPVKit](https://github.com/mpvkit/MPVKit) (LGPL build; media-kit's
libmpv-darwin-build has no tvOS). MPVKit says it is "only suitable for
learning": pin one release. Fallback: AetherEngine (LGPL, FFmpeg +
VideoToolbox, no libass).

## Storage (step 5)

tvOS guarantees ~500 KB of NSUserDefaults; Caches (the guide and catalog
databases, posters) can be purged. Keep logins / sources / profiles /
settings small and in prefs; treat the databases as re-downloadable.

## Test box

Apple TV 4K 2nd gen (2021) or 3rd gen (2022). Not the Apple TV HD
(4th gen, 2015): 1080p only, no HDR, reportedly no tvOS 27.
