import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/screens/settings/general_settings_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/goal_overlay_probe.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/widgets/goal_overlay_probe_settings.dart';
import 'package:nox_iptv/widgets/tv_menu_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Map<String, Object?> status;
  bool openResult = true;
  bool testResult = true;

  setUp(() {
    calls = [];
    status = {'access': 'settings', 'canOpenSettings': true, 'running': false};
    openResult = true;
    testResult = true;
    L10n.code = 'en';
    messenger.setMockMethodCallHandler(GoalOverlayProbe.channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'status':
          return status;
        case 'openSettings':
          return openResult;
        case 'testPopup':
          if (testResult) status['running'] = true;
          return testResult;
      }
      throw MissingPluginException();
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(GoalOverlayProbe.channel, null);
    L10n.code = 'en';
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> pumpProbe(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
            body: SingleChildScrollView(child: GoalOverlayProbeSettings()))));
    await tester.pumpAndSettle();
  }

  TvMenuTile tile(WidgetTester tester, String title) =>
      tester.widget<TvMenuTile>(find.widgetWithText(TvMenuTile, title));

  for (final access in ['granted', 'settings', 'unavailable']) {
    testWidgets('access=$access drives grant/test controls', (tester) async {
      status['access'] = access;
      status['canOpenSettings'] = access != 'unavailable';
      await pumpProbe(tester);
      expect(tile(tester, 'Test popup over other apps').enabled,
          access == 'granted');
      expect(tile(tester, 'Open overlay settings').enabled,
          access != 'unavailable');
      expect(
          find.text(switch (access) {
            'granted' => 'Overlay access granted',
            'settings' => 'Open settings to allow overlays',
            _ => 'Overlay access not available',
          }),
          findsOneWidget);
      expect(calls.map((c) => c.method), ['status']);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('returning from system settings refreshes actual access',
      (tester) async {
    await pumpProbe(tester);
    await tester.tap(find.text('Open overlay settings'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'openSettings').length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    status['access'] = 'granted';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tile(tester, 'Test popup over other apps').enabled, isTrue);
    status['access'] = 'settings';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tile(tester, 'Test popup over other apps').enabled, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'settings launch failure reports unavailable without starting test',
      (tester) async {
    openResult = false;
    await pumpProbe(tester);
    await tester.tap(find.text('Open overlay settings'));
    await tester.pumpAndSettle();
    expect(find.text('Overlay access not available'), findsOneWidget);
    expect(tile(tester, 'Test popup over other apps').enabled, isFalse);
    expect(calls.where((c) => c.method == 'testPopup'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('one native request survives leaving the settings widget',
      (tester) async {
    status['access'] = 'granted';
    await pumpProbe(tester);
    await tester.tap(find.text('Test popup over other apps'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'testPopup').length, 1);
    expect(tile(tester, 'Test popup over other apps').enabled, isFalse);
    await tester.pumpWidget(const SizedBox());
    final count = calls.length;
    await tester.pump(const Duration(seconds: 30));
    expect(calls.length, count,
        reason: 'widget disposal cancels status checks, not native test');
  });

  testWidgets(
      'completion refresh enables another test without claiming visibility',
      (tester) async {
    status['access'] = 'granted';
    await pumpProbe(tester);
    await tester.tap(find.text('Test popup over other apps'));
    await tester.pumpAndSettle();
    status['running'] = false;
    status['result'] = 'completed';
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(tile(tester, 'Test popup over other apps').enabled, isTrue);
    expect(
        find.text(
            'Test finished. Check whether the popup appeared in the other app.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('native start refusal leaves the page usable', (tester) async {
    status['access'] = 'granted';
    testResult = false;
    await pumpProbe(tester);
    await tester.tap(find.text('Test popup over other apps'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'The overlay test could not start. Check overlay access and try again.'),
        findsOneWidget);
    expect(tile(tester, 'Test popup over other apps').enabled, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final language in ['en', 'fr', 'es', 'it', 'el', 'de']) {
    test('native test text follows $language; no score or watch data sent',
        () async {
      L10n.code = language;
      expect(await GoalOverlayProbe.testPopup(), isTrue);
      final arguments = calls.single.arguments as Map;
      expect(
          arguments.keys,
          unorderedEquals(
              ['title', 'message', 'waiting', 'channelName', 'cancel']));
      expect(arguments['title'], tr('VesperTV overlay test'));
      expect(arguments['message'], tr('This test closes after 6 seconds.'));
      expect(arguments['waiting'],
          tr('Test popup in 10 seconds. Switch to another app.'));
      if (language != 'en') {
        expect(
            arguments['message'], isNot('This test closes after 6 seconds.'));
      }
    });
  }

  test('missing native plugin and platform errors fail closed', () async {
    messenger.setMockMethodCallHandler(GoalOverlayProbe.channel, null);
    expect((await GoalOverlayProbe.status()).access,
        OverlayProbeAccess.unavailable);
    expect(await GoalOverlayProbe.openSettings(), isFalse);
    expect(await GoalOverlayProbe.testPopup(), isFalse);
    messenger.setMockMethodCallHandler(GoalOverlayProbe.channel,
        (_) async => throw PlatformException(code: 'denied'));
    expect((await GoalOverlayProbe.status()).access,
        OverlayProbeAccess.unavailable);
    expect(await GoalOverlayProbe.openSettings(), isFalse);
    expect(await GoalOverlayProbe.testPopup(), isFalse);
  });

  for (final tv in [true, false]) {
    testWidgets('Goals alert settings exposes probe only on Android TV: tv=$tv',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final prefs = AppPreferences(storage);
      await prefs.init();
      prefs.isTelevision = tv;
      await tester.pumpWidget(MultiProvider(
          providers: [
            Provider.value(value: storage),
            ChangeNotifierProvider.value(value: prefs),
          ],
          child: const MaterialApp(
              home: GeneralSettingsScreen(
                  sections: {'goals'}, title: 'Goals alert'))));
      await tester.pumpAndSettle();
      expect(find.byType(GoalOverlayProbeSettings),
          tv ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox());
      prefs.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
