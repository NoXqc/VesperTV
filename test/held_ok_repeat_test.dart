import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/held_ok_repeat.dart';
import 'package:nox_iptv/widgets/hold_to_activate.dart';

/// The Siri Remote sends a key-down at the click and a key-up at the
/// release, never a repeat in between: these tests press keys the same way
/// (sendKeyDownEvent ... pump ... sendKeyUpEvent).
void main() {
  HeldOkRepeat attach() {
    final repeat = HeldOkRepeat()..attach();
    addTearDown(repeat.detach);
    return repeat;
  }

  Future<List<KeyEvent>> pumpCounter(WidgetTester tester) async {
    final seen = <KeyEvent>[];
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Focus(
        focusNode: node,
        autofocus: true,
        onKeyEvent: (_, event) {
          seen.add(event);
          return KeyEventResult.handled;
        },
        child: const SizedBox.expand(),
      ),
    ));
    await tester.pump();
    return seen;
  }

  int repeats(List<KeyEvent> events) =>
      events.whereType<KeyRepeatEvent>().length;

  Future<(List<String>, Widget)> holdButton() async {
    final calls = <String>[];
    final button = HoldToActivate(
      onTap: () => calls.add('tap'),
      onHold: () => calls.add('hold'),
      child: TextButton(
        autofocus: true,
        onPressed: () => calls.add('pressed'),
        child: const Text('Game'),
      ),
    );
    return (calls, MaterialApp(home: Scaffold(body: Center(child: button))));
  }

  testWidgets('without it a held click opens nothing (the Apple TV bug)',
      (tester) async {
    final (calls, app) = await holdButton();
    await tester.pumpWidget(app);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(calls, ['tap']);
  });

  testWidgets('a held click opens the hold menu, without a tap',
      (tester) async {
    attach();
    final (calls, app) = await holdButton();
    await tester.pumpWidget(app);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 900));
    expect(calls, ['hold']);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(calls, ['hold']);
  });

  testWidgets('a quick click stays a tap and sends no repeat', (tester) async {
    final repeat = attach();
    final seen = await pumpCounter(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(seconds: 2));

    expect(repeats(seen), 0);
    expect(repeat.repeating, isFalse);
  });

  testWidgets('repeats like Android: first at 0.5 s, then every 50 ms',
      (tester) async {
    attach();
    final seen = await pumpCounter(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 450));
    expect(repeats(seen), 0);
    await tester.pump(const Duration(milliseconds: 50));
    expect(repeats(seen), 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(repeats(seen), 5);
    final repeat = seen.whereType<KeyRepeatEvent>().first;
    expect(repeat.logicalKey, LogicalKeyboardKey.enter);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 1));
    expect(repeats(seen), 5);
  });

  testWidgets('a key the platform repeats itself is left alone',
      (tester) async {
    final repeat = attach();
    final seen = await pumpCounter(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    expect(repeat.repeating, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(repeats(seen), 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
  });

  testWidgets('held arrows are not repeated (flutter-tvos does that)',
      (tester) async {
    final repeat = attach();
    final seen = await pumpCounter(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    expect(repeat.repeating, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(repeats(seen), 0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
  });

  testWidgets('another key pressed during the hold ends the repeats',
      (tester) async {
    final repeat = attach();
    final seen = await pumpCounter(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    final before = repeats(seen);
    expect(before, greaterThan(0));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    expect(repeat.repeating, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(repeats(seen), before);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
  });

  testWidgets('a hold menu opened by the hold swallows the rest of the press',
      (tester) async {
    attach();
    final picked = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: HoldToActivate(
              onTap: () {},
              onHold: () => showDialog<void>(
                context: context,
                builder: (_) => SwallowHeldActivate(
                  child: AlertDialog(
                    content: TextButton(
                      autofocus: true,
                      onPressed: () => picked.add('first row'),
                      child: const Text('Stats'),
                    ),
                  ),
                ),
              ),
              child: TextButton(
                autofocus: true,
                onPressed: () {},
                child: const Text('Game'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Stats'), findsOneWidget);
    // Still held: the repeats and the release land on the dialog.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(picked, isEmpty);

    // The next click is a real one.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(picked, ['first row']);
  });
}
