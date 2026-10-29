import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/screens/settings/settings_menu_screen.dart';
import 'package:nox_iptv/screens/settings/sports_country_settings_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';

void main() {
  for (final size in [const Size(1280, 720), const Size(390, 760)]) {
    testWidgets('new Sports Trak Settings category opens preferences at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
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
      if (size.width >= 700) {
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
      } else {
        await tester.tap(
            find.widgetWithText(TvMenuTile, 'Preferred channel countries'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(SportsCountrySettingsScreen), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferredCountries(), ['CA']);
      final focused = FocusManager.instance.primaryFocus;
      expect(focused?.context?.findAncestorWidgetOfExactType<TvMenuTile>()?.key,
          const ValueKey('country-CA'));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SportsCountrySettingsScreen), findsNothing);
      expect(storage.getSportsPreferredCountries(), ['CA']);
      await tester.pumpWidget(const SizedBox());
      prefs.dispose();
    });
  }

  for (final language in ['en', 'fr', 'es', 'it', 'el']) {
    testWidgets(
        'country editor supports multiple choices, reset and large text in $language',
        (tester) async {
      L10n.code = language;
      addTearDown(() => L10n.code = 'en');
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      await tester.pumpWidget(Provider.value(
          value: storage,
          child: MaterialApp(
              theme: ThemeData.dark(),
              home: const MediaQuery(
                  data: MediaQueryData(
                      size: Size(390, 760), textScaler: TextScaler.linear(1.4)),
                  child: SportsCountrySettingsScreen()))));
      await tester.pumpAndSettle();
      for (final code in ['CA', 'US']) {
        final tile = find.byKey(ValueKey('country-$code'));
        await tester.scrollUntilVisible(tile, 120);
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
      expect(storage.getSportsPreferredCountries().toSet(), {'CA', 'US'});
      final reset = find.byKey(const ValueKey('country-automatic'));
      await tester.scrollUntilVisible(reset, -180);
      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferredCountries(), isEmpty);
      expect(tester.takeException(), isNull);
      await storage.setActiveViewerId('other');
      final canada = find.byKey(const ValueKey('country-CA'));
      await tester.scrollUntilVisible(canada, 120);
      await tester.ensureVisible(canada);
      await tester.pumpAndSettle();
      await tester.tap(canada);
      await tester.pumpAndSettle();
      expect(storage.getSportsPreferredCountries(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
