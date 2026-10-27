import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Reversible glass finish. Existing stable focus wrappers supply bounded blur;
/// decorations preserve geometry and never sample or reconfigure native video.
class RefinedFinish extends ThemeExtension<RefinedFinish> {
  const RefinedFinish({required this.enabled});
  final bool enabled;

  static bool of(BuildContext context) =>
      Theme.of(context).extension<RefinedFinish>()?.enabled ?? false;

  static ThemeData apply(ThemeData base, bool enabled) {
    final result = base.copyWith(extensions: [
      ...base.extensions.values.where((value) => value is! RefinedFinish),
      RefinedFinish(enabled: enabled),
    ]);
    if (!enabled) return result;
    const panel = Color(0xEE24272D);
    return result.copyWith(
      dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: panel, surfaceTintColor: Colors.transparent),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: panel,
          modalBackgroundColor: panel,
          surfaceTintColor: Colors.transparent),
      popupMenuTheme: base.popupMenuTheme
          .copyWith(color: panel, surfaceTintColor: Colors.transparent),
      filledButtonTheme: FilledButtonThemeData(
          style: _button(base.filledButtonTheme.style, base.colorScheme)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: _button(base.outlinedButtonTheme.style, base.colorScheme)),
      textButtonTheme: TextButtonThemeData(
          style: _button(base.textButtonTheme.style, base.colorScheme)),
      iconButtonTheme: IconButtonThemeData(
          style: _button(base.iconButtonTheme.style, base.colorScheme)),
    );
  }

  static ButtonStyle _button(ButtonStyle? original, ColorScheme scheme) =>
      (original ?? const ButtonStyle()).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused) &&
              !states.contains(WidgetState.disabled)) {
            return Color.alphaBlend(
                scheme.primaryContainer.withValues(alpha: 0.20),
                const Color(0xFF17191D));
          }
          return original?.backgroundColor?.resolve(states);
        }),
      );

  /// Brighter top reflections, bevelled rims and layered depth. Original
  /// border padding/radii are retained; dense guide cells stay focus-only.
  static BoxDecoration decorate(BuildContext context, BoxDecoration original,
      {bool focused = false, bool artwork = false, bool focusOnly = false}) {
    if (!of(context) || (focusOnly && !focused)) return original;
    final shadows = <BoxShadow>[
      if (focused)
        BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.42),
            blurRadius: 19,
            spreadRadius: 1),
      BoxShadow(
          color: Colors.black.withValues(alpha: focused ? 0.65 : 0.4),
          blurRadius: focused ? 18 : 11,
          offset: Offset(0, focused ? 7 : 4)),
    ];
    if (artwork || original.image != null) {
      return original.copyWith(boxShadow: shadows);
    }
    final base = surface(context, original.color ?? Colors.black);
    final tint = Color.alphaBlend(
        Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: focused ? 0.19 : 0.025),
        base);
    final painted = original.copyWith(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(
              Colors.white.withValues(alpha: focused ? 0.25 : 0.15), tint),
          Color.alphaBlend(Colors.white.withValues(alpha: 0.055), tint),
          tint,
          Color.alphaBlend(Colors.black.withValues(alpha: 0.18), base),
        ],
        stops: const [0, 0.09, 0.30, 1],
      ),
      boxShadow: shadows,
    );
    return _GlassDecoration(painted, rim: focused ? 0.68 : 0.32);
  }

  /// Always provide a foreground decoration so the image subtree keeps its slot
  /// when toggled. Only edge reflections are painted over artwork, never blur.
  static BoxDecoration artworkRim(BuildContext context, BorderRadius radius,
      {bool focused = false}) {
    final base = BoxDecoration(borderRadius: radius);
    return of(context)
        ? _GlassDecoration(base, rim: focused ? 0.7 : 0.32)
        : base;
  }

  /// Readable over a bright video frame; does not sample the native video plane.
  static Color surface(BuildContext context, Color original) {
    if (!of(context)) return original;
    // Low-alpha white/accent fills were designed over OLED black. Resolve that
    // appearance first; raising their alpha directly would create a white panel.
    final resolved = Color.alphaBlend(original, const Color(0xFF14171C));
    final tinted = Color.alphaBlend(const Color(0x267C8CA4), resolved);
    return tinted.withValues(alpha: math.max(original.a, 0.78));
  }

  @override
  RefinedFinish copyWith({bool? enabled}) =>
      RefinedFinish(enabled: enabled ?? this.enabled);

  @override
  RefinedFinish lerp(covariant RefinedFinish? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// A BoxDecoration with a painted bevel, not a layout-affecting extra border.
class _GlassDecoration extends BoxDecoration {
  _GlassDecoration(this.base, {required this.rim})
      : super(
            color: base.color,
            image: base.image,
            border: base.border,
            borderRadius: base.borderRadius,
            boxShadow: base.boxShadow,
            gradient: base.gradient,
            backgroundBlendMode: base.backgroundBlendMode,
            shape: base.shape);
  final BoxDecoration base;
  final double rim;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GlassPainter(this, onChanged);

  @override
  bool operator ==(Object other) =>
      other is _GlassDecoration && super == other && rim == other.rim;
  @override
  int get hashCode => Object.hash(super.hashCode, rim);
}

class _GlassPainter extends BoxPainter {
  _GlassPainter(this.glass, VoidCallback? onChanged)
      : basePainter = glass.base.createBoxPainter(onChanged),
        super(onChanged);
  final _GlassDecoration glass;
  final BoxPainter basePainter;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    basePainter.paint(canvas, offset, configuration);
    final size = configuration.size;
    if (size == null || size.shortestSide < 5) return;
    final rect = offset & size;
    final radius = glass.borderRadius
            ?.resolve(configuration.textDirection ?? TextDirection.ltr) ??
        BorderRadius.zero;
    Path edge(double inset) => Path()
      ..addPath(
          glass.shape == BoxShape.circle
              ? (Path()
                ..addOval(Rect.fromCircle(
                    center: rect.center,
                    radius: size.shortestSide / 2 - inset)))
              : (Path()..addRRect(radius.toRRect(rect.deflate(inset)))),
          Offset.zero);
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: glass.rim),
            Colors.white.withValues(alpha: glass.rim * 0.32),
            Colors.white.withValues(alpha: 0.035),
            Colors.white.withValues(alpha: glass.rim * 0.45)
          ],
          stops: const [
            0,
            0.35,
            0.7,
            1
          ]).createShader(rect);
    canvas.drawPath(edge(0.85), highlight);
    canvas.drawPath(
        edge(2.25),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = Colors.white.withValues(alpha: glass.rim * 0.16));
  }

  @override
  void dispose() {
    basePainter.dispose();
    super.dispose();
  }
}
