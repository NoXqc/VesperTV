import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/refined_finish.dart';
import 'package:nox_iptv/utils/tv_theme.dart';

// A screen that builds its Theme on every build (the TV home screen) must get
// an equal ThemeData each time, or `Theme` rebuilds everything under it: a
// 1.2 s frame on a group change on the Homatics (2026-11-12).
void main() {
  ThemeData build(bool refined) => RefinedFinish.apply(
      ThemeData(colorScheme: const ColorScheme.dark(), useMaterial3: true),
      refined);

  for (final refined in [false, true]) {
    test('the same inputs give the same theme (refined $refined)', () {
      expect(identical(build(refined), build(refined)), isTrue);
    });
  }

  test('the finish switch still changes the theme', () {
    expect(build(true) == build(false), isFalse);
    expect(build(true).extension<RefinedFinish>()?.enabled, isTrue);
    expect(build(false).extension<RefinedFinish>()?.enabled, isFalse);
  });

  // withTvThemeIfNeeded (Sports Trak, the player, Search...): its button
  // styles hold closures, so it must not build a new theme per build.
  for (final refined in [false, true]) {
    test('the TV theme is built once per palette (refined $refined)', () {
      final palette = AppConstants.cyberpunkPalettes.first;
      expect(
          identical(tvThemeFor(palette, refined), tvThemeFor(palette, refined)),
          isTrue);
    });
  }
}
