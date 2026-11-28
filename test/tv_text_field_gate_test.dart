import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/tv_text_field_gate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The D-pad must be able to leave a gated text field that has a cursor
/// (typed in once): Flutter's own arrow handling moved the cursor instead
/// and kept the remote on the field ("stuck in the text field").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FocusNode above, field, below;
  late TextEditingController controller;

  Future<void> pump(WidgetTester tester, {required bool tv}) async {
    above = FocusNode(debugLabel: 'above');
    field = FocusNode(debugLabel: 'field');
    below = FocusNode(debugLabel: 'below');
    controller = TextEditingController();
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage)..isTelevision = tv;
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: prefs,
      child: MaterialApp(
        home: Scaffold(
          body: Column(children: [
            TextButton(
                focusNode: above, onPressed: () {}, child: const Text('A')),
            TvTextFieldGate(
              focusNode: field,
              builder: (context, readOnly) => TextField(
                  controller: controller, focusNode: field, readOnly: readOnly),
            ),
            TextButton(
                focusNode: below, onPressed: () {}, child: const Text('B')),
          ]),
        ),
      ),
    ));
    // A field that was typed in: text and a cursor.
    controller.value = const TextEditingValue(
        text: 'nba', selection: TextSelection.collapsed(offset: 3));
    field.requestFocus();
    await tester.pumpAndSettle();
  }

  testWidgets(
      'TV: the keyboard closing ends typing and Down leaves (Google TV)',
      (tester) async {
    await pump(tester, tv: true);
    addTearDown(tester.view.reset);
    await tester.sendKeyEvent(LogicalKeyboardKey.select); // opens typing
    await tester.pumpAndSettle();
    TextField textField() => tester.widget<TextField>(find.byType(TextField));
    expect(textField().readOnly, isFalse);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(textField().readOnly, isFalse);
    tester.view.viewInsets = FakeViewPadding.zero; // Back closed it
    await tester.pumpAndSettle();
    expect(textField().readOnly, isTrue);
    expect(field.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(below.hasFocus, isTrue);
  });

  for (final inset in [0.0, 300.0]) {
    testWidgets('TV: editing ESPN2 keeps cursor arrows in Gboard; inset=$inset',
        (tester) async {
      await pump(tester, tv: true);
      addTearDown(tester.view.reset);
      controller.value = const TextEditingValue(
          text: 'ESPN2', selection: TextSelection.collapsed(offset: 5));
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
          tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
      expect(field.hasPrimaryFocus, isTrue);
      expect(controller.selection.baseOffset, 4);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(controller.selection.baseOffset, 3);
      expect(field.hasPrimaryFocus, isTrue);
      expect(HardwareKeyboard.instance.logicalKeysPressed,
          isNot(contains(LogicalKeyboardKey.arrowLeft)));
    });
  }

  testWidgets('TV: zero-inset keyboard yields only after explicit Back',
      (tester) async {
    await pump(tester, tv: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.select); // opens typing
    await tester.pumpAndSettle();
    TextField textField() => tester.widget<TextField>(find.byType(TextField));
    expect(textField().readOnly, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(field.hasPrimaryFocus, isTrue);
    expect(textField().readOnly, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(textField().readOnly, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(below.hasFocus, isTrue);
    expect(controller.selection.baseOffset, 3);
    expect(textField().readOnly, isTrue);
  });

  // Apple TV's keyboard is a full-screen page with the remote to itself;
  // Menu closes it without telling the app (no inset, no Back), so the
  // first arrow the app sees comes after it closed (Mycue66, TestFlight 954:
  // Search results unreachable, the remote stuck in the search box).
  testWidgets('Apple TV: an arrow after the keyboard closed leaves the field',
      (tester) async {
    TvTextFieldGate.debugFullScreenKeyboard = true;
    addTearDown(() => TvTextFieldGate.debugFullScreenKeyboard = null);
    await pump(tester, tv: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.select); // opens typing
    await tester.pumpAndSettle();
    TextField textField() => tester.widget<TextField>(find.byType(TextField));
    expect(textField().readOnly, isFalse);
    controller.value = const TextEditingValue(
        text: 'nba finals', selection: TextSelection.collapsed(offset: 10));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(below.hasFocus, isTrue);
    expect(textField().readOnly, isTrue);
    expect(TvTextFieldGate.isEditing(field), isFalse);
    expect(controller.text, 'nba finals');
    // OK on the field opens the keyboard again.
    field.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(textField().readOnly, isFalse);
  });

  testWidgets(
      "Apple TV: the screen's own Down (Search's rows) wins on the first press",
      (tester) async {
    TvTextFieldGate.debugFullScreenKeyboard = true;
    addTearDown(() => TvTextFieldGate.debugFullScreenKeyboard = null);
    final search = FocusNode(debugLabel: 'search');
    final firstResult = FocusNode(debugLabel: 'result 0');
    final other = FocusNode(debugLabel: 'nearest below');
    addTearDown(search.dispose);
    addTearDown(firstResult.dispose);
    addTearDown(other.dispose);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage)..isTelevision = true;
    // Like SearchScreen: Up / Down shortcuts around the whole page pick the
    // row themselves (the first result row, not the nearest widget below).
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: prefs,
      child: MaterialApp(
        home: CallbackShortcuts(
          bindings: {
            const TvNavigationActivator(LogicalKeyboardKey.arrowDown): () =>
                firstResult.requestFocus(),
          },
          child: Scaffold(
            body: Column(children: [
              TvTextFieldGate(
                focusNode: search,
                builder: (context, readOnly) => TextField(
                    focusNode: search, readOnly: readOnly, autofocus: true),
              ),
              TextButton(
                  focusNode: other, onPressed: () {}, child: const Text('B')),
              TextButton(
                  focusNode: firstResult,
                  onPressed: () {},
                  child: const Text('Result')),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(search.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    tester.testTextInput.enterText('news');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(firstResult.hasFocus, isTrue);
    expect(TvTextFieldGate.isEditing(search), isFalse);
  });

  // Add Playlist (and the Multiview picker, channel linking, EPG matching)
  // move between fields from a HardwareKeyboard handler registered before
  // the gate's own, and stand aside while a field is editing
  // (cleverclogs17's Xtream fields needed Menu before Down).
  testWidgets("Apple TV: a screen's earlier key handler takes the first Down",
      (tester) async {
    TvTextFieldGate.debugFullScreenKeyboard = true;
    addTearDown(() => TvTextFieldGate.debugFullScreenKeyboard = null);
    bool handler(KeyEvent e) {
      if (e is! KeyDownEvent ||
          e.logicalKey != LogicalKeyboardKey.arrowDown ||
          TvTextFieldGate.isEditing(FocusManager.instance.primaryFocus)) {
        return false;
      }
      above.requestFocus(); // the screen's own pick, not the nearest below
      return true;
    }

    HardwareKeyboard.instance.addHandler(handler); // before the gate's
    addTearDown(() => HardwareKeyboard.instance.removeHandler(handler));
    await pump(tester, tv: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(above.hasFocus, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
  });

  testWidgets('Apple TV: Menu after the keyboard closed goes back at once',
      (tester) async {
    TvTextFieldGate.debugFullScreenKeyboard = true;
    addTearDown(() => TvTextFieldGate.debugFullScreenKeyboard = null);
    await pump(tester, tv: true);
    final page = FocusNode(debugLabel: 'page field');
    addTearDown(page.dispose);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: TvTextFieldGate(
          focusNode: page,
          builder: (context, readOnly) =>
              TextField(focusNode: page, readOnly: readOnly, autofocus: true),
        ),
      ),
    )));
    await tester.pumpAndSettle();
    expect(page.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(TvTextFieldGate.isEditing(page), isFalse); // never, on Apple TV
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    expect(find.byType(TextField, skipOffstage: false), findsNWidgets(2));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // One press: the page is gone (it used to end typing first).
    expect(find.byType(TextField, skipOffstage: false), findsOneWidget);
  });

  testWidgets('Apple TV: the app leaving the screen keeps typing (dictation)',
      (tester) async {
    TvTextFieldGate.debugFullScreenKeyboard = true;
    addTearDown(() => TvTextFieldGate.debugFullScreenKeyboard = null);
    await pump(tester, tv: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(below.hasFocus, isTrue);
  });

  testWidgets('TV: inactive IME ownership preserves editing; Home ends it',
      (tester) async {
    await pump(tester, tv: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(TvTextFieldGate.isEditing(field), isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(TvTextFieldGate.isEditing(field), isFalse);
    tester.testTextInput.log.clear();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        tester.testTextInput.log
            .where((call) => call.method == 'TextInput.show'),
        isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(TvTextFieldGate.isEditing(field), isFalse);
  });

  testWidgets('TV: delayed hide is cancelled when the app leaves foreground',
      (tester) async {
    await pump(tester, tv: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    below.requestFocus();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.testTextInput.log.clear();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        tester.testTextInput.log
            .where((call) => call.method == 'TextInput.hide'),
        isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('TV: Down leaves a typed-in field', (tester) async {
    await pump(tester, tv: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(below.hasFocus, isTrue);
  });

  testWidgets('TV: Up leaves a typed-in field', (tester) async {
    await pump(tester, tv: true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(above.hasFocus, isTrue);
    expect(controller.text, 'nba');
  });

  testWidgets("TV: a screen's own key handler keeps the last word",
      (tester) async {
    await pump(tester, tv: true);
    // Like Add Playlist's _handleFieldEscapeKey: Down goes to a field of its
    // choosing (here, deliberately not the one below).
    bool handler(KeyEvent e) {
      if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.arrowDown) {
        above.requestFocus();
        return true;
      }
      return false;
    }

    HardwareKeyboard.instance.addHandler(handler);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(handler));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(above.hasFocus, isTrue);
  });

  testWidgets('phone: arrows still move the cursor', (tester) async {
    await pump(tester, tv: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(field.hasFocus, isTrue);
    expect(controller.selection.baseOffset, 0);
  });
}
