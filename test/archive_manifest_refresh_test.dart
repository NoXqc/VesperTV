import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nox_iptv/models/archive_models.dart';
import 'package:nox_iptv/services/archive_api_service.dart';
import 'package:nox_iptv/services/archive_cache.dart';
import 'package:nox_iptv/services/archive_service.dart';
import 'package:nox_iptv/services/storage_service.dart';
import 'package:nox_iptv/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Cache extends ArchiveCache {
  @override
  Future<DateTime?> fetchedAt(String sourceKey, ArchiveCatalog catalog) async =>
      null;
  @override
  Future<List<ArchiveMeta>> read(
          String sourceKey, ArchiveCatalog catalog) async =>
      [];
  @override
  Future<void> write(String sourceKey, ArchiveCatalog catalog,
      List<ArchiveMeta> items) async {}
}

const _old = ArchiveSource(
  manifestUrl: 'https://source.example/manifest.json',
  name: 'Custom source',
  otherChoice: false,
  catalogs: [
    ArchiveCatalog(
        type: ArchiveType.movie,
        wireType: 'CustomVideo',
        id: 'retired',
        name: 'Old catalog')
  ],
);

http.Response _manifest() => http.Response(
    jsonEncode({
      'name': 'Custom source',
      'resources': ['catalog', 'stream'],
      'types': ['CustomVideo'],
      'idPrefixes': ['own:'],
      'catalogs': [
        {'type': 'CustomVideo', 'id': 'current', 'name': 'Current'}
      ],
    }),
    200);

http.Response _catalog() => http.Response(
    jsonEncode({
      'metas': [
        {'id': 'own:1', 'type': 'CustomVideo', 'name': 'Sample'}
      ],
    }),
    200);

Future<StorageService> _storage() async {
  SharedPreferences.setMockInitialValues({
    AppConstants.keyArchiveSources: jsonEncode([_old.toJson()])
  });
  final storage = StorageService();
  await storage.init();
  return storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final coldOpen in [false, true]) {
    test('catalog definitions update on ${coldOpen ? 'cold open' : 'Refresh'}',
        () async {
      final hits = <String>[];
      final storage = await _storage();
      final loaded = Completer<void>();
      final api = ArchiveApiService(client: MockClient((request) async {
        hits.add(request.url.path);
        if (request.url.path == '/manifest.json') return _manifest();
        if (request.url.path == '/catalog/CustomVideo/current.json') {
          if (!loaded.isCompleted) loaded.complete();
          return _catalog();
        }
        return http.Response(jsonEncode({'metas': []}), 200);
      }));
      final service = ArchiveService(storage, api: api, cache: _Cache());
      if (coldOpen) {
        await service.open();
        await loaded.future;
        while (service.refreshing) {
          await Future<void>.delayed(Duration.zero);
        }
      } else {
        await service.refresh(force: true);
      }
      expect(service.sources.single.catalogs.single.id, 'current');
      expect(service.sources.single.otherChoice, isFalse);
      expect(service.rows(ArchiveType.movie).single.items.single.id, 'own:1');
      expect(hits, isNot(contains('/catalog/CustomVideo/retired.json')));
      service.dispose();
      api.close();
    });
  }

  test('failed manifest keeps the saved catalogs usable', () async {
    final storage = await _storage();
    final api = ArchiveApiService(
        client: MockClient((request) async =>
            request.url.path == '/manifest.json'
                ? http.Response('temporarily unavailable', 503)
                : _catalog()));
    final service = ArchiveService(storage, api: api, cache: _Cache());
    await service.refresh(force: true);
    expect(service.sources.single.catalogs.single.id, 'retired');
    expect(service.rows(ArchiveType.movie).single.items, hasLength(1));
    service.dispose();
    api.close();
  });

  test('manifest response preserves settings changed during its request',
      () async {
    final storage = await _storage();
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final api = ArchiveApiService(client: MockClient((request) async {
      if (request.url.path == '/manifest.json') {
        started.complete();
        return pending.future;
      }
      return _catalog();
    }));
    final service = ArchiveService(storage, api: api, cache: _Cache());
    final refresh = service.refresh(force: true);
    await started.future;
    await service.setEnabled(service.sources.single, false);
    await service.setUnderOther(service.sources.single, true);
    pending.complete(_manifest());
    await refresh;
    expect(service.sources.single.enabled, isFalse);
    expect(service.sources.single.otherChoice, isTrue);
    expect(service.sources.single.catalogs.single.id, 'current');
    service.dispose();
    api.close();
  });

  test('removed source is not resurrected by a pending manifest response',
      () async {
    final storage = await _storage();
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final api = ArchiveApiService(client: MockClient((request) async {
      started.complete();
      return pending.future;
    }));
    final service = ArchiveService(storage, api: api, cache: _Cache());
    final refresh = service.refresh(force: true);
    await started.future;
    await storage.setArchiveSourcesJson('[]');
    pending.complete(_manifest());
    await refresh;
    expect(service.sources, isEmpty);
    service.dispose();
    api.close();
  });
  test('Refresh queued during a catalog load still updates the manifest',
      () async {
    final storage = await _storage();
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    var oldRequests = 0;
    final api = ArchiveApiService(client: MockClient((request) async {
      if (request.url.path == '/manifest.json') return _manifest();
      if (request.url.path.contains('/retired.json') && oldRequests++ == 0) {
        started.complete();
        return pending.future;
      }
      return _catalog();
    }));
    final service = ArchiveService(storage, api: api, cache: _Cache());
    final refresh = service.refresh();
    await started.future;
    await service.refresh(force: true);
    pending.complete(_catalog());
    await refresh;
    expect(service.sources.single.catalogs.single.id, 'current');
    expect(service.rows(ArchiveType.movie).single.catalog.id, 'current');
    service.dispose();
    api.close();
  });

  test('HTTP failure diagnostics never include the configured URL', () async {
    final api = ArchiveApiService(
        client:
            MockClient((request) async => http.Response('unavailable', 503)));
    try {
      await api.fetchManifest(
          'https://source.example/private-configuration/manifest.json');
      fail('Expected a source error');
    } on ArchiveApiException catch (error) {
      expect(error.statusCode, 503);
      expect(error.toString(), isNot(contains('private-configuration')));
      expect(error.toString(), isNot(contains('source.example')));
    } finally {
      api.close();
    }
  });
}
