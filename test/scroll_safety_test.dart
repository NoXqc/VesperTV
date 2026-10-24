import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/utils/scroll_safety.dart';

void main() {
  testWidgets(
      'attached guide position is not reset until content metrics exist',
      (tester) async {
    late ScrollController controller;
    var skipped = false;
    var reset = false;
    controller = ScrollController(
        initialScrollOffset: 160,
        onAttach: (position) {
          expect(position.hasContentDimensions, isFalse);
          skipped = !jumpToIfLaidOut(controller, 0);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            reset = jumpToIfLaidOut(controller, 0);
          });
        });
    addTearDown(controller.dispose);
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            child: const SizedBox(height: 2000))));
    expect(skipped, isTrue);
    expect(reset, isTrue);
    expect(controller.offset, 0);
    expect(tester.takeException(), isNull);
    controller.jumpTo(250);
    expect(jumpToIfLaidOut(controller, 0), isTrue);
    expect(controller.offset, 0);
    await tester.pumpWidget(const SizedBox());
    expect(jumpToIfLaidOut(controller, 0), isFalse);
  });

  testWidgets('shared controller waits for every attached position',
      (tester) async {
    late ScrollController controller;
    var waits = 0;
    controller = ScrollController(onAttach: (_) {
      if (!jumpToIfLaidOut(controller, 0)) waits++;
    });
    addTearDown(controller.dispose);
    await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: [
          for (var i = 0; i < 2; i++)
            Expanded(
                child: SingleChildScrollView(
                    controller: controller,
                    child: const SizedBox(height: 2000))),
        ])));
    expect(waits, 2);
    expect(jumpToIfLaidOut(controller, 0), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
