import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/screens/settings/settings_menu_screen.dart';
import 'package:nox_iptv/screens/settings/sports_quality_settings_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';
import 'package:nox_iptv/widgets/tv_switch_list_tile.dart';

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
      final category = find.widgetWithText(TvMenuTile, 'Sports Trak');
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      final entry = find.widgetWithText(TvMenuTile, 'Prefer highest quality');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(SportsQualitySettingsScreen), findsOneWidget);
      expect(
          tester.widget<TvSwitchListTile>(find.byType(TvSwitchListTile)).value,
          isFalse);
      // Initial focus supports the TV remote as well as a phone tap.
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferQuality(), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(
          tester.widget<TvSwitchListTile>(find.byType(TvSwitchListTile)).value,
          isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferQuality(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      prefs.dispose();
    });
  }

  testWidgets('a covered old viewer quality page cannot change the new viewer',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await tester.pumpWidget(Provider.value(
        value: storage,
        child: const MaterialApp(home: SportsQualitySettingsScreen())));
    await tester.pumpAndSettle();
    await storage.setActiveViewerId('another');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(storage.getSportsPreferQuality(), isTrue);
    await storage.setSportsPreferQuality(false);
    await storage.setActiveViewerId('main');
    expect(storage.getSportsPreferQuality(), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
