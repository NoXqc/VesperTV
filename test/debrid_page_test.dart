import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/settings/debrid_settings_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner, 2026-11-23: many users thought Debrid accounts was where their
/// debrid add-ons go. The page says first that it adds nothing to watch,
/// and its first button (focused, for the remote) opens Media Hub sources.
void main() {
  testWidgets('the Debrid page sends people to Media Hub sources first',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await tester.pumpWidget(MultiProvider(providers: [
      Provider.value(value: storage),
      ChangeNotifierProvider.value(value: AppPreferences(storage)),
    ], child: const MaterialApp(home: DebridSettingsScreen())));
    await tester.pump();

    expect(find.text("This page doesn't add movies or shows"), findsOneWidget);
    final open = find.text('Open Media Hub sources');
    expect(open, findsOneWidget);
    // Above the key fields, and where the remote starts.
    expect(tester.getTopLeft(open).dy,
        lessThan(tester.getTopLeft(find.text('Real-Debrid API token')).dy));
    expect(Focus.of(tester.element(open)).hasPrimaryFocus, isTrue);
  });
}
