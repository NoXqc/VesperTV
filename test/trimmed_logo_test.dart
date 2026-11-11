import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/trimmed_logo.dart';

/// Collection packs centre their title logos on a big transparent canvas:
/// the hero measures the visible part and draws only that (owner,
/// 2026-11-11: the NETFLIX wordmark came out tiny).
void main() {
  testWidgets('measures the visible part of a padded logo', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      // A 200x100 canvas, transparent, with a wordmark at 40..160 x 30..60.
      Canvas(recorder).drawRect(
          const Rect.fromLTRB(40, 30, 160, 60), Paint()..color = Colors.white);
      final image = await recorder.endRecording().toImage(200, 100);
      final box = await TrimmedLogo.measure('test://padded', image);
      expect(box, const Rect.fromLTRB(40, 30, 160, 60));

      final blank = ui.PictureRecorder();
      Canvas(blank);
      final empty = await blank.endRecording().toImage(20, 10);
      expect(await TrimmedLogo.measure('test://empty', empty),
          const Rect.fromLTWH(0, 0, 20, 10),
          reason: 'nothing visible: the whole picture');
      image.dispose();
      empty.dispose();
    });
  });

  test('brand colours by service name; others stay white', () {
    expect(TrimmedLogo.brandColor('Netflix'), const Color(0xFFE50914));
    expect(TrimmedLogo.brandColor('Prime Video'), isNotNull);
    expect(TrimmedLogo.brandColor('HBO Max'), isNotNull);
    expect(TrimmedLogo.brandColor('Disney Plus'), isNull);
    expect(TrimmedLogo.brandColor('Apple TV'), isNull);
    expect(TrimmedLogo.brandColor('Netflixing'), isNull,
        reason: 'whole words only');
  });

  testWidgets('the name shows until the logo loads', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: TrimmedLogo(
            url: 'https://example.invalid/logo.webp',
            height: 64,
            maxWidth: 320,
            fallback: Text('Netflix'))));
    expect(find.text('Netflix'), findsOneWidget);
  });
}
