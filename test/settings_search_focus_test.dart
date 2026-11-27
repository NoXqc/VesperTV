import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/settings/settings_menu_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/setting_row.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// cillfog (Discord, 2026-11-26, TV box): Settings > Search settings, type
/// "tmdb", the keyboard's search key: focus sat on the field's clear X and
/// Down did nothing (Left still went to the categories).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: prefs),
      ],
      child: const MaterialApp(home: SettingsMenuScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pumpAndSettle();
  }

  bool focusedIn(Finder finder) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    final target = finder.evaluate();
    var found = false;
    ctx.visitAncestorElements((e) {
      if (target.contains(e)) found = true;
      return !found;
    });
    return found || target.contains(ctx);
  }

  bool clearFocused() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    var found = false;
    ctx.visitAncestorElements((e) {
      if (e.widget is IconButton &&
          (e.widget as IconButton).tooltip == 'Clear') {
        found = true;
      }
      return !found;
    });
    return found;
  }

  Future<void> typeTmdb(WidgetTester tester) async {
    await key(tester, LogicalKeyboardKey.arrowUp); // Search settings
    await key(tester, LogicalKeyboardKey.arrowRight); // the text box
    await key(tester, LogicalKeyboardKey.enter); // keyboard
    await tester.enterText(find.byType(TextField), 'tmdb');
    await tester.pumpAndSettle();
  }

  final tmdbRow = find.widgetWithText(SettingRow, 'TMDB (Release Dates)');

  testWidgets('the search key goes on to the first result', (tester) async {
    await pump(tester);
    await typeTmdb(tester);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(clearFocused(), isFalse);
    expect(focusedIn(tmdbRow), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Down leaves the clear X for the results', (tester) async {
    await pump(tester);
    await typeTmdb(tester);
    // Keyboard closed with Back, then Right onto the X.
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.arrowUp); // the field
    await key(tester, LogicalKeyboardKey.arrowRight); // the X
    expect(clearFocused(), isTrue);
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(clearFocused(), isFalse);
    expect(focusedIn(tmdbRow), isTrue);
  });

  testWidgets('no result: the search key closes the keyboard, focus stays',
      (tester) async {
    await pump(tester);
    await key(tester, LogicalKeyboardKey.arrowUp);
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.enter);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'settings-search');
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
  });
}
