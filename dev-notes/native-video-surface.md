# Native video surface (beta)

Branch `claude/native-surface` (from main `ebb0fa5`, test builds `1.0.39+423` / `+424` / `+425`). Android main player only.

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


## Codex fixes after Formuler +424 feedback (2026-10-24; beta +425)

Branch `codex/native-surface-fixes` (6222f16), based on `claude/native-surface` at `f1ceb95`, fast-forwarded into the beta branch for +425.
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
- No version bump, APK package, installation, merge, push or release in the original
  fix task; the owner subsequently requested beta +425. Owner device check: return from Settings without late video pop-in;
  Send log should contain seeded decoder/format; startup guide error absent.

## Beta +425 packaging (Codex, 2026-10-24)

- Owner requested Android beta only, retaining tag `1.0.39-test.423` and asset
  `VesperTV-1.0.39-test.423.apk` so the download link stays unchanged.
- Includes only the three follow-ups above; per-profile palettes and compact
  reminder-card styling remain on their separate Codex branches.
- Required checks: analyze baseline 17; all 403 Flutter tests passed. The fix
  branch also passed 76 Android unit tests across SDK28/30.
- Beta stays off by default and applies after restart. Installing over an
  existing beta preserves its switch; Android installation restarts the app.
- No device installation/test in this packaging task. Cube HDR and Shield
  flicker outcomes still require owner/device feedback. Stable +422 untouched.
- Release APK built successfully; apksigner verified the expected release
  certificate (see CLAUDE.md section 5); aapt confirms versionCode425 / 1.0.39.
- APK SHA-256: `2d31025af217aae87f1d96f5d6e2757a9b0408f04d1f6331982d99b24c62f195`.

## Acceptance (owner, 2026-10-24)
Sam (Shield) and AMD (Cube) must, with the beta on, play **HDR normally** (TV switches to HDR, not
washed out; no Shield green flicker; Cube decodes 4K at 3840x2160) on live channels **and Media Hub**,
and play **Media Hub video normally** (start, resume, pause/play without a black picture — Android 9
paused-surface workaround still missing here —, seek, subtitles, audio tracks, next episode, stream
picker, trailers). Full list in HANDOFF.md "Beta acceptance".


## Movies / TV Shows return follow-up (Codex, 2026-10-24; not packaged)

- Owner reported +425 fixed Settings return but Movies/TV Shows still rebuilt
  a playing live stream. Unlike Settings routes, those tabs explicitly called
  `_parkLiveChannel` -> `stop` -> controller disposal. Retaining a covered
  route's native rect cannot preserve a player that has been disposed.
- `codex/browse-video-transition` keeps an existing native-surface controller
  alive when entering Movies/TV Shows (including the initial-tab path).
  `PlaybackService.usesNativeSurface` checks the controller's original mode,
  so changing Compatibility video does not reclassify an existing session.
- The tab removes its hole: the native surface moves offscreen at the same
  size, retaining its player. Returning to TV or holding Right reuses it.
  Sound/connection continue while browsing, matching Settings behavior.
- Beta-off/platform/texture players retain the prior stop-and-resume behavior;
  Home and Media Hub continue parking live video. No codec/native Java changes.
- Regression coverage: both tabs, startup vs tab selection, native vs legacy
  parking (8 widget cases), plus hole removal/restoration without a new attach.
- Owner confirmation still needed on the box; no APK built or beta updated
  for this follow-up. Release +425 remains the published package.

### Owner clarification: HDR / 4K only
- Owner reports tab-switch flicker with HDR / 4K streams, apparently not
  1080p (2026-10-24). HDR vs resolution has not been isolated independently.
- Source check: `PlaybackService.stop` disposes the controller and calls
  `DisplayMatch.reset`. That reset asks Android to restore its display mode
  only if frame-rate/resolution matching previously requested a change.
- Avoiding stop for native browse transitions also avoids this explicit reset.
  Ending HDR output may itself cause a TV mode transition; this is a plausible
  explanation, not a confirmed device diagnosis. Do not disable HDR/matching.
- Device validation should compare HDR 4K, SDR 4K and SDR 1080p, with the
  same tab-switch sequence. Check Send log DisplayMatch/NativeSurface lines
  if the retained-player fix still flickers. No additional code change yet.

## Native channel handoff follow-up (Codex, 2026-10-24; not packaged)

Owner log LOG-M25S33 (+425, Formuler Z11 Pro MAX / Realtek / SDK30) includes
HDR4K -> reported SDR4K -> SDR4K ->1080p swaps. Around09:24:32-09:24:51 each
replacement releases its ExoPlayer, clears the native output, prepares a new
player, then assigns the real surface after initialization. Flutter also hides
the surface during the gap with no video widget. DisplayMatch reports same;
recorded display mode remains1920x1080/60. This does not prove an HDMI mode
change or app restart. The last SDR selections lack full five-second snapshots;
missing transfer metadata must not be called verified SDR.

Branch codex/native-channel-handoff removes the unnecessary output transitions:
- Dart awaits native configure at opt-in beta startup; native creates its one
  offscreen SurfaceView early. Beta-off does not configure/create a surface.
- The main player's per-instance VideoPlayerOptions receives that holder only
  when no existing native owner is running. VideoPlayer binds it BEFORE
  setMediaItem/prepare, then registration attaches diagnostics without rebinding.
- If a backup/reload candidate is prepared while an owner is running, it gets
  no early native holder; it binds only when adopted. Texture/Multiview players
  never receive a native holder. No HDR, codec, tunneling or matching changes.
- onPlayerDisposed removes diagnostics/references but skips clearVideoSurfaceHolder
  just before release; explicit detach/switch-away still clears a retained player,
  and its binding marker resets so it can be attached again later.
- PlaybackService retains the last native rectangle across the temporary widget
  gap until initialization finishes/fails. Holds overlap safely and are cancelled
  on explicit stop/service disposal. No speculative time-based hold or fake frame.
- Existing browse fix avoids stop entirely on Movies/TV Shows. HDR-vs-SDR output
  changes may still require a hardware blackout; channel loading is not eliminated.

Owner-authorized integration on this branch includes codex/browse-video-transition,
codex/profile-theme-colours and codex/reminder-card-style; Coming soon episode tags
are also included. Main/stable and published beta+425 remain untouched. The profile
onViewerChanged callback and native configure call both remain wired in main.dart.

Verification: flutter analyze17 baseline infos (8.7s); flutter test426 passed
(00:22). Native Gradle tests96 passed, zero failures/errors/skips, SDK28/30,
BUILD SUCCESSFUL in11s (NativeVideoSurfaceTest, VideoPlayerTest, VideoPlayerPluginTest).
Plugin test fixtures now provide an ExoPlayer for SubtitleBridge, and use SDK28/30
with the repo JDK17. Native tests cover early prepare order, no duplicate binding,
no clear-before-release, explicit reattachment, busy-owner guard, and texture exclusion.
No APK built/released or box driven. Owner must test same-stream tab transitions
and HDR4K/SDR4K/1080p channel swaps; compare new logs for no placeholder switch on
release, early attachment, and no hidden/rect excursion during channel loading.

## Owner test package +426 (Codex, 2026-10-24)

- Owner requested a local APK build and installation on their Formuler.
- Built `1.0.39+426` from `codex/native-channel-handoff` (code ff0523c),
  including profile themes, compact reminders, browse retention and Coming soon.
- `flutter build apk --release` succeeded in42.4s; apksigner matches the
  expected release certificate; aapt verifies package/versionCode426.
- APK SHA256: `afee2b538287faebda37502cbf035ed5d8b01aeda3a7c40f7c0fb2b1e5569b20`.
- Retained local copy outside checkout: `C:\Users\aarse\VesperTV-test426\`.
- Code checks from ff0523c remain valid (version-only packaging): analyze17,
  Flutter426 tests passed, Android96 tests passed. No code changed for packaging.
- No GitHub upload/push/tag/Discord; public beta link still contains+425.

## Native live zap follow-up +427 (Codex, 2026-10-24)

LOG-MBF8SN confirms owner+426 on Formuler, whole-TV black for guide-preview
1080p->reported SDR4K. At09:47:17-09:47:19 the native rect remains558x314;
there is no hide/resize/destroy at that zap and display matching says same.
The remaining lifecycle is releasing the AVC ExoPlayer and creating HEVC output.
This rules out the prior temporary offscreen move as the cause of that example;
it does not prove the TV's HDMI/color transition or guarantee seamless HDR changes.

Branch codex/native-live-zap (from combined+426) adds replaceLive on the native
channel, narrowly for initialized, healthy, native live->live HTTP(S) playback
without external caption files, with Compatibility video off. The native owner
must still match; changed audio-passthrough configuration rejects reuse.
- Same ExoPlayer, holder, native player id and Dart controller: replace the
  MediaSource, prepare and play. No output clear/detach or player release.
- The new media source gets fresh HTTP transfer stats and frame-rate probe;
  previous audio/text track overrides and recovery counters/tasks reset.
  Keep the existing initialized event state; never initialize a Dart controller twice.
- Wait for READY (15s bound); native error, disposal or superseding zap completes
  the waiting request and cancels its listener/timeout. Unsupported/failed reuse
  falls back to the existing recreation/HLS-learning/backup flow.
- Service updates current channel, history, start time and picture dimensions;
  replaces its restart-loop listener and invalidates delayed old-channel metadata
  and display-match work. Generation guards cover rapid A->B->A and stop/disposal.
- Native diagnostics are logged after successful reuse. Look for reusing player N
  for live zap / reused live player, with the same id across guide selections.
- VOD, Multiview/texture, beta-off, external-caption and uninitialized/error paths
  keep the existing lifecycle. This does not implement Multiview HDR tone mapping.

Tests: two Flutter cases verify controller/history/size and late A->B->A failure;
native SDK28/30 tests verify no release/output clear, READY completion, supersession,
dispose cancellation and unsupported rejection. No new user-visible strings.
Owner must still verify whether this removes the whole-TV blackout on Realtek;
codec changes inside ExoPlayer and genuine HDR output changes may still black out.

Final checks: `17 issues found. (ran in 9.2s)`; `00:22 +428: All tests passed!`;
Android104 tests, zero failures/errors/skips, `BUILD SUCCESSFUL in 27s`.
Final release APK rebuilt after A->B->A generation guard:40.6s /81.3MB; expected
release certificate and package `com.nox.nox_iptv` /versionCode427 verified.
APK SHA256: `5046c986de045746226452cdc5dc13b07eed1798f4b17068aa37043b617e4051`.
Local copy: `C:\Users\aarse\VesperTV-test427\VesperTV-1.0.39-test.427.apk`.
No GitHub upload/push/tag/Discord; owner-authorized ADB install only, no UI driving.
