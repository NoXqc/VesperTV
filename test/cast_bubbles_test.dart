import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/widgets/cast_bubbles.dart';

Widget _host(bool visible, {List<String>? names}) => MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          const Center(child: FocusScope(child: Text('page'))),
          CastBubbles(
            names: names ?? const ['Tim Robbins', 'Morgan Freeman'],
            visible: visible,
            area: CastBubbles.wideArea,
          ),
        ]),
      ),
    );

void main() {
  test('parseNames trims, de-duplicates and caps the provider string', () {
    expect(CastBubbles.parseNames(null), isEmpty);
    expect(CastBubbles.parseNames(' A ,B;  b| C,,'), ['A', 'B', 'C']);
    final many = List.generate(20, (i) => 'Actor $i').join(', ');
    expect(CastBubbles.parseNames(many), hasLength(CastBubbles.maxNames));
  });

  testWidgets('fades in when shown and out when hidden', (tester) async {
    await tester.pumpWidget(_host(false));
    expect(find.text('Tim Robbins'), findsNothing);

    await tester.pumpWidget(_host(true));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Tim Robbins'), findsOneWidget);
    expect(find.text('Morgan Freeman'), findsOneWidget);
    expect(find.text('TR'), findsOneWidget); // initials

    await tester.pumpWidget(_host(false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Tim Robbins'), findsOneWidget); // still fading
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Tim Robbins'), findsNothing);
  });

  testWidgets('hiding right after showing never leaves bubbles behind',
      (tester) async {
    await tester.pumpWidget(_host(false));
    await tester.pumpWidget(_host(true));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpWidget(_host(false));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('Tim Robbins'), findsNothing);
  });

  testWidgets('never takes focus or taps', (tester) async {
    await tester.pumpWidget(_host(true));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(
        find.ancestor(
            of: find.text('Tim Robbins'), matching: find.byType(IgnorePointer)),
        findsWidgets);
    expect(
        find.ancestor(
            of: find.text('Tim Robbins'), matching: find.byType(ExcludeFocus)),
        findsWidgets);
  });

  testWidgets('no names, nothing drawn', (tester) async {
    await tester.pumpWidget(_host(true, names: const []));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byType(Opacity), findsNothing);
  });
}
