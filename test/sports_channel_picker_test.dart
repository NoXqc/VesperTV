import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nox_iptv/models/channel.dart';
import 'package:nox_iptv/screens/sports_channels_screen.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/epg_service.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_service.dart';

void main() {
  testWidgets(
      'manual selections survive searches beyond channel 200 without EPG',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final prefs = AppPreferences(storage);
    await prefs.init();
    final playlist = PlaylistManager(storage, CatalogDatabase());
    final epg = EpgService(storage);
    await tester.pumpWidget(MultiProvider(
        providers: [
          Provider.value(value: storage),
          ChangeNotifierProvider.value(value: prefs),
          ChangeNotifierProvider<PlaylistManager>.value(value: playlist),
          ChangeNotifierProvider<EpgService>.value(value: epg),
        ],
        child: MaterialApp(
            home: SportsChannelPicker(channels: [
          for (var i = 0; i < 1000; i++)
            Channel(
                id: 'p::$i',
                rawId: '$i',
                playlistId: 'p',
                name: 'Local $i',
                group: 'No tags',
                url: ''),
        ]))));
    await tester.enterText(find.byType(TextField), 'Local 999');
    await tester.pump();
    await tester.tap(find.text('Local 999').last);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Local 123');
    await tester.pump();
    await tester.tap(find.text('Local 123').last);
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    prefs.dispose();
    playlist.dispose();
    epg.dispose();
  });
}
