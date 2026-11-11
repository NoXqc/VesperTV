import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' show IconData, Icons;

/// How the full-screen player sizes the picture (owner, 2026-11-11, from
/// Nuvio: one button cycles through them). Applied by sizing the video's
/// box ([VideoPlayerPane]), so the platform view and the native surface's
/// hole follow it alike; the screen edge crops whatever overflows. Saved
/// on the device (`vesper_video_fit`).
enum VideoFit {
  fit('Fit', Icons.fit_screen),
  stretch('Stretched', Icons.open_in_full),
  crop('Crop', Icons.crop),
  fitHeight('Fit height', Icons.height),
  fitWidth('Fit width', Icons.swap_horiz),
  zoom('Slight zoom', Icons.zoom_in),
  cinema('Cinema zoom', Icons.theaters);

  const VideoFit(this.label, this.icon);

  /// English label: `tr()` it where it's shown.
  final String label;
  final IconData icon;

  /// The next one in the button's cycle (back to [fit] after the last).
  VideoFit get next => values[(index + 1) % values.length];

  static VideoFit byName(String? name) =>
      values.where((f) => f.name == name).firstOrNull ?? fit;

  /// A wide film (2.39:1) burned into a 16:9 picture: [cinema] scales the
  /// fitted picture until that band fills the screen's height.
  static const cinemaRatio = 2.39;

  /// [slight zoom]: just enough to lose thin borders.
  static const zoomFactor = 1.12;

  /// The video's box for a [pane] and a picture of [ratio] (width /
  /// height). Bigger than the pane = cropped by its edge.
  Size sizeIn(Size pane, double ratio) {
    final w = pane.width, h = pane.height;
    final paneRatio = w / h;
    final fitSize =
        paneRatio > ratio ? Size(h * ratio, h) : Size(w, w / ratio);
    return switch (this) {
      fit => fitSize,
      stretch => pane,
      crop => paneRatio > ratio ? Size(w, w / ratio) : Size(h * ratio, h),
      fitHeight => Size(h * ratio, h),
      fitWidth => Size(w, w / ratio),
      zoom => fitSize * zoomFactor,
      // Capped so a portrait phone doesn't blow it up 4x.
      cinema => fitSize * math.min(math.max(1.0, cinemaRatio / paneRatio), 1.5),
    };
  }
}
