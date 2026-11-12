import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/settings/settings_menu_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/device_memory_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/glass_menu.dart';
import 'package:nox_iptv/widgets/setting_row.dart';
import 'package:nox_iptv/widgets/settings_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings (rework 2026-11-10): categories on the left, the focused
/// category's rows on the right; Right enters them, Left / Back returns.
/// Switches flip in place, choices roll down beside the row.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late AppPreferences prefs;

  Future<void> pump(WidgetTester tester, {Size size = const Size(1920, 1080)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: prefs),
      ],
      child: const MaterialApp(home: SettingsMenuScreen()),
    ));
    await tester.pumpAndSettle();
  }

  String? focusedLabel() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return null;
    final texts = <String>[];
    ctx.visitChildElements(_collect(texts));
    return texts.isEmpty ? null : texts.first;
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pumpAndSettle();
  }

  testWidgets('pane follows the panel; Right / Left move between them',
      (tester) async {
    await pump(tester);
    expect(focusedLabel(), 'Playlists & sources');
    expect(find.text('Playlist Manager'), findsOneWidget);
    // No playlist yet: Start here (Add Playlist, language, colour) first.
    expect(find.text('START HERE'), findsOneWidget);
    expect(find.text('Refined finish'), findsNothing);

    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedLabel(), 'Appearance');
    expect(find.text('Theme color'), findsOneWidget);
    expect(find.text('Playlist Manager'), findsNothing);

    // Right: the first row; Down stays in the pane.
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedLabel(), 'Theme color');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedLabel(), 'Refined finish');

    // Left: back on the same category.
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusedLabel(), 'Appearance');

    // Down: Playback, the player's settings and no appearance ones.
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedLabel(), 'Playback');
    expect(find.text('Automatic trailers'), findsOneWidget);
    expect(find.text('Theme color'), findsNothing);
  });

  testWidgets('a switch flips in place and the help line follows focus',
      (tester) async {
    await pump(tester);
    await key(tester, LogicalKeyboardKey.arrowDown); // Appearance
    await key(tester, LogicalKeyboardKey.arrowRight); // Theme color
    await key(tester, LogicalKeyboardKey.arrowDown); // Refined finish
    expect(prefs.refinedFinish, isFalse);
    expect(
        find.text(
            'Glossy surfaces, reflections and blur. Uses more graphics resources.'),
        findsOneWidget);
    await key(tester, LogicalKeyboardKey.enter);
    expect(prefs.refinedFinish, isTrue);
    // Focus stays on the row (no page was opened).
    expect(focusedLabel(), 'Refined finish');
    expect(
        tester
            .widget<GlassSwitch>(find.descendant(
                of: find.widgetWithText(SettingRow, 'Refined finish'),
                matching: find.byType(GlassSwitch)))
            .value,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a choice rolls down and saves the pick', (tester) async {
    await pump(tester);
    await key(tester, LogicalKeyboardKey.arrowDown); // Appearance
    await key(tester, LogicalKeyboardKey.arrowRight); // Theme color
    expect(prefs.palette.id, isNot('dark_gold'));
    await key(tester, LogicalKeyboardKey.enter);
    expect(find.byType(GlassMenuSurface), findsOneWidget);
    await tester.tap(find.text('Dark / Gold').last);
    await tester.pumpAndSettle();
    expect(prefs.palette.id, 'dark_gold');
    expect(find.byType(GlassMenuSurface), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tabs are switched on and off by name', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(SettingRow, 'Appearance'));
    await tester.pumpAndSettle();
    final row = find.widgetWithText(SettingRow, 'Media Hub');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(prefs.hideArchive, isFalse);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(prefs.hideArchive, isTrue);
  });

  testWidgets('Advanced holds the device fixes, after a divider',
      (tester) async {
    await pump(tester);
    final advanced = find.widgetWithText(SettingRow, 'Advanced');
    await tester.ensureVisible(advanced);
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(find.text('Data pool display'), findsOneWidget);
    expect(find.text('TMDB (Release Dates)'), findsOneWidget);
    expect(find.text('Clear search & channel history'), findsOneWidget);
  });

  testWidgets('phone: categories open their own page', (tester) async {
    await pump(tester, size: const Size(390, 800));
    await tester.tap(find.widgetWithText(SettingRow, 'Playback'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsCategoryScreen), findsOneWidget);
    final row = find.text('Automatic trailers');
    await tester.scrollUntilVisible(row, 200,
        scrollable: find.byType(Scrollable).last);
    expect(row, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search: up from the categories, type, and change it there',
      (tester) async {
    await pump(tester);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(focusedLabel(), 'Search settings');
    await key(tester, LogicalKeyboardKey.arrowRight);
    // OK opens the text box (gated on a TV), then type.
    await key(tester, LogicalKeyboardKey.enter);
    await tester.enterText(find.byType(TextField), 'atmos');
    await tester.pumpAndSettle();
    final result =
        find.widgetWithText(SettingRow, 'Surround passthrough (Dolby Atmos)');
    expect(result, findsOneWidget);
    // Where it lives, instead of its description.
    expect(find.descendant(of: result, matching: find.text('Playback › Audio & subtitles')),
        findsOneWidget);
    expect(prefs.audioPassthrough, isFalse);
    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(prefs.audioPassthrough, isTrue);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No setting matches "zzzz".'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a short page floats over Settings on a TV', (tester) async {
    DeviceTypeService.television = true;
    addTearDown(() => DeviceTypeService.television = false);
    await pump(tester);
    final help = find.widgetWithText(SettingRow, 'Help');
    await tester.tap(help);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SettingRow, 'Support VesperTV'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsFloating), findsOneWidget);
    // Settings stays underneath (dimmed), Back closes the panel only.
    expect(find.byType(SettingsMenuScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsFloating), findsNothing);
    expect(find.widgetWithText(SettingRow, 'Support VesperTV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ElementVisitor _collect(List<String> out) => (Element e) {
      final w = e.widget;
      if (w is Text && w.data != null) out.add(w.data!);
      e.visitChildElements(_collect(out));
    };
