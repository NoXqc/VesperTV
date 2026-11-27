import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/device_memory_service.dart';
import '../services/live_group_styles.dart';

/// A live style behind a group row ([LiveGroupStyle]): still while the
/// remote is elsewhere, moving while [animate] (the row has focus), at most
/// [fps] frames a second, stopped on unfocus and when the page is covered
/// (TickerMode); the painter repaints alone (no rebuilds), inside its own
/// RepaintBoundary (CLAUDE.md §10 frame-cost rules 1 and 5).
///
/// A timer, not a vsync ticker, and at most [movesFor] per visit: on the
/// Homatics every frame re-rasters the whole screen, ~21 ms (27 ms with a
/// channel in the preview: 40-53 frames over 33 ms per 10 s) however small
/// the change, so any moving row costs the box real work (1034 / 1035). The
/// style moves while the remote rests, then settles until it comes back
/// (like Sports Trak's RedZone pill).
///
/// A touch screen has no remote focus (a tap opens the group, owner on his
/// phone, 2026-11-27: "we don't really see the animations"): there every
/// styled row moves for [touchMovesFor] when it shows, then rests, and
/// again each time its page comes back ([TickerMode]). Not on a TV box,
/// which counts as touch until its first key press.
class LiveStyleBackground extends StatefulWidget {
  const LiveStyleBackground({
    super.key,
    required this.colorId,
    required this.animate,
    this.borderRadius = 8,
    this.style,
  });

  /// `style:<id>`; drawn once the bank names it.
  final String colorId;

  /// A style to draw as is (the picker's previews).
  final LiveGroupStyle? style;
  final bool animate;
  final double borderRadius;

  @override
  State<LiveStyleBackground> createState() => _LiveStyleBackgroundState();
}

class _LiveStyleBackgroundState extends State<LiveStyleBackground> {
  /// Where a still row rests: particles spread along their way, not
  /// bunched at the start.
  static const restAt = 2.6;

  /// Frames a second while moving.
  static const fps = 30;

  /// How long one visit moves.
  static const movesFor = Duration(seconds: 30);

  /// How long a row moves on a touch screen after it shows.
  static const touchMovesFor = Duration(seconds: 12);

  /// A phone / tablet used by touch (no remote focus to follow).
  static bool get _touch =>
      !DeviceTypeService.television &&
      FocusManager.instance.highlightMode == FocusHighlightMode.touch;

  final _time = ValueNotifier<double>(restAt);
  Timer? _timer;
  double _base = restAt;

  /// This visit moved [movesFor]: still until the remote leaves.
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    if (widget.style == null) {
      LiveGroupStyles.instance.ensureLoaded(wanted: widget.colorId);
    }
  }

  @override
  void didUpdateWidget(LiveStyleBackground old) {
    super.didUpdateWidget(old);
    if (old.colorId != widget.colorId && widget.style == null) {
      LiveGroupStyles.instance.ensureLoaded(wanted: widget.colorId);
    }
  }

  void _sync(bool moving, Duration length) {
    if (moving) {
      if (_timer != null || _settled) return;
      final last = length.inMilliseconds * fps ~/ 1000;
      // Timer ticks count periods gone by, also when one fires late.
      _timer =
          Timer.periodic(const Duration(microseconds: 1000000 ~/ fps), (t) {
        _time.value = _base + t.tick / fps;
        if (t.tick >= last) {
          _stop();
          _settled = true;
        }
      });
    } else {
      _stop();
      _settled = false;
    }
  }

  void _stop() {
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    _base = _time.value;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _time.dispose();
    super.dispose();
  }

  Widget _paint(LiveGroupStyle style) => RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: CustomPaint(
            painter: LiveStylePainter(style, _time),
            child: const SizedBox.expand(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final touch = _touch;
    final moving = (widget.animate || touch) &&
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    final length = widget.animate ? movesFor : touchMovesFor;
    // After the frame: never start or stop during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(moving, length);
    });
    if (widget.style case final style?) return _paint(style);
    return ValueListenableBuilder<List<LiveGroupStyle>>(
      valueListenable: LiveGroupStyles.instance.styles,
      builder: (context, _, __) {
        final style = LiveGroupStyles.instance.styleOf(widget.colorId);
        return style == null ? const SizedBox.shrink() : _paint(style);
      },
    );
  }
}

/// Draws a [LiveGroupStyle] at time [time] (seconds). Every particle's
/// place comes from its seed and the time alone, so a still row is one
/// frame and a moving one never keeps state.
class LiveStylePainter extends CustomPainter {
  LiveStylePainter(this.style, this.time) : super(repaint: time);

  final LiveGroupStyle style;
  final ValueListenable<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time.value;
    final rect = Offset.zero & size;
    if (style.fade.isNotEmpty) {
      var alpha = 1.0;
      if (style.pulse > 0) {
        alpha = 0.72 + 0.28 * math.sin(t * style.pulse * 2 * math.pi);
      }
      final colors = [
        for (final c in style.fade.length == 1
            ? [style.fade.first, style.fade.first.withValues(alpha: 0)]
            : style.fade)
          c.withValues(alpha: c.a * alpha),
      ];
      canvas.drawRect(rect,
          Paint()..shader = LinearGradient(colors: colors).createShader(rect));
    }
    final seed = style.id.hashCode & 0x7fffffff;
    for (var l = 0; l < style.layers.length; l++) {
      _LayerPainter(canvas, size, style.layers[l], seed * 31 + l, t).paint();
    }
  }

  @override
  bool shouldRepaint(LiveStylePainter old) =>
      old.style != style || old.time != time;
}

/// A particle's fixed numbers, 0..1, from its seed.
double _r(int seed, int i, int k) {
  var h = (seed * 73856093) ^ (i * 19349663) ^ (k * 83492791);
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  return (h & 0xFFFFFF) / 0x1000000;
}

double _frac(double v) => v - v.floorToDouble();

class _LayerPainter {
  _LayerPainter(this.canvas, this.size, this.layer, this.seed, this.t);

  final Canvas canvas;
  final Size size;
  final LiveStyleLayer layer;
  final int seed;
  final double t;

  double get w => size.width;
  double get h => size.height;

  double _lerp(double a, double b, double f) => a + (b - a) * f;
  double _bandX(double f) => w * _lerp(layer.xBand.$1, layer.xBand.$2, f);
  double _bandY(double f) => h * _lerp(layer.yBand.$1, layer.yBand.$2, f);

  void paint() {
    if (layer.motion == 'wave') return _waves();
    if (layer.motion == 'burst') return _bursts();
    for (var i = 0; i < layer.count; i++) {
      _particle(i);
    }
  }

  void _particle(int i) {
    final r1 = _r(seed, i, 1), r2 = _r(seed, i, 2), r3 = _r(seed, i, 3);
    final r4 = _r(seed, i, 4), r5 = _r(seed, i, 5), r6 = _r(seed, i, 6);
    final r7 = _r(seed, i, 7);
    final s = _lerp(layer.minSize, layer.maxSize, r1);
    final v = layer.speed * _lerp(0.7, 1.3, r2);
    final color = layer.colors[(r3 * layer.colors.length).floor()];
    var opacity = _lerp(layer.minOpacity, layer.maxOpacity, r4);
    var angle =
        r5 * 2 * math.pi + layer.spin * t * 2 * math.pi * (r2 > 0.5 ? 1 : -1);
    final swing =
        layer.sway * math.sin(t * 1.4 * _lerp(0.6, 1.2, r2) + r5 * 2 * math.pi);
    double x, y;
    switch (layer.motion) {
      case 'fall' || 'rise':
        final span = h + 2 * s;
        final p = _frac(r5 + t * v / span);
        y = layer.motion == 'fall' ? -s + p * span : h + s - p * span;
        x = _bandX(r6) + swing + layer.tilt * (y - h / 2);
        if (layer.fadeOut) opacity *= 1 - p;
      case 'drift' || 'drift-left':
        final span = w + 2 * s;
        final p = _frac(r5 + t * v / span);
        x = layer.motion == 'drift' ? -s + p * span : w + s - p * span;
        y = _bandY(r7) + swing;
        if (layer.fadeOut) opacity *= 1 - p;
      case 'twinkle':
        x = _bandX(r6);
        y = _bandY(r7);
        final f = 0.5 + 0.5 * math.sin((t * v + r5) * 2 * math.pi);
        opacity *= 0.2 + 0.8 * f;
        return _shape(x, y, s * (0.75 + 0.25 * f), angle, color, opacity);
      case 'chase':
        // Evenly spaced lights; a bright one runs along every third.
        x = _bandX((i + 0.5) / layer.count);
        y = _bandY(0.5);
        final f = 0.5 + 0.5 * math.cos(2 * math.pi * (i / 3 - t * v));
        opacity *= 0.25 + 0.75 * f;
        return _shape(
            x, y, s, 0, layer.colors[i % layer.colors.length], opacity);
      case 'still':
        x = _bandX(layer.count == 1 ? 0.5 : i / (layer.count - 1));
        y = _bandY(0.5);
      case 'streak':
        return _streak(i, s, v, color, opacity, r5, r6, r2);
      case 'slide' || 'arc':
        final travel = (w + 2 * s) / math.max(v, 1);
        final cycle = travel + layer.gap * _lerp(0.6, 1.4, r2);
        final local = _frac(t / cycle + r5) * cycle;
        if (local > travel) return;
        final p = local / travel;
        x = -s + p * (w + 2 * s);
        if (layer.motion == 'arc') {
          y = h - s / 2 - 2 - math.sin(math.pi * p) * (h - s) * 0.85;
        } else {
          y = _bandY(r7);
          // A short trail behind a fast slide.
          for (var k = 3; k >= 1; k--) {
            _shape(x - k * s * 0.45, y, s * (1 - k * 0.12), angle, color,
                opacity * 0.18 * (4 - k));
          }
        }
      case 'bounce' || 'roll':
        final span = w + 2 * s;
        final p = _frac(r5 + t * v / span);
        x = -s + p * span;
        final floor = h - s / 2 - 1;
        if (layer.motion == 'bounce') {
          final hop = _lerp(36, 64, r6);
          y = floor - (math.sin(math.pi * x / hop)).abs() * (h - s) * 0.8;
        } else {
          y = floor;
        }
        angle = x / math.max(s / 2, 1);
      default:
        return;
    }
    _shape(x, y, s, angle, color, opacity);
  }

  /// A shooting star: across the row on a slant, then a pause.
  void _streak(int i, double s, double v, Color color, double opacity,
      double r5, double r6, double r2) {
    final length = w * 0.75;
    final travel = length / math.max(v, 1);
    final cycle = travel + layer.gap * _lerp(0.5, 1.5, r2);
    final local = _frac(t / cycle + r5) * cycle;
    if (local > travel) return;
    final p = local / travel;
    // Seeded by the pass: each one starts somewhere else.
    final pass = (t / cycle + r5).floor();
    final startX = w * _lerp(0.35, 1.05, _r(seed, i * 977 + pass, 8));
    final startY = h * _lerp(-0.2, 0.35, _r(seed, i * 977 + pass, 9));
    const dir = Offset(-0.9, 0.44);
    final head = Offset(startX, startY) + dir * (length * p);
    final fade = math.sin(math.pi * p);
    final tail = head - dir * (s * 9);
    canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(1, s * 0.32)
          ..shader = LinearGradient(colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: opacity * fade),
          ]).createShader(Rect.fromPoints(tail, head)));
    _shape(head.dx, head.dy, s, 0, color, opacity * fade);
  }

  /// Fireworks: rings of sparks from a new place each time.
  void _bursts() {
    final per = math.max(6, layer.count ~/ 2);
    final bursts = math.max(1, (layer.count / per).ceil());
    const travel = 1.1;
    for (var b = 0; b < bursts; b++) {
      final cycle = travel + layer.gap * _lerp(0.6, 1.4, _r(seed, b, 2));
      final offset = _r(seed, b, 5) * cycle;
      final local = (t + offset) % cycle;
      if (local > travel) continue;
      final pass = ((t + offset) / cycle).floor();
      final p = local / travel;
      final cx = _bandX(_r(seed, b * 131 + pass, 6));
      final cy = _bandY(_r(seed, b * 131 + pass, 7));
      final color = layer.colors[(b + pass) % layer.colors.length];
      final reach = h * 0.42 * (1 - math.pow(1 - p, 3));
      for (var k = 0; k < per; k++) {
        final a = 2 * math.pi * k / per + _r(seed, b, 9);
        final s = _lerp(layer.minSize, layer.maxSize, _r(seed, b * 31 + k, 1));
        _shape(cx + math.cos(a) * reach, cy + math.sin(a) * reach + p * p * 4,
            s * (1 - 0.5 * p), 0, color, layer.maxOpacity * (1 - p));
      }
    }
  }

  /// Soft bands that roll along the row (aurora, neon).
  void _waves() {
    for (var i = 0; i < layer.count; i++) {
      final color = layer.colors[i % layer.colors.length];
      final base = _bandY(_r(seed, i, 7));
      final amp = layer.sway == 0 ? h * 0.18 : layer.sway;
      final length = w * _lerp(0.55, 1.1, _r(seed, i, 6));
      final thick = _lerp(layer.minSize, layer.maxSize, _r(seed, i, 1));
      final phase = _r(seed, i, 5) * 2 * math.pi;
      final speed = layer.speed * _lerp(0.7, 1.3, _r(seed, i, 2));
      final top = Path(), path = Path();
      const steps = 24;
      for (var k = 0; k <= steps; k++) {
        final x = w * k / steps;
        final y = base +
            amp * math.sin(2 * math.pi * (x / length - t * speed) + phase);
        k == 0 ? top.moveTo(x, y) : top.lineTo(x, y);
      }
      path.addPath(top, Offset.zero);
      for (var k = steps; k >= 0; k--) {
        final x = w * k / steps;
        final y = base +
            thick +
            amp * math.sin(2 * math.pi * (x / length - t * speed) + phase);
        path.lineTo(x, y);
      }
      path.close();
      final opacity = _lerp(layer.minOpacity, layer.maxOpacity,
          0.5 + 0.5 * math.sin(t * speed * 2 * math.pi + phase));
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0),
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromLTWH(0, base - amp, w, thick + 2 * amp)));
    }
  }

  void _shape(
      double x, double y, double s, double angle, Color color, double opacity) {
    if (opacity <= 0.01) return;
    final c = color.withValues(alpha: (color.a * opacity).clamp(0, 1));
    final fill = Paint()..color = c;
    if (layer.glow) {
      // A big shape's glow stays close (a wide disc read as a blot).
      final g = s > 10 ? 0.7 : 1.0;
      canvas.drawCircle(Offset(x, y), s * 0.95 * g,
          Paint()..color = c.withValues(alpha: c.a * 0.16));
      canvas.drawCircle(Offset(x, y), s * 0.62 * g,
          Paint()..color = c.withValues(alpha: c.a * 0.22));
    }
    final shape = layer.shape;
    if (shape.startsWith('glyph:')) {
      final icon = liveStyleGlyphs[shape.substring(6)];
      if (icon != null) _glyph(icon, x, y, s, angle, c);
      return;
    }
    switch (shape) {
      case 'dot':
        canvas.drawCircle(Offset(x, y), s / 2, fill);
      case 'snowflake':
        _snowflake(x, y, s, angle, c);
      case 'star4':
        _star(x, y, s, angle, 4, 0.18, fill);
      case 'star5':
        _star(x, y, s, angle, 5, 0.45, fill);
      case 'spark':
        final p = Paint()
          ..color = c
          ..strokeWidth = math.max(1, s * 0.14)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x - s / 2, y), Offset(x + s / 2, y), p);
        canvas.drawLine(Offset(x, y - s / 2), Offset(x, y + s / 2), p);
      case 'heart':
        _heart(x, y, s, angle, fill);
      case 'bubble':
        canvas.drawCircle(
            Offset(x, y),
            s / 2,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.8, s * 0.09)
              ..color = c);
        canvas.drawCircle(
            Offset(x - s * 0.16, y - s * 0.16), s * 0.09, Paint()..color = c);
      case 'confetti':
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: s, height: s * 0.45),
            fill);
        canvas.restore();
      case 'balloon':
        canvas.drawLine(
            Offset(x, y + s * 0.55),
            Offset(x + math.sin(angle) * s * 0.2, y + s * 1.25),
            Paint()
              ..color = c.withValues(alpha: c.a * 0.6)
              ..strokeWidth = 0.8);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(x, y), width: s * 0.82, height: s * 1.05),
            fill);
        canvas.drawCircle(Offset(x - s * 0.15, y - s * 0.2), s * 0.1,
            Paint()..color = Colors.white.withValues(alpha: 0.45 * opacity));
      case 'puck':
        final r =
            Rect.fromCenter(center: Offset(x, y), width: s, height: s * 0.42);
        canvas.drawOval(r.shift(Offset(0, s * 0.08)), fill);
        canvas.drawOval(
            r,
            Paint()
              ..color =
                  Color.lerp(c, Colors.white, 0.25)!.withValues(alpha: c.a));
      case 'dash':
        // Along the way it moves (tilt), a fast streak of rain / speed.
        final along = layer.motion == 'drift' || layer.motion == 'drift-left'
            ? const Offset(1, 0)
            : Offset(layer.tilt, 1) / math.sqrt(1 + layer.tilt * layer.tilt);
        canvas.drawLine(
            Offset(x, y) - along * (s / 2),
            Offset(x, y) + along * (s / 2),
            Paint()
              ..color = c
              ..strokeWidth = 1.1
              ..strokeCap = StrokeCap.round);
      case 'vline':
        canvas.drawRect(Rect.fromLTWH(x - s / 2, 0, s, h), fill);
      case 'hline':
        canvas.drawRect(Rect.fromLTWH(0, y - s / 2, w, s), fill);
      case 'band':
        canvas.drawRect(Rect.fromLTWH(x - s / 2, 0, s, h), fill);
      case 'char':
        final chars = layer.chars.isEmpty ? '01' : layer.chars;
        final pick =
            (_r(seed, (x * 0.1).floor(), (t * 4).floor()) * chars.length)
                .floor();
        _text(chars[pick % chars.length], null, x, y, s, 0, c);
    }
  }

  void _snowflake(double x, double y, double s, double angle, Color c) {
    final p = Paint()
      ..color = c
      ..strokeWidth = math.max(0.9, s * 0.11)
      ..strokeCap = StrokeCap.round;
    final r = s / 2;
    for (var k = 0; k < 6; k++) {
      final a = angle + k * math.pi / 3;
      final dir = Offset(math.cos(a), math.sin(a));
      final tip = Offset(x, y) + dir * r;
      canvas.drawLine(Offset(x, y), tip, p);
      if (s >= 6) {
        final mid = Offset(x, y) + dir * (r * 0.55);
        for (final side in const [-1, 1]) {
          final b = a + side * math.pi / 4;
          canvas.drawLine(
              mid, mid + Offset(math.cos(b), math.sin(b)) * (r * 0.38), p);
        }
      }
    }
  }

  void _star(double x, double y, double s, double angle, int points,
      double inner, Paint paint) {
    final path = Path();
    final outer = s / 2;
    for (var k = 0; k < points * 2; k++) {
      final r = k.isEven ? outer : outer * inner;
      final a = angle - math.pi / 2 + k * math.pi / points;
      final pt = Offset(x + math.cos(a) * r, y + math.sin(a) * r);
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _heart(double x, double y, double s, double angle, Paint paint) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(math.sin(angle) * 0.35);
    final r = s / 2;
    final path = Path()
      ..moveTo(0, r * 0.9)
      ..cubicTo(-r * 1.3, -r * 0.1, -r * 0.6, -r * 1.15, 0, -r * 0.4)
      ..cubicTo(r * 0.6, -r * 1.15, r * 1.3, -r * 0.1, 0, r * 0.9)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _glyph(
          IconData icon, double x, double y, double s, double angle, Color c) =>
      _text(String.fromCharCode(icon.codePoint), icon.fontFamily, x, y, s,
          angle, c);

  void _text(String text, String? family, double x, double y, double s,
      double angle, Color c) {
    final painter = _TextCache.get(text, family, s, c);
    canvas.save();
    canvas.translate(x, y);
    if (angle != 0) canvas.rotate(angle);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }
}

/// Laid-out glyphs by text, size and colour (alpha in 16 steps): a moving
/// row draws the same few every frame.
class _TextCache {
  // A map literal keeps insertion order: the oldest goes first.
  static final _cache = <String, TextPainter>{};

  static TextPainter get(String text, String? family, double s, Color c) {
    final size = s.roundToDouble().clamp(4, 80).toDouble();
    final alpha = ((c.a * 15).round() / 15).clamp(0.0, 1.0);
    final color = c.withValues(alpha: alpha);
    final key = '$text|$family|$size|${color.toARGB32()}';
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: family,
          fontSize: size,
          height: 1,
          color: color,
          fontWeight: family == null ? FontWeight.w700 : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _cache[key] = painter;
    if (_cache.length > 400) {
      _cache.remove(_cache.keys.first)?.dispose();
    }
    return painter;
  }
}
