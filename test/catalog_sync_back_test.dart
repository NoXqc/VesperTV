import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/catalog_sync_screen.dart';
import 'package:nox_iptv/services/app_exit.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const device = MethodChannel('com.nox.nox_iptv/device_type');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(device, null);
    AppExit.beforeWarm = null;
    AppExit.afterWarm = null;
  });

  // Fire TV report: Back on "Updating Content" finished the activity and
  // the update stopped. It now goes to the background like the Home key.
  testWidgets('Back on the launch sync screen is a warm exit', (tester) async {
    AppExit.isWindows = false;
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(device, (call) async {
      calls.add(call.method);
      return call.method == 'moveTaskToBack' ? true : null;
    });
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    final manager = PlaylistManager(storage, CatalogDatabase());
    addTearDown(manager.dispose);

    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: prefs, child: CatalogSyncScreen(playlist: manager)));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(calls, contains('moveTaskToBack'));
  });
}
