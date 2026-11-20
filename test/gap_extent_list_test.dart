import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/gap_extent_list.dart';

/// [GapExtentList]: fixed rows with one taller row (the Timeline guide's
/// programme details open under it).
void main() {
  const rowExtent = 50.0;
  const count = 200;

  Future<ScrollController> pumpList(WidgetTester tester,
      {int? gapAfter, double gap = 0, ScrollController? controller}) async {
    final scroll = controller ?? ScrollController();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: CustomScrollView(
            controller: scroll,
            slivers: [
              GapExtentList(
                rowExtent: rowExtent,
                gapAfter: gapAfter,
                gapExtent: gap,
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(height: rowExtent, child: Text('row $i')),
                  ),
                  childCount: count,
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    return scroll;
  }

  double topOf(WidgetTester tester, int i) =>
      tester.getTopLeft(find.text('row $i')).dy;

  testWidgets('without a gap it lays out like a fixed-extent list',
      (tester) async {
    final scroll = await pumpList(tester);
    final origin = topOf(tester, 0);
    expect(topOf(tester, 3) - origin, 3 * rowExtent);
    expect(scroll.position.maxScrollExtent, count * rowExtent - 400);
    scroll.jumpTo(5000);
    await tester.pump();
    expect(find.text('row 99'), findsNothing);
    expect(find.text('row 100'), findsOneWidget);
    expect(topOf(tester, 100), origin);
  });

  testWidgets('rows after the gap move down by it, the rest stay',
      (tester) async {
    final scroll = await pumpList(tester, gapAfter: 2, gap: 120);
    final origin = topOf(tester, 0);
    expect(topOf(tester, 2) - origin, 2 * rowExtent);
    expect(topOf(tester, 3) - origin, 3 * rowExtent + 120);
    expect(topOf(tester, 4) - origin, 4 * rowExtent + 120);
    // The gapped row's child gets the taller slot.
    final slot = tester.getSize(find
        .ancestor(of: find.text('row 2'), matching: find.byType(Align))
        .first);
    expect(slot.height, rowExtent + 120);
    expect(scroll.position.maxScrollExtent, count * rowExtent + 120 - 400);
  });

  testWidgets('scrolled into and past the gap, the right rows are built',
      (tester) async {
    final scroll = await pumpList(tester, gapAfter: 10, gap: 130);
    // Inside the gap: row 10 starts the view (its slot is 180 tall).
    scroll.jumpTo(10 * rowExtent + 100);
    await tester.pump();
    expect(find.text('row 10'), findsOneWidget);
    expect(find.text('row 9'), findsNothing);
    // Exactly at the gap's end: row 11 is the first one.
    scroll.jumpTo(11 * rowExtent + 130);
    await tester.pump();
    expect(find.text('row 10'), findsNothing);
    expect(
        topOf(tester, 11), tester.getTopLeft(find.byType(CustomScrollView)).dy);
    // The end of the list.
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(find.text('row ${count - 1}'), findsOneWidget);
    final listBottom = tester.getBottomLeft(find.byType(CustomScrollView)).dy;
    expect(tester.getBottomLeft(find.text('row ${count - 1}')).dy, listBottom);
  });

  testWidgets('opening and closing the gap keeps each row\'s element',
      (tester) async {
    final scroll = ScrollController();
    await pumpList(tester, controller: scroll);
    final before = tester.element(find.text('row 3'));
    await pumpList(tester, gapAfter: 3, gap: 90, controller: scroll);
    expect(tester.element(find.text('row 3')), same(before));
    final origin = topOf(tester, 0);
    expect(topOf(tester, 4) - origin, 4 * rowExtent + 90);
    await pumpList(tester, controller: scroll);
    expect(tester.element(find.text('row 3')), same(before));
    expect(topOf(tester, 4) - origin, 4 * rowExtent);
  });

  testWidgets('a gap after the last row adds to the end', (tester) async {
    final scroll = await pumpList(tester, gapAfter: count - 1, gap: 60);
    expect(scroll.position.maxScrollExtent, count * rowExtent + 60 - 400);
    final none = await pumpList(tester, gapAfter: count + 5, gap: 60);
    expect(none.position.maxScrollExtent, count * rowExtent - 400);
  });
}
