import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  for (final paletteId in [
    'dark_gold',
    'habs',
    'minimal',
    'neon_green',
    'aqua'
  ]) {
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
      expect(find.byType(BackdropFilter), findsNothing);
      prefs.setRefinedFinish(true);
      await tester.pumpAndSettle();
      expect(tester.state(find.byKey(tileKey)), same(tileState));
      expect(tester.getRect(find.byKey(tileKey)), bounds);
      expect(tester.getRect(find.byKey(panelKey)), panelBounds);
      expect(focus.hasFocus, isTrue);
      expect(find.byType(BackdropFilter), findsOneWidget);
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
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.state(find.byKey(tileKey)), same(tileState));
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
      prefs.dispose();
      expect(storage.getRefinedFinish(), isFalse);
    });
  }
  testWidgets('artwork remains intact and idle guide cells stay unchanged',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: RefinedFinish.apply(ThemeData.dark(), true),
      home: const Scaffold(body: SizedBox()),
    ));
    final context = tester.element(find.byType(SizedBox).last);
    const image = DecorationImage(image: AssetImage('assets/icon/icon.png'));
    final original =
        BoxDecoration(image: image, borderRadius: BorderRadius.circular(10));
    final painted = RefinedFinish.decorate(context, original, artwork: true);
    expect(painted.image, same(image));
    expect(painted.gradient, isNull);
    expect(painted.borderRadius, original.borderRadius);
    expect(painted.padding, original.padding);
    final rim = RefinedFinish.artworkRim(context, BorderRadius.circular(10));
    expect(rim.image, isNull);
    expect(rim.gradient, isNull);
    expect(rim.padding, EdgeInsets.zero);
    expect(RefinedFinish.decorate(context, original, focusOnly: true),
        same(original));
  });

  testWidgets('glass has visible reflections without changing panel bounds',
      (tester) async {
    final capture = GlobalKey();
    Future<int> sample(bool enabled) async {
      await tester.pumpWidget(MaterialApp(
        theme: RefinedFinish.apply(ThemeData.dark(), enabled),
        home: Scaffold(body: Builder(builder: (context) {
          return RepaintBoundary(
            key: capture,
            child: SizedBox(
                width: 220,
                height: 120,
                child: ColoredBox(
                    color: Colors.black,
                    child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: DecoratedBox(
                            decoration: RefinedFinish.decorate(
                                context,
                                BoxDecoration(
                                    color: Colors.black,
                                    borderRadius:
                                        BorderRadius.circular(8))))))),
          );
        })),
      ));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(capture)), const Size(220, 120));
      final boundary =
          capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final topRed = data!.getUint8((12 * image.width + 110) * 4);
        final lowerRed = data.getUint8((90 * image.width + 110) * 4);
        image.dispose();
        return topRed - lowerRed;
      }))!;
    }

    expect(await sample(false), 0);
    expect(await sample(true), greaterThan(25));
    expect(tester.takeException(), isNull);
  });
  for (final focused in [false, true]) {
    testWidgets('full-video finish reveals backdrop pixels, focused=$focused',
        (tester) async {
      final capture = GlobalKey();
      Future<List<int>> sample(bool translucent, Color backdrop) async {
        await tester.pumpWidget(MaterialApp(
          theme: RefinedFinish.apply(ThemeData.dark(), true),
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: SizedBox(
                width: 200,
                height: 100,
                child: ColoredBox(
                  color: backdrop,
                  child: RefinedFinishBackdrop(
                    translucent: translucent,
                    child: Builder(
                      builder: (context) => DecoratedBox(
                        decoration: RefinedFinish.decorate(
                            context,
                            BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: Colors.amber, width: 2)),
                            focused: focused),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final boundary =
            capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
        return (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data =
              await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          final offset = (50 * image.width + 100) * 4;
          final rgb = [for (var i = 0; i < 3; i++) data!.getUint8(offset + i)];
          image.dispose();
          return rgb;
        }))!;
      }

      final solidRed = await sample(false, Colors.red);
      final solidBlue = await sample(false, Colors.blue);
      expect(solidRed, solidBlue);
      final glassRed = await sample(true, Colors.red);
      final glassBlue = await sample(true, Colors.blue);
      expect(glassRed[0] - glassBlue[0], greaterThan(90));
      expect(glassBlue[2] - glassRed[2], greaterThan(90));
      expect(tester.takeException(), isNull);
    });
  }
}
