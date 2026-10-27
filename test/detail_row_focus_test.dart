import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/detail_header.dart';

void main() {
  testWidgets('Up/Down reach buttons wrapped onto the next row',
      (tester) async {
    // Resume, Trailer, Restart on row 1; Favorites, Cast on row 2 (TV photo).
    final nodes = List.generate(5, (i) => FocusNode(debugLabel: 'b$i'));
    await tester.pumpWidget(MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 340,
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final n in nodes)
              Focus(
                  focusNode: n, child: const SizedBox(width: 100, height: 40)),
          ]),
        ),
      ),
    ));
    nodes[0].requestFocus();
    await tester.pump();
    expect(detailNodeInRow(nodes, down: false), isNull); // -> back button
    expect(detailNodeInRow(nodes, down: true), nodes[3]);

    nodes[2].requestFocus(); // Restart: nearest below is Cast
    await tester.pump();
    expect(detailNodeInRow(nodes, down: true), nodes[4]);

    nodes[4].requestFocus();
    await tester.pump();
    expect(detailNodeInRow(nodes, down: true), isNull);
    expect(detailNodeInRow(nodes, down: false), nodes[1]);

    for (final n in nodes) {
      n.dispose();
    }
  });
}
