import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/desktop_multiview_screen.dart';
import 'package:nox_iptv/screens/multiview_screen.dart' show swapRotation;
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Windows Multiview: the 1 + 3 layout (remembered with Android's keys)
/// and its Swap mode.
void main() {
  /// [tips]: the connections tip shows on open (hidden otherwise).
  Future<StorageService> pump(WidgetTester tester,
      {Map<String, Object> prefs = const {}, bool tips = false}) async {
    SharedPreferences.setMockInitialValues(
        {AppConstants.keyMultiviewHideTips: !tips, ...prefs});
    final storage = StorageService();
    await storage.init();
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(Provider<StorageService>.value(
        value: storage,
        child: const MaterialApp(home: DesktopMultiviewScreen())));
    await tester.pump();
    return storage;
  }

  testWidgets('1 + 3 comes back; Swap mode waits for two playing screens',
      (tester) async {
    final storage = await pump(tester);
    await storage.setMultiviewMain(true);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(Provider<StorageService>.value(
        value: storage,
        child: const MaterialApp(home: DesktopMultiviewScreen())));
    await tester.pump();
    final swap = find.widgetWithText(TextButton, 'Swap mode');
    expect(swap, findsOneWidget);
    // Nothing plays yet: nothing to swap.
    expect(tester.widget<TextButton>(swap).onPressed, isNull);
    // Four empty screens to fill.
    expect(find.byIcon(Icons.add_circle_outline), findsNWidgets(4));
  });

  testWidgets('choosing a layout remembers it', (tester) async {
    final storage = await pump(tester);
    expect(find.widgetWithText(TextButton, 'Swap mode'), findsNothing);
    await tester.tap(find.byIcon(Icons.grid_view));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 + 3 screens'));
    await tester.pumpAndSettle();
    expect(storage.getMultiviewMain(), isTrue);
    expect(find.widgetWithText(TextButton, 'Swap mode'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_view));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 channels'));
    await tester.pumpAndSettle();
    expect(storage.getMultiviewMain(), isFalse);
    expect(storage.getMultiviewQuad(), isFalse);
  });

  testWidgets('a computer shows the connections tip; a click hides it for good',
      (tester) async {
    final storage = await pump(tester, tips: true);
    await tester.pump();
    expect(find.text('Before you start'), findsOneWidget);
    // OK has focus (a keyboard's Enter closes it too).
    expect(Focus.of(tester.element(find.text('OK'))).hasPrimaryFocus, isTrue);
    await tester.tap(find.text('Don\'t show this again'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Before you start'), findsNothing);
    expect(storage.getMultiviewHideTips(), isTrue);

    // Next time Multiview opens straight on the screens.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(Provider<StorageService>.value(
        value: storage,
        child: const MaterialApp(home: DesktopMultiviewScreen())));
    await tester.pump();
    await tester.pump();
    expect(find.text('Before you start'), findsNothing);
  });

  group('opening with channels (Sports Trak picks, the player bar)', () {
    const dual = DesktopMultiviewLayout.dual,
        quad = DesktopMultiviewLayout.quad,
        main = DesktopMultiviewLayout.main;
    test('a mouse: 2 = the 2-screen layout, 3-4 = the 4-screen grid', () {
      for (final remembered in DesktopMultiviewLayout.values) {
        expect(
            desktopMultiviewOpening(2, remote: false, remembered: remembered),
            (layout: dual, slots: 2));
        for (final n in [3, 4, 6]) {
          expect(
              desktopMultiviewOpening(n, remote: false, remembered: remembered),
              (layout: quad, slots: 4));
        }
        // None or one: the layout chosen last.
        for (final n in [0, 1]) {
          expect(
              desktopMultiviewOpening(n, remote: false, remembered: remembered)
                  .layout,
              remembered);
        }
      }
    });

    test('a remote: one equal screen per channel, as on Android', () {
      for (final remembered in DesktopMultiviewLayout.values) {
        for (final (n, slots) in [(1, 1), (2, 2), (3, 3), (4, 4), (5, 4)]) {
          expect(
              desktopMultiviewOpening(n, remote: true, remembered: remembered),
              (layout: quad, slots: slots));
        }
      }
      // Nothing handed over: one screen, or 1 + 3 when chosen last.
      expect(desktopMultiviewOpening(0, remote: true, remembered: quad),
          (layout: quad, slots: 1));
      expect(desktopMultiviewOpening(0, remote: true, remembered: dual),
          (layout: quad, slots: 1));
      expect(desktopMultiviewOpening(0, remote: true, remembered: main),
          (layout: main, slots: 4));
    });
  });

  test('swap rotation moves every playing screen one place', () {
    // Screens playing in slots 0, 2, 3: Right moves 2 -> big, 3 -> 2, big -> 3.
    expect(swapRotation([0, 2, 3], 1), [2, 3, 0]);
    expect(swapRotation([0, 2, 3], -1), [3, 0, 2]);
  });
}
