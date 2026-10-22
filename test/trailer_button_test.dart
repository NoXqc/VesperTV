import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/trailer_service.dart';
import 'package:nox_iptv/widgets/trailer_button.dart';

void main() {
  testWidgets('missing handler hides the action; failed launch retains focus',
      (tester) async {
    final node = FocusNode();
    const request =
        TrailerRequest(title: 'Film', series: false, supplied: ['AbCdEfGhI12']);
    var available = false;
    var opened = 0;
    Widget page() => MaterialApp(
        home: Scaffold(
            body: TrailerButton(
                key: ValueKey(available),
                request: request,
                focusNode: node,
                available: (_) async => available,
                open: (_) async {
                  opened++;
                  return false;
                })));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('Trailer'), findsNothing);
    available = true;
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trailer'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(find.text('Unable to open trailer'), findsOneWidget);
    expect(node.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    node.dispose();
  });
}
