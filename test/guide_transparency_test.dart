import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/l10n/l10n.dart';
import 'package:nox_iptv/screens/settings/guide_settings_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageService storage;
  late AppPreferences prefs;

  setUp(() async {
    L10n.code = 'en';
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    prefs = AppPreferences(storage);
    await prefs.init();
  });

  tearDown(() {
    prefs.dispose();
    L10n.code = 'en';
  });

  Widget settings() => ChangeNotifierProvider.value(
      value: prefs, child: const MaterialApp(home: GuideSettingsScreen()));

  test('existing guide appearance is the default; percentage survives reload',
      () async {
    expect(prefs.guideTransparency, 45);
    expect(prefs.guideOverlayOpacity, closeTo(0.55, 0.00001));
    prefs.setGuideTransparency(73);
    final reloaded = AppPreferences(storage);
    await reloaded.init();
    expect(reloaded.guideTransparency, 73);
    expect(reloaded.guideOverlayOpacity, closeTo(0.27, 0.00001));
    reloaded.dispose();
  });

  testWidgets('remote arrows and touch set and persist the percentage',
      (tester) async {
    prefs.setGuideFullVideo(true);
    await tester.pumpWidget(settings());
    expect(find.text('45%'), findsOneWidget);
    final slider = find.byType(Slider);
    final focus = find.descendant(
        of: slider, matching: find.byType(FocusableActionDetector));
    tester.widget<FocusableActionDetector>(focus).focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(storage.getGuideTransparency(), 46);
    expect(find.text('46%'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(storage.getGuideTransparency(), 45);

    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
    await tester.pumpAndSettle();
    expect(storage.getGuideTransparency(), 100);
    await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
    await tester.pumpAndSettle();
    expect(storage.getGuideTransparency(), 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('slider follows the full-video option and keeps its saved value',
      (tester) async {
    prefs.setGuideTransparency(65);
    await tester.pumpWidget(settings());
    expect(find.byType(Slider), findsNothing);
    prefs.setGuideFullVideo(true);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 65);
    prefs.setGuideViewMode('live');
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
    prefs.setGuideViewMode('timeline');
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 65);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final saved in [-20, 120]) {
    testWidgets('out-of-range saved percentage $saved remains a usable slider',
        (tester) async {
      final raw = await SharedPreferences.getInstance();
      await raw.setInt(AppConstants.keyGuideTransparency, saved);
      prefs.setGuideFullVideo(true);
      await tester.pumpWidget(settings());
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, saved < 0 ? 0 : 100);
      prefs.setGuideTransparency(saved);
      expect(
          raw.getInt(AppConstants.keyGuideTransparency), saved < 0 ? 0 : 100);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('Windows keeps its existing guide controls without this slider',
      (tester) async {
    prefs.setGuideFullVideo(true);
    await tester.pumpWidget(settings());
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Full-screen video behind the guide'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
