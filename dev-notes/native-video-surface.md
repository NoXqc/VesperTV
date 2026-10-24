# Native video surface (beta)

Branch `claude/native-surface` (from main `ebb0fa5`, test builds `1.0.39+423` / `+424`). Android main player only.

## Why
- **AMD, Fire TV Cube** (AFTGAZL, Android 9 / SDK 28, Amlogic): 4K HDR10 channels look washed out.
  `LOG-CFN2FE`: `OMX.amlogic.hevc.decoder.awesome` outputs `Resolution change … to 1920x1080` /
  `videoResolution.FHD` for every 3840x2160 stream, so the HDR video plane is never used. Tunneled
  playback (`claude/tunneling-test`, +420, not released) was a side attempt. TiviMate gets HDR on that box.
- **Sam, NVIDIA Shield** (Android 11 / SDK 30): green flicker in the live preview under the guide.
  The 1.0.38 "Green flicker fix (test)" (`setZOrderMediaOverlay`) did not help. Compatibility video
  (texture) stops it but loses HDR (movies washed out).
- Common factor: the main player's SurfaceView sits inside a Flutter **platform view** (hybrid
  composition, `initSurfaceAndroidView` with a SurfaceView falls back to HC on Flutter 3.47), so
  Flutter's overlay layers and composition sit between the decoder and the display.

## How it works
- Setting: Settings > Interface > Background video > **Native video surface (beta)**
  (`AppPreferences.nativeVideoSurface`, key `vesper_native_video_surface`, device-only, off by default,
  **applies after a restart**). Old path is untouched when off.
- `MainActivity.getBackgroundMode()` (NOT getTransparencyMode: FlutterActivity derives window + render mode from it; +423 got this wrong, so the beta was effectively off) reads `flutter.vesper_native_video_surface` from
  `FlutterSharedPreferences` → `BackgroundMode.transparent` (FlutterActivity then also uses texture
  render mode and a transparent window).
- Vendored plugin `NativeVideoSurface.java` (channel `vespertv/native_surface`, plugin is now
  `ActivityAware`): one `SurfaceView` added at index 0 of `android.R.id.content` (behind Flutter).
  `attach(playerId)` → `exoPlayer.setVideoSurfaceHolder`, `setRect` (physical px, layout margins),
  `hide` (moved off screen, not GONE — GONE destroys the surface), `diagnostics`. Player dispose
  detaches first (`VideoPlayerPlugin.dispose`).
- Dart `widgets/native_video_hole.dart`: `NativeVideoSurface.active` (set once in main.dart, Android
  only); `NativeVideoHole` paints `BlendMode.clear` in its own `RepaintBoundary`; a persistent frame
  callback sends the topmost visible hole's rect + player id after every frame (holes whose
  `TickerMode` is off are skipped for geometry; covered routes retain the last native rect
  beneath Flutter through transitions. Last registered visible hole wins).
- `PlaybackService._viewTypeFor` marks controllers created while the beta is on (and Compatibility
  video off); `VideoPlayerPane` shows `NativeVideoHole` for those, `VideoPlayerHdr` otherwise.
  Multiview / texture players / Windows unchanged.

## Logs (Send log)
- Session log: `NativeSurface:` lines — beta on at launch, attach player N, hole size/position + dpr,
  and 5 s after each attach a `diagnostics` dump: decoder, input format (size, fps, codecs, colour:
  `PQ (HDR10)` / `HLG` / `SDR`, BT.2020, HDR static info), video size, surface size/format, first
  frame, dropped frames, tunneling, display mode + supported HDR types + window colour mode.
- Logcat tag `VesperNativeSurface`: startup state (+ device/SDK), surface created/changed/destroyed,
  decoder init, every format/size change, first frame, drops, player errors.
- Compare with the platform-view path: Amlogic `MediaCodecLogger … Resolution change … to WxH` and
  `videoResolution.FHD/UHD` lines are the box's own view of what it decoded.

## Known risks / things to check on devices
- Anything opaque drawn between the screen and the hole hides the video: opacity/fade (route
  transitions), `BackdropFilter` blur over the video won't blur it (it's not in Flutter).
- Raster-cached pictures or a `saveLayer` (Opacity, ShaderMask) around the hole stop the clear.
- Preview clipping/rounded corners don't apply to the native surface.
- Hole position lags a frame during animations (hero shrink, guide transitions).
- Transparent Flutter view = texture render mode: some extra GPU cost on weak boxes.
- Other platform views (YouTube trailers WebView) with a transparent Flutter view: untested.
- Android 9 paused-surface first-frame workaround of `PlatformVideoView` is not replicated.

## Test checklist (owner / Sam / AMD)
1. Turn on, restart. Live channel in the guide preview: picture in the right place and size?
2. Full screen, back to guide, channel up/down, translucent guide over full-screen video.
3. Shield: green flicker gone? HDR movie: TV shows HDR?
4. Cube: 4K HDR10 channel: TV shows HDR? Send log → `NativeSurface: format`, `video size`, Amlogic
   `Resolution change` line (want 3840x2160).
5. Mini player / pill, Sports hero preview, Settings/Search over live video, Multiview in and out,
   Media Hub movie, trailer.
6. Turn off, restart: everything as before.


## Codex fixes after Formuler +424 feedback (2026-10-24; unreleased)

Branch `codex/native-surface-fixes`, based on `claude/native-surface` at `f1ceb95`.
`LOG-5NEAZT` confirms format/decoder events precede native attach and the guide
reset throws from a ScrollPosition without content dimensions. Both captured
sessions had the beta on; no beta-off device reproduction is claimed.

- Covered video routes keep their last native rect while TickerMode is off,
  including reverse transitions. Flutter's opaque Settings page covers the
  surface. Visible/translucent/fullscreen holes still take priority; removing
  the last hole or explicitly disabling it still hides the surface. Cancel the
  pending diagnostics timer when the last hole is removed.
- Cache the actual video decoder name through a lightweight AnalyticsListener
  installed before ExoPlayer.prepare in VideoPlayer. DecoderCounters has no
  decoder-name field. Native attach seeds decoder name, current Format and
  VideoSize before listening for subsequent changes; switching players resets
  prior facts. This does not alter surface selection/codec behavior when off.
- Guide group changes only jump once all attached positions have pixels and
  content dimensions; retry a reset after layout when needed. Mirrored ruler/
  channel-label scrolls use the same guard. This applies to both beta modes.
- Regression coverage: Settings push/pop, translucent overlay, explicit hidden
  TickerMode, fullscreen priority/return, unmeasured/shared scroll positions,
  late decoder/format attach and subsequent changes. Android unit tests use
  SDK28 (Cube) and SDK30 (Shield/Formuler) with the repo's Java17 runtime.
- No version bump, APK package, installation, merge, push or release in this
  fix task. Owner device check: return from Settings without late video pop-in;
  Send log should contain seeded decoder/format; startup guide error absent.
