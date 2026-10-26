import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Opt-in paint only. Never adds a layer, filter, layout widget or focus node.
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
    const panel = Color(0xF2151618);
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
                scheme.primaryContainer.withValues(alpha: 0.14), Colors.black);
          }
          return original?.backgroundColor?.resolve(states);
        }),
      );

  /// Preserve every geometry field, especially border padding and image bounds.
  /// Artwork receives only a quieter existing focus shadow, never a colour wash.
  static BoxDecoration decorate(BuildContext context, BoxDecoration original,
      {bool focused = false, bool artwork = false, bool focusOnly = false}) {
    if (!of(context) || (focusOnly && !focused)) return original;
    final shadows = focused
        ? original.boxShadow
            ?.map((shadow) => shadow.copyWith(
                color: shadow.color
                    .withValues(alpha: math.min(shadow.color.a, 0.22)),
                blurRadius: math.min(shadow.blurRadius, 8),
                spreadRadius: math.min(shadow.spreadRadius, 1)))
            .toList()
        : original.boxShadow;
    if (artwork || original.image != null) {
      return original.copyWith(boxShadow: shadows);
    }
    final base = surface(context, original.color ?? Colors.black);
    final tint = focused
        ? Color.alphaBlend(
            Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.14),
            base)
        : base;
    return original.copyWith(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(
              Colors.white.withValues(alpha: focused ? 0.08 : 0.045), tint),
          tint,
          base,
        ],
        stops: const [0, 0.18, 1],
      ),
      boxShadow: shadows,
    );
  }

  /// Readable over a bright video frame; does not sample the native video plane.
  static Color surface(BuildContext context, Color original) {
    if (!of(context)) return original;
    // Low-alpha white/accent fills were designed over OLED black. Resolve that
    // appearance first; raising their alpha directly would create a white panel.
    final resolved = Color.alphaBlend(original, const Color(0xFF08090B));
    final tinted = Color.alphaBlend(const Color(0x071C2026), resolved);
    return tinted.withValues(alpha: math.max(original.a, 0.82));
  }

  @override
  RefinedFinish copyWith({bool? enabled}) =>
      RefinedFinish(enabled: enabled ?? this.enabled);

  @override
  RefinedFinish lerp(covariant RefinedFinish? other, double t) =>
      t < 0.5 || other == null ? this : other;
}
