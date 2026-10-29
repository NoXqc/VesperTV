import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/multiview_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<List<Rect>> pumpTiles(
      WidgetTester tester, Map<String, Object> prefsValues) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(
        {AppConstants.keyMultiviewHideTips: true, ...prefsValues});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    prefs.isTelevision = true;
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: storage),
        ChangeNotifierProvider.value(value: prefs),
      ],
      child: const MaterialApp(home: MultiviewScreen()),
    ));
    await tester.pump(const Duration(seconds: 5));
    final icons = find.byIcon(Icons.add_circle_outline);
    return [
      for (var i = 0; i < icons.evaluate().length; i++)
        tester.getRect(find
            .ancestor(of: icons.at(i), matching: find.byType(InkWell))
            .first)
    ];
  }

  testWidgets('1 + 3: one big 16:9 screen, three small stacked on the right',
      (tester) async {
    final tiles =
        await pumpTiles(tester, {AppConstants.keyMultiviewMain: true});
    expect(tiles, hasLength(4));
    final big = tiles.first;
    final small = tiles.skip(1).toList();
    // The small ones share one column right of the big one, top to bottom.
    for (final r in small) {
      expect(r.left, greaterThan(big.right - 1));
      expect(r.center.dx, closeTo(small.first.center.dx, 1));
    }
    expect(small[0].top, lessThan(small[1].top));
    expect(small[1].top, lessThan(small[2].top));
    // The big screen is twice as wide as a small one.
    expect(big.width / small.first.width, closeTo(2, 0.1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the saved 2-screen layout is unchanged', (tester) async {
    final tiles = await pumpTiles(tester, const {});
    expect(tiles, hasLength(2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  test('Swap mode rotates playing screens through the big one', () {
    // Big = slot 0; Down brings the next screen up, the old big one last.
    expect(swapRotation([0, 1, 2, 3], 1), [1, 2, 3, 0]);
    expect(swapRotation([0, 1, 2, 3], -1), [3, 0, 1, 2]);
    // Empty slots (here 2) are skipped.
    expect(swapRotation([0, 1, 3], 1), [1, 3, 0]);
    expect(swapRotation([0, 3], -1), [3, 0]);
  });
}
