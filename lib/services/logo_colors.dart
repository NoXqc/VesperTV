import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

/// A channel logo's main colours, for Home's glow behind a live channel
/// (owner, 2026-11-10: Discord idea of a banner that changes with the
/// channel). The logo is decoded once at 48 px wide from the same image
/// cache the cards use, so it costs nothing on a weak box; results are
/// kept for the app run.
class LogoColors {
  LogoColors._();

  static final _cache = <String, Future<List<Color>>>{};
  static const _maxCached = 200;

  /// Up to two colours, strongest first; empty for a black / white / grey
  /// logo or one that doesn't load (the caller falls back to the theme's).
  static Future<List<Color>> of(String url) {
    final hit = _cache.remove(url);
    if (hit != null) return _cache[url] = hit; // most recent last
    if (_cache.length >= _maxCached) _cache.remove(_cache.keys.first);
    return _cache[url] = _load(url);
  }

  static Future<List<Color>> _load(String url) async {
    final stream = ResizeImage(
      CachedNetworkImageProvider(url),
      width: 48,
    ).resolve(ImageConfiguration.empty);
    final done = Completer<ui.Image?>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!done.isCompleted) done.complete(info.image.clone());
        info.dispose();
      },
      onError: (_, __) {
        if (!done.isCompleted) done.complete(null);
      },
    );
    stream.addListener(listener);
    final image = await done.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
    stream.removeListener(listener);
    if (image == null) return const [];
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      return data == null ? const [] : dominant(data.buffer.asUint8List());
    } catch (_) {
      return const [];
    } finally {
      image.dispose();
    }
  }

  /// The two strongest hues of straight RGBA pixels: transparent, dark and
  /// grey/white pixels don't count (a white logo on nothing has no colour).
  /// The second needs a clearly different hue and a fifth of the first's
  /// weight.
  static List<Color> dominant(Uint8List rgba) {
    const bins = 12;
    final weight = List<double>.filled(bins, 0);
    final sumR = List<double>.filled(bins, 0);
    final sumG = List<double>.filled(bins, 0);
    final sumB = List<double>.filled(bins, 0);
    var opaque = 0;
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 128) continue;
      opaque++;
      final r = rgba[i] / 255, g = rgba[i + 1] / 255, b = rgba[i + 2] / 255;
      final mx = math.max(r, math.max(g, b));
      final mn = math.min(r, math.min(g, b));
      final s = mx == 0 ? 0.0 : (mx - mn) / mx;
      if (mx < 0.2 || s < 0.25) continue;
      final d = mx - mn;
      var h = mx == r
          ? ((g - b) / d) % 6
          : mx == g
              ? (b - r) / d + 2
              : (r - g) / d + 4;
      h *= 60;
      if (h < 0) h += 360;
      final bin = (h / 360 * bins).floor() % bins;
      final w = s * mx;
      weight[bin] += w;
      sumR[bin] += r * w;
      sumG[bin] += g * w;
      sumB[bin] += b * w;
    }
    if (opaque == 0) return const [];
    final order = List<int>.generate(bins, (i) => i)
      ..sort((a, b) => weight[b].compareTo(weight[a]));
    final first = order.first;
    // A few coloured pixels in a grey logo (anti-aliasing) don't count.
    if (weight[first] < opaque * 0.03) return const [];
    Color colour(int bin) => Color.fromARGB(
          255,
          (sumR[bin] / weight[bin] * 255).round(),
          (sumG[bin] / weight[bin] * 255).round(),
          (sumB[bin] / weight[bin] * 255).round(),
        );
    final result = [colour(first)];
    for (final bin in order.skip(1)) {
      if (weight[bin] < weight[first] * 0.2) break;
      final apart = (bin - first).abs();
      if (math.min(apart, bins - apart) >= 2) {
        result.add(colour(bin));
        break;
      }
    }
    return result;
  }

  /// [c] made vivid enough to read as a glow on black, not so light that
  /// white text over it gets lost.
  static Color glow(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation(math.max(hsl.saturation, 0.6))
        .withLightness(hsl.lightness.clamp(0.4, 0.55))
        .toColor();
  }
}
