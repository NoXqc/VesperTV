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
