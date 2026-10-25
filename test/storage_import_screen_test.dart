import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/models/playlist_profile.dart';
import 'package:nox_iptv/screens/settings/storage_import_screen.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/app_preferences.dart';
import 'package:nox_iptv/services/catalog_database.dart';
import 'package:nox_iptv/services/playlist_manager.dart';
import 'package:nox_iptv/services/storage_import_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:provider/provider.dart';

const _link = 'https://example.com/addon/manifest.json';

class _Importer extends StorageImportService {
  int reads = 0;
  final folder =
      StorageItem(uri: Directory('USB').uri, name: 'USB', folder: true);
  @override
  Future<List<StorageItem>> roots() async => [folder];
  @override
  Future<List<StorageItem>> children(StorageItem folder,
          {bool all = false}) async =>
      [
        StorageItem(
            uri: folder.uri.resolve('channels.m3u'), name: 'channels.m3u')
      ];
  @override
  Future<PreparedStorageImport> preparePlaylist(
      StorageItem file, StorageItem folder) async {
    reads++;
    return PreparedStorageImport(File('imported.m3u'), 10,
        sourceLinks: [_link]);
  }
}

class _Manager extends PlaylistManager {
  _Manager() : super(StorageService(), CatalogDatabase());
  final entries = [
    PlaylistProfile(
        id: 'existing',
        name: 'Existing',
        mode: 'm3u',
        sortOrder: 0,
        createdAt: DateTime(2026))
  ];
  @override
  List<PlaylistProfile> get profiles => entries;
  @override
  Future<void> addPlaylist(PlaylistProfile profile) async {
    entries.add(profile);
  }

  @override
  Future<void> loadPlaylist(String id) async {}
}

class _Archive extends ArchiveService {
  _Archive() : super(StorageService());
  final added = <ArchiveSource>[];
  @override
  bool hasSource(String link) => false;
  @override
  Future<ArchiveSource> checkSource(String link) async =>
      ArchiveSource(manifestUrl: link, name: 'Imported');
  @override
  Future<List<ArchiveSource>> addCheckedSources(
      List<ArchiveSource> sources) async {
    added.addAll(sources);
    return sources;
  }
}

void main() {
  for (final confirm in [false, true]) {
    testWidgets(
        'storage import ${confirm ? 'adds' : 'cancels'} without replacing setup',
        (tester) async {
      final manager = _Manager();
      final archive = _Archive();
      final importer = _Importer();
      final prefs = AppPreferences(StorageService())
        ..layoutMode = 'auto'
        ..palette = AppConstants.cyberpunkPalettes.first;
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider<PlaylistManager>.value(value: manager),
        ChangeNotifierProvider<ArchiveService>.value(value: archive),
        ChangeNotifierProvider<AppPreferences>.value(value: prefs),
      ], child: MaterialApp(home: StorageImportScreen(importer: importer))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USB'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('channels.m3u'));
      await tester.pumpAndSettle();
      expect(importer.reads, 0);
      expect(FocusManager.instance.primaryFocus?.debugLabel,
          'storage-import-cancel');
      await tester.tap(find.text(confirm ? 'Import' : 'Cancel'));
      await tester.pumpAndSettle();
      expect(importer.reads, confirm ? 1 : 0);
      expect(manager.profiles.first.id, 'existing');
      expect(manager.profiles.length, confirm ? 2 : 1);
      expect(
          archive.added.map((s) => s.manifestUrl), confirm ? [_link] : isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
