import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A title logo drawn without the empty margin around it. Collection packs
/// ship their logos (the hero's NETFLIX, Disney+…) centred on a large
/// transparent 1280x720 canvas: fitted as it is, the wordmark came out a
/// third of the size it should be (owner, 2026-11-11, Home's hero). The
/// visible box is measured once per link and kept for the app run.
class TrimmedLogo extends StatefulWidget {
  const TrimmedLogo({
    super.key,
    required this.url,
    required this.height,
    required this.maxWidth,
    required this.fallback,
    this.tint,
  });

  final String url;

  /// The logo's height; narrower when [maxWidth] stops it first.
  final double height;
  final double maxWidth;

  /// Shown while loading and when the picture fails (the name as text).
  final Widget fallback;

  /// Paints the logo in one colour (the packs' wordmarks are plain white):
  /// a service's brand colour, see [brandColor].
  final Color? tint;

  /// The brand colour of a streaming service's wordmark, by its name
  /// (owner, 2026-11-11: the red NETFLIX on Home). Null = keep it white
  /// (Disney+, Apple TV, Peacock… are white on dark anyway).
  static Color? brandColor(String name) {
    final n = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    for (final (key, color) in _brands) {
      if (' $n '.contains(' $key ')) return color;
    }
    return null;
  }

  static const _brands = [
    ('netflix', Color(0xFFE50914)),
    ('prime video', Color(0xFF00A8E1)),
    ('hulu', Color(0xFF1CE783)),
    ('paramount', Color(0xFF0064FF)),
    ('crunchyroll', Color(0xFFF47521)),
    ('hbo max', Color(0xFF9B4DFF)),
    ('shudder', Color(0xFFE10E1B)),
    ('youtube', Color(0xFFFF0033)),
  ];

  /// The visible part of [image] (cached under [url]).
  @visibleForTesting
  static Future<Rect> measure(String url, ui.Image image) =>
      _TrimmedLogoState._measure(url, image);

  @override
  State<TrimmedLogo> createState() => _TrimmedLogoState();
}

class _TrimmedLogoState extends State<TrimmedLogo> {
  /// The visible part of each logo (decoded at [_decodeWidth]).
  static final Map<String, Rect> _boxes = {};
  static const _decodeWidth = 640;

  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  Rect? _box;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(TrimmedLogo old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _image?.dispose();
      _image = null;
      _box = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    final stream =
        ResizeImage(CachedNetworkImageProvider(widget.url), width: _decodeWidth)
            .resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stop();
    _listener = ImageStreamListener((info, _) {
      final image = info.image.clone();
      final url = widget.url;
      unawaited(_measure(url, image).then((box) {
        if (!mounted || url != widget.url) {
          image.dispose();
          return;
        }
        setState(() {
          _image?.dispose();
          _image = image;
          _box = box;
        });
      }));
    }, onError: (_, __) {
      if (mounted) setState(() => _failed = true);
    });
    _stream = stream..addListener(_listener!);
  }

  /// The bounding box of the pixels that aren't (almost) transparent.
  static Future<Rect> _measure(String url, ui.Image image) async {
    final known = _boxes[url];
    if (known != null) return known;
    final full =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return full;
    final w = image.width, h = image.height;
    var minX = w, minY = h, maxX = -1, maxY = -1;
    for (var y = 0; y < h; y++) {
      final row = y * w * 4;
      for (var x = 0; x < w; x++) {
        if (data.getUint8(row + x * 4 + 3) > 16) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    final box = maxX < 0
        ? full
        : Rect.fromLTRB(
            minX.toDouble(), minY.toDouble(), maxX + 1.0, maxY + 1.0);
    return _boxes[url] = box;
  }

  void _stop() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _listener = null;
    _stream = null;
  }

  @override
  void dispose() {
    _stop();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image, box = _box;
    if (_failed || image == null || box == null || box.isEmpty) {
      return widget.fallback;
    }
    final aspect = box.width / box.height;
    final width = math.min(widget.maxWidth, widget.height * aspect);
    final logo = CustomPaint(
      size: Size(width, width / aspect),
      painter: _LogoPainter(image, box),
    );
    final tint = widget.tint;
    return tint == null
        ? logo
        : ColorFiltered(
            colorFilter: ColorFilter.mode(tint, BlendMode.srcIn), child: logo);
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.image, this.box);
  final ui.Image image;
  final Rect box;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(image, box,
      Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);

  @override
  bool shouldRepaint(_LogoPainter old) => old.image != image || old.box != box;
}
