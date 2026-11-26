import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/skip_step.dart';
import 'package:nox_iptv/widgets/skip_step_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner, 2026-11-25: the Skip buttons choice in the player's options row.
void main() {
  testWidgets('options row > Skip saves the step and tells the tile',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    SkipStep.seconds = storage.getSkipSeconds();
    addTearDown(() => SkipStep.seconds = SkipStep.defaultSeconds);
    final seen = <int>[];
    void note() => seen.add(SkipStep.changes.value);
    SkipStep.changes.addListener(note);
    addTearDown(() => SkipStep.changes.removeListener(note));

    await tester.pumpWidget(Provider<StorageService>.value(
      value: storage,
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showSkipStepPicker(context),
                      child: const Text('Skip'))))),
    ));
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Skip buttons'), findsOneWidget);
    for (final s in SkipStep.choices) {
      expect(find.text('$s s'), findsOneWidget);
    }
    // The current one (10 s) is ticked.
    expect(
        find.descendant(
            of: find.ancestor(
                of: find.text('10 s'), matching: find.byType(Row)),
            matching: find.byIcon(Icons.check)),
        findsOneWidget);

    await tester.tap(find.text('30 s'));
    await tester.pumpAndSettle();
    expect(SkipStep.seconds, 30);
    expect(storage.getSkipSeconds(), 30);
    expect(seen, [30]);
  });
}
