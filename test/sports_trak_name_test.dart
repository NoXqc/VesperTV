import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/sports_trak_name.dart';

// The TV home's Sports Trak tab: "Sports" with a small gold "Trak" raised
// after it, on one line (owner, 2026-11-17: as two words it took two lines).
void main() {
  testWidgets('one line in a narrow tab, Trak in gold, read as Sports Trak',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(
        child: SizedBox(
          width: 90,
          child: SportsTrakName(
              style: TextStyle(fontSize: 20, color: Colors.white)),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    final trak = tester.widget<Text>(find.text('Trak'));
    expect(trak.style!.color, SportsTrakName.gold);
    expect(trak.style!.fontSize, lessThan(20));
    // Shrunk to fit, never wrapped: the label is one line high.
    expect(tester.getSize(find.byType(SportsTrakName)).height, lessThan(26));
    expect(find.bySemanticsLabel('Sports Trak'), findsOneWidget);
  });
}
