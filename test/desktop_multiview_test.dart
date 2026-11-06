import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/desktop_multiview_screen.dart';
import 'package:nox_iptv/screens/multiview_screen.dart' show swapRotation;
import 'package:nox_iptv/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Windows Multiview: the 1 + 3 layout (remembered with Android's keys)
/// and its Swap mode.
void main() {
  Future<StorageService> pump(WidgetTester tester,
      {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
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

  test('swap rotation moves every playing screen one place', () {
    // Screens playing in slots 0, 2, 3: Right moves 2 -> big, 3 -> 2, big -> 3.
    expect(swapRotation([0, 2, 3], 1), [2, 3, 0]);
    expect(swapRotation([0, 2, 3], -1), [3, 0, 2]);
  });
}
