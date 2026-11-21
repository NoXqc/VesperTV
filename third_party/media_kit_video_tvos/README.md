# media_kit_video_tvos

Apple TV video output for `package:media_kit`, used by VesperTV
(`dev-notes/apple-tv.md`). Not published.

- `tvos/Classes/`: media_kit_video **1.3.1**'s iOS plugin code
  (`ios/Classes/plugin`), unchanged: libmpv's OpenGL ES render API draws into
  a CVPixelBuffer that Flutter shows as a texture (`TextureHW`); the simulator
  uses mpv's software renderer (`TextureSW`). Same method channel as the iOS
  plugin, so media_kit_video's own Dart code drives it. MIT, `LICENSE`.
- `tvos/Headers/mpv/`: libmpv's public headers from MPVKit 1.0.0 (mpv 0.41).
- `tvos/Frameworks/Mpv.xcframework`: not committed. Built on the tvOS
  workflow by `tools/tvos/build_mpv_framework.sh` from MPVKit's LGPL static
  libraries (libmpv, FFmpeg and their dependencies) as one dynamic framework,
  the `Mpv.framework/Mpv` media_kit opens on iOS. On Apple TV the app passes
  that path to `MediaKit.ensureInitialized` (media_kit has no `tvos` entry).

If media_kit_video is bumped, re-copy its `ios/Classes/plugin` here.
