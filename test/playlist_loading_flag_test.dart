import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/models/xtream_category.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_session.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/services/xtream_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The TV header's "Updating…" ([PlaylistSession.isLoading]) stayed on
/// after a background update (owner, 2026-11-07): a row opened on screen
/// finished while the update still had rows in flight, and the update's own
/// row loads never cleared the flag.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late StorageService storage;
  late Directory temp;
  CatalogDatabase? catalog;
  setUp(() async {
    HttpOverrides.global = null; // the test binding fakes HTTP otherwise
    databaseFactory = databaseFactoryFfi;
    temp = await Directory.systemTemp.createTemp('vesper-loading-');
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });
  tearDown(() async {
    await catalog?.close();
    await temp.delete(recursive: true);
  });

  test('Updating… clears after a row load overlaps the background update',
      () async {
    // The on-screen row (id 99) answers at once; the update's rows slowly.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.queryParameters['category_id'] != '99') {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      request.response
        ..headers.contentType = ContentType.json
        ..write('[]')
        ..close();
    });

    final s = PlaylistSession(
        profile: PlaylistProfile(
            id: 'p',
            name: 'p',
            mode: 'xtream',
            sortOrder: 0,
            createdAt: DateTime(2026)),
        storage: storage,
        catalogDb: catalog =
            CatalogDatabase(databasePath: '${temp.path}/catalog.db'),
        favoriteIds: () => {},
        favoriteSeriesIds: () => {},
        isRestrictedViewer: () => false,
        onNotify: () {});
    s.xtreamApi = XtreamApiService(
        server: 'http://127.0.0.1:${server.port}',
        username: 'u',
        password: 'p',
        playlistId: 'p');
    s.vodCategories = [
      for (var i = 0; i < 6; i++) XtreamCategory(id: '$i', name: 'Movies $i')
    ];
    s.vodCategoryIdByName['On screen'] = '99';

    final update = s.refreshAllCategories();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(s.loadingCategoryNames, isNotEmpty,
        reason: 'the update has rows in flight');

    await s.ensureCategoryLoaded('On screen', 'vod');
    await update;
    await server.close(force: true);

    expect(s.loadingCategoryNames, isEmpty);
    expect(s.isLoading, isFalse);
  });
}
