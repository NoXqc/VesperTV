import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/screens/settings/settings_menu_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/widgets/setting_row.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings > Appearance > Live TV > Guide transparency (a stepper row since
/// the 2026-11-10 Settings: Left/Right change it by 5, OK lists the values).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late AppPreferences prefs;

  setUp(() async {
    L10n.code = 'en';
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
  });

  tearDown(() {
    prefs.dispose();
    L10n.code = 'en';
  });

  Widget settings() => ChangeNotifierProvider.value(
      value: prefs,
      child: const MaterialApp(
          home: SettingsCategoryScreen(categoryId: 'appearance')));

  final row = find.widgetWithText(SettingRow, 'Guide transparency');

  Future<void> show(WidgetTester tester) async {
    await tester.scrollUntilVisible(row, 200,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
  }

  test('existing guide appearance is the default; percentage survives reload',
      () async {
    expect(prefs.guideTransparency, 45);
    expect(prefs.guideOverlayOpacity, closeTo(0.55, 0.00001));
    prefs.setGuideTransparency(73);
    final reloaded = AppPreferences(storage);
    await reloaded.init();
    expect(reloaded.guideTransparency, 73);
    expect(reloaded.guideOverlayOpacity, closeTo(0.27, 0.00001));
    reloaded.dispose();
  });

  testWidgets('remote arrows step it by 5; OK lists the values',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    prefs.setGuideFullVideo(true);
    await tester.pumpWidget(settings());
    await show(tester);
    expect(find.descendant(of: row, matching: find.text('45%')),
        findsOneWidget);
    Focus.of(tester.element(find.text('Guide transparency'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(storage.getGuideTransparency(), 50);
    expect(find.descendant(of: row, matching: find.text('50%')),
        findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(storage.getGuideTransparency(), 45);
    // Up / Down leave it (the remote was once stuck on a slider here).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(storage.getGuideTransparency(), 45);
    expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<SettingRow>()
            ?.title,
        isNot('Guide transparency'));

    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('100%').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('100%').last);
    await tester.pumpAndSettle();
    expect(storage.getGuideTransparency(), 100);
    // At the ends the arrows stop.
    Focus.of(tester.element(find.text('Guide transparency'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(storage.getGuideTransparency(), 100);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('row follows the full-video option and keeps its saved value',
      (tester) async {
    prefs.setGuideTransparency(65);
    await tester.pumpWidget(settings());
    expect(row, findsNothing);
    prefs.setGuideFullVideo(true);
    await tester.pumpAndSettle();
    await show(tester);
    expect(find.descendant(of: row, matching: find.text('65%')),
        findsOneWidget);
    prefs.setGuideViewMode('live');
    await tester.pumpAndSettle();
    expect(row, findsNothing);
    prefs.setGuideViewMode('timeline');
    await tester.pumpAndSettle();
    await show(tester);
    expect(find.descendant(of: row, matching: find.text('65%')),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final saved in [-20, 120]) {
    testWidgets('out-of-range saved percentage $saved shows in range',
        (tester) async {
      final raw = await SharedPreferences.getInstance();
      await raw.setInt(AppConstants.keyGuideTransparency, saved);
      prefs.setGuideFullVideo(true);
      await tester.pumpWidget(settings());
      await show(tester);
      expect(
          find.descendant(
              of: row, matching: find.text(saved < 0 ? '0%' : '100%')),
          findsOneWidget);
      prefs.setGuideTransparency(saved);
      expect(
          raw.getInt(AppConstants.keyGuideTransparency), saved < 0 ? 0 : 100);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('Windows keeps its existing guide controls without this row',
      (tester) async {
    prefs.setGuideFullVideo(true);
    await tester.pumpWidget(settings());
    expect(row, findsNothing);
    expect(find.text('Full-screen video behind the guide'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
