import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/time_format.dart';
import 'package:nox_iptv/widgets/player_bar_title.dart';

void main() {
  late AppPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    TimeFormat.use24h = true;
  });

  tearDown(() {
    prefs.dispose();
    TimeFormat.use24h = true;
  });

  Widget bar({double width = 400, bool enabled = true}) =>
      ChangeNotifierProvider.value(
        value: prefs,
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TickerMode(
                enabled: enabled,
                child: SizedBox(
                  width: width,
                  child: const PlayerBarTitle(
                      title: 'A long channel name or movie / episode title'),
                ),
              ),
            ),
          ),
        ),
      );

  Finder clockText() =>
      find.descendant(of: find.byType(FittedBox), matching: find.byType(Text));

  testWidgets('clock is beside the title and reacts to 12/24-hour changes',
      (tester) async {
    await tester.pumpWidget(bar());
    expect(tester.widget<Text>(clockText()).data, matches(r'^\d{2}:\d{2}$'));
    prefs.setUse24h(false);
    await tester.pump();
    expect(tester.widget<Text>(clockText()).data,
        matches(r'^\d{1,2}:\d{2} (AM|PM)$'));
    final title = find.text('A long channel name or movie / episode title');
    expect(tester.getRect(clockText()).left,
        greaterThanOrEqualTo(tester.getRect(title).right));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('long titles and 12-hour clocks fit narrow player bars',
      (tester) async {
    prefs.setUse24h(false);
    for (final width in [20.0, 64.0, 160.0, 600.0]) {
      await tester.pumpWidget(bar(width: width));
      expect(tester.takeException(), isNull);
      expect(clockText(), findsOneWidget);
      expect(tester.getRect(find.byType(FittedBox)).right,
          lessThanOrEqualTo(width + 0.01));
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('minute updates survive route and app suspension and dispose',
      (tester) async {
    await tester.pumpWidget(bar());
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpWidget(bar(enabled: false));
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpWidget(bar());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(clockText(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
    expect(tester.takeException(), isNull);
  });
}
