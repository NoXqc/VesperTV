import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/screens/settings/settings_menu_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:nox_iptv/widgets/player_controls.dart';
import 'package:nox_iptv/widgets/setting_row.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings > Playback > Player bar / Options row transparency (owner,
/// 2026-11-21: one per menu, so the options row can be darker than the info
/// bar). 0 % = solid, 15 % = the old look, 100 % = clear.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late AppPreferences prefs;

  Future<void> start(Map<String, Object> values) async {
    L10n.code = 'en';
    SharedPreferences.setMockInitialValues(values);
    storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
  }

  tearDown(() => prefs.dispose());

  test('0 % solid, 15 % the old look, 100 % clear', () async {
    await start({});
    for (final base in [0.54, 0.8, 0.85]) {
      expect(playerMenuAlpha(base, 0), 1);
      expect(playerMenuAlpha(base, 15), closeTo(base, 0.0001));
      expect(playerMenuAlpha(base, 100), 0);
      expect(playerMenuAlpha(base, 5), greaterThan(base));
      expect(playerMenuAlpha(base, 50), lessThan(base));
    }
    // The options pill has no fill at 15 % (as before), solid at 0 %.
    expect(playerMenuAlpha(0, 15), 0);
    expect(playerMenuAlpha(0, 0), 1);
  });

  test('two separate settings; the single +948 one seeds both', () async {
    await start({'vesper_player_menu_transparency': 30});
    expect(prefs.playerBarTransparency, 30);
    expect(prefs.playerOptionsTransparency, 30);
    prefs.setPlayerOptionsTransparency(0);
    expect(prefs.playerOptionsTransparency, 0);
    expect(prefs.playerBarTransparency, 30, reason: 'the bar keeps its own');
    expect(AppConstants.keyPlayerBarTransparency,
        isNot(AppConstants.keyPlayerOptionsTransparency));
  });

  testWidgets('both in Settings > Playback; Right steps one by 5',
      (tester) async {
    await start({});
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: prefs,
        child: const MaterialApp(
            home: SettingsCategoryScreen(categoryId: 'playback'))));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SettingRow, 'Player bar transparency'),
        findsOneWidget);
    expect(find.widgetWithText(SettingRow, 'Options row transparency'),
        findsOneWidget);
    Focus.of(tester.element(find.text('Options row transparency')))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(storage.getPlayerOptionsTransparency(), 20);
    expect(storage.getPlayerBarTransparency(), 15);
  });
}
