import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/baked_backdrop.dart';

/// Full-screen gradients are painted once into a small image (the
/// Homatics spent 20 ms of every frame redrawing two of them, 2026-11-21).
void main() {
  const glow = BoxDecoration(
    gradient: LinearGradient(colors: [Colors.red, Colors.transparent]),
  );

  Widget page(List<Widget> children) => MaterialApp(
          home: Column(children: [
        for (final c in children) SizedBox(width: 800, height: 250, child: c)
      ]));

  testWidgets('drawn as one small image, shared by the same backdrop',
      (tester) async {
    await tester.pumpWidget(page(const [
      BakedBackdrop(layers: [glow]),
      BakedBackdrop(layers: [glow]),
    ]));
    final images = tester
        .widgetList<RawImage>(find.byType(RawImage))
        .map((r) => r.image!)
        .toList();
    expect(images, hasLength(2));
    expect(images.first.width, 100);
    expect(images.first.height, 32);
    expect(images.first.isCloneOf(images.last), isTrue);
    expect(find.byType(DecoratedBox), findsNothing);
  });
}
