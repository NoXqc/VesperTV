import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/screens/settings/theme_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/utils/refined_finish.dart';
import 'package:nox_iptv/utils/tv_theme.dart';
import 'package:nox_iptv/widgets/settings_panel.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(StorageService, AppPreferences)> preferences() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    return (storage, prefs);
  }

  test('off by default, persists independently, reloads with identical palette',
      () async {
    final (storage, prefs) = await preferences();
    expect(storage.getRefinedFinish(), isFalse);
    expect(prefs.refinedFinish, isFalse);
    final palette = prefs.palette.id;
    prefs.setRefinedFinish(true);
    final reopened = StorageService();
    await reopened.init();
    expect(reopened.getRefinedFinish(), isTrue);
    await storage.setActiveViewerId('other');
    prefs.reloadPaletteForViewer();
    expect(prefs.palette.id, palette);
    expect(prefs.refinedFinish, isFalse);
    prefs.setRefinedFinish(false);
    await storage.setActiveViewerId('main');
    prefs.reloadPaletteForViewer();
    expect(prefs.refinedFinish, isTrue);
    prefs.dispose();
  });

  for (final backup in [true, false]) {
    test(
        '${backup ? 'backup' : 'transfer'} retains independent finish preferences',
        () async {
      final (storage, prefs) = await preferences();
      prefs.setRefinedFinish(true);
      await storage.setActiveViewerId('other');
      await storage.setRefinedFinish(false);
      final data =
          backup ? storage.exportForBackup() : storage.exportForTransfer();
      SharedPreferences.setMockInitialValues({});
      final restored = StorageService();
      await restored.init();
      if (backup) {
        await restored.importForBackup(data);
      } else {
        await restored.importForTransfer(data);
      }
      await restored.setActiveViewerId('main');
      expect(restored.getRefinedFinish(), isTrue);
      await restored.setActiveViewerId('other');
      expect(restored.getRefinedFinish(), isFalse);
      prefs.dispose();
    });
  }

  testWidgets('Theme toggle persists and updates in place', (tester) async {
    final (storage, prefs) = await preferences();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: prefs,
        child: Consumer<AppPreferences>(builder: (_, value, __) {
          return MaterialApp(
            theme: RefinedFinish.apply(ThemeData.dark(), value.refinedFinish),
            home: const ThemeScreen(),
          );
        })));
    final label = find.text('Refined finish');
    expect(label, findsOneWidget);
    await tester.ensureVisible(label);
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(storage.getRefinedFinish(), isTrue);
    final context = tester.element(label);
    expect(RefinedFinish.of(context), isTrue);
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(storage.getRefinedFinish(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    prefs.dispose();
  });

  for (final paletteId in ['dark_gold', 'habs', 'minimal', 'neon_green']) {
    testWidgets('paint preserves geometry and focus for $paletteId',
        (tester) async {
      final (storage, prefs) = await preferences();
      final palette =
          AppConstants.cyberpunkPalettes.firstWhere((p) => p.id == paletteId);
      prefs.setPalette(palette);
      final focus = FocusNode();
      final tileKey = GlobalKey();
      final panelKey = GlobalKey();
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: prefs,
          child: Consumer<AppPreferences>(builder: (_, value, __) {
            final scheme =
                buildPaletteColorScheme(value.palette, Brightness.dark);
            return MaterialApp(
              theme: RefinedFinish.apply(
                  ThemeData(colorScheme: scheme), value.refinedFinish),
              home: Scaffold(
                  body: Center(
                      child: SizedBox(
                          width: 500,
                          child: SettingsPanel(key: panelKey, children: [
                            Material(
                                color: Colors.transparent,
                                child: TvMenuTile(
                                    key: tileKey,
                                    focusNode: focus,
                                    autofocus: true,
                                    icon: Icons.palette,
                                    title: 'Theme',
                                    subtitle: 'Clock, accent color, layout',
                                    onTap: () {})),
                          ])))),
            );
          })));
      await tester.pumpAndSettle();
      final tileState = tester.state(find.byKey(tileKey));
      final bounds = tester.getRect(find.byKey(tileKey));
      final panelBounds = tester.getRect(find.byKey(panelKey));
      expect(focus.hasFocus, isTrue);
      prefs.setRefinedFinish(true);
      await tester.pumpAndSettle();
      expect(tester.state(find.byKey(tileKey)), same(tileState));
      expect(tester.getRect(find.byKey(tileKey)), bounds);
      expect(tester.getRect(find.byKey(panelKey)), panelBounds);
      expect(focus.hasFocus, isTrue);
      final context = tester.element(find.byKey(tileKey));
      final original = BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.primary, width: 2));
      final decorated =
          RefinedFinish.decorate(context, original, focused: true);
      expect(decorated.padding, original.padding);
      expect(decorated.borderRadius, original.borderRadius);
      expect(decorated.border, same(original.border));
      // A low-alpha white panel must remain dark with white labels.
      final surface =
          RefinedFinish.surface(context, Colors.white.withValues(alpha: 0.07));
      expect(surface.computeLuminance(), lessThan(0.05));
      expect(Theme.of(context).colorScheme.primary,
          buildPaletteColorScheme(palette, Brightness.dark).primary);
      prefs.setRefinedFinish(false);
      await tester.pumpAndSettle();
      expect(RefinedFinish.decorate(context, original), same(original));
      expect(tester.state(find.byKey(tileKey)), same(tileState));
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
      prefs.dispose();
      expect(storage.getRefinedFinish(), isFalse);
    });
  }
}
