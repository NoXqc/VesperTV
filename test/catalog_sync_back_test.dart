import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/screens/catalog_sync_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Fire TV report: Back on "Updating Content" left the app and the update
  // stopped. Back now leaves only the screen; the update keeps going.
  testWidgets('Back on the launch sync screen opens the app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    final manager = PlaylistManager(storage, CatalogDatabase());
    addTearDown(manager.dispose);
    var backs = 0;

    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: prefs,
        child: CatalogSyncScreen(playlist: manager, onBack: () => backs++)));
    await tester.pump();
    expect(
        find.textContaining('Press Back to use the app now'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();
    expect(handled, isTrue, reason: 'Back must not reach Android (app exit)');
    expect(backs, 1);
  });
}
