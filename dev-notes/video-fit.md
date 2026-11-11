# Player picture modes (owner, 2026-11-11)

Owner photo of Nuvio's player: one button that cycles how the picture fills the screen, with the mode's name
shown at the top. Asked for movies and shows (IPTV and Media Hub); it replaced the old two-state Fit / Fill
button, so live channels get it too.

## What it does
- Android player, TV options row (OK, then Down) and the phone's top bar: the **picture button** shows the
  current mode and each press moves to the next: **Fit → Stretched → Crop → Fit height → Fit width → Slight
  zoom → Cinema zoom → Fit**. The name shows in a pill at the top for 1.6 s (`_FitPill`, key
  `video-fit-pill`).
- Leaving Fit hides the system bars (a phone also turns sideways), back to Fit brings them back: the old
  Fill button's behaviour.
- Remembered on the device (`vesper_video_fit`, never transferred, like `vesper_video_fill`). The old
  Fill switch reads as Crop the first time; setting a mode also writes the old switch (on = anything but
  Fit) for a downgrade and for Vesper AI's `video_fill` switch (on = Crop, off = Fit).

## How
- `utils/video_fit.dart`: `VideoFit` enum (label, icon, `next`, `byName`) and `sizeIn(pane, ratio)` = the
  video box's size. Fit / Crop as before; Stretched = the pane; Fit height = `h * ratio` wide; Fit width =
  `w / ratio` high; Slight zoom = Fit x 1.12; Cinema zoom = Fit x 2.39 / pane ratio (a 2.39:1 film burned
  into a 16:9 picture fills the height; a 2.39:1 file = Crop), capped at 1.5x (portrait phones).
- `VideoPlayerPane(fit:)` sizes the box in an `OverflowBox` (no clip: the screen edge crops). The platform
  view and the native surface's hole both follow the box; `NativeVideoSurface.setRect` places the
  SurfaceView there with no aspect correction, so Stretched really stretches on both paths.
- Not done: the Windows player (`DesktopPlayerScreen`, media_kit) keeps its own fit.

## Tests
`test/video_fit_test.dart` (sizes, cycle, old switch), `test/player_video_fit_test.dart` (the real player
screen: OK, Down, press through all seven, pane + pill follow, pill fades). Not box-tested.
