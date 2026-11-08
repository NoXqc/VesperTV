# Linux desktop build (first pass, 2026-11-07)

Branch `claude/linux-build`, stacked on `claude/appstore-build` (it reuses `usesMediaKit`).

- `isDesktop` / `isDesktopTarget` now include Linux, so Linux gets everything a computer gets:
  the media_kit (mpv) player stack, window_manager full screen / windowed, mouse layouts,
  Backup in `~/Documents/VesperTV`, Restart relaunches itself.
- `media_kit_libs_linux` links the **system libmpv**: `libmpv-dev` to build, `libmpv2` to run.
- No web view on Linux (flutter_inappwebview has none): YouTube trailers open in the browser
  (`youtube_playback.dart`), automatic detail trailers fail quietly back to the artwork
  (`YouTubePlatformView` reports an error).
- No updater on Linux (`AppUpdateService.checkForUpdate` returns null): no Linux release asset.
- Runner: binary `vespertv`, window title VesperTV (no Linux install ever shipped, so renaming
  orphans nothing). GTK application id stays `com.nox.nox_iptv`.

## Build

`.github/workflows/linux-build.yml` (ubuntu-24.04, Flutter 3.47.9) uploads **VesperTV-linux**:
`VesperTV-<version>-<build>-linux-x64.tar.gz` (the whole release bundle; the binary needs its
`lib/` and `data/` beside it).

## Run

Ubuntu 24.04+ / Mint 22+ (built against glibc 2.39):

```
sudo apt install libmpv2
tar -xzf VesperTV-*-linux-x64.tar.gz
./VesperTV-*-linux-x64/vespertv
```

Older distros (Debian 12, Ubuntu 22.04) need a build on an older runner or a Flatpak/AppImage
that bundles libmpv: not done.

## First user report (Steam Machine, SteamOS, AMD, +676, LOG-CUBM2E, 2026-11-08)

- **Blue video on every channel.** The app window draws with OpenGL ES there, but
  media_kit_video 1.3.1's GPU path (`linux/video_output.cc`: its own `GdkGLContext`, mpv render
  context created while a desktop-GL context is current, frames rendered later on Flutter's) sets
  mpv up for desktop GL: `GLSL 4.40 is not supported. Supported versions are: 1.00 ES ...`, shader
  link fails, no colour conversion. Fix in this branch: **Settings > Playback > Software video is on
  by default on Linux** (`getDesktopSoftwareVideo` -> `Platform.isLinux`), mpv's SW render API
  (CPU drawing, at most 1920x1080) with `hwdec=auto-copy` so VA-API still decodes 4K HEVC. Proper
  fix (GPU drawing) = patch/upgrade media_kit_video's Linux output; not done.
- **Reconnect every 30-40 s.** The branch predated main's 5b360ce / 3e7b392 (30 s network timeout,
  no reopen on mpv's "Cannot seek in this stream" while playback moves): merged main.
- `Cannot load libcuda.so.1` lines are mpv probing NVDEC on an AMD box: harmless.
