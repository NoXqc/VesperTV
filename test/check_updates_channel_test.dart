import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/settings/check_updates_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/app_update_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records which channel each check asked for; a test build is out.
class _Updater extends AppUpdateService {
  final channels = <UpdateChannel>[];

  @override
  Future<UpdateInfo?> checkForUpdate(
      {UpdateChannel channel = UpdateChannel.stable}) async {
    channels.add(channel);
    return channel == UpdateChannel.test
        ? const UpdateInfo(
            version: '1.0.73-dev.955',
            releaseNotes: '',
            downloadUrl: 'https://example.com/app-release.apk',
            apkSizeBytes: 10,
            testBuild: true)
        : null;
  }
}

void main() {
  testWidgets('Test builds: saved on this device and checked at once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    addTearDown(prefs.dispose);
    PackageInfo.setMockInitialValues(
        appName: 'VesperTV',
        packageName: 'com.nox.nox_iptv',
        version: '1.0.72',
        buildNumber: '928',
        buildSignature: '');
    final updater = _Updater();
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider.value(value: prefs),
        ],
        child: MaterialApp(
            theme: ThemeData.dark(),
            home: CheckUpdatesScreen(updateService: updater))));
    await tester.pump();

    expect(find.text('One tested update a week.'), findsOneWidget);
    await tester.tap(find.text('Test builds'));
    await tester.pump();
    await tester.pump();

    expect(storage.getUpdateChannel(), 'test');
    expect(updater.channels, [UpdateChannel.test]);
    expect(find.text('Test build 1.0.73-dev.955 is available'), findsOneWidget);
    expect(find.textContaining('A test build can have new bugs'),
        findsOneWidget);

    // Back to Stable: checked again on that channel.
    await tester.tap(find.text('Stable'));
    await tester.pump();
    await tester.pump();
    expect(storage.getUpdateChannel(), 'stable');
    expect(updater.channels.last, UpdateChannel.stable);
    expect(find.text("You're on the latest version."), findsOneWidget);
  });
}
