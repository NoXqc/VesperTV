import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Full-screen gradient backdrops painted ONCE into a small image and shown
/// stretched, instead of re-drawn by the GPU on every frame.
///
/// Measured on the Homatics (owner, 2026-11-21, Sports Trak's Pick the
/// channel, `Frames:` avgRaster with layers switched off one by one): the
/// team-colour glow (two full-screen gradients) cost 20 ms of every frame,
/// the Settings wallpaper backdrop (gradient + picture + dim) 12 ms; with
/// them gone the page drew in 7 ms instead of 50. A gradient is smooth, so
/// an image an eighth of the size, scaled up with bilinear filtering, looks
/// the same.
///
/// [layers] are painted bottom to top over the widget's whole size, like a
/// stack of `DecoratedBox`es. The image is keyed by the layers and the size:
/// the same backdrop on several pages shares one image.
class BakedBackdrop extends StatefulWidget {
  const BakedBackdrop({super.key, required this.layers});

  final List<Decoration> layers;

  /// The image's size relative to the widget's logical size.
  static const double scale = 1 / 8;

  @override
  State<BakedBackdrop> createState() => _BakedBackdropState();
}

class _BakedBackdropState extends State<BakedBackdrop> {
  static final Map<String, ui.Image> _cache = {};

  ui.Image? _image;
  String? _key;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  ui.Image _bake(Size size, String key) {
    final cached = _cache[key];
    if (cached != null) return cached;
    final w = (size.width * BakedBackdrop.scale).ceil().clamp(8, 512);
    final h = (size.height * BakedBackdrop.scale).ceil().clamp(8, 512);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(w / size.width, h / size.height);
    for (final layer in widget.layers) {
      final painter = layer.createBoxPainter();
      painter.paint(canvas, Offset.zero, ImageConfiguration(size: size));
      painter.dispose();
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    // A few backdrops at most (theme glow, team colours); the oldest go.
    while (_cache.length >= 12) {
      _cache.remove(_cache.keys.first)?.dispose();
    }
    return _cache[key] = image;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
      final key = '${Object.hashAll(widget.layers)}|'
          '${size.width.round()}x${size.height.round()}';
      if (key != _key) {
        _key = key;
        _image?.dispose();
        // Our own handle: the cache may drop its one while we still draw.
        _image = _bake(size, key).clone();
      }
      return RawImage(
        image: _image,
        width: size.width,
        height: size.height,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.low,
      );
    });
  }
}
