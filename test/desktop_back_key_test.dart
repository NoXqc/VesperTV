import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/desktop_back_key.dart';

/// A computer keyboard's Esc / Backspace = Back (a Windows viewer with a
/// K400, 2026-11-14): pops through the screen's PopScope, never steals a
/// key a widget handles, never leaves a text field on Backspace.
void main() {
  final nav = GlobalKey<NavigatorState>();

  setUp(() => DesktopBackKey.install(nav));
  tearDown(DesktopBackKey.reset);

  Future<void> open(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(body: Text('home')),
    ));
    nav.currentState!.push(MaterialPageRoute(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  testWidgets('Esc and Backspace go back', (tester) async {
    await open(tester,
        const Scaffold(body: Focus(autofocus: true, child: Text('page'))));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('page'), findsNothing);

    nav.currentState!.push(MaterialPageRoute(
        builder: (_) =>
            const Scaffold(body: Focus(autofocus: true, child: Text('page')))));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.text('page'), findsNothing);
  });

  testWidgets('a PopScope decides, like the remote\'s Back', (tester) async {
    var asked = 0;
    await open(
        tester,
        PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) asked++;
          },
          child: const Scaffold(
              body: Focus(autofocus: true, child: Text('player'))),
        ));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(find.text('player'), findsOneWidget);
  });

  testWidgets('a widget that handles Esc keeps it', (tester) async {
    var panelClosed = 0;
    await open(
        tester,
        Scaffold(
          body: Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event.logicalKey != LogicalKeyboardKey.escape) {
                return KeyEventResult.ignored;
              }
              if (event is KeyDownEvent) panelClosed++;
              return KeyEventResult.handled;
            },
            child: const Text('panel'),
          ),
        ));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(panelClosed, 1);
    expect(find.text('panel'), findsOneWidget, reason: 'not popped as well');
  });

  testWidgets('Backspace in a text field edits, never leaves', (tester) async {
    final controller = TextEditingController(text: 'abc');
    addTearDown(controller.dispose);
    await open(
        tester,
        Scaffold(
            body: TextField(
                controller: controller, autofocus: true, readOnly: true)));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
