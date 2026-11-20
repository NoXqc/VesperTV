import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/detail_header.dart';

void main() {
  testWidgets('a focused pill keeps its width (no Wrap reflow)',
      (tester) async {
    final node = FocusNode();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: DetailPillButton(
            focusNode: node,
            icon: Icons.movie,
            label: 'Trailer anschauen jetzt',
            scale: 1,
            onPressed: () {},
          ),
        ),
      ),
    ));
    final before = tester.getSize(find.byType(DetailPillButton));
    node.requestFocus();
    await tester.pump();
    expect(tester.getSize(find.byType(DetailPillButton)), before);
    node.dispose();
  });
}
