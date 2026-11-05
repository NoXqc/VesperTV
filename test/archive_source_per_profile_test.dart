import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Cache extends ArchiveCache {
  @override
  Future<List<ArchiveMeta>> read(
          String sourceKey, ArchiveCatalog catalog) async =>
      const [];
  @override
  Future<DateTime?> fetchedAt(String sourceKey, ArchiveCatalog catalog) async =>
      null;
  @override
  Future<void> deleteSource(String sourceKey) async {}
}

const _a = ArchiveSource(
    manifestUrl: 'https://a.example/manifest.json', name: 'A');
const _b = ArchiveSource(
    manifestUrl: 'https://b.example/manifest.json', name: 'B');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Enabled and Show under Other are per profile; the list is shared',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyArchiveSources: jsonEncode([_a.toJson(), _b.toJson()]),
    });
    final storage = StorageService();
    await storage.init();
    final service = ArchiveService(storage, cache: _Cache());

    // The wife's profile turns A off and puts B under Other.
    await storage.setActiveViewerId('wife');
    await service.setEnabled(_a, false);
    await service.setUnderOther(_b, true);
    expect(service.enabledSources.map((s) => s.name), ['B']);
    expect(service.sources.firstWhere((s) => s.name == 'B').underOther,
        isTrue);

    // Main still has both, as they were.
    await storage.setActiveViewerId(AppConstants.mainViewerId);
    expect(service.enabledSources.map((s) => s.name), ['A', 'B']);
    expect(service.sources.every((s) => !s.underOther), isTrue);

    // The shared list was never rewritten with a profile's choices.
    final stored = jsonDecode(storage.getArchiveSourcesJson()!) as List;
    expect(stored.every((j) => j['enabled'] == true && j['other'] == null),
        isTrue);

    // Removing is still for everyone.
    await service.removeSource(_a);
    await storage.setActiveViewerId('wife');
    expect(service.sources.map((s) => s.name), ['B']);
    service.dispose();
  });
}
