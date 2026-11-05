import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/audio_delay.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/audio_delay_adjuster.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('steps of 25 ms, clamped to one second either way', () {
    expect(AudioDelay.step(0, 1), 25);
    expect(AudioDelay.step(0, -1), -25);
    expect(AudioDelay.step(1000, 1), 1000);
    expect(AudioDelay.step(-1000, -1), -1000);
  });

  test('labels say which way the sound moves', () {
    expect(AudioDelay.label(0), 'No delay');
    expect(AudioDelay.label(150), '+150 ms · sound later');
    expect(AudioDelay.label(-75), '-75 ms · sound earlier');
  });

  testWidgets('Left/Right adjust and save, OK closes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: prefs,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAudioDelayAdjuster(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(prefs.audioDelayMs, 25);
    expect(storage.getAudioDelayMs(), 25);
    expect(find.text('+25 ms · sound later'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Audio sync'), findsNothing);
  });
}
