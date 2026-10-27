import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Floating name bubbles for a title's cast, drawn over a detail page's
/// artwork or its automatic trailer (the Cast button on the movie, show and
/// Media Hub movie pages). [visible] fades them in one after another and
/// back out; while shown they drift gently.
///
/// Fills its parent and ignores pointers/focus, so the page's buttons and
/// D-pad order never change. Plain translucent fills, no blur (weak Fire
/// Sticks). It sits in the detail subtree, so it floats over a playing
/// trailer without touching it — except on Fire TV, whose WebView draws
/// a YouTube preview above all Flutter UI (`youtube_platform_view.dart`).
class CastBubbles extends StatefulWidget {
  const CastBubbles({
    super.key,
    required this.names,
    required this.visible,
    required this.area,
    this.scale = 1,
  });

  final List<String> names;
  final bool visible;

  /// Where the bubbles float, as fractions of the parent (0..1 on each side).
  final Rect area;
  final double scale;

  /// At most this many bubbles (provider cast strings can be very long).
  static const maxNames = 8;

  /// The page area right of the title text, above the buttons / episodes.
  static const wideArea = Rect.fromLTRB(0.6, 0.1, 0.97, 0.6);

  /// Over the phone layout's top image.
  static const narrowArea = Rect.fromLTRB(0.04, 0.09, 0.96, 0.3);

  /// Names from a provider's `cast` string ("A, B, C") — trimmed, de-duplicated.
  static List<String> parseNames(String? raw) =>
      raw == null ? const [] : namesFrom(raw.split(RegExp(r'\s*[,;|]\s*')));

  static List<String> namesFrom(Iterable<String> raw) {
    final seen = <String>{};
    final out = <String>[];
    for (final n in raw) {
      final name = n.trim();
      if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
      out.add(name);
      if (out.length == maxNames) break;
    }
    return out;
  }

  @override
  State<CastBubbles> createState() => _CastBubblesState();
}

/// Scattered resting spots inside [CastBubbles.area] (alignment fractions),
/// so up to eight names don't stack in a column.
const _slots = <Offset>[
  Offset(0.12, 0.06),
  Offset(0.78, 0.0),
  Offset(0.44, 0.28),
  Offset(0.96, 0.36),
  Offset(0.06, 0.56),
  Offset(0.64, 0.66),
  Offset(0.3, 0.94),
  Offset(0.9, 1.0),
];

class _CastBubblesState extends State<CastBubbles>
    with TickerProviderStateMixin {
  late final _show = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    reverseDuration: const Duration(milliseconds: 650),
    value: widget.visible ? 1 : 0,
  )..addStatusListener(_onStatus);

  // Drifts only while something is on screen.
  late final _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));

  @override
  void initState() {
    super.initState();
    if (widget.visible) _drift.repeat();
  }

  @override
  void didUpdateWidget(CastBubbles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    if (widget.visible) {
      if (!_drift.isAnimating) _drift.repeat();
      _show.forward();
    } else {
      _show.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _drift.stop();
      if (mounted) setState(() {}); // drop the hidden bubbles
    }
  }

  @override
  void dispose() {
    _show.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.names;
    if (names.isEmpty || (!widget.visible && _show.isDismissed)) {
      return const SizedBox.shrink();
    }
    final area = widget.area;
    final s = widget.scale;
    return IgnorePointer(
      child: ExcludeFocus(
        child: RepaintBoundary(
          child: LayoutBuilder(builder: (context, c) {
            final rect = Rect.fromLTRB(
              area.left * c.maxWidth,
              area.top * c.maxHeight,
              area.right * c.maxWidth,
              area.bottom * c.maxHeight,
            );
            return Stack(children: [
              Positioned.fromRect(
                rect: rect,
                child: Stack(children: [
                  for (var i = 0; i < names.length; i++)
                    _buildBubble(i, names[i], s),
                ]),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _buildBubble(int i, String name, double s) {
    final count = widget.names.length;
    final slot = _slots[i % _slots.length];
    // Staggered: each bubble takes its own slice of the show animation.
    final start = count <= 1 ? 0.0 : 0.45 * i / (count - 1);
    final popIn =
        Interval(start, math.min(start + 0.55, 1), curve: Curves.easeOutBack);
    final fadeOut = Interval(start * 0.6, math.min(start * 0.6 + 0.6, 1),
        curve: Curves.easeIn);
    final phase = i * 0.37;
    final bubble = _Bubble(name: name, scale: s);
    return Align(
      alignment: Alignment(slot.dx * 2 - 1, slot.dy * 2 - 1),
      child: AnimatedBuilder(
        animation: Listenable.merge([_show, _drift]),
        child: bubble,
        builder: (context, child) {
          final t = (_show.status == AnimationStatus.reverse ? fadeOut : popIn)
              .transform(_show.value);
          final a = 2 * math.pi * (_drift.value + phase);
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(
                math.cos(a) * 4 * s,
                math.sin(a) * 6 * s + (1 - t) * 18 * s,
              ),
              child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
            ),
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.name, required this.scale});

  final String name;
  final double scale;

  String get _initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = [
      if (parts.isNotEmpty) parts.first.characters.first,
      if (parts.length > 1) parts.last.characters.first,
    ];
    return letters.join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = scale;
    final dot = 26 * s;
    return Container(
      padding: EdgeInsets.fromLTRB(4 * s, 4 * s, 14 * s, 4 * s),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(dot),
        border: Border.all(
            color: scheme.primary.withValues(alpha: 0.7), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: scheme.primary.withValues(alpha: 0.22),
              blurRadius: 14 * s),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dot,
            height: dot,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.25), Colors.black),
            ),
            child: Text(
              _initials,
              style: TextStyle(
                color: scheme.primary,
                fontSize: 10.5 * s,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 8 * s),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 170 * s),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13 * s,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
