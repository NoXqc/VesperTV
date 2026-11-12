import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/screens/settings/settings_menu_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/setting_row.dart';

void main() {
  for (final size in [const Size(1280, 720), const Size(390, 760)]) {
    testWidgets('Sports Trak quality setting retains saved value at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      expect(storage.getSportsPreferQuality(), isTrue);
      await storage.setSportsPreferQuality(false);
      final prefs = AppPreferences(storage);
      await prefs.init();
      await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: storage),
            ChangeNotifierProvider.value(value: prefs)
          ],
          child: MaterialApp(
              theme: ThemeData.dark(), home: const SettingsMenuScreen())));
      await tester.pumpAndSettle();
      final category = find.widgetWithText(SettingRow, 'Sports Trak');
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      // A switch right in the Settings list now (2026-11-10), no page.
      final entry = find.widgetWithText(SettingRow, 'Prefer highest quality');
      await tester.scrollUntilVisible(entry, 120,
          scrollable: find.byType(Scrollable).last);
      GlassSwitch pill() => tester.widget<GlassSwitch>(
          find.descendant(of: entry, matching: find.byType(GlassSwitch)));
      expect(pill().value, isFalse);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferQuality(), isTrue);
      expect(pill().value, isTrue);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferQuality(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      prefs.dispose();
    });
  }

  testWidgets('a covered old viewer quality row cannot change the new viewer',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    addTearDown(prefs.dispose);
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: storage),
          ChangeNotifierProvider.value(value: prefs)
        ],
        child: const MaterialApp(
            home: SettingsCategoryScreen(categoryId: 'sports'))));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('setting-sports_quality'));
    await tester.scrollUntilVisible(row, 120,
        scrollable: find.byType(Scrollable).last);
    await storage.setActiveViewerId('another');
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(storage.getSportsPreferQuality(), isTrue);
    await storage.setSportsPreferQuality(false);
    await storage.setActiveViewerId('main');
    expect(storage.getSportsPreferQuality(), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
