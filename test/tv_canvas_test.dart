import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/tv_canvas.dart';

void main() {
  testWidgets('Apple TV 1920x1080 lays out as a 960x540 TV box, scaled up',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late MediaQueryData seen;
    await tester.pumpWidget(TvCanvas(
      child: Builder(builder: (context) {
        seen = MediaQuery.of(context);
        return const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.bottomRight,
            child: SizedBox(key: Key('corner'), width: 96, height: 54),
          ),
        );
      }),
    ));
    expect(seen.size, const Size(960, 540));
    expect(seen.devicePixelRatio, 2);
    // 96x54 logical in the corner = 192x108 on the 1920x1080 screen.
    final rect = tester.getRect(find.byKey(const Key('corner')));
    expect(rect, const Rect.fromLTWH(1728, 972, 192, 108));
  });

  testWidgets('a TV box canvas (960x540) is left as is', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late MediaQueryData seen;
    await tester.pumpWidget(TvCanvas(
      child: Builder(builder: (context) {
        seen = MediaQuery.of(context);
        return const SizedBox();
      }),
    ));
    expect(seen.size, const Size(960, 540));
    expect(seen.devicePixelRatio, 2);
    expect(find.byType(FittedBox), findsNothing);
  });

  test('scale follows the short side', () {
    expect(TvCanvas.scaleFor(const Size(1920, 1080)), 2);
    expect(TvCanvas.scaleFor(const Size(3840, 2160)), 4);
    expect(TvCanvas.scaleFor(const Size(960, 540)), 1);
    expect(TvCanvas.scaleFor(const Size(1000, 560)), 1);
  });

  testWidgets('menus anchor in the canvas, not in screen pixels',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TvCanvas(
      child: MaterialApp(
        home: Stack(children: [
          Positioned(
            left: 100,
            top: 50,
            width: 40,
            height: 20,
            child: Container(key: const Key('button')),
          ),
        ]),
      ),
    ));
    final context = tester.element(find.byKey(const Key('button')));
    final box = context.findRenderObject()! as RenderBox;
    // The screen sees it at twice the place and size...
    expect(tester.getRect(find.byKey(const Key('button'))),
        const Rect.fromLTWH(200, 100, 80, 40));
    // ...the overlay, where the menu opens, at the app's own place.
    expect(overlayRectOf(context, box), const Rect.fromLTWH(100, 50, 40, 20));
  });
}
