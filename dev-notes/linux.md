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
- **Segfault in libmpv on every close** (+676, KDE crash viewer photo): the window closed with players open,
  the Dart VM went away and mpv's wakeup callback (a Dart NativeCallable) ran into freed memory. Fixed on main
  (7599296): every player closes before the window (`AppExit.quit`, preventClose + onWindowClose). The user runs
  the app in a distrobox (Ubuntu 24.04 container on SteamOS).

## Flatpak (`claude/linux-flatpak`, 2026-11-20)

Discord (AMD, Steam Machine): the tarball needs `sudo apt install libmpv2`, Ubuntu 24.04+
(glibc 2.39) and a hand-made `.desktop`; media_kit_video's plugin is linked against
`libmpv.so.2`, so distros that only ship `libmpv.so.1` (Debian 12, Ubuntu 22.04) can't start it.

- `linux/flatpak/app.vespertv.VesperTV.yml`: **GNOME 51 runtime** (Flutter's Linux embedder needs
  GTK 3; the freedesktop runtime has none). Builds libass, libplacebo, libdisplay-info (+ hwdata),
  FFmpeg 9.0.2 (built-in decoders, GnuTLS, libxml2 for DASH, dav1d, VA-API) and libmpv only
  (mpv 0.42.0, `cplayer=false`), pinned to what Flathub's io.mpv.Mpv builds on freedesktop 26.08.
  The Flutter bundle goes in `/app/vespertv` unchanged, `/app/bin/vespertv` links to it.
- `.github/workflows/linux-flatpak.yml`: job 1 builds the bundle on Ubuntu 24.04 with
  `APPLICATION_ID` sed'ed to `app.vespertv.VesperTV` (the tarball keeps `com.nox.nox_iptv`: its
  settings folder is named after it; inside the Flatpak the window must carry the Flatpak id or
  Wayland shows no icon); job 2 runs flatpak-builder in `flathub-infra/flatpak-github-actions:gnome-51`
  and uploads `VesperTV-<version>-x86_64.flatpak` as an artifact. Run by hand with `release_tag`, a
  third job puts it on that release as `VesperTV-linux-x86_64.flatpak` (release.md step 4b; first on
  1.0.72, 2026-11-21, beside `VesperTV-linux-x64.tar.gz` from linux-build.yml the same way).
- Permissions: network, Wayland + fallback X11, PulseAudio, `/dev/dri` (GPU, VA-API),
  `~/Documents/VesperTV` (backups). Restore from a file = file chooser portal; keep the screen on =
  `org.freedesktop.portal.Inhibit` (wakelock_plus), no extra permission. No in-app updater on Linux
  anyway: Flatpak updates come from wherever it was installed.
- Settings live in `~/.var/app/app.vespertv.VesperTV/`: a tarball user starts fresh (Backup &
  restore or Transfer moves the setup).
- VA-API: AMD's driver comes with the runtime's Mesa (GL extension); Intel needs the
  `org.freedesktop.Platform.VAAPI.Intel` extension. `--socket=fallback-x11` means no X11 on a
  Wayland desktop, so mpv's copy-back VA-API needs its DRM display (`-Ddrm` + libdisplay-info).
  Software video stays on by default (the GPU drawing path's GLES problem above is media_kit_video's,
  not the packaging's); decoding still asks for `hwdec=auto-copy`. Data pool's Decoder row says
  which one ran (`hwdec-current`).

CI (runs 44817485915 / 44819615453, 2026-11-20): mpv features vaapi, vaapi-drm, vaapi-wayland, vaapi-x11,
drm, egl, wayland, x11, vulkan, pipewire, pulse; ~28 MB bundle. The smoke step installs it, checks `ldd` (plugins need
`LD_LIBRARY_PATH=/app/vespertv/lib` to see libflutter_linux_gtk.so, which the binary loads first; libdartjni.so is
package:jni's Android bridge, skipped) and runs the app 20 s under Xvfb: it started (StartupMark, DesktopWindow lines).
Two image problems on the way: mpv's X11 needs libXpresent (built here, like io.mpv.Mpv), and a GNOME SDK update
failed in the image's lower overlay layer ("Invalid cross-device link"): the workflow copies /var/lib/flatpak into
the container's own layer first.

Install: `flatpak install --user VesperTV-*.flatpak` (needs the Flathub remote for the runtime:
`flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`),
run from the menu or `flatpak run app.vespertv.VesperTV`. Flathub itself (needs a source build of the
Flutter app and a domain check on vespertv.app) is a later step.
