import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/settings/check_updates_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/app_update_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// GitHub #22 (Fire TV Stick 4K Max): the installer said "installed" and the
// app stayed on 1.0.74-dev.980. MainActivity notes what it handed to the
// installer and, at the next start, whether it arrived.
class _Updater extends AppUpdateService {
  _Updater(this.failure);
  final String? failure;

  @override
  Future<String?> lastInstallFailure() async => failure;

  @override
  Future<UpdateInfo?> checkForUpdate(
          {UpdateChannel channel = UpdateChannel.stable}) async =>
      null;
}

const _text = "The update to 1.0.74-dev.1013 didn't install: this device still "
    'has the version above. Try again; if it fails again, free some storage '
    'or install it with the Downloader app.';

Future<void> _open(WidgetTester tester, String? failure) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  final prefs = AppPreferences(storage);
  await prefs.init();
  addTearDown(prefs.dispose);
  PackageInfo.setMockInitialValues(
      appName: 'VesperTV',
      packageName: 'com.nox.nox_iptv',
      version: '1.0.74-dev.980',
      buildNumber: '980',
      buildSignature: '');
  await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider.value(value: prefs),
      ],
      child: MaterialApp(
          theme: ThemeData.dark(),
          home: CheckUpdatesScreen(updateService: _Updater(failure)))));
  await tester.pump();
}

void main() {
  testWidgets('an update that never arrived is named under the version',
      (tester) async {
    await _open(tester, '1.0.74-dev.1013');
    expect(find.text(_text), findsOneWidget);
  });

  testWidgets('nothing when the last update arrived', (tester) async {
    await _open(tester, null);
    expect(find.textContaining("didn't install"), findsNothing);
  });

  group('lastInstallFailure', () {
    const channel = MethodChannel('com.nox.nox_iptv/app_update');
    final messenger =
        TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('Android asks MainActivity', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'lastInstallFailure');
        return '1.0.74-dev.1013';
      });
      final service = AppUpdateService(operatingSystem: 'android');
      expect(await service.lastInstallFailure(), '1.0.74-dev.1013');
    });

    test('an older app without the method = nothing', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException();
      });
      final service = AppUpdateService(operatingSystem: 'android');
      expect(await service.lastInstallFailure(), isNull);
    });

    test('other systems never ask', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        fail('asked on Windows');
      });
      final service = AppUpdateService(operatingSystem: 'windows');
      expect(await service.lastInstallFailure(), isNull);
    });
  });
}
