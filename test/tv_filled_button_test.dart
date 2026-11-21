import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/tv_theme.dart';

/// On a TV a filled button is see-through with a thin outline until it has
/// focus; the stock solid pastel fill looked focused when it wasn't (owner
/// photos, 2026-11-21).
void main() {
  final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFD4AF37), brightness: Brightness.dark);
  final style = tvFilledButtonStyle(scheme);

  test('not focused: no fill, thin outline', () {
    expect(style.backgroundColor!.resolve({}), Colors.transparent);
    expect(style.side!.resolve({})!.width, 1);
    expect(style.elevation!.resolve({}), 0);
  });

  test('focused: accent border, accent text, a glow', () {
    const focused = {WidgetState.focused};
    expect(style.backgroundColor!.resolve(focused), isNot(Colors.transparent));
    expect(style.side!.resolve(focused),
        BorderSide(color: scheme.primary, width: 2));
    expect(style.foregroundColor!.resolve(focused), scheme.primary);
    expect(style.elevation!.resolve(focused), greaterThan(0));
  });

  test('one style per scheme, so the theme compares equal', () {
    expect(identical(tvFilledButtonStyle(scheme), style), isTrue);
  });
}
