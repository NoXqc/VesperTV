import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

// An add-on reconfigured in its web page gets a new install link; titles
// played under the old link must stay in Recently watched / Continue watching.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(StorageService, ArchiveService)> setUp(
      List<ArchiveSource> sources) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources:
          jsonEncode([for (final s in sources) s.toJson()])
    });
    final storage = StorageService();
    await storage.init();
    return (storage, ArchiveService(storage));
  }

  const old = ArchiveSource(
      manifestUrl: 'https://addon.example/OLDCONFIG/manifest.json', name: 'A');
  const now = ArchiveSource(
      manifestUrl: 'https://addon.example/NEWCONFIG/manifest.json', name: 'A');
  const movie = ArchiveMeta(id: 'tt1', name: 'M', type: ArchiveType.movie);

  test('history under a reconfigured add-on link stays visible', () async {
    final (storage, hub) = await setUp(const [now]);
    await hub.recordWatched(old, movie);
    expect(hub.continueWatching(ArchiveType.movie).single.source.manifestUrl,
        now.manifestUrl);
    expect(hub.recentlyWatched().single.meta.id, 'tt1');
    hub.dispose();
  });

  test('an old link with two add-ons on its host stays hidden', () async {
    const other = ArchiveSource(
        manifestUrl: 'https://addon.example/OTHER/manifest.json', name: 'B');
    final (storage, hub) = await setUp(const [now, other]);
    await hub.recordWatched(old, movie);
    expect(hub.continueWatching(ArchiveType.movie), isEmpty);
    hub.dispose();
  });
}
