import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/settings/transfer_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/device_memory_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Transfer > Receive on this device: the whole keypad must be on screen on
/// a TV without scrolling (Apple TV photo, 2026-11-22: the Back / 0 / OK row
/// was cut off at the bottom). A TV screen is 960x540 (Android TV boxes;
/// Apple TV through TvCanvas), and Apple TV also reports its safe area
/// (60 pt top / bottom, 80 pt left / right at 1920x1080 = 30 / 40 here).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> open(WidgetTester tester, EdgeInsets safeArea) async {
    DeviceTypeService.television = true;
    addTearDown(() => DeviceTypeService.television = false);
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(
        left: safeArea.left,
        top: safeArea.top,
        right: safeArea.right,
        bottom: safeArea.bottom);
    tester.view.viewPadding = tester.view.padding;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: prefs),
      ],
      child: const MaterialApp(home: TransferScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receive on this device'));
    await tester.pumpAndSettle();
  }

  for (final (name, safeArea) in [
    ('Android TV box', EdgeInsets.zero),
    (
      'Apple TV (safe area)',
      const EdgeInsets.symmetric(horizontal: 40, vertical: 30)
    ),
  ]) {
    testWidgets('$name: every key on screen, no scrolling', (tester) async {
      await open(tester, safeArea);
      final keys = find.byType(TransferCodeKey);
      expect(keys, findsNWidgets(12));
      final screenBottom = 540 - safeArea.bottom;
      for (var i = 0; i < 12; i++) {
        final rect = tester.getRect(keys.at(i));
        expect(rect.bottom, lessThanOrEqualTo(screenBottom),
            reason: 'key $i ends at ${rect.bottom}, screen at $screenBottom');
      }
      // The code (16 slots) beside it, whole and on screen.
      final code = tester.getRect(find.textContaining('····'));
      expect(code.left, greaterThanOrEqualTo(safeArea.left));
      expect(code.right, lessThanOrEqualTo(tester.getRect(keys.first).left));
      expect(code.bottom, lessThanOrEqualTo(screenBottom));
      debugPrint('$name: last row ends at '
          '${tester.getRect(keys.last).bottom} of $screenBottom');
      expect(tester.takeException(), isNull);
    });
  }

  // Not only TVs: any OS's screen, by its size.
  for (final (name, size, platform) in [
    ('phone on its side', const Size(844, 390), TargetPlatform.android),
    ('iPhone on its side', const Size(844, 390), TargetPlatform.iOS),
    ('computer window', const Size(1280, 720), TargetPlatform.windows),
    ('small Mac window', const Size(900, 560), TargetPlatform.macOS),
    ('Linux laptop', const Size(1366, 768), TargetPlatform.linux),
  ]) {
    testWidgets('$name: every key on screen', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final prefs = AppPreferences(storage);
      await prefs.init();
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: storage),
          ChangeNotifierProvider.value(value: prefs),
        ],
        child: const MaterialApp(home: TransferScreen()),
      ));
      await tester.pumpAndSettle();
      // The Transfer menu scrolls on a short screen.
      await tester.ensureVisible(find.text('Receive on this device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Receive on this device'));
      await tester.pumpAndSettle();
      final keys = find.byType(TransferCodeKey);
      for (var i = 0; i < 12; i++) {
        expect(
            tester.getRect(keys.at(i)).bottom, lessThanOrEqualTo(size.height),
            reason: 'key $i');
      }
      expect(tester.getRect(find.textContaining('····')).bottom,
          lessThanOrEqualTo(size.height));
      debugPrint('$name: last row ends at '
          '${tester.getRect(keys.last).bottom} of ${size.height}');
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('a phone keeps the code over the keypad', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: prefs),
      ],
      child: const MaterialApp(home: TransferScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receive on this device'));
    await tester.pumpAndSettle();
    final code = tester.getRect(find.textContaining('····'));
    final first = tester.getRect(find.byType(TransferCodeKey).first);
    expect(code.bottom, lessThan(first.top));
    expect(tester.takeException(), isNull);
  });
}
