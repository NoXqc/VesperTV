import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/vod_buffering.dart';
import 'package:nox_iptv/widgets/live_buffer_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('short names for the player options row', () {
    expect(liveBufferShortName(-1), 'Gradual');
    expect(liveBufferShortName(0), 'Off');
    expect(liveBufferShortName(1500), '1.5 s');
    expect(liveBufferShortName(8000), '8 s');
  });

  // Settings > Playback > Live buffer and the player's Buffer button share
  // this picker: a pick is saved and becomes every new player's default.
  testWidgets('a pick is saved and becomes the default', (tester) async {
    // The native player's channel (no plugin in tests).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('vespertv/stats'), (_) async => null);
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    int? picked;
    await tester.pumpWidget(Provider.value(
      value: storage,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await pickLiveBuffer(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Live buffer'), findsOneWidget);
    await tester.tap(find.text('8 seconds'));
    await tester.pumpAndSettle();
    expect(picked, 8000);
    expect(storage.getLiveBufferMs(), 8000);
    expect(VodBuffering.liveBufferMs, 8000);

    // Cancelling changes nothing.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(storage.getLiveBufferMs(), 8000);
  });
}
